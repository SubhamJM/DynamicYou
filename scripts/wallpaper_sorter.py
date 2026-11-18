#!/usr/bin/env python3
"""
DynamicYou Wallpaper Sorter Engine
Uses Material You Chroma-Scoring + CIELAB Color Space Analysis to accurately
classify and partition wallpapers into DynamicYou themes:
  - Abyss     (Deep Ocean / Bioluminescent Cyan / Blue)
  - Verdant   (Emerald Moss / Lush Botanical Forest)
  - Crimson   (Ruby Scarlet / Coral Red / Burgundy)
  - Afterglow (Twilight Sunset Pink / Lavender Purple)
  - Solstice  (Golden Sunlight / Amber Orange / Sand)
  - Frost     (Monochrome / Ice Gray / Slate)

Includes deduplication to ensure unique wallpapers with the same name
are never copied together.
"""

import sys
import os
import argparse
import json
import math
import shutil
from pathlib import Path
from PIL import Image

# Exact perceptual theme anchors for CIELAB distance calculations
THEME_ANCHORS = {
    "Abyss": [
        (0, 229, 255),   # #00e5ff (Bright cyan)
        (0, 245, 212),   # #00f5d4 (Aqua)
        (2, 132, 199),   # #0284c7 (Ocean blue)
        (14, 165, 233),  # #0ea5e9 (Sky blue)
    ],
    "Verdant": [
        (5, 223, 114),   # #05df72 (Emerald)
        (52, 211, 153),  # #34d399 (Mint)
        (35, 73, 54),    # #234936 (Deep forest)
        (131, 192, 146), # #83c092 (Sage)
    ],
    "Crimson": [
        (255, 42, 95),   # #ff2a5f (Ruby scarlet)
        (244, 63, 94),   # #f43f5e (Rose red)
        (230, 126, 128), # #e67e80 (Coral red)
        (180, 20, 50),   # Deep wine
    ],
    "Afterglow": [
        (244, 114, 182), # #f472b6 (Twilight pink)
        (196, 181, 253), # #c4b5fd (Lavender)
        (129, 140, 248), # #818cf8 (Violet)
        (214, 153, 182), # #d699b6 (Mauve)
    ],
    "Solstice": [
        (255, 158, 59),  # #ff9e3b (Amber orange)
        (245, 158, 11),  # #f59e0b (Deep amber)
        (219, 188, 127), # #dbbc7f (Golden ochre)
        (254, 215, 170), # #fed7aa (Warm peach)
    ],
    "Frost": [
        (255, 255, 255), # Pure white
        (148, 163, 184), # Cool slate
        (100, 116, 139), # Graphite
        (200, 210, 220), # Ice gray
    ]
}

THEME_HEX = {
    "Abyss": "#00e5ff",
    "Verdant": "#05df72",
    "Crimson": "#ff2a5f",
    "Afterglow": "#f472b6",
    "Solstice": "#ff9e3b",
    "Frost": "#ffffff",
}

def rgb_to_lab(r, g, b):
    """Converts sRGB (0-255) to CIE L*a*b* coordinates."""
    r, g, b = [x / 255.0 for x in (r, g, b)]
    r = ((r + 0.055) / 1.055) ** 2.4 if r > 0.04045 else r / 12.92
    g = ((g + 0.055) / 1.055) ** 2.4 if g > 0.04045 else g / 12.92
    b = ((b + 0.055) / 1.055) ** 2.4 if b > 0.04045 else b / 12.92
    x = (r * 0.4124 + g * 0.3576 + b * 0.1805) / 0.95047
    y = (r * 0.2126 + g * 0.7152 + b * 0.0722) / 1.00000
    z = (r * 0.0193 + g * 0.1192 + b * 0.9505) / 1.08883
    fx, fy, fz = [t ** (1/3) if t > 0.008856 else (7.787 * t) + (16 / 116) for t in (x, y, z)]
    return (116 * fy) - 16, 500 * (fx - fy), 200 * (fy - fz)

def classify_wallpaper(img_path):
    """
    Analyzes an image using Material You Chroma weighting and CIELAB color space.
    Returns: (theme_name, dominant_rgb, hex_color)
    """
    try:
        with Image.open(img_path) as img:
            img = img.convert("RGB")
            img.thumbnail((120, 120))
            quantized = img.quantize(colors=20)
            palette = quantized.getpalette()[:60]
            colors = quantized.getcolors() or []

            total_pixels = sum(c[0] for c in colors)
            theme_scores = {
                "Abyss": 0.0,
                "Verdant": 0.0,
                "Crimson": 0.0,
                "Afterglow": 0.0,
                "Solstice": 0.0,
            }
            frost_weight = 0.0
            dominant_rgb_by_theme = {}

            for count, idx in colors:
                r = palette[idx * 3]
                g = palette[idx * 3 + 1]
                b = palette[idx * 3 + 2]
                L, a, b_val = rgb_to_lab(r, g, b)
                chroma = math.sqrt(a**2 + b_val**2)
                hab = math.degrees(math.atan2(b_val, a)) % 360

                # Monochrome / low-saturation check: pure black/white or low chroma
                if chroma < 9 or L < 6 or L > 94:
                    frost_weight += count
                    continue

                # Material You Chroma weighting formula
                weight = count * (chroma ** 1.25) * (1.0 - abs(L - 50) / 60.0)

                # Map hab angle to target theme
                if 95 <= hab < 185:
                    theme = "Verdant"
                elif 185 <= hab < 275:
                    theme = "Abyss"
                elif 275 <= hab < 350:
                    theme = "Afterglow"
                elif 45 <= hab < 95:
                    theme = "Solstice"
                else:  # 350° to 45°
                    theme = "Crimson"

                theme_scores[theme] += weight
                if theme not in dominant_rgb_by_theme or weight > dominant_rgb_by_theme[theme][0]:
                    dominant_rgb_by_theme[theme] = (weight, (r, g, b))

            best_theme = max(theme_scores, key=lambda t: theme_scores[t])

            # Classify as Frost if mostly desaturated or weak chroma
            if theme_scores[best_theme] <= 0 or (frost_weight / max(1, total_pixels) > 0.86 and theme_scores[best_theme] < 1200):
                return "Frost", (210, 215, 220), THEME_HEX["Frost"]

            chosen_rgb = dominant_rgb_by_theme.get(best_theme, (0, (128, 128, 128)))[1]
            hex_color = f"#{chosen_rgb[0]:02x}{chosen_rgb[1]:02x}{chosen_rgb[2]:02x}"
            return best_theme, chosen_rgb, hex_color

    except Exception:
        return "Frost", (200, 200, 200), THEME_HEX["Frost"]

def collect_existing_names(dest_dir):
    """Gathers all existing wallpaper filenames across destination theme subfolders."""
    existing = set()
    dest_path = Path(dest_dir).expanduser().resolve()
    if not dest_path.is_dir():
        return existing

    extensions = {".jpg", ".jpeg", ".png", ".webp"}
    for item in dest_path.glob("*/*"):
        if item.is_file() and item.suffix.lower() in extensions:
            existing.add(item.name.lower())
    return existing

def sort_directory(source_dir, dest_dir, mode="copy", as_json=False):
    """
    Scans source_dir for images, deduplicates by filename, classifies via Material You,
    and sorts into partitioned theme subdirectories in dest_dir.
    """
    source_path = Path(source_dir).expanduser().resolve()
    dest_path = Path(dest_dir).expanduser().resolve()

    if not source_path.is_dir():
        if as_json:
            print(json.dumps({"type": "error", "message": f"Source directory does not exist: {source_path}"}), flush=True)
        else:
            print(f"Error: Source directory does not exist: {source_path}", file=sys.stderr)
        return False

    extensions = {".jpg", ".jpeg", ".png", ".webp"}
    # Gather all image files
    files = [f for f in source_path.rglob("*") if f.is_file() and f.suffix.lower() in extensions]
    total_files = len(files)

    existing_names = collect_existing_names(dest_path)
    seen_in_batch = set()

    if as_json:
        print(json.dumps({
            "type": "start",
            "source": str(source_path),
            "dest": str(dest_path),
            "total_files": total_files,
            "existing_count": len(existing_names)
        }), flush=True)
    else:
        print(f"\n🎨 DynamicYou Wallpaper Sorter (Material You Chroma + CIELAB)")
        print(f"📂 Source: {source_path} ({total_files} images found)")
        print(f"🎯 Target: {dest_path}")
        print(f"🔒 Deduplication: Active (Existing in pool: {len(existing_names)})")
        print("─" * 70)

    stats = {t: 0 for t in THEME_ANCHORS}
    duplicates_skipped = 0
    unique_added = 0

    for idx, file_path in enumerate(sorted(files, key=lambda f: f.name.lower()), start=1):
        file_key = file_path.name.lower()

        # Deduplication check: duplicate photos with the same name are skipped
        if file_key in existing_names or file_key in seen_in_batch:
            duplicates_skipped += 1
            if as_json:
                print(json.dumps({
                    "type": "progress",
                    "current": idx,
                    "total": total_files,
                    "filename": file_path.name,
                    "theme": None,
                    "status": "duplicate_skipped"
                }), flush=True)
            else:
                print(f"[{idx:3d}/{total_files:3d}] \033[33m[DUPLICATE]\033[0m {file_path.name} (Skipped)")
            continue

        seen_in_batch.add(file_key)
        existing_names.add(file_key)

        # Classify color
        theme, rgb, hex_col = classify_wallpaper(file_path)
        stats[theme] += 1
        unique_added += 1

        # Destination path
        theme_dir = dest_path / theme
        theme_dir.mkdir(parents=True, exist_ok=True)
        dest_file = theme_dir / file_path.name

        try:
            if mode == "symlink":
                if dest_file.exists() or dest_file.is_symlink():
                    dest_file.unlink()
                dest_file.symlink_to(file_path)
            elif mode == "move":
                shutil.move(file_path, dest_file)
            else:  # copy
                shutil.copy2(file_path, dest_file)
        except Exception as e:
            if as_json:
                print(json.dumps({"type": "warn", "message": f"Failed to place {file_path.name}: {e}"}), flush=True)

        if as_json:
            print(json.dumps({
                "type": "progress",
                "current": idx,
                "total": total_files,
                "filename": file_path.name,
                "theme": theme,
                "hex": hex_col,
                "status": "sorted"
            }), flush=True)
        else:
            r, g, b = rgb
            ansi_swatch = f"\033[48;2;{r};{g};{b}m  \033[0m"
            print(f"[{idx:3d}/{total_files:3d}] {ansi_swatch} \033[1m{theme:<10}\033[0m -> {file_path.name}")

    if as_json:
        print(json.dumps({
            "type": "done",
            "total_found": total_files,
            "unique_added": unique_added,
            "duplicates_skipped": duplicates_skipped,
            "by_theme": stats
        }), flush=True)
    else:
        print("\n" + "═" * 70)
        print(f"🎉 Sorting Complete!")
        print(f"   • Total Processed    : {total_files}")
        print(f"   • Unique Added       : {unique_added}")
        print(f"   • Duplicates Skipped : {duplicates_skipped}")
        print("─" * 40)
        for t, count in stats.items():
            print(f"   • {t:<10}: +{count}")
        print("═" * 70 + "\n")

    return True

def main():
    parser = argparse.ArgumentParser(description="Sort wallpapers into DynamicYou theme folders.")
    parser.add_argument("source", nargs="?", default=os.path.expanduser("~/customwallpapers"),
                        help="Source folder containing wallpapers (default: ~/customwallpapers)")
    parser.add_argument("--dest", default=os.path.expanduser("~/Pictures/Wallpapers"),
                        help="Destination Wallpapers root folder (default: ~/Pictures/Wallpapers)")
    parser.add_argument("--mode", choices=["copy", "symlink", "move"], default="copy",
                        help="Operation mode: copy (default), symlink, or move")
    parser.add_argument("--json", action="store_true", help="Emit line-by-line JSON events for UI consumers")

    args = parser.parse_args()
    sort_directory(args.source, args.dest, mode=args.mode, as_json=args.json)

if __name__ == "__main__":
    main()
