#!/usr/bin/env python3
import sys
import os
import json

CONFIG_DIR = os.path.expanduser("~/.config/quickshell")
CONFIG_FILE = os.path.join(CONFIG_DIR, "utilities.json")

DEFAULT_ENABLED = [
    "screenshot",
    "ocr",
    "colorpicker",
    "record",
    "caffeine",
    "nightlight",
    "mic_mute",
    "dnd",
    "shelf",
    "qr",
    "pomo",
    "notes"
]

def ensure_file():
    os.makedirs(CONFIG_DIR, exist_ok=True)
    if not os.path.exists(CONFIG_FILE):
        with open(CONFIG_FILE, "w", encoding="utf-8") as f:
            json.dump({"enabled": DEFAULT_ENABLED}, f, indent=2)

def load_data():
    ensure_file()
    try:
        with open(CONFIG_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
            if isinstance(data, dict) and "enabled" in data and isinstance(data["enabled"], list):
                return data
            elif isinstance(data, list):
                return {"enabled": data}
    except Exception as e:
        sys.stderr.write(f"Error reading utilities config: {e}\n")
    return {"enabled": DEFAULT_ENABLED}

def save_data(enabled_list):
    ensure_file()
    try:
        temp_file = CONFIG_FILE + ".tmp"
        with open(temp_file, "w", encoding="utf-8") as f:
            json.dump({"enabled": enabled_list}, f, indent=2)
        os.replace(temp_file, CONFIG_FILE)
        return True
    except Exception as e:
        sys.stderr.write(f"Error saving utilities config: {e}\n")
        return False

def main():
    if len(sys.argv) < 2 or sys.argv[1] == "load":
        print(json.dumps(load_data()))
        return

    cmd = sys.argv[1]
    if cmd == "save" and len(sys.argv) >= 3:
        try:
            raw = sys.argv[2]
            parsed = json.loads(raw)
            if isinstance(parsed, dict) and "enabled" in parsed:
                enabled_list = parsed["enabled"]
            elif isinstance(parsed, list):
                enabled_list = parsed
            else:
                enabled_list = DEFAULT_ENABLED
            if save_data(enabled_list):
                print(json.dumps({"status": "ok", "enabled": enabled_list}))
            else:
                print(json.dumps({"status": "error"}))
        except Exception as e:
            sys.stderr.write(f"Invalid JSON provided: {e}\n")
            print(json.dumps({"status": "error", "message": str(e)}))
    elif cmd == "reset":
        save_data(DEFAULT_ENABLED)
        print(json.dumps({"status": "ok", "enabled": DEFAULT_ENABLED}))
    else:
        print(json.dumps(load_data()))

if __name__ == "__main__":
    main()
