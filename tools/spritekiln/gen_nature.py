"""SpriteKiln trial (owner 2026-11-10): trees, rocks and a pig with animations.

Writes art/specs/props/<name>/<name>.yaml:
  tree_grown, tree_felled, tree_stump, rock_grown, rock_felled, rock_stump: one view (se), frame 96x96
    rendered and cut to the game's 64x96 with the tile centre at (32, 80) (ART_SPEC 8: natural objects);
  pig: 8 directions, animations idle (breathing, tail, ears), walk (diagonal leg pairs) and root
    (snout in the ground), frame 32.
Run: python3 tools/spritekiln/gen_nature.py [name ...], render each, then compose_nature.py
"""
import math
import os
import random
import sys

import yaml

HERE = os.path.dirname(os.path.abspath(__file__))
PROPS = os.path.join(HERE, "art", "specs", "props")
K = 0.05176

RAMPS = {
    "bark": ["#140a05", "#33200f", "#4a2e18", "#5e3c20", "#76502c", "#8e643a"],
    "cut": ["#2a1a0c", "#6a4a26", "#a07440", "#c8995a", "#e2bc80", "#f4dcaa"],
    "leaf": ["#06100a", "#16301a", "#244a26", "#346432", "#4a8040", "#6a9e52"],
    "leaf_hi": ["#16301a", "#346432", "#4a8040", "#6a9e52", "#8cba66", "#b0d47e"],
    "leaf_pale": ["#24401c", "#4a7a32", "#6a9e48", "#8cba60", "#acd27a", "#c8e49a"],
    "needle": ["#060e0a", "#102a1c", "#1a3e28", "#255234", "#326a42", "#448252"],
    "needle_hi": ["#102a1c", "#255234", "#326a42", "#448252", "#5a9a62", "#76b07a"],
    "needle_light": ["#0e1a06", "#2a4410", "#44641c", "#5e8228", "#7a9e36", "#98b84a"],
    "needle_light_hi": ["#2a4410", "#5e8228", "#7a9e36", "#98b84a", "#b4cc64", "#cce082"],
    "tuft": ["#0c1408", "#24401a", "#3a5e26", "#527a34", "#6c9444", "#8aae58"],
    "rock": ["#121110", "#3a3834", "#56534c", "#747068", "#948f84", "#b4afa2"],
    "moss": ["#0c1408", "#24401a", "#3a5e26", "#527a34", "#6c9444", "#8aae58"],
    "pig": ["#1e0c0c", "#5a2a2c", "#965052", "#c87a78", "#e4a09a", "#f6c6be"],
    "pig_dark": ["#1e0c0c", "#4a2224", "#7a3e40", "#a05a5a", "#c07874", "#d89892"],
    "eye": ["#0a0606", "#1a1010", "#2a1a1a", "#3a2424"],
    "dirt": ["#1a120b", "#3e2e1e", "#5e4630", "#7c6043", "#9a7c58"],
}
MAT = {
    "bark": {"ramp": "bark", "bands": [2, 5]},
    "bark_dark": {"ramp": "bark", "bands": [1, 2], "outline": False, "line": False},
    "bark_hi": {"ramp": "bark", "bands": [4, 5], "outline": False, "line": False},
    "needle": {"ramp": "needle", "bands": [2, 5]},
    "needle_dark": {"ramp": "needle", "bands": [1, 2], "outline": False, "line": False},
    "needle_hi": {"ramp": "needle_hi", "bands": [3, 5], "outline": False, "line": False},
    "tuft": {"ramp": "tuft", "bands": [2, 4]},
    "cut": {"ramp": "cut", "bands": [2, 5]},
    "ring": {"ramp": "cut", "bands": [1, 2], "outline": False, "line": False},
    "leaf": {"ramp": "leaf", "bands": [1, 5]},
    "leaf_hi": {"ramp": "leaf_hi", "bands": [3, 5], "outline": False, "line": False},
    "leaf_dark": {"ramp": "leaf", "bands": [1, 2], "outline": False, "line": False},
    "rock": {"ramp": "rock", "bands": [1, 5]},
    "rock_dark": {"ramp": "rock", "bands": [1, 3], "outline": False, "line": False},
    "crack": {"ramp": "rock", "bands": [0, 1], "outline": False, "line": False},
    "moss": {"ramp": "moss", "bands": [2, 3], "outline": False, "line": False},
    "pig": {"ramp": "pig", "bands": [2, 5], "finish": "soft"},
    "pig_dark": {"ramp": "pig_dark", "bands": [2, 4]},
    "eye": {"ramp": "eye", "bands": [0, 1], "outline": False},
    "dirt": {"ramp": "dirt", "bands": [2, 4], "outline": False, "line": False},
}


def r3(v):
    return [round(float(x), 3) for x in v] if isinstance(v, (list, tuple)) else round(float(v), 3)


def crown(rng, cx, cy, cz, scale=1.0):
    """A natural crown: clumps of different sizes on an uneven dome (not a ball), gaps between them,
    small leaf spots (lighter where the light falls, darker hollows)."""
    prims = []
    for k in range(24):
        a = k * 2.399 + rng.uniform(-0.3, 0.3)            # golden-angle spread round the trunk
        e = rng.uniform(-0.35, 1.0)                      # from the lower rim to the top
        rad = 1.0 * math.cos(e * 0.9) * rng.uniform(0.75, 1.05)
        x = cx + scale * rad * math.cos(a) * (1.1 if math.cos(a) > 0 else 0.95)   # a little lopsided
        z = cz + scale * rad * math.sin(a)
        y = cy + scale * (0.75 * math.sin(e * 1.2) + rng.uniform(-0.08, 0.08))
        r = scale * rng.uniform(0.24, 0.46)
        prims.append({"ellipsoid": {"c": r3([x, y, z]), "r": r3([r, r * 0.82, r]), "rot": r3([0, rng.uniform(0, 3), 0])}})
    for k in range(4):   # the inner bulk, so no daylight through the middle
        prims.append({"ellipsoid": {"c": r3([cx + scale * rng.uniform(-0.3, 0.3), cy + scale * rng.uniform(-0.1, 0.4),
                                             cz + scale * rng.uniform(-0.3, 0.3)]), "r": r3([0.55 * scale, 0.45 * scale, 0.55 * scale])}})
    return {"material": "leaf", "blend": 0.05, "priority": 1, "prims": prims,
            "paint": [{"material": "leaf_dark", "spots": {"scale": 0.06, "density": 0.32, "seed": 3}},
                      {"material": "leaf_hi", "spots": {"scale": 0.05, "density": 0.26, "seed": 4}}]}


def r3p(pts):
    return [r3(p) for p in pts]


def shift(prim, dx, dz):
    """A primitive moved in x and z (its points and centre)."""
    (kind, d), = prim.items()
    d = dict(d)
    for key in ("a", "b", "c"):
        if key in d:
            d[key] = r3([d[key][0] + dx, d[key][1], d[key][2] + dz])
    if "pts" in d:
        d["pts"] = [r3([p[0] + dx, p[1], p[2] + dz]) for p in d["pts"]]
    return {kind: d}


def tree(state):
    rng = random.Random(5)
    parts = {}
    stump = {"material": "bark", "prims": [{"cylinder": {"a": [0, 0, 0], "b": [0, 0.3, 0], "r": 0.2}}] +
             [{"tube": {"pts": r3p([[0.15 * math.cos(a), 0.1, 0.15 * math.sin(a)], [0.3 * math.cos(a), 0.04, 0.3 * math.sin(a)],
                                    [0.42 * math.cos(a), 0.0, 0.42 * math.sin(a)]]), "r": [0.06, 0.02]}} for a in (0.4, 2.3, 4.2)]}
    if state == "stump":
        parts["stump"] = stump
        parts["top"] = {"material": "cut", "prims": [{"cylinder": {"a": [0, 0.29, 0], "b": [0, 0.32, 0], "r": 0.19}}],
                        "paint": [{"material": "ring", "rings": {"axis": "y", "period": 0.07, "width": 0.03}}]}
        return parts, 0.5
    if state == "grown":
        parts["trunk"] = {"material": "bark", "blend": 0.06, "prims": [
            {"tube": {"pts": [[0, 0, 0], [0.05, 0.9, 0.03], [-0.06, 1.7, -0.02], [0.04, 2.5, 0.0]], "r": [0.21, 0.1]}},
            {"tube": {"pts": [[0.02, 1.55, 0], [0.4, 2.0, 0.15], [0.7, 2.55, 0.2]], "r": [0.08, 0.035]}},
            {"tube": {"pts": [[-0.03, 1.75, 0], [-0.35, 2.15, -0.15], [-0.62, 2.7, -0.12]], "r": [0.07, 0.03]}},
            {"tube": {"pts": [[0.0, 2.0, 0], [0.1, 2.4, -0.45], [0.15, 2.9, -0.6]], "r": [0.06, 0.03]}}] +
            stump["prims"][1:],
            "paint": [{"material": "bark_dark", "stripes": {"axis": "x", "period": 0.09, "width": 0.025}}]}
        parts["crown"] = crown(rng, 0.03, 3.1, -0.05)
        return parts, 1.91
    # felled: the trunk lies on the ground towards the upper right, the crown at its end, the stump behind
    parts["stump"] = stump
    parts["top"] = {"material": "cut", "prims": [{"cylinder": {"a": [0, 0.3, 0], "b": [0, 0.34, 0], "r": 0.19}}],
                    "paint": [{"material": "ring", "rings": {"axis": "y", "period": 0.06, "width": 0.04}}]}
    parts["log"] = {"material": "bark", "prims": [{"cone": {"a": [0.35, 0.2, 0.15], "b": [0.15, 0.15, -1.15], "r": [0.19, 0.12]}}],
                    "paint": [{"material": "bark_dark", "stripes": {"axis": "z", "period": 0.09, "width": 0.025}}]}
    parts["log_end"] = {"material": "cut", "prims": [{"cylinder": {"a": [0.36, 0.2, 0.2], "b": [0.355, 0.2, 0.16], "r": 0.18}}]}
    parts["crown"] = crown(rng, 0.1, 0.5, -1.65, scale=0.55)
    for p_ in parts.values():   # the stump a little to the right of the tile centre
        p_["prims"] = [shift(pr, 0.25, 0.25) for pr in p_["prims"]]
    return parts, 0.9


def rock(state):
    rng = random.Random({"grown": 11, "felled": 12, "stump": 13}[state])
    if state == "grown":
        masses = [([0.0, 0.55, -0.15], [0.62, 0.62, 0.55]), ([0.55, 0.4, 0.35], [0.45, 0.42, 0.4]),
                  ([-0.5, 0.32, 0.4], [0.42, 0.34, 0.38]), ([0.1, 0.95, -0.05], [0.4, 0.32, 0.36]),
                  ([0.15, 0.2, 0.75], [0.25, 0.2, 0.22])]
    elif state == "felled":
        masses = [([0.15, 0.32, 0.05], [0.48, 0.38, 0.42]), ([-0.4, 0.22, 0.45], [0.34, 0.26, 0.3]),
                  ([0.45, 0.15, 0.6], [0.2, 0.16, 0.18])]
    else:   # rubble
        masses = [([rng.uniform(-0.7, 0.7), 0.08, rng.uniform(-0.6, 0.7)], [rng.uniform(0.1, 0.2), 0.1, rng.uniform(0.08, 0.16)])
                  for _ in range(9)]
    prims = [{"box": {"c": r3(c), "half": r3(h), "round": r3(min(h) * 0.55),
                      "rot": r3([rng.uniform(-0.35, 0.35), rng.uniform(0, 3.1), rng.uniform(-0.3, 0.3)])}} for c, h in masses]
    cracks = [{"box": {"c": r3([rng.uniform(-0.4, 0.4), rng.uniform(0.3, 0.8), rng.uniform(-0.4, 0.4)]),
                       "half": [0.9, 0.012, 0.012], "rot": r3([rng.uniform(-1, 1), rng.uniform(0, 3), rng.uniform(-0.6, 0.6)])}}
              for _ in range(3 if state == "grown" else 1)] if state != "stump" else []
    parts = {"rock": {"material": "rock", "blend": 0.07, "prims": prims,
                      "cut": [{"plane": {"n": [0, -1, 0], "at": 0.0}}] + cracks,
                      "cut_blend": {"mode": "groove", "depth": 0.03, "width": 0.015},
                      "paint": [{"material": "rock_dark", "spots": {"scale": 0.1, "density": 0.25, "seed": 5}},
                                {"material": "moss", "spots": {"scale": 0.07, "density": 0.12, "seed": 8}}]}}
    return parts, 0.9


def pig():
    """A pig on four legs; bones for the body, head, ears, tail and each leg (channels drive them)."""
    bones = {
        "body": {"parent": "root", "pos": "[0, 0.31 + bob, 0]", "rot": "[pitch, 0, roll]", "scale": 0.85},
        "head": {"parent": "body", "pos": [0, 0.04, 0.42], "rot": "[head_pitch, head_yaw, 0]"},
        "tail": {"parent": "body", "pos": [0, 0.08, -0.45], "rot": "[0, tail, 0]"},
    }
    legs = {"fl": (0.13, 0.27, "swing_a"), "br": (-0.13, -0.27, "swing_a"), "fr": (-0.13, 0.27, "swing_b"),
            "bl": (0.13, -0.27, "swing_b")}
    parts = {
        "body": {"material": "pig", "space": "body", "prims": [{"ellipsoid": {"c": [0, 0, 0], "r": [0.24, 0.22, 0.45]}}]},
        "head": {"material": "pig", "space": "head", "prims": [
            {"ellipsoid": {"c": [0, 0.02, 0.06], "r": [0.17, 0.16, 0.17]}},
            {"cylinder": {"a": [0, -0.02, 0.18], "b": [0, -0.03, 0.29], "r": 0.08}}]},
        "snout": {"material": "pig_dark", "space": "head", "prims": [
            {"cylinder": {"a": [0, -0.03, 0.28], "b": [0, -0.03, 0.3], "r": 0.075}}]},
        "ears": {"material": "pig_dark", "space": "head", "prims": [
            {"ellipsoid": {"c": [0.11, 0.17, 0.02], "r": [0.06, 0.03, 0.07], "rot": "[0.5 + ear, 0, -0.5]"}},
            {"ellipsoid": {"c": [-0.11, 0.17, 0.02], "r": [0.06, 0.03, 0.07], "rot": "[0.5 + ear, 0, 0.5]"}}]},
        "eyes": {"material": "eye", "space": "head", "min_cover": 1, "prims": [
            {"sphere": {"c": [0.09, 0.08, 0.17], "r": 0.025}}, {"sphere": {"c": [-0.09, 0.08, 0.17], "r": 0.025}}]},
        "tail": {"material": "pig", "space": "tail", "min_cover": 2, "prims": [
            {"torus": {"c": [0, 0.04, -0.04], "R": 0.045, "r": 0.018, "rot": [1.2, 0, 0]}}]},
    }
    for name, (x, z, ch) in legs.items():
        bones[f"leg_{name}"] = {"parent": "body", "pos": r3([x, -0.12, z]), "rot": f"[{ch}, 0, 0]"}
        parts[f"leg_{name}"] = {"material": "pig", "space": f"leg_{name}", "prims": [
            {"cone": {"a": [0, 0, 0], "b": [0, -0.26, 0], "r": [0.07, 0.05]}}]}
        parts[f"hoof_{name}"] = {"material": "pig_dark", "space": f"leg_{name}", "prims": [
            {"cylinder": {"a": [0, -0.25, 0], "b": [0, -0.29, 0], "r": 0.05}}]}
    channels = {"bob": 0.0, "pitch": 0.0, "roll": 0.0, "head_pitch": 0.0, "head_yaw": 0.0, "tail": 0.0, "ear": 0.0,
                "swing_a": 0.0, "swing_b": 0.0}
    anims = {
        "idle": {"frames": 8, "ms": 150, "channels": {
            "bob": "0.012*sin(p)", "tail": "0.6*sin(2*p)", "ear": "0.25*pulse(t, 0.6, 0.15)", "head_pitch": "0.05*sin(p)"}},
        "walk": {"frames": 8, "ms": 95, "events": {0: "step", 4: "step"}, "channels": {
            "swing_a": "0.5*sin(p)", "swing_b": "-0.5*sin(p)", "bob": "0.018*abs(sin(p))", "roll": "0.04*sin(p)",
            "head_pitch": "0.06*sin(2*p)", "tail": "0.4*sin(p)", "ear": "0.15*sin(2*p)"}},
        "root": {"frames": 8, "ms": 130, "channels": {
            "head_pitch": "0.55 + 0.08*sin(2*p)", "head_yaw": "0.2*sin(p)", "pitch": "0.12", "bob": "-0.02",
            "tail": "0.5*sin(2*p)", "ear": "0.2*sin(p)"}},
    }
    return bones, parts, channels, anims


def clump(rng, c, r, n_bumps=7):
    """One cloud of leaves: a body and small bumps on its outline (a fluffy edge, not a ball)."""
    prims = [{"ellipsoid": {"c": r3(c), "r": r3([r, r * 0.8, r])}}]
    for k in range(n_bumps):
        a = k * math.tau / n_bumps + rng.uniform(-0.3, 0.3)
        e = rng.uniform(-0.2, 0.9)
        rb = r * rng.uniform(0.3, 0.42)
        prims.append({"sphere": {"c": r3([c[0] + r * 0.85 * math.cos(a) * math.cos(e), c[1] + r * 0.7 * math.sin(e),
                                          c[2] + r * 0.85 * math.sin(a) * math.cos(e)]), "r": r3(rb)}})
    return prims


def leafy(variant):
    """Deciduous trees after the owner's oak reference: a thick trunk with bark plates and a root flare,
    two big limbs showing under the crown, a wide crown of big leaf clouds, each its own part so a dark
    line runs between them. a = oak (wide), b = linden (rounder, lighter)."""
    rng = random.Random(21 if variant == "a" else 22)
    wide = 1.0 if variant == "a" else 0.82
    parts = {"trunk": {"material": "bark", "blend": 0.08, "prims": [
        {"tube": {"pts": [[0, 0, 0], [0.04, 0.8, 0.02], [-0.03, 1.5, 0.0]], "r": [0.3, 0.2]}},
        {"tube": {"pts": [[-0.02, 1.35, 0], [-0.55 * wide, 1.85, 0.15], [-1.0 * wide, 2.15, 0.25]], "r": [0.13, 0.05]}},
        {"tube": {"pts": [[0.0, 1.45, 0], [0.5 * wide, 1.95, -0.05], [0.95 * wide, 2.25, -0.1]], "r": [0.12, 0.05]}},
        {"tube": {"pts": [[-0.03, 1.45, 0], [0.0, 2.1, -0.2], [0.05, 2.6, -0.3]], "r": [0.14, 0.06]}}] +
        [{"cone": {"a": r3([0.18 * math.cos(a), 0.18, 0.18 * math.sin(a)]), "b": r3([0.45 * math.cos(a), 0.0, 0.45 * math.sin(a)]),
                   "r": [0.11, 0.03]}} for a in (0.3, 1.9, 3.3, 4.8)],
        "paint": [{"material": "bark_dark", "stripes": {"axis": "x", "period": 0.11, "width": 0.03}},
                  {"material": "bark_dark", "stripes": {"axis": "y", "period": 0.23, "width": 0.025}},
                  {"material": "bark_hi", "spots": {"scale": 0.07, "density": 0.22, "seed": 6}}]}}
    # the clouds: a lower ring hanging over the limbs, a middle ring, a top
    clouds = []
    for k in range(5):   # the lower clouds, apart, so the limbs show between them
        a = k * math.tau / 5 + 0.15
        clouds.append(([1.15 * wide * math.cos(a), 2.35 + rng.uniform(-0.12, 0.12), 0.95 * wide * math.sin(a)], 0.48 * wide))
    for k in range(5):
        a = k * math.tau / 5 + 0.8
        clouds.append(([0.75 * wide * math.cos(a), 3.05 + rng.uniform(-0.1, 0.1), 0.65 * wide * math.sin(a)], 0.6 * wide))
    clouds.append(([0.05, 3.75, -0.05], 0.62 * wide))
    clouds.append(([0.0, 3.0, -0.2], 0.62 * wide))   # the bulk inside, high enough to leave the limbs free
    for i, (c, r) in enumerate(clouds):
        parts[f"cloud_{i}"] = {"material": "leaf", "blend": 0.04, "prims": clump(rng, c, r),
                               "paint": [{"material": "leaf_dark", "spots": {"scale": 0.07, "density": 0.3, "seed": 30 + i}},
                                         {"material": "leaf_hi", "spots": {"scale": 0.05, "density": 0.16, "seed": 50 + i}}]}
    parts["grass"] = {"material": "tuft", "prims": [{"cone": {"a": r3([0.5 * math.cos(a), 0, 0.5 * math.sin(a)]),
                                                             "b": r3([0.55 * math.cos(a), 0.1, 0.55 * math.sin(a)]), "r": [0.05, 0.01]}}
                                                   for a in [k * 0.7 for k in range(9)]]}
    return parts


def conifer(variant):
    """Conifers after the owner's reference: stacked, drooping, jagged tiers narrowing to a spire.
    spruce = dense and dark; pine = fewer tiers with the trunk showing between them; spruce_light = a
    lighter green, wider at the bottom."""
    rng = random.Random({"spruce": 31, "pine": 32, "spruce_light": 33}[variant])
    sparse = variant == "pine"
    n = 5 if sparse else 8
    R0 = 1.05 if variant != "spruce_light" else 1.2
    parts = {"trunk": {"material": "bark", "prims": [{"cone": {"a": [0, 0, 0], "b": [0, 4.5, 0], "r": [0.15, 0.04]}}],
                       "paint": [{"material": "bark_dark", "stripes": {"axis": "x", "period": 0.09, "width": 0.025}}]}}
    base = 1.1 if sparse else 0.8
    top = 4.55
    for k in range(n):
        f = k / n
        y = base + (top - base - 0.35) * f
        R = R0 * (1 - f) ** 0.85 + 0.12
        h = (0.55 if not sparse else 0.3) * (1 - 0.4 * f)
        prims = [{"cone": {"a": r3([0, y + h, 0]), "b": r3([0, y, 0]), "r": r3([0.06, R * 0.75])}}]
        m = 9
        for j in range(m):   # drooping branch tips: a jagged outline
            a = j * math.tau / m + rng.uniform(-0.25, 0.25) + k * 0.5
            rr = R * rng.uniform(0.85, 1.12)
            prims.append({"cone": {"a": r3([0.25 * R * math.cos(a), y + h * 0.55, 0.25 * R * math.sin(a)]),
                                   "b": r3([rr * math.cos(a), y - (0.06 if sparse else 0.12) - 0.08 * rng.random(), rr * math.sin(a)]),
                                   "r": r3([0.2 * R + 0.05, 0.035])}})
        parts[f"tier_{k}"] = {"material": "needle", "blend": 0.05, "prims": prims,
                              "paint": [{"material": "needle_dark", "spots": {"scale": 0.05, "density": 0.25, "seed": 40 + k}},
                                        {"material": "needle_hi", "spots": {"scale": 0.045, "density": 0.18, "seed": 60 + k}}]}
    parts["tip"] = {"material": "needle", "prims": [{"cone": {"a": r3([0, top - 0.5, 0]), "b": r3([0, top + 0.25, 0]), "r": [0.14, 0.02]}}]}
    return parts


VARIANTS = {"tree_oak_a": lambda: leafy("a"), "tree_oak_b": lambda: leafy("b"), "tree_spruce": lambda: conifer("spruce"),
            "tree_pine": lambda: conifer("pine"), "tree_spruce_light": lambda: conifer("spruce_light")}
TREE = ["tree_grown", "tree_felled", "tree_stump"]
ROCK = ["rock_grown", "rock_felled", "rock_stump"]


def spec(name):
    common = {"spritekiln": 1, "name": name,
              "render": {"outline": "dark", "lines": "depth+normal", "light": "classic", "shading": "toon"},
              "kind": "prop", "shadow": None, "ramps": RAMPS}
    if name == "pig":
        bones, parts, channels, anims = pig()
        d = dict(common, size=32, directions=8, mirror=False,
                 camera={"pitch": 30, "scale": K, "center": [0, 0.3, 0]},
                 brief={"summary": "Your Kingdom pig: pink, on four short legs, a curly tail; idle, walk, root"},
                 channels=channels, bones=bones, parts=parts, animations=anims)
        d["render"] = dict(d["render"], shading="soft")
    else:
        if name in VARIANTS:   # tree variants after the owner's references: toon, dark outline, lines between clouds/tiers
            parts = VARIANTS[name]()
            if "spruce_light" in name:
                common["ramps"] = dict(RAMPS, needle=RAMPS["needle_light"], needle_hi=RAMPS["needle_light_hi"])
            if name == "tree_oak_b":
                common["ramps"] = dict(RAMPS, leaf=RAMPS["leaf_hi"], leaf_hi=RAMPS["leaf_pale"])
        else:
            parts, cy = (tree if name.startswith("tree") else rock)(name.split("_")[1])
            common["render"] = dict(common["render"], shading="soft", lines="depth")
        # frame 96: the tile centre at (48, 80) -> cut to 64x96 at (32, 80)
        d = dict(common, size=96, directions=["se"],
                 camera={"pitch": 30, "scale": K, "center": [0, round(32 * K / math.cos(math.radians(30)), 3), 0]},
                 brief={"summary": f"Your Kingdom {name.replace('_', ' ')}: a natural object on one tile"},
                 channels={}, bones={}, parts=parts, animations={"idle": {"frames": 1, "ms": 500, "channels": {}}})
    used = set()
    for p in d["parts"].values():
        used.add(p["material"])
        for layer in p.get("paint", []):
            used.add(layer["material"])
    d["materials"] = {k: v for k, v in MAT.items() if k in used}
    return d


def main():
    for name in sys.argv[1:] or TREE + ROCK + ["pig"] + list(VARIANTS):
        dd = os.path.join(PROPS, name)
        os.makedirs(dd, exist_ok=True)
        text = yaml.safe_dump(spec(name), sort_keys=False, default_flow_style=None, width=140)
        first, rest = text.split("\n", 1)
        with open(os.path.join(dd, name + ".yaml"), "w") as fh:
            fh.write(first + "\n# Generated by tools/spritekiln/gen_nature.py; edit the script, not this file.\n" + rest)
        print(name)


if __name__ == "__main__":
    main()
