"""Read a saved Wi-Fi profile and encode its sharing QR code on demand."""

import json
import subprocess
import sys


def nmcli(args):
    try:
        r = subprocess.run(["nmcli"] + args, capture_output=True, text=True,
                           timeout=8)
    except (OSError, subprocess.SubprocessError):
        return ""
    return r.stdout if r.returncode == 0 else ""


def unescape(s):
    out, esc = [], False
    for ch in s:
        if esc:
            out.append(ch)
            esc = False
        elif ch == "\\":
            esc = True
        else:
            out.append(ch)
    return "".join(out)


def split_row(line):
    """nmcli -t rows are colon separated with backslash-escaped colons."""
    fields, cur, esc = [], [], False
    for ch in line:
        if esc:
            cur.append(ch)
            esc = False
        elif ch == "\\":
            esc = True
        elif ch == ":":
            fields.append("".join(cur))
            cur = []
        else:
            cur.append(ch)
    fields.append("".join(cur))
    return fields


def qr_rows(payload):
    """The QR code of payload as rows of 0/1, or [] without qrencode.

    The payload goes in on stdin: on the command line the password would sit
    in /proc for anyone to read while qrencode runs."""
    try:
        r = subprocess.run(["qrencode", "-t", "ASCII", "-m", "0", "-l", "M"],
                           input=payload, capture_output=True, text=True,
                           timeout=8)
    except (OSError, subprocess.SubprocessError):
        return []
    if r.returncode != 0:
        return []
    # two characters per module, "##" dark and "  " light
    return ["".join("1" if row[i] == "#" else "0"
                    for i in range(0, len(row) - 1, 2))
            for row in r.stdout.splitlines() if row]


def qr_escape(s):
    for ch in '\\;,:"':
        s = s.replace(ch, "\\" + ch)
    return s


def wifi_secret(ssid):
    """The saved profile of one Wi-Fi network, password included, as the
    Share view needs it. Only runs when someone asks to share."""
    out = {"ssid": ssid, "found": False, "security": "", "hidden": False,
           "psk": "", "agentOwned": False, "qr": []}
    rows = [split_row(line) for line in nmcli(
        ["-t", "-f", "NAME,UUID,TYPE,ACTIVE", "connection", "show"]).splitlines()]
    # the active profile first, then one named like the network, which is
    # how NetworkManager names them unless someone renamed it
    wifi = [r for r in rows if len(r) >= 4 and r[2] == "802-11-wireless"]
    wifi.sort(key=lambda r: (r[3] != "yes", r[0] != ssid))
    fields = ("802-11-wireless.ssid,802-11-wireless.hidden,"
              "802-11-wireless-security.key-mgmt,802-11-wireless-security.psk,"
              "802-11-wireless-security.psk-flags,"
              "802-11-wireless-security.wep-key0")
    for r in wifi:
        line = nmcli(["-t", "-f", "802-11-wireless.ssid", "connection", "show",
                      r[1]]).rstrip("\n")
        if unescape(line.partition(":")[2]) != ssid:
            continue
        d = {}
        for line in nmcli(["-s", "-t", "-f", fields, "connection", "show",
                           r[1]]).splitlines():
            key, _, value = line.partition(":")
            d[key] = unescape(value)
        mgmt = d.get("802-11-wireless-security.key-mgmt", "").strip()
        wep = d.get("802-11-wireless-security.wep-key0", "")
        out["found"] = True
        out["hidden"] = d.get("802-11-wireless.hidden", "").strip() == "yes"
        if mgmt in ("wpa-psk", "sae"):
            out["security"] = "WPA"
            out["psk"] = d.get("802-11-wireless-security.psk", "")
        elif mgmt == "none" and wep:
            out["security"] = "WEP"
            out["psk"] = wep
        elif mgmt in ("", "owe"):
            out["security"] = "nopass"
        else:
            # 802.1X: a login, not a password a phone can scan
            out["security"] = "enterprise"
        # "1 (agent-owned)": the password lives in a keyring, not with NM
        flags = d.get("802-11-wireless-security.psk-flags", "")
        out["agentOwned"] = flags[:1].isdigit() and int(flags.split()[0]) & 1 == 1
        break
    if not out["found"] or out["security"] == "enterprise":
        return out
    if out["security"] != "nopass" and not out["psk"]:
        return out
    payload = "WIFI:T:%s;S:%s;" % (out["security"], qr_escape(ssid))
    if out["security"] != "nopass":
        payload += "P:%s;" % qr_escape(out["psk"])
    if out["hidden"]:
        payload += "H:true;"
    out["qr"] = qr_rows(payload + ";")
    return out


if __name__ == "__main__":
    print(json.dumps(wifi_secret(sys.argv[1])))
