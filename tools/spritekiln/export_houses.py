"""Copy the rendered SpriteKiln burgher and patrician houses into the game (assets/buildings/hut/level_2_*
and level_3_*, ART_SPEC 7).

Each render (art/specs/props/townhouse_l<2|3>_<piece>[_<look>][_back]) is cropped to its content,
symmetrically about the pivot's column (the game mirrors houses about the image's width, so the
pivot must stay in the middle), and saved as level_<n>_<piece>[_<look>][_back].png with its .json
(entrance and footprint like before, pivot = the plot's front corner).

Run after gen_townhouses.py game (and game3 for the patricians) and the renders:
    python3 tools/spritekiln/export_houses.py [2|3]   (default: both levels)
Then: "$GODOT" --headless --path . --import
"""
import glob
import json
import os

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PROPS = os.path.join(ROOT, "tools", "spritekiln", "art", "specs", "props")
OUT = os.path.join(ROOT, "assets", "buildings", "hut")


def main():
    import sys
    levels = sys.argv[1:] or ["2", "3"]
    done = 0
    for d in sorted(sum((glob.glob(os.path.join(PROPS, "townhouse_l%s_*" % lv)) for lv in levels), [])):
        name = os.path.basename(d)
        png = os.path.join(d, "out", name, name + ".png")
        if not os.path.exists(png):
            print("missing render:", name)
            continue
        meta = json.load(open(os.path.join(d, "out", name, name + ".json")))["spritekiln"]
        im = Image.open(png).convert("RGBA")
        px, py = int(round(meta["pivot"]["x"])), int(round(meta["pivot"]["y"] + 32))   # the plot's front corner
        l, t, r, b = im.getchannel("A").getbbox()
        half = max(px - l, r - px) + 2
        top = max(0, t - 2)
        bottom = max(b, py + 1) + 2
        crop = im.crop((px - half, top, px + half, bottom))
        art = "level_%s_%s" % (name[len("townhouse_l")], name[len("townhouse_l2_"):])
        crop.save(os.path.join(OUT, art + ".png"))
        with open(os.path.join(OUT, art + ".json"), "w") as fh:
            json.dump({"entrance": [1, 1], "footprint": [2, 2], "pivot": [half, py - top]}, fh, indent="\t")
        done += 1
    print(done, "houses ->", OUT)


if __name__ == "__main__":
    main()
