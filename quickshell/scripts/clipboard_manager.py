#!/usr/bin/env python3
import sys
import os
import re
import json
import subprocess
import urllib.parse
import hashlib
import tempfile

CACHE_DIR = os.path.join(os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache"), "dynamic-you")
THUMB_DIR = os.path.join(CACHE_DIR, "clipboard-thumbnails")
THUMB_LIMIT = 64
PINS_FILE = os.path.join(CACHE_DIR, "clipboard_pins.json")

os.makedirs(CACHE_DIR, exist_ok=True)
os.makedirs(THUMB_DIR, mode=0o700, exist_ok=True)

IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp", ".svg", ".gif", ".avif", ".bmp"}

def get_pinned_items():
    if os.path.exists(PINS_FILE):
        try:
            with open(PINS_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
                if isinstance(data, list):
                    return set(data)
        except Exception:
            pass
    return set()

def save_pinned_items(pins_set):
    try:
        with open(PINS_FILE, "w", encoding="utf-8") as f:
            json.dump(list(pins_set), f, indent=2, ensure_ascii=False)
    except OSError as error:
        sys.stderr.write(f"Failed to save pins: {error}\n")
        sys.exit(1)

def cmd_thumbnail(clip_id, descriptor):
    if not clip_id.isascii() or not clip_id.isdecimal():
        return
    key = hashlib.sha256(f"{clip_id}:{descriptor}".encode()).hexdigest()[:20]
    target = os.path.join(THUMB_DIR, f"{key}.png")
    if os.path.isfile(target):
        os.utime(target, None)
        print(target)
        return

    try:
        with tempfile.TemporaryFile(dir=THUMB_DIR) as raw:
            subprocess.run(["cliphist", "decode", clip_id], stdout=raw,
                           stderr=subprocess.DEVNULL, check=True, timeout=2)
            raw.seek(0)
            with tempfile.NamedTemporaryFile(dir=THUMB_DIR, delete=False) as output:
                try:
                    try:
                        from PIL import Image
                        with Image.open(raw) as image:
                            image.thumbnail((104, 104))
                            image.convert("RGBA").save(output, format="PNG")
                    except ImportError:
                        # QML still decodes to the display size when Pillow is unavailable.
                        from shutil import copyfileobj
                        copyfileobj(raw, output)
                    if output.tell() == 0:
                        return
                    output.flush()
                    os.replace(output.name, target)
                finally:
                    if os.path.exists(output.name):
                        os.unlink(output.name)
    except (OSError, ValueError, subprocess.SubprocessError):
        return

    entries = []
    for entry in os.scandir(THUMB_DIR):
        if entry.name.endswith(".png"):
            try:
                entries.append((entry.stat().st_mtime, entry.path))
            except FileNotFoundError:
                pass
    for _, path in sorted(entries, reverse=True)[THUMB_LIMIT:]:
        try:
            os.unlink(path)
        except FileNotFoundError:
            pass
    print(target)


def cmd_scan():
    pinned_items = get_pinned_items()

    try:
        p = subprocess.run(["cliphist", "list"], capture_output=True)
        if p.returncode == 1 and p.stderr.strip() == b"opening db: please store something first":
            print("[]")
            return
        p.check_returncode()
        raw = p.stdout.decode("utf-8", errors="ignore")
    except (OSError, subprocess.SubprocessError) as error:
        sys.stderr.write(f"Could not read clipboard history: {error}\n")
        sys.exit(1)

    lines = [l for l in raw.splitlines() if l.strip()][:140]
    clips = []
    seen_texts = set()

    for line in lines:
        parts = line.split("\t", 1)
        if len(parts) < 2:
            continue
        c_id = parts[0].strip()
        c_desc = parts[1].strip()

        norm = c_desc.strip()
        is_binary_image = c_desc.startswith("[[ binary data")
        if not norm or (not is_binary_image and norm in seen_texts):
            continue
        if not is_binary_image:
            seen_texts.add(norm)

        # Skip incremental typing prefixes of recent items
        if clips and not clips[-1]["isImage"] and not is_binary_image:
            prev_desc = clips[-1]["description"].strip()
            if prev_desc.startswith(norm) and len(prev_desc) > len(norm):
                continue

        img_path = ""
        title = ""
        subtitle = ""
        clip_type = "text"
        icon_name = "notes"

        if is_binary_image:
            clip_type = "image"
            icon_name = "image"
            m = re.search(r"binary data\s+([^\s]+(?:\s+[KMGTPE]?i?B)?)\s+(\w+)\s+(\d+x\d+)", c_desc)
            title = "Image Clip"
            subtitle = f"{m.group(3)} • {m.group(1)}" if m else "Image Preview"
        else:
            # Check for file:// URI or local paths
            is_file_uri = c_desc.startswith("file://")
            clean_path = c_desc
            if is_file_uri:
                clean_path = urllib.parse.unquote(clean_path[7:])

            ext = os.path.splitext(clean_path)[1].lower() if clean_path else ""

            if is_file_uri or (clean_path.startswith("/") and not "\n" in clean_path and (os.path.exists(clean_path) or "/" in clean_path)):
                bname = os.path.basename(clean_path)
                dname = os.path.dirname(clean_path).replace(os.path.expanduser("~"), "~")
                if ext in IMAGE_EXTENSIONS and os.path.exists(clean_path):
                    clip_type = "image"
                    icon_name = "image"
                    title = bname
                    subtitle = dname
                    img_path = clean_path
                else:
                    clip_type = "file"
                    icon_name = "folder_open" if os.path.isdir(clean_path) else "description"
                    title = bname if bname else clean_path
                    subtitle = dname
            elif re.match(r"^#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$", norm):
                clip_type = "color"
                icon_name = "palette"
                title = norm
                subtitle = ""
            elif re.match(r"^https?://", norm):
                clip_type = "url"
                icon_name = "link"
                title = norm
                domain_m = re.search(r"^https?://([^/]+)", norm)
                subtitle = domain_m.group(1) if domain_m else ""
            elif (norm.startswith("{") and norm.endswith("}")) or (norm.startswith("[") and norm.endswith("]")):
                clip_type = "code"
                icon_name = "data_object"
                title = norm.replace("\n", " ").strip()
                subtitle = ""
            elif any(norm.startswith(cmd) for cmd in ("sudo ", "git ", "pacman ", "yay ", "curl ", "wget ", "systemctl ", "cargo ", "npm ", "docker ", "kill ", "mv ", "cp ", "ssh ", "echo ", "cat ", "nvim ", "nano ", "ls ")):
                clip_type = "cmd"
                icon_name = "terminal"
                title = norm.replace("\n", " ").strip()
                subtitle = ""
            elif any(kw in norm for kw in ("function ", "const ", "let ", "import ", "export ", "class ", "def ", "return ", "#include", "int ", "void ", "public:", "namespace ")):
                clip_type = "code"
                icon_name = "code"
                title = norm.replace("\n", " ").strip()
                subtitle = ""
            else:
                clip_type = "text"
                icon_name = "notes"
                lines_list = c_desc.splitlines()
                title = lines_list[0].strip() if lines_list else norm
                subtitle = f"{len(lines_list)} lines" if len(lines_list) > 1 else ""

        is_pinned = (c_desc in pinned_items) or (c_id in pinned_items)

        clips.append({
            "clipId": c_id,
            "type": clip_type,
            "icon": icon_name,
            "isImage": (clip_type == "image"),
            "imgPath": img_path,
            "title": title,
            "subtitle": subtitle,
            "description": c_desc,
            "isPinned": is_pinned,
            "binary": is_binary_image
        })

    clips.sort(key=lambda x: 0 if x["isPinned"] else 1)
    print(json.dumps(clips))

def cmd_delete(clip_id):
    result = subprocess.run(["cliphist", "list"], stdout=subprocess.PIPE, check=True)
    for line in result.stdout.splitlines():
        if line.startswith(clip_id.encode() + b"\t"):
            subprocess.run(["cliphist", "delete"], input=line, check=True)
            break

def cmd_pin(c_id, c_desc):
    pinned = get_pinned_items()
    target = c_id if c_desc.startswith("[[ binary data") else (c_desc or c_id)
    if target in pinned or c_id in pinned or c_desc in pinned:
        pinned.discard(target)
        pinned.discard(c_id)
        pinned.discard(c_desc)
    else:
        pinned.add(target)
    save_pinned_items(pinned)

def cmd_wipe():
    subprocess.run(["cliphist", "wipe"], check=True)
    try:
        for f in os.listdir(THUMB_DIR):
            fp = os.path.join(THUMB_DIR, f)
            if os.path.isfile(fp):
                os.remove(fp)
    except Exception:
        pass

if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] == "scan":
        cmd_scan()
    elif sys.argv[1] == "thumbnail" and len(sys.argv) >= 4:
        cmd_thumbnail(sys.argv[2], sys.argv[3])
    elif sys.argv[1] == "delete" and len(sys.argv) >= 3:
        cmd_delete(sys.argv[2])
    elif sys.argv[1] == "pin" and len(sys.argv) >= 3:
        desc = sys.argv[3] if len(sys.argv) >= 4 else ""
        cmd_pin(sys.argv[2], desc)
    elif sys.argv[1] == "wipe":
        cmd_wipe()
