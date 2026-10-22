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

        // Terminals
        "kitty": { name: "Kitty Terminal", icon: "kitty", symbol: "terminal" },
        "alacritty": { name: "Alacritty", icon: "Alacritty", symbol: "terminal" },
        "foot": { name: "Foot", icon: "foot", symbol: "terminal" },
        "wezterm": { name: "WezTerm", icon: "org.wezfurlong.wezterm", symbol: "terminal" },
        "wezterm-gui": { name: "WezTerm", icon: "org.wezfurlong.wezterm", symbol: "terminal" },
        "ghostty": { name: "Ghostty", icon: "com.mitchellh.ghostty", symbol: "terminal" },
        "bash": { name: "Bash Shell", icon: "utilities-terminal", symbol: "terminal" },
        "zsh": { name: "Zsh Shell", icon: "utilities-terminal", symbol: "terminal" },
        "fish": { name: "Fish Shell", icon: "utilities-terminal", symbol: "terminal" },

        // Code Editors & IDEs
        "code": { name: "VS Code", icon: "com.visualstudio.code", symbol: "code" },
        "code-oss": { name: "Code OSS", icon: "code-oss", symbol: "code" },
        "vscodium": { name: "VSCodium", icon: "vscodium", symbol: "code" },
        "cursor": { name: "Cursor Editor", icon: "cursor", symbol: "code" },
        "cursor-bin": { name: "Cursor Editor", icon: "cursor", symbol: "code" },
        "nvim": { name: "Neovim", icon: "nvim", symbol: "code" },
        "vim": { name: "Vim", icon: "vim", symbol: "code" },
        "sublime_text": { name: "Sublime Text", icon: "sublime-text", symbol: "code" },
        "zed": { name: "Zed Editor", icon: "dev.zed.Zed", symbol: "code" },

        // Chat & Communication
        "discord": { name: "Discord", icon: "discord", symbol: "forum" },
        "vesktop": { name: "Vesktop", icon: "vesktop", symbol: "forum" },
        "webcord": { name: "WebCord", icon: "webcord", symbol: "forum" },
        "telegram-desktop": { name: "Telegram", icon: "telegram", symbol: "send" },
        "slack": { name: "Slack", icon: "slack", symbol: "forum" },
        "signal": { name: "Signal", icon: "signal-desktop", symbol: "chat" },
        "signal-desktop": { name: "Signal", icon: "signal-desktop", symbol: "chat" },
        "element": { name: "Element", icon: "element", symbol: "chat" },

        // Audio & Music
        "spotify": { name: "Spotify", icon: "spotify", symbol: "music_note" },
        "cider": { name: "Cider", icon: "cider", symbol: "music_note" },
        "amberol": { name: "Amberol", icon: "io.bassi.Amberol", symbol: "music_note" },
        "rhythmbox": { name: "Rhythmbox", icon: "rhythmbox", symbol: "music_note" },
        "pavucontrol": { name: "Volume Control", icon: "multimedia-volume-control", symbol: "volume_up" },
        "pipewire": { name: "PipeWire Audio", icon: "audio-card", symbol: "volume_up" },

        // Media & Video
        "obs": { name: "OBS Studio", icon: "com.obsproject.Studio", symbol: "videocam" },
        "obs-studio": { name: "OBS Studio", icon: "com.obsproject.Studio", symbol: "videocam" },
        "vlc": { name: "VLC Media Player", icon: "vlc", symbol: "play_circle" },
        "mpv": { name: "MPV Media Player", icon: "mpv", symbol: "play_circle" },
        "kdenlive": { name: "Kdenlive", icon: "org.kde.kdenlive", symbol: "movie" },

        // File Managers
        "thunar": { name: "Thunar", icon: "thunar", symbol: "folder" },
        "nautilus": { name: "Files", icon: "org.gnome.Nautilus", symbol: "folder" },
        "dolphin": { name: "Dolphin", icon: "org.kde.dolphin", symbol: "folder" },
        "nemo": { name: "Nemo", icon: "nemo", symbol: "folder" },
        "yazi": { name: "Yazi File Manager", icon: "utilities-terminal", symbol: "folder" },

        // Notes & Office
        "obsidian": { name: "Obsidian", icon: "obsidian", symbol: "edit_note" },
        "notion-app": { name: "Notion", icon: "notion-app", symbol: "description" },
        "libreoffice": { name: "LibreOffice", icon: "libreoffice-startcenter", symbol: "description" },
        "et": { name: "WPS Spreadsheets", icon: "wps-office-et", symbol: "description" },
        "wps": { name: "WPS Writer", icon: "wps-office-wps", symbol: "description" },
        "wpp": { name: "WPS Presentation", icon: "wps-office-wpp", symbol: "description" },

        // Gaming
        "steam": { name: "Steam", icon: "steam", symbol: "sports_esports" },
        "heroic": { name: "Heroic Games", icon: "com.heroicgameslauncher.hgl", symbol: "sports_esports" },
        "lutris": { name: "Lutris", icon: "net.lutris.Lutris", symbol: "sports_esports" },

        // System & Desktop
        "quickshell": { name: "Quickshell", icon: "quickshell", symbol: "widgets" },
        "qs": { name: "Quickshell", icon: "quickshell", symbol: "widgets" },
        "hyprland": { name: "Hyprland", icon: "hyprland", symbol: "desktop_windows" },
        "btop": { name: "Btop Monitor", icon: "utilities-terminal", symbol: "monitoring" },
        "htop": { name: "Htop Monitor", icon: "utilities-terminal", symbol: "monitoring" },
        "systemsettings": { name: "Settings", icon: "preferences-system", symbol: "settings" },
        "gnome-control-center": { name: "Settings", icon: "preferences-system", symbol: "settings" }
    })

    // Resolves an app/process into icon path and fallback symbol
    function resolve(inputName, windowClass) {
        var rawKey = (inputName || "").toString().toLowerCase().trim();
        var rawClass = (windowClass || "").toString().toLowerCase().trim();

        // 1. Direct map lookup
        var entry = root.iconMap[rawKey] || root.iconMap[rawClass];

        var candidateIcon = entry ? entry.icon : (rawKey || rawClass);
        var fallbackSym = entry ? entry.symbol : "apps";
        var dispName = entry ? entry.name : "";

        // 2. Try Quickshell iconPath lookup
        var iconPath = "";
        if (candidateIcon && !candidateIcon.startsWith("/") && !candidateIcon.startsWith("file://")) {
            try {
                var p = Quickshell.iconPath(candidateIcon, true);
                if (p && p.trim() !== "") {
                    iconPath = "file://" + p;
                }
            } catch (e) {}
        } else if (candidateIcon) {
            iconPath = candidateIcon.startsWith("/") ? ("file://" + candidateIcon) : candidateIcon;
        }

        return {
            "iconPath": iconPath,
            "hasIcon": iconPath !== "",
            "iconName": candidateIcon,
            "fallbackSymbol": fallbackSym,
            "displayName": dispName
        };
    }
}
