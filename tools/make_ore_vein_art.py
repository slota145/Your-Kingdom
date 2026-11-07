#!/usr/bin/env python3
"""Draws the iron ore vein (M7 part 1) from the rock art: the same boulders, whole, half
quarried and rubble, with rusty streaks of ore across the stone and a few bright flecks.
Writes assets/nature/ore_vein/{grown,felled,stump}.png from assets/nature/rock/ and the
placeholders likewise from assets/_placeholder/nature/rock/.

Run: python3 tools/make_ore_vein_art.py  (needs Pillow)"""
import colorsys
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RUST_HUE = 0.045   # red-brown
STATES = ("grown", "felled", "stump")


def _hash(x, y, salt):
    h = (x * 374761393 + y * 668265263 + salt * 2246822519) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    return (h ^ (h >> 16)) / 0xFFFFFFFF


def ore(src, dst):
    img = Image.open(src).convert("RGBA")
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 200:
                continue
            hue, light, sat = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
            if light < 0.2:
                continue   # the outline stays
            # A few diagonal veins of ore across the stone, gently wavy, and rare flecks.
            band = (x + y * 2 + int(4 * _hash(x // 6, y // 6, 7))) % 14
            fleck = _hash(x, y, 11) > 0.975
            if band < 2 or fleck:
                rr, gg, bb = colorsys.hls_to_rgb(RUST_HUE + 0.015 * _hash(x, y, 3),
                                                 min(light * 0.72, 0.46), 0.5)
                if band == 0 and _hash(x, y, 5) > 0.75 or fleck:
                    rr, gg, bb = colorsys.hls_to_rgb(RUST_HUE + 0.025, min(light * 0.95, 0.6), 0.55)
                px[x, y] = (int(rr * 255), int(gg * 255), int(bb * 255), a)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    img.save(dst)


def main():
    for base in ("assets", "assets/_placeholder"):
        for state in STATES:
            src = os.path.join(ROOT, base, "nature", "rock", state + ".png")
            ore(src, os.path.join(ROOT, base, "nature", "ore_vein", state + ".png"))


if __name__ == "__main__":
    main()
