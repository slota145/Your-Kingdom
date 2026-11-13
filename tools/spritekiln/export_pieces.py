"""Copy a building drawn as separately sorted pieces into the game (G3 part 4b: the warehouse shed).

art/specs/props/<id>/pieces.json (written by gen_town.py) lists the pieces: name -> {offset, footprint},
in tiles from the building's origin. Each piece is rendered from the same model and camera as the
building (<id>_<piece>.yaml, so SpriteKiln's pivot is the plot's centre); its own pivot is the front
corner of its footprint. The image is cropped symmetrically about that pivot (the game mirrors art
about the image width) and saved as assets/buildings/<id>/<piece>.png with its .json
{footprint, entrance [0, 0], pivot, offset}. BuildingLayer places each piece at origin + offset.

Run: python3 tools/spritekiln/export_pieces.py <id>   (after rendering every <id>_<piece>.yaml)
"""
import json
import os
import sys

from export_building import ROOT, rendered


def main():
    bid = sys.argv[1]
    folder = os.path.join(ROOT, "tools", "spritekiln", "art", "specs", "props", bid)
    pieces = json.load(open(os.path.join(folder, "pieces.json")))
    n = json.load(open(os.path.join(ROOT, "assets", "buildings", bid, "construction_1.json")))["footprint"][0]
    for name, d in pieces.items():
        img, piv = rendered(bid, "%s_%s" % (bid, name))
        (ox, oy), (fx, fy) = d["offset"], d["footprint"]
        dgx, dgy = ox + fx - n / 2, oy + fy - n / 2
        px = round(piv["x"] + (dgx - dgy) * 32)
        py = round(piv["y"] + (dgx + dgy) * 16)
        left, top, right, bottom = img.getbbox()
        half = max(px - left, right - px) + 1
        bottom = max(bottom, py + 1)
        crop = img.crop((px - half, top, px + half, bottom))
        out = os.path.join(ROOT, "assets", "buildings", bid)
        crop.save(os.path.join(out, name + ".png"))
        with open(os.path.join(out, name + ".json"), "w") as f:
            json.dump({"entrance": [0, 0], "footprint": [fx, fy], "offset": [ox, oy], "pivot": [half, py - top]}, f,
                      indent="\t", sort_keys=True)
        print("written", name, crop.size, (half, py - top))


if __name__ == "__main__":
    main()
