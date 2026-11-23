"""Lucid’s Material 3 tone and light-surface calculations."""

import colorsys
import re


def _lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _gam(c):
    c = max(0.0, min(1.0, c))
    v = c * 12.92 if c <= 0.0031308 else 1.055 * (c ** (1 / 2.4)) - 0.055
    return max(0.0, min(1.0, v))


def P(h):
    """'#rrggbb' (or 'rrggbb', or '#rgb') -> 0-1 float triple."""
    h = h.strip().lstrip('#')
    if len(h) == 3:
        h = ''.join(ch * 2 for ch in h)
    h = h[:6]
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def hx(c):
    if isinstance(c, str):
        c = P(c)
    return '#' + ''.join(f'{round(x * 255):02x}' for x in c)


def _y(c):
    return 0.2126 * _lin(c[0]) + 0.7152 * _lin(c[1]) + 0.0722 * _lin(c[2])


def tone(c):
    if isinstance(c, str):
        c = P(c)
    y = _y(c)
    return y * 903.2963 if y <= 0.008856 else 116 * (y ** (1 / 3)) - 16


def _y_at(t):
    return t / 903.2963 if t <= 8 else ((t + 16) / 116) ** 3


def at_tone(c, t):
    """Re-tone a colour to an exact M3 tone, holding its hue. Scaling in
    linear light is what preserves the hue; the same scale on gamma-encoded
    channels would drag it."""
    if isinstance(c, str):
        c = P(c)
    target = _y_at(max(0, min(100, t)))
    y = _y(c)
    if y <= 0:
        g = _gam(target)
        return (g, g, g)
    l = [_lin(x) * (target / y) for x in c]
    peak = max(l)
    if peak > 1:
        # scaling alone would clip a channel and skew the hue, so desaturate
        # toward white instead - what a tonal palette does near tone 100
        l = [x / peak for x in l]
        yb = 0.2126 * l[0] + 0.7152 * l[1] + 0.0722 * l[2]
        w = 0 if yb >= 1 else max(0, min(1, (target - yb) / (1 - yb)))
        l = [x + (1 - x) * w for x in l]
    return tuple(_gam(x) for x in l)


TINT_LIFT = 10
TINT_TARGET = 0.13
TINT_AUTO = 0.7
SURFACE_ROLES = ("background", "surface", "surface_dim", "surface_bright", "surface_variant",
                 "surface_container_lowest", "surface_container_low", "surface_container",
                 "surface_container_high", "surface_container_highest")


def _tint(c, k, primary):
    """Theme.qml's tint(): pull a neutral toward the accent's hue, then pin it
    back on its own tone so the ladder keeps its spacing."""
    if k <= 0 or max(primary) == min(primary):
        return c
    h, _, s = colorsys.rgb_to_hls(*primary)
    t = tone(c)
    pure = at_tone(colorsys.hls_to_rgb(h, 0.55, max(0.55, min(1, s))), t)
    head = max(pure) - min(pure)
    if head <= 0.001:
        return c
    f = min(1, k * TINT_TARGET / head)
    return at_tone(tuple(a * (1 - f) + b * f for a, b in zip(c, pure)), t)


def app_surfaces(pal, k=TINT_AUTO):
    """{role: hex} -> the same palette with every surface role where the shell
    draws it. a dark palette, or a tint of 0, comes back unchanged."""
    surface, primary = pal.get("surface"), pal.get("primary")
    if not surface or not primary or tone(surface) <= 50 or k <= 0:
        return dict(pal)
    lowest = pal.get("surface_container_lowest") or surface
    shift = max(0, tone(lowest) - (100 - k * TINT_LIFT))
    out = dict(pal)
    for role in SURFACE_ROLES:
        v = pal.get(role)
        if isinstance(v, str) and re.fullmatch(r"#[0-9a-fA-F]{6}", v):
            c = P(v)
            if shift:
                c = at_tone(c, tone(c) - shift)
            out[role] = hx(_tint(c, k, P(primary)))
    return out
