"""Comparison sheets for G3 part 4a (ROADMAP): the hut (house level 1) and the patrician houses
(level 3), old art (from git, default origin/main) left of the yellow line, new art right of it,
and a street of rows built as the game places them. 2x scale.

Run: python3 tools/spritekiln/compose_homes.py <out dir> [--rev=<git rev>]
Writes g3_part4a_1.png (huts, backs, stages, scaffold), g3_part4a_2.png (patricians: each piece
old | new look 1, 2, 3 and the back of look 1) and g3_part4a_street.png.
"""
import io
import json
import os
import subprocess
import sys

from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
HUT = os.path.join(ROOT, "assets", "buildings", "hut")
BG = (88, 116, 68, 255)
YELLOW = (240, 200, 40, 255)


def old(rev, name):
    data = subprocess.run(["git", "show", "%s:assets/buildings/hut/%s.png" % (rev, name)], cwd=ROOT,
                          capture_output=True, check=True).stdout
    return Image.open(io.BytesIO(data)).convert("RGBA")


def new(name):
    return Image.open(os.path.join(HUT, name + ".png")).convert("RGBA")


def sheet(rows, out):
    """rows: lists of images; the first image of each row is the old one (a yellow line after it)."""
    W = max(sum(i.width for i in r) + 16 * len(r) + 8 for r in rows)
    H = sum(max(i.height for i in r) + 12 for r in rows)
    img = Image.new("RGBA", (W, H), BG)
    draw = ImageDraw.Draw(img)
    y = 0
    for r in rows:
        h = max(i.height for i in r)
        x = 4
        for k, im in enumerate(r):
            img.alpha_composite(im, (x, y + h - im.height + 6))
            x += im.width + 16
            if k == 0:
                draw.line([(x - 9, y + 4), (x - 9, y + h + 8)], fill=YELLOW, width=2)
        y += h + 12
    img = img.resize((W * 2, H * 2), Image.NEAREST)
    img.save(out)
    print(out, img.size)


def street(out):
    """Rows as the game lays them: along game y, fronts to +x; an empty road tile column between."""
    rows = [
        (0, ["level_3_end_a", "level_3_middle_2", "level_3_middle", "level_3_middle_3", "level_3_end_b_2"]),
        (4, ["level_2_end_a", "level_2_middle_3", "level_2_middle", "level_2_end_b"]),
        (8, ["base", "base_2", "base_3", "base_2"]),
    ]
    items = []
    for gx, names in rows:
        for i, n in enumerate(names):
            ox, oy = gx, i * 2
            meta = json.load(open(os.path.join(HUT, n + ".json")))
            items.append((ox + oy, ox, oy, new(n), meta["pivot"]))
    items.sort(key=lambda t: t[0])
    W, H = 1100, 640
    img = Image.new("RGBA", (W, H), BG)
    draw = ImageDraw.Draw(img)
    cx, cy = 560, 120
    for gx in range(-1, 12):        # a road of trodden earth in front of each row
        for gy in range(0, 10):
            if gx in (2, 3, 6, 7, 10, 11):
                x, y = cx + (gx - gy) * 32, cy + (gx + gy) * 16
                draw.polygon([(x, y), (x + 32, y + 16), (x, y + 32), (x - 32, y + 16)], fill=(124, 104, 74, 255))
    for _, ox, oy, im, piv in items:
        fx, fy = ox + 2, oy + 2
        x, y = cx + (fx - fy) * 32, cy + (fx + fy) * 16
        img.alpha_composite(im, (x - piv[0], y - piv[1]))
    img = img.resize((W * 2, H * 2), Image.NEAREST)
    img.save(out)
    print(out, img.size)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    rev = next((a[6:] for a in sys.argv if a.startswith("--rev=")), "origin/main")
    out = args[0] if args else os.path.join(ROOT, "tools", "spritekiln", "previews")
    rows = []
    for b in ("base", "base_2", "base_3"):
        rows.append([old(rev, b), new(b), new(b + "_back")])
    rows.append([old(rev, "construction_2"), new("construction_1"), new("construction_2"), new("construction_2_back"),
                 new("upgrade_scaffold")])
    sheet(rows, os.path.join(out, "g3_part4a_1.png"))
    rows = []
    for piece in ("single", "end_a", "middle", "end_b", "corner_a", "corner_b"):
        n = "level_3_" + piece
        rows.append([old(rev, n), new(n), new(n + "_2"), new(n + "_3"), new(n + "_back")])
    sheet(rows[:3], os.path.join(out, "g3_part4a_2.png"))
    sheet(rows[3:], os.path.join(out, "g3_part4a_3.png"))
    street(os.path.join(out, "g3_part4a_street.png"))


if __name__ == "__main__":
    main()
