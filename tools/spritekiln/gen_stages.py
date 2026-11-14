"""G3 clean-up (ROADMAP G3, part 5): construction stages from the model for the SpriteKiln
buildings made before G3 part 3, whose stages were still drawn by tools/generate_art.gd (owner's
survey 2026-11-14: "Pełne, z etapami").

Reads a finished building's spec (art/specs/props/<id>/<id>.yaml, written by its own generator or
by hand) and writes <id>_c1.yaml and <id>_c2.yaml beside it, with the same camera, so they lie
exactly on the building:
- stage 1: the model cut off just above the ground (yard, plinths, foundations), stakes at the
  corners of the building's body and strings between them, a heap of squared beams and stones;
- stage 2: the model cut off at wall height 0.85 (walls half built), scaffold poles and plank walks
  along the two faces the camera sees.
The body's rectangle is found from the model: the boxes that stand as walls (tall boxes on the
ground), or BODY below. Nothing else in the game changes.

Run (inside tools/spritekiln): python3 gen_stages.py [<id>...], then build_stages.sh <id>...
"""
import copy
import os
import sys

import yaml

import gen_workshops as W
import workshop_kit as K
from workshop_kit import box, cyl, plane, r4

HERE = os.path.dirname(os.path.abspath(__file__))
IDS = ["pigsty", "sheep_farm", "stud_farm", "apiary", "orchard", "hunter_lodge", "porters_hut", "porters_house",
       "stone_pit", "deep_mine", "school", "university", "barracks_small", "barracks_large"]
# Buildings whose body the wall search cannot find (open sheds, pits): model (x0, x1, z0, z1).
BODY = {}
CUT_1, CUT_2 = 0.24, 0.85
EXTRA_RAMPS = {"stage_rope": W.RAMPS["rope"]}
EXTRA_MATERIALS = {
    "stage_timber": {"ramp": "wood", "bands": [2, 5]},
    "stage_rope": {"ramp": "stage_rope", "bands": [1, 3], "outline": False},
    "stage_stone": {"ramp": "stone", "bands": [2, 5]},
}


def prim_min_y(prim):
    """Lowest point of a primitive (None when unknown: kept)."""
    (kind, d), = prim.items()
    try:
        if kind == "box":
            return None if "rot" in d else d["c"][1] - d["half"][1]
        if kind in ("cylinder", "capsule"):
            return min(d["a"][1], d["b"][1]) - (d["r"] if isinstance(d["r"], (int, float)) else max(d["r"]))
        if kind == "cone":
            return min(d["a"][1], d["b"][1]) - max(d["r"])
        if kind == "sphere":
            return d["c"][1] - d["r"]
        if kind == "ellipsoid":
            return None if "rot" in d else d["c"][1] - d["r"][1]
        if kind == "torus":
            return d["c"][1] - d["R"] - d["r"]
    except (KeyError, TypeError, IndexError):
        return None
    return None


def body(spec, n):
    """Model (x0, x1, z0, z1) of the building's body: the union of tall boxes standing on the ground."""
    xs, zs = [], []
    for part in spec["parts"].values():
        for prim in part.get("prims", []):
            (kind, d), = prim.items()
            if kind != "box" or "rot" in d:
                continue
            try:
                c, h = d["c"], d["half"]
            except KeyError:
                continue
            if not all(isinstance(v, (int, float)) for v in list(c) + list(h)):
                continue
            if c[1] - h[1] < 0.5 and c[1] + h[1] > 1.2 and max(h[0], h[2]) > 0.5:
                xs += [c[0] - h[0], c[0] + h[0]]
                zs += [c[2] - h[2], c[2] + h[2]]
    half = n * K.T / 2
    if not xs:
        return -half + 0.3, half - 0.3, -half + 0.3, half - 0.3
    return max(min(xs), -half), min(max(xs), half), max(min(zs), -half), min(max(zs), half)


def cut_parts(parts, y):
    out = {}
    for name, part in parts.items():
        prims = [q for q in part.get("prims", []) if (prim_min_y(q) is None or prim_min_y(q) < y)]
        if not prims:
            continue
        p = copy.deepcopy(part)
        p["prims"] = prims
        p.setdefault("cut", []).append(plane([0, 1, 0], [0, y, 0]))
        out[name] = p
    return out


def add(parts, name, material, prim, **extra):
    p = parts.setdefault(name, {"material": material, "prims": []})
    p.update(extra)
    p["prims"].append(prim)


def site(parts, rect, which, n):
    x0, x1, z0, z1 = rect
    if which == 1:
        for (x, z) in ((x0, z0), (x0, z1), (x1, z1), (x1, z0)):
            add(parts, "stakes", "stage_timber", cyl([x - 0.08, 0, z + 0.08], [x - 0.08, 0.5, z + 0.08], 0.035))
        for a, b in (((x0, z0), (x0, z1)), ((x0, z1), (x1, z1))):
            add(parts, "strings", "stage_rope", cyl([a[0] - 0.08, 0.42, a[1] + 0.08], [b[0] - 0.08, 0.42, b[1] + 0.08], 0.018),
                min_cover=1, priority=2)
    else:
        top = CUT_2 + 0.9
        for (x, z) in ((x0 - 0.35, z0), (x0 - 0.35, (z0 + z1) / 2), (x0 - 0.35, z1 + 0.35), ((x0 + x1) / 2, z1 + 0.35),
                       (x1, z1 + 0.35)):
            add(parts, "scaffold", "stage_timber", cyl([x, 0, z], [x, top, z], 0.035), priority=2)
        add(parts, "scaffold_planks", "stage_timber", box([x0 - 0.35, CUT_2 - 0.05, (z0 + z1 + 0.35) / 2],
                                                          [0.16, 0.03, (z1 - z0 + 0.4) / 2]))
        add(parts, "scaffold_planks", "stage_timber", box([(x0 - 0.35 + x1) / 2, CUT_2 - 0.05, z1 + 0.35],
                                                          [(x1 - x0 + 0.4) / 2, 0.03, 0.16]))
        add(parts, "scaffold", "stage_timber", box([x0 - 0.35, CUT_2 + 0.6, (z0 + z1 + 0.35) / 2], [0.03, 0.03, (z1 - z0 + 0.4) / 2]),
            priority=2)
        add(parts, "scaffold", "stage_timber", box([(x0 - 0.35 + x1) / 2, CUT_2 + 0.6, z1 + 0.35], [(x1 - x0 + 0.4) / 2, 0.03, 0.03]),
            priority=2)
    # a heap of squared beams and stones by the right corner of the body
    hx, hz = (x0 + x1) / 2 + 0.2, min(z1 + 0.55, n * K.T / 2 - 0.4)
    for k in range(3):
        add(parts, "beams", "stage_timber", box([hx - 0.3 + k * 0.16, 0.08, hz], [0.07, 0.08, 0.5]))
    add(parts, "beams", "stage_timber", box([hx - 0.14, 0.24, hz], [0.07, 0.08, 0.5]))
    for dx, dz, r in ((0.35, -0.2, 0.11), (0.45, 0.05, 0.13), (0.3, 0.15, 0.1)):
        add(parts, "stone_heap", "stage_stone", {"ellipsoid": {"c": r4([hx + dx, r * 0.5, hz + dz]), "r": r4([r * 1.2, r * 0.7, r])}})


def main():
    ids = [a for a in sys.argv[1:] if not a.startswith("-")] or IDS
    for bid in ids:
        folder = os.path.join(HERE, "art", "specs", "props", bid)
        spec = yaml.safe_load(open(os.path.join(folder, bid + ".yaml")))
        fp = [l for l in open(os.path.join(HERE, "..", "..", "data", "buildings", bid + ".tres")) if l.startswith("footprint")]
        n = int(fp[0].split("(")[1].split(",")[0]) if fp else 2
        rect = BODY.get(bid) or body(spec, n)
        for k, y in ((1, CUT_1), (2, CUT_2)):
            st = copy.deepcopy(spec)
            st["name"] = "%s_c%d" % (bid, k)
            st.setdefault("brief", {})["summary"] = (st.get("brief", {}).get("summary", bid) + " (construction stage %d, "
                                                     "from the model by gen_stages.py)" % k)
            st["brief"].pop("must_keep", None)
            st["parts"] = cut_parts(spec["parts"], y)
            site(st["parts"], rect, k, n)
            ramps = st.get("ramps") or {}
            ramps.update(EXTRA_RAMPS)
            st["ramps"] = ramps
            mats = st.get("materials") or {}
            mats.update(EXTRA_MATERIALS)
            st["materials"] = mats
            st["animations"] = {"idle": {"frames": 1, "ms": 500, "channels": {}}}
            st.pop("bones", None)
            text = yaml.safe_dump(st, sort_keys=False, default_flow_style=None, width=140)
            first, rest = text.split("\n", 1)
            with open(os.path.join(folder, st["name"] + ".yaml"), "w") as fh:
                fh.write(first + "\n# Generated by tools/spritekiln/gen_stages.py from %s.yaml; edit the script.\n" % bid + rest)
        print("written", bid, "stages, body", [round(v, 2) for v in rect])


if __name__ == "__main__":
    main()
