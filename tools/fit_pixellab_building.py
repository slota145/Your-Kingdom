#!/usr/bin/env python3
"""Fits a building drawn by PixelLab onto its footprint (G1, ART_SPEC §10.12).

Takes the raw PNG from PixelLab (Pro Flash, "high top-down"), brightens it like every
PixelLab building (tools/brighten_pixellab.py, owner's "medium" level), drops stray
specks, and places it on a canvas the game reads like code-drawn art: pivot = front
(bottom) corner of the footprint diamond, written to <name>.json next to <name>.png.

Placement: the drawn building stands on a grid rectangle inside the footprint (--volume,
default the whole footprint). The middle of the art goes over the middle of that
rectangle's diamond and the lowest pixel sits --inset pixels above its front corner.
--dx / --dy nudge it by hand. A construction stage made from a finished building
(edit of the same raw canvas) takes --like=<raw base PNG>: it gets exactly the same
shift as that base, so the site lines up with the building.

A building with a production yard (paczka 2, BuildingDef.yard_at) gets the yard tile
drawn under it as trodden earth (--yard=x,y), like tools/generate_art.gd does.

Run: python3 tools/fit_pixellab_building.py <raw.png> <assets/buildings/<id>/<name>>
       --footprint=2,2 --entrance=1,1 [--volume=x0,y0,x1,y1] [--inset=4] [--dx=0] [--dy=0]
       [--like=<raw.png>] [--yard=x,y] [--no-brighten] [--margin=12] [--clip-front=<px>]

--clip-front cuts away whatever hangs below the two front edges of the footprint diamond
(plus <px> pixels of slack): a patch of ground drawn a little wider than the footprint
(the pioneer camp) would otherwise lie over the neighbours' tiles.
(needs Pillow)."""
import json
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from brighten_pixellab import brighten  # noqa: E402

HALF_W = 32
HALF_H = 16
SPECK = 12  # opaque islands smaller than this many pixels are dropped


def grid_to_screen(x, y):
    return ((x - y) * HALF_W, (x + y) * HALF_H)


def drop_specks(img):
    """Removes small islands of opaque pixels (PixelLab leaves a few loose dots)."""
    px = img.load()
    w, h = img.size
    seen = bytearray(w * h)
    for sy in range(h):
        for sx in range(w):
            if seen[sy * w + sx] or px[sx, sy][3] == 0:
                continue
            stack = [(sx, sy)]
            seen[sy * w + sx] = 1
            island = []
            while stack:
                x, y = stack.pop()
                island.append((x, y))
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx] and px[nx, ny][3] > 0:
                        seen[ny * w + nx] = 1
                        stack.append((nx, ny))
            if len(island) < SPECK:
                for x, y in island:
                    px[x, y] = (0, 0, 0, 0)
    return img


def shift_of(raw, footprint, volume, inset, dx, dy):
    """Pixel shift from raw canvas to the footprint frame (origin = front corner B)."""
    box = raw.getbbox()
    fx, fy = footprint
    x0, y0, x1, y1 = volume
    # Volume corners relative to B = grid (fx, fy).
    left = grid_to_screen(x0 - fx, y1 - fy)[0]
    right = grid_to_screen(x1 - fx, y0 - fy)[0]
    front_y = grid_to_screen(x1 - fx, y1 - fy)[1]
    mid_x = (left + right) / 2.0
    art_mid = (box[0] + box[2]) / 2.0
    return (round(mid_x - art_mid) + dx, front_y - inset - box[3] + dy)


def clip_front(img, pivot, footprint, slack):
    """Clears pixels below the front edges of the footprint diamond (left corner - B -
    right corner), and below the side corners' height outside the diamond's width."""
    fx, fy = footprint
    lx = pivot[0] + grid_to_screen(-fx, 0)[0]
    ly = pivot[1] + grid_to_screen(-fx, 0)[1]
    rx = pivot[0] + grid_to_screen(0, -fy)[0]
    ry = pivot[1] + grid_to_screen(0, -fy)[1]
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            if x <= pivot[0]:
                edge = pivot[1] - (pivot[0] - x) * 0.5 if x >= lx else ly
            else:
                edge = pivot[1] - (x - pivot[0]) * 0.5 if x <= rx else ry
            if y > edge + slack:
                px[x, y] = (0, 0, 0, 0)


def yard_tile(img, pivot, footprint, tile):
    """Trodden earth on the yard tile, as in generate_art.gd (_yard_ground)."""
    fx, fy = footprint
    tx, ty = tile
    inset = 0.06
    corners = [(tx + inset, ty + inset), (tx + 1 - inset, ty + inset),
               (tx + 1 - inset, ty + 1 - inset), (tx + inset, ty + 1 - inset)]
    pts = [(pivot[0] + grid_to_screen(cx - fx, cy - fy)[0], pivot[1] + grid_to_screen(cx - fx, cy - fy)[1])
           for cx, cy in corners]
    from PIL import ImageDraw
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).polygon(pts, fill=255)
    earth = (128, 102, 71)
    m = mask.load()
    px = img.load()

    def h(x, y, s):
        n = (x * 374761393 + y * 668265263 + s * 2246822519) & 0xFFFFFFFF
        n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
        return (n & 0xFFFF) / 65535.0

    for y in range(img.height):
        for x in range(img.width):
            if not m[x, y]:
                continue
            n = h(x // 2, y // 2, 91)
            if n > 0.93:
                c = (184, 153, 102)
            elif n < 0.08:
                c = tuple(int(v * 0.78) for v in earth)
            else:
                k = 1.0 - 0.12 * h(x // 3, y // 3, 17)
                c = tuple(min(255, int(v * k + 12 * h(x, y, 5))) for v in earth)
            px[x, y] = c + (255,)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    opts = dict((a[2:].split("=", 1) + [""])[:2] for a in sys.argv[1:] if a.startswith("--"))
    if len(args) != 2 or "footprint" not in opts:
        sys.exit(__doc__)
    ints = lambda s: [int(v) for v in s.split(",")]  # noqa: E731
    footprint = ints(opts["footprint"])
    entrance = ints(opts.get("entrance", "%d,%d" % (footprint[0] - 1, footprint[1] - 1)))
    volume = ints(opts.get("volume", "0,0,%d,%d" % tuple(footprint)))
    inset = int(opts.get("inset", "4"))
    margin = int(opts.get("margin", "12"))
    dx, dy = int(opts.get("dx", "0")), int(opts.get("dy", "0"))

    raw = drop_specks(Image.open(args[0]).convert("RGBA"))
    anchor = drop_specks(Image.open(opts["like"]).convert("RGBA")) if "like" in opts else raw
    sx, sy = shift_of(anchor, footprint, volume, inset, dx, dy)
    art = raw if "no-brighten" in opts else brighten(raw)
    box = art.getbbox()

    fx, fy = footprint
    left = grid_to_screen(0 - fx, fy - fy)[0]       # left corner, relative to B
    right = grid_to_screen(fx - fx, 0 - fy)[0]      # right corner
    top = min(box[1] + sy, grid_to_screen(-fx, -fy)[1])
    min_x = min(left, box[0] + sx) - margin
    max_x = max(right, box[2] + sx) + margin
    pivot = (-min_x, -top + 2)
    size = (max_x - min_x, pivot[1] + 2)
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    if "yard" in opts:
        yard_tile(out, pivot, footprint, ints(opts["yard"]))
    out.alpha_composite(art.crop(box), (box[0] + sx + pivot[0], box[1] + sy + pivot[1]))
    if "clip-front" in opts:
        clip_front(out, pivot, footprint, int(opts["clip-front"] or "0"))
    os.makedirs(os.path.dirname(args[1]) or ".", exist_ok=True)
    out.save(args[1] + ".png")
    with open(args[1] + ".json", "w") as f:
        json.dump({"entrance": entrance, "footprint": footprint, "pivot": list(pivot)}, f, indent="\t")
        f.write("\n")
    print("%s.png %dx%d pivot %s" % (args[1], size[0], size[1], pivot))


if __name__ == "__main__":
    main()
