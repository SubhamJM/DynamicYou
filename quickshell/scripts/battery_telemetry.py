#!/usr/bin/env python3
import os
import sys
import glob
import json
import subprocess
import re

def keyboard_backlights():
    return sorted(glob.glob('/sys/class/leds/*kbd_backlight'))


def display_modes():
    monitors = json.loads(subprocess.check_output(['hyprctl', 'monitors', '-j'], text=True, stderr=subprocess.DEVNULL))
    monitor = next((m for m in monitors if m.get('name', '').startswith(('eDP-', 'LVDS-', 'DSI-'))), None)
    if not monitor:
        return None, []
    dimensions = f"{monitor.get('width')}x{monitor.get('height')}"
    modes = []
    for mode in monitor.get('availableModes', []):
        match = re.fullmatch(r'(\d+x\d+)@(\d+(?:\.\d+)?)Hz', mode)
        if match and match.group(1) == dimensions:
            modes.append((float(match.group(2)), mode[:-2]))
    return monitor, sorted(modes)


def get_telemetry():
    bats = battery_paths()
    if not bats:
        return {
            'percentage': 100,
            'status': 'AC Connected',
            'isCharging': False,
            'isFull': True,
            'powerW': 0.0,
            'voltageV': 0.0,
            'health': 100,
            'currentEnergyWh': 0.0,
            'fullEnergyWh': 0.0,
            'timeStr': 'Connected to AC Power',
            'chargeThreshold': 100,
            'chargeThresholdSupported': False,
            'refreshRate': 144,
            'kbdBacklight': 0,
            'topDrainers': []
        }

    bat = bats[0]

    def read_num(n):
        p = os.path.join(bat, n)
        if os.path.exists(p):
            try:
                return float(open(p).read().strip())
            except Exception:
                pass
        return 0.0

    def read_str(n, default=''):
        p = os.path.join(bat, n)
        if os.path.exists(p):
            try:
                return open(p).read().strip()
            except Exception:
                pass
        return default

    cap = int(read_num('capacity'))
    status = read_str('status', 'Discharging')
    is_charging = status.lower() == 'charging'
    is_full = (status.lower() in ('full', 'not charging')) and cap >= 95

    has_energy = os.path.exists(os.path.join(bat, 'energy_now')) or os.path.exists(os.path.join(bat, 'energy_full'))
    
    if has_energy:
        e_now = read_num('energy_now')
        e_full = read_num('energy_full')
        e_design = read_num('energy_full_design')
        p_now = read_num('power_now')
        v_now = read_num('voltage_now') or 11993000.0

        current_energy_wh = round(e_now / 1e6, 1)
        full_energy_wh = round(e_full / 1e6, 1)
        power_w = round(p_now / 1e6, 1)
        voltage_v = round(v_now / 1e6, 1)
        c_now = e_now
        c_full = e_full
        c_design = e_design
        cur = p_now
    else:
        c_now = read_num('charge_now')
        c_full = read_num('charge_full')
        c_design = read_num('charge_full_design')
        cur = read_num('current_now')
        v_now = read_num('voltage_now') or 11993000.0

        power_w = round((cur * v_now) / 1e12, 1)
        voltage_v = round(v_now / 1e6, 1)
        current_energy_wh = round((c_now * v_now) / 1e12, 1)
        full_energy_wh = round((c_full * v_now) / 1e12, 1)

    # Battery Health
    health = 100
    if c_design > 0:
        health = int(round((c_full / c_design) * 100))

    # Time remaining or time to full
    time_str = 'Calculating...'
    if is_full:
        time_str = 'Fully Charged'
    elif is_charging and cur > 0 and c_full > c_now:
        rem_hrs = (c_full - c_now) / cur
        hrs = int(rem_hrs)
        mins = int((rem_hrs - hrs) * 60)
        time_str = f'{hrs}h {mins}m until full' if hrs > 0 else f'{mins}m until full'
    elif not is_charging and cur > 0 and c_now > 0:
        rem_hrs = c_now / cur
        hrs = int(rem_hrs)
        mins = int((rem_hrs - hrs) * 60)
        time_str = f'{hrs}h {mins}m remaining' if hrs > 0 else f'{mins}m remaining'
    elif is_charging:
        time_str = 'Charging'
    else:
        time_str = f'{cap}% Discharging'

    # Read the first charge cap exposed by the kernel/firmware. Laptops without a
    # supported sysfs control report unsupported instead of pretending the cap is 100%.
    threshold_control = find_charge_threshold_control(bats)
    thresh = read_charge_threshold(threshold_control) if threshold_control else 100

    rr = 0
    refresh_supported = False
    try:
        monitor, modes = display_modes()
        if monitor:
            rr = round(monitor.get('refreshRate', 0))
            refresh_supported = len(modes) > 1 and modes[-1][0] - modes[0][0] > 1
    except (OSError, ValueError, subprocess.SubprocessError):
        pass

    backlights = keyboard_backlights()
    kbd = 0
    if backlights:
        try:
            with open(os.path.join(backlights[0], 'brightness')) as stream:
                kbd = int(stream.read().strip())
        except (OSError, ValueError):
            pass

    # Top CPU / Energy Draining Processes
    drainers = []
    try:
        ps_out = subprocess.check_output(['ps', '-eo', 'pid,%cpu,comm', '--sort=-%cpu'], stderr=subprocess.DEVNULL).decode().splitlines()
        seen = set()
        for line in ps_out[1:]:
            parts = line.strip().split(None, 2)
            if len(parts) == 3:
                try:
                    cpu_val = float(parts[1])
                except Exception:
                    continue
                comm = parts[2]
                cl = comm.lower()
                if cl in ('ps', 'python', 'python3', 'systemd', 'qs') or cl.startswith('[') or cl.startswith('kworker'):
                    continue
                if comm not in seen and cpu_val >= 0.1:
                    seen.add(comm)
                    icon = '󰘚'
                    name = comm
                    if 'zen' in cl or 'web' in cl: icon, name = '󰈹', 'Zen Browser'
                    elif 'firefox' in cl: icon, name = '󰈹', 'Firefox'
                    elif 'chrome' in cl or 'chromium' in cl: icon, name = '󰊯', 'Chrome'
                    elif 'brave' in cl: icon, name = '󰖟', 'Brave'
                    elif 'kitty' in cl: icon, name = '󰆍', 'Kitty'
                    elif 'alacritty' in cl or 'foot' in cl: icon, name = '󰆍', 'Terminal'
                    elif 'nvim' in cl: icon, name = '', 'Neovim'
                    elif 'hyprland' in cl: icon, name = '', 'Hyprland'
                    elif 'agy' in cl or 'antigravity' in cl: icon, name = '󰌠', 'AI CLI'
                    elif 'code' in cl: icon, name = '󰨞', 'VSCode'
                    elif 'discord' in cl or 'vesktop' in cl: icon, name = '󰙯', 'Discord'
                    elif 'spotify' in cl: icon, name = '󰓇', 'Spotify'
                    elif 'steam' in cl: icon, name = '󰓓', 'Steam'
                    elif 'obs' in cl: icon, name = '󰑋', 'OBS Studio'
                    elif 'vlc' in cl or 'mpv' in cl: icon, name = '󰕼', 'Media Player'
                    elif 'telegram' in cl: icon, name = '󰓧', 'Telegram'
                    drainers.append({'name': name, 'cpu': f'{cpu_val:.1f}%', 'cpuNum': cpu_val, 'icon': icon, 'pid': parts[0]})
                if len(drainers) >= 3:
                    break
    except Exception:
        pass

    return {
        'percentage': cap,
        'status': status,
        'isCharging': is_charging,
        'isFull': is_full,
        'powerW': power_w,
        'voltageV': voltage_v,
        'health': health,
        'currentEnergyWh': current_energy_wh,
        'fullEnergyWh': full_energy_wh,
        'timeStr': time_str,
        'chargeThreshold': thresh,
        'chargeThresholdSupported': bool(threshold_control),
        'refreshRate': rr,
        'refreshRateSupported': refresh_supported,
        'kbdBacklight': kbd,
        'kbdBacklightSupported': bool(backlights),
        'topDrainers': drainers
    }

def toggle_refresh_rate():
    try:
        monitor, modes = display_modes()
        if not monitor or len(modes) < 2 or modes[-1][0] - modes[0][0] <= 1:
            raise RuntimeError('No alternate refresh rate is available')
        current = float(monitor.get('refreshRate', 0))
        target = modes[-1] if abs(current - modes[0][0]) < 1 else modes[0]
        name = monitor['name']
        if not re.fullmatch(r'[A-Za-z0-9_.-]+', name):
            raise ValueError('Unsupported monitor name')
        scale = float(monitor.get('scale', 1))
        x, y = int(monitor.get('x', 0)), int(monitor.get('y', 0))
        cmd = f'hl.monitor({{ output = "{name}", mode = "{target[1]}", position = "{x}x{y}", scale = "{scale}" }})'
        subprocess.run(['hyprctl', 'eval', cmd], check=True, capture_output=True, text=True)
        print(json.dumps({'status': 'ok', 'newRate': round(target[0])}))
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as e:
        print(json.dumps({'status': 'error', 'message': str(e)}))


def toggle_kbd_backlight():
    try:
        backlights = keyboard_backlights()
        if not backlights:
            raise RuntimeError('No keyboard backlight is available')
        path = backlights[0]
        with open(os.path.join(path, 'brightness')) as stream:
            current = int(stream.read().strip())
        with open(os.path.join(path, 'max_brightness')) as stream:
            maximum = int(stream.read().strip())
        new_val = maximum if current == 0 else 0
        subprocess.run(['brightnessctl', '--device=' + os.path.basename(path), 'set', str(new_val)], check=True, capture_output=True)
        print(json.dumps({'status': 'ok', 'kbdBacklight': new_val}))
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as e:
        print(json.dumps({'status': 'error', 'message': str(e)}))

def battery_paths():
    paths = []
    for path in sorted(glob.glob('/sys/class/power_supply/*')):
        try:
            with open(os.path.join(path, 'type'), encoding='utf-8') as stream:
                if stream.read().strip() == 'Battery':
                    paths.append(path)
        except OSError:
            continue
    return paths


def charge_threshold_controls(batteries):
    """Known charge-limit interfaces with explicit kernel/vendor encodings."""
    controls = []
    for battery in batteries:
        for name in ('charge_control_end_threshold', 'charge_stop_threshold'):
            path = os.path.join(battery, name)
            if os.path.isfile(path):
                controls.append((path, 'number'))
        name = os.path.basename(os.path.realpath(battery))
        path = os.path.join('/sys/devices/platform/smapi', name, 'stop_charge_thresh')
        if os.path.isfile(path):
            controls.append((path, 'number'))
    for path, encoding in (
        ('/sys/devices/platform/lg-laptop/battery_care_limit', 'number'),
        ('/sys/devices/platform/sony-laptop/battery_care_limiter', 'number'),
        ('/sys/devices/platform/samsung/battery_life_extender', 'bool80'),
    ):
        if os.path.isfile(path):
            controls.append((path, encoding))
    for path in ('/sys/devices/platform/huawei-wmi/charge_control_thresholds',):
        if os.path.isfile(path):
            controls.append((path, 'pair'))
    # Preserve discovery order and avoid touching the same sysfs node twice.
    unique = []
    seen = set()
    for path, encoding in controls:
        real = os.path.realpath(path)
        if real not in seen:
            seen.add(real)
            unique.append((path, encoding))
    return unique


def find_charge_threshold_control(batteries=None):
    batteries = battery_paths() if batteries is None else batteries
    controls = charge_threshold_controls(batteries)
    return controls[0] if controls else None


def read_charge_threshold(control):
    path, encoding = control
    try:
        with open(path, encoding='utf-8') as stream:
            values = stream.read().strip().split()
        if not values:
            return 100
        if encoding == 'bool80':
            return 80 if int(values[0]) else 100
        return int(values[-1])
    except (OSError, ValueError):
        return 100


def write_charge_threshold(control, value):
    path, encoding = control
    if encoding == 'bool80':
        payload = '1' if value == 80 else '0'
    elif encoding == 'pair':
        try:
            with open(path, encoding='utf-8') as stream:
                current = stream.read().strip().split()
            start = int(current[0]) if current else 50
        except (OSError, ValueError):
            start = 50
        payload = f'{min(start, value)} {value}'
    else:
        payload = str(value)
    try:
        with open(path, 'w', encoding='utf-8') as stream:
            stream.write(payload)
    except PermissionError:
        result = subprocess.run(
            ['pkexec', '/usr/bin/tee', '--', path],
            input=payload, capture_output=True, text=True, timeout=45,
        )
        if result.returncode != 0:
            detail = (result.stderr or result.stdout).strip()
            raise RuntimeError(detail or 'Authorization was cancelled or the firmware denied the change')
    actual = read_charge_threshold(control)
    if actual != value:
        raise RuntimeError(f'Firmware reported {actual}% after requesting {value}%')


def set_charge_threshold(val):
    try:
        val_int = int(val)
        if val_int not in (80, 100):
            raise ValueError('Charge Care supports 80% or 100%')
        controls = charge_threshold_controls(battery_paths())
        if not controls:
            raise RuntimeError('This laptop does not expose a supported charge limit')

        control = controls[0]
        write_charge_threshold(control, val_int)
        print(json.dumps({'status': 'ok', 'chargeThreshold': val_int, 'control': control[0]}))
    except Exception as error:
        print(json.dumps({'status': 'error', 'message': str(error)}))

def main():
    if len(sys.argv) > 1:
        cmd = sys.argv[1]
        if cmd == 'toggle_hz':
            toggle_refresh_rate()
        elif cmd == 'toggle_kbd':
            toggle_kbd_backlight()
        elif cmd == 'set_threshold' and len(sys.argv) > 2:
            set_charge_threshold(sys.argv[2])
        elif cmd == 'telemetry':
            print(json.dumps(get_telemetry()))
        else:
            print(json.dumps(get_telemetry()))
    else:
        print(json.dumps(get_telemetry()))

if __name__ == '__main__':
    main()
