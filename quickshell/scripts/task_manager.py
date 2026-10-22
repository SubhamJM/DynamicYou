#!/usr/bin/env python3
import sys
import os
import time
import json
import subprocess
import signal
import re
from collections import defaultdict

# -----------------------------------------------------------------------------
# DynamicYou / Iris System Process Manager Engine
# Zero-dependency, pure Linux /proc & procps engine.
# Provides real-time process aggregation, desktop icon resolution,
# subprocess tree extraction, and dual-mode window focusing.
# -----------------------------------------------------------------------------

ICON_MAPPINGS = {
    'zen-bin': ('Zen Browser', 'zen-browser', 'language'),
    'zen': ('Zen Browser', 'zen-browser', 'language'),
    'firefox': ('Firefox', 'firefox', 'language'),
    'chrome': ('Google Chrome', 'google-chrome', 'language'),
    'google-chrome': ('Google Chrome', 'google-chrome', 'language'),
    'chromium': ('Chromium', 'chromium', 'language'),
    'brave': ('Brave Browser', 'brave-browser', 'language'),
    'brave-browser': ('Brave Browser', 'brave-browser', 'language'),
    'opera': ('Opera', 'opera', 'language'),
    'vivaldi': ('Vivaldi', 'vivaldi', 'language'),
    'edge': ('Microsoft Edge', 'microsoft-edge', 'language'),

    'kitty': ('Kitty Terminal', 'kitty', 'terminal'),
    'alacritty': ('Alacritty', 'Alacritty', 'terminal'),
    'foot': ('Foot', 'foot', 'terminal'),
    'wezterm': ('WezTerm', 'org.wezfurlong.wezterm', 'terminal'),
    'ghostty': ('Ghostty', 'com.mitchellh.ghostty', 'terminal'),
    'bash': ('Bash Shell', 'utilities-terminal', 'terminal'),
    'zsh': ('Zsh Shell', 'utilities-terminal', 'terminal'),
    'fish': ('Fish Shell', 'utilities-terminal', 'terminal'),

    'code': ('VS Code', 'com.visualstudio.code', 'code'),
    'vscodium': ('VSCodium', 'vscodium', 'code'),
    'cursor': ('Cursor Editor', 'cursor', 'code'),
    'cursor-bin': ('Cursor Editor', 'cursor', 'code'),
    'nvim': ('Neovim', 'nvim', 'code'),
    'vim': ('Vim', 'vim', 'code'),
    'sublime_text': ('Sublime Text', 'sublime-text', 'code'),
    'zed': ('Zed Editor', 'dev.zed.Zed', 'code'),

    'vesktop': ('Vesktop', 'vesktop', 'forum'),
    'discord': ('Discord', 'discord', 'forum'),
    'webcord': ('WebCord', 'webcord', 'forum'),
    'telegram-desktop': ('Telegram', 'telegram-desktop', 'send'),
    'telegram': ('Telegram', 'telegram-desktop', 'send'),
    'slack': ('Slack', 'slack', 'forum'),
    'signal-desktop': ('Signal', 'signal-desktop', 'forum'),

    'spotify': ('Spotify', 'spotify-launcher', 'music_note'),
    'amberol': ('Amberol', 'io.bassi.Amberol', 'music_note'),
    'rhythmbox': ('Rhythmbox', 'rhythmbox', 'music_note'),
    'mpv': ('MPV Player', 'mpv', 'play_circle'),
    'vlc': ('VLC Media Player', 'vlc', 'play_circle'),
    'obs': ('OBS Studio', 'com.obsproject.Studio', 'videocam'),
    'obs64': ('OBS Studio', 'com.obsproject.Studio', 'videocam'),

    'steam': ('Steam', 'steam', 'sports_esports'),
    'heroic': ('Heroic Games', 'com.heroicgameslauncher.hgl', 'sports_esports'),
    'lutris': ('Lutris', 'net.lutris.Lutris', 'sports_esports'),
    'blender': ('Blender', 'blender', 'view_in_ar'),
    'gimp': ('GIMP', 'gimp', 'palette'),
    'inkscape': ('Inkscape', 'org.inkscape.Inkscape', 'palette'),
    'krita': ('Krita', 'org.kde.krita', 'palette'),

    'et': ('WPS Spreadsheets', 'wps-office-et', 'description'),
    'wps': ('WPS Office', 'wps-office-wps', 'description'),
    'wpp': ('WPS Presentation', 'wps-office-wpp', 'description'),
    'libreoffice': ('LibreOffice', 'libreoffice-startcenter', 'description'),
    'soffice.bin': ('LibreOffice', 'libreoffice-startcenter', 'description'),
    'obsidian': ('Obsidian', 'obsidian', 'edit_note'),
    'notion-app-electron': ('Notion', 'notion-app-electron', 'edit_note'),

    'yazi': ('Yazi', 'utilities-terminal', 'folder'),
    'thunar': ('Thunar', 'org.xfce.thunar', 'folder'),
    'nautilus': ('Files', 'org.gnome.Nautilus', 'folder'),
    'dolphin': ('Dolphin', 'system-file-manager', 'folder'),
    'nemo': ('Nemo', 'nemo', 'folder'),

    'quickshell': ('Quickshell', 'quickshell', 'widgets'),
    'qs': ('Quickshell', 'quickshell', 'widgets'),
    'hyprland': ('Hyprland', 'hyprland', 'desktop_windows'),
    'pipewire': ('PipeWire Audio', 'audio-card', 'volume_up'),
    'wireplumber': ('WirePlumber', 'audio-card', 'volume_up'),
    'pipewire-pulse': ('PipeWire Pulse', 'audio-card', 'volume_up'),
    'networkmanager': ('NetworkManager', 'network-workgroup', 'wifi'),
    'bluetoothd': ('Bluetooth Service', 'bluetooth', 'bluetooth'),
    'systemd': ('systemd', 'system-run', 'settings'),
    'warp-svc': ('Cloudflare WARP', 'network-vpn', 'vpn_key'),
    'hypridle': ('Hypridle', 'preferences-system', 'bedtime'),
    'hyprlock': ('Hyprlock', 'system-lock-screen', 'lock'),
    'awww-daemon': ('Wallpaper Engine', 'preferences-desktop-wallpaper', 'palette'),
    'swww-daemon': ('Wallpaper Engine', 'preferences-desktop-wallpaper', 'palette'),
    'kdeconnectd': ('KDE Connect', 'kdeconnect', 'phonelink'),
    'wlsunset': ('Blue Light Filter', 'preferences-system', 'nightlight'),
    'hyprsunset': ('Blue Light Filter', 'preferences-system', 'nightlight'),
    'gammastep': ('Blue Light Filter', 'preferences-system', 'nightlight'),
    'hyprpolkitagent': ('Auth Agent', 'system-lock-screen', 'security'),
    'Xwayland': ('XWayland Server', 'xorg', 'display_settings'),
    'cava': ('CAVA Audio Visualizer', 'audio-card', 'equalizer')
}

USER_APP_KEYS = {
    'quickshell', 'qs', 'hyprland', 'waybar', 'rofi', 'wofi', 'fuzzel', 'tofi', 'dunst', 'mako',
    'awww-daemon', 'swww-daemon', 'swww', 'hypridle', 'hyprlock', 'hyprpolkitagent',
    'kdeconnectd', 'kdeconnect', 'wlsunset', 'hyprsunset', 'gammastep',
    'wl-paste', 'cliphist', 'pipewire', 'wireplumber', 'pipewire-pulse', 'cava',
    'zen-bin', 'zen', 'firefox', 'chrome', 'google-chrome', 'chromium', 'brave', 'brave-browser', 'opera', 'vivaldi', 'edge',
    'kitty', 'alacritty', 'foot', 'wezterm', 'ghostty',
    'code', 'vscodium', 'cursor', 'cursor-bin', 'nvim', 'vim', 'sublime_text', 'zed',
    'vesktop', 'discord', 'webcord', 'telegram-desktop', 'telegram', 'slack', 'signal-desktop',
    'spotify', 'amberol', 'rhythmbox', 'mpv', 'vlc', 'obs', 'obs64', 'steam', 'heroic', 'lutris',
    'blender', 'gimp', 'inkscape', 'krita', 'obsidian', 'notion-app-electron',
    'libreoffice', 'soffice.bin', 'wps', 'wpp', 'et',
    'thunar', 'nautilus', 'dolphin', 'nemo', 'yazi'
}

def token_matches(name, token):
    if not name or not token:
        return False
    n, t = name.lower(), token.lower()
    if n == t:
        return True
    if len(t) <= 4:
        return bool(re.search(r'(^|[-_.])' + re.escape(t) + r'($|[-_.])', n))
    return t in n

def resolve_app_info(comm, p_class):
    c = (comm or '').lower()
    cl = (p_class or '').lower()

    if cl in ICON_MAPPINGS:
        return ICON_MAPPINGS[cl]
    if c in ICON_MAPPINGS:
        return ICON_MAPPINGS[c]

    for k, v in ICON_MAPPINGS.items():
        if token_matches(cl, k) or token_matches(c, k):
            return v

    disp = p_class.capitalize() if p_class else comm
    icon_name = cl if cl else c
    return disp, icon_name, 'window' if p_class else 'memory'

def clean_child_info(comm, args):
    a = (args or '').strip()
    c = (comm or '').strip().lower()

    if 'zen' in c or 'firefox' in c:
        if 'socket' in a:
            return 'Network Socket Service', 'wifi'
        if 'rdd' in a:
            return 'Media Decoder (RDD)', 'play_circle'
        if 'tab' in a:
            return 'Web Content Tab', 'tab'
        if 'forkserver' in a:
            return 'Fork Server', 'account_tree'
        if 'gpu' in a:
            return 'GPU Acceleration', 'speed'
        if 'utility' in a:
            return 'Utility Service', 'tune'
        if 'privileged' in a.lower():
            return 'Privileged Web Content', 'security'
        return 'Web Content Process', 'language'

    if 'spotify' in c:
        if '--type=renderer' in a:
            return 'Spotify UI Renderer', 'brush'
        if '--type=gpu-process' in a:
            return 'GPU Acceleration', 'speed'
        if '--type=utility' in a:
            return 'Audio / Utility Service', 'volume_up'
        if '--type=zygote' in a:
            return 'Zygote Preloader', 'hourglass_empty'
        if 'crashpad' in a:
            return 'Crash Monitor', 'healing'
        return 'Spotify Worker Process', 'music_note'

    if c == 'nvim':
        return 'Neovim Editor', 'code'
    if c == 'vim':
        return 'Vim Editor', 'code'
    if c == 'agy':
        return 'agy (AI Assistant)', 'psychology'
    if c in ['fish', 'bash', 'zsh', 'sh']:
        return f'{c.capitalize()} Shell', 'terminal'
    if c == 'kitten':
        return 'Kitty Helper Service', 'widgets'
    if 'copilot' in a.lower():
        return 'GitHub Copilot LS', 'neurology'
    if c == 'java':
        return 'Java Language Server', 'coffee'
    if c == 'inotifywait':
        return 'File Watcher', 'visibility'
    if 'node' in c:
        return 'Node.js Runtime', 'terminal'
    if c == 'bwrap':
        return 'Bubblewrap Sandbox', 'security'

    return comm if comm else 'Subprocess', 'subdirectory_arrow_right'

def get_mem_info():
    mem = {}
    try:
        with open('/proc/meminfo', 'r') as f:
            for line in f:
                parts = line.split(':')
                if len(parts) == 2:
                    k = parts[0].strip()
                    v = parts[1].strip().split()[0]
                    mem[k] = int(v) * 1024
    except Exception:
        pass

    tot = mem.get('MemTotal', 1)
    avail = mem.get('MemAvailable', mem.get('MemFree', 0) + mem.get('Buffers', 0) + mem.get('Cached', 0))
    used = max(0, tot - avail)
    pct = round((used / tot) * 100.0, 1) if tot > 0 else 0.0

    return {
        "mem_total_bytes": tot,
        "mem_used_bytes": used,
        "mem_total_gb": round(tot / (1024**3), 2),
        "mem_used_gb": round(used / (1024**3), 2),
        "mem_percent": pct
    }

def get_cpu_info():
    cpu_pct = 0.0
    stat_file = '/dev/shm/quickshell_cpu_stat'
    try:
        with open('/proc/stat', 'r') as f:
            line = f.readline()
        parts = [int(x) for x in line.split()[1:]]
        idle = parts[3] + (parts[4] if len(parts) > 4 else 0)
        total = sum(parts)

        prev_idle, prev_total = 0, 0
        if os.path.exists(stat_file):
            try:
                with open(stat_file, 'r') as sf:
                    c = sf.read().strip().split()
                    if len(c) >= 2:
                        prev_idle, prev_total = int(c[0]), int(c[1])
            except Exception:
                pass

        diff_total = total - prev_total
        diff_idle = idle - prev_idle

        if diff_total > 0 and prev_total > 0 and diff_idle >= 0:
            cpu_pct = round((1.0 - (diff_idle / diff_total)) * 100.0, 1)
            with open(stat_file, 'w') as sf:
                sf.write(f"{idle} {total}")
        else:
            time.sleep(0.04)
            with open('/proc/stat', 'r') as f2:
                line2 = f2.readline()
            parts2 = [int(x) for x in line2.split()[1:]]
            idle2 = parts2[3] + (parts2[4] if len(parts2) > 4 else 0)
            total2 = sum(parts2)
            with open(stat_file, 'w') as sf:
                sf.write(f"{idle2} {total2}")
            dt = total2 - total
            di = idle2 - idle
            if dt > 0:
                cpu_pct = round((1.0 - (di / dt)) * 100.0, 1)
    except Exception:
        pass

    loads = ["0.00", "0.00", "0.00"]
    try:
        with open('/proc/loadavg', 'r') as lf:
            loads = lf.read().strip().split()[:3]
    except Exception:
        pass

    return {
        "cpu_total": max(0.0, min(100.0, cpu_pct)),
        "cpu_count": os.cpu_count() or 1,
        "load_1": loads[0] if len(loads) > 0 else "0.00",
        "load_5": loads[1] if len(loads) > 1 else "0.00",
        "load_15": loads[2] if len(loads) > 2 else "0.00"
    }

def get_hyprland_windows():
    client_pids = {}
    try:
        p = subprocess.run(['hyprctl', 'clients', '-j'], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=0.8)
        clients = json.loads(p.stdout.decode('utf-8'))
        for c in clients:
            c_pid = c.get('pid')
            if c_pid:
                ws = c.get('workspace', {})
                ws_name = ws.get('name', str(ws.get('id', '')))
                client_pids[c_pid] = {
                    'class': c.get('class', ''),
                    'title': c.get('title', ''),
                    'initialClass': c.get('initialClass', ''),
                    'address': c.get('address', ''),
                    'workspace': ws_name,
                    'floating': c.get('floating', False),
                    'fullscreen': c.get('fullscreen', 0) > 0
                }
    except Exception:
        pass
    return client_pids

def get_all_pss():
    pss_map = {}
    try:
        for entry in os.scandir('/proc'):
            if entry.is_dir() and entry.name.isdigit():
                try:
                    with open(f'{entry.path}/smaps_rollup', 'r') as f:
                        for line in f:
                            if line.startswith('Pss:'):
                                pss_map[int(entry.name)] = int(line.split()[1])
                                break
                except Exception:
                    pass
    except Exception:
        pass
    return pss_map

def list_processes():
    mem_info = get_mem_info()
    cpu_info = get_cpu_info()
    client_pids = get_hyprland_windows()
    pss_map = get_all_pss()

    try:
        out = subprocess.check_output(
            ['ps', '-eo', 'pid:10,ppid:10,user:20,%cpu:6,%mem:6,rss:12,comm:30,args'],
            stderr=subprocess.DEVNULL,
            timeout=2.0
        ).decode('utf-8', errors='ignore')
        lines = out.strip().split('\n')
    except Exception:
        lines = []

    procs = {}
    seen_pids = set()

    for line in lines[1:]:
        if len(line) < 70:
            continue
        try:
            pid = int(line[0:10].strip())
            if pid in seen_pids or pid <= 0:
                continue
            seen_pids.add(pid)

            ppid = int(line[11:21].strip())
            user = line[22:42].strip()
            cpu = float(line[43:49].strip())
            mem_pct = float(line[50:56].strip())
            rss_kb = int(line[57:69].strip())
            comm = line[70:100].strip()
            args = line[101:].strip()

            is_kernel = (ppid == 2 or pid == 2 or comm.startswith('kworker') or comm.startswith('kthread') or (args.startswith('[') and args.endswith(']')))

            # PSS for proportional shared memory, RSS for resident set size matching btop/top
            pss_kb = pss_map.get(pid, rss_kb)
            proc_mem_mb = round(rss_kb / 1024.0, 1)
            proc_mem_pct = round((rss_kb * 1024.0 / mem_info['mem_total_bytes']) * 100.0, 1) if mem_info['mem_total_bytes'] > 0 else 0.0

            procs[pid] = {
                'pid': pid,
                'ppid': ppid,
                'user': user,
                'cpu': cpu,
                'mem_pct': proc_mem_pct,
                'mem_kb': pss_kb,
                'rss_kb': rss_kb,
                'mem_mb': proc_mem_mb,
                'comm': comm,
                'args': args,
                'is_kernel': is_kernel
            }
        except Exception:
            continue

    # Session boundaries: do not cross these when walking ancestry for child processes
    SESSION_BOUNDARIES = {'systemd', 'hyprland', 'init', 'dbus-daemon', 'dbus-broker'}

    # 1. Discover window client apps & traverse their child subprocesses
    window_children = defaultdict(list)
    claimed_by_window = set()

    for w_pid in client_pids:
        claimed_by_window.add(w_pid)
        queue = [w_pid]
        visited = {w_pid}
        while queue:
            curr = queue.pop(0)
            for p, d in procs.items():
                if d['ppid'] == curr and p not in visited:
                    visited.add(p)
                    # Don't swallow another top-level window client
                    if p in client_pids:
                        continue
                    # Skip task_manager.py helper itself
                    if 'task_manager.py' in d['args']:
                        continue
                    queue.append(p)
                    window_children[w_pid].append(d)
                    claimed_by_window.add(p)

    # 2. Also group orphan workers of window apps (e.g. Spotify crashpad or background workers)
    for pid, p in procs.items():
        if p['is_kernel'] or pid in claimed_by_window:
            continue
        c_lower = p['comm'].lower()
        if c_lower == 'spotify':
            for w_pid, w_info in client_pids.items():
                if 'spotify' in w_info.get('class', '').lower():
                    window_children[w_pid].append(p)
                    claimed_by_window.add(pid)
                    break

    # 3. Discover standalone user applications & desktop tools
    standalone_apps = {}
    standalone_children = defaultdict(list)

    for pid, p in procs.items():
        if p['is_kernel'] or pid in claimed_by_window:
            continue
        comm = p['comm']
        if any(token_matches(comm, k) for k in USER_APP_KEYS):
            is_standalone_root = True
            curr = p['ppid']
            visited = {pid}
            while curr in procs and curr not in visited and curr > 1:
                visited.add(curr)
                p_comm = procs[curr]['comm']
                if p_comm in SESSION_BOUNDARIES:
                    break
                if curr in standalone_apps:
                    is_standalone_root = False
                    standalone_children[curr].append(p)
                    break
                curr = procs[curr]['ppid']

            if is_standalone_root:
                standalone_apps[pid] = p

    # Build Grouped APPS List
    apps_list = []

    # 1. Add window applications
    for w_pid, w_info in client_pids.items():
        root_proc = procs.get(w_pid)
        children = window_children.get(w_pid, [])
        comm = root_proc['comm'] if root_proc else w_info.get('class', 'app')
        p_class = w_info.get('class', '')
        disp_name, icon_name, icon_sym = resolve_app_info(comm, p_class)

        all_pids = [w_pid] + [c['pid'] for c in children]
        tot_cpu = round((root_proc['cpu'] if root_proc else 0.0) + sum(c['cpu'] for c in children), 1)
        if children:
            tot_mem_kb = (root_proc['mem_kb'] if root_proc else 0) + sum(c['mem_kb'] for c in children)
        else:
            tot_mem_kb = root_proc['rss_kb'] if root_proc else 0
        tot_mb = round(tot_mem_kb / 1024.0, 1)
        tot_pct = round((tot_mem_kb * 1024 / mem_info['mem_total_bytes']) * 100.0, 1) if mem_info['mem_total_bytes'] > 0 else 0.0

        title = w_info.get('title') or (root_proc['args'].split()[0] if root_proc and root_proc['args'] else comm)
        user = root_proc['user'] if root_proc else ''

        clean_children = []
        for c in children:
            c_title, c_icon = clean_child_info(c['comm'], c['args'])
            clean_children.append({
                "pid": c['pid'],
                "name": c['comm'],
                "title": c_title,
                "icon": c_icon,
                "cpu": c['cpu'],
                "mem_mb": c['mem_mb'],
                "mem_percent": c['mem_pct']
            })
        clean_children.sort(key=lambda x: (x['cpu'], x['mem_mb']), reverse=True)

        apps_list.append({
            "pid": w_pid,
            "all_pids": all_pids,
            "name": comm,
            "display_name": disp_name,
            "title": title,
            "class": p_class,
            "category": "app",
            "cpu": tot_cpu,
            "mem_bytes": tot_mem_kb * 1024,
            "mem_mb": tot_mb,
            "mem_percent": tot_pct,
            "user": user,
            "status": "running",
            "icon": icon_sym,
            "icon_name": icon_name,
            "is_kernel": False,
            "has_window": bool(w_info.get('address')),
            "workspace": w_info.get('workspace', ''),
            "address": w_info.get('address', ''),
            "proc_count": len(clean_children) + 1,
            "children": clean_children
        })

    # 2. Add standalone user apps & tools
    for s_pid, s_proc in standalone_apps.items():
        children = standalone_children.get(s_pid, [])
        comm = s_proc['comm']
        disp_name, icon_name, icon_sym = resolve_app_info(comm, '')

        all_pids = [s_pid] + [c['pid'] for c in children]
        tot_cpu = round(s_proc['cpu'] + sum(c['cpu'] for c in children), 1)
        if children:
            tot_mem_kb = s_proc['mem_kb'] + sum(c['mem_kb'] for c in children)
        else:
            tot_mem_kb = s_proc['rss_kb']
        tot_mb = round(tot_mem_kb / 1024.0, 1)
        tot_pct = round((tot_mem_kb * 1024 / mem_info['mem_total_bytes']) * 100.0, 1) if mem_info['mem_total_bytes'] > 0 else 0.0

        title = s_proc['args'].split()[0] if s_proc['args'] else comm

        clean_children = []
        for c in children:
            c_title, c_icon = clean_child_info(c['comm'], c['args'])
            clean_children.append({
                "pid": c['pid'],
                "name": c['comm'],
                "title": c_title,
                "icon": c_icon,
                "cpu": c['cpu'],
                "mem_mb": c['mem_mb'],
                "mem_percent": c['mem_pct']
            })
        clean_children.sort(key=lambda x: (x['cpu'], x['mem_mb']), reverse=True)

        apps_list.append({
            "pid": s_pid,
            "all_pids": all_pids,
            "name": comm,
            "display_name": disp_name,
            "title": title,
            "class": "",
            "category": "app",
            "cpu": tot_cpu,
            "mem_bytes": tot_mem_kb * 1024,
            "mem_mb": tot_mb,
            "mem_percent": tot_pct,
            "user": s_proc['user'],
            "status": "running",
            "icon": icon_sym,
            "icon_name": icon_name,
            "is_kernel": False,
            "has_window": False,
            "workspace": "",
            "address": "",
            "proc_count": len(clean_children) + 1,
            "children": clean_children
        })

    apps_list.sort(key=lambda x: (x['cpu'], x['mem_mb']), reverse=True)

    # Claimed PIDs across all apps and their children
    app_claimed_pids = set()
    for a in apps_list:
        app_claimed_pids.update(a['all_pids'])

    # Build BACKGROUND Services List
    bg_list = []
    for pid, p in procs.items():
        if p['is_kernel'] or pid in app_claimed_pids:
            continue
        disp_name, icon_name, icon_sym = resolve_app_info(p['comm'], '')
        bg_list.append({
            "pid": pid,
            "all_pids": [pid],
            "name": p['comm'],
            "display_name": disp_name,
            "title": p['args'].split()[0] if p['args'] else p['comm'],
            "class": "",
            "category": "background",
            "cpu": p['cpu'],
            "mem_bytes": p['rss_kb'] * 1024,
            "mem_mb": p['mem_mb'],
            "mem_percent": p['mem_pct'],
            "user": p['user'],
            "status": "running",
            "icon": icon_sym,
            "icon_name": icon_name,
            "is_kernel": False,
            "has_window": False,
            "workspace": "",
            "address": "",
            "proc_count": 1,
            "children": []
        })
    bg_list.sort(key=lambda x: (x['cpu'], x['mem_mb']), reverse=True)

    # Build ALL Processes List
    all_list = []
    for pid, p in procs.items():
        disp_name, icon_name, icon_sym = resolve_app_info(p['comm'], '')
        is_client = pid in client_pids
        win_info = client_pids.get(pid, {})
        all_list.append({
            "pid": pid,
            "all_pids": [pid],
            "name": p['comm'],
            "display_name": disp_name,
            "title": win_info.get('title') if win_info.get('title') else (p['args'].split()[0] if p['args'] else p['comm']),
            "class": win_info.get('class', ''),
            "category": "app" if is_client else "background",
            "cpu": p['cpu'],
            "mem_bytes": p['rss_kb'] * 1024,
            "mem_mb": p['mem_mb'],
            "mem_percent": p['mem_pct'],
            "user": p['user'],
            "status": "running",
            "icon": icon_sym,
            "icon_name": icon_name,
            "is_kernel": p['is_kernel'],
            "has_window": is_client,
            "workspace": win_info.get('workspace', ''),
            "address": win_info.get('address', ''),
            "proc_count": 1,
            "children": []
        })
    all_list.sort(key=lambda x: (x['cpu'], x['mem_mb']), reverse=True)

    result = {
        "cpu_total": cpu_info["cpu_total"],
        "cpu_count": cpu_info["cpu_count"],
        "load_1": cpu_info["load_1"],
        "load_5": cpu_info["load_5"],
        "load_15": cpu_info["load_15"],
        "mem_total_bytes": mem_info["mem_total_bytes"],
        "mem_used_bytes": mem_info["mem_used_bytes"],
        "mem_total_gb": mem_info["mem_total_gb"],
        "mem_used_gb": mem_info["mem_used_gb"],
        "mem_percent": mem_info["mem_percent"],
        "tasks_total": len(all_list),
        "tasks_apps": len(apps_list),
        "tasks_bg": len(bg_list),
        "apps": apps_list,
        "background": bg_list,
        "all": all_list,
        "processes": apps_list + bg_list
    }

    print(json.dumps(result))

def kill_process(pid_str, force=False):
    try:
        pid = int(pid_str)
    except ValueError:
        print(json.dumps({"success": False, "error": "Invalid PID"}))
        return

    proc_name = f"PID {pid}"
    try:
        with open(f"/proc/{pid}/comm", "r") as f:
            proc_name = f.read().strip()
    except Exception:
        pass

    sig = signal.SIGKILL if force else signal.SIGTERM

    # 1. Kill primary process
    try:
        os.kill(pid, sig)
    except ProcessLookupError:
        print(json.dumps({"success": True, "pid": pid, "name": proc_name, "note": "Already terminated"}))
        return
    except PermissionError:
        print(json.dumps({"success": False, "error": "Permission denied"}))
        return
    except Exception as e:
        print(json.dumps({"success": False, "error": str(e)}))
        return

    # 2. Also terminate child processes if any
    try:
        out = subprocess.check_output(['pgrep', '-P', str(pid)], stderr=subprocess.DEVNULL, timeout=0.5).decode('utf-8')
        for child_pid in out.strip().split():
            try:
                os.kill(int(child_pid), sig)
            except Exception:
                pass
    except Exception:
        pass

    print(json.dumps({"success": True, "pid": pid, "name": proc_name, "forced": force}))

def focus_window(target):
    if not target:
        print(json.dumps({"success": False, "error": "Missing target"}))
        return

    formatted_addr = target if target.startswith("0x") else f"0x{target}"

    # Try Lua dispatch first (for Hyprland Lua setups)
    try:
        res = subprocess.run(
            ['hyprctl', 'dispatch', f"hl.dsp.focus({{ window = 'address:{formatted_addr}' }})"],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=1.0
        )
        if res.returncode == 0 and "ok" in res.stdout.lower():
            print(json.dumps({"success": True, "target": target, "method": "lua"}))
            return
    except Exception:
        pass

    # Standard Hyprland fallback
    try:
        subprocess.run(
            ['hyprctl', 'dispatch', 'focuswindow', f"address:{formatted_addr}"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=1.0
        )
        print(json.dumps({"success": True, "target": target, "method": "standard"}))
    except Exception as e:
        print(json.dumps({"success": False, "error": str(e)}))

if __name__ == "__main__":
    if len(sys.argv) > 1:
        cmd = sys.argv[1]
        if cmd == "kill":
            if len(sys.argv) > 2:
                force = len(sys.argv) > 3 and (sys.argv[3] in ["--force", "-9", "force"])
                kill_process(sys.argv[2], force=force)
            else:
                print(json.dumps({"success": False, "error": "Missing PID"}))
        elif cmd == "focus":
            if len(sys.argv) > 2:
                focus_window(sys.argv[2])
            else:
                print(json.dumps({"success": False, "error": "Missing target"}))
        else:
            list_processes()
    else:
        list_processes()
