#!/usr/bin/env python3
"""Icons (32x32) and goods carried in hands (24x24, 5 rows) of the goods of M7 part 1 from
their PixelLab pieces (tools/pixellab_src/goods/, colours evened out like their stacks by
tools/compose_pixellab_stacks.py). The icon is the piece in the middle; carried, it is shrunk
to at most CARRIED_MAX px. The horse is drawn by tools/generate_characters.gd.

Run: python3 tools/make_goods_icons.py  (needs Pillow)"""
import os
import sys
import tempfile

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from compose_pixellab_stacks import G2_SET, LAYOUTS, SRC  # noqa: E402
from harmonize_pixellab import harmonize  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GOODS = {"charcoal": "sack", "iron_ore": "stone", "iron": "bundle", "spear": "bundle",
         "bow": "bundle", "sword": "bundle", "chainmail": "crate"}
CARRIED_MAX = 16
ROWS = 5


def main():
    tmp = tempfile.mkdtemp(prefix="icons_")
    groups = {g: [(os.path.join(SRC, g + ".png"), os.path.join(tmp, g + ".png"))] for g in LAYOUTS}
    harmonize(groups, value_strength=0.0, reference=lambda name: name in G2_SET)
    for good, category in GOODS.items():
        piece = Image.open(os.path.join(tmp, good + ".png")).convert("RGBA")
        piece = piece.crop(piece.getbbox())
        icon = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        icon.alpha_composite(piece, ((32 - piece.width) // 2, (32 - piece.height) // 2))
        icon.save(os.path.join(ROOT, "assets", "goods", "icons", good + ".png"))
        small = piece
        if max(piece.size) > CARRIED_MAX:
            f = CARRIED_MAX / max(piece.size)
            small = piece.resize((max(1, round(piece.width * f)), max(1, round(piece.height * f))), Image.LANCZOS)
            px = small.load()
            for y in range(small.height):
                for x in range(small.width):
                    r, g, b, a = px[x, y]
                    px[x, y] = (r, g, b, 255 if a > 110 else 0)
        sheet = Image.new("RGBA", (24, 24 * ROWS), (0, 0, 0, 0))
        for row in range(ROWS):
            sheet.alpha_composite(small, ((24 - small.width) // 2, row * 24 + 24 - small.height - 2))
        out = os.path.join(ROOT, "assets", "goods", "carried", category)
        os.makedirs(out, exist_ok=True)
        sheet.save(os.path.join(out, good + ".png"))
        print(good)


if __name__ == "__main__":
    main()
