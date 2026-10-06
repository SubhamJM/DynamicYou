#!/usr/bin/env python3
import sys
import os
import json
import time
import urllib.parse

NOTES_FILE = os.path.expanduser("~/.cache/quickshell/notes.json")

def ensure_file():
    os.makedirs(os.path.dirname(NOTES_FILE), exist_ok=True)
    if not os.path.exists(NOTES_FILE):
        default_data = {
            "notes": [
                {
                    "id": "tasks",
                    "type": "tasks",
                    "title": "Tasks & Projects",
                    "content": "- [ ] Add your first task here",
                    "todos": [],
                    "updated_at": int(time.time())
                },
                {
                    "id": "scratchpad",
                    "type": "note",
                    "title": "Scratchpad",
                    "content": "# Scratchpad\n\nJot down quick thoughts, code snippets, or ideas here.\nSupports markdown formatting and auto-saves in real time.",
                    "todos": [],
                    "updated_at": int(time.time())
                }
            ],
            "activeNoteId": "tasks",
            "scratchpad": "",
            "todos": []
        }
        with open(NOTES_FILE, "w", encoding="utf-8") as f:
            json.dump(default_data, f, indent=2)

def migrate_data(data):
    if not isinstance(data, dict):
        data = {}
    if "notes" not in data or not isinstance(data["notes"], list) or len(data["notes"]) == 0:
        notes = []
        existing_todos = data.get("todos", [])
        if not isinstance(existing_todos, list):
            existing_todos = []

        task_lines = []
        for t in existing_todos:
            marker = "x" if t.get("done") else " "
            task_lines.append("- [" + marker + "] " + t.get("text", ""))

        tasks_content = "\n".join(task_lines) if task_lines else "- [ ] Add your first task here"

        notes.append({
            "id": "tasks",
            "type": "tasks",
            "title": "Tasks & Projects",
            "content": tasks_content,
            "todos": existing_todos,
            "updated_at": int(time.time())
        })

        scratch = data.get("scratchpad", "")
        if not scratch or scratch.strip() == ".,":
            scratch = "# Scratchpad\n\nJot down quick thoughts, code snippets, or ideas here.\nSupports markdown formatting and auto-saves in real time."

        notes.append({
            "id": "scratchpad",
            "type": "note",
            "title": "Scratchpad",
            "content": scratch,
            "todos": [],
            "updated_at": int(time.time()) - 60
        })

        data["notes"] = notes
        data["activeNoteId"] = "tasks"
        save_data(data)
    return data

def load_data():
    ensure_file()
    try:
        with open(NOTES_FILE, "r", encoding="utf-8") as f:
            raw = json.load(f)
            return migrate_data(raw)
    except Exception as e:
        return migrate_data({})

def save_data(data):
    ensure_file()
    try:
        # Keep backward compatibility sync
        if "notes" in data and isinstance(data["notes"], list):
            for n in data["notes"]:
                if n.get("type") == "tasks" or n.get("id") == "tasks":
                    data["todos"] = n.get("todos", [])
                if n.get("type") == "note" or n.get("id") == "scratchpad":
                    data["scratchpad"] = n.get("content", "")

        temp_file = NOTES_FILE + ".tmp"
        with open(temp_file, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
        os.replace(temp_file, NOTES_FILE)
        return True
    except Exception as e:
        print(f"Error saving notes: {e}", file=sys.stderr)
        return False

def main():
    if len(sys.argv) < 2:
        print(json.dumps(load_data()))
        return

    cmd = sys.argv[1]

    if cmd == "load":
        print(json.dumps(load_data()))

    elif cmd in ("save_notes_enc", "save_all_enc"):
        content = urllib.parse.unquote(sys.argv[2])
        try:
            parsed = json.loads(content)
            data = load_data()
            if isinstance(parsed, list):
                data["notes"] = parsed
            elif isinstance(parsed, dict):
                data.update(parsed)
            save_data(data)
            print("OK")
        except Exception as e:
            print(f"Invalid JSON: {e}", file=sys.stderr)
            sys.exit(1)

    elif cmd in ("save_scratchpad_b64", "save_scratchpad_enc"):
        content = urllib.parse.unquote(sys.argv[2])
        data = load_data()
        data["scratchpad"] = content
        # Sync to scratchpad or active note
        active_id = data.get("activeNoteId", "scratchpad")
        for n in data.get("notes", []):
            if n.get("id") == active_id or n.get("id") == "scratchpad":
                n["content"] = content
                n["updated_at"] = int(time.time())
                break
        save_data(data)
        print("OK")

    elif cmd in ("save_todos_b64", "save_todos_enc"):
        content = urllib.parse.unquote(sys.argv[2])
        data = load_data()
        try:
            todos_list = json.loads(content)
            data["todos"] = todos_list
            for n in data.get("notes", []):
                if n.get("type") == "tasks" or n.get("id") == "tasks":
                    n["todos"] = todos_list
                    lines = ["- [" + ("x" if t.get("done") else " ") + "] " + t.get("text", "") for t in todos_list]
                    n["content"] = "\n".join(lines)
                    n["updated_at"] = int(time.time())
                    break
            save_data(data)
            print("OK")
        except Exception as e:
            print(f"Invalid JSON: {e}", file=sys.stderr)
            sys.exit(1)

    elif cmd in ("export_txt", "export_md"):
        filepath = os.path.expanduser(sys.argv[2])
        content = urllib.parse.unquote(sys.argv[3])
        try:
            os.makedirs(os.path.dirname(os.path.abspath(filepath)), exist_ok=True)
            with open(filepath, "w", encoding="utf-8") as f:
                f.write(content)
            print("OK:" + filepath)
        except Exception as e:
            print(f"Error exporting file: {e}", file=sys.stderr)
            sys.exit(1)

    else:
        print(f"Unknown command: {cmd}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
