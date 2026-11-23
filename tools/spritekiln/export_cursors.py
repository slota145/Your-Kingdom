"""UI-4 part 1: copies the rendered cursors (gen_cursors.py) into assets/ui/cursors/<id>_<size>.png
and writes cursors.json with each one's hotspot: the point (the finger, the spear's and the sword's
point: the opaque pixel furthest up-left) or the middle (hammer, anchor, no-way sign).

Run: python3 tools/spritekiln/export_cursors.py
"""
import json
import os

from PIL import Image

import gen_cursors as GC

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "assets", "ui", "cursors")
POINTED = ("pointer", "command", "attack")


def main():
    os.makedirs(OUT, exist_ok=True)
    hotspots = {}
    for cid in GC.CURSORS:
        for size in GC.SIZES:
            name = f"cursor_{cid}_{size}"
            d = os.path.join(HERE, "art", "specs", "props", name, "out", name)
            meta = json.load(open(os.path.join(d, name + ".json")))
            frame = next(iter(meta["frames"].values()))["frame"]
            img = Image.open(os.path.join(d, name + ".png")).convert("RGBA").crop(
                (frame["x"], frame["y"], frame["x"] + frame["w"], frame["y"] + frame["h"]))
            if cid in POINTED:
                best = None
                for y in range(img.height):
                    for x in range(img.width):
                        if img.getpixel((x, y))[3] > 128 and (best is None or x + y < best[0] + best[1]):
                            best = (x, y)
                spot = list(best)
            else:
                box = img.getbbox()
                spot = [(box[0] + box[2]) // 2, (box[1] + box[3]) // 2]
            img.save(os.path.join(OUT, f"{cid}_{size}.png"))
            hotspots[f"{cid}_{size}"] = spot
    with open(os.path.join(OUT, "cursors.json"), "w") as fh:
        json.dump(hotspots, fh, indent="\t", sort_keys=True)
    print(hotspots)


if __name__ == "__main__":
    main()
