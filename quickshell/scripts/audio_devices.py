#!/usr/bin/env python3
import sys
import json
import subprocess
import re

def get_audio_info():
    try:
        out = subprocess.check_output(['wpctl', 'status'], text=True, stderr=subprocess.DEVNULL)
    except Exception:
        out = ""

    sinks = []
    sources = []
    section = None

    for line in out.splitlines():
        clean = line.strip().replace('│', '').strip()
        if 'Sinks:' in line:
            section = 'sinks'
            continue
        elif 'Sources:' in line:
            section = 'sources'
            continue
        elif 'Filters:' in line or 'Streams:' in line or 'Devices:' in line or 'Settings' in line:
            section = None
            continue

        if section in ('sinks', 'sources') and clean:
            m = re.match(r'^(\*?)\s*(\d+)\.\s+(.*?)(?:\s+\[vol:.*\])?$', clean)
            if m:
                is_default = (m.group(1) == '*')
                dev_id = m.group(2)
                desc = m.group(3).strip()
                item = {
                    'id': dev_id,
                    'name': dev_id,
                    'desc': desc,
                    'isDefault': is_default
                }
                if section == 'sinks':
                    sinks.append(item)
                else:
                    sources.append(item)

    return {"sinks": sinks, "sources": sources}

def set_sink(sink_id):
    try:
        # Strip any non-digit prefix if needed
        m = re.search(r'\d+', str(sink_id))
        sid = m.group(0) if m else str(sink_id)
        subprocess.run(['wpctl', 'set-default', sid], check=True, stderr=subprocess.DEVNULL)
    except Exception:
        pass

def set_source(source_id):
    try:
        m = re.search(r'\d+', str(source_id))
        sid = m.group(0) if m else str(source_id)
        subprocess.run(['wpctl', 'set-default', sid], check=True, stderr=subprocess.DEVNULL)
    except Exception:
        pass

if __name__ == "__main__":
    if len(sys.argv) > 2 and sys.argv[1] == "set-sink":
        set_sink(sys.argv[2])
    elif len(sys.argv) > 2 and sys.argv[1] == "set-source":
        set_source(sys.argv[2])
    else:
        print(json.dumps(get_audio_info()))
