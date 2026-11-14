"""Comparison sheet for G3 part 5a (ROADMAP): each harbour building's old art (from git, default
origin/main; a yard without base art shows its old construction stage 2) on the left of the yellow
line, then the new art with its pieces put together (the port's shed, the warehouses' sheds) on a
plain pier-coloured diamond, and its two construction stages, 2x scale.

Run: python3 tools/spritekiln/compose_port.py <out.png> <id>... [--rev=<git rev>]
"""
import io
import json
import os
import subprocess
import sys

from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BG = (88, 116, 68, 255)
FLOOR = (118, 92, 66, 255)
PIECES = ["shed_a_back", "shed_b_back", "shed_a_front", "shed_b_front"]


def old(rev, bid):
    for name in ("base", "construction_2"):
        r = subprocess.run(["git", "show", "%s:assets/buildings/%s/%s.png" % (rev, bid, name)], cwd=ROOT, capture_output=True)
        if r.returncode == 0:
            return Image.open(io.BytesIO(r.stdout)).convert("RGBA")
    raise SystemExit("no old art for " + bid)


def assembled(bid):
    """The base art (if any) with its pieces on a floor diamond, pivots matched."""
    d = os.path.join(ROOT, "assets", "buildings", bid)
    n = json.load(open(os.path.join(d, "construction_1.json")))["footprint"][0]
    layers = []          # (image, pivot in the sheet's frame: plot front corner = (0, 0))
    if os.path.exists(os.path.join(d, "base.png")):
        meta = json.load(open(os.path.join(d, "base.json")))
        layers.append((Image.open(os.path.join(d, "base.png")).convert("RGBA"), meta["pivot"], (0, 0)))
    for piece in PIECES:
        p = os.path.join(d, piece + ".png")
        if not os.path.exists(p):
            continue
        meta = json.load(open(os.path.join(d, piece + ".json")))
        (ox, oy), (fx, fy) = meta["offset"], meta["footprint"]
        dgx, dgy = ox + fx - n, oy + fy - n
        layers.append((Image.open(p).convert("RGBA"), meta["pivot"], ((dgx - dgy) * 32, (dgx + dgy) * 16)))
    left = min(-pv[0] + sh[0] for im, pv, sh in layers + [(None, (n * 32, 0), (0, 0))])
    right = max([im.width - pv[0] + sh[0] for im, pv, sh in layers] + [n * 32])
    right = max(right, n * 32)
    top = min([-pv[1] + sh[1] for im, pv, sh in layers] + [-n * 32])
    canvas = Image.new("RGBA", (right - left, -top + 2), (0, 0, 0, 0))
    ox, oy = -left, -top
    floor = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(floor).polygon([(ox, oy), (ox + n * 32, oy - n * 16), (ox, oy - n * 32), (ox - n * 32, oy - n * 16)], fill=FLOOR)
    canvas.alpha_composite(floor)
    for im, pv, sh in layers:
        canvas.alpha_composite(im, (ox - pv[0] + sh[0], oy - pv[1] + sh[1]))
    return canvas


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    rev = next((a[6:] for a in sys.argv if a.startswith("--rev=")), "origin/main")
    out, ids = args[0], args[1:]
    rows = []
    for bid in ids:
        d = os.path.join(ROOT, "assets", "buildings", bid)
        rows.append([old(rev, bid), assembled(bid)] + [Image.open(os.path.join(d, n + ".png")).convert("RGBA")
                                                      for n in ("construction_1", "construction_2")])
    W = max(sum(i.width for i in r) + 16 * len(r) + 8 for r in rows)
    H = sum(max(i.height for i in r) + 12 for r in rows)
    sheet = Image.new("RGBA", (W, H), BG)
    draw = ImageDraw.Draw(sheet)
    y = 0
    for r in rows:
        h = max(i.height for i in r)
        x = 4
        for k, im in enumerate(r):
            sheet.alpha_composite(im, (x, y + h - im.height + 6))
            x += im.width + 16
            if k == 0:
                draw.line([(x - 9, y + 4), (x - 9, y + h + 8)], fill=(240, 200, 40, 255), width=2)
        y += h + 12
    sheet = sheet.resize((W * 2, H * 2), Image.NEAREST)
    sheet.save(out)
    print(out, sheet.size)


if __name__ == "__main__":
    main()
