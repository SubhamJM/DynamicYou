#!/usr/bin/env python3
import os
import sys
import json
import glob
import subprocess

def get_active_wallpaper():
    active = ""
    we_state = os.path.expanduser("~/.config/active-wallpaper-engine")
    if os.path.isfile(we_state):
        try:
            with open(we_state, "r") as f:
                val = f.read().strip()
                if val:
                    active = val
        except Exception:
            pass

    if not active:
        try:
            p = subprocess.run(["awww", "query"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
            for line in p.stdout.splitlines():
                if "image:" in line.lower():
                    active = line.split("image:", 1)[1].strip()
                    break
                elif line.strip():
                    active = line.strip().split()[-1]
                    break
        except Exception:
            pass
    return active

def resolve_we_assets(entry_id, item_path, data, item_type):
    poster_dir = os.path.expanduser("~/.cache/wallpaper-engine-posters")
    we_thumb_dir = os.path.expanduser("~/.cache/skwd-wall-v2/we-thumbs")
    local_thumb_dir = os.path.expanduser("~/.cache/wallpaper-engine-thumbs")
    os.makedirs(poster_dir, exist_ok=True)
    os.makedirs(local_thumb_dir, exist_ok=True)

    poster_path = os.path.join(poster_dir, f"{entry_id}.png")
    we_thumb_file = os.path.join(we_thumb_dir, f"{entry_id}.webp")
    local_thumb_file = os.path.join(local_thumb_dir, f"{entry_id}.webp")

    # 1. Resolve / Ensure High-Resolution Poster (1920x1200)
    if not (os.path.isfile(poster_path) and os.path.getsize(poster_path) > 50000):
        # A. If it's a video, grab frame from MP4
        video_cand = ""
        if data.get("file"):
            vf = os.path.join(item_path, data.get("file"))
            if os.path.isfile(vf) and any(vf.lower().endswith(ext) for ext in [".mp4", ".mkv", ".webm"]):
                video_cand = vf
        if not video_cand:
            mp4s = glob.glob(os.path.join(item_path, "*.mp4"))
            if mp4s:
                video_cand = mp4s[0]

        if video_cand:
            try:
                subprocess.run(
                    ["ffmpeg", "-y", "-ss", "00:00:02", "-i", video_cand, "-vframes", "1", "-q:v", "2", poster_path],
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5
                )
            except Exception:
                pass

        # B. Check for high-res preview image (jpg/png) inside item folder
        if not (os.path.isfile(poster_path) and os.path.getsize(poster_path) > 50000):
            p_img = os.path.join(item_path, "preview.jpg")
            if not os.path.isfile(p_img):
                p_img = os.path.join(item_path, "preview.png")
            if os.path.isfile(p_img) and os.path.getsize(p_img) > 100000:
                try:
                    subprocess.run(
                        ["magick", p_img, "-filter", "Lanczos", "-resize", "1920x1200^", "-gravity", "center", "-extent", "1920x1200", poster_path],
                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5
                    )
                except Exception:
                    pass

        # C. Upscale from cached we-thumb (640x360 WebP)
        if not (os.path.isfile(poster_path) and os.path.getsize(poster_path) > 50000):
            if os.path.isfile(we_thumb_file):
                try:
                    subprocess.run(
                        ["magick", we_thumb_file, "-filter", "Lanczos", "-resize", "1920x1200^", "-gravity", "center", "-extent", "1920x1200", "-unsharp", "0x0.8", poster_path],
                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5
                    )
                except Exception:
                    pass

        # D. Frame 0 from preview.gif
        if not (os.path.isfile(poster_path) and os.path.getsize(poster_path) > 50000):
            pg = os.path.join(item_path, "preview.gif")
            if os.path.isfile(pg):
                try:
                    subprocess.run(
                        ["magick", f"{pg}[0]", "-filter", "Lanczos", "-resize", "1920x1200^", "-gravity", "center", "-extent", "1920x1200", poster_path],
                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5
                    )
                except Exception:
                    pass

    # 2. Resolve Crisp Card Thumbnail (preview)
    preview_path = ""
    if os.path.isfile(we_thumb_file):
        preview_path = we_thumb_file
    elif os.path.isfile(local_thumb_file):
        preview_path = local_thumb_file
    else:
        # Check inside item folder for static images
        pj = os.path.join(item_path, "preview.jpg")
        pp = os.path.join(item_path, "preview.png")
        pw = os.path.join(item_path, "preview.webp")
        if os.path.isfile(pj):
            preview_path = pj
        elif os.path.isfile(pp):
            preview_path = pp
        elif os.path.isfile(pw):
            preview_path = pw
        elif os.path.isfile(poster_path):
            preview_path = poster_path
        else:
            pg = os.path.join(item_path, "preview.gif")
            if os.path.isfile(pg):
                # Convert frame 0 to static webp thumbnail once
                try:
                    subprocess.run(
                        ["magick", f"{pg}[0]", "-resize", "640x360^", "-gravity", "center", "-extent", "640x360", local_thumb_file],
                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=4
                    )
                    if os.path.isfile(local_thumb_file):
                        preview_path = local_thumb_file
                    else:
                        preview_path = pg
                except Exception:
                    preview_path = pg

    return preview_path, poster_path

def scan_wallpaper_engine():
    items = []
    seen_ids = set()

    # 1. Steam Workshop directory (App ID 431960)
    ws_candidates = [
        os.path.expanduser("~/.local/share/Steam/steamapps/workshop/content/431960"),
        os.path.expanduser("~/.steam/steam/steamapps/workshop/content/431960"),
        os.path.expanduser("~/.steam/debian-installation/steamapps/workshop/content/431960")
    ]
    
    for ws_dir in ws_candidates:
        if not os.path.isdir(ws_dir):
            continue
        for entry in os.listdir(ws_dir):
            if entry in seen_ids:
                continue
            item_path = os.path.join(ws_dir, entry)
            if not os.path.isdir(item_path):
                continue
            pj = os.path.join(item_path, "project.json")
            if not os.path.isfile(pj):
                continue
            try:
                with open(pj, "r", encoding="utf-8", errors="ignore") as f:
                    data = json.load(f)
                title = (data.get("title") or entry).strip()
                item_type = (data.get("type") or "scene").lower().strip()
                
                video_file = ""
                if item_type == "video" and data.get("file"):
                    vf = os.path.join(item_path, data.get("file"))
                    if os.path.isfile(vf):
                        video_file = vf
                if not video_file and item_type == "video":
                    cand_vids = glob.glob(os.path.join(item_path, "*.mp4"))
                    if cand_vids:
                        video_file = cand_vids[0]

                preview_path, poster_path = resolve_we_assets(entry, item_path, data, item_type)
                
                items.append({
                    "id": entry,
                    "title": title,
                    "type": item_type,
                    "isWE": True,
                    "path": item_path,
                    "preview": preview_path,
                    "poster": poster_path,
                    "videoFile": video_file,
                    "description": data.get("description") or ""
                })
                seen_ids.add(entry)
            except Exception:
                continue

    # 2. Default Wallpaper Engine projects (built-in templates)
    default_candidates = [
        os.path.expanduser("~/.local/share/Steam/steamapps/common/wallpaper_engine/projects/defaultprojects"),
        os.path.expanduser("~/.steam/steam/steamapps/common/wallpaper_engine/projects/defaultprojects")
    ]
    for dp_dir in default_candidates:
        if not os.path.isdir(dp_dir):
            continue
        for entry in os.listdir(dp_dir):
            if entry in seen_ids:
                continue
            item_path = os.path.join(dp_dir, entry)
            if not os.path.isdir(item_path):
                continue
            pj = os.path.join(item_path, "project.json")
            if not os.path.isfile(pj):
                continue
            try:
                with open(pj, "r", encoding="utf-8", errors="ignore") as f:
                    data = json.load(f)
                title = (data.get("title") or entry).strip()
                item_type = (data.get("type") or "scene").lower().strip()
                preview_path, poster_path = resolve_we_assets(entry, item_path, data, item_type)
                
                items.append({
                    "id": entry,
                    "title": title,
                    "type": item_type,
                    "isWE": True,
                    "path": item_path,
                    "preview": preview_path,
                    "poster": poster_path,
                    "videoFile": "",
                    "description": data.get("description") or ""
                })
                seen_ids.add(entry)
            except Exception:
                continue

    return items

def scan_local_wallpapers():
    items = []
    seen_paths = set()
    dirs = [
        os.path.expanduser("~/Pictures/Wallpapers"),
        os.path.expanduser("~/git/DynamicYou/Wallpapers"),
        os.path.expanduser("~/.config/quickshell/inir/assets/wallpapers")
    ]
    valid_exts = (".png", ".jpg", ".jpeg", ".webp", ".gif", ".mp4", ".webm", ".mkv")

    for base_dir in dirs:
        if not os.path.isdir(base_dir):
            continue
        for root_dir, _, filenames in os.walk(base_dir):
            for fn in filenames:
                if fn.startswith("."):
                    continue
                lower = fn.lower()
                if lower.endswith(valid_exts):
                    full_path = os.path.join(root_dir, fn)
                    if full_path in seen_paths:
                        continue
                    seen_paths.add(full_path)
                    
                    is_gif = lower.endswith(".gif")
                    is_vid = lower.endswith((".mp4", ".webm", ".mkv"))
                    w_type = "video" if is_vid else ("gif" if is_gif else "image")

                    items.append({
                        "id": fn,
                        "title": fn,
                        "type": w_type,
                        "isWE": False,
                        "path": full_path,
                        "preview": full_path,
                        "poster": full_path,
                        "videoFile": full_path if is_vid else "",
                        "description": ""
                    })

    items.sort(key=lambda x: x["title"].lower())
    return items

def main():
    active = get_active_wallpaper()
    engine_items = scan_wallpaper_engine()
    local_items = scan_local_wallpapers()

    result = {
        "active": active,
        "engine": engine_items,
        "local": local_items
    }
    print(json.dumps(result))

if __name__ == "__main__":
    main()
