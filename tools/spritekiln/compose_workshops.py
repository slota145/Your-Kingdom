"""Comparison sheet for G3 part 3 (ROADMAP): each building's old art (from git, default origin/main)
on the left, the new SpriteKiln art and its two construction stages on the right, 2x scale.

Run: python3 tools/spritekiln/compose_workshops.py <out.png> <id>... [--rev=<git rev>]
"""
import io
import os
import subprocess
import sys

from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BG = (88, 116, 68, 255)


def old(rev, bid):
    data = subprocess.run(["git", "show", "%s:assets/buildings/%s/base.png" % (rev, bid)], cwd=ROOT,
                          capture_output=True, check=True).stdout
    return Image.open(io.BytesIO(data)).convert("RGBA")


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    rev = next((a[6:] for a in sys.argv if a.startswith("--rev=")), "origin/main")
    out, ids = args[0], args[1:]
    rows = []
    for bid in ids:
        d = os.path.join(ROOT, "assets", "buildings", bid)
        ims = [old(rev, bid)] + [Image.open(os.path.join(d, n + ".png")).convert("RGBA")
                                 for n in ("base", "construction_1", "construction_2")]
        rows.append(ims)
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
