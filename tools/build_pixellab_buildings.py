#!/usr/bin/env python3
"""Builds the game art of the buildings drawn by PixelLab (G1, ART_SPEC §10.12) from the raw
PixelLab images kept in tools/pixellab_src/buildings/<id>/ (not imported by Godot).

First the colours of the whole set are evened out (tools/harmonize_pixellab.py, owner's
decision 2026-11-07): each material pulled to the set's common hue and saturation, each
building's brightness three quarters of the way to the set's average, greys warmed. Then every image goes through
tools/fit_pixellab_building.py: placed on its footprint with the pivot in the front corner,
the production yard drawn under it. A construction stage or the back of a house is an edit of its finished
building on the same canvas, so it takes the finished building's placement (--like).

Run after changing a raw image or a setting below: python3 tools/build_pixellab_buildings.py
[<building id>...]  (needs Pillow). Then import in Godot (tools/run_tests.sh does it)."""
import os
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from harmonize_pixellab import harmonize  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tools", "pixellab_src", "buildings")
OUT = os.path.join(ROOT, "assets", "buildings")
FIT = os.path.join(ROOT, "tools", "fit_pixellab_building.py")
# Pixen art is as bright as the code-drawn buildings: the owner turned the brightening of the
# trial (tools/brighten_pixellab.py, made for the darker Pro Flash) off on 2026-11-07.
COMMON = ["--no-brighten"]

# Building id -> (fit options shared by all its images, {art name: raw image it is made of}).
# The first raw named in each group is the finished building the others line up with.
# Workshops with a production yard (BuildingDef.yard_at = (1, 0)) stand on the two back
# tiles (volume x 0..1, y 0..2) beside the yard, like the code-drawn art (paczka 2).
WORKSHOP = ["--footprint=2,2", "--entrance=1,1", "--volume=0,0,1,2", "--yard=1,0"]
BUILDINGS = {
    "pioneer_camp": (
        # Laid out from separate pieces by tools/compose_pixellab_camp.py (no ground of its
        # own, inside the 3x3 tiles); the front corner sits at its PIVOT.
        ["--footprint=3,3", "--entrance=1,2", "--pivot=120,190"],
        [("base", "base", {}),
         ("construction_1", "construction_1", {"like": "base"}),
         ("construction_2", "construction_2", {"like": "base"})]),
    "hut": (
        ["--footprint=2,2", "--entrance=1,1"],
        [("base", "base", {}),
         ("base_2", "base_2", {}),
         ("base_3", "base_3", {}),
         ("base_back", "base_back", {"like": "base"}),
         ("base_2_back", "base_2_back", {"like": "base_2"}),
         ("base_3_back", "base_3_back", {"like": "base_3"}),
         ("construction_1", "construction_1", {"like": "base"}),
         # A bare foundation has no door: the back of the site is the same picture.
         ("construction_1_back", "construction_1", {"like": "base"}),
         ("construction_2", "construction_2", {"like": "base"}),
         ("construction_2_back", "construction_2_back", {"like": "base"})]),
    "woodcutter": (WORKSHOP, [("base", "base", {}),
                              ("construction_1", "construction_1", {"like": "base"}),
                              ("construction_2", "construction_2", {"like": "base"})]),
    "quarry": (WORKSHOP, [("base", "base", {}),
                          ("construction_1", "construction_1", {"like": "base"}),
                          ("construction_2", "construction_2", {"like": "base"})]),
    "fishing_hut": (WORKSHOP, [("base", "base", {}),
                               ("construction_1", "construction_1", {"like": "base"}),
                               ("construction_2", "construction_2", {"like": "base"})]),
}


def main():
    only = sys.argv[1:]
    subprocess.run([sys.executable, os.path.join(ROOT, "tools", "compose_pixellab_camp.py")],
                   check=True)
    # Colours are evened out over the whole set (all buildings, even when only some are
    # rebuilt), into a temporary copy of the raw images.
    tmp = tempfile.mkdtemp(prefix="pixellab_")
    groups = {}
    for building, (_opts, images) in BUILDINGS.items():
        os.makedirs(os.path.join(tmp, building), exist_ok=True)
        for _name, raw, extra in images:
            key = "%s/%s" % (building, extra.get("like", raw))
            pair = (os.path.join(SRC, building, raw + ".png"), os.path.join(tmp, building, raw + ".png"))
            files = groups.setdefault(key, [])
            if pair not in files:
                files.insert(0, pair) if "like" not in extra else files.append(pair)
    harmonize(groups)
    for building, (opts, images) in BUILDINGS.items():
        if only and building not in only:
            continue
        for name, raw, extra in images:
            args = [sys.executable, FIT, os.path.join(tmp, building, raw + ".png"),
                    os.path.join(OUT, building, name)] + opts + COMMON
            if "like" in extra:
                args.append("--like=" + os.path.join(tmp, building, extra["like"] + ".png"))
            subprocess.run(args, check=True)


if __name__ == "__main__":
    main()
