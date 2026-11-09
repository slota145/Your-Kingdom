"""SpriteKiln trial: goods icons (ART_SPEC 3.1: 32x32, the ship slots, the goods lists, the storehouse).

Writes art/specs/props/icon_<good>/icon_<good>.yaml: a small model in one 3/4 view (yaw 45, pitch 35),
32x32, the same dark outline and toon shading as the buildings. Compare: compose_icons.py.

Run: python3 tools/spritekiln/gen_icons.py [good ...]
"""
import math
import os
import sys

import yaml

HERE = os.path.dirname(os.path.abspath(__file__))
PROPS = os.path.join(HERE, "art", "specs", "props")

RAMPS = {
    "bark": ["#140a05", "#33200f", "#55361a", "#76502a", "#946a3a", "#b0884e"],
    "cut": ["#2a1a0c", "#6a4a26", "#a07440", "#c8995a", "#e2bc80", "#f4dcaa"],
    "crust": ["#1e0c04", "#4e2410", "#84421c", "#b0662c", "#d08c44", "#e8b468"],
    "fishskin": ["#0c1218", "#26384a", "#466078", "#6e8ca4", "#9cb8cc", "#d0e2ee"],
    "straw": ["#1e1404", "#4e3a10", "#866618", "#b89028", "#dcb84a", "#f4dc86"],
    "linen": ["#1a1712", "#4a443a", "#7e7666", "#b4aa94", "#d6cdb6", "#f2ecdc"],
    "iron": ["#0c0e12", "#24282e", "#3e444c", "#5c646e", "#848e98", "#b8c2cc"],
    "barrel": ["#160a06", "#3c1c0e", "#643218", "#8a4a24", "#ac6634", "#c8864c"],
    "winered": ["#120408", "#3a0c18", "#641428", "#8c2038", "#b03a50", "#d0647a"],
    "rope": ["#0e0a06", "#3a2a18", "#6a5032", "#94744c"],
    "gold": ["#1c1006", "#4d2f0e", "#8a5a16", "#c48c22", "#e8c04e", "#fff0a0"],
}

MAT = {
    "bark": {"ramp": "bark", "bands": [2, 5]},
    "cut": {"ramp": "cut", "bands": [2, 5]},
    "ring": {"ramp": "cut", "bands": [1, 2], "outline": False, "line": False},
    "plank": {"ramp": "wood", "bands": [2, 5]},
    "grain_line": {"ramp": "wood", "bands": [1, 2], "outline": False, "line": False},
    "stone": {"ramp": "stone", "bands": [2, 5]},
    "crust": {"ramp": "crust", "bands": [2, 5], "finish": "soft"},
    "score": {"ramp": "cut", "bands": [3, 4], "outline": False, "line": False},
    "fish": {"ramp": "fishskin", "bands": [2, 5], "finish": "glossy"},
    "fin": {"ramp": "fishskin", "bands": [1, 3]},
    "eye": {"ramp": "iron", "bands": [0, 0], "outline": False},
    "straw": {"ramp": "straw", "bands": [2, 5]},
    "linen": {"ramp": "linen", "bands": [2, 5]},
    "rope": {"ramp": "rope", "bands": [1, 3]},
    "iron": {"ramp": "iron", "bands": [2, 5], "finish": "metal"},
    "steel": {"ramp": "steel", "bands": [2, 5], "finish": "metal"},
    "barrel": {"ramp": "barrel", "bands": [2, 5]},
    "hoop": {"ramp": "iron", "bands": [1, 3], "outline": False},
    "wine": {"ramp": "winered", "bands": [2, 4]},
    "gold": {"ramp": "gold", "bands": [2, 5], "finish": "metal"},
    "grip": {"ramp": "bark", "bands": [1, 3]},
}


def cyl(a, b, r):
    return {"cylinder": {"a": a, "b": b, "r": r}}


def box(c, h, rot=None, rnd=0.0):
    d = {"c": c, "half": h}
    if rot:
        d["rot"] = rot
    if rnd:
        d["round"] = rnd
    return {"box": d}


def ell(c, r, rot=None):
    d = {"c": c, "r": r}
    if rot:
        d["rot"] = rot
    return {"ellipsoid": d}


ICONS = {
    "wood": {  # a log with a cut end showing the rings
        "log": {"material": "bark", "prims": [cyl([0.7, 0.3, 0], [-0.62, 0.3, 0], 0.3)]},
        "end": {"material": "cut", "prims": [cyl([-0.6, 0.3, 0], [-0.68, 0.3, 0], 0.29)],   # faces the camera
                "paint": [{"material": "ring", "rings": {"axis": "x", "period": 0.11, "width": 0.04}}]},
    },
    "planks": {  # three boards, the top one turned a little
        "boards": {"material": "plank", "prims": [box([0, 0.06, 0.2], [0.75, 0.06, 0.17]),
                                                   box([0, 0.06, -0.2], [0.75, 0.06, 0.17]),
                                                   box([0.02, 0.19, 0.0], [0.75, 0.06, 0.17], rot=[0, 0.12, 0])],
                   "paint": [{"material": "grain_line", "stripes": {"axis": "z", "period": 0.12, "width": 0.03}}]},
    },
    "stone": {  # a dressed block and a smaller rough stone
        "block": {"material": "stone", "prims": [box([0.05, 0.3, 0], [0.48, 0.3, 0.4], rnd=0.05)],
                  "paint": [{"material": "ring", "spots": {"scale": 0.12, "density": 0.15, "seed": 4}}]},
        "chip": {"material": "stone", "prims": [box([-0.62, 0.13, 0.55], [0.16, 0.13, 0.15], rot=[0.15, 0.6, 0.1], rnd=0.04)]},
    },
    "bread": {  # a round loaf with three scores
        "loaf": {"material": "crust", "prims": [ell([0, 0.32, 0], [0.62, 0.36, 0.5])],
                 "cut": [{"plane": {"n": [0, -1, 0], "at": -0.02}}],
                 "paint": [{"material": "score", "prims": [box([x, 0.66, 0], [0.04, 0.2, 0.32], rot=[0, 0, 0.3])
                                                            for x in (-0.25, 0.0, 0.25)]}]},
    },
    "fish": {  # a fish lying on its side
        "body": {"material": "fish", "prims": [ell([0, 0.25, 0], [0.62, 0.25, 0.18])]},
        "tail": {"material": "fin", "prims": [{"extrude": {"c": [-0.62, 0.25, 0], "depth": 0.06,
                                                           "profile": {"polygon": [[0.1, 0], [-0.3, 0.26], [-0.22, 0], [-0.3, -0.26]]}}}]},
        "fin": {"material": "fin", "prims": [{"extrude": {"c": [0.0, 0.46, 0], "depth": 0.05,
                                                          "profile": {"polygon": [[-0.25, 0], [0.18, 0], [-0.1, 0.14]]}}}]},
        "eye": {"material": "eye", "prims": [{"sphere": {"c": [0.42, 0.31, 0.12], "r": 0.05}},
                                             {"sphere": {"c": [0.42, 0.31, -0.12], "r": 0.05}}]},
    },
    "grain": {  # a sheaf: stalks bound in the middle, ears at the top
        "stalks": {"material": "straw", "prims": [cyl([0.12 * math.cos(a), 0.0, 0.12 * math.sin(a)],
                                                      [0.3 * math.cos(a), 1.05, 0.3 * math.sin(a)], 0.06)
                                                  for a in [k * 0.9 for k in range(7)]]},
        "ears": {"material": "straw", "prims": [ell([0.32 * math.cos(a), 1.12, 0.32 * math.sin(a)], [0.08, 0.18, 0.08])
                                                for a in [k * 0.9 for k in range(7)]] + [ell([0, 1.2, 0], [0.09, 0.2, 0.09])]},
        "band": {"material": "rope", "prims": [cyl([0, 0.42, 0], [0, 0.52, 0], 0.22)]},
    },
    "flour": {  # a sack tied at the top
        "sack": {"material": "linen", "prims": [ell([0, 0.42, 0], [0.45, 0.45, 0.4]),
                                                {"cone": {"a": [0, 0.75, 0], "b": [0, 1.02, 0], "r": [0.2, 0.08]}}]},
        "tie": {"material": "rope", "prims": [cyl([0, 0.86, 0], [0, 0.93, 0], 0.13)]},
        "spill": {"material": "linen", "prims": [ell([0.45, 0.04, 0.35], [0.22, 0.05, 0.18])]},
    },
    "iron": {  # two bars, one on the other
        "bars": {"material": "iron", "prims": [
            {"extrude": {"c": [0, 0.0, 0.18], "rot": [0, 0, 0], "depth": 0.3,
                         "profile": {"polygon": [[-0.62, 0], [0.62, 0], [0.52, 0.2], [-0.52, 0.2]]}}},
            {"extrude": {"c": [0.02, 0.21, -0.08], "rot": [0, 0.15, 0], "depth": 0.3,
                         "profile": {"polygon": [[-0.62, 0], [0.62, 0], [0.52, 0.2], [-0.52, 0.2]]}}}]},
    },
    "wine": {  # a small barrel standing up, a red stain at the bung
        "barrel": {"material": "barrel", "prims": [{"revolve": {"c": [0, 0, 0], "profile": {
            "polygon": [[0, 0], [0.36, 0], [0.45, 0.25], [0.47, 0.45], [0.45, 0.65], [0.36, 0.9], [0, 0.9]]}}}],
            "paint": [{"material": "grain_line", "stripes": {"axis": "x", "period": 0.14, "width": 0.03}},
                      {"material": "hoop", "stripes": {"axis": "y", "at": [0.12, 0.3, 0.6, 0.78], "width": 0.05}},
                      {"material": "wine", "prims": [ell([0, 0.9, 0], [0.22, 0.04, 0.22])]}]},
    },
    "sword": {  # a sword lying diagonally
        "blade": {"material": "steel", "prims": [{"extrude": {"c": [0.1, 0.06, 0], "rot": [1.5708, 0, 0], "depth": 0.06,
                                                              "profile": {"polygon": [[-0.35, -0.1], [0.75, -0.08], [0.9, 0], [0.75, 0.08], [-0.35, 0.1]]}}}]},
        "guard": {"material": "gold", "prims": [box([-0.27, 0.07, 0], [0.04, 0.05, 0.22])]},
        "grip": {"material": "grip", "prims": [cyl([-0.3, 0.07, 0], [-0.58, 0.07, 0], 0.045)]},
        "pommel": {"material": "gold", "prims": [{"sphere": {"c": [-0.62, 0.07, 0], "r": 0.07}}]},
    },
}


def spec(good):
    parts = ICONS[good]
    used = {p["material"] for p in parts.values()}
    for p in parts.values():
        for layer in p.get("paint", []):
            used.add(layer["material"])
    return {
        "spritekiln": 1,
        "name": f"icon_{good}",
        "render": {"outline": "dark", "lines": "depth", "light": "classic", "shading": "toon"},
        "kind": "prop",
        "size": 32,
        "directions": ["se"],
        "palette": ["../../palettes/kingdom.yaml", "../../palettes/town.yaml"],
        "ramps": {k: v for k, v in RAMPS.items()},
        "camera": {"pitch": 35, "scale": 0.048 if good == "sword" else 0.058,
                   "center": [0.1 if good == "sword" else 0, 0.35 if good not in ("grain",) else 0.55, 0]},
        "shadow": None,
        "brief": {"summary": f"Your Kingdom goods icon: {good}, 32x32, one 3/4 view, bold silhouette for the UI"},
        "materials": {k: v for k, v in MAT.items() if k in used},
        "channels": {},
        "bones": {},
        "parts": parts,
        "animations": {"idle": {"frames": 1, "ms": 500, "channels": {}}},
    }


def main():
    for g in sys.argv[1:] or list(ICONS):
        d = os.path.join(PROPS, f"icon_{g}")
        os.makedirs(d, exist_ok=True)
        text = yaml.safe_dump(spec(g), sort_keys=False, default_flow_style=None, width=140)
        first, rest = text.split("\n", 1)
        with open(os.path.join(d, f"icon_{g}.yaml"), "w") as fh:
            fh.write(first + "\n# Generated by tools/spritekiln/gen_icons.py; edit the script, not this file.\n" + rest)
        print(g)


if __name__ == "__main__":
    main()
