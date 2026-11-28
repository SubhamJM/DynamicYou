#!/usr/bin/env python3
"""Apply a Dynamic You preset to KDE and qt6ct."""
import configparser
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile


FOLDER_COLORS = {
    "abyss": "cyan",
    "afterglow": "violet",
    "crimson": "red",
    "frost": "grey",
    "solstice": "yellow",
    "verdant": "green",
}


def write(path, contents):
    """Publish a complete config file and leave unchanged files alone."""
    path = path.resolve()
    if path.is_file() and path.read_text() == contents:
        return False
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as temp:
        temp.write(contents)
    Path(temp.name).replace(path)
    return True


def update_groups(path, groups, replace_groups=()):
    """Update specific INI keys while preserving KDE group syntax and other settings."""
    original = path.read_text() if path.is_file() else ""
    blocks = re.split(r"(?m)(?=^\[)", original)
    pending = groups.copy()
    for index, block in enumerate(blocks):
        heading, _, body = block.partition("\n")
        if not heading.startswith("["):
            continue
        group = heading.strip()[1:-1]
        if group not in pending:
            continue
        values = pending.pop(group)
        keep = [] if group in replace_groups else [
            line for line in body.splitlines()
            if line.partition("=")[0].split("[", 1)[0].strip() not in values
        ]
        blocks[index] = ini_group(group, values, keep)
    blocks.extend(ini_group(group, values) for group, values in pending.items())
    return write(path, "\n\n".join(block.rstrip() for block in blocks if block.strip()) + "\n")


def ini_group(group, values, keep=()):
    lines = [f"[{group}]", "\n".join(keep).rstrip(), *(f"{key}={value}" for key, value in values.items())]
    if not lines[1]:
        lines.pop(1)
    return "\n".join(lines) + "\n"


def kde_palette(colors):
    bg, card, hover, text, muted, accent, visited = colors
    ink = "#101014"

    def rgb(value):
        return ",".join(str(int(value[i:i + 2], 16)) for i in (1, 3, 5))

    def roles(base, alternate, foreground=text, secondary=muted, link=accent):
        return {key: rgb(value) for key, value in {
            "BackgroundNormal": base, "BackgroundAlternate": alternate,
            "ForegroundNormal": foreground, "ForegroundInactive": secondary,
            "ForegroundActive": link, "ForegroundLink": link, "ForegroundVisited": visited,
            "ForegroundNegative": "#ff9b9b", "ForegroundNeutral": "#ffc47f",
            "ForegroundPositive": "#86daa3", "DecorationFocus": accent,
            "DecorationHover": accent,
        }.items()}

    return {
        "Colors:View": roles(bg, card),
        "Colors:Window": roles(card, hover),
        "Colors:Button": roles(card, hover),
        "Colors:Selection": roles(accent, accent, ink, ink, ink),
        "Colors:Tooltip": roles(card, hover),
        "Colors:Header": roles(card, hover),
        "Colors:Header][Inactive": roles(card, hover),
        "Colors:Complementary": roles(card, hover),
        "Colors:Menu": roles(card, hover),
        "ColorEffects:Inactive": {"Enable": "false", "ChangeSelectionColor": "true"},
        "ColorEffects:Disabled": {"Enable": "true", "Color": rgb(bg), "ColorEffect": "0",
                                  "IntensityEffect": "0", "ContrastEffect": "1",
                                  "ContrastAmount": "0.55"},
    }


def qt_palette(colors):
    bg, card, hover, text, muted, accent, visited = colors
    # Colors in QPalette::ColorRole order, including Accent at the end.
    active = [text, card, hover, hover, bg, card, text, text, text, bg, card,
              "#000000", accent, "#101014", accent, visited, card, bg, card, text, muted, accent]
    disabled = active.copy()
    for role in (0, 6, 7, 8, 13, 14, 15, 19, 20):
        disabled[role] = muted
    disabled[12] = hover
    return {"ColorScheme": {
        f"{state}_colors": ", ".join("#ff" + value[1:] for value in palette)
        for state, palette in (("active", active), ("inactive", active), ("disabled", disabled))
    }}


def papirus_variant(data_dir, color):
    """Create a small icon theme that inherits Papirus Dark and overrides folders."""
    source = Path("/usr/share/icons/Papirus-Dark")
    if not (source / "index.theme").is_file():
        return None
    base = configparser.ConfigParser(interpolation=None)
    base.optionxform = str
    base.read(source / "index.theme")
    name = f"DynamicYou-Papirus-{color}"
    destination = data_dir / "icons" / name
    theme = {"Name": f"Dynamic You Papirus ({color})", "Inherits": "Papirus-Dark",
             "FollowsColorScheme": "true", "Example": "folder"}
    groups = {"Icon Theme": theme}
    for key in ("Directories", "ScaledDirectories"):
        used = []
        for entry in base["Icon Theme"].get(key, "").split(","):
            if not entry.endswith("/places"):
                continue
            directory = source / entry
            aliases = {}
            for icon in directory.glob("*.svg"):
                if not icon.is_symlink():
                    continue
                target = icon.readlink().name
                if target.startswith(("folder-blue", "user-blue-")):
                    variant = icon.with_name(target.replace("-blue", f"-{color}", 1))
                    if variant.is_file():
                        aliases[icon.name] = variant
            if "folder.svg" in aliases:
                aliases["inode-directory.svg"] = aliases["folder.svg"]
            if not aliases:
                continue
            overlay = destination / entry
            overlay.mkdir(parents=True, exist_ok=True)
            for alias, target in aliases.items():
                link = overlay / alias
                if not link.exists() and not link.is_symlink():
                    link.symlink_to(target)
            groups[entry] = dict(base[entry])
            used.append(entry)
        if used:
            theme[key] = ",".join(used)
    write(destination / "index.theme", "\n".join(ini_group(group, values) for group, values in groups.items()))
    return name


def notify(interface, path, member, *values):
    if os.environ.get("DBUS_SESSION_BUS_ADDRESS") and shutil.which("busctl"):
        subprocess.run(["busctl", "--user", "emit", path, interface, member,
                        "i" * len(values), *map(str, values)], check=False)


def set_dolphin_scale(data_dir):
    # Dolphin inherits Quickshell's 1.2x scale when opened from the app launcher.
    # Use the monitor's native scale through the usual Dolphin desktop entry.
    destination = data_dir / "applications/org.kde.dolphin.desktop"
    source = destination if destination.is_file() else Path("/usr/share/applications/org.kde.dolphin.desktop")
    if source.is_file():
        original = source.read_text()
        updated = re.sub(r"(?m)^Exec=((?:/usr/bin/)?dolphin)(?=\s|$)",
                         r"Exec=env QT_SCALE_FACTOR=1 \1", original)
        if updated != original:
            write(destination, updated)


def main():
    config = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
    data_dir = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share")
    settings_path = config / "dynamic-you/install.json"
    settings = json.loads(settings_path.read_text()) if settings_path.is_file() else {}
    choices = settings.get("integrations", {})
    if choices.get("kde") is False:
        return

    active = config / "active-theme"
    if not (active / "theme-name.txt").is_file() or not (active / "quickshell-colors.json").is_file():
        return
    theme = (active / "theme-name.txt").read_text().strip()
    preset = json.loads((active / "quickshell-colors.json").read_text())
    colors = [preset[key] for key in (
        "bg", "card_bg", "hover_bg", "text_primary", "text_secondary",
        "accent", "secondary_accent",
    )]
    scheme_name = "DynamicYou"
    groups = kde_palette(colors)
    scheme = {"General": {"Name": "Dynamic You"}, **groups}
    write(data_dir / "color-schemes" / f"{scheme_name}.colors",
          "\n".join(ini_group(group, values) for group, values in scheme.items()))
    icons = papirus_variant(data_dir, FOLDER_COLORS.get(theme.lower(), "blue"))
    set_dolphin_scale(data_dir)
    config_groups = {
        **groups,
        "General": {"ColorScheme": scheme_name, "ColorSchemeHash": "@Invalid()", "AccentColor": "0,0,0,0"},
        "UiSettings": {"ColorScheme": scheme_name},
    }
    if icons:
        config_groups["Icons"] = {"Theme": icons}
    update_groups(config / "kdeglobals", config_groups, replace_groups=groups)

    qt_config = config / "qt6ct/qt6ct.conf"
    if (choices.get("qt6ct") or os.environ.get("QT_QPA_PLATFORMTHEME") == "qt6ct"
            or (choices.get("qt6ct") is not False and qt_config.is_file())):
        palette = config / "qt6ct/colors/DynamicYou.conf"
        palette_changed = write(palette, ini_group("ColorScheme", qt_palette(colors)["ColorScheme"]))
        appearance = {"custom_palette": "true", "color_scheme_path": str(palette)}
        if icons:
            appearance["icon_theme"] = icons
        qt_changed = update_groups(qt_config, {"Appearance": appearance})
        if palette_changed and not qt_changed:
            # qt6ct watches its config directory rather than the palette file.
            with tempfile.NamedTemporaryFile(dir=qt_config.parent, prefix=".theme-change-"):
                pass

    notify("org.kde.KGlobalSettings", "/KGlobalSettings", "notifyChange", 0, 0)
    if icons:
        for group in range(6):
            notify("org.kde.KIconLoader", "/KIconLoader", "iconChanged", group)


if __name__ == "__main__":
    main()
