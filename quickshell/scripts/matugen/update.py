#!/usr/bin/env python3
"""Derive one wallpaper palette and publish it to Dynamic You and its apps."""

import argparse
import configparser
from copy import deepcopy
import fcntl
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import uuid

sys.dont_write_bytecode = True
from surfaces import app_surfaces

HERE = Path(__file__).resolve().parent
HOME = Path.home()
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME") or HOME / ".config")
CACHE = Path(os.environ.get("XDG_CACHE_HOME") or HOME / ".cache")
DATA = Path(os.environ.get("XDG_DATA_HOME") or HOME / ".local/share")
STATE = CACHE / "dynamic-you"
SETTINGS = CONFIG / "dynamic-you/matugen.json"
ACTIVE = CONFIG / "active-theme"
TAPE = (HERE.parents[2] / "tape.toml").is_file()
SCHEMES = {"content", "expressive", "fidelity", "fruit-salad", "monochrome", "neutral",
           "rainbow", "tonal-spot", "vibrant"}
HEX = re.compile(r"#[0-9a-fA-F]{6}")


def read_json(path):
    try:
        data = json.loads(path.read_text())
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def write(path, text):
    if not path.is_symlink() and path.exists() and path.read_text(encoding="utf-8") == text:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=path.parent, delete=False) as file:
        temporary = Path(file.name)
        file.write(text)
    try:
        temporary.replace(path)
    finally:
        temporary.unlink(missing_ok=True)


def quiet(*command):
    if shutil.which(command[0]):
        try:
            subprocess.run(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False, timeout=5)
        except (OSError, subprocess.SubprocessError):
            pass


def report(error):
    print(f"Dynamic You colors: {error}", file=sys.stderr)


def options(image, prefs):
    scheme = prefs.get("scheme")
    if not isinstance(scheme, str) or scheme.removeprefix("scheme-") not in SCHEMES:
        scheme = "scheme-tonal-spot"
    if not scheme.startswith("scheme-"):
        scheme = "scheme-" + scheme
    contrast = prefs.get("contrast", 0)
    if type(contrast) not in (int, float) or not -1 <= contrast <= 1:
        contrast = 0
    mode = prefs.get("mode", "dark")
    if mode == "auto" and shutil.which("magick"):
        try:
            result = subprocess.check_output(
                ["magick", "-define", "jpeg:size=128x128", f"{image}[0]", "-resize",
                 "64x64!", "-colorspace", "Gray", "-format", "%[fx:mean]", "info:"],
                env={**os.environ, "MAGICK_THREAD_LIMIT": "2"}, stderr=subprocess.DEVNULL,
                timeout=10, text=True)
            mode = "light" if float(result) > 0.5 else "dark"
        except (OSError, ValueError, subprocess.SubprocessError):
            mode = "dark"
    if mode not in ("light", "dark"):
        mode = "dark"
    index = prefs.get("sourceIndex", 0)
    if prefs.get("sourceImage") != str(image) or type(index) is not int or not 0 <= index <= 3:
        index = 0
    tint = prefs.get("surfaceTint", 0.7)
    if type(tint) not in (int, float) or not math.isfinite(tint) or tint < 0:
        tint = 0.7
    return mode, scheme, contrast, index, tint


def derive(image, config, mode, scheme, contrast, index):
    command = ["matugen", "-c", str(config), "image", str(image), "-m", mode, "-t", scheme,
               "--contrast", str(contrast), "--dry-run", "--json", "hex", "-q",
               "--include-image-in-json", "true", "--source-color-index"]
    for candidate in dict.fromkeys((index, 0)):
        result = subprocess.run(command + [str(candidate)], text=True, capture_output=True,
                                check=False, timeout=45)
        if result.returncode == 0:
            return json.loads(result.stdout)
    raise ValueError(result.stderr.strip() or "Matugen could not read the wallpaper")


def roles(scheme):
    return {
        name: value["default"]["color"]
        for name, value in scheme["colors"].items()
        if isinstance(value, dict) and isinstance(value.get("default"), dict)
        and isinstance(value["default"].get("color"), str)
        and HEX.fullmatch(value["default"]["color"])
    }


def render(work, scheme, mode, template):
    output = work / "app-output"
    output.unlink(missing_ok=True)
    config = work / "render.toml"
    config.write_text("[config]\n[templates.app]\n"
                      f"input_path = {json.dumps(str(HERE / 'templates' / template))}\n"
                      f"output_path = {json.dumps(str(output))}\n")
    result = subprocess.run(["matugen", "-c", str(config), "json", str(scheme), "-m", mode, "-q"],
                            capture_output=True, text=True, check=False, timeout=15)
    if result.returncode:
        raise ValueError(f"{template}: {result.stderr.strip()}")
    return output.read_text()


def zen_profile():
    configured = os.environ.get("ZEN_ROOT")
    roots = [Path(configured)] if configured else [
        CONFIG / "zen", HOME / ".zen",
        HOME / ".var/app/app.zen_browser.zen/config/zen",
        HOME / ".var/app/app.zen_browser.zen/.zen",
    ]
    for root in roots:
        for filename in ("installs.ini", "profiles.ini"):
            parser = configparser.ConfigParser(interpolation=None)
            try:
                parser.read(root / filename)
            except configparser.Error:
                continue
            defaults = [parser[section].get("Default") for section in parser.sections()
                        if filename == "installs.ini" or section.startswith("Install")]
            if filename == "profiles.ini":
                defaults += [parser[section].get("Path") for section in parser.sections()
                             if section.startswith("Profile") and parser[section].get("Default") == "1"]
            for default in filter(None, defaults):
                path = root / default
                if path.is_dir():
                    return path
    return None


def add_import(path, target):
    old = path.read_text() if path.exists() else ""
    if re.search(r"@import[^;]*" + re.escape(target) + r"""[\x27\x22)]""", old):
        return
    directive = f'@import url("{target}");\n'
    charset = re.match(r'^\s*@charset[^;]+;[^\n]*\n?', old)
    pos = charset.end() if charset else 0
    updated = old[:pos] + directive + old[pos:]
    if path.is_symlink():
        path = path.resolve()
    write(path, updated)


def restore_destination(path):
    # Tapes swaps the original config back before running eject hooks.
    # Paths resolved through its staging tree must point to the live config.
    staging = CONFIG.with_name(CONFIG.name + ".tapes")
    if path.is_relative_to(staging):
        return CONFIG / path.relative_to(staging)
    return path


def remember_shared(path):
    if not TAPE:
        return
    directory = STATE / "tape-restore"
    directory.mkdir(parents=True, exist_ok=True)
    index = directory / "files.json"
    files = read_json(index)
    key = str(restore_destination(path))
    if key in files:
        return
    saved = directory / str(len(files))
    if path.is_file():
        write(saved, path.read_text())
        files[key] = saved.name
    else:
        files[key] = None
    write(index, json.dumps(files))


def restore_shared():
    directory = STATE / "tape-restore"
    index = directory / "files.json"
    for destination, filename in read_json(index).items():
        path = restore_destination(Path(destination))
        if filename is None:
            path.unlink(missing_ok=True)
        else:
            saved = directory / filename
            write(path, saved.read_text())
    if directory.is_dir():
        shutil.rmtree(directory)


def update_zen(profile, work, scheme, mode):
    if profile is None:
        return
    prefs = profile / "user.js"
    current = prefs.read_text() if prefs.exists() else ""
    key = "toolkit.legacyUserProfileCustomizations.stylesheets"
    if not re.search(r'user_pref\(\s*"' + re.escape(key) + r'"', current):
        remember_shared(prefs.resolve())
        with prefs.open("a", encoding="utf-8") as file:
            file.write(f'\nuser_pref("{key}", true);\n')
    chrome = profile / "chrome"
    # An existing Lucid live reloader expects these names. Fresh profiles get
    # owned imports that work through Zen's native CSS support.
    live = (chrome / "JS/lucid-zen.sys.mjs").is_file() and not (chrome / "JS/dynamic-you-zen.sys.mjs").is_file()
    if live:
        css = ("lucid-zen.css", "lucid-sites.css")
    else:
        css = ("dynamic-you-zen.css", "dynamic-you-sites.css")
    for template, output, entry in (
        ("zen-userchrome.css", css[0], "userChrome.css"),
        ("zen-sites.css", css[1], "userContent.css"),
    ):
        rendered = render(work, scheme, mode, template)
        remember_shared(chrome / output)
        remember_shared((chrome / entry).resolve())
        write(chrome / output, rendered)
        add_import(chrome / entry, output)


def publish_apps(work, scheme, mode, prefs):
    targets = [
        ("kitty.conf", STATE / "kitty.conf"),
        ("gtk-colors.css", STATE / "gtk.css"),
        ("qt6ct-colors.conf", CONFIG / "qt6ct/colors/DynamicYou.conf"),
        ("kde-colors.colors", DATA / "color-schemes/DynamicYou.colors"),
        ("midnight-discord.css", CONFIG / "vesktop/themes/dynamic-you.css"),
        ("vscode-colors", CACHE / "matugen/vscode-colors"),
        ("vscode-colors.json", CACHE / "matugen/vscode-colors.json"),
    ]
    errors = []
    for template, path in targets:
        try:
            rendered = render(work, scheme, mode, template)
            if path.parent == CACHE / "matugen":
                remember_shared(path)
            write(path, rendered)
        except (OSError, ValueError, subprocess.SubprocessError) as error:
            errors.append(str(error))
    try:
        update_zen(zen_profile(), work, scheme, mode)
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        errors.append(str(error))
    try:
        enable_app_includes()
        update_prompt(roles(json.loads(scheme.read_text())))
    except OSError as error:
        errors.append(str(error))
    if not prefs.get("reloadApps", True):
        return errors
    # Kitty's supplied config loads the generated file on startup. Existing
    # instances reread their config. A socket is optional for custom configs.
    quiet("pkill", "-USR1", "-u", str(os.getuid()), "-x", "kitty")
    sockets = [value for value in (os.environ.get("KITTY_LISTEN_ON"), prefs.get("kittySocket")) if value]
    for socket in dict.fromkeys(value for value in sockets if isinstance(value, str)):
        if isinstance(socket, str) and socket.startswith("unix:"):
            quiet("kitty", "@", "--to", socket, "set-colors", "--all", "--configured", str(STATE / "kitty.conf"))
    if not TAPE:
        quiet("gsettings", "set", "org.gnome.desktop.interface", "color-scheme", f"prefer-{mode}")
    return errors


def update_prompt(palette):
    path = Path(os.environ.get("STARSHIP_CONFIG") or CONFIG / "starship.toml").resolve()
    if not path.is_file():
        return
    text = path.read_text()
    active = re.search(r"""(?m)^\s*palette\s*=\s*["']([\w-]+)["']""", text)
    if not active:
        return
    table = re.search(r"(?m)^\[palettes\." + re.escape(active[1]) + r"\] *$", text)
    if not table:
        return
    tail = text[table.end():]
    next_table = re.search(r"(?m)^\s*\[", tail)
    end = table.end() + next_table.start() if next_table else len(text)
    colors = {
        "color1": "primary_fixed_dim", "color2": "on_primary", "color3": "on_surface_variant",
        "color4": "surface_container", "color5": "on_primary", "color6": "surface_dim",
        "color7": "surface", "color8": "primary", "color9": "primary",
        "bg": "surface", "mantle": "surface_container_low", "crust": "surface_container_lowest",
        "surface0": "surface_container", "surface1": "surface_container_high",
        "surface2": "surface_container_highest", "overlay0": "outline", "text": "on_surface",
        "subtext": "on_surface_variant", "lavender": "primary", "mauve": "tertiary",
        "blue": "secondary", "red": "error", "green": "primary", "yellow": "secondary_fixed_dim",
    }

    def repaint(match):
        color = palette.get(colors.get(match[2]))
        return match[1] + match[3] + color + match[3] if color else match[0]

    updated = re.sub(r"""(?m)^(\s*([\w-]+)\s*=\s*)(["'])(#[0-9a-fA-F]{6})\3""",
                     repaint, text[table.end():end])
    if updated != text[table.end():end]:
        remember_shared(path)
        write(path, text[:table.end()] + updated + text[end:])


def enable_kitty_palette():
    config = Path(os.environ.get("KITTY_CONFIG_DIRECTORY") or CONFIG / "kitty") / "kitty.conf"
    local_palette = config.parent / "dynamic-you-wallpaper.generated.conf"
    config.parent.mkdir(parents=True, exist_ok=True)
    if local_palette.is_symlink():
        if local_palette.readlink() != STATE / "kitty.conf":
            local_palette.unlink()
            local_palette.symlink_to(STATE / "kitty.conf")
    elif not local_palette.exists():
        local_palette.symlink_to(STATE / "kitty.conf")

    original = config.read_text(encoding="utf-8") if config.is_file() else ""
    # Kitty glob patterns must be relative to the config directory. Migrate
    # the absolute pattern emitted by the first version of the palette port.
    command = f"globinclude {local_palette.name}"
    old_pattern = re.compile(
        r"^[ \t]*globinclude[ \t]+(?:/|~/).*?/dynamic-you/kitty\.conf[ \t]*$", re.MULTILINE
    )
    updated = old_pattern.sub(lambda _: command, original)
    lines = updated.splitlines(keepends=True)
    matches = [index for index, line in enumerate(lines) if line.strip() == command]
    for index in reversed(matches[1:]):
        del lines[index]
    updated = "".join(lines)
    if not matches:
        updated = updated.rstrip("\n") + ("\n\n" if updated else "") + command + "\n"
    if updated != original:
        write(config.resolve(), updated)


def enable_app_includes():
    enable_kitty_palette()
    for toolkit in ("gtk-3.0", "gtk-4.0"):
        add_import(CONFIG / toolkit / "gtk.css", (STATE / "gtk.css").as_uri())


def deactivate():
    if not STATE.is_dir():
        return
    write(STATE / "requested", uuid.uuid4().hex)
    with (STATE / "update.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        restore_shared()
        for name in ("palette.json", "material.json", "hypr-colors"):
            (STATE / name).unlink(missing_ok=True)
        # Keep the include target valid for Kitty and GTK when the tape is off.
        kitty = STATE / "kitty.conf"
        if kitty.is_file():
            write(kitty, "# Dynamic You wallpaper palette is inactive.\n")
        # User stylesheet imports can safely stay in place between tape uses.
        if (STATE / "gtk.css").is_file():
            write(STATE / "gtk.css", "/* Dynamic You wallpaper palette is inactive. */\n")
        if read_json(SETTINGS).get("reloadApps", True):
            quiet("pkill", "-USR1", "-u", str(os.getuid()), "-x", "kitty")


def current_request(ticket, image):
    if (STATE / "requested").read_text() != ticket:
        return False
    # The active config can change while a tape is being ejected.
    return (CONFIG / "quickshell/scripts/matugen").resolve() == HERE and image.is_file()


def apply(image):
    prefs = read_json(SETTINGS)
    if prefs.get("enabled") is False:
        deactivate()
        if prefs.get("reloadApps", True):
            quiet("hyprctl", "reload")
        return 0
    if not shutil.which("matugen"):
        report("Matugen is missing. The wallpaper still applies.")
        return 1
    STATE.mkdir(parents=True, exist_ok=True)
    ticket = uuid.uuid4().hex
    write(STATE / "requested", ticket)
    with (STATE / "update.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if not current_request(ticket, image):
            return 0
        mode, scheme_type, contrast, index, tint = options(image, prefs)
        image_info = image.stat()
        key = [str(image), image_info.st_mtime_ns, image_info.st_size, mode, scheme_type, contrast, index, tint]
        saved = read_json(STATE / "palette.json")
        with tempfile.TemporaryDirectory(prefix="render-", dir=STATE) as tmp:
            work = Path(tmp)
            config = work / "empty.toml"
            config.write_text("[config]\n[templates]\n")
            scheme = read_json(STATE / "scheme.json") if saved.get("request") == key else {}
            if not scheme:
                scheme = derive(image, config, mode, scheme_type, contrast, index)
            palette = roles(scheme)
            for required in ("primary", "surface", "on_surface", "outline"):
                if required not in palette:
                    raise ValueError(f"Matugen returned no {required} color")
            if not current_request(ticket, image):
                return 0

            # Publish the shell palette first, then render apps off the same
            # result. Lucid softens light surfaces before handing them to apps.
            softened = app_surfaces(palette, tint) if mode == "light" else palette
            write(STATE / "scheme.json", json.dumps(scheme))
            write(STATE / "material.json", json.dumps(palette))
            write(STATE / "palette.json", json.dumps({**softened, "mode": mode, "request": key}))
            write(STATE / "hypr-colors", f"{palette['primary'][1:]} {palette['outline'][1:]}\n")
            if prefs.get("reloadApps", True):
                quiet("hyprctl", "eval", "hl.config({general={col={active_border='rgb("
                      + palette["primary"][1:] + ")', inactive_border='rgb("
                      + palette["outline"][1:] + ")'}}})")
            apps = deepcopy(scheme)
            for role, color in softened.items():
                if color != palette[role]:
                    for variant in ("default", "light"):
                        if variant in apps["colors"][role]:
                            apps["colors"][role][variant]["color"] = color
            app_scheme = work / "apps.json"
            app_scheme.write_text(json.dumps(apps))
            if not current_request(ticket, image):
                return 0
            for error in publish_apps(work, app_scheme, mode, prefs):
                report(error)
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    actions = parser.add_mutually_exclusive_group()
    actions.add_argument("--deactivate", action="store_true")
    actions.add_argument("--install-zen-live", action="store_true",
                         help="install the palette watcher into an existing Fx AutoConfig profile")
    parser.add_argument("image", nargs="?", type=Path)
    options = parser.parse_args()
    try:
        if options.deactivate:
            deactivate()
            return 0
        if options.install_zen_live:
            profile = zen_profile()
            if not profile or not (profile / "chrome/utils/boot.sys.mjs").is_file():
                raise ValueError("Zen live updates require a Zen profile with Fx AutoConfig already enabled")
            chrome = profile / "chrome"
            if (chrome / "JS/lucid-zen.sys.mjs").is_file():
                print("Zen already has the compatible Lucid palette watcher.")
            else:
                write(chrome / "JS/dynamic-you-zen.sys.mjs", (HERE / "zen-live.sys.mjs").read_text())
                print("Restart Zen once to load the Dynamic You palette watcher.")
            return 0
        image = (options.image or ACTIVE / "current-wallpaper").expanduser().resolve(strict=True)
        if not image.is_file():
            raise ValueError("the wallpaper must be an image file")
        return apply(image)
    except (KeyError, OSError, TypeError, ValueError, subprocess.SubprocessError) as error:
        report(error)
        return 1


if __name__ == "__main__":
    sys.exit(main())
