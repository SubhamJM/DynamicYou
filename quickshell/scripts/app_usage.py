#!/usr/bin/env python3
import sys
import os
import json
import time

USAGE_FILE = os.path.expanduser('~/.local/state/dms/appusage.json')

def load_data():
    if os.path.exists(USAGE_FILE):
        try:
            with open(USAGE_FILE, 'r') as fp:
                return json.load(fp)
        except Exception:
            pass
    return {"appUsageRanking": {}}

def get_scores():
    data = load_data()
    ranking = data.get("appUsageRanking", {})
    scores = {}
    for k, v in ranking.items():
        cnt = v.get("usageCount", 0)
        last = v.get("lastUsed", 0)
        score = cnt * 1000 + (1 if last else 0)
        k_clean = str(k).lower().strip()
        scores[k_clean] = score
        if k_clean.endswith(".desktop"):
            scores[k_clean[:-8]] = score
        else:
            scores[k_clean + ".desktop"] = score
        if v.get("name"):
            scores[str(v["name"]).lower().strip()] = score
        if v.get("exec"):
            parts = str(v["exec"]).strip().split()
            if parts:
                exe = os.path.basename(parts[0]).lower()
                scores[exe] = score
    print(json.dumps(scores))

def record_usage(app_id, name, exec_cmd):
    data = load_data()
    ranking = data.setdefault("appUsageRanking", {})
    key = app_id if app_id else (name if name else exec_cmd)
    if not key:
        return
    clean_key = str(key).strip()
    if clean_key.endswith(".desktop"):
        clean_key = clean_key[:-8]
    
    # Try to find matching existing key
    matched_key = None
    for existing in ranking.keys():
        ex_clean = existing[:-8] if existing.endswith(".desktop") else existing
        if ex_clean.lower() == clean_key.lower():
            matched_key = existing
            break
    
    final_key = matched_key if matched_key else clean_key
    entry = ranking.setdefault(final_key, {
        "name": name or final_key,
        "exec": exec_cmd or "",
        "icon": final_key,
        "comment": "",
        "usageCount": 0,
        "lastUsed": 0
    })
    entry["usageCount"] = entry.get("usageCount", 0) + 1
    entry["lastUsed"] = int(time.time() * 1000)
    if name and not entry.get("name"):
        entry["name"] = name
    if exec_cmd and not entry.get("exec"):
        entry["exec"] = exec_cmd

    os.makedirs(os.path.dirname(USAGE_FILE), exist_ok=True)
    try:
        with open(USAGE_FILE, 'w') as fp:
            json.dump(data, fp, indent=2)
    except Exception:
        pass

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "record":
        app_id = sys.argv[2] if len(sys.argv) > 2 else ""
        name = sys.argv[3] if len(sys.argv) > 3 else ""
        exec_cmd = sys.argv[4] if len(sys.argv) > 4 else ""
        record_usage(app_id, name, exec_cmd)
    else:
        get_scores()
