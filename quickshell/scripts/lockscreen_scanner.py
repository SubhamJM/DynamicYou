#!/usr/bin/env python3
import os
import json

def scan_lockscreens():
    home = os.path.expanduser("~")
    # Primary lockscreen location
    candidates = [
        os.path.join(home, ".local/share/quickshell-lockscreen/themes"),
        os.path.join(home, "git/MyLinuxSetup/lockscreen/themes"),
        os.path.join(home, "git/DynamicYou/lockscreen/themes")
    ]

    themes_dir = None
    for c in candidates:
        if os.path.exists(c) and os.path.isdir(c):
            themes_dir = c
            break

    # Get active theme
    active_theme = "dog-samurai"
    config_file = os.path.join(home, ".config/qylock/theme")
    if os.path.exists(config_file):
        try:
            with open(config_file, "r", encoding="utf-8") as f:
                content = f.read().strip()
                if content:
                    active_theme = content
        except Exception:
            pass

    # The 6 allowed themes and metadata
    ALLOWED_THEMES = [
        {
            "id": "dog-samurai",
            "name": "Dog Samurai",
            "description": "Animated samurai dog in cherry blossom rain",
            "accent": "#ffb7c5"
        },
        {
            "id": "minecraft",
            "name": "Minecraft",
            "description": "Classic Minecraft panorama & interactive interface",
            "accent": "#5b8731"
        },
        {
            "id": "pixel-hollowknight",
            "name": "Hollow Knight",
            "description": "Atmospheric Hallownest pixel art",
            "accent": "#f5aa5b"
        },
        {
            "id": "pixel-emerald",
            "name": "Pixel - Emerald",
            "description": "Retro Pokémon Emerald pixel art adventure",
            "accent": "#3ec878"
        },
        {
            "id": "enfield",
            "name": "Enfield",
            "description": "Cinematic Royal Enfield under falling sakura",
            "accent": "#d4849e"
        },
        {
            "id": "last-of-us",
            "name": "The Last of Us",
            "description": "Post-apocalyptic overgrown room with spores",
            "accent": "#f7c594"
        }
    ]

    result = []
    for item in ALLOWED_THEMES:
        tid = item["id"]
        t_dir = os.path.join(themes_dir, tid) if themes_dir else ""
        preview_png = os.path.join(t_dir, "preview.png") if t_dir else ""
        preview_gif = os.path.join(t_dir, "preview.gif") if t_dir else ""

        # Read custom theme.json if present
        json_path = os.path.join(t_dir, "theme.json") if t_dir else ""
        if os.path.exists(json_path):
            try:
                with open(json_path, "r", encoding="utf-8") as f:
                    tj = json.load(f)
                    item["name"] = tj.get("name", item["name"])
                    item["description"] = tj.get("description", item["description"])
                    item["accent"] = tj.get("accent", item["accent"])
            except Exception:
                pass

        result.append({
            "id": tid,
            "name": item["name"],
            "description": item["description"],
            "accent": item["accent"],
            "preview": preview_png if os.path.exists(preview_png) else "",
            "gif": preview_gif if os.path.exists(preview_gif) else "",
            "folder": t_dir,
            "isActive": (tid == active_theme)
        })

    print(json.dumps(result))

if __name__ == "__main__":
    scan_lockscreens()
