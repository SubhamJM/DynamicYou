#!/usr/bin/env python3
"""Build Material role names from a selected preset, never from wallpaper pixels."""
import json
import sys
from pathlib import Path


def blend(a, b, amount):
    aa = [int(a[i:i + 2], 16) for i in (1, 3, 5)]
    bb = [int(b[i:i + 2], 16) for i in (1, 3, 5)]
    return '#' + ''.join(f'{round(x * (1 - amount) + y * amount):02x}' for x, y in zip(aa, bb))


def palette(c):
    bg, card, hover, accent, text = (c[k] for k in ('bg', 'card_bg', 'hover_bg', 'accent', 'text_primary'))
    subtext = c.get('text_secondary', '#9aa3b2')
    secondary = c.get('secondary_accent', accent)
    tertiary = c.get('tertiary_accent', secondary)
    border = c.get('border', hover)
    on_accent = '#101014' if sum(int(accent[i:i + 2], 16) * w for i, w in ((1, .2126), (3, .7152), (5, .0722))) > 132 else '#ffffff'
    on_sec = '#101014' if sum(int(secondary[i:i + 2], 16) * w for i, w in ((1, .2126), (3, .7152), (5, .0722))) > 132 else '#ffffff'
    on_tert = '#101014' if sum(int(tertiary[i:i + 2], 16) * w for i, w in ((1, .2126), (3, .7152), (5, .0722))) > 132 else '#ffffff'
    return dict(primary=accent, on_primary=on_accent, primary_container=blend(card, accent, .18), on_primary_container=text,
                secondary=secondary, on_secondary=on_sec, secondary_container=blend(card, secondary, .14), on_secondary_container=text,
                tertiary=tertiary, on_tertiary=on_tert, tertiary_container=blend(hover, tertiary, .14), on_tertiary_container=text,
                surface=bg, on_surface=text, surface_variant=card, on_surface_variant=subtext,
                surface_dim=bg, surface_bright=hover, surface_container_lowest=blend(bg, '#000000', .22),
                surface_container_low=card, surface_container=blend(card, hover, .45),
                surface_container_high=hover, surface_container_highest=blend(hover, text, .08),
                outline=border, outline_variant=blend(bg, border, .65), inverse_surface=text,
                inverse_on_surface=bg, inverse_primary=accent, background=bg, on_background=text,
                shadow='#000000', scrim='#000000', surface_tint=accent,
                error=c.get('error', '#ffb4ab'), on_error='#390005', error_container='#93000a', on_error_container='#ffdad6')


if __name__ == '__main__':
    source, destination = map(Path, sys.argv[1:3])
    colors = json.loads(source.read_text())
    result = palette(colors)
    destination.parent.mkdir(parents=True, exist_ok=True)
    temp = destination.with_name(destination.name + '.tmp')
    temp.write_text(json.dumps(result, indent=2) + '\n')
    temp.replace(destination)
