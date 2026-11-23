"""UI-4 part 1 (owner's survey 2026-11-23): the mouse cursors from SpriteKiln.

Six small models seen from the front (direction s, a low pitch), lying in the screen plane: screen
right = model +x, up = +y, towards the camera = +z. Each is drawn at 32 px (interface scale 100%)
and 48 px (125% and more):
  pointer  - a steel gauntlet pointing up-left with its index finger (the ordinary cursor),
  command  - a spear with a red pennant, its point up-left (soldiers selected),
  attack   - a sword, its point up-left (over an enemy),
  break    - a war hammer (over an enemy's wall, gate or town hall door to break),
  board    - an iron anchor (over a warship the soldiers can board),
  blocked  - a red ring with a bar (nowhere to go).

Writes art/specs/props/cursor_<id>_<size>/cursor_<id>_<size>.yaml; edit this script.
Run (inside tools/spritekiln): python3 gen_cursors.py, then for each spec `spritekiln render`, then
python3 export_cursors.py (from anywhere): assets/ui/cursors/<id>_<size>.png and cursors.json (hotspots).
"""
import math
import os
import sys

import yaml

HERE = os.path.dirname(os.path.abspath(__file__))
PROPS = os.path.join(HERE, "art", "specs", "props")
SIZES = (32, 48)
# Model units across the 32 px frame (the models span about -0.95..0.95).
SPAN = 1.88

RAMPS = {
    "steel": ["#0c0e12", "#2a3038", "#4a525c", "#76808a", "#a8b2bc", "#e2e8ee"],
    "gold": ["#1c1006", "#4d2f0e", "#8a5a16", "#c48c22", "#e8c04e", "#fff0a0"],
    "wood": ["#140a05", "#3a2210", "#5e3a1c", "#835630", "#a87444", "#c89660"],
    "leather": ["#120a06", "#3a2214", "#5e3a22", "#80542e", "#a07040", "#bc8c58"],
    "red": ["#1c0606", "#4a1210", "#7a1e1a", "#a82824", "#d0443a", "#ee7464"],
    "iron": ["#060708", "#1c1f24", "#33383f", "#4e555e", "#6e7680", "#949ca6"],
}
MAT = {
    "steel": {"ramp": "steel", "bands": [2, 5], "finish": "metal"},
    "gold": {"ramp": "gold", "bands": [2, 5], "finish": "metal"},
    "wood": {"ramp": "wood", "bands": [2, 5]},
    "leather": {"ramp": "leather", "bands": [2, 5]},
    "red": {"ramp": "red", "bands": [2, 5], "two_sided": True},
    "iron": {"ramp": "iron", "bands": [2, 5], "finish": "metal"},
}
# Up-left in the screen plane.
UL = (-math.sqrt(0.5), math.sqrt(0.5), 0.0)


def cyl(a, b, r):
    return {"cylinder": {"a": a, "b": b, "r": r}}


def cone(a, b, r0, r1):
    return {"cone": {"a": a, "b": b, "r": [r0, r1]}}


def sph(c, r):
    return {"sphere": {"c": c, "r": r}}


def box(c, half, rot=None, rnd=0.0):
    d = {"c": c, "half": half}
    if rot:
        d["rot"] = rot
    if rnd:
        d["round"] = rnd
    return {"box": d}


def tor(c, R, r, rot=None):
    d = {"c": c, "R": R, "r": r}
    if rot:
        d["rot"] = rot
    return {"torus": d}


def ext(c, pts, depth, rot=None):
    d = {"c": c, "profile": {"polygon": pts}, "depth": depth}
    if rot:
        d["rot"] = rot
    return {"extrude": d}


def along(t, off=0.0):
    """A point t along the up-left diagonal, `off` across it (to its upper right)."""
    return [round(UL[0] * t + off * math.sqrt(0.5), 4), round(UL[1] * t + off * math.sqrt(0.5), 4), 0.0]


# Turn about z putting a shape drawn pointing up (+y) onto the up-left diagonal.
TILT = [0, 0, round(math.pi / 4, 4)]


def pointer():
    """A steel gauntlet seen from the back of the hand: a broad plated hand, the index finger
    pointing up-left, the thumb out to the upper right, the other fingers curled under, a leather
    cuff with a gilt rim at the lower right."""
    return {
        "cuff": {"material": "leather", "prims": [cyl(along(-0.5), along(-0.92), 0.3)]},
        "cuff_rim": {"material": "gold", "prims": [cyl(along(-0.46), along(-0.53), 0.32)]},
        "hand": {"material": "steel", "prims": [box(along(-0.18, -0.04), [0.3, 0.3, 0.14], rot=TILT, rnd=0.1)],
                 "paint": [{"material": "iron", "stripes": {"axis": "y", "period": 0.16, "width": 0.05}}]},
        "curled": {"material": "steel", "prims": [sph(along(0.14, -0.16), 0.13), sph(along(0.04, -0.3), 0.12),
                                                  sph(along(-0.08, -0.38), 0.11)]},
        "thumb": {"material": "steel", "prims": [cyl(along(-0.22, 0.26), along(0.0, 0.42), 0.09)]},
        "finger": {"material": "steel", "prims": [cyl(along(0.1, 0.1), along(0.55, 0.1), 0.095)]},
        "finger_tip": {"material": "steel", "prims": [cone(along(0.55, 0.1), along(0.74, 0.1), 0.095, 0.035)]},
        "finger_joint": {"material": "gold", "prims": [cyl(along(0.3, 0.1), along(0.35, 0.1), 0.105)]},
    }


def command():
    """A spear, the point up-left, a red swallow-tailed pennant under the point."""
    return {
        "shaft": {"material": "wood", "prims": [cyl(along(-0.95), along(0.55), 0.045)]},
        "socket": {"material": "iron", "prims": [cyl(along(0.5), along(0.6), 0.06)]},
        "point": {"material": "steel", "prims": [ext(along(0.6), [[-0.09, 0], [0, 0.36], [0.09, 0]], 0.04, rot=TILT)]},
        "pennant": {"material": "red", "prims": [ext(along(0.36, 0.02),
                                                     [[0, 0.14], [0.55, 0.1], [0.42, 0.0], [0.55, -0.1], [0, -0.14]], 0.02,
                                                     rot=[0, 0, round(-math.pi / 4 + 0.15, 4)])]},
        "butt": {"material": "iron", "prims": [cyl(along(-0.95), along(-0.88), 0.055)]},
    }


def attack():
    """A sword, the point up-left: a steel blade with a fuller, a gilt cross-guard and pommel."""
    return {
        "blade": {"material": "steel", "prims": [ext(along(-0.15), [[-0.085, 0], [0.085, 0], [0.07, 0.85], [0, 1.05],
                                                                      [-0.07, 0.85]], 0.04, rot=TILT)],
                  "paint": [{"material": "iron", "prims": [cyl(along(-0.1), along(0.6), 0.02)]}]},
        "guard": {"material": "gold", "prims": [cyl(along(-0.17, -0.3), along(-0.17, 0.3), 0.045)]},
        "grip": {"material": "leather", "prims": [cyl(along(-0.2), along(-0.62), 0.055)]},
        "pommel": {"material": "gold", "prims": [sph(along(-0.7), 0.1)]},
    }


def breaking():
    """A war hammer: a heavy iron head at the upper left, a wooden haft to the lower right."""
    return {
        "haft": {"material": "wood", "prims": [cyl(along(-0.95), along(0.45), 0.05)]},
        "grip": {"material": "leather", "prims": [cyl(along(-0.95), along(-0.55), 0.06)]},
        "head": {"material": "iron", "prims": [box(along(0.5), [0.36, 0.17, 0.15], rot=[0, 0, round(math.pi / 4, 4)], rnd=0.03)]},
        "face": {"material": "steel", "prims": [box(along(0.5, -0.38), [0.19, 0.04, 0.17], rot=[0, 0, round(math.pi / 4, 4)])]},
        "spike": {"material": "steel", "prims": [cone(along(0.5, 0.33), along(0.5, 0.62), 0.11, 0.0)]},
        "bands": {"material": "gold", "prims": [cyl(along(0.3), along(0.34), 0.065)]},
    }


def board():
    """An iron anchor: a ring at the top, a stock across, flukes at the bottom (a little smaller
    than the others: it is tall)."""
    k = 0.88

    def v(x, y):
        return [round(x * k, 4), round(y * k, 4), 0]
    return {
        "ring": {"material": "iron", "prims": [tor(v(0, 0.78), 0.13 * k, 0.04, rot=[1.5708, 0, 0])]},
        "shank": {"material": "iron", "prims": [cyl(v(0, 0.66), v(0, -0.72), 0.065)]},
        "stock": {"material": "wood", "prims": [cyl(v(-0.42, 0.48), v(0.42, 0.48), 0.06)],
                  "paint": [{"material": "gold", "prims": [cyl(v(-0.44, 0.48), v(-0.36, 0.48), 0.08),
                                                            cyl(v(0.36, 0.48), v(0.44, 0.48), 0.08)]}]},
        "arms": {"material": "iron", "prims": [tor(v(0, -0.24), 0.55 * k, 0.06, rot=[1.5708, 0, 0])],
                 "cut": [{"plane": {"n": [0, 1, 0], "c": v(0, -0.3)}}]},
        "flukes": {"material": "iron", "prims": [cone(v(-0.55, -0.32), v(-0.62, -0.02), 0.12, 0.0),
                                                 cone(v(0.55, -0.32), v(0.62, -0.02), 0.12, 0.0)]},
    }


def blocked():
    """A red ring with a bar from the upper left to the lower right."""
    return {
        "ring": {"material": "red", "prims": [tor([0, 0, 0], 0.66, 0.13, rot=[1.5708, 0, 0])]},
        "bar": {"material": "red", "prims": [cyl(along(0.6), along(-0.6), 0.12)]},
        "rim": {"material": "gold", "prims": [tor([0, 0, -0.02], 0.82, 0.03, rot=[1.5708, 0, 0])]},
    }


CURSORS = {"pointer": pointer, "command": command, "attack": attack, "break": breaking, "board": board,
           "blocked": blocked}
SUMMARY = {
    "pointer": "a steel gauntlet pointing up-left with its index finger",
    "command": "a spear with a red swallow-tailed pennant, the point up-left",
    "attack": "a sword with a gilt cross-guard, the point up-left",
    "break": "a war hammer with an iron head and a spike",
    "board": "an iron anchor with a wooden stock",
    "blocked": "a red ring with a bar: no way there",
}


def spec(cid, size):
    parts = CURSORS[cid]()
    used = {p["material"] for p in parts.values()}
    for p in parts.values():
        for layer in p.get("paint", []):
            used.add(layer["material"])
    return {
        "spritekiln": 1,
        "name": f"cursor_{cid}_{size}",
        "render": {"outline": "dark", "lines": "depth", "light": "classic", "shading": "toon"},
        "kind": "prop",
        "size": size,
        "directions": ["s"],
        "palette": ["../../palettes/kingdom.yaml"],
        "ramps": {k: v for k, v in RAMPS.items()},
        "camera": {"pitch": 12, "scale": round(SPAN / 30.0 * 32 / size, 5), "center": [0, 0, 0]},
        "shadow": None,
        "brief": {"summary": f"Your Kingdom mouse cursor ({size} px): {SUMMARY[cid]}; bold silhouette, dark outline"},
        "materials": {k: v for k, v in MAT.items() if k in used},
        "channels": {},
        "bones": {},
        "parts": parts,
        "animations": {"idle": {"frames": 1, "ms": 500, "channels": {}}},
    }


def main():
    for cid in sys.argv[1:] or list(CURSORS):
        for size in SIZES:
            name = f"cursor_{cid}_{size}"
            d = os.path.join(PROPS, name)
            os.makedirs(d, exist_ok=True)
            text = yaml.safe_dump(spec(cid, size), sort_keys=False, default_flow_style=None, width=140)
            first, rest = text.split("\n", 1)
            with open(os.path.join(d, name + ".yaml"), "w") as fh:
                fh.write(first + "\n# Generated by tools/spritekiln/gen_cursors.py; edit the script, not this file.\n" + rest)
            print(name)


if __name__ == "__main__":
    main()
