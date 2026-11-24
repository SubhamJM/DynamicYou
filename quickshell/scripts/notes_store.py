#!/usr/bin/env python3
"""Store the Dynamic You scratchpad and checklist."""

import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import urllib.parse


NOTES_FILE = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "quickshell/notes.json"


def load():
    if not NOTES_FILE.exists():
        return {"scratchpad": "", "todos": [], "notes": [], "activeNoteId": "tasks"}
    data = json.loads(NOTES_FILE.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError("Expected a notes object")
    return normalize(data)


def normalize(data):
    entries = data.get("notes", [])
    if not isinstance(entries, list):
        entries = []
    data["notes"] = entries
    for identifier, field, kind, default in (
        ("scratchpad", "scratchpad", str, ""),
        ("tasks", "todos", list, []),
    ):
        record = next((note for note in entries if isinstance(note, dict) and note.get("id") == identifier), {})
        legacy = record.get("content" if identifier == "scratchpad" else "todos")
        if not isinstance(data.get(field), kind):
            data[field] = legacy if isinstance(legacy, kind) else default
    return data


def save(data):
    data = normalize(data)
    for ident, role, title in (("scratchpad", "note", "Scratchpad"), ("tasks", "tasks", "Tasks & Projects")):
        entry = next((note for note in data["notes"] if isinstance(note, dict) and note.get("id") == ident), None)
        if entry is None:
            entry = {"id": ident, "type": role, "title": title, "todos": []}
            data["notes"].append(entry)
        if ident == "scratchpad":
            entry["content"] = data["scratchpad"]
        else:
            entry["todos"] = data["todos"]
            entry["content"] = "\n".join(
                f"- [{'x' if task.get('done') else ' '}] {task.get('text', '')}" for task in data["todos"]
            )
        entry["updated_at"] = int(time.time())
    data.setdefault("activeNoteId", "tasks")
    write_atomic(NOTES_FILE, json.dumps(data, ensure_ascii=False, indent=2))


def write_atomic(target, content):
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=target.parent, delete=False) as stream:
        path = Path(stream.name)
        try:
            stream.write(content)
            stream.flush()
            path.replace(target)
        finally:
            path.unlink(missing_ok=True)


def export(path, content):
    target = Path(path).expanduser()
    target.parent.mkdir(parents=True, exist_ok=True)
    write_atomic(target.resolve(), content)
    print("OK:" + str(target))


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else "load"
    if action in ("export_txt", "export_md"):
        export(sys.argv[2], urllib.parse.unquote(sys.argv[3]))
        return
    if action in ("export-stdin", "copy-stdin"):
        payload = json.loads(sys.stdin.readline())
        if action == "export-stdin":
            export(payload["path"], payload["text"])
        else:
            subprocess.run(["wl-copy", "--type", "text/plain"], input=payload["text"].encode(), check=True)
        return

    NOTES_FILE.parent.mkdir(parents=True, exist_ok=True)
    with NOTES_FILE.with_suffix(".lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        data = load()
        if action == "load":
            print(json.dumps(data))
            return
        if action == "save-stdin":
            payload = json.loads(sys.stdin.readline())
            if not isinstance(payload["scratchpad"], str) or not isinstance(payload["todos"], list):
                raise ValueError("Invalid notes snapshot")
            data.update(scratchpad=payload["scratchpad"], todos=payload["todos"])
        elif action in ("save_scratchpad_enc", "save_scratchpad_b64"):
            data["scratchpad"] = urllib.parse.unquote(sys.argv[2])
        elif action in ("save_todos_enc", "save_todos_b64"):
            data["todos"] = json.loads(urllib.parse.unquote(sys.argv[2]))
        elif action in ("save_notes_enc", "save_all_enc"):
            payload = json.loads(urllib.parse.unquote(sys.argv[2]))
            if isinstance(payload, list):
                data = {key: value for key, value in data.items() if key not in ("scratchpad", "todos")}
                data["notes"] = payload
            elif isinstance(payload, dict):
                data.update(payload)
            else:
                raise ValueError("Invalid notes data")
        else:
            raise ValueError("Unknown notes command")
        save(data)
        print("OK")


if __name__ == "__main__":
    try:
        main()
    except (OSError, KeyError, IndexError, TypeError, ValueError, subprocess.SubprocessError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
