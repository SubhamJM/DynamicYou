#!/usr/bin/env python3
import sys
import os
import time
import json
import subprocess
import signal

try:
    import psutil
except ImportError:
    psutil = None

def get_icon_and_display_name(name, p_class, p_title):
    n = name.lower()
    c = (p_class or '').lower()
    
    if 'zen' in n or 'zen' in c:
        return 'language', 'Zen Browser'
    if 'firefox' in n or 'chrome' in n or 'chromium' in n or 'brave' in n or 'browser' in c:
        return 'language', 'Web Browser'
    if 'kitty' in n or 'kitty' in c:
        return 'terminal', 'Kitty Terminal'
    if 'alacritty' in n or 'foot' in n or 'wezterm' in n or 'terminal' in c:
        return 'terminal', 'Terminal'
    if 'code' in n or 'vscodium' in n:
        return 'code', 'Visual Studio Code'
    if 'nvim' in n or 'vim' in n:
        return 'code', 'Neovim'
    if 'networkmanager' in n or 'nmcli' in n:
        return 'wifi', 'NetworkManager'
    if n == 'et' or 'wps' in n:
        return 'description', 'WPS Spreadsheets' if n == 'et' else 'WPS Office'
    if 'quickshell' in n or n == 'qs':
        return 'widgets', 'Quickshell'
    if 'hyprland' in n:
        return 'desktop_windows', 'Hyprland'
    if 'pipewire' in n or 'wireplumber' in n or 'pulseaudio' in n:
        return 'volume_up', 'Audio Server'
    if 'spotify' in n:
        return 'music_note', 'Spotify'
    if 'discord' in n or 'vesktop' in n:
        return 'forum', 'Discord'
    if 'python' in n:
        return 'terminal', 'Python'
    if n in ['bash', 'zsh', 'sh', 'fish'] or n.endswith('sh'):
        return 'terminal', 'Shell'
    if 'systemd' in n:
        return 'settings', 'systemd'
    if 'yazi' in n:
        return 'folder', 'Yazi File Manager'
    if 'thunar' in n or 'nautilus' in n or 'dolphin' in n:
        return 'folder', 'File Manager'
    if 'steam' in n:
        return 'sports_esports', 'Steam'
    if 'obs' in n:
        return 'videocam', 'OBS Studio'
    if 'mpv' in n or 'vlc' in n:
        return 'play_circle', 'Media Player'
    if 'hypridle' in n or 'hyprlock' in n or 'hyprpaper' in n or 'awww' in n:
        return 'palette', name
    if 'bluetoothd' in n:
        return 'bluetooth', 'Bluetooth'

    if p_class:
        return 'window', p_class.capitalize()
    return 'memory', name

def list_processes():
    if not psutil:
        print(json.dumps({"error": "psutil not installed"}))
        return

    # Hyprland graphical clients
    client_pids = {}
    try:
        p = subprocess.run(['hyprctl', 'clients', '-j'], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        clients = json.loads(p.stdout.decode('utf-8'))
        for c in clients:
            c_pid = c.get('pid')
            if c_pid:
                client_pids[c_pid] = {
                    'class': c.get('class', ''),
                    'title': c.get('title', ''),
                    'initialClass': c.get('initialClass', '')
                }
    except Exception:
        pass

    # Sample CPU percent
    for p in psutil.process_iter():
        try:
            p.cpu_percent()
        except Exception:
            pass

    time.sleep(0.04)

    mem = psutil.virtual_memory()
    cpu_total = psutil.cpu_percent()

    procs = []
    seen_pids = set()

    for p in psutil.process_iter(['pid', 'ppid', 'name', 'cmdline', 'cpu_percent', 'memory_info', 'username', 'status']):
        try:
            info = p.info
            pid = info['pid']
            if pid in seen_pids or pid == 0:
                continue
            seen_pids.add(pid)

            ppid = info['ppid'] or 0
            name = info['name'] or 'unknown'
            cmd = info['cmdline'] or []
            is_kernel = (ppid == 2 or pid == 2 or len(cmd) == 0)

            cpu = round(info['cpu_percent'] or 0.0, 1)
            mem_info = info['memory_info']
            rss = mem_info.rss if mem_info else 0
            mem_mb = round(rss / (1024 * 1024), 1)
            mem_pct = round((rss / mem.total) * 100.0, 1) if mem.total > 0 else 0.0

            # Determine if this process is an interactive application
            is_app = False
            app_title = ''
            app_class = ''

            if pid in client_pids:
                is_app = True
                app_title = client_pids[pid].get('title', '')
                app_class = client_pids[pid].get('class', '')
            elif ppid in client_pids:
                is_app = True
                app_title = client_pids[ppid].get('title', '')
                app_class = client_pids[ppid].get('class', '')

            icon, display_name = get_icon_and_display_name(name, app_class, app_title)

            # Extra app classification based on known desktop apps even if window is unmapped
            if not is_app and not is_kernel:
                lower_name = name.lower()
                if lower_name in ['zen-bin', 'zen', 'firefox', 'kitty', 'code', 'discord', 'vesktop', 'spotify', 'et', 'wps']:
                    is_app = True

            procs.append({
                "pid": pid,
                "ppid": ppid,
                "name": name,
                "display_name": display_name,
                "title": app_title if app_title else (cmd[0] if cmd else name),
                "class": app_class,
                "category": "app" if is_app else "background",
                "cpu": cpu,
                "mem_bytes": rss,
                "mem_mb": mem_mb,
                "mem_percent": mem_pct,
                "user": info['username'] or '',
                "status": info['status'] or 'running',
                "icon": icon,
                "is_kernel": is_kernel
            })
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            continue

    # Default sort by CPU % descending, then Memory descending
    procs.sort(key=lambda x: (x['cpu'], x['mem_mb']), reverse=True)

    result = {
        "cpu_total": round(cpu_total, 1),
        "cpu_count": psutil.cpu_count() or 1,
        "mem_total_bytes": mem.total,
        "mem_used_bytes": mem.used,
        "mem_total_gb": round(mem.total / (1024**3), 2),
        "mem_used_gb": round(mem.used / (1024**3), 2),
        "mem_percent": round(mem.percent, 1),
        "tasks_total": len(procs),
        "tasks_apps": len([p for p in procs if p['category'] == 'app']),
        "tasks_bg": len([p for p in procs if p['category'] == 'background' and not p['is_kernel']]),
        "processes": procs
    }

    print(json.dumps(result))

def kill_process(pid_str, force=False):
    try:
        pid = int(pid_str)
    except ValueError:
        print(json.dumps({"success": False, "error": "Invalid PID"}))
        return

    try:
        p = psutil.Process(pid) if psutil else None
        proc_name = p.name() if p else f"PID {pid}"
        if force:
            os.kill(pid, signal.SIGKILL)
        else:
            os.kill(pid, signal.SIGTERM)
        print(json.dumps({"success": True, "pid": pid, "name": proc_name, "forced": force}))
    except ProcessLookupError:
        print(json.dumps({"success": True, "pid": pid, "note": "Already terminated"}))
    except PermissionError:
        print(json.dumps({"success": False, "error": "Permission denied"}))
    except Exception as e:
        print(json.dumps({"success": False, "error": str(e)}))

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "kill":
        if len(sys.argv) > 2:
            force = len(sys.argv) > 3 and (sys.argv[3] == "--force" or sys.argv[3] == "-9")
            kill_process(sys.argv[2], force=force)
        else:
            print(json.dumps({"success": False, "error": "Missing PID"}))
    else:
        list_processes()
