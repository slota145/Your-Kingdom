"""SpriteKiln trial (owner 2026-11-10): isometric terrain textures.

SpriteKiln 0.3 has no tile kind, so a terrain texture is a flat prop: a square patch of 4x4 tiles
(9.37 units) seen from se (yaw 45) gives the game's 256x128 diamond (ART_SPEC 8: the big textures
wrap in grid space). To make it seamless, every feature that crosses an edge of the patch is copied to
the opposite side, and every part is cut by the four edge planes, so copies meet edge to edge.
Features stay low (a few px), so nothing sticks out above the diamond.

The game's big textures are full 256x128 rectangles (the corners hold the neighbouring copies), laid
like bricks; so the model is the pattern repeated over a 2x2-patch area and the render's middle
256x128 is cut out (compose_terrain.py): no mask, no seam.
Writes art/specs/props/terrain_<id>/terrain_<id>.yaml for grass, paving and stony.
Run: python3 tools/spritekiln/gen_terrain.py [id ...], render, then compose_terrain.py
"""
import math
import os
import random
import sys

import yaml

HERE = os.path.dirname(os.path.abspath(__file__))
PROPS = os.path.join(HERE, "art", "specs", "props")
TILE = 2.343
P = 4 * TILE          # the patch: 4x4 tiles, the period of the pattern
HP = P / 2

# ramps taken from the game's own textures (spritekiln palette extract, ART_SPEC 10.20)
RAMPS = {
    "grass": ["#0c0f0b", "#35442a", "#4f6238", "#607345", "#76884f", "#8d9e60"],
    "grass_hi": ["#35442a", "#607345", "#8d9e60", "#a0ad70", "#b0b68c", "#c4c8a0"],
    "flower_y": ["#3a3010", "#8a7420", "#d4b23a", "#f0d460", "#f8ea9a", "#fff8d0"],
    "flower_w": ["#3a3a36", "#8a8a80", "#c8c8c0", "#e4e4dc", "#f4f4ee", "#ffffff"],
    "cobble": ["#0d0d0d", "#3e3e3c", "#575653", "#696865", "#7f7e7a", "#91908d"],
    "cobble_b": ["#0e0d0c", "#494639", "#646249", "#7c7d5f", "#908f74", "#a4a78b"],
    "joint": ["#0e0d0c", "#2c2a24", "#3a372e", "#494639", "#57543f", "#65614a"],
    "dirt": ["#0f0c0b", "#46362c", "#5e4a3a", "#776148", "#8c7756", "#a28f67"],
    "pebble": ["#0f0c0b", "#4e4a43", "#6f6a60", "#938d80", "#aaa494", "#b8b2a3"],
    "pebble_r": ["#0f0c0b", "#5a4434", "#7a5e48", "#9a7c62", "#b0967a", "#c4ae94"],
}


def r3(v):
    return [round(float(x), 3) for x in v] if isinstance(v, (list, tuple)) else round(float(v), 3)


REACH = HP + 0.4   # copies anywhere within the 256x128 rectangle around the patch


def wrapped(x, z, reach=REACH):
    """The position and its copies in the neighbouring patches that show in the rectangle."""
    out = [(x, z)]
    for dx in (-P, 0, P):
        for dz in (-P, 0, P):
            if (dx, dz) == (0, 0):
                continue
            nx, nz = x + dx, z + dz
            if -HP - reach < nx < HP + reach and -HP - reach < nz < HP + reach:
                out.append((nx, nz))
    return out


EDGES = []   # nothing is cut: the rectangle is cut out of the render instead


def ground(material):
    return {"material": material, "prims": [{"box": {"c": [0, -0.05, 0], "half": r3([P + 0.5, 0.05, P + 0.5])}}]}


def grass(rng):
    parts = {"ground": ground("grass")}
    pl, pd, tl, td, fy, fw = [], [], [], [], [], []
    for _ in range(46):   # flat patches of lighter and darker grass
        x, z = rng.uniform(-HP, HP), rng.uniform(-HP, HP)
        r = rng.uniform(0.35, 0.8)
        target = pl if rng.random() < 0.5 else pd
        rot = rng.uniform(0, math.pi)
        for (cx, cz) in wrapped(x, z):
            target.append({"ellipsoid": {"c": r3([cx, 0.0, cz]), "r": r3([r, 0.012, r * 0.6]), "rot": r3([0, rot, 0])}})
    for _ in range(230):  # tufts: two blades leaning apart
        x, z = rng.uniform(-HP, HP), rng.uniform(-HP, HP)
        a = rng.uniform(0, math.tau)
        target = tl if rng.random() < 0.55 else td
        for (cx, cz) in wrapped(x, z):
            for sgn in (-1, 1):
                target.append({"cone": {"a": r3([cx, 0.0, cz]),
                                        "b": r3([cx + sgn * 0.07 * math.cos(a), 0.12, cz + sgn * 0.07 * math.sin(a)]),
                                        "r": [0.04, 0.01]}})
    for _ in range(22):
        x, z = rng.uniform(-HP, HP), rng.uniform(-HP, HP)
        target = fy if rng.random() < 0.5 else fw
        for (cx, cz) in wrapped(x, z):
            target.append({"sphere": {"c": r3([cx, 0.07, cz]), "r": 0.05}})
    parts.update({"patch_light": {"material": "grass_light", "prims": pl}, "patch_dark": {"material": "grass_dark", "prims": pd},
                  "tufts": {"material": "grass_hi", "prims": tl}, "tufts_dark": {"material": "grass_dark", "prims": td},
                  "flowers_y": {"material": "flower_y", "prims": fy}, "flowers_w": {"material": "flower_w", "prims": fw}})
    return parts


def paving(rng):
    """Cobbles in rows along x, every other row shifted half a stone; 24 stones x 24 rows per patch."""
    parts = {"ground": ground("joint")}
    n = 24
    s = P / n
    a, b = [], []
    for row in range(n):
        z = -HP + (row + 0.5) * s
        shift = 0.5 * s if row % 2 else 0.0
        for col in range(n):
            x = -HP + (col + 0.5) * s + shift
            if x > HP:
                x -= P
            hw, hd = s * rng.uniform(0.43, 0.48), s * rng.uniform(0.42, 0.47)
            h = rng.uniform(0.025, 0.045)
            rot = rng.uniform(-0.12, 0.12)
            target = a if rng.random() < 0.75 else b
            for (cx, cz) in wrapped(x, z):
                target.append({"box": {"c": r3([cx, h, cz]), "half": r3([hw, h, hd]), "rot": r3([0, rot, 0]),
                                       "round": 0.06}})
    parts["stones"] = {"material": "cobble", "prims": a, "cut": EDGES}
    parts["stones_b"] = {"material": "cobble_b", "prims": b, "cut": EDGES}
    return parts


def stony(rng):
    parts = {"ground": ground("dirt")}
    grey, red = [], []
    for _ in range(140):
        x, z = rng.uniform(-HP, HP), rng.uniform(-HP, HP)
        big = rng.random() < 0.15
        r = rng.uniform(0.12, 0.2) if big else rng.uniform(0.04, 0.09)
        ry = r * rng.uniform(0.4, 0.6)
        rot = rng.uniform(0, math.pi)
        target = red if rng.random() < 0.3 else grey
        for (cx, cz) in wrapped(x, z):
            target.append({"ellipsoid": {"c": r3([cx, ry * 0.4, cz]), "r": r3([r, ry, r * rng.uniform(0.6, 0.9)]),
                                         "rot": r3([0, rot, 0])}})
    parts["pebbles"] = {"material": "pebble", "prims": grey, "cut": EDGES}
    parts["pebbles_r"] = {"material": "pebble_r", "prims": red, "cut": EDGES}
    return parts


KINDS = {"grass": grass, "paving": paving, "stony": stony}
MATERIALS = {
    "grass": {"ramp": "grass", "bands": [3, 5], "outline": False, "line": False},
    "grass_light": {"ramp": "grass_hi", "bands": [2, 3], "outline": False, "line": False},
    "grass_dark": {"ramp": "grass", "bands": [2, 3], "outline": False, "line": False},
    "grass_hi": {"ramp": "grass_hi", "bands": [1, 4], "outline": False},
    "flower_y": {"ramp": "flower_y", "bands": [2, 5], "outline": False},
    "flower_w": {"ramp": "flower_w", "bands": [2, 5], "outline": False},
    "joint": {"ramp": "joint", "bands": [4, 5], "outline": False, "line": False},
    "cobble": {"ramp": "cobble", "bands": [2, 5], "outline": False},
    "cobble_b": {"ramp": "cobble_b", "bands": [2, 5], "outline": False},
    "dirt": {"ramp": "dirt", "bands": [3, 5], "outline": False, "line": False},
    "pebble": {"ramp": "pebble", "bands": [2, 5], "outline": False},
    "pebble_r": {"ramp": "pebble_r", "bands": [2, 5], "outline": False},
}


def spec(kind):
    parts = KINDS[kind](random.Random(7))
    used = {p["material"] for p in parts.values()}
    return {
        "spritekiln": 1,
        "name": f"terrain_{kind}",
        "render": {"outline": "none", "lines": "none" if kind == "grass" else "depth", "light": "classic", "shading": "soft"},
        "kind": "prop",
        "size": 256,
        "directions": ["se"],
        "camera": {"pitch": 30, "scale": 0.05176, "center": [0, 0, 0]},
        "shadow": None,
        "ramps": RAMPS,
        "brief": {"summary": f"Your Kingdom terrain texture '{kind}': a seamless 4x4-tile patch (256x128 diamond)"},
        "materials": {k: v for k, v in MATERIALS.items() if k in used},
        "channels": {},
        "bones": {},
        "parts": parts,
        "animations": {"idle": {"frames": 1, "ms": 500, "channels": {}}},
    }


def main():
    for kind in sys.argv[1:] or list(KINDS):
        d = os.path.join(PROPS, f"terrain_{kind}")
        os.makedirs(d, exist_ok=True)
        text = yaml.safe_dump(spec(kind), sort_keys=False, default_flow_style=None, width=140)
        first, rest = text.split("\n", 1)
        with open(os.path.join(d, f"terrain_{kind}.yaml"), "w") as fh:
            fh.write(first + "\n# Generated by tools/spritekiln/gen_terrain.py; edit the script, not this file.\n" + rest)
        print(kind, sum(len(p["prims"]) for p in spec(kind)["parts"].values()), "prims")


if __name__ == "__main__":
    main()
