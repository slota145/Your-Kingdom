"""Copy the rendered standing crops (gen_crops.py) into the game: assets/nature/crops/<crop>/
<state>.png, every state of a crop on the same canvas with the tile centre at FOOT (the view's
CROPS table in src/view/terrain/vine_layer.gd uses the same numbers). Also writes the field
ground under them: assets/terrain/field{,_hops}/<stage>.png, ploughed soil for every stage
but fallow (the plants stand on it now, owner 2026-11-11).

Run (repository root): python3 tools/spritekiln/export_crops.py
"""
import json
import os

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SPECS = os.path.join(ROOT, "tools", "spritekiln", "art", "specs", "props")
# crop -> (states, canvas size, foot = tile centre on the canvas)
CROPS = {
    "grain": (["sprout", "young", "green", "ripe"], (64, 64), (32, 48)),
    "hops": (["poles", "shoot", "half", "full", "ripe"], (64, 112), (32, 96)),
}
GROUND = {"grain": "field", "hops": "field_hops"}


def main():
    for crop, (states, size, foot) in CROPS.items():
        out = os.path.join(ROOT, "assets", "nature", "crops", crop)
        os.makedirs(out, exist_ok=True)
        for state in states:
            name = "crop_%s_%s" % (crop, state)
            d = os.path.join(SPECS, name, "out", name)
            meta = json.load(open(os.path.join(d, name + ".json")))
            piv = meta["spritekiln"]["pivot"]
            frame = next(iter(meta["frames"].values()))["frame"]
            atlas = Image.open(os.path.join(d, name + ".png")).convert("RGBA")
            img = atlas.crop((frame["x"], frame["y"], frame["x"] + frame["w"], frame["y"] + frame["h"]))
            canvas = Image.new("RGBA", size, (0, 0, 0, 0))
            dx, dy = foot[0] - round(piv["x"]), foot[1] - round(piv["y"])
            canvas.alpha_composite(img, (dx, dy)) if dx >= 0 and dy >= 0 else canvas.paste(img, (dx, dy), img)
            box = img.getbbox()
            if box[0] + dx < 0 or box[1] + dy < 0 or box[2] + dx > size[0] or box[3] + dy > size[1]:
                raise SystemExit("%s does not fit %s (box %s, shift %d,%d)" % (name, size, box, dx, dy))
            canvas.save(os.path.join(out, state + ".png"))
            print("written", crop, state)
        # The ground under the plants: the placeholder's ploughed soil for every grown stage.
        src = os.path.join(ROOT, "assets", "_placeholder", "terrain", GROUND[crop])
        dst = os.path.join(ROOT, "assets", "terrain", GROUND[crop])
        os.makedirs(dst, exist_ok=True)
        plowed = Image.open(os.path.join(src, "plowed.png")).convert("RGBA")
        Image.open(os.path.join(src, "fallow.png")).convert("RGBA").save(os.path.join(dst, "fallow.png"))
        for stage in ["plowed", "sown_1", "sown_2", "sown_3", "ripe"]:
            plowed.save(os.path.join(dst, stage + ".png"))


if __name__ == "__main__":
    main()
