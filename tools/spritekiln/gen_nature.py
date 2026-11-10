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
    "rock": ["#121110", "#3a3834", "#56534c", "#747068", "#948f84", "#b4afa2"],
    "moss": ["#0c1408", "#24401a", "#3a5e26", "#527a34", "#6c9444", "#8aae58"],
    "pig": ["#1e0c0c", "#5a2a2c", "#965052", "#c87a78", "#e4a09a", "#f6c6be"],
    "pig_dark": ["#1e0c0c", "#4a2224", "#7a3e40", "#a05a5a", "#c07874", "#d89892"],
    "eye": ["#0a0606", "#1a1010", "#2a1a1a", "#3a2424"],
    "dirt": ["#1a120b", "#3e2e1e", "#5e4630", "#7c6043", "#9a7c58"],
}
MAT = {
    "bark": {"ramp": "bark", "bands": [2, 5]},
    "cut": {"ramp": "cut", "bands": [2, 5]},
    "ring": {"ramp": "cut", "bands": [1, 2], "outline": False, "line": False},
    "leaf": {"ramp": "leaf", "bands": [2, 5]},
    "leaf_hi": {"ramp": "leaf_hi", "bands": [3, 5], "outline": False, "line": False},
    "leaf_dark": {"ramp": "leaf", "bands": [1, 2], "outline": False, "line": False},
    "rock": {"ramp": "rock", "bands": [2, 5], "crease": True, "edge_highlight": True},
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
    """A leafy crown: overlapping clumps, lighter leaves where the light falls, darker hollows."""
    prims = []
    for k in range(15):
        a = k * 2.4
        rr = (0.55 if k < 8 else 0.25) * scale
        y = cy + (0.25 * math.sin(k * 1.3) + (0.35 if k >= 8 else 0.0)) * scale
        prims.append({"ellipsoid": {"c": r3([cx + rr * math.cos(a) + rng.uniform(-0.08, 0.08), y,
                                             cz + rr * math.sin(a) + rng.uniform(-0.08, 0.08)]),
                                    "r": r3([0.55 * scale, 0.46 * scale, 0.55 * scale])}})
    prims.append({"ellipsoid": {"c": r3([cx, cy + 0.75 * scale, cz]), "r": r3([0.5 * scale, 0.42 * scale, 0.5 * scale])}})
    return {"material": "leaf", "blend": 0.08, "priority": 1, "prims": prims,
            "paint": [{"material": "leaf_dark", "spots": {"scale": 0.12, "density": 0.3, "seed": 3}},
                      {"material": "leaf_hi", "spots": {"scale": 0.09, "density": 0.28, "seed": 4}}]}


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
        parts["trunk"] = {"material": "bark", "prims": [
            {"cone": {"a": [0, 0, 0], "b": [0, 2.4, 0], "r": [0.2, 0.11]}},
            {"tube": {"pts": [[0, 1.5, 0], [0.35, 2.0, 0.1], [0.6, 2.5, 0.15]], "r": [0.08, 0.04]}},
            {"tube": {"pts": [[0, 1.7, 0], [-0.3, 2.2, -0.1], [-0.55, 2.6, -0.1]], "r": [0.07, 0.04]}}] +
            stump["prims"][1:]}
        parts["crown"] = crown(rng, 0, 3.05, 0)
        return parts, 1.91
    # felled: the trunk lies on the ground towards the upper right, the crown at its end, the stump behind
    parts["stump"] = stump
    parts["top"] = {"material": "cut", "prims": [{"cylinder": {"a": [0, 0.3, 0], "b": [0, 0.34, 0], "r": 0.19}}],
                    "paint": [{"material": "ring", "rings": {"axis": "y", "period": 0.06, "width": 0.04}}]}
    parts["log"] = {"material": "bark", "prims": [{"cone": {"a": [-0.15, 0.2, 0.45], "b": [1.15, 0.14, 0.25], "r": [0.19, 0.12]}}]}
    parts["log_end"] = {"material": "cut", "prims": [{"cylinder": {"a": [-0.2, 0.2, 0.46], "b": [-0.16, 0.2, 0.455], "r": 0.18}}]}
    parts["crown"] = crown(rng, 1.55, 0.45, 0.2, scale=0.6)
    for p_ in parts.values():   # the whole group a step to the lower left, so the crown fits
        p_["prims"] = [shift(pr, -0.55, 0.45) for pr in p_["prims"]]
    return parts, 0.9


def rock(state):
    parts = {}
    if state == "grown":
        boulders = [([0.0, 0.55, -0.1], [0.75, 0.6, 0.6], [0, 0.4, 0.1]), ([0.55, 0.38, 0.45], [0.5, 0.42, 0.45], [0, -0.3, 0]),
                    ([-0.55, 0.3, 0.45], [0.45, 0.32, 0.4], [0.1, 0.6, 0])]
    elif state == "felled":
        boulders = [([0.2, 0.3, 0.1], [0.5, 0.34, 0.45], [0, 0.4, 0.1]), ([-0.45, 0.22, 0.4], [0.38, 0.25, 0.32], [0.1, 0.6, 0])]
    else:   # rubble
        rng = random.Random(2)
        boulders = [([rng.uniform(-0.7, 0.7), 0.08, rng.uniform(-0.6, 0.7)], [rng.uniform(0.1, 0.2), 0.09, rng.uniform(0.08, 0.16)],
                     [0, rng.uniform(0, 3), 0.2]) for _ in range(8)]
    prims = [{"box": {"c": r3(c), "half": r3(h), "rot": r3(rot), "round": 0.12 if state != "stump" else 0.04}} for c, h, rot in boulders]
    parts["rock"] = {"material": "rock", "blend": {"mode": "chamfer", "k": 0.05} if state != "stump" else 0.0, "prims": prims,
                     "cut": [{"plane": {"n": [0, -1, 0], "at": 0.0}}],
                     "paint": [{"material": "crack", "stripes": {"axis": "x", "at": [0.12, -0.31], "width": 0.025}},
                               {"material": "moss", "spots": {"scale": 0.08, "density": 0.16, "seed": 8}}]}
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
        parts, cy = (tree if name.startswith("tree") else rock)(name.split("_")[1])
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
    for name in sys.argv[1:] or TREE + ROCK + ["pig"]:
        dd = os.path.join(PROPS, name)
        os.makedirs(dd, exist_ok=True)
        text = yaml.safe_dump(spec(name), sort_keys=False, default_flow_style=None, width=140)
        first, rest = text.split("\n", 1)
        with open(os.path.join(dd, name + ".yaml"), "w") as fh:
            fh.write(first + "\n# Generated by tools/spritekiln/gen_nature.py; edit the script, not this file.\n" + rest)
        print(name)


if __name__ == "__main__":
    main()
