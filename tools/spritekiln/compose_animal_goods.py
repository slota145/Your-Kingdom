"""Goods art of a live animal from its SpriteKiln sheets (Z1 part 2: the sheep).

From assets/animals/<id>/idle.png (tools/spritekiln/export_animal.py) writes:
- goods/icons/<id>.png: 32x32, the animal seen from the side (row E),
- goods/carried/animal/<id>.png: 24x120, rows S, SE, E, NE, N, the hooves 4 px above the row's bottom
  (an animal led beside a porter, ART_SPEC 4.5),
- goods/stacks/<id>.png: 4 frames of 64x64, 1 to 4 animals standing on the tile (the wagon, a pile).
Run: python3 tools/spritekiln/compose_animal_goods.py <id>
"""
import json
import os
import sys

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def main():
    good = sys.argv[1]
    d = os.path.join(ROOT, "assets", "animals", good)
    info = json.load(open(os.path.join(d, "sheet.json")))
    size = info["frame"]
    fx, fy = info["foot"]
    sheet = Image.open(os.path.join(d, "idle.png")).convert("RGBA")

    def frame(row):
        return sheet.crop((0, row * size, size, row * size + size))

    goods = os.path.join(ROOT, "assets", "goods")
    # Icon: the side view, centred.
    side = frame(2)
    box = side.getbbox()
    part = side.crop(box)
    icon = Image.new("RGBA", (32, 32))
    icon.alpha_composite(part, ((32 - part.width) // 2, (32 - part.height) // 2))
    icon.save(os.path.join(goods, "icons", good + ".png"))
    # Led: 5 rows of 24, the ground point at (12, 20).
    led = Image.new("RGBA", (24, 120))
    for row in range(5):
        led.alpha_composite(frame(row), (12 - fx, row * 24 + 20 - fy))
    led.save(os.path.join(goods, "carried", "animal", good + ".png"))
    # Stack: 1..4 animals on the tile (centre of the tile at (32, 48)).
    spots = [(32, 47, 1), (21, 52, 7), (43, 52, 1), (31, 57, 7)]
    stack = Image.new("RGBA", (64 * 4, 64))
    for n in range(4):
        tile = Image.new("RGBA", (64, 64))
        for x, y, row in sorted(spots[: n + 1], key=lambda s: s[1]):
            tile.alpha_composite(frame(row), (x - fx, y - fy))
        stack.alpha_composite(tile, (n * 64, 0))
    stack.save(os.path.join(goods, "stacks", good + ".png"))
    print("written", good)


if __name__ == "__main__":
    main()
