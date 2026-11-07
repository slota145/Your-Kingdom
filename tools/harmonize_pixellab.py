#!/usr/bin/env python3
"""Evens out the colours of a set of PixelLab buildings (G1, owner's decision 2026-11-07:
the log hut came out much darker than the others, the plaster hut and the quarry nearly
grey, the camp very orange).

Every pixel falls into a material by its hue and brightness: grey stone and plaster, red
brick and tiles, dark wood, straw and light wood, green, blue slate. Over the whole set we
measure each material's average hue and saturation; then every building is pulled towards
them (hue moved to the set's hue, saturation scaled towards it), so the logs of the camp
and of the woodcutter look cut in one forest. Finally the building's overall brightness is
pulled three quarters of the way towards the set's average, and every grey gets the
same warm tint. Shading inside each material (value) is kept.

A construction stage or the back of a house takes the correction of its finished building
(the same group), so a site does not change colour when the building is finished.

Used by tools/build_pixellab_buildings.py; harmonize(groups) takes
{group: [(path_in, path_out), ...]} with the finished building first in each group."""
import colorsys
import math

from PIL import Image

HUE_STRENGTH = 1.0
HUE_LIMIT = 15.0        # degrees a material's hue may move
SAT_STRENGTH = 0.7
SAT_LIMITS = (0.6, 1.5)
VALUE_STRENGTH = 0.75
# Greys (stone, plaster, slate) get a warm tint, the same for every building, so a stone
# hut does not look cold and blue next to the timber ones (hue in degrees, added saturation).
GREY_HUE = 35.0
GREY_WARMTH = 0.05


def material(h, s, v):
    """Material of a pixel (h in degrees, s and v 0..1)."""
    if s < 0.15:
        return "grey"
    if h < 15 or h >= 335:
        return "red"
    if h < 60:
        return "wood" if v < 0.62 else "straw"
    if h < 180:
        return "green"
    return "blue"


def _pixels(img):
    for p in img.get_flattened_data():
        if p[3] > 200:
            h, s, v = colorsys.rgb_to_hsv(p[0] / 255, p[1] / 255, p[2] / 255)
            yield h * 360.0, s, v


def measure(img):
    """{material: [sum cos, sum sin, sum sat, count]}, sum of values, pixel count."""
    stats = {}
    vsum = 0.0
    n = 0
    for h, s, v in _pixels(img):
        m = stats.setdefault(material(h, s, v), [0.0, 0.0, 0.0, 0])
        m[0] += math.cos(math.radians(h)) * s
        m[1] += math.sin(math.radians(h)) * s
        m[2] += s
        m[3] += 1
        vsum += v
        n += 1
    return stats, vsum, n


def _means(stats):
    return {k: (math.degrees(math.atan2(m[1], m[0])) % 360.0, m[2] / m[3]) for k, m in stats.items() if m[3] > 0}


def _add(total, stats):
    for k, m in stats.items():
        t = total.setdefault(k, [0.0, 0.0, 0.0, 0])
        for i in range(4):
            t[i] += m[i]


def correction(group_stats, set_means, group_value, set_value):
    """Per material (hue shift in degrees, saturation factor) and the value gamma."""
    shifts = {}
    for k, (h, s) in _means(group_stats).items():
        th, ts = set_means[k]
        dh = ((th - h + 180.0) % 360.0) - 180.0
        dh = max(-HUE_LIMIT, min(HUE_LIMIT, dh * HUE_STRENGTH))
        if k == "grey":
            dh = 0.0 if s < 0.04 else dh   # pure greys have no hue to move
        f = (ts / s) if s > 0 else 1.0
        f = max(SAT_LIMITS[0], min(SAT_LIMITS[1], 1.0 + (f - 1.0) * SAT_STRENGTH))
        shifts[k] = (dh, f)
    target = group_value + (set_value - group_value) * VALUE_STRENGTH
    gamma = math.log(target) / math.log(group_value) if 0 < group_value < 1 and 0 < target < 1 else 1.0
    return shifts, gamma


def apply(img, shifts, gamma):
    img = img.convert("RGBA")
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            kind = material(h * 360.0, s, v)
            if kind == "grey":
                h = GREY_HUE / 360.0
                s = min(0.15, s + GREY_WARMTH * (1.0 - s / 0.15))
            else:
                dh, f = shifts.get(kind, (0.0, 1.0))
                h = ((h * 360.0 + dh) % 360.0) / 360.0
                s = min(1.0, s * f)
            v = v ** gamma
            r2, g2, b2 = colorsys.hsv_to_rgb(h, s, v)
            px[x, y] = (round(r2 * 255), round(g2 * 255), round(b2 * 255), a)
    return img


def harmonize(groups):
    """groups: {name: [(path_in, path_out), ...]}, the finished building first."""
    measured = {}
    total = {}
    vsum = 0.0
    n = 0
    for name, files in groups.items():
        stats, gv, gn = measure(Image.open(files[0][0]).convert("RGBA"))
        measured[name] = (stats, gv / max(1, gn))
        _add(total, stats)
        vsum += gv
        n += gn
    set_means = _means(total)
    set_value = vsum / max(1, n)
    for name, files in groups.items():
        stats, value = measured[name]
        shifts, gamma = correction(stats, set_means, value, set_value)
        for path_in, path_out in files:
            apply(Image.open(path_in), shifts, gamma).save(path_out)
    return set_means, set_value
