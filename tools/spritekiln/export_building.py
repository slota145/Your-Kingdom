"""Copy a rendered one-view SpriteKiln building (kind: prop, directions [se]) into the game.

The game's building art (ART_SPEC 3): assets/buildings/<id>/base.png + base.json with the
footprint, the entrance and the pivot = the plot's front corner on the ground. SpriteKiln's pivot
is the ground point under the model origin (the plot's centre), so ours lies 16 px x (footprint
x + y) / 2 lower. The image is cropped symmetrically about the pivot's x (the game mirrors buildings
about the image width) and down to the front corner. The construction stages stay as before.

Run: python3 tools/spritekiln/export_building.py <spec> [<building id>] [--stages]
     (cd tools/spritekiln/art/specs/props/<spec> && spritekiln render <spec>.yaml first)
     --stages also exports the construction stages rendered from <spec>_c1 and <spec>_c2 (specs in the
     same folder, written by gen_workshops.py) as construction_1 and construction_2.
Then: "$GODOT" --headless --path . --import
"""
import json
import os
import sys

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    spec = args[0]
    building = args[1] if len(args) > 1 else spec
    export(spec, spec, building, "base")
    if "--stages" in sys.argv:
        for k in (1, 2):
            export(spec, "%s_c%d" % (spec, k), building, "construction_%d" % k)


def export(folder, spec, building, art):
    d = os.path.join(ROOT, "tools", "spritekiln", "art", "specs", "props", folder, "out", spec)
    meta = json.load(open(os.path.join(d, spec + ".json")))
    piv = meta["spritekiln"]["pivot"]
    frame = next(iter(meta["frames"].values()))["frame"]
    atlas = Image.open(os.path.join(d, spec + ".png")).convert("RGBA")
    img = atlas.crop((frame["x"], frame["y"], frame["x"] + frame["w"], frame["y"] + frame["h"]))
    out = os.path.join(ROOT, "assets", "buildings", building)
    info = json.load(open(os.path.join(out, art + ".json")))
    fp = info["footprint"]
    px = round(piv["x"])
    py = round(piv["y"] + 16 * (fp[0] + fp[1]) / 2)
    left, top, right, bottom = img.getbbox()
    half = max(px - left, right - px)
    bottom = max(bottom, py + 1)
    img = img.crop((px - half, top, px + half, bottom))
    info["pivot"] = [half, py - top]
    img.save(os.path.join(out, art + ".png"))
    with open(os.path.join(out, art + ".json"), "w") as f:
        json.dump(info, f, indent="\t", sort_keys=True)
    print("written", out, img.size, info)


if __name__ == "__main__":
    main()
