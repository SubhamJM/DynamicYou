#!/usr/bin/env python3
"""Install Dynamic You with a preview, per-application consent and rollback."""

import argparse
from contextlib import contextmanager
from dataclasses import dataclass
import fcntl
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
sys.dont_write_bytecode = True
sys.path.insert(0, str(ROOT / "quickshell/scripts/matugen"))
from backups import Backup, backup_root, copy, exists, replace


HOME = Path.home()
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME") or HOME / ".config")
DATA = Path(os.environ.get("XDG_DATA_HOME") or HOME / ".local/share")
BIN = Path(os.environ.get("XDG_BIN_HOME") or HOME / ".local/bin")
SETTINGS = CONFIG / "dynamic-you/install.json"
LEGACY_SETTINGS = CONFIG / "dynamic-you/matugen.json"
APPS = {
    "kitty": "Kitty terminal colors",
    "zen": "Zen Browser and supported site colors",
    "gtk": "GTK application colors",
    "starship": "the current Starship prompt palette",
    "qt6ct": "a selectable qt6ct palette",
    "kde": "a selectable KDE color scheme",
    "vesktop": "a selectable Vesktop theme",
    "vscode": "VS Code / VSCodium Matugen color caches",
}


def preferences():
    source = SETTINGS if SETTINGS.is_file() else LEGACY_SETTINGS
    if not source.is_file():
        return {}
    data = json.loads(source.read_text())
    if not isinstance(data, dict):
        raise ValueError(f"Expected a JSON object in {source}")
    return data


def confirm(prompt, default=False):
    try:
        answer = input(f"{prompt} {'[Y/n]' if default else '[y/N]'} ").strip().lower()
    except EOFError:
        return False
    return default if not answer else answer in ("yes", "y")


def integration_choices(args, previous):
    saved = previous.get("integrations", {})
    enabled = {app: isinstance(saved, dict) and saved.get(app) is True for app in APPS}
    if args.apps is not None:
        names = set(args.apps.split(","))
        if names == {"all"}:
            names = set(APPS)
        elif names == {"none"}:
            names = set()
        if names - APPS.keys():
            raise ValueError(f"Unknown app integration(s): {', '.join(sorted(names - APPS.keys()))}")
        return {app: app in names for app in APPS}
    if sys.stdin.isatty() and not (args.yes or args.dry_run):
        print("Choose which apps should follow the Dynamic You theme.")
        for app, label in APPS.items():
            enabled[app] = confirm(f"Use Dynamic You colors for {label}?", enabled[app])
    return enabled


def is_tape():
    root = (HOME / ".tapes").resolve()
    return any((CONFIG / name).resolve().is_relative_to(root)
               for name in ("hypr", "quickshell", "active-theme"))


@contextmanager
def locked():
    directory = backup_root()
    directory.mkdir(parents=True, exist_ok=True)
    with (directory / ".lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        yield


@dataclass(frozen=True)
class Change:
    target: Path
    source: Path | None
    action: str


def install_plan():
    module_names = [
        "hypr", "quickshell", "scripts", "themes",
        "kitty", "fastfetch", "fish", "nvim", "yazi", "krabby", "eza"
    ]
    changes = [Change(CONFIG / name, ROOT / name, "install")
               for name in module_names if (ROOT / name).exists()]
    if (ROOT / "starship.toml").is_file():
        changes.append(Change(CONFIG / "starship.toml", ROOT / "starship.toml", "install"))
    if (ROOT / "gtk/gtk-3.0").is_dir():
        changes.append(Change(CONFIG / "gtk-3.0", ROOT / "gtk/gtk-3.0", "install"))
    if (ROOT / "gtk/gtk-4.0").is_dir():
        changes.append(Change(CONFIG / "gtk-4.0", ROOT / "gtk/gtk-4.0", "install"))
    icon_fonts = ROOT / "quickshell/assets/fonts"
    if (icon_fonts / "MaterialSymbolsRounded.ttf").is_file():
        changes.append(Change(DATA / "fonts/dynamic-you", icon_fonts, "install"))
    changes.extend((Change(CONFIG / "active-theme", None, "initialize"),
                    Change(SETTINGS, None, "save app choices")))
    optional_links = {
        HOME / "Pictures/Wallpapers": ROOT / "Wallpapers",
        DATA / "quickshell-lockscreen": ROOT / "lockscreen",
        BIN / "lock-screen.sh": DATA / "quickshell-lockscreen/lock.sh",
        BIN / "hotspot": CONFIG / "scripts/hotspot.sh",
    }
    for name in ("apply-theme.sh", "init-wallpaper.sh", "osd-control.sh", "screenshot.sh"):
        optional_links[BIN / name] = CONFIG / "scripts" / name
    changes.extend(Change(dest, source, "keep" if exists(dest) else "link")
                   for dest, source in optional_links.items())
    return changes


def print_plan(changes, selected, deps):
    for change in changes:
        backup = " (back up existing)" if change.action not in ("keep", "link") and exists(change.target) else ""
        print(f"  {change.action:16} {change.target}{backup}")
    print("  App colors: " + (", ".join(app for app in APPS if selected[app]) or "none"))
    print("  Arch packages: " + ("install missing packages" if deps else "no package changes"))
    print(f"  Backups: {backup_root()}")


def retain_extras(source, stage, relative=Path(), skip_legacy=False):
    """Keep unrelated files and named configs when a packaged tree is updated."""
    if not source.is_dir():
        return
    for child in source.iterdir():
        position = stage / child.name
        path = relative / child.name
        if skip_legacy and path == Path("hyprland.conf"):
            # Keep the legacy entry in the backup so the new Lua entry is unambiguous.
            continue
        if not exists(position):
            copy(child, position)
        elif child.is_dir() and position.is_dir() and not (child.is_symlink() or position.is_symlink()):
            retain_extras(child, position, path, skip_legacy)


def initialize_theme(stage, old):
    stage.mkdir()
    retain_extras(old, stage)
    fallback = ROOT / "themes/Abyss"
    for name in ("hypr-colors.lua", "hyprland-colors.conf", "kitty-colors.conf",
                 "quickshell-colors.json", "starship-colors.toml", "theme-name.txt"):
        destination = stage / name
        if (old / name).is_file() and destination.is_symlink():
            # Materialize preset files so updates never write through into another config.
            destination.unlink()
            copy((old / name).resolve(), destination)
        elif not destination.is_file():
            destination.unlink(missing_ok=True)
            copy(fallback / name, destination)
    for name in ("hyprlock-colors.conf", "wallpaper-transition.txt"):
        destination = stage / name
        if not destination.is_file():
            destination.unlink(missing_ok=True)
            copy(ROOT / "active-theme" / name, destination)
    palette_script = ROOT / "quickshell/scripts/theme_palette.py"
    subprocess.run([sys.executable, str(palette_script), str(stage / "quickshell-colors.json"),
                    str(stage / "material.json")], check=True)
    (stage / "starship.toml").write_text(
        (ROOT / "fish/base.toml").read_text() + "\n" + (stage / "starship-colors.toml").read_text()
    )
    wallpaper = stage / "current-wallpaper"
    if (old / wallpaper.name).is_file() and wallpaper.is_symlink():
        wallpaper.unlink()
        wallpaper.symlink_to((old / wallpaper.name).resolve())
    if not wallpaper.is_file():
        wallpaper.unlink(missing_ok=True)
        recorded = stage / "current-wallpaper.txt"
        chosen = Path(recorded.read_text().strip()) if recorded.is_file() else None
        if not chosen or not chosen.is_file():
            # The startup helper uses the actual library when no image is selected yet.
            if recorded.is_symlink():
                recorded.unlink()
            elif recorded.is_file():
                recorded.unlink()
        else:
            wallpaper.symlink_to(chosen)


def make_scripts_executable(root_dir):
    for dirpath, _, filenames in os.walk(root_dir):
        for name in filenames:
            if name.endswith((".sh", ".py")) or name in ("hotspot", "lock-screen.sh"):
                p = Path(dirpath) / name
                try:
                    p.chmod(p.stat().st_mode | 0o755)
                except OSError:
                    pass


def prepare(changes, stage, prefs, backup, browser):
    prepared = []
    for number, change in enumerate(changes):
        if change.action == "keep":
            continue
        payload = stage / str(number)
        if change.action == "install":
            copy(change.source, payload)
            retain_extras(change.target, payload, skip_legacy=change.target == CONFIG / "hypr")
            if change.target.name == "hypr":
                source = change.target / "modules/monitors.lua"
                managed = prefs.get("installId")
                if source.is_file() and (managed or change.target.resolve() == (ROOT / "hypr").resolve()):
                    shutil.copy2(source, payload / "modules/monitors.lua")
                if browser:
                    browser_bin = "zen-browser" if browser == "zen" else "helium-browser"
                    bindings = payload / "modules/keybinds.lua"
                    text = bindings.read_text()
                    bindings.write_text(re.sub(r'(?m)^local browser\s*=\s*"[^"]*"', f'local browser = "{browser_bin}"', text))
                    env = payload / "modules/env.lua"
                    env.write_text(re.sub(r'hl\.env\("BROWSER", "[^"]*"\)', f'hl.env("BROWSER", "{browser_bin}")', env.read_text()))
        elif change.action == "initialize":
            initialize_theme(payload, change.target)
        elif change.action == "link":
            payload.symlink_to(change.source)
        else:
            payload.write_text(json.dumps({**prefs, "installId": backup.directory.name}, indent=2) + "\n")
        prepared.append((change.target, payload))
    if shutil.which("Hyprland"):
        config = next(payload for dest, payload in prepared if dest == CONFIG / "hypr") / "hyprland.lua"
        check = subprocess.run(["Hyprland", "--verify-config", "-c", str(config)], text=True, capture_output=True)
        if check.returncode != 0:
            raise ValueError("Staged Hyprland configuration failed validation:\n" + check.stdout + check.stderr)
    return prepared


def runtime_version(prog):
    if not shutil.which(prog):
        return ()
    result = subprocess.run([prog, "--version"], text=True, capture_output=True)
    version = re.search(r"(\d+)\.(\d+)\.(\d+)", result.stdout)
    return tuple(map(int, version.groups())) if version else ()


def install_deps(selected, browser):
    if not (shutil.which("pacman") and Path("/etc/arch-release").exists()):
        raise ValueError("--deps is available on Arch-based distributions. Install dependencies with your package manager.")
    core = ("hyprland hyprlock hypridle hyprpicker hyprlauncher hyprpolkitagent hyprsunset "
            "xdg-desktop-portal-hyprland xdg-desktop-portal-gtk xorg-xwayland xdg-utils "
            "awww imagemagick wl-clipboard cliphist grim slurp swappy ffmpeg wf-recorder "
            "kitty yazi playerctl brightnessctl pamixer cava upower networkmanager iw bluez bluez-utils "
            "pipewire pipewire-pulse wireplumber power-profiles-daemon gnome-keyring libsecret dnsmasq iptables "
            "dbus jq socat libnotify python python-dbus python-gobject python-pillow qrencode "
            "noto-fonts noto-fonts-emoji ttf-jetbrains-mono-nerd inter-font fastfetch fish").split()
    if runtime_version("qs") < (0, 3, 2):
        core.append("quickshell")
    if selected["starship"]:
        core.append("starship")
    if not browser and not any(shutil.which(name) for name in ("zen-browser", "helium-browser", "firefox")):
        core.append("firefox")
    needed = [pkg for pkg in core if not package_installed(pkg) or
              (pkg == "quickshell" and runtime_version("qs") < (0, 3, 2))]
    for pkg in needed:
        if subprocess.run(["pacman", "-Si", pkg], stdout=subprocess.DEVNULL,
                          stderr=subprocess.DEVNULL).returncode != 0:
            raise ValueError(f"Arch package {pkg} is unavailable in the configured repositories. Enable Core and Extra and bring Arch fully up to date.")
    browsers = {"zen": ("zen-browser", "zen-browser-bin"), "helium": ("helium-browser", "helium-browser-bin")}
    helper = None
    browser_package = None
    if browser:
        executable, package = browsers[browser]
        if not shutil.which(executable) and not package_installed(package):
            helper = shutil.which("paru") or shutil.which("yay")
            if not helper:
                raise ValueError(f"{browser} was requested and {package} requires an AUR helper. Install the browser first or omit --browser to use Firefox.")
            browser_package = package
    if needed:
        subprocess.run(["sudo", "pacman", "-S", "--needed", *needed], check=True)
    if browser_package:
        subprocess.run([helper, "-S", "--needed", browser_package], check=True)
    if runtime_version("qs") < (0, 3, 2):
        raise ValueError("Install Quickshell 0.3.2 or later with Quickshell.Networking support, then run the installer again.")


def configure_services(explicit, interactive):
    for unit, label in (("NetworkManager.service", "NetworkManager for Wi-Fi"),
                        ("bluetooth.service", "BlueZ for Bluetooth")):
        result = subprocess.run(["systemctl", "is-active", "--quiet", unit], check=False)
        if result.returncode == 0:
            continue
        active_other_network = unit.startswith("NetworkManager") and any(
            subprocess.run(["systemctl", "is-active", "--quiet", other], check=False).returncode == 0
            for other in ("systemd-networkd.service", "connman.service", "dhcpcd.service")
        )
        if active_other_network:
            print(f"Keeping the existing network service. To use Wi-Fi in the bar, configure {unit} when you switch network managers.")
            continue
        if explicit or (interactive and confirm(f"Enable and start {label}?")):
            result = subprocess.run(["sudo", "systemctl", "enable", "--now", unit], check=False)
            if result.returncode:
                print(f"Could not start {label}. Check systemctl status {unit}.", file=sys.stderr)
        else:
            print(f"When ready, start {label} with: sudo systemctl enable --now {unit}")


def package_installed(name):
    return subprocess.run(["pacman", "-Qq", name], stdout=subprocess.DEVNULL,
                          stderr=subprocess.DEVNULL).returncode == 0


def select_backup(name):
    root = backup_root()
    if name == "latest":
        for directory in sorted(root.glob("install-*"), reverse=True):
            if (directory / "manifest.json").is_file():
                candidate = Backup(directory)
                if candidate.data["status"] == "complete":
                    return candidate
        raise ValueError(f"No completed install backup in {root}")
    if Path(name).name != name or not re.fullmatch(r"install-[\w-]+", name):
        raise ValueError("Use an install snapshot ID or 'latest'")
    candidate = Backup(root / name)
    if candidate.data["status"] not in ("complete", "pending") or not candidate.data["paths"]:
        raise ValueError(f"Install backup {name} is {candidate.data['status']} and has no restorable installation.")
    return candidate


def rollback(name, dry_run, yes):
    backup = select_backup(name)
    print(f"Restore from {backup.directory}:")
    for target, original in backup.data["paths"].items():
        print(f"  {'restore' if original else 'remove':9} {target}")
    if dry_run:
        return
    if not yes and not confirm("Restore these paths and keep a recovery copy of their current contents?"):
        print("Rollback cancelled.")
        return
    recovery = Backup.create("pre-rollback")
    for target in backup.data["paths"]:
        recovery.remember(Path(target))
    try:
        backup.restore()
    except BaseException:
        recovery.restore()
        raise
    recovery.status("complete")
    backup.status("restored")
    print(f"Restored. The previous installed state was saved in {recovery.directory}.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true", help="show the changes without writing files")
    parser.add_argument("--yes", "-y", action="store_true", help="accept the preview and retain saved app choices by default")
    parser.add_argument("--deps", "--install", "-i", action="store_true", help="also install missing Arch dependencies")
    parser.add_argument("--no-deps", dest="deps", action="store_false", help="deploy configs only (the default)")
    parser.set_defaults(deps=False)
    parser.add_argument("--enable-services", action="store_true",
                        help="after --deps, start NetworkManager and BlueZ if no competing network manager is active")
    parser.add_argument("--browser", "-b", choices=("zen", "helium"), help="set the Dynamic You browser shortcut")
    parser.add_argument("--apps", help=f"comma-separated choices ({', '.join(APPS)}), all, or none")
    parser.add_argument("--rollback", nargs="?", const="latest", metavar="INSTALL_ID", help="restore a previous install")
    args = parser.parse_args()
    if args.enable_services and not args.deps:
        parser.error("--enable-services requires --deps")
    if os.geteuid() == 0:
        raise ValueError("Run the installer as the desktop user, without sudo.")
    if is_tape() and not args.dry_run:
        raise ValueError("A Tapes-managed desktop is active. Eject the tape before installing or restoring a standalone desktop.")
    if args.rollback:
        if args.dry_run:
            rollback(args.rollback, True, args.yes)
        else:
            with locked():
                rollback(args.rollback, False, args.yes)
        return

    prefs = preferences()
    choices = integration_choices(args, prefs)
    browser = args.browser or prefs.get("browserShortcut")
    if browser not in ("zen", "helium"):
        browser = None
    changes = install_plan()
    print_plan(changes, choices, args.deps)
    if browser:
        print(f"  Browser shortcut: {browser}")
    if args.dry_run:
        return
    if not args.yes and not confirm("Install Dynamic You using this plan?"):
        print("Installation cancelled.")
        return
    if args.deps:
        install_deps(choices, browser)

    with locked():
        changes = install_plan()
        state = backup_root().resolve()
        if any(change.action != "keep" and state.is_relative_to(change.target.resolve())
               for change in changes):
            raise ValueError("The backup directory must be outside the paths being installed.")
        backup = Backup.create("install")
        print(f"Saving originals in {backup.directory}")
        with tempfile.TemporaryDirectory(prefix="stage-", dir=backup.directory) as directory:
            try:
                current = preferences()
                settings = {**current, "integrations": choices}
                if browser:
                    settings["browserShortcut"] = browser
                prepared = prepare(changes, Path(directory), settings, backup, browser)
                for target, payload in prepared:
                    backup.remember(target)
                    replace(target, payload)
                for sub in ("scripts", "hypr/scripts", "quickshell/scripts", "quickshell/luciddocks", "quickshell/inir/sdata/dist-arch"):
                    p = CONFIG / sub
                    if p.is_dir():
                        make_scripts_executable(p)
                if BIN.is_dir():
                    make_scripts_executable(BIN)
            except BaseException:
                backup.restore()
                backup.status("failed")
                raise
            backup.status("complete")
    if args.deps:
        configure_services(args.enable_services, sys.stdin.isatty() and not args.yes)
    print("Installed. Start a Hyprland session to apply the desktop and selected app colors.")
    print(f"Rollback: ./install.sh --rollback {backup.directory.name}")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"Dynamic You: {error}", file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        sys.exit(130)
