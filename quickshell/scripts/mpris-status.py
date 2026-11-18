import dbus
import sys
import os
import urllib.request
import hashlib

try:
    bus = dbus.SessionBus()
    players = [n for n in bus.list_names() if n.startswith("org.mpris.MediaPlayer2.")]
    
    selected_player = None
    selected_props = None
    
    # Priority selection: Playing with title > Playing > Paused with title > Any with title
    candidates = []
    for p in players:
        if "playerctld" in p.lower():
            continue
        try:
            proxy = bus.get_object(p, "/org/mpris/MediaPlayer2")
            props_iface = dbus.Interface(proxy, "org.freedesktop.DBus.Properties")
            props = props_iface.GetAll("org.mpris.MediaPlayer2.Player")
            status = str(props.get("PlaybackStatus", ""))
            meta = props.get("Metadata", {})
            title = str(meta.get("xesam:title", "")).strip()
            
            score = 0
            if status == "Playing":
                score = 100 if title else 80
            elif status == "Paused":
                score = 60 if title else 30
            elif title:
                score = 40
            else:
                score = 10
            
            candidates.append((score, p, props))
        except Exception:
            continue

    if candidates:
        candidates.sort(key=lambda x: x[0], reverse=True)
        selected_player = candidates[0][1]
        selected_props = candidates[0][2]
            
    if selected_props:
        status = str(selected_props.get("PlaybackStatus", ""))
        meta = selected_props.get("Metadata", {})
        title = str(meta.get("xesam:title", ""))
        artists = meta.get("xesam:artist", [""])
        if isinstance(artists, (list, tuple, dbus.Array)) and len(artists) > 0:
            artist = str(artists[0])
        else:
            artist = str(artists) if artists else ""
        art = str(meta.get("mpris:artUrl", ""))
        
        # Cache remote artwork locally for fast & error-free QML loading
        if art.startswith("http://") or art.startswith("https://"):
            try:
                hash_val = hashlib.md5(art.encode()).hexdigest()
                cache_path = f"/tmp/mpris_art_{hash_val}.jpg"
                if not os.path.exists(cache_path) or os.path.getsize(cache_path) == 0:
                    tmp_dl = cache_path + ".tmp"
                    urllib.request.urlretrieve(art, tmp_dl)
                    os.replace(tmp_dl, cache_path)
                art = f"file://{cache_path}"
            except Exception:
                pass

        try:
            pos = int(selected_props.get("Position", 0))
        except Exception:
            pos = 0
        try:
            length = int(meta.get("mpris:length", 0))
        except Exception:
            length = 0

        # Extract vibrant color using Iris 1:1 ColorQuantizer algorithm
        vibrant_hex = ""
        img_path = ""
        if art.startswith("file://"):
            img_path = art[7:]
        elif os.path.exists(art):
            img_path = art

        if img_path and os.path.exists(img_path):
            try:
                from PIL import Image, ImageFile
                import colorsys
                ImageFile.LOAD_TRUNCATED_IMAGES = True
                im = Image.open(img_path).convert("RGB")
                im = im.resize((48, 48))
                colors = im.getcolors(48 * 48)
                if colors:
                    best = None
                    best_score = -1
                    for count, col in colors:
                        r, g, b = [x / 255.0 for x in col[:3]]
                        h, l, s = colorsys.rgb_to_hls(r, g, b)
                        if s < 0.14 or h < 0:
                            continue
                        score = s * (1.0 - abs(l - 0.5))
                        if score > best_score:
                            best_score = score
                            target_s = max(0.50, min(1.0, s))
                            target_l = max(0.64, min(0.76, l + 0.22))
                            r2, g2, b2 = colorsys.hls_to_rgb(h, target_l, target_s)
                            best = f"#{int(r2*255):02x}{int(g2*255):02x}{int(b2*255):02x}"
                    if best:
                        vibrant_hex = best
            except Exception:
                pass

        if vibrant_hex:
            try:
                with open("/tmp/current_accent.txt", "w") as f:
                    f.write(vibrant_hex)
            except Exception:
                pass

        print(f"{status}\n{title}\n{artist}\n{art}\n{pos}\n{length}\n{vibrant_hex}")
    else:
        print("\n\n\n\n\n\n")
except Exception:
    print("\n\n\n\n\n\n")
