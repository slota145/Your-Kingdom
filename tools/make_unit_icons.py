#!/usr/bin/env python3
"""Icons of the soldiers (P2 part 2, the troop slots of a warship's panel): a bust (head and
chest) from the first idle frame of each unit's character sheet facing the viewer, doubled
in size (whole pixels) and fitted into 32x32 like the goods icons. Output: assets/units/icons/<unit>.png.

Run: python3 tools/make_unit_icons.py  (needs Pillow; then the Godot import)"""
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UNITS = os.path.join(ROOT, "data", "units")
SHEETS = os.path.join(ROOT, "assets", "characters")
OUT = os.path.join(ROOT, "assets", "units", "icons")
FRAME = 64
SIZE = 32
# The row of the sheet facing the viewer (south-west, lit from the left).
ROW = 0
# Side of the square bust (from just above the head), before doubling.
BUST = 16


def icon(unit):
    path = os.path.join(SHEETS, unit, "idle.png")
    if not os.path.exists(path):
        return None
    sheet = Image.open(path).convert("RGBA")
    frame = sheet.crop((0, ROW * FRAME, FRAME, ROW * FRAME + FRAME))
    box = frame.getbbox()
    if box is None:
        return None
    # The body's middle column: the centre of the lower half of the figure (weapons held
    # up beside it do not move it much); the head is the topmost pixel near that column.
    lower = frame.crop((0, (box[1] + box[3]) // 2, FRAME, box[3]))
    lb = lower.getbbox() or box
    cx = (lb[0] + lb[2]) // 2
    px = frame.load()
    top = box[1]
    for y in range(box[1], box[3]):
        if any(px[x, y][3] > 0 for x in range(cx - 2, cx + 3)):
            top = y
            break
    half = BUST // 2
    bust = frame.crop((cx - half, top - 1, cx + half, top - 1 + BUST))
    big = bust.resize((bust.width * 2, bust.height * 2), Image.NEAREST)
    out = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    out.alpha_composite(big, ((SIZE - big.width) // 2, 0))
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    for name in sorted(os.listdir(UNITS)):
        if not name.endswith(".tres"):
            continue
        unit = name[:-5]
        img = icon(unit)
        if img is None:
            print("no sheet for", unit)
            continue
        img.save(os.path.join(OUT, unit + ".png"))
        print("written", unit)


if __name__ == "__main__":
    main()
