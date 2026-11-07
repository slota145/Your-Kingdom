#!/usr/bin/env python3
"""Lays out the pioneer camp from separate PixelLab pieces (G1, owner's decision 2026-11-07:
the camp drawn whole by PixelLab came with its own patch of earth, wider than the 3x3 tiles
and of another colour than our ground). The pieces stand on our grass, inside the footprint.

Pieces: tools/pixellab_src/buildings/pioneer_camp/parts/*.png (Pixen, no ground). Each piece
is placed with the middle of its lowest row ("foot") on a point of the footprint grid and
drawn back to front. Writes base.png, construction_1.png and construction_2.png next to the
parts folder, with the front corner of the footprint at PIVOT; tools/build_pixellab_buildings.py
then fits them like any other building (--pivot).

Run: python3 tools/compose_pixellab_camp.py  (needs Pillow)."""
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIR = os.path.join(ROOT, "tools", "pixellab_src", "buildings", "pioneer_camp")
CANVAS = (240, 200)
PIVOT = (120, 190)   # front corner of the 3x3 footprint on the canvas
FOOTPRINT = 3

# Piece -> foot on the footprint grid (x, y in tiles, 0..3; the front corner is (3, 3)).
SPOTS = {
    "cabin": (1.35, 1.3),
    "flag": (2.15, 0.45),
    "tent_a": (1.0, 2.85),
    "tent_b": (2.85, 1.0),
    "campfire": (2.25, 2.25),
    "logs": (1.45, 2.3),
    "supplies": (2.3, 1.45),
}
# Art name -> pieces (a piece "cabin" may be swapped for its construction stage).
LAYOUTS = {
    "base": {"cabin": "cabin", "flag": "flag", "tent_a": "tent_a", "tent_b": "tent_b",
             "campfire": "campfire", "logs": "logs", "supplies": "supplies"},
    # Just landed: a log floor for the cabin, one tent up, the supplies unloaded.
    "construction_1": {"cabin": "cabin_construction_1", "flag": "flag", "tent_a": "tent_a",
                       "logs": "logs", "supplies": "supplies"},
    # The cabin's walls going up, both tents and the fire.
    "construction_2": {"cabin": "cabin_construction_2", "flag": "flag", "tent_a": "tent_a",
                       "tent_b": "tent_b", "campfire": "campfire", "logs": "logs",
                       "supplies": "supplies"},
}


def screen(gx, gy):
    """Canvas pixel of the footprint grid point (gx, gy)."""
    return (PIVOT[0] + (gx - gy) * 32,
            PIVOT[1] + (gx + gy - 2 * FOOTPRINT) * 16)


def main():
    for name, pieces in LAYOUTS.items():
        out = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
        placed = []
        for spot, piece in pieces.items():
            img = Image.open(os.path.join(DIR, "parts", piece + ".png")).convert("RGBA")
            img = img.crop(img.getbbox())
            fx, fy = screen(*SPOTS[spot])
            placed.append((fy, fx, img))
        for fy, fx, img in sorted(placed, key=lambda p: (p[0], p[1])):
            out.alpha_composite(img, (round(fx - img.width / 2), round(fy - img.height)))
        out.save(os.path.join(DIR, name + ".png"))
        print(name)


if __name__ == "__main__":
    main()
