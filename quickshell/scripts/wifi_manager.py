#!/usr/bin/env python3
"""Unified Wi-Fi Management Backend for Quickshell
Combines Minflair's robust scan/connect/toggle architecture with Lucid's
saved secret extraction, auto-connect controls, and sharing capabilities.
"""
import sys
import os
import json
import subprocess

sys.dont_write_bytecode = True

def run_cmd(args, timeout=10):
    try:
        res = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
        return res.returncode, res.stdout.strip(), res.stderr.strip()
    except Exception as e:
        return 1, "", str(e)

def get_wifi_device():
    rc, out, _ = run_cmd(["nmcli", "-t", "-f", "DEVICE,TYPE", "device"])
    if rc == 0:
        for line in out.splitlines():
            parts = line.split(":")
            if len(parts) >= 2 and parts[1] == "wifi":
                return parts[0].strip()
    return "wlan0"

def get_saved_connections():
    saved = {}
    rc, out, _ = run_cmd(["nmcli", "-t", "-f", "NAME,TYPE,UUID,AUTOCONNECT", "connection", "show"])
    if rc == 0:
        for line in out.splitlines():
            parts = line.split(":")
            if len(parts) >= 4 and parts[1] in ("802-11-wireless", "wifi"):
                name = parts[0].replace(r"\:", ":").strip()
                saved[name] = {
                    "uuid": parts[2].strip(),
                    "autoconnect": (parts[3].strip() == "yes")
                }
    return saved

def get_status():
    radio = False
    connected_ssid = ""
    active_ip = ""
    active_dev = get_wifi_device()
    hotspot_active = False

    # Check radio state
    rc, out, _ = run_cmd(["nmcli", "radio", "wifi"])
    if rc == 0:
        radio = (out == "enabled")

    # Check active devices
    ethernet = None
    rc, out, _ = run_cmd(["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device"])
    if rc == 0:
        for line in out.splitlines():
            parts = line.split(":")
            if len(parts) >= 4:
                dtype = parts[1].strip()
                dev = parts[0].strip()
                state = parts[2].strip()
                con = parts[3].replace(r"\:", ":").strip()
                if dtype == "wifi":
                    active_dev = dev
                    if state == "connected":
                        connected_ssid = con
                elif dtype == "ethernet" and ethernet is None:
                    eth_ip = ""
                    rc_ip, out_ip, _ = run_cmd(["ip", "-4", "-br", "addr", "show", "dev", dev])
                    if rc_ip == 0 and out_ip:
                        fields = out_ip.split()
                        if len(fields) >= 3:
                            eth_ip = fields[2].split("/")[0]
                    speed = ""
                    speed_path = f"/sys/class/net/{dev}/speed"
                    if os.path.exists(speed_path):
                        try:
                            with open(speed_path) as sf:
                                s = sf.read().strip()
                                if s and int(s) > 0:
                                    speed = s
                        except Exception:
                            pass
                    ethernet = {
                        "device": dev,
                        "connected": (state == "connected"),
                        "state": state,
                        "connection": con,
                        "ip": eth_ip,
                        "speed": speed
                    }

    # Check active IP for wifi device
    if active_dev:
        rc, out, _ = run_cmd(["ip", "-4", "-br", "addr", "show", "dev", active_dev])
        if rc == 0 and out:
            fields = out.split()
            if len(fields) >= 3:
                active_ip = fields[2].split("/")[0]

    # Check hotspot
    rc, out, _ = run_cmd(["nmcli", "-t", "-f", "TYPE,NAME", "con", "show", "--active"])
    if rc == 0:
        for line in out.splitlines():
            if ":Hotspot" in line or "hotspot" in line.lower():
                hotspot_active = True
                break

    return {
        "radio": radio,
        "connected_ssid": connected_ssid,
        "active_ip": active_ip,
        "active_dev": active_dev,
        "hotspot_active": hotspot_active,
        "ethernet": ethernet
    }

def scan_networks(rescan=True):
    status = get_status()
    if not status["radio"]:
        return {
            "status": status,
            "saved": [],
            "available": []
        }

    saved_conns = get_saved_connections()
    networks = {}
    
    cmd = [
        "nmcli", "-t",
        "-f", "IN-USE,SSID,SIGNAL,SECURITY,CHAN,FREQ,RATE",
        "device", "wifi", "list"
    ]
    if rescan:
        cmd.extend(["--rescan", "yes"])
    else:
        cmd.extend(["--rescan", "no"])

    rc, out, _ = run_cmd(cmd, timeout=12)
    if rc == 0:
        for raw_line in out.splitlines():
            if not raw_line:
                continue
            line = raw_line.replace(r"\:", "__COLON__")
            parts = line.split(":")
            if len(parts) < 7:
                continue
            
            in_use = (parts[0].strip() == "*")
            ssid = parts[1].replace("__COLON__", ":").strip()
            if not ssid or ssid == "--":
                continue

            try:
                signal = int(parts[2].strip())
            except ValueError:
                signal = 0

            security = parts[3].replace("__COLON__", ":").strip()
            if not security:
                security = "Open"
            elif "WPA3" in security:
                security = "WPA3"
            elif "WPA2" in security:
                security = "WPA2"
            elif "WPA" in security:
                security = "WPA"

            try:
                chan = int(parts[4].strip())
            except ValueError:
                chan = 0

            freq_str = parts[5].strip()
            band = "5 GHz" if (freq_str.startswith("5") or chan > 14) else "2.4 GHz"
            rate = parts[6].strip().replace("Mbit/s", "Mbps")

            is_saved = (ssid in saved_conns) or in_use
            autoconnect = saved_conns.get(ssid, {}).get("autoconnect", True) if is_saved else False

            entry = {
                "ssid": ssid,
                "signal": signal,
                "active": in_use,
                "saved": is_saved,
                "security": security,
                "band": band,
                "chan": chan,
                "rate": rate,
                "autoconnect": autoconnect,
                "ip": status["active_ip"] if in_use else ""
            }

            if ssid not in networks or in_use or signal > networks[ssid]["signal"]:
                networks[ssid] = entry

    # Split into Lucid standard: Connected, Saved, and Nearby
    connected_list = []
    saved_list = []
    nearby_list = []

    for ssid, item in networks.items():
        if item["active"]:
            connected_list.append(item)
        elif item["saved"]:
            saved_list.append(item)
        else:
            nearby_list.append(item)

    connected_list.sort(key=lambda x: (-x["signal"], x["ssid"].lower()))
    saved_list.sort(key=lambda x: (-x["signal"], x["ssid"].lower()))
    nearby_list.sort(key=lambda x: (-x["signal"], x["ssid"].lower()))

    return {
        "status": status,
        "connected": connected_list,
        "saved": saved_list,
        "nearby": nearby_list
    }

def connect_network(ssid, password=None):
    saved_conns = get_saved_connections()
    safe_ssid = ssid.strip()

    if safe_ssid in saved_conns and not password:
        rc, out, err = run_cmd(["nmcli", "connection", "up", "id", safe_ssid])
    else:
        cmd = ["nmcli", "device", "wifi", "connect", safe_ssid]
        if password and len(password) > 0:
            cmd.extend(["password", password])
        rc, out, err = run_cmd(cmd, timeout=20)

    success = (rc == 0)
    error_msg = ""
    if not success:
        error_msg = err if err else out
        if "Secrets were required, but not provided" in error_msg or "password" in error_msg.lower():
            error_msg = "Incorrect password"
        elif "No network with SSID" in error_msg:
            error_msg = "Network not in range"
        else:
            error_msg = error_msg or "Connection failed"

        # If a bad new profile was created with timestamp 0, clean it up
        if safe_ssid not in saved_conns:
            run_cmd(["nmcli", "connection", "delete", "id", safe_ssid])

    return {"success": success, "error": error_msg}

def disconnect_network(ssid=None):
    dev = get_wifi_device()
    rc, out, _ = run_cmd(["nmcli", "-t", "-f", "UUID,NAME,TYPE", "con", "show", "--active"])
    if rc == 0:
        for line in out.splitlines():
            parts = line.split(":")
            if len(parts) >= 3 and parts[2] in ("802-11-wireless", "wifi"):
                uuid = parts[0].strip()
                cname = parts[1].replace(r"\:", ":").strip()
                should_down = False
                if not ssid or cname == ssid:
                    should_down = True
                else:
                    rc_s, out_s, _ = run_cmd(["nmcli", "-g", "802-11-wireless.ssid", "con", "show", "uuid", uuid])
                    if rc_s == 0 and out_s.strip() == ssid:
                        should_down = True
                if should_down:
                    run_cmd(["nmcli", "con", "down", "uuid", uuid])
    if dev:
        run_cmd(["nmcli", "device", "disconnect", dev])
    return {"success": True}

def forget_network(ssid):
    rc, _, err = run_cmd(["nmcli", "connection", "delete", "id", ssid])
    return {"success": (rc == 0), "error": err}

def find_qrencode_bin():
    candidates = [
        "/run/current-system/sw/bin/qrencode",
        "/nix/store/z57zah5g5zqq8cb9a9m6ryrljgmmi1f6-qrencode-4.1.1-bin/bin/qrencode",
        "qrencode"
    ]
    for p in candidates:
        if os.path.isabs(p) and os.path.isfile(p) and os.access(p, os.X_OK):
            return p
    return "qrencode"

def qr_rows(payload):
    bin_path = find_qrencode_bin()
    try:
        r = subprocess.run([bin_path, "-t", "ASCII", "-m", "0", "-l", "M"],
                           input=payload, capture_output=True, text=True, timeout=6)
        if r.returncode != 0:
            return []
        return ["".join("1" if row[i] == "#" else "0"
                        for i in range(0, len(row) - 1, 2))
                for row in r.stdout.splitlines() if row]
    except Exception:
        return []

def get_secret(ssid):
    rc, out, _ = run_cmd(["nmcli", "-s", "-t", "-f", "802-11-wireless-security.key-mgmt,802-11-wireless-security.psk,802-11-wireless-security.wep-key0", "connection", "show", ssid])
    psk = ""
    sec = "WPA"
    if rc == 0:
        for line in out.splitlines():
            if "802-11-wireless-security.psk:" in line:
                psk = line.partition(":")[2].strip()
            elif "802-11-wireless-security.wep-key0:" in line and not psk:
                psk = line.partition(":")[2].strip()
                sec = "WEP"

    payload = f"WIFI:T:{sec};S:{ssid};P:{psk};;" if psk else f"WIFI:T:nopass;S:{ssid};;"
    rows = qr_rows(payload)
    return {
        "ssid": ssid,
        "psk": psk,
        "security": sec,
        "qr_payload": payload,
        "qr_rows": rows
    }

def set_autoconnect(ssid, enable=True):
    val = "yes" if enable else "no"
    rc, _, err = run_cmd(["nmcli", "connection", "modify", "id", ssid, "connection.autoconnect", val])
    return {"success": (rc == 0), "error": err}

def toggle_radio():
    st = get_status()
    target = "off" if st["radio"] else "on"
    rc, _, _ = run_cmd(["nmcli", "radio", "wifi", target])
    return {"radio": (target == "on")}

def hotspot(action, ssid="LinuxHotspot", password=""):
    if action == "start":
        run_cmd(["nmcli", "radio", "wifi", "on"])
        cmd = ["nmcli", "device", "wifi", "hotspot", "ssid", ssid]
        if password and len(password) >= 8:
            cmd.extend(["password", password])
        rc, out, err = run_cmd(cmd, timeout=15)
        return {"success": (rc == 0), "output": out or err}
    else:
        # Find hotspot connection UUIDs and stop them
        rc, out, _ = run_cmd(["nmcli", "-t", "-f", "UUID,TYPE,NAME", "con", "show", "--active"])
        if rc == 0:
            for line in out.splitlines():
                if ":Hotspot" in line or "hotspot" in line.lower():
                    uuid = line.split(":")[0]
                    run_cmd(["nmcli", "con", "down", "uuid", uuid])
        run_cmd(["nmcli", "con", "down", "Hotspot"])
        return {"success": True}

def disconnect_wired(device=None):
    if not device:
        status = get_status()
        if status.get("ethernet") and status["ethernet"].get("device"):
            device = status["ethernet"]["device"]
    if device:
        rc, out, err = run_cmd(["nmcli", "device", "disconnect", device])
        return {"success": (rc == 0), "output": out or err}
    return {"success": False, "error": "No wired device"}

def connect_wired(device=None):
    if not device:
        status = get_status()
        if status.get("ethernet") and status["ethernet"].get("device"):
            device = status["ethernet"]["device"]
    if device:
        rc, out, err = run_cmd(["nmcli", "device", "connect", device])
        return {"success": (rc == 0), "output": out or err}
    return {"success": False, "error": "No wired device"}

def main():
    action = sys.argv[1] if len(sys.argv) > 1 else "scan"
    
    if action == "status":
        print(json.dumps(get_status()))
    elif action == "scan":
        rescan = (sys.argv[2] != "no") if len(sys.argv) > 2 else True
        print(json.dumps(scan_networks(rescan)))
    elif action == "toggle-radio":
        print(json.dumps(toggle_radio()))
    elif action == "connect" and len(sys.argv) > 2:
        ssid = sys.argv[2]
        password = sys.argv[3] if len(sys.argv) > 3 else None
        print(json.dumps(connect_network(ssid, password)))
    elif action == "disconnect":
        ssid = sys.argv[2] if len(sys.argv) > 2 else None
        print(json.dumps(disconnect_network(ssid)))
    elif action == "disconnect-wired":
        device = sys.argv[2] if len(sys.argv) > 2 else None
        print(json.dumps(disconnect_wired(device)))
    elif action == "connect-wired":
        device = sys.argv[2] if len(sys.argv) > 2 else None
        print(json.dumps(connect_wired(device)))
    elif action == "forget" and len(sys.argv) > 2:
        ssid = sys.argv[2]
        print(json.dumps(forget_network(ssid)))
    elif action == "secret" and len(sys.argv) > 2:
        ssid = sys.argv[2]
        print(json.dumps(get_secret(ssid)))
    elif action == "autoconnect" and len(sys.argv) > 3:
        ssid = sys.argv[2]
        enable = (sys.argv[3].lower() in ("yes", "true", "1"))
        print(json.dumps(set_autoconnect(ssid, enable)))
    elif action == "hotspot" and len(sys.argv) > 2:
        hs_action = sys.argv[2]
        hs_ssid = sys.argv[3] if len(sys.argv) > 3 else "LinuxHotspot"
        hs_pass = sys.argv[4] if len(sys.argv) > 4 else "12345678"
        print(json.dumps(hotspot(hs_action, hs_ssid, hs_pass)))
    else:
        print(json.dumps(scan_networks(False)))

if __name__ == "__main__":
    main()
