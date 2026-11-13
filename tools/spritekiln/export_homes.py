"""Copy the rendered SpriteKiln huts (house level 1, G3 part 4a) into the game (assets/buildings/hut).

Renders in art/specs/props/hut/out (written by gen_homes.py, rendered by build_homes.sh) map to:
    hut, hut_2, hut_3 [+ _back]      -> base, base_2, base_3 [+ _back]
    hut_c1, hut_c2 [hut_back_c1/2]   -> construction_1, construction_2 [+ _back]
    hut_scaffold                     -> upgrade_scaffold and upgrade_scaffold_back (one model)
Each is cropped symmetrically about the pivot and down to the plot's front corner (export_building.cut).

Run (from anywhere): python3 tools/spritekiln/export_homes.py
Then: "$GODOT" --headless --path . --import
"""
import json
import os

from export_building import ROOT, cut, rendered

ART = {"hut": "base", "hut_2": "base_2", "hut_3": "base_3", "hut_c1": "construction_1", "hut_c2": "construction_2",
       "hut_scaffold": "upgrade_scaffold"}


def main():
    out = os.path.join(ROOT, "assets", "buildings", "hut")
    jobs = []
    for spec, art in ART.items():
        jobs.append((spec, art))
        if spec == "hut_scaffold":
            jobs.append((spec, art + "_back"))
        elif spec.endswith(("_c1", "_c2")):
            jobs.append((spec.replace("hut_", "hut_back_"), art + "_back"))
        else:
            jobs.append((spec + "_back", art + "_back"))
    for spec, art in jobs:
        img, info = cut(rendered("hut", spec), "hut", None, art)
        img.save(os.path.join(out, art + ".png"))
        with open(os.path.join(out, art + ".json"), "w") as f:
            json.dump(info, f, indent="\t", sort_keys=True)
        print("written", art, img.size, info["pivot"])


if __name__ == "__main__":
    main()
