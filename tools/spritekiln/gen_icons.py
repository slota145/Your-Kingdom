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
    "coal": ["#060606", "#121214", "#202024", "#30303a", "#46464e", "#5e5e68"],
    "clay": ["#1c0c06", "#4a2412", "#7a3e20", "#a45a32", "#c47a4c", "#dc9c6c"],
    "redcloth": ["#1c0606", "#4a1210", "#7a1e1a", "#a82824", "#c8463a", "#e07060"],
    "bluecloth": ["#0a0e1c", "#16244c", "#22387a", "#2e54a8", "#4a72c4", "#6e92da"],
    "grape": ["#0c0612", "#26103a", "#3e1a5e", "#5a2a82", "#7a46a4", "#9a6cc4"],
    "leaf": ["#06100a", "#143018", "#225024", "#347032", "#4e9042", "#74b05a"],
    "hide": ["#1a0e06", "#4a2c14", "#7a4e26", "#a2703a", "#c09456", "#d8b47a"],
    "honey": ["#1c0e02", "#5a3006", "#9a5c0c", "#d08e1a", "#eeb83c", "#fadc7a"],
    "hop": ["#0a1206", "#20380e", "#3a5e18", "#5a8424", "#7ea83a", "#a8ca62"],
    "horse": ["#140a06", "#3a1e10", "#5e321c", "#844a2a", "#a4663c", "#c08656"],
    "mane": ["#08060a", "#181216", "#2a2024", "#3c3036", "#504448", "#685c60"],
    "meat": ["#1c0606", "#4e1414", "#86242a", "#b43a3a", "#d46252", "#ec8e76"],
    "bone": ["#1e1a12", "#4e463a", "#86806a", "#b8b29a", "#dcd6c0", "#f4f0e2"],
    "pig": ["#1e0c0c", "#5a2a2c", "#965052", "#c87a78", "#e4a09a", "#f6c6be"],
    "tar": ["#040404", "#0c0c0e", "#16161a", "#222228", "#303038", "#44444e"],
    "wool": ["#1e1c18", "#56524a", "#908a7c", "#c4beae", "#e2ddd0", "#f8f6ee"],
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
    "coal": {"ramp": "coal", "bands": [1, 5], "finish": "glossy"},
    "clay": {"ramp": "clay", "bands": [2, 5]},
    "redcloth": {"ramp": "redcloth", "bands": [2, 5]},
    "bluecloth": {"ramp": "bluecloth", "bands": [2, 5]},
    "grape": {"ramp": "grape", "bands": [2, 5], "finish": "glossy"},
    "leaf": {"ramp": "leaf", "bands": [2, 5]},
    "hide": {"ramp": "hide", "bands": [2, 5]},
    "honey": {"ramp": "honey", "bands": [3, 5], "finish": "glossy"},
    "hop": {"ramp": "hop", "bands": [2, 5]},
    "horse": {"ramp": "horse", "bands": [2, 5]},
    "mane": {"ramp": "mane", "bands": [1, 4]},
    "meat": {"ramp": "meat", "bands": [2, 5], "finish": "soft"},
    "bone": {"ramp": "bone", "bands": [3, 5]},
    "pig": {"ramp": "pig", "bands": [2, 5]},
    "tar": {"ramp": "tar", "bands": [1, 5], "finish": "glossy"},
    "wool": {"ramp": "wool", "bands": [2, 5]},
    "brick": {"ramp": "brick", "bands": [2, 5]},
    "mortar": {"ramp": "stone", "bands": [4, 5], "outline": False, "line": False},
    "rust": {"ramp": "clay", "bands": [2, 4], "outline": False, "line": False},
    "ink": {"ramp": "coal", "bands": [0, 0], "outline": False, "line": False},
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

def rev(c, pts, rot=None):
    d = {"c": c, "profile": {"polygon": pts}}
    if rot:
        d["rot"] = rot
    return {"revolve": d}


def ext(c, pts, depth, rot=None):
    d = {"c": c, "depth": depth, "profile": {"polygon": pts}}
    if rot:
        d["rot"] = rot
    return {"extrude": d}


def sph(c, r):
    return {"sphere": {"c": c, "r": r}}


FLAT = [1.5708, 0, 0]   # an extrude laid flat: the profile on the ground, the depth vertical

ICONS.update({
    "beer": {  # a wooden tankard with a foam head and a handle
        "mug": {"material": "barrel", "prims": [rev([0, 0, 0], [[0, 0], [0.33, 0], [0.36, 0.78], [0, 0.78]])],
                "paint": [{"material": "hoop", "stripes": {"axis": "y", "at": [0.12, 0.66], "width": 0.06}},
                          {"material": "grain_line", "stripes": {"axis": "x", "period": 0.14, "width": 0.03}}]},
        "handle": {"material": "barrel", "prims": [{"torus": {"c": [-0.4, 0.42, 0], "R": 0.2, "r": 0.06, "rot": [1.5708, 0, 0]}}]},
        "foam": {"material": "wool", "prims": [ell([0, 0.8, 0], [0.37, 0.12, 0.37]), sph([0.15, 0.85, 0.1], 0.12)]},
    },
    "mead": {  # a clay jug with a stopper
        "jug": {"material": "clay", "prims": [rev([0, 0, 0], [[0, 0], [0.26, 0], [0.38, 0.3], [0.34, 0.6], [0.16, 0.82],
                                                                [0.16, 0.95], [0, 0.95]])],
                "paint": [{"material": "honey", "stripes": {"axis": "y", "at": [0.45], "width": 0.08}}]},
        "handle": {"material": "clay", "prims": [{"torus": {"c": [-0.28, 0.62, 0], "R": 0.17, "r": 0.05, "rot": [1.5708, 0, 0]}}]},
        "stopper": {"material": "cut", "prims": [cyl([0, 0.93, 0], [0, 1.05, 0], 0.12)]},
    },
    "bow": {  # a longbow lying diagonally, the string straight
        "limb": {"material": "plank", "priority": 2, "prims": [{"tube": {"pts": [[-0.75, 0.06, -0.15], [0, 0.06, 0.42], [0.75, 0.06, -0.15]], "r": 0.05}}]},
        "string": {"material": "linen", "min_cover": 2, "prims": [cyl([-0.73, 0.06, -0.14], [0.73, 0.06, -0.14], 0.018)]},
        "grip": {"material": "grip", "prims": [cyl([-0.08, 0.06, 0.13], [0.08, 0.06, 0.13], 0.07)]},
    },
    "crossbow": {  # a crossbow: stock, bow across the front, string
        "stock": {"material": "plank", "prims": [box([0, 0.08, 0.05], [0.09, 0.07, 0.62])]},
        "bow": {"material": "steel", "priority": 2, "prims": [{"tube": {"pts": [[-0.6, 0.12, 0.35], [0, 0.12, 0.72], [0.6, 0.12, 0.35]], "r": 0.045}}]},
        "string": {"material": "linen", "min_cover": 2, "prims": [cyl([-0.58, 0.12, 0.36], [0, 0.12, 0.18], 0.016),
                                                                  cyl([0.58, 0.12, 0.36], [0, 0.12, 0.18], 0.016)]},
        "trigger": {"material": "iron", "prims": [box([0, -0.02, -0.25], [0.03, 0.08, 0.04])]},
    },
    "spear": {  # a spear lying diagonally: shaft and a leaf-shaped head
        "shaft": {"material": "plank", "priority": 2, "prims": [cyl([-0.85, 0.06, 0], [0.45, 0.06, 0], 0.045)]},
        "head": {"material": "steel", "prims": [ext([0.45, 0.06, 0], [[0, -0.06], [0.2, -0.1], [0.45, 0], [0.2, 0.1], [0, 0.06]], 0.05, FLAT)]},
    },
    "halberd": {  # a halberd: shaft, axe blade, spike and hook
        "shaft": {"material": "plank", "priority": 2, "prims": [cyl([-0.85, 0.06, 0], [0.5, 0.06, 0], 0.045)]},
        "head": {"material": "steel", "prims": [
            ext([0.32, 0.06, 0], [[-0.12, 0], [0.12, 0], [0.18, 0.38], [-0.18, 0.36]], 0.05, FLAT),
            ext([0.32, 0.06, 0], [[-0.06, 0], [0.06, 0], [0.0, -0.18]], 0.05, FLAT),
            ext([0.5, 0.06, 0], [[0, -0.05], [0.32, 0], [0, 0.05]], 0.05, FLAT)]},
    },
    "morning_star": {  # a club with a spiked iron ball
        "shaft": {"material": "plank", "priority": 2, "prims": [cyl([-0.75, 0.1, 0], [0.25, 0.1, 0], 0.06)]},
        "ball": {"material": "iron", "prims": [sph([0.42, 0.18, 0], 0.24)] + [
            {"cone": {"a": [0.42, 0.18, 0], "b": [round(0.42 + 0.38 * math.cos(a) * math.cos(e), 3), round(0.18 + 0.38 * math.sin(e), 3),
                                                  round(0.38 * math.sin(a) * math.cos(e), 3)], "r": [0.07, 0.01]}}
            for a in (0, 1.6, 3.2, 4.8) for e in (-0.5, 0.5)] + [
            {"cone": {"a": [0.42, 0.18, 0], "b": [0.42, 0.58, 0], "r": [0.07, 0.01]}}]},
    },
    "chainmail": {  # armour (zbroja): a steel breastplate with shoulder plates
        "plate": {"material": "steel", "prims": [ell([0, 0.55, 0.0], [0.46, 0.55, 0.3])],
                  "cut": [{"plane": {"n": [0, 0, -1], "at": 0.02}}, {"plane": {"n": [0, 1, 0], "at": 0.98}},
                          {"plane": {"n": [0, -1, 0], "at": -0.06}}],
                  "paint": [{"material": "gold", "stripes": {"axis": "y", "at": [0.12, 0.9], "width": 0.05}},
                            {"material": "ink", "prims": [box([0, 0.55, 0.3], [0.015, 0.4, 0.1])]}]},
        "shoulders": {"material": "steel", "prims": [ell([0.42, 0.88, 0.0], [0.2, 0.12, 0.24]), ell([-0.42, 0.88, 0.0], [0.2, 0.12, 0.24])]},
    },
    "bricks": {  # a small stack of bricks
        "bricks": {"material": "brick", "prims": [box([x, 0.1 + 0.2 * k, z], [0.24, 0.09, 0.12], rnd=0.01)
                                                  for k, row in enumerate([[(-0.26, -0.15), (0.26, -0.15), (-0.26, 0.15), (0.26, 0.15)],
                                                                           [(0.0, -0.15), (0.0, 0.15)]]) for (x, z) in row]},
    },
    "charcoal": {  # a heap of black lumps
        "lumps": {"material": "coal", "prims": [box([x, y, z], [0.2, 0.12, 0.16], rot=[r1, r2, 0], rnd=0.03)
                                                for (x, y, z, r1, r2) in [(-0.3, 0.12, 0.1, 0.1, 0.4), (0.25, 0.12, 0.15, 0.2, -0.3),
                                                                          (0.0, 0.12, -0.25, -0.1, 0.9), (-0.05, 0.33, 0.02, 0.3, 0.2),
                                                                          (0.35, 0.1, -0.25, 0.0, 1.2)]]},
    },
    "clay": {  # a lump of clay, cut flat on top
        "lump": {"material": "clay", "prims": [ell([0, 0.25, 0], [0.55, 0.35, 0.45])],
                 "cut": [{"plane": {"n": [0, 1, 0], "at": 0.42}}, {"plane": {"n": [0, -1, 0], "at": 0.0}}],
                 "paint": [{"material": "rust", "spots": {"scale": 0.12, "density": 0.2, "seed": 2}}]},
    },
    "cloth": {  # a bolt of red cloth, the end unrolled
        "roll": {"material": "redcloth", "prims": [cyl([-0.45, 0.25, -0.1], [0.45, 0.25, -0.1], 0.25)]},
        "flap": {"material": "redcloth", "prims": [box([0.0, 0.03, 0.4], [0.45, 0.025, 0.32])],
                 "paint": [{"material": "gold", "stripes": {"axis": "z", "at": [0.62], "width": 0.05}}]},
    },
    "clothes": {  # a folded blue tunic with a belt
        "tunic": {"material": "bluecloth", "prims": [ext([0, 0.08, 0], [[-0.2, -0.45], [0.2, -0.45], [0.2, 0.15], [0.55, 0.3],
                                                                        [0.5, 0.45], [-0.5, 0.45], [-0.55, 0.3], [-0.2, 0.15]], 0.14, FLAT)]},
        "belt": {"material": "grip", "prims": [box([0, 0.16, -0.05], [0.22, 0.02, 0.05])]},
    },
    "grapes": {  # a bunch of grapes with a leaf
        "berries": {"material": "grape", "prims": [sph([round(0.13 * (i - (3 - k) / 2 * 1.0) * 1.0, 3), round(0.7 - 0.17 * k, 3),
                                                        round(0.06 * ((i + k) % 2), 3)], 0.12)
                                                   for k in range(4) for i in range(4 - k)]},
        "leaf": {"material": "leaf", "prims": [ext([0.18, 0.86, -0.1], [[0, 0], [0.35, 0.1], [0.4, 0.3], [0.15, 0.3]], 0.04, [0.6, 0, 0])]},
        "stem": {"material": "grip", "prims": [cyl([0.0, 0.78, 0], [0.05, 0.95, 0], 0.035)]},
    },
    "hides": {  # a stretched hide, a little curled
        "hide": {"material": "hide", "prims": [ext([0, 0.05, 0], [[-0.6, -0.2], [-0.4, -0.45], [0, -0.35], [0.4, -0.45], [0.62, -0.15],
                                                                  [0.55, 0.25], [0.3, 0.45], [-0.3, 0.42], [-0.55, 0.22]], 0.06, FLAT)],
                 "paint": [{"material": "grain_line", "spots": {"scale": 0.1, "density": 0.15, "seed": 6}}]},
    },
    "honey": {  # a clay honey pot, honey dripping over the rim
        "pot": {"material": "clay", "prims": [rev([0, 0, 0], [[0, 0], [0.3, 0], [0.42, 0.3], [0.36, 0.62], [0.3, 0.66], [0, 0.66]])]},
        "honey": {"material": "honey", "prims": [ell([0, 0.66, 0], [0.31, 0.05, 0.31]), ell([0.2, 0.55, 0.25], [0.07, 0.14, 0.07]),
                                                 ell([-0.12, 0.58, 0.3], [0.06, 0.1, 0.06])]},
    },
    "hops": {  # three hop cones and a leaf
        "cones": {"material": "hop", "prims": [ell([-0.25, 0.25, 0.05], [0.17, 0.27, 0.17]), ell([0.2, 0.25, 0.12], [0.17, 0.27, 0.17]),
                                               ell([-0.02, 0.42, -0.2], [0.16, 0.25, 0.16])],
                  "paint": [{"material": "leaf", "stripes": {"axis": "y", "period": 0.09, "width": 0.03}}]},
        "leaf": {"material": "leaf", "prims": [ext([0.1, 0.62, -0.25], [[0, 0], [0.35, 0.05], [0.4, 0.3], [0.1, 0.3]], 0.04, [0.5, 0, 0])]},
    },
    "horse": {  # a horse standing, side on
        "body": {"material": "horse", "prims": [ell([0, 0.62, 0], [0.48, 0.22, 0.2]),
                                                {"cone": {"a": [0.35, 0.68, 0], "b": [0.55, 0.98, 0], "r": [0.14, 0.09]}},
                                                ell([0.66, 0.96, 0], [0.16, 0.08, 0.08], rot=[0, 0, -0.5])],
                 "paint": [{"material": "mane", "prims": [box([0.5, 0.06, 0], [0.4, 0.4, 0.3])]}]},
        "legs": {"material": "horse", "prims": [cyl([x, 0.55, z], [x, 0.02, z], 0.05) for x in (-0.36, 0.32) for z in (-0.1, 0.1)]},
        "mane": {"material": "mane", "prims": [{"tube": {"pts": [[0.35, 0.86, 0], [0.48, 1.02, 0], [0.6, 1.08, 0]], "r": 0.05}},
                                               {"tube": {"pts": [[-0.46, 0.7, 0], [-0.6, 0.5, 0], [-0.58, 0.3, 0]], "r": 0.06}}]},
    },
    "iron_ore": {  # rocks with rust-red streaks
        "rocks": {"material": "stone", "prims": [box([-0.18, 0.22, 0.05], [0.33, 0.22, 0.28], rot=[0.1, 0.4, 0.05], rnd=0.06),
                                                 box([0.35, 0.14, 0.25], [0.2, 0.14, 0.17], rot=[0.0, -0.3, 0.1], rnd=0.05)],
                  "paint": [{"material": "rust", "spots": {"scale": 0.09, "density": 0.4, "seed": 9}}]},
    },
    "meat": {  # a leg of ham with the bone
        "ham": {"material": "meat", "prims": [ell([-0.1, 0.3, 0], [0.48, 0.3, 0.32], rot=[0, 0, 0.2])],
                "paint": [{"material": "bone", "prims": [ell([-0.55, 0.38, 0], [0.12, 0.3, 0.3])]}]},
        "bone": {"material": "bone", "prims": [cyl([0.3, 0.38, 0], [0.62, 0.48, 0], 0.07), sph([0.66, 0.5, 0.05], 0.09), sph([0.66, 0.5, -0.05], 0.09)]},
    },
    "pig": {  # a pig standing, side on
        "body": {"material": "pig", "prims": [ell([0, 0.42, 0], [0.48, 0.27, 0.27]), ell([0.45, 0.48, 0], [0.18, 0.17, 0.17]),
                                              cyl([0.58, 0.46, 0], [0.68, 0.45, 0], 0.08)]},
        "ears": {"material": "pig", "prims": [ell([0.45, 0.66, 0.1], [0.06, 0.08, 0.04], rot=[0.5, 0, -0.4]),
                                              ell([0.45, 0.66, -0.1], [0.06, 0.08, 0.04], rot=[-0.5, 0, -0.4])]},
        "legs": {"material": "pig", "prims": [cyl([x, 0.3, z], [x, 0.0, z], 0.06) for x in (-0.3, 0.28) for z in (-0.13, 0.13)]},
        "tail": {"material": "pig", "prims": [{"torus": {"c": [-0.5, 0.52, 0], "R": 0.06, "r": 0.02, "rot": [1.5708, 0, 0]}}]},
        "eye": {"material": "eye", "prims": [sph([0.55, 0.55, 0.13], 0.03), sph([0.55, 0.55, -0.13], 0.03)]},
    },
    "tar": {  # a barrel of tar, black tar running down
        "barrel": {"material": "barrel", "prims": [rev([0, 0, 0], [[0, 0], [0.36, 0], [0.45, 0.25], [0.47, 0.45], [0.45, 0.65], [0.36, 0.9], [0, 0.9]])],
                   "paint": [{"material": "hoop", "stripes": {"axis": "y", "at": [0.12, 0.3, 0.6, 0.78], "width": 0.05}},
                             {"material": "tar", "prims": [ell([0, 0.9, 0], [0.3, 0.05, 0.3]), box([0.3, 0.7, 0.3], [0.08, 0.25, 0.08])]}]},
    },
    "wool": {  # a fluffy heap of fleece
        "fleece": {"material": "wool", "prims": [sph([x, y, z], r) for (x, y, z, r) in
                                                 [(-0.3, 0.2, 0.05, 0.24), (0.05, 0.22, 0.15, 0.26), (0.35, 0.18, -0.05, 0.22),
                                                  (-0.05, 0.2, -0.25, 0.22), (0.0, 0.42, -0.02, 0.22), (-0.25, 0.36, -0.15, 0.17)]]},
    },
})


SCALE = {"crossbow": 0.046, "clothes": 0.05, "honey": 0.052, "sword": 0.048, "spear": 0.052, "halberd": 0.054, "morning_star": 0.05}
CENTER_X = {"sword": 0.1}
CENTER_Y = {"grain": 0.55, "beer": 0.45, "mead": 0.5, "horse": 0.55, "chainmail": 0.5, "grapes": 0.5, "honey": 0.4,
            "tar": 0.45, "wine": 0.45, "hops": 0.35}


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
        "camera": {"pitch": 35, "scale": SCALE.get(good, 0.058),
                   "center": [CENTER_X.get(good, 0), CENTER_Y.get(good, 0.35), 0]},
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
