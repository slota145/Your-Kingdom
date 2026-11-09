"""Copy a rendered SpriteKiln ship into the game's sheet format (ART_SPEC 9, ShipLayer.BIG_FRAMES).

The game's sheet: 8 rows of directions in ART_SPEC order (S, SE, E, NE, N, NW, W, SW), one column per
rocking frame, every frame the same size with the ship's waterline centre at the same pivot. The
spec's frame size and camera centre must already give that pivot (the script checks it).

Run: python3 tools/spritekiln/export_ship.py <spec name> <ship asset id> <pivot x,y>
     e.g. python3 tools/spritekiln/export_ship.py cog cog 110,168
          python3 tools/spritekiln/export_ship.py cog_build_0 cog 110,168 --out=build_0   (a slipway stage)
Then: "$GODOT" --headless --path . --import
"""
import json
import os
import sys

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DIRS = ["s", "se", "e", "ne", "n", "nw", "w", "sw"]


def main():
    spec, asset = sys.argv[1], sys.argv[2]
    want = [float(v) for v in sys.argv[3].split(",")]
    d = os.path.join(ROOT, "tools", "spritekiln", "art", "specs", "props", spec, "out", spec)
    meta = json.load(open(os.path.join(d, f"{spec}.json")))
    piv = meta["spritekiln"]["pivot"]
    if abs(piv["x"] - want[0]) > 0.5 or abs(piv["y"] - want[1]) > 0.5:
        sys.exit(f"pivot {piv} is not {want}: fix camera.center in the spec")
    size = meta["spritekiln"]["frame_size"]
    atlas = Image.open(os.path.join(d, f"{spec}.png")).convert("RGBA")
    nf = sum(1 for k in meta["frames"] if k.startswith("idle_s_"))
    sheet = Image.new("RGBA", (size * nf, size * 8))
    for row, dr in enumerate(DIRS):
        for f in range(nf):
            r = meta["frames"][f"idle_{dr}_{f}"]["frame"]
            sheet.alpha_composite(atlas.crop((r["x"], r["y"], r["x"] + r["w"], r["y"] + r["h"])), (f * size, row * size))
    name = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--out=")), "idle")
    out = os.path.join(ROOT, "assets", "ships", asset, name + ".png")
    sheet.save(out)
    print(out, sheet.size)


if __name__ == "__main__":
    main()
