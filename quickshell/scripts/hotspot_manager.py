#!/usr/bin/env python3
"""
Hotspot Manager for DynamicYou Quickshell & Hyprland
Manages Wi-Fi Access Point (Hotspot) creation, credentials, persistence, and NetworkManager state.
Provides seamless DHCP leasing via NetworkManager + dnsmasq, avoids duplicate profiles,
and eliminates "Obtaining IP address" hangs on connecting client devices.
"""

import sys
import os
import json
import shutil
import socket
import subprocess

CONFIG_DIR = os.path.expanduser("~/.config/quickshell")
CONFIG_FILE = os.path.join(CONFIG_DIR, "hotspot.json")
CONNECTION_NAME = "Hotspot"
DEFAULT_PASS = "12345678"

def get_default_ssid():
    """Generate a clean, personalized default SSID instead of hardcoded author names."""
    user = os.environ.get("USER", "").strip()
    if user and user.lower() not in ("root", "nobody"):
        return f"{user.capitalize()}-Hotspot"
    try:
        host = socket.gethostname().strip()
        if host:
            return f"{host.capitalize()}-Hotspot"
    except Exception:
        pass
    return "Linux-Hotspot"

def get_nm_hotspot_credentials():
    """Try reading SSID and password from existing NetworkManager Hotspot connection."""
    ssid = None
    password = None
    if shutil.which("nmcli"):
        try:
            out_s = subprocess.check_output(
                ["nmcli", "-s", "-g", "802-11-wireless.ssid", "connection", "show", CONNECTION_NAME],
                text=True, stderr=subprocess.DEVNULL, timeout=2
            ).strip()
            if out_s:
                ssid = out_s
        except Exception:
            pass
        try:
            out_p = subprocess.check_output(
                ["nmcli", "-s", "-g", "802-11-wireless-security.psk", "connection", "show", CONNECTION_NAME],
                text=True, stderr=subprocess.DEVNULL, timeout=2
            ).strip()
            if out_p and len(out_p) >= 8:
                password = out_p
        except Exception:
            pass
    return ssid, password

def load_config():
    """Load hotspot configuration from JSON, with fallback to NM profile or smart defaults."""
    default_ssid = get_default_ssid()
    default_config = {
        "ssid": default_ssid,
        "password": DEFAULT_PASS
    }

    if os.path.exists(CONFIG_FILE):
        try:
            with open(CONFIG_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
                if isinstance(data, dict):
                    ssid = str(data.get("ssid", "")).strip() or default_ssid
                    password = str(data.get("password", "")).strip() or DEFAULT_PASS
                    return {"ssid": ssid, "password": password}
        except Exception as e:
            sys.stderr.write(f"Warning: could not read {CONFIG_FILE}: {e}\n")

    # If no config file yet, check if NM already has credentials
    nm_ssid, nm_pass = get_nm_hotspot_credentials()
    if nm_ssid:
        default_config["ssid"] = nm_ssid
    if nm_pass:
        default_config["password"] = nm_pass

    # Save initial config
    save_config(default_config["ssid"], default_config["password"], update_nm=False)
    return default_config

def save_config(ssid, password, update_nm=True):
    """Persist hotspot settings to ~/.config/quickshell/hotspot.json and update NM profile."""
    os.makedirs(CONFIG_DIR, exist_ok=True)
    ssid = (ssid or "").strip() or get_default_ssid()
    password = (password or "").strip() or DEFAULT_PASS
    data = {"ssid": ssid, "password": password}

    try:
        tmp_file = CONFIG_FILE + ".tmp"
        with open(tmp_file, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
        os.replace(tmp_file, CONFIG_FILE)
    except Exception as e:
        sys.stderr.write(f"Error saving config to {CONFIG_FILE}: {e}\n")

    if update_nm and shutil.which("nmcli") and len(password) >= 8:
        try:
            # Check if Hotspot profile exists
            out = subprocess.check_output(
                ["nmcli", "-t", "-f", "NAME", "connection", "show"],
                text=True, stderr=subprocess.DEVNULL, timeout=2
            )
            has_profile = any(line.strip() == CONNECTION_NAME for line in out.splitlines())
            if has_profile:
                subprocess.run([
                    "nmcli", "connection", "modify", CONNECTION_NAME,
                    "802-11-wireless.ssid", ssid,
                    "802-11-wireless-security.psk", password
                ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=3)
        except Exception:
            pass

def get_wifi_interface():
    """Identify the primary Wi-Fi network interface."""
    if not shutil.which("nmcli"):
        return "wlan0"
    try:
        out = subprocess.check_output(
            ["nmcli", "-t", "-f", "DEVICE,TYPE", "dev"],
            text=True, stderr=subprocess.DEVNULL, timeout=2
        )
        for line in out.splitlines():
            parts = line.strip().split(":")
            if len(parts) >= 2 and parts[1] == "wifi":
                return parts[0]
    except Exception:
        pass
    return "wlan0"

def is_hotspot_active():
    """Check if the Wi-Fi AP hotspot is currently active."""
    if not shutil.which("nmcli"):
        return False
    try:
        out = subprocess.check_output(
            ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show", "--active"],
            text=True, stderr=subprocess.DEVNULL, timeout=2
        )
        for line in out.splitlines():
            parts = line.strip().split(":")
            if len(parts) >= 2:
                name = parts[0].strip()
                ctype = parts[1].strip()
                if name.lower() == CONNECTION_NAME.lower() or "hotspot" in name.lower():
                    if "wifi" in ctype or "802-11" in ctype:
                        return True
    except Exception:
        pass
    return False

def get_connected_clients(iface=None):
    """Count connected Wi-Fi stations/devices using `iw`."""
    if not iface:
        iface = get_wifi_interface()
    if not iface or not shutil.which("iw"):
        return 0
    try:
        out = subprocess.check_output(
            ["iw", "dev", iface, "station", "dump"],
            text=True, stderr=subprocess.DEVNULL, timeout=2
        )
        stations = [line for line in out.splitlines() if line.startswith("Station ")]
        return len(stations)
    except Exception:
        return 0

def cleanup_duplicate_hotspots():
    """Clean up any redundant 'Hotspot 1', 'Hotspot 2' profiles left by raw nmcli hotspot commands."""
    if not shutil.which("nmcli"):
        return
    try:
        out = subprocess.check_output(
            ["nmcli", "-t", "-f", "UUID,NAME", "connection", "show"],
            text=True, stderr=subprocess.DEVNULL, timeout=2
        )
        for line in out.splitlines():
            parts = line.strip().split(":")
            if len(parts) >= 2:
                uuid = parts[0]
                name = parts[1]
                if name.startswith(CONNECTION_NAME + " ") or (name.lower().startswith("hotspot ") and name != CONNECTION_NAME):
                    subprocess.run(["nmcli", "connection", "delete", "uuid", uuid],
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=3)
    except Exception:
        pass

def start_hotspot(ssid=None, password=None):
    """
    Start or reconfigure the Hotspot connection profile and activate it.
    Uses:
      - 802-11-wireless.mode = ap
      - 802-11-wireless.band = bg
      - 802-11-wireless-security.pmf = 1 (disable PMF to fix handshake rejection on Android/iOS)
      - ipv4.method = shared (NetworkManager internal DHCP via dnsmasq)
      - ipv6.method = ignore (prevents DHCPv6/RA timeouts)
    """
    if not shutil.which("nmcli"):
        return False, "nmcli command not found"

    cfg = load_config()
    target_ssid = (ssid or cfg.get("ssid") or get_default_ssid()).strip()
    target_pass = (password or cfg.get("password") or DEFAULT_PASS).strip()

    if len(target_pass) < 8:
        return False, "Password must be at least 8 characters"

    # Persist the used SSID & password
    save_config(target_ssid, target_pass, update_nm=False)
    cleanup_duplicate_hotspots()
    iface = get_wifi_interface()

    # 1. Ensure Wi-Fi radio is switched on
    try:
        subprocess.run(["nmcli", "radio", "wifi", "on"],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5)
    except Exception:
        pass

    # 2. Check if connection profile named "Hotspot" already exists
    has_profile = False
    try:
        out = subprocess.check_output(
            ["nmcli", "-t", "-f", "NAME", "connection", "show"],
            text=True, stderr=subprocess.DEVNULL, timeout=2
        )
        has_profile = any(line.strip() == CONNECTION_NAME for line in out.splitlines())
    except Exception:
        pass

    try:
        if not has_profile:
            # Create fresh profile
            subprocess.run([
                "nmcli", "connection", "add",
                "type", "wifi",
                "ifname", iface,
                "con-name", CONNECTION_NAME,
                "autoconnect", "no",
                "ssid", target_ssid
            ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5)

        # 3. Apply bulletproof Hotspot AP & DHCP sharing configuration
        subprocess.run([
            "nmcli", "connection", "modify", CONNECTION_NAME,
            "connection.interface-name", iface,
            "802-11-wireless.ssid", target_ssid,
            "802-11-wireless.mode", "ap",
            "802-11-wireless.band", "bg",
            "802-11-wireless-security.key-mgmt", "wpa-psk",
            "802-11-wireless-security.proto", "rsn",
            "802-11-wireless-security.pairwise", "ccmp",
            "802-11-wireless-security.group", "ccmp",
            "802-11-wireless-security.pmf", "1",
            "802-11-wireless-security.psk", target_pass,
            "ipv4.method", "shared",
            "ipv6.method", "ignore"
        ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5)

        # 4. Bring up the connection
        res = subprocess.run(
            ["nmcli", "connection", "up", CONNECTION_NAME],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=12
        )
        if res.returncode == 0:
            return True, "Hotspot activated successfully"
        else:
            return False, res.stderr.strip() or "Failed to activate Hotspot"
    except Exception as e:
        return False, str(e)

def stop_hotspot():
    """Gracefully stop the hotspot connection and any dangling AP instances."""
    if not shutil.which("nmcli"):
        return False, "nmcli command not found"
    try:
        # Deactivate Hotspot connection
        subprocess.run(["nmcli", "connection", "down", CONNECTION_NAME],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5)

        # Catch any other active Wi-Fi AP connections
        out = subprocess.check_output(
            ["nmcli", "-t", "-f", "UUID,NAME,TYPE", "connection", "show", "--active"],
            text=True, stderr=subprocess.DEVNULL, timeout=2
        )
        for line in out.splitlines():
            parts = line.strip().split(":")
            if len(parts) >= 3:
                uuid = parts[0]
                name = parts[1]
                ctype = parts[2]
                if ("wifi" in ctype or "802-11" in ctype) and "hotspot" in name.lower():
                    subprocess.run(["nmcli", "connection", "down", "uuid", uuid],
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=3)
        cleanup_duplicate_hotspots()
        return True, "Hotspot stopped successfully"
    except Exception as e:
        return False, str(e)

def toggle_hotspot(ssid=None, password=None):
    """Toggle hotspot state on or off."""
    if is_hotspot_active():
        return stop_hotspot()
    else:
        return start_hotspot(ssid, password)

def print_status():
    """Print current live status and metadata as JSON."""
    active = is_hotspot_active()
    cfg = load_config()
    clients = get_connected_clients() if active else 0
    has_dnsmasq = bool(shutil.which("dnsmasq"))
    has_iptables = bool(shutil.which("iptables"))

    data = {
        "active": active,
        "ssid": cfg.get("ssid", get_default_ssid()),
        "password": cfg.get("password", DEFAULT_PASS),
        "clients": clients,
        "dnsmasq_installed": has_dnsmasq,
        "iptables_installed": has_iptables
    }
    print(json.dumps(data))

def print_config():
    """Print saved credentials and settings as JSON."""
    cfg = load_config()
    active = is_hotspot_active()
    clients = get_connected_clients() if active else 0
    has_dnsmasq = bool(shutil.which("dnsmasq"))

    data = {
        "ssid": cfg.get("ssid", get_default_ssid()),
        "password": cfg.get("password", DEFAULT_PASS),
        "active": active,
        "clients": clients,
        "dnsmasq_installed": has_dnsmasq
    }
    print(json.dumps(data))

def main():
    if len(sys.argv) < 2 or sys.argv[1] in ("status", "get"):
        print_status()
        return

    cmd = sys.argv[1].lower()

    if cmd == "config":
        print_config()
    elif cmd == "set-config":
        ssid = sys.argv[2] if len(sys.argv) > 2 else ""
        password = sys.argv[3] if len(sys.argv) > 3 else ""
        save_config(ssid, password, update_nm=True)
        print_config()
    elif cmd == "start":
        ssid = sys.argv[2] if len(sys.argv) > 2 else None
        password = sys.argv[3] if len(sys.argv) > 3 else None
        success, msg = start_hotspot(ssid, password)
        print(json.dumps({"success": success, "message": msg, "active": is_hotspot_active()}))
    elif cmd == "stop":
        success, msg = stop_hotspot()
        print(json.dumps({"success": success, "message": msg, "active": is_hotspot_active()}))
    elif cmd == "toggle":
        ssid = sys.argv[2] if len(sys.argv) > 2 else None
        password = sys.argv[3] if len(sys.argv) > 3 else None
        success, msg = toggle_hotspot(ssid, password)
        print(json.dumps({"success": success, "message": msg, "active": is_hotspot_active()}))
    else:
        print_status()

if __name__ == "__main__":
    main()
