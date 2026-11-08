#!/usr/bin/env python3
"""
Dynamic-You Unified Theming Engine
Works identically on NixOS and Arch Linux.
Manages theme presets, wallpaper-based dynamic color extraction (via matugen or built-in fallback),
and updates terminals (Kitty, Foot, Alacritty, Ghostty), Hyprland, Hyprlock, Quickshell, GTK, Starship, and Fastfetch.
"""

import sys
import os
import re
import json
import shutil
import random
import subprocess
import colorsys
from pathlib import Path

HOME = Path(os.path.expanduser("~"))
DYNAMIC_YOU_DIR = Path(__file__).resolve().parent.parent

# Standard Directory Paths
THEMES_DIRS = [
    DYNAMIC_YOU_DIR / "themes",
    HOME / ".config" / "themes",
    HOME / "themes"
]
WALLPAPER_DIRS = [
    DYNAMIC_YOU_DIR / "Wallpapers",
    HOME / "Pictures" / "Wallpapers",
    HOME / ".config" / "Wallpapers"
]
ACTIVE_DIR = HOME / ".config" / "active-theme"
KITTY_DIR = HOME / ".config" / "kitty"
FOOT_DIR = HOME / ".config" / "foot"
GTK3_DIR = HOME / ".config" / "gtk-3.0"
GTK4_DIR = HOME / ".config" / "gtk-4.0"
STARSHIP_FILE = HOME / ".config" / "starship.toml"
FASTFETCH_FILE = HOME / ".config" / "fastfetch" / "config.jsonc"
OMARCHY_DIR = HOME / ".local" / "state" / "omarchy" / "current" / "theme"

def hex_to_rgb(h):
    h = h.lstrip("#")
    if len(h) == 3:
        h = "".join(c * 2 for c in h)
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

def rgb_to_hex(r, g, b):
    return f"#{int(max(0, min(255, r))):02x}{int(max(0, min(255, g))):02x}{int(max(0, min(255, b))):02x}"

def strip_hash(h):
    return h.lstrip("#")

def adjust_lightness(h, factor):
    r, g, b = hex_to_rgb(h)
    h_val, l_val, s_val = colorsys.rgb_to_hls(r/255.0, g/255.0, b/255.0)
    l_val = max(0.0, min(1.0, l_val * factor))
    nr, ng, nb = colorsys.hls_to_rgb(h_val, l_val, s_val)
    return rgb_to_hex(nr * 255, ng * 255, nb * 255)

def is_dark(h):
    r, g, b = hex_to_rgb(h)
    # Relative luminance
    return (0.299 * r + 0.587 * g + 0.114 * b) < 128

def extract_colors_from_wallpaper(image_path):
    """
    Extracts a full Material Design 3 / Material You palette from an image.
    Uses matugen if available, with a robust native Python/magick fallback.
    """
    image_path = str(Path(image_path).resolve())
    matugen_bin = shutil.which("matugen")

    if matugen_bin:
        try:
            cmd = [
                matugen_bin, "image", image_path,
                "--source-color-index", "0",
                "-m", "dark",
                "--dry-run",
                "--json", "hex",
                "-q"
            ]
            res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True)
            data = json.loads(res.stdout)
            raw_colors = data.get("colors", {})

            def get_col(name, fallback="#89b4fa"):
                val = raw_colors.get(name, {})
                if isinstance(val, dict):
                    return val.get("default", {}).get("color") or val.get("dark", {}).get("color") or fallback
                return str(val) if val else fallback

            accent = get_col("primary", "#89b4fa")
            bg = get_col("surface", "#101014")
            card_bg = get_col("surface_container", "#181820")
            hover_bg = get_col("surface_container_high", "#22222c")
            outline = get_col("outline", "#565f89")
            fg = get_col("on_surface", "#f8fafc")
            subtext = get_col("on_surface_variant", "#94a3b8")
            error = get_col("error", "#f87171")
            sec = get_col("secondary", "#7aa2f7")
            tert = get_col("tertiary", "#bb9af7")

            # Extract base16 colors if present
            base16 = data.get("base16", {})
            ansi = {}
            for i in range(16):
                key = f"base{i:02x}"
                b_val = base16.get(key, {})
                if isinstance(b_val, dict):
                    ansi[i] = b_val.get("default", {}).get("color") or b_val.get("dark", {}).get("color")
                else:
                    ansi[i] = str(b_val) if b_val else None

            # Fallback for standard 16 colors
            c0 = ansi.get(0) or bg
            c1 = ansi.get(8) or error
            c2 = ansi.get(11) or get_col("tertiary", "#9ece6a")
            c3 = ansi.get(10) or get_col("secondary", "#e0af68")
            c4 = ansi.get(14) or accent
            c5 = ansi.get(13) or tert
            c6 = ansi.get(12) or sec
            c7 = ansi.get(5) or fg
            c8 = ansi.get(3) or outline
            c9 = ansi.get(8) or adjust_lightness(c1, 1.2)
            c10 = ansi.get(11) or adjust_lightness(c2, 1.2)
            c11 = ansi.get(10) or adjust_lightness(c3, 1.2)
            c12 = ansi.get(14) or adjust_lightness(c4, 1.2)
            c13 = ansi.get(13) or adjust_lightness(c5, 1.2)
            c14 = ansi.get(12) or adjust_lightness(c6, 1.2)
            c15 = ansi.get(7) or "#ffffff"

            return {
                "accent": accent,
                "bg": bg,
                "card_bg": card_bg,
                "hover_bg": hover_bg,
                "border": outline,
                "border_hover": accent,
                "text_primary": fg,
                "text_secondary": subtext,
                "text_muted": outline,
                "error": error,
                "secondary": sec,
                "tertiary": tert,
                "ansi": [c0, c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12, c13, c14, c15]
            }
        except Exception as e:
            print(f"[theme-manager] matugen failed ({e}), falling back to native extraction", file=sys.stderr)

    # Native Python + ImageMagick fallback
    return extract_colors_fallback(image_path)

def extract_colors_fallback(image_path):
    """Fallback color extractor using ImageMagick convert or default algorithm."""
    dominant = ["#89b4fa", "#101014", "#f8fafc", "#565f89", "#f87171", "#7aa2f7"]
    magick_bin = shutil.which("magick") or shutil.which("convert")
    if magick_bin:
        try:
            cmd = [magick_bin, image_path, "-resize", "64x64!", "-colors", "8", "-format", "%c", "histogram:info:"]
            out = subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL)
            matches = re.findall(r"#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})", out)
            if matches:
                # Deduplicate and sort by vibrancy
                clean = []
                for m in matches:
                    hex6 = m[:7].lower()
                    if hex6 not in clean:
                        clean.append(hex6)
                if clean:
                    dominant = clean
        except Exception:
            pass

    # Pick brightest saturated for accent, darkest for background
    bg = "#101014"
    accent = dominant[0] if dominant else "#89b4fa"
    for c in dominant:
        if is_dark(c):
            bg = adjust_lightness(c, 0.4)
            break
    for c in dominant:
        r, g, b = hex_to_rgb(c)
        h, l, s = colorsys.rgb_to_hls(r/255.0, g/255.0, b/255.0)
        if s > 0.3 and l > 0.4 and l < 0.85:
            accent = c
            break

    card_bg = adjust_lightness(bg, 1.4)
    hover_bg = adjust_lightness(bg, 1.8)
    outline = adjust_lightness(bg, 2.5)
    fg = "#f8fafc"
    subtext = adjust_lightness(fg, 0.7)

    c0 = bg
    c1 = "#f87171"
    c2 = "#4ade80"
    c3 = "#facc15"
    c4 = accent
    c5 = "#c084fc"
    c6 = "#38bdf8"
    c7 = fg
    c8 = outline
    c9 = "#fca5a5"
    c10 = "#86efac"
    c11 = "#fde047"
    c12 = adjust_lightness(accent, 1.2)
    c13 = "#d8b4fe"
    c14 = "#7dd3fc"
    c15 = "#ffffff"

    return {
        "accent": accent,
        "bg": bg,
        "card_bg": card_bg,
        "hover_bg": hover_bg,
        "border": outline,
        "border_hover": accent,
        "text_primary": fg,
        "text_secondary": subtext,
        "text_muted": outline,
        "error": "#f87171",
        "secondary": c6,
        "tertiary": c5,
        "ansi": [c0, c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12, c13, c14, c15]
    }

def find_theme_dir(theme_name):
    """Finds directory of theme name (case-insensitive)."""
    t_lower = theme_name.lower().strip()
    for d in THEMES_DIRS:
        if not d.is_dir():
            continue
        for child in d.iterdir():
            if child.is_dir() and child.name.lower() == t_lower:
                return child
    return None

def find_theme_wallpaper(theme_name):
    """Finds a random wallpaper matching the theme name."""
    t_lower = theme_name.lower().strip()
    candidates = []
    for d in WALLPAPER_DIRS:
        if not d.is_dir():
            continue
        for child in d.iterdir():
            if child.is_dir() and child.name.lower() == t_lower:
                for ext in ("*.jpg", "*.jpeg", "*.png", "*.webp"):
                    candidates.extend(child.glob(ext))
    if candidates:
        return str(random.choice(candidates))
    # Fallback to any wallpaper in Wallpapers/
    for d in WALLPAPER_DIRS:
        if d.is_dir():
            all_wall = []
            for ext in ("*.jpg", "*.jpeg", "*.png", "*.webp"):
                all_wall.extend(d.rglob(ext))
            if all_wall:
                return str(random.choice(all_wall))
    return None

def safe_write(path: Path, content: str):
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        if path.is_symlink() or path.exists():
            path.unlink()
    except Exception:
        pass
    path.write_text(content)

def write_theme_configs(palette, theme_name):
    """
    Writes all target files across the entire desktop system.
    """
    ACTIVE_DIR.mkdir(parents=True, exist_ok=True)
    KITTY_DIR.mkdir(parents=True, exist_ok=True)
    GTK3_DIR.mkdir(parents=True, exist_ok=True)
    GTK4_DIR.mkdir(parents=True, exist_ok=True)

    accent = palette["accent"]
    bg = palette["bg"]
    card_bg = palette["card_bg"]
    hover_bg = palette["hover_bg"]
    border = palette["border"]
    fg = palette["text_primary"]
    subtext = palette["text_secondary"]
    error = palette.get("error", "#f87171")
    sec = palette.get("secondary", "#7aa2f7")
    tert = palette.get("tertiary", "#bb9af7")
    ansi = palette.get("ansi", [bg, error, sec, tert, accent, tert, sec, fg, border, error, sec, tert, accent, tert, sec, "#ffffff"])

    accent_stripped = strip_hash(accent)
    bg_stripped = strip_hash(bg)
    border_stripped = strip_hash(border)
    card_bg_stripped = strip_hash(card_bg)
    fg_stripped = strip_hash(fg)
    subtext_stripped = strip_hash(subtext)

    # 1. Quickshell Theme Colors JSON
    qs_colors = {
        "bg": bg,
        "card_bg": card_bg,
        "hover_bg": hover_bg,
        "border": border,
        "border_hover": accent,
        "text_primary": fg,
        "text_secondary": subtext,
        "accent": accent
    }
    safe_write(ACTIVE_DIR / "quickshell-colors.json", json.dumps(qs_colors, indent=2))
    safe_write(ACTIVE_DIR / "theme-name.txt", theme_name)

    # Also write to ~/.local/state/quickshell/user/generated/colors.json if dir exists
    qs_gen_dir = HOME / ".local" / "state" / "quickshell" / "user" / "generated"
    qs_gen_m3 = {
        "primary": accent,
        "on_primary": bg,
        "primary_container": card_bg,
        "on_primary_container": fg,
        "surface": bg,
        "on_surface": fg,
        "surface_container": card_bg,
        "surface_container_high": hover_bg,
        "outline": border,
        "outline_variant": border,
        "background": bg,
        "on_background": fg,
        "error": error
    }
    safe_write(qs_gen_dir / "colors.json", json.dumps(qs_gen_m3, indent=2))

    # 2. Hyprland Border Colors
    hypr_lua = f"""local colors = {{
    active_border = "rgba({accent_stripped}ee)",
    inactive_border = "rgba({border_stripped}aa)"
}}

return colors
"""
    safe_write(ACTIVE_DIR / "hypr-colors.lua", hypr_lua)

    hypr_conf = f"""$active_border = rgb({accent_stripped})
$inactive_border = rgb({border_stripped})
"""
    safe_write(ACTIVE_DIR / "hyprland-colors.conf", hypr_conf)

    # 3. Hyprlock Colors
    hyprlock_conf = f"""# Auto-generated by dynamic-you theme manager for {theme_name}
$accent = rgb({accent_stripped})
$accentAlpha = {accent_stripped}
$card_bg = rgba({card_bg_stripped}d9)
$text = rgb({fg_stripped})
$subtext = rgb({subtext_stripped})
"""
    safe_write(ACTIVE_DIR / "hyprlock-colors.conf", hyprlock_conf)

    # 4. Kitty Terminal Colors
    kitty_colors = f"""# Auto-generated Kitty Theme for {theme_name}
foreground            {fg}
background            {bg}
selection_foreground  {bg}
selection_background  {accent}

cursor                {fg}
cursor_text_color     {bg}
url_color             {accent}

# Window border colors
active_border_color     {accent}
inactive_border_color   {border}
bell_border_color       {error}

wayland_titlebar_color system
macos_titlebar_color system

# Tab bar colors
active_tab_foreground   {bg}
active_tab_background   {accent}
inactive_tab_foreground {subtext}
inactive_tab_background {card_bg}
tab_bar_background      {bg}

# 16 terminal colors
color0   {ansi[0]}
color1   {ansi[1]}
color2   {ansi[2]}
color3   {ansi[3]}
color4   {ansi[4]}
color5   {ansi[5]}
color6   {ansi[6]}
color7   {ansi[7]}
color8   {ansi[8]}
color9   {ansi[9]}
color10  {ansi[10]}
color11  {ansi[11]}
color12  {ansi[12]}
color13  {ansi[13]}
color14  {ansi[14]}
color15  {ansi[15]}
"""
    safe_write(ACTIVE_DIR / "kitty-colors.conf", kitty_colors)
    safe_write(KITTY_DIR / "dank-theme.conf", kitty_colors)

    kitty_tabs = f"""tab_bar_edge            top
tab_bar_style           powerline
tab_powerline_style     slanted
tab_bar_align           left
tab_bar_min_tabs        2
tab_bar_margin_width    0.0
tab_bar_margin_height   2.5 1.5
tab_bar_margin_color    {bg}

tab_bar_background              {bg}

active_tab_foreground           {bg}
active_tab_background           {accent}
active_tab_font_style           bold

inactive_tab_foreground         {subtext}
inactive_tab_background         {card_bg}
inactive_tab_font_style         normal

tab_activity_symbol             " ● "
"""
    safe_write(KITTY_DIR / "dank-tabs.conf", kitty_tabs)

    # 5. GTK 3 & GTK 4 CSS Colors
    gtk_css = f"""/* Auto-generated GTK theme for {theme_name} */
@define-color accent_color {accent};
@define-color accent_bg_color {accent};
@define-color accent_fg_color {bg};

@define-color window_bg_color {bg};
@define-color window_fg_color {fg};

@define-color headerbar_bg_color {card_bg};
@define-color headerbar_fg_color {fg};
@define-color headerbar_border_color {border};

@define-color view_bg_color {bg};
@define-color view_fg_color {fg};

@define-color card_bg_color {card_bg};
@define-color card_fg_color {fg};

@define-color dialog_bg_color {card_bg};
@define-color dialog_fg_color {fg};

@define-color popover_bg_color {card_bg};
@define-color popover_fg_color {fg};
"""
    safe_write(GTK3_DIR / "gtk.css", gtk_css)
    safe_write(GTK4_DIR / "gtk.css", gtk_css)

    # 6. Starship Prompt Colors
    starship_palette = f"""[palettes.custom]
bg = "{bg}"
mantle = "{card_bg}"
crust = "{bg}"
surface0 = "{border}"
surface1 = "{border}"
surface2 = "{accent}"
overlay0 = "{subtext}"
text = "{fg}"
subtext = "{subtext}"
lavender = "{accent}"
mauve = "{sec}"
blue = "{ansi[4]}"
red = "{ansi[1]}"
green = "{ansi[2]}"
yellow = "{ansi[3]}"
"""
    safe_write(ACTIVE_DIR / "starship-colors.toml", starship_palette)

    if STARSHIP_FILE.is_file():
        try:
            content = STARSHIP_FILE.read_text()
            if "[palettes.custom]" in content:
                content = re.sub(r"\[palettes\.custom\][\s\S]*$", starship_palette.strip(), content)
            else:
                content = content.rstrip() + "\n\n" + starship_palette
            safe_write(STARSHIP_FILE, content)
        except Exception as e:
            print(f"[theme-manager] Failed to update starship.toml: {e}", file=sys.stderr)

    # 7. Fastfetch Colors (keeps the default distro logo intact while matching keys to theme)
    if FASTFETCH_FILE.is_file():
        try:
            content = FASTFETCH_FILE.read_text()
            content = re.sub(r'("keys":\s*)"#[0-9a-fA-F]{6}"', f'\\1"{accent}"', content)
            safe_write(FASTFETCH_FILE, content)
        except Exception as e:
            print(f"[theme-manager] Failed to update fastfetch: {e}", file=sys.stderr)

    # 8. Foot Terminal Colors (strictly valid foot.ini format: [colors-dark] with alpha & blur)
    foot_content = f"""[colors-dark]
alpha=0.90
blur=yes
foreground={fg_stripped}
background={bg_stripped}
selection-foreground={fg_stripped}
selection-background={accent_stripped}

cursor={bg_stripped} {accent_stripped}
urls={accent_stripped}

regular0={strip_hash(ansi[0])}
regular1={strip_hash(ansi[1])}
regular2={strip_hash(ansi[2])}
regular3={strip_hash(ansi[3])}
regular4={strip_hash(ansi[4])}
regular5={strip_hash(ansi[5])}
regular6={strip_hash(ansi[6])}
regular7={strip_hash(ansi[7])}

bright0={strip_hash(ansi[8])}
bright1={strip_hash(ansi[9])}
bright2={strip_hash(ansi[10])}
bright3={strip_hash(ansi[11])}
bright4={strip_hash(ansi[12])}
bright5={strip_hash(ansi[13])}
bright6={strip_hash(ansi[14])}
bright7={strip_hash(ansi[15])}
"""
    if FOOT_DIR.is_dir():
        safe_write(FOOT_DIR / "dank-colors.ini", foot_content)

    # 9. Omarchy State Directory Mirror (Foot, Kitty, Alacritty, Ghostty, Colors.toml, Hyprland.lua)
    if OMARCHY_DIR.is_dir():
        try:
            # Foot terminal in omarchy
            safe_write(OMARCHY_DIR / "foot.ini", foot_content)

            # Global omarchy colors.toml
            omarchy_colors = f"""mode = "dark"

accent = "{accent}"
selection = "{card_bg}"
muted = "{border}"

background = "{bg}"
dark_background = "{bg}"
darker_background = "{bg}"
lighter_background = "{card_bg}"

foreground = "{fg}"
dark_foreground = "{subtext}"
light_foreground = "{fg}"
bright_foreground = "#ffffff"

red = "{ansi[1]}"
yellow = "{ansi[3]}"
orange = "{sec}"
green = "{ansi[2]}"
cyan = "{ansi[6]}"
blue = "{ansi[4]}"
magenta = "{ansi[5]}"
brown = "{border}"

bright_red = "{ansi[9]}"
bright_yellow = "{ansi[11]}"
bright_green = "{ansi[10]}"
bright_cyan = "{ansi[14]}"
bright_blue = "{ansi[12]}"
bright_magenta = "{ansi[13]}"
"""
            safe_write(OMARCHY_DIR / "colors.toml", omarchy_colors)

            # Hyprland border in omarchy
            omarchy_hypr = f"""local active_border_color = "{accent}"
local inactive_border_color = "rgba({border_stripped}aa)"

hl.config({{
  general = {{
    col = {{
      active_border = active_border_color,
      inactive_border = inactive_border_color,
    }},
  }},

  group = {{
    col = {{
      border_active = active_border_color,
      border_inactive = inactive_border_color,
    }},
  }},
}})
"""
            safe_write(OMARCHY_DIR / "hyprland.lua", omarchy_hypr)

            # Kitty terminal in omarchy
            safe_write(OMARCHY_DIR / "kitty.conf", kitty_colors)

            # Alacritty in omarchy
            alac = f"""[colors.primary]
background = "{bg}"
foreground = "{fg}"

[colors.cursor]
text = "{bg}"
cursor = "{accent}"

[colors.selection]
text = "{bg}"
background = "{accent}"

[colors.normal]
black = "{ansi[0]}"
red = "{ansi[1]}"
green = "{ansi[2]}"
yellow = "{ansi[3]}"
blue = "{ansi[4]}"
magenta = "{ansi[5]}"
cyan = "{ansi[6]}"
white = "{ansi[7]}"

[colors.bright]
black = "{ansi[8]}"
red = "{ansi[9]}"
green = "{ansi[10]}"
yellow = "{ansi[11]}"
blue = "{ansi[12]}"
magenta = "{ansi[13]}"
cyan = "{ansi[14]}"
white = "{ansi[15]}"
"""
            safe_write(OMARCHY_DIR / "alacritty.toml", alac)

            # Ghostty in omarchy
            gh = f"""palette = 0={ansi[0]}
palette = 1={ansi[1]}
palette = 2={ansi[2]}
palette = 3={ansi[3]}
palette = 4={ansi[4]}
palette = 5={ansi[5]}
palette = 6={ansi[6]}
palette = 7={ansi[7]}
palette = 8={ansi[8]}
palette = 9={ansi[9]}
palette = 10={ansi[10]}
palette = 11={ansi[11]}
palette = 12={ansi[12]}
palette = 13={ansi[13]}
palette = 14={ansi[14]}
palette = 15={ansi[15]}
background = {bg}
foreground = {fg}
cursor-color = {accent}
selection-background = {accent}
selection-foreground = {bg}
"""
            safe_write(OMARCHY_DIR / "ghostty.conf", gh)
        except Exception as e:
            print(f"[theme-manager] Omarchy mirror warning: {e}", file=sys.stderr)

    # 10. Neovim colorscheme state
    nvim_state_dir = HOME / ".local" / "state" / "nvim"
    nvim_map = {
        "afterglow": "rose-pine", "crimson": "monokai-pro", "solstice": "gruvbox",
        "verdant": "everforest", "frost": "e-ink", "cyber": "tokyonight-night",
        "astral": "nord", "abyss": "tokyonight-night", "serenity": "ayu-mirage",
        "cloudscape": "onedark"
    }
    safe_write(nvim_state_dir / "active_colorscheme", nvim_map.get(theme_name.lower(), "tokyonight-night"))

def safe_signal(proc_name, sig="SIGUSR1"):
    pkill = shutil.which("pkill")
    killall = shutil.which("killall")
    if pkill:
        subprocess.run([pkill, f"-{sig}", proc_name], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    elif killall:
        subprocess.run([killall, f"-{sig}", proc_name], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def safe_run(cmd, timeout=2.0):
    if not cmd:
        return
    bin_path = shutil.which(cmd[0])
    if bin_path:
        try:
            subprocess.run([bin_path] + cmd[1:], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=timeout)
        except Exception:
            pass

def broadcast_live_reloads(theme_name=""):
    """
    Notifies and signals all running desktop processes to hot-reload themes instantly.
    """
    # 1. Kitty Terminal live update (only if kitty process is actively running)
    is_kitty_running = False
    pkill = shutil.which("pgrep")
    if pkill:
        is_kitty_running = (subprocess.run([pkill, "-x", "kitty"], stdout=subprocess.DEVNULL).returncode == 0)
    if is_kitty_running:
        kitty_colors_path = str(ACTIVE_DIR / "kitty-colors.conf")
        safe_run(["kitty", "@", "set-colors", "--all", "--configured", kitty_colors_path], timeout=0.8)
        safe_signal("kitty", "SIGUSR1")

    # 2. Foot Terminal live update (reloads ~/.local/state/omarchy/current/theme/foot.ini)
    safe_signal("foot", "SIGUSR1")

    # 3. Hyprland reload (window borders, decorations)
    safe_run(["hyprctl", "reload"], timeout=1.5)

    # 4. Quickshell theme reload IPC
    safe_run(["quickshell", "ipc", "call", "notch", "reloadTheme"], timeout=1.5)

    # 5. Neovim live update
    safe_signal("nvim", "SIGUSR1")

    # 6. GTK3 / GTK4 reload
    safe_signal("xsettingsd", "HUP")
    safe_run(["gsettings", "set", "org.gnome.desktop.interface", "color-scheme", "prefer-dark"], timeout=1.0)

    # 7. Arch & Standalone Compositor & Notification daemons (Waybar, Dunst, Mako)
    safe_signal("waybar", "SIGUSR2")
    safe_run(["dunstctl", "reload"], timeout=1.0)
    safe_run(["makoctl", "reload"], timeout=1.0)

    # 8. User Custom Hooks (Runs any executable script in ~/.config/theme-hooks.d/ or ~/.config/dynamic-you/hooks/)
    hook_dirs = [
        HOME / ".config" / "theme-hooks.d",
        HOME / ".config" / "dynamic-you" / "hooks",
        Path("/etc/dynamic-you/hooks.d")
    ]
    cur_wall = ""
    wall_txt = ACTIVE_DIR / "current-wallpaper.txt"
    if wall_txt.is_file():
        try:
            cur_wall = wall_txt.read_text().strip()
        except Exception:
            pass

    hook_env = os.environ.copy()
    hook_env["DYNAMIC_YOU_THEME"] = theme_name
    hook_env["DYNAMIC_YOU_WALLPAPER"] = cur_wall

    for hdir in hook_dirs:
        if hdir.is_dir():
            for hook in sorted(hdir.iterdir()):
                if hook.is_file() and os.access(hook, os.X_OK):
                    try:
                        subprocess.Popen([str(hook), theme_name, cur_wall], env=hook_env,
                                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    except Exception as e:
                        print(f"[theme-manager] Warning: hook {hook.name} failed: {e}", file=sys.stderr)

    # 9. Desktop notification
    if theme_name and shutil.which("notify-send"):
        safe_run(["notify-send", "-a", "Theme Manager", "-i", "preferences-desktop-theme",
                  "Theme Applied", f"Activated {theme_name}"], timeout=1.0)

def apply_wallpaper_image(image_path, transition="simple"):
    """
    Applies desktop wallpaper across NixOS and Arch Linux using awww, swww, or hyprpaper.
    """
    image_path = str(Path(image_path).resolve())
    if not os.path.isfile(image_path):
        print(f"[theme-manager] Error: wallpaper not found at {image_path}", file=sys.stderr)
        return False

    ACTIVE_DIR.mkdir(parents=True, exist_ok=True)
    cur_wall_link = ACTIVE_DIR / "current-wallpaper"
    try:
        if cur_wall_link.is_symlink() or cur_wall_link.exists():
            cur_wall_link.unlink()
        cur_wall_link.symlink_to(image_path)
    except Exception:
        pass
    (ACTIVE_DIR / "current-wallpaper.txt").write_text(image_path)

    # 1. Transition wallpaper using awww if available (Primary on NixOS)
    awww_bin = shutil.which("awww")
    if awww_bin:
        check = subprocess.run(["pgrep", "-x", "awww-daemon"], stdout=subprocess.DEVNULL)
        if check.returncode != 0:
            subprocess.Popen(["awww-daemon"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            import time
            for _ in range(20):
                if subprocess.run([awww_bin, "query"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
                    break
                time.sleep(0.05)

        subprocess.Popen([
            awww_bin, "img", image_path,
            "--transition-type", transition,
            "--transition-fps", "144",
            "--transition-step", "240",
            "--transition-bezier", "0.25,0.1,0.25,1.0"
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return True

    # 2. Fallback to swww (Common on Arch Linux)
    swww_bin = shutil.which("swww")
    if swww_bin:
        check = subprocess.run(["pgrep", "-x", "swww-daemon"], stdout=subprocess.DEVNULL)
        if check.returncode != 0:
            subprocess.Popen(["swww-daemon"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            import time
            time.sleep(0.2)
        subprocess.Popen([swww_bin, "img", image_path, "--transition-type", transition],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return True

    # 3. Fallback to hyprpaper (Common on Arch Linux)
    hyprpaper_bin = shutil.which("hyprpaper")
    if hyprpaper_bin:
        subprocess.Popen(["hyprctl", "hyprpaper", "preload", image_path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        subprocess.Popen(["hyprctl", "hyprpaper", "wallpaper", f",{image_path}"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return True

    return True

def cmd_apply_theme(theme_name):
    print(f"[theme-manager] Applying theme: {theme_name}")
    theme_dir = find_theme_dir(theme_name)
    if not theme_dir:
        print(f"[theme-manager] Error: theme '{theme_name}' not found.", file=sys.stderr)
        return False

    actual_name = theme_dir.name
    # 1. Load preset colors from quickshell-colors.json or kitty-colors.conf
    palette = {}
    qs_json_file = theme_dir / "quickshell-colors.json"
    if qs_json_file.is_file():
        try:
            palette = json.loads(qs_json_file.read_text())
        except Exception:
            pass

    # Read ANSI colors from kitty-colors.conf if present
    kitty_file = theme_dir / "kitty-colors.conf"
    ansi_colors = []
    if kitty_file.is_file():
        k_text = kitty_file.read_text()
        for i in range(16):
            m = re.search(rf"^color{i}\s+([#0-9a-fA-F]+)", k_text, re.MULTILINE)
            if m:
                ansi_colors.append(m.group(1))
            else:
                ansi_colors.append(palette.get("accent", "#89b4fa"))
    if len(ansi_colors) == 16:
        palette["ansi"] = ansi_colors

    # Ensure required keys exist
    if "accent" not in palette:
        palette["accent"] = "#89b4fa"
    if "bg" not in palette:
        palette["bg"] = "#101014"
    if "card_bg" not in palette:
        palette["card_bg"] = adjust_lightness(palette["bg"], 1.4)
    if "hover_bg" not in palette:
        palette["hover_bg"] = adjust_lightness(palette["bg"], 1.8)
    if "border" not in palette:
        palette["border"] = adjust_lightness(palette["bg"], 2.5)
    if "border_hover" not in palette:
        palette["border_hover"] = palette["accent"]
    if "text_primary" not in palette:
        palette["text_primary"] = "#f8fafc"
    if "text_secondary" not in palette:
        palette["text_secondary"] = adjust_lightness(palette["text_primary"], 0.7)

    # 2. Check transition setting
    trans = "simple"
    trans_file = ACTIVE_DIR / "wallpaper-transition.txt"
    if trans_file.is_file():
        trans = trans_file.read_text().strip() or "simple"
    if trans == "random":
        trans = random.choice(["simple", "fade", "left", "right", "top", "bottom", "wipe", "wave", "outer"])

    # 3. Apply theme wallpaper if available
    wall = find_theme_wallpaper(actual_name)
    if wall:
        apply_wallpaper_image(wall, trans)

    # 4. Write all system configs
    write_theme_configs(palette, actual_name)

    # 5. Broadcast hot reloads
    broadcast_live_reloads(actual_name)
    print(f"[theme-manager] Theme '{actual_name}' applied successfully.")
    return True

def cmd_apply_wallpaper(wallpaper_path, transition="simple"):
    print(f"[theme-manager] Applying wallpaper and extracting dynamic colors: {wallpaper_path}")
    if not os.path.isfile(wallpaper_path):
        print(f"[theme-manager] Error: file not found: {wallpaper_path}", file=sys.stderr)
        return False

    # 1. Apply wallpaper
    apply_wallpaper_image(wallpaper_path, transition)

    # 2. Extract colors dynamically
    palette = extract_colors_from_wallpaper(wallpaper_path)
    theme_name = f"Wallpaper ({Path(wallpaper_path).stem})"

    # 3. Write all configurations
    write_theme_configs(palette, theme_name)

    # 4. Broadcast hot reloads
    broadcast_live_reloads(theme_name)
    print(f"[theme-manager] Dynamic wallpaper theme applied successfully.")
    return True

def main():
    if len(sys.argv) < 2:
        print("Usage:")
        print("  theme-manager.py apply-theme <ThemeName>")
        print("  theme-manager.py apply-wallpaper <WallpaperPath> [transition]")
        sys.exit(1)

    cmd = sys.argv[1]
    if cmd in ("apply-theme", "theme", "set-theme"):
        if len(sys.argv) < 3:
            print("Error: Theme name required.")
            sys.exit(1)
        ok = cmd_apply_theme(sys.argv[2])
        sys.exit(0 if ok else 1)
    elif cmd in ("apply-wallpaper", "wallpaper", "set-wallpaper", "wall"):
        if len(sys.argv) < 3:
            print("Error: Wallpaper path required.")
            sys.exit(1)
        trans = sys.argv[3] if len(sys.argv) > 3 else "simple"
        ok = cmd_apply_wallpaper(sys.argv[2], trans)
        sys.exit(0 if ok else 1)
    else:
        # Shorthand: theme-manager.py <ThemeName> or check if it's an image file
        if Path(cmd).is_file():
            ok = cmd_apply_wallpaper(cmd, "simple")
        else:
            ok = cmd_apply_theme(cmd)
        sys.exit(0 if ok else 1)

if __name__ == "__main__":
    main()
