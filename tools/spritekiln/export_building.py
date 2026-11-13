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
     A moving part (the mill's sails): when the folder has anim.json and specs <spec>_anim_<k>, the
     base and its frames are cut with one box (so the frames keep the base's pivot) and the frames
     are written side by side to base_anim.png with base_anim.json {frames, fps, sort_tile}.
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
    folder = os.path.join(ROOT, "tools", "spritekiln", "art", "specs", "props", spec)
    anim_meta = os.path.join(folder, "anim.json")
    if os.path.exists(anim_meta):
        anim = json.load(open(anim_meta))
        frames = ["%s_anim_%d" % (spec, k) for k in range(anim["frames"])]
        box = None
        for name in [spec] + frames:
            b = rendered(spec, name)[0].getbbox()
            box = b if box is None else (min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3]))
        export(spec, spec, building, "base", box)
        imgs = [cut(rendered(spec, n), building, box)[0] for n in frames]
        strip = Image.new("RGBA", (imgs[0].width * len(imgs), imgs[0].height))
        for k, im in enumerate(imgs):
            strip.paste(im, (k * im.width, 0))
        out = os.path.join(ROOT, "assets", "buildings", building)
        strip.save(os.path.join(out, "base_anim.png"))
        with open(os.path.join(out, "base_anim.json"), "w") as f:
            json.dump(anim, f, indent="\t", sort_keys=True)
        print("written", out, "base_anim", strip.size)
    else:
        export(spec, spec, building, "base")
    if "--stages" in sys.argv:
        for k in (1, 2):
            export(spec, "%s_c%d" % (spec, k), building, "construction_%d" % k)


def rendered(folder, spec):
    """The rendered frame of a one-view spec and its SpriteKiln pivot."""
    d = os.path.join(ROOT, "tools", "spritekiln", "art", "specs", "props", folder, "out", spec)
    meta = json.load(open(os.path.join(d, spec + ".json")))
    frame = next(iter(meta["frames"].values()))["frame"]
    atlas = Image.open(os.path.join(d, spec + ".png")).convert("RGBA")
    img = atlas.crop((frame["x"], frame["y"], frame["x"] + frame["w"], frame["y"] + frame["h"]))
    return img, meta["spritekiln"]["pivot"]


def cut(rendered_img, building, box=None, art="base"):
    """Crops symmetrically about the pivot's x and down to the plot's front corner; `box` = the
    bounding box to keep (default: the image's own)."""
    img, piv = rendered_img
    info = json.load(open(os.path.join(ROOT, "assets", "buildings", building, art + ".json")))
    fp = info["footprint"]
    px = round(piv["x"])
    py = round(piv["y"] + 16 * (fp[0] + fp[1]) / 2)
    left, top, right, bottom = box or img.getbbox()
    half = max(px - left, right - px)
    bottom = max(bottom, py + 1)
    info["pivot"] = [half, py - top]
    return img.crop((px - half, top, px + half, bottom)), info


def export(folder, spec, building, art, box=None):
    img, info = cut(rendered(folder, spec), building, box, art)
    out = os.path.join(ROOT, "assets", "buildings", building)
    img.save(os.path.join(out, art + ".png"))
    with open(os.path.join(out, art + ".json"), "w") as f:
        json.dump(info, f, indent="\t", sort_keys=True)
    print("written", out, img.size, info)


if __name__ == "__main__":
    main()
