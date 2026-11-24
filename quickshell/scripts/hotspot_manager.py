#!/usr/bin/env python3
"""Manage the Dynamic You Hotspot profile with NetworkManager."""

import fcntl
import getpass
import json
import os
from pathlib import Path
import re
import secrets
import shutil
import subprocess
import sys
import tempfile


HOME = Path.home()
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME") or HOME / ".config") / "quickshell/hotspot.json"
STATE = Path(os.environ.get("XDG_STATE_HOME") or HOME / ".local/state") / "dynamic-you"
NAME = "Hotspot"


def nmcli(*args, check=True, timeout=5):
    if not shutil.which("nmcli"):
        raise RuntimeError("NetworkManager is required for hotspot sharing.")
    result = subprocess.run(
        ["nmcli", *args], capture_output=True, text=True, timeout=timeout,
        env={**os.environ, "LC_ALL": "C"},
    )
    if check and result.returncode:
        message = result.stderr.strip() or "NetworkManager couldn't update the hotspot."
        raise RuntimeError(message)
    return result


def profile_uuid():
    result = nmcli("-g", "connection.uuid,802-11-wireless.mode", "connection", "show", "id", NAME, check=False)
    if result.returncode == 10:
        return None
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or "Couldn’t read the hotspot profile.")
    uuid, *mode = result.stdout.splitlines() or [""]
    if mode != ["ap"]:
        raise RuntimeError("A NetworkManager connection named Hotspot already exists in client mode.")
    return uuid


def active_interface(uuid):
    if not uuid:
        return None
    output = nmcli("-t", "-f", "UUID,DEVICE", "connection", "show", "--active").stdout
    for line in output.splitlines():
        connection, _, device = line.partition(":")
        if connection == uuid:
            return device or None
    return None


def wifi_interface():
    output = nmcli("-t", "-f", "DEVICE,TYPE,STATE", "device", "status").stdout
    for line in output.splitlines():
        device, _, rest = line.partition(":")
        kind, _, state = rest.partition(":")
        if kind == "wifi" and state not in ("unavailable", "unmanaged"):
            capability = nmcli("-g", "WIFI-PROPERTIES.AP", "device", "show", device, check=False)
            if capability.stdout.strip() == "yes":
                return device
    raise RuntimeError("No available Wi-Fi adapter supports hotspot mode.")


def clients(interface):
    if not interface or not shutil.which("iw"):
        return None
    try:
        result = subprocess.run(
            ["iw", "dev", interface, "station", "dump"], capture_output=True, text=True, timeout=2,
        )
        if result.returncode == 0:
            return sum(line.startswith("Station ") for line in result.stdout.splitlines())
    except (OSError, subprocess.TimeoutExpired):
        pass
    return None


def save_config(ssid, password):
    CONFIG.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w", dir=CONFIG.parent, delete=False, encoding="utf-8") as file:
        temporary = Path(file.name)
        try:
            json.dump({"ssid": ssid, "password": password}, file)
            file.flush()
            temporary.replace(CONFIG)
        finally:
            temporary.unlink(missing_ok=True)


def load_config(uuid):
    if CONFIG.is_file():
        data = json.loads(CONFIG.read_text(encoding="utf-8"))
        if isinstance(data, dict):
            try:
                return validate(str(data.get("ssid", "")), str(data.get("password", "")))
            except ValueError:
                pass

    name = getpass.getuser().capitalize()
    ssid = name.encode("utf-8")[:24].decode("utf-8", errors="ignore") + "-Hotspot"
    password = secrets.token_urlsafe(12)
    if uuid:
        def existing(setting):
            return nmcli("-s", "-g", setting, "connection", "show", "uuid", uuid, check=False).stdout.rstrip("\n")

        ssid = existing("802-11-wireless.ssid") or ssid
        saved_password = existing("802-11-wireless-security.psk")
        if saved_password:
            password = saved_password
    save_config(ssid, password)
    return ssid, password


def validate(ssid, password):
    ssid = ssid.strip()
    if not ssid or len(ssid.encode("utf-8")) > 32 or any(ord(char) < 32 for char in ssid):
        raise ValueError("Enter a hotspot name of 1–32 bytes.")
    if not (re.fullmatch(r"[ -~]{8,63}", password) or re.fullmatch(r"[0-9a-fA-F]{64}", password)):
        raise ValueError("Use 8–63 printable ASCII characters or a 64-digit hexadecimal key.")
    return ssid, password


def update_credentials(uuid, ssid, password):
    nmcli("connection", "modify", "uuid", uuid,
          "802-11-wireless.ssid", ssid, "802-11-wireless-security.psk", password)


def start(uuid, ssid, password):
    if not shutil.which("dnsmasq"):
        raise RuntimeError("Install dnsmasq to share a connection through the hotspot.")
    nmcli("radio", "wifi", "on")
    device = active_interface(uuid) or wifi_interface()
    if uuid is None:
        nmcli(
            "connection", "add", "type", "wifi", "ifname", device,
            "con-name", NAME, "autoconnect", "no", "ssid", ssid,
            "802-11-wireless.mode", "ap",
        )
        uuid = profile_uuid()
        if uuid is None:
            raise RuntimeError("NetworkManager could not create the hotspot profile.")
    nmcli(
        "connection", "modify", "uuid", uuid,
        "connection.interface-name", device,
        "802-11-wireless.ssid", ssid,
        "802-11-wireless.mode", "ap",
        "802-11-wireless.band", "bg",
        "802-11-wireless-security.key-mgmt", "wpa-psk",
        "802-11-wireless-security.proto", "rsn",
        "802-11-wireless-security.pairwise", "ccmp",
        "802-11-wireless-security.group", "ccmp",
        "802-11-wireless-security.pmf", "1",
        "802-11-wireless-security.psk", password,
        "ipv4.method", "shared",
        "ipv6.method", "ignore",
    )
    nmcli("--wait", "12", "connection", "up", "uuid", uuid, timeout=15)
    save_config(ssid, password)
    return uuid


def run(action, provided):
    uuid = profile_uuid()
    interface = active_interface(uuid)
    ssid, password = validate(*provided) if provided is not None else load_config(uuid)
    if action == "toggle":
        action = "stop" if interface else "start"
    if action == "set-config":
        if uuid:
            update_credentials(uuid, ssid, password)
        save_config(ssid, password)
    elif action == "start":
        uuid = start(uuid, ssid, password)
        interface = active_interface(uuid)
    elif action == "stop" and interface:
        nmcli("connection", "down", "uuid", uuid)
        interface = active_interface(uuid)
    return {
        "success": True, "ssid": ssid, "password": password,
        "active": bool(interface), "clients": clients(interface),
        "dnsmasq_installed": bool(shutil.which("dnsmasq")),
    }


def main():
    args = sys.argv[1:]
    action = args.pop(0) if args else "status"
    provided = None
    try:
        if action not in ("status", "get", "config", "set-config", "start", "stop", "toggle"):
            raise ValueError("Unknown hotspot command.")
        if args == ["--stdin"]:
            credentials = json.loads(sys.stdin.readline())
            provided = (credentials["ssid"], credentials["password"])
        elif len(args) == 2:
            provided = tuple(args)
        elif args or action == "set-config":
            raise ValueError("Set both a hotspot name and a password.")
        STATE.mkdir(parents=True, exist_ok=True)
        with (STATE / ".hotspot.lock").open("a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            result = run(action, provided)
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired, TypeError, KeyError) as error:
        message = str(error)
        if isinstance(error, subprocess.TimeoutExpired):
            message = "NetworkManager took too long to respond."
        if provided and isinstance(provided[1], str) and provided[1]:
            message = message.replace(provided[1], "••••")
        print(json.dumps({"success": False, "message": message}))
        return 1
    print(json.dumps(result))
    return 0


if __name__ == "__main__":
    sys.exit(main())
