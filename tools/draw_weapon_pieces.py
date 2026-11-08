#!/usr/bin/env python3
"""Draws the pieces of the new weapons of J1 part 1 (owner's survey 2026-11-08: drawn by
code): halberd, crossbow and morning star, 24x24 with no ground, lying diagonally like the
PixelLab pieces of the spear and the sword, in their colours (dark outline, oak shaft with a
light edge, steel with a bright edge). Output: tools/pixellab_src/goods/<good>.png, from
which tools/compose_pixellab_stacks.py builds the stacks and tools/make_goods_icons.py the
icons and the goods carried in hands.

Run: python3 tools/draw_weapon_pieces.py  (needs Pillow)"""
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "tools", "pixellab_src", "goods")

OUTLINE = (12, 10, 8, 255)
WOOD = (137, 74, 24, 255)
WOOD_LIGHT = (176, 104, 40, 255)
WOOD_DARK = (96, 50, 14, 255)
STEEL = (150, 148, 165, 255)
STEEL_LIGHT = (214, 216, 228, 255)
STEEL_DARK = (98, 96, 114, 255)
STRING = (205, 196, 170, 255)
WRAP = (70, 40, 22, 255)


def line(px, a, b, colour):
    (x0, y0), (x1, y1) = a, b
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err = dx + dy
    while True:
        px[(x0, y0)] = colour
        if (x0, y0) == (x1, y1):
            break
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy


def shaft(px, a, b):
    """A round shaft two pixels thick lying from a (top right) to b (bottom left)."""
    line(px, a, b, WOOD)
    line(px, (a[0] + 1, a[1]), (b[0] + 1, b[1]), WOOD_DARK)
    line(px, (a[0], a[1] - 1), (b[0], b[1] - 1), WOOD_LIGHT)


def outline(img):
    """A dark rim round everything drawn (the pieces have a black outline)."""
    src = img.copy().load()
    dst = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            if src[x, y][3] != 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3] != 0 and src[nx, ny] != OUTLINE:
                    dst[x, y] = OUTLINE
                    break


def halberd():
    img = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    px = {}
    shaft(px, (22, 1), (7, 16))
    # The spike going on past the head.
    line(px, (6, 17), (2, 21), STEEL)
    line(px, (5, 17), (2, 20), STEEL_LIGHT)
    # The axe blade on one side of the shaft (towards the bottom right): longer in the
    # middle, so its edge is curved; the edge itself bright.
    for t, reach in enumerate((3, 5, 6, 5, 3)):
        x, y = 11 - t, 12 + t
        for k in range(1, reach + 1):
            colour = STEEL_LIGHT if k == reach else (STEEL_DARK if k == 1 else STEEL)
            px[(x + k, y + k)] = colour
            px[(x + k - 1, y + k)] = colour
    # The hook on the other side.
    for (x, y) in [(8, 13), (7, 12), (6, 11), (6, 12)]:
        px[(x, y)] = STEEL_DARK
    _paint(img, px)
    return img


def crossbow():
    img = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    px = {}
    # The stock, thick, from the butt (top right) to the nose (bottom left).
    shaft(px, (20, 3), (8, 15))
    line(px, (21, 3), (9, 15), WOOD)
    # The steel bow across the nose, bent forward a little.
    line(px, (2, 11), (6, 15), STEEL)
    line(px, (6, 15), (12, 21), STEEL)
    line(px, (3, 10), (6, 14), STEEL_LIGHT)
    line(px, (7, 14), (12, 19), STEEL_LIGHT)
    # The string pulled back to the nut.
    line(px, (2, 11), (11, 12), STRING)
    line(px, (12, 21), (11, 13), STRING)
    # The trigger under the stock.
    px[(16, 10)] = STEEL_DARK
    px[(17, 11)] = STEEL_DARK
    _paint(img, px)
    return img


def morning_star():
    img = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    px = {}
    shaft(px, (21, 2), (13, 10))
    # A leather grip at the butt.
    for (x, y) in [(20, 3), (19, 4), (20, 4)]:
        px[(x, y)] = WRAP
    # The ball, round, lit from the top left.
    cx, cy, r = 8, 15, 4.2
    for y in range(24):
        for x in range(24):
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            if d <= r:
                lit = (x - cx) * -0.7 + (y - cy) * -0.7
                px[(x, y)] = STEEL_LIGHT if lit > 1.8 else (STEEL if lit > -1.5 else STEEL_DARK)
    # Spikes all round.
    for (x, y) in [(8, 9), (8, 10), (2, 15), (3, 15), (14, 15), (13, 15), (8, 21), (8, 20),
                   (4, 11), (12, 11), (4, 19), (12, 19)]:
        px[(x, y)] = STEEL_LIGHT if y < cy else STEEL
    _paint(img, px)
    return img


def _paint(img, px):
    canvas = img.load()
    for (x, y), colour in px.items():
        if 0 <= x < img.width and 0 <= y < img.height:
            canvas[x, y] = colour
    outline(img)


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, draw in (("halberd", halberd), ("crossbow", crossbow), ("morning_star", morning_star)):
        draw().save(os.path.join(OUT, name + ".png"))
        print("written", name)


if __name__ == "__main__":
    main()
