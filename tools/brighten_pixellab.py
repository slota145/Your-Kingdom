#!/usr/bin/env python3
"""Brightens building art from PixelLab (owner's choice 2026-11-07: Pro Flash buildings looked
too dark next to our terrain; ART_SPEC §10.11). Lifts dark and middle tones with a gamma curve
on the HSV value and takes a little saturation off, so the highlights stay and the outlines
stay sharp. The default is the "medium" level the owner picked.

Run: python3 tools/brighten_pixellab.py <in.png> <out.png> [--gamma=0.65] [--saturation=0.95]
(needs Pillow)."""
import colorsys
import sys

from PIL import Image

GAMMA = 0.65
SATURATION = 0.95


def brighten(img, gamma=GAMMA, saturation=SATURATION):
    img = img.convert("RGBA")
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            r2, g2, b2 = colorsys.hsv_to_rgb(h, min(1.0, s * saturation), v ** gamma)
            px[x, y] = (round(r2 * 255), round(g2 * 255), round(b2 * 255), a)
    return img


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    opts = dict(a[2:].split("=", 1) for a in sys.argv[1:] if a.startswith("--"))
    if len(args) != 2:
        sys.exit(__doc__)
    out = brighten(Image.open(args[0]), float(opts.get("gamma", GAMMA)),
                   float(opts.get("saturation", SATURATION)))
    out.save(args[1])


if __name__ == "__main__":
    main()
