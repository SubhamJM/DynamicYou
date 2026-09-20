#!/usr/bin/env python3
import sys
import os
import json
import shutil
import subprocess

CONFIG_DIR = os.path.expanduser("~/.config/quickshell")
DEFAULT_VPN_FILE = os.path.join(CONFIG_DIR, "default_vpn")

def get_default_vpn():
    try:
        if os.path.exists(DEFAULT_VPN_FILE):
            with open(DEFAULT_VPN_FILE, "r") as f:
                val = f.read().strip()
                if val:
                    return val
    except Exception:
        pass
    return "warp"

def set_default_vpn(provider_id):
    try:
        os.makedirs(CONFIG_DIR, exist_ok=True)
        with open(DEFAULT_VPN_FILE, "w") as f:
            f.write(provider_id.strip())
    except Exception:
        pass

def is_iface_up(iface_name):
    path = f"/sys/class/net/{iface_name}/operstate"
    if os.path.exists(path):
        try:
            with open(path, "r") as f:
                state = f.read().strip().lower()
                return state in ("up", "unknown")
        except Exception:
            return True
    return False

def get_nm_vpn_connections():
    conns = []
    if not shutil.which("nmcli"):
        return conns
    try:
        out = subprocess.check_output(
            ["nmcli", "-t", "-f", "NAME,TYPE,STATE", "connection", "show"],
            text=True, stderr=subprocess.DEVNULL, timeout=2
        )
        for line in out.splitlines():
            parts = line.strip().split(":")
            if len(parts) >= 2:
                name = parts[0]
                ctype = parts[1]
                state = parts[2] if len(parts) >= 3 else ""
                if ctype in ("vpn", "wireguard"):
                    conns.append({
                        "name": name,
                        "type": ctype,
                        "active": (state == "activated")
                    })
    except Exception:
        pass
    return conns

def get_status():
    default_id = get_default_vpn()
    providers = []
    active_id = "none"
    active_name = "Disconnected"

    # 1. Cloudflare WARP (Default zero-setup option)
    warp_installed = shutil.which("warp-cli") is not None
    warp_active = False
    warp_connecting = False
    if warp_installed:
        if is_iface_up("CloudflareWARP"):
            warp_active = True
        else:
            try:
                out = subprocess.check_output(
                    ["warp-cli", "--accept-tos", "--json", "status"],
                    text=True, stderr=subprocess.DEVNULL, timeout=1.5
                )
                data = json.loads(out)
                st = str(data.get("status", "")).lower()
                if st == "connected":
                    warp_active = True
                elif st == "connecting":
                    warp_connecting = True
            except Exception:
                pass

    if warp_active:
        active_id = "warp"
        active_name = "Cloudflare WARP"
    elif warp_connecting:
        active_id = "warp"
        active_name = "Connecting..."

    providers.append({
        "id": "warp",
        "name": "Cloudflare WARP",
        "subtitle": "Connecting..." if warp_connecting else "Zero-Setup • 1.1.1.1 Anycast Privacy",
        "icon": "shield",
        "installed": warp_installed,
        "active": warp_active,
        "connecting": warp_connecting,
        "is_default": (default_id == "warp")
    })

    # 2. Tailscale Mesh VPN
    ts_installed = shutil.which("tailscale") is not None
    ts_active = is_iface_up("tailscale0")
    if ts_active and active_id == "none":
        active_id = "tailscale"
        active_name = "Tailscale"
    providers.append({
        "id": "tailscale",
        "name": "Tailscale",
        "subtitle": "Mesh Network (tailscale0)",
        "icon": "hub",
        "installed": ts_installed,
        "active": ts_active,
        "connecting": False,
        "is_default": (default_id == "tailscale")
    })

    # 3. Kernel WireGuard (wg0)
    wg_installed = shutil.which("wg-quick") is not None
    wg_active = is_iface_up("wg0")
    if wg_active and active_id == "none":
        active_id = "wireguard"
        active_name = "WireGuard (wg0)"
    providers.append({
        "id": "wireguard",
        "name": "WireGuard (wg0)",
        "subtitle": "Fast Kernel Tunnel",
        "icon": "lock",
        "installed": wg_installed,
        "active": wg_active,
        "connecting": False,
        "is_default": (default_id == "wireguard")
    })

    # 4. NetworkManager VPN Profiles
    nm_conns = get_nm_vpn_connections()
    for c in nm_conns:
        cid = f"nm:{c['name']}"
        c_active = c["active"]
        if c_active and active_id == "none":
            active_id = cid
            active_name = c["name"]
        providers.append({
            "id": cid,
            "name": c["name"],
            "subtitle": f"NetworkManager {c['type'].upper()}",
            "icon": "vpn_key",
            "installed": True,
            "active": c_active,
            "connecting": False,
            "is_default": (default_id == cid)
        })

    connected = (active_id != "none" and not warp_connecting)
    connecting = warp_connecting
    return {
        "connected": connected,
        "connecting": connecting,
        "active_id": active_id,
        "active_name": "Connecting..." if connecting else (active_name if connected else "Disconnected"),
        "default_id": default_id,
        "providers": providers
    }

def connect_provider(pid):
    set_default_vpn(pid)
    if pid == "warp":
        subprocess.run(["sh", "-c", "warp-cli --accept-tos registration new 2>/dev/null; warp-cli --accept-tos connect"], stderr=subprocess.DEVNULL)
    elif pid == "tailscale":
        subprocess.run(["tailscale", "up"], stderr=subprocess.DEVNULL)
    elif pid == "wireguard":
        subprocess.run(["wg-quick", "up", "wg0"], stderr=subprocess.DEVNULL)
    elif pid.startswith("nm:"):
        cname = pid[3:]
        subprocess.run(["nmcli", "connection", "up", cname], stderr=subprocess.DEVNULL)

def disconnect_all():
    if shutil.which("warp-cli"):
        subprocess.run(["warp-cli", "--accept-tos", "disconnect"], stderr=subprocess.DEVNULL)
    if is_iface_up("tailscale0"):
        subprocess.run(["tailscale", "down"], stderr=subprocess.DEVNULL)
    if is_iface_up("wg0"):
        subprocess.run(["wg-quick", "down", "wg0"], stderr=subprocess.DEVNULL)
    nm_conns = get_nm_vpn_connections()
    for c in nm_conns:
        if c["active"]:
            subprocess.run(["nmcli", "connection", "down", c["name"]], stderr=subprocess.DEVNULL)

def disconnect_provider(pid):
    if pid == "warp":
        subprocess.run(["warp-cli", "--accept-tos", "disconnect"], stderr=subprocess.DEVNULL)
    elif pid == "tailscale":
        subprocess.run(["tailscale", "down"], stderr=subprocess.DEVNULL)
    elif pid == "wireguard":
        subprocess.run(["wg-quick", "down", "wg0"], stderr=subprocess.DEVNULL)
    elif pid.startswith("nm:"):
        cname = pid[3:]
        subprocess.run(["nmcli", "connection", "down", cname], stderr=subprocess.DEVNULL)

def toggle_provider(pid=None):
    status = get_status()
    if not pid:
        if status.get("connected") or status.get("connecting"):
            disconnect_all()
        else:
            target = status["default_id"]
            connect_provider(target)
    else:
        target_running = False
        for p in status["providers"]:
            if p["id"] == pid and (p.get("active") or p.get("connecting")):
                target_running = True
                break
        if target_running:
            disconnect_provider(pid)
        else:
            disconnect_all()
            connect_provider(pid)

if __name__ == "__main__":
    if len(sys.argv) > 1:
        cmd = sys.argv[1]
        if cmd == "toggle":
            pid = sys.argv[2] if len(sys.argv) > 2 else None
            toggle_provider(pid)
        elif cmd == "connect" and len(sys.argv) > 2:
            connect_provider(sys.argv[2])
        elif cmd == "disconnect":
            if len(sys.argv) > 2:
                disconnect_provider(sys.argv[2])
            else:
                disconnect_all()
        elif cmd == "set-default" and len(sys.argv) > 2:
            set_default_vpn(sys.argv[2])
        else:
            print(json.dumps(get_status()))
    else:
        print(json.dumps(get_status()))
