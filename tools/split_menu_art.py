#!/usr/bin/env python3
"""Splits the main menu picture (ROADMAP UI-1: assets/ui/menu/source.png, 640x360 from PixelLab)
into the layers of the living menu:
  sky.png    the sky with its clouds; where the land is, the sky goes on downwards (it shows
             through when the layers move apart),
  land.png   the town, the sea, the cog and the quay, the sky cut out (transparent),
  water.png  a mask of the open sea (white where the waves glitter).
Every layer gets PAD pixels of the edge repeated on each side, so moving it a little with the
mouse never shows an empty border. The sky is found by a flood fill from the top edge over sky
blues and cloud whites, down to the horizon, and from the EXTRA_SKY points (enclosed pieces).
Run from the project root: python3 tools/split_menu_art.py (needs Pillow)."""
from collections import deque

from PIL import Image

SRC = "assets/ui/menu/source.png"
OUT = "assets/ui/menu/"
PAD = 8
HORIZON = 215
## Pieces of sky the flood fill from the top cannot reach (between the sail and its rope).
EXTRA_SKY = [(293, 160)]


def is_sky(c):
    r, g, b, _ = c
    if b - g >= 35 and b > 150:
        return True   # sky blues
    if r > 185 and g > 185 and b > 170 and abs(r - g) < 30:
        return True   # clouds, cream to white
    return b > 200 and g > 200 and r > 150 and b - g >= 8 and g < 235   # pale sky by the horizon


def is_sea(c):
    r, g, b, _ = c
    return g > 120 and b > 140 and r < 120 and b >= g - 10


def pad(img):
    w, h = img.size
    out = Image.new("RGBA", (w + 2 * PAD, h + 2 * PAD))
    out.paste(img, (PAD, PAD))
    src = img.load()
    dst = out.load()
    for y in range(h + 2 * PAD):
        for x in range(w + 2 * PAD):
            if PAD <= x < w + PAD and PAD <= y < h + PAD:
                continue
            dst[x, y] = src[min(max(x - PAD, 0), w - 1), min(max(y - PAD, 0), h - 1)]
    return out


def main():
    img = Image.open(SRC).convert("RGBA")
    w, h = img.size
    px = img.load()
    sky = [[False] * w for _ in range(h)]
    queue = deque()
    for x in range(w):
        if is_sky(px[x, 0]):
            sky[0][x] = True
            queue.append((x, 0))
    for x, y in EXTRA_SKY:
        sky[y][x] = True
        queue.append((x, y))
    while queue:
        x, y = queue.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < min(h, HORIZON) and not sky[ny][nx] and is_sky(px[nx, ny]):
                sky[ny][nx] = True
                queue.append((nx, ny))
    sky_img = img.copy()
    land_img = img.copy()
    water_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    s = sky_img.load()
    land = land_img.load()
    water = water_img.load()
    for x in range(w):
        last = px[x, 0]
        for y in range(h):
            if sky[y][x]:
                last = px[x, y]
                land[x, y] = (0, 0, 0, 0)
            else:
                s[x, y] = last   # the sky goes on behind the land
                if y >= HORIZON - 5 and is_sea(px[x, y]):
                    water[x, y] = (255, 255, 255, 255)
    pad(sky_img).save(OUT + "sky.png")
    pad(land_img).save(OUT + "land.png")
    pad(water_img).save(OUT + "water.png")
    print("layers written: sky, land, water (%dx%d with %d px padding)" % (w, h, PAD))


if __name__ == "__main__":
    main()
