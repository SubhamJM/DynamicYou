#!/usr/bin/env python3
"""Publish the current Dynamic You preset to Zen's active profile."""
import json
import os
from pathlib import Path
import re
import sys

config = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
settings = config / "dynamic-you/install.json"
if settings.is_file() and json.loads(settings.read_text()).get("integrations", {}).get("zen") is False:
    sys.exit(0)
support = config / "quickshell/scripts/matugen"
sys.path.insert(0, str(support))
from update import add_import, write, zen_profile

profile = zen_profile()
if profile is None:
    sys.exit(0)
palette_path = config / "active-theme/quickshell-colors.json"
if not palette_path.is_file():
    sys.exit(0)
palette = json.loads(palette_path.read_text())
chrome = profile / "chrome"
compatible = (chrome / "JS/lucid-zen.sys.mjs").is_file()
filename = "lucid-zen.css" if compatible else "dynamic-you-zen.css"
target = chrome / filename
if target.is_file() and not (chrome / (filename + ".preset-backup")).exists():
    write(chrome / (filename + ".preset-backup"), target.read_text())
template = (support / "templates/zen-userchrome.css").read_text()
roles = {
    "surface_container": palette["card_bg"],
    "surface_container_highest": palette["hover_bg"],
    "surface_container_lowest": palette["bg"],
    "surface_container_low": palette["bg"],
    "surface_container_high": palette["card_bg"],
    "surface": palette["bg"],
    "on_surface": palette["text_primary"],
    "on_surface_variant": palette["text_secondary"],
    "primary": palette["accent"],
    "on_primary": "#101014",
    "secondary_container": palette["hover_bg"],
    "outline_variant": palette["border"],
}
template = re.sub(r"<\* if.*?\*>(.*?)<\* else \*>.*?<\* endif \*>", r"\1", template, flags=re.S)
template = re.sub(r"{{colors\.([a-z_]+)\.default\.hex}}", lambda m: roles[m[1]], template)
template = template.replace("{{mode}}", "dark")
write(target, template)
add_import(chrome / "userChrome.css", filename)

prefs = profile / "user.js"
current = prefs.read_text() if prefs.is_file() else ""
key = "toolkit.legacyUserProfileCustomizations.stylesheets"
setting = f'user_pref("{key}", true);'
pattern = r'user_pref\(\s*"' + re.escape(key) + r'"\s*,\s*(true|false)\s*\);'
if re.search(pattern, current):
    current = re.sub(pattern, setting, current)
else:
    current += "\n" + setting + "\n"
write(prefs, current)

# Profiles using Fx AutoConfig can reload palettes immediately.
if not compatible and (chrome / "utils/boot.sys.mjs").is_file():
    write(chrome / "JS/dynamic-you-zen.sys.mjs", (support / "zen-live.sys.mjs").read_text())
print(f"Zen preset applied to {profile.name}")
