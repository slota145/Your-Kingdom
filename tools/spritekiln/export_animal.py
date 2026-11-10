"""Copy a rendered SpriteKiln animal (pig, sheep, horse; Z1 animal pens) into the game's sheets.

The game's sheet: assets/animals/<id>/<anim>.png, rows = screen directions S, SE, E, NE, N, NW, W, SW
(8 rows, nothing mirrored), columns = frames, square frames as rendered (a pig: 32 px). The ground point
under the animal is the spec's pivot, written to assets/animals/<id>/sheet.json with the frame size,
the frame time of each animation and the frame count (PenLayer reads it).

Run: python3 tools/spritekiln/export_animal.py <spec name> [--anims=idle,walk,root]
     (cd tools/spritekiln/art/specs/props/<spec> && spritekiln render <spec>.yaml first)
Then: "$GODOT" --headless --path . --import
"""
import json
import os
import sys

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DIRS = ["s", "se", "e", "ne", "n", "nw", "w", "sw"]


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    spec = args[0]
    anims = None
    for a in sys.argv:
        if a.startswith("--anims="):
            anims = a.split("=", 1)[1].split(",")
    d = os.path.join(ROOT, "tools", "spritekiln", "art", "specs", "props", spec, "out", spec)
    meta = json.load(open(os.path.join(d, spec + ".json")))
    piv = meta["spritekiln"]["pivot"]
    size = next(iter(meta["frames"].values()))["frame"]["w"]
    atlas = Image.open(os.path.join(d, spec + ".png")).convert("RGBA")
    if anims is None:
        anims = sorted({k.split("_")[0] for k in meta["frames"]})
    out_dir = os.path.join(ROOT, "assets", "animals", spec)
    os.makedirs(out_dir, exist_ok=True)
    info = {"frame": size, "foot": [round(piv["x"]), round(piv["y"])], "anims": {}}
    for anim in anims:
        n = sum(1 for k in meta["frames"] if k.startswith(f"{anim}_s_"))
        if n == 0:
            sys.exit(f"no frames for {anim}")
        sheet = Image.new("RGBA", (size * n, size * len(DIRS)))
        for row, dr in enumerate(DIRS):
            for f in range(n):
                r = meta["frames"][f"{anim}_{dr}_{f}"]["frame"]
                sheet.alpha_composite(atlas.crop((r["x"], r["y"], r["x"] + size, r["y"] + size)), (f * size, row * size))
        sheet.save(os.path.join(out_dir, anim + ".png"))
        ms = meta["frames"][f"{anim}_s_0"].get("duration", 120)
        info["anims"][anim] = {"frames": n, "ms": ms}
    json.dump(info, open(os.path.join(out_dir, "sheet.json"), "w"), indent=1)
    print("written", out_dir, info)


if __name__ == "__main__":
    main()
