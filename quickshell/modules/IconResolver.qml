pragma Singleton
import QtQuick
import Quickshell

// Centralized icon resolution service inspired by Matushell
// Resolves application IDs, process names, and window classes into:
// 1. System icon theme paths via Quickshell.iconPath()
// 2. High-fidelity desktop icon assets
// 3. Crisp Material Symbol fallback glyphs
QtObject {
    id: root

    readonly property var iconMap: ({
        // Browsers
        "zen": { name: "Zen Browser", icon: "zen-browser", symbol: "language" },
        "zen-bin": { name: "Zen Browser", icon: "zen-browser", symbol: "language" },
        "helium": { name: "Helium Browser", icon: "helium-browser", symbol: "language" },
        "helium-browser": { name: "Helium Browser", icon: "helium-browser", symbol: "language" },
        "firefox": { name: "Firefox", icon: "firefox", symbol: "language" },
        "chrome": { name: "Google Chrome", icon: "google-chrome", symbol: "language" },
        "google-chrome": { name: "Google Chrome", icon: "google-chrome", symbol: "language" },
        "google-chrome-stable": { name: "Google Chrome", icon: "google-chrome", symbol: "language" },
        "chromium": { name: "Chromium", icon: "chromium", symbol: "language" },
        "brave": { name: "Brave Browser", icon: "brave-browser", symbol: "language" },
        "brave-browser": { name: "Brave Browser", icon: "brave-browser", symbol: "language" },
        "opera": { name: "Opera", icon: "opera", symbol: "language" },
        "vivaldi": { name: "Vivaldi", icon: "vivaldi", symbol: "language" },
        "microsoft-edge": { name: "Microsoft Edge", icon: "microsoft-edge", symbol: "language" },
        "isolated web content": { name: "Web Content", icon: "", symbol: "language" },
        "isolated web co": { name: "Web Content", icon: "", symbol: "language" },
        "privileged content": { name: "Privileged Content", icon: "", symbol: "security" },
        "privileged con": { name: "Privileged Content", icon: "", symbol: "security" },
        "socket process": { name: "Socket Process", icon: "", symbol: "wifi" },
        "rdd process": { name: "Media Decoder", icon: "", symbol: "play_circle" },

        // Terminals
        "kitty": { name: "Kitty Terminal", icon: "kitty", symbol: "terminal" },
        "alacritty": { name: "Alacritty", icon: "Alacritty", symbol: "terminal" },
        "foot": { name: "Foot", icon: "foot", symbol: "terminal" },
        "wezterm": { name: "WezTerm", icon: "org.wezfurlong.wezterm", symbol: "terminal" },
        "wezterm-gui": { name: "WezTerm", icon: "org.wezfurlong.wezterm", symbol: "terminal" },
        "ghostty": { name: "Ghostty", icon: "com.mitchellh.ghostty", symbol: "terminal" },
        "bash": { name: "Bash Shell", icon: "", symbol: "terminal" },
        "zsh": { name: "Zsh Shell", icon: "", symbol: "terminal" },
        "fish": { name: "Fish Shell", icon: "", symbol: "terminal" },

        // Code Editors & IDEs
        "code": { name: "VS Code", icon: "com.visualstudio.code", symbol: "code" },
        "code-oss": { name: "Code OSS", icon: "vscodium", symbol: "code" },
        "vscodium": { name: "VSCodium", icon: "vscodium", symbol: "code" },
        "cursor": { name: "Cursor Editor", icon: "cursor", symbol: "code" },
        "cursor-bin": { name: "Cursor Editor", icon: "cursor", symbol: "code" },
        "nvim": { name: "Neovim", icon: "nvim", symbol: "code" },
        "vim": { name: "Vim", icon: "vim", symbol: "code" },
        "sublime_text": { name: "Sublime Text", icon: "sublime-text", symbol: "code" },
        "zed": { name: "Zed Editor", icon: "dev.zed.Zed", symbol: "code" },
        "python": { name: "Python", icon: "", symbol: "terminal" },
        "python3": { name: "Python 3", icon: "", symbol: "terminal" },
        "node": { name: "Node.js", icon: "", symbol: "terminal" },
        "nodejs": { name: "Node.js", icon: "", symbol: "terminal" },
        "perl": { name: "Perl", icon: "", symbol: "terminal" },
        "ruby": { name: "Ruby", icon: "", symbol: "terminal" },

        // Chat & Communication
        "discord": { name: "Discord", icon: "discord", symbol: "forum" },
        "vesktop": { name: "Vesktop", icon: "vesktop", symbol: "forum" },
        "webcord": { name: "WebCord", icon: "webcord", symbol: "forum" },
        "telegram-desktop": { name: "Telegram", icon: "telegram", symbol: "send" },
        "telegram": { name: "Telegram", icon: "telegram", symbol: "send" },
        "slack": { name: "Slack", icon: "slack", symbol: "forum" },
        "signal": { name: "Signal", icon: "signal-desktop", symbol: "chat" },
        "signal-desktop": { name: "Signal", icon: "signal-desktop", symbol: "chat" },
        "element": { name: "Element", icon: "element", symbol: "chat" },

        // Audio & Music
        "spotify": { name: "Spotify", icon: "spotify", symbol: "music_note" },
        "cider": { name: "Cider", icon: "cider", symbol: "music_note" },
        "amberol": { name: "Amberol", icon: "io.bassi.Amberol", symbol: "music_note" },
        "rhythmbox": { name: "Rhythmbox", icon: "rhythmbox", symbol: "music_note" },
        "pavucontrol": { name: "Volume Control", icon: "org.pulseaudio.pavucontrol", symbol: "volume_up" },
        "pipewire": { name: "PipeWire Audio", icon: "", symbol: "volume_up" },
        "wireplumber": { name: "WirePlumber", icon: "", symbol: "volume_up" },
        "pipewire-pulse": { name: "PipeWire Pulse", icon: "", symbol: "volume_up" },

        // Media & Video
        "obs": { name: "OBS Studio", icon: "com.obsproject.Studio", symbol: "videocam" },
        "obs-studio": { name: "OBS Studio", icon: "com.obsproject.Studio", symbol: "videocam" },
        "vlc": { name: "VLC Media Player", icon: "vlc", symbol: "play_circle" },
        "mpv": { name: "MPV Media Player", icon: "mpv", symbol: "play_circle" },
        "kdenlive": { name: "Kdenlive", icon: "org.kde.kdenlive", symbol: "movie" },

        // File Managers
        "thunar": { name: "Thunar", icon: "org.xfce.thunar", symbol: "folder" },
        "nautilus": { name: "Files", icon: "org.gnome.Nautilus", symbol: "folder" },
        "dolphin": { name: "Dolphin", icon: "org.kde.dolphin", symbol: "folder" },
        "nemo": { name: "Nemo", icon: "nemo", symbol: "folder" },
        "yazi": { name: "Yazi File Manager", icon: "", symbol: "folder" },

        // Notes & Office
        "obsidian": { name: "Obsidian", icon: "obsidian", symbol: "edit_note" },
        "notion-app": { name: "Notion", icon: "", symbol: "description" },
        "notion-app-electron": { name: "Notion", icon: "", symbol: "description" },
        "libreoffice": { name: "LibreOffice", icon: "libreoffice-startcenter", symbol: "description" },
        "et": { name: "WPS Spreadsheets", icon: "wps-office-et", symbol: "description" },
        "wps": { name: "WPS Writer", icon: "wps-office-wps", symbol: "description" },
        "wpp": { name: "WPS Presentation", icon: "", symbol: "description" },

        // Gaming & Creative
        "steam": { name: "Steam", icon: "steam", symbol: "sports_esports" },
        "heroic": { name: "Heroic Games", icon: "com.heroicgameslauncher.hgl", symbol: "sports_esports" },
        "lutris": { name: "Lutris", icon: "net.lutris.Lutris", symbol: "sports_esports" },
        "blender": { name: "Blender", icon: "blender", symbol: "view_in_ar" },
        "gimp": { name: "GIMP", icon: "gimp", symbol: "palette" },
        "inkscape": { name: "Inkscape", icon: "org.inkscape.Inkscape", symbol: "palette" },
        "krita": { name: "Krita", icon: "org.kde.krita", symbol: "palette" },

        // Screen & Wayland Utilities
        "grim": { name: "Grim Screenshot", icon: "accessories-screenshot", symbol: "screenshot_monitor" },
        "grimblast": { name: "Grimblast Screenshot", icon: "accessories-screenshot", symbol: "screenshot_monitor" },
        "screenshot hub": { name: "Screenshot Hub", icon: "accessories-screenshot", symbol: "screenshot_monitor" },
        "slurp": { name: "Slurp Selection", icon: "", symbol: "crop" },
        "hyprpicker": { name: "Hyprpicker", icon: "", symbol: "colorize" },
        "wf-recorder": { name: "Screen Recorder", icon: "", symbol: "videocam" },
        "wl-copy": { name: "Clipboard", icon: "", symbol: "content_paste" },
        "wl-paste": { name: "Clipboard", icon: "", symbol: "content_paste" },
        "cliphist": { name: "Cliphist", icon: "", symbol: "content_paste" },

        // System, Services & Desktop Daemons (no fake desktop app icons)
        "quickshell": { name: "Quickshell", icon: "", symbol: "widgets" },
        "qs": { name: "Quickshell", icon: "", symbol: "widgets" },
        "hyprland": { name: "Hyprland", icon: "", symbol: "desktop_windows" },
        "hypridle": { name: "Hypridle", icon: "", symbol: "bedtime" },
        "hyprlock": { name: "Hyprlock", icon: "", symbol: "lock" },
        "cava": { name: "CAVA", icon: "", symbol: "equalizer" },
        "fastfetch": { name: "Fastfetch", icon: "", symbol: "info" },
        "btop": { name: "Btop Monitor", icon: "", symbol: "monitoring" },
        "htop": { name: "Htop Monitor", icon: "", symbol: "monitoring" },
        "swaync": { name: "Notifications", icon: "", symbol: "notifications" },
        "dunst": { name: "Notifications", icon: "", symbol: "notifications" },
        "mako": { name: "Notifications", icon: "", symbol: "notifications" },
        "systemd": { name: "systemd", icon: "", symbol: "settings" },
        "dbus-broker": { name: "D-Bus Broker", icon: "", symbol: "hub" },
        "dbus-broker-launch": { name: "D-Bus Broker", icon: "", symbol: "hub" },
        "dbus-broker-lau": { name: "D-Bus Broker", icon: "", symbol: "hub" },
        "avahi-daemon": { name: "Avahi mDNS", icon: "", symbol: "lan" },
        "networkmanager": { name: "NetworkManager", icon: "", symbol: "wifi" },
        "bluetoothd": { name: "Bluetooth Service", icon: "", symbol: "bluetooth" },
        "warp-svc": { name: "Cloudflare WARP", icon: "", symbol: "vpn_key" },
        "awww-daemon": { name: "Wallpaper Engine", icon: "", symbol: "palette" },
        "swww-daemon": { name: "Wallpaper Engine", icon: "", symbol: "palette" },
        "hyprpolkitagent": { name: "Auth Agent", icon: "", symbol: "security" },
        "xwayland": { name: "XWayland Server", icon: "", symbol: "display_settings" },
        "Xwayland": { name: "XWayland Server", icon: "", symbol: "display_settings" },
        "systemsettings": { name: "Settings", icon: "systemsettings", symbol: "settings" },
        "gnome-control-center": { name: "Settings", icon: "org.gnome.Settings", symbol: "settings" }
    })

    // Intelligent symbol guessing for unmapped processes and background tasks
    function guessSymbol(input) {
        if (!input) return "memory";
        var s = input.toLowerCase();
        if (s.indexOf("sh") !== -1 || s.indexOf("bash") !== -1 || s.indexOf("zsh") !== -1 || s.indexOf("term") !== -1 || s.indexOf("cmd") !== -1) return "terminal";
        if (s.indexOf("wifi") !== -1 || s.indexOf("wlan") !== -1 || s.indexOf("net") !== -1 || s.indexOf("lan") !== -1 || s.indexOf("ip") !== -1 || s.indexOf("conn") !== -1) return "lan";
        if (s.indexOf("audio") !== -1 || s.indexOf("sound") !== -1 || s.indexOf("pipe") !== -1 || s.indexOf("pulse") !== -1 || s.indexOf("volume") !== -1) return "volume_up";
        if (s.indexOf("auth") !== -1 || s.indexOf("polkit") !== -1 || s.indexOf("key") !== -1 || s.indexOf("pass") !== -1 || s.indexOf("sec") !== -1 || s.indexOf("crypt") !== -1) return "security";
        if (s.indexOf("disk") !== -1 || s.indexOf("mount") !== -1 || s.indexOf("fs") !== -1 || s.indexOf("fuse") !== -1 || s.indexOf("drive") !== -1 || s.indexOf("btrfs") !== -1) return "hard_drive";
        if (s.indexOf("dbus") !== -1 || s.indexOf("broker") !== -1 || s.indexOf("ipc") !== -1 || s.indexOf("rpc") !== -1 || s.indexOf("msg") !== -1) return "hub";
        if (s.indexOf("hypr") !== -1 || s.indexOf("wayland") !== -1 || s.indexOf("x11") !== -1 || s.indexOf("screen") !== -1 || s.indexOf("display") !== -1) return "desktop_windows";
        if (s.indexOf("systemd") !== -1 || s.indexOf("init") !== -1 || s.indexOf("service") !== -1 || s.indexOf("daemon") !== -1 || s.indexOf("manager") !== -1 || s.indexOf("ctl") !== -1) return "settings";
        if (s.indexOf("mon") !== -1 || s.indexOf("log") !== -1 || s.indexOf("stat") !== -1 || s.indexOf("audit") !== -1 || s.indexOf("watch") !== -1) return "monitoring";
        if (s.indexOf("shot") !== -1 || s.indexOf("grim") !== -1 || s.indexOf("slurp") !== -1 || s.indexOf("picker") !== -1 || s.indexOf("record") !== -1) return "screenshot_monitor";
        if (s.indexOf("notify") !== -1 || s.indexOf("alert") !== -1 || s.indexOf("dunst") !== -1 || s.indexOf("mako") !== -1) return "notifications";
        if (s.indexOf("blue") !== -1 || s.indexOf("bt") !== -1) return "bluetooth";
        return "memory";
    }

    // Resolves an app/process into icon path and fallback symbol
    function resolve(inputName, windowClass) {
        var rawKey = (inputName || "").toString().toLowerCase().trim();
        var rawClass = (windowClass || "").toString().toLowerCase().trim();

        // 1. Direct map lookup
        var entry = root.iconMap[rawKey] || root.iconMap[rawClass];

        // 1b. Substring / Token lookup if no direct match
        if (!entry) {
            for (var k in root.iconMap) {
                if (k.length >= 3 && (rawKey.indexOf(k) !== -1 || rawClass.indexOf(k) !== -1)) {
                    entry = root.iconMap[k];
                    break;
                }
            }
        }

        var candidateIcon = entry ? (entry.icon || "") : "";
        var fallbackSym = entry ? (entry.symbol || "") : "";
        var dispName = entry ? (entry.name || "") : "";

        // If no mapped symbol, intelligently guess
        if (!fallbackSym || fallbackSym === "") {
            fallbackSym = root.guessSymbol(rawKey || rawClass);
        }

        // 2. Only build Quickshell iconPath if we have a non-empty desktop application icon
        var iconPath = "";
        if (candidateIcon && candidateIcon !== "") {
            if (candidateIcon.startsWith("/") || candidateIcon.startsWith("file://") || candidateIcon.startsWith("image://")) {
                iconPath = candidateIcon.startsWith("/") ? ("file://" + candidateIcon) : candidateIcon;
            } else {
                try {
                    iconPath = Quickshell.iconPath(candidateIcon);
                } catch (e) {}
            }
        }

        return {
            "iconPath": iconPath,
            "hasIcon": iconPath !== "",
            "iconName": candidateIcon,
            "fallbackSymbol": fallbackSym,
            "displayName": dispName !== "" ? dispName : (inputName || windowClass || "App")
        };
    }
}
