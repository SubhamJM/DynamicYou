#!/usr/bin/env python3
import sys
import os
import json
import time
import urllib.parse
from datetime import datetime, timedelta

CALENDAR_FILE = os.path.expanduser("~/.cache/quickshell/calendar_events.json")

def generate_default_events():
    today = datetime.now()
    today_str = today.strftime("%Y-%m-%d")
    tomorrow = today + timedelta(days=1)
    tomorrow_str = tomorrow.strftime("%Y-%m-%d")

    return [
        {
            "id": "evt_default_1",
            "title": "Deep Work & Code Review",
            "date": today_str,
            "startTime": "09:30",
            "endTime": "11:30",
            "allDay": False,
            "category": "work",
            "color": "#7aa2f7",
            "description": "Quickshell notch & system polish"
        },
        {
            "id": "evt_default_2",
            "title": "Team Sync & Architecture",
            "date": today_str,
            "startTime": "14:00",
            "endTime": "14:45",
            "allDay": False,
            "category": "meeting",
            "color": "#bb9af7",
            "description": "Review next sprint roadmap"
        },
        {
            "id": "evt_default_3",
            "title": "Evening Workout & Reset",
            "date": today_str,
            "startTime": "18:00",
            "endTime": "19:00",
            "allDay": False,
            "category": "personal",
            "color": "#9ece6a",
            "description": "Cardio & strength training"
        },
        {
            "id": "evt_default_4",
            "title": "System Backup & Flake Update",
            "date": tomorrow_str,
            "startTime": "11:00",
            "endTime": "12:00",
            "allDay": False,
            "category": "dev",
            "color": "#2ac3de",
            "description": "NixOS generation cleanup & testing"
        },
        {
            "id": "evt_default_5",
            "title": "Weekly Retrospective",
            "date": tomorrow_str,
            "startTime": "16:00",
            "endTime": "17:00",
            "allDay": False,
            "category": "review",
            "color": "#ff9e64",
            "description": "Review goals and progress"
        }
    ]

def ensure_file():
    os.makedirs(os.path.dirname(CALENDAR_FILE), exist_ok=True)
    if not os.path.exists(CALENDAR_FILE):
        events = generate_default_events()
        with open(CALENDAR_FILE, "w", encoding="utf-8") as f:
            json.dump(events, f, indent=2)

def load_events():
    ensure_file()
    try:
        with open(CALENDAR_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
            if isinstance(data, list):
                return data
            return []
    except Exception as e:
        return []

def save_events(events):
    ensure_file()
    try:
        temp_file = CALENDAR_FILE + ".tmp"
        with open(temp_file, "w", encoding="utf-8") as f:
            json.dump(events, f, indent=2)
        os.replace(temp_file, CALENDAR_FILE)
        return True
    except Exception as e:
        print(f"Error saving events: {e}", file=sys.stderr)
        return False

def main():
    if len(sys.argv) < 2:
        print(json.dumps(load_events()))
        return

    cmd = sys.argv[1]

    if cmd == "load":
        print(json.dumps(load_events()))

    elif cmd == "save_enc":
        if len(sys.argv) < 3:
            print("Missing payload", file=sys.stderr)
            sys.exit(1)
        content = urllib.parse.unquote(sys.argv[2])
        try:
            parsed = json.loads(content)
            if isinstance(parsed, list):
                save_events(parsed)
                print(json.dumps(parsed))
            else:
                print("Payload must be a JSON array", file=sys.stderr)
                sys.exit(1)
        except Exception as e:
            print(f"Invalid JSON: {e}", file=sys.stderr)
            sys.exit(1)

    elif cmd == "add_enc":
        if len(sys.argv) < 3:
            print("Missing payload", file=sys.stderr)
            sys.exit(1)
        content = urllib.parse.unquote(sys.argv[2])
        try:
            new_event = json.loads(content)
            if not isinstance(new_event, dict):
                print("Event must be a JSON object", file=sys.stderr)
                sys.exit(1)
            
            if "id" not in new_event or not new_event["id"]:
                new_event["id"] = f"evt_{int(time.time() * 1000)}"
            
            events = load_events()
            events.append(new_event)
            save_events(events)
            print(json.dumps(events))
        except Exception as e:
            print(f"Failed to add event: {e}", file=sys.stderr)
            sys.exit(1)

    elif cmd == "delete":
        if len(sys.argv) < 3:
            print("Missing event id", file=sys.stderr)
            sys.exit(1)
        target_id = sys.argv[2]
        events = load_events()
        events = [e for e in events if str(e.get("id")) != str(target_id)]
        save_events(events)
        print(json.dumps(events))

    else:
        print(f"Unknown command: {cmd}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
