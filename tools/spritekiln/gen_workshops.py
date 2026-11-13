"""G3 part 3: workshops and raw-material buildings from SpriteKiln (ROADMAP G3, "Część 3, plan").

Each building is designed anew (owner's survey 2026-11-13): very detailed and clearly medieval,
complex massing welcome, a small work yard by the entrance where the worker stands. One model gives
the finished building and both construction stages (stage 1: foundations, stakes and strings;
stage 2: walls cut half way, scaffolding, bare rafters).

Plot layout of a 2x2 building (entrance (1, 1), door side +x, stack tile (1, 0)): the building
stands on game x 0..1 (tiles (0, 0) and (0, 1)), its door in the right face (game x ~1) looking at
the entrance tile; the entrance tile is the work yard (low props at its edges, the middle free);
the stack tile stays free for the game's goods stack.

Writes art/specs/props/<id>/<id>.yaml, <id>_c1.yaml and <id>_c2.yaml (stages); edit this script.
Run (inside tools/spritekiln):
  python3 gen_workshops.py [<id>...]
  cd art/specs/props/<id> && spritekiln render <id>.yaml && spritekiln render <id>_c1.yaml && spritekiln render <id>_c2.yaml
  python3 tools/spritekiln/export_building.py <id> --stages      (from the repository root)
"""
import copy
import math
import os
import sys

import yaml

import workshop_kit as K
from workshop_kit import (Gable, Parts, Plot, box, cone, cyl, ell, ext, plane, sph, tor)

HERE = os.path.dirname(os.path.abspath(__file__))

RAMPS = {
    "earth": ["#16120e", "#3a3028", "#54463a", "#6c5c4c", "#86745f"],
    "grass": ["#0e160a", "#24361a", "#3a5226", "#4f6c32", "#68883f"],
    "straw": ["#1a1208", "#3f2e14", "#6a5022", "#93723a", "#b89650", "#d8b870"],
    "bark": ["#0c0805", "#24180e", "#3a2716", "#523820", "#6a4a2c"],
    "endgrain": ["#3a2a18", "#7a5a34", "#a8824e", "#c8a46a", "#e0c48a"],
    "split": ["#2a1c0e", "#5a3e20", "#8a6234", "#b08448", "#cca462"],
    "rope": ["#2a2014", "#5e4c30", "#8c7650", "#b09a70"],
    "soot": ["#060504", "#141210", "#22201c"],
    "flame": ["#5a1a04", "#b44a0a", "#ec8a1a", "#fcc848", "#fff0a0"],
    "leaves": ["#0a1408", "#1e3414", "#30501e", "#46702a", "#5e8c36", "#7aa648"],
    "iron": ["#08080a", "#1c1c20", "#34343a", "#505058", "#70707a"],
    "barrel": ["#140c06", "#3a2614", "#5c3e20", "#7e5830", "#9c7240"],
    "bloom": ["#1a0a20", "#4a2058", "#7a3a8a", "#a058b4", "#c886d6"],
    "moss": ["#0c1406", "#1c2c0e", "#2c4216", "#3c5820"],
    "signboard": ["#1a0e06", "#4a2a12", "#6e4420", "#92602e", "#b07c40"],
    "paint_red": ["#2a0806", "#6a1610", "#9a2a1a", "#c4442a"],
}


def materials():
    m = {
        "earth": {"ramp": "earth", "outline": False},
        "earth_dark": {"ramp": "earth", "bands": [1, 2], "outline": False},
        "grass": {"ramp": "grass", "outline": False},
        "grass_tuft": {"ramp": "grass", "bands": [2, 4], "outline": False},
        "chips": {"ramp": "endgrain", "bands": [2, 4], "outline": False},
        "stone": {"ramp": "stone", "bands": [2, 5]},
        "stone_dark": {"ramp": "stone", "bands": [1, 2], "outline": False},
        "sill_mat": {"ramp": "stone", "bands": [3, 5], "line": False},
        "log": {"ramp": "log", "bands": [2, 5]},
        "log_groove": {"ramp": "log", "bands": [0, 1], "outline": False},
        "log_end": {"ramp": "endgrain", "bands": [2, 4]},
        "log_ring": {"ramp": "endgrain", "bands": [1, 2], "outline": False},
        "log_bark": {"ramp": "bark", "bands": [1, 4]},
        "split": {"ramp": "split", "bands": [1, 4]},
        "split_alt": {"ramp": "split", "bands": [2, 4]},
        "board": {"ramp": "log", "bands": [2, 5]},
        "post": {"ramp": "log", "bands": [1, 4]},
        "haft": {"ramp": "wood", "bands": [2, 4]},
        "timber": {"ramp": "timber", "bands": [1, 4], "line": False},
        "raw_timber": {"ramp": "wood", "bands": [2, 5]},
        "ink": {"ramp": "timber", "bands": [0, 1], "outline": False},
        "plaster": {"ramp": "plaster_cream", "bands": [2, 5]},
        "plaster_ochre": {"ramp": "plaster_ochre", "bands": [2, 5]},
        "shingle": {"ramp": "shingle", "bands": [1, 4]},
        "shingle_dark": {"ramp": "shingle", "bands": [0, 1], "outline": False},
        "thatch": {"ramp": "straw", "bands": [1, 5]},
        "thatch_dark": {"ramp": "straw", "bands": [0, 2], "outline": False},
        "tile": {"ramp": "tile", "bands": [2, 4]},
        "tile_dark": {"ramp": "tile", "bands": [0, 1], "outline": False},
        "slate": {"ramp": "slate", "bands": [2, 5]},
        "slate_dark": {"ramp": "slate", "bands": [0, 1], "outline": False},
        "ridge_cap": {"ramp": "log", "bands": [0, 2]},
        "moss": {"ramp": "moss", "bands": [1, 3], "outline": False},
        "brick": {"ramp": "brick", "bands": [1, 4]},
        "brick_line": {"ramp": "brick", "bands": [0, 1], "outline": False},
        "soot": {"ramp": "soot", "outline": False},
        "door_wood": {"ramp": "wood", "bands": [1, 3]},
        "iron": {"ramp": "iron", "bands": [1, 4], "finish": "metal"},
        "steel": {"ramp": "steel", "finish": "metal"},
        "glass": {"ramp": "glass", "bands": [2, 4], "finish": "glossy", "line": False},
        "shutter": {"ramp": "shutter", "bands": [2, 4], "line": False},
        "bloom": {"ramp": "bloom", "bands": [2, 4], "outline": False},
        "barrel": {"ramp": "barrel", "bands": [1, 4]},
        "barrel_dark": {"ramp": "barrel", "bands": [0, 1], "outline": False},
        "barrel_lid": {"ramp": "endgrain", "bands": [1, 3]},
        "crate": {"ramp": "wood", "bands": [2, 5]},
        "sack": {"ramp": "bone", "bands": [3, 5]},
        "rope": {"ramp": "rope", "bands": [1, 3], "outline": False},
        "sign_board": {"ramp": "signboard", "bands": [2, 4]},
        "sign_edge": {"ramp": "signboard", "bands": [0, 1], "outline": False},
        "flame": {"ramp": "flame", "bands": [2, 4], "emissive": True},
        "leaves": {"ramp": "leaves", "bands": [1, 4]},
        "paint_red": {"ramp": "paint_red", "bands": [1, 3]},
        "brush": {"ramp": "bark", "bands": [2, 4]},
    }
    return m


# =================================================================================================
# Woodcutter: a log lodge with a jettied, half-timbered gable, a stone chimney and an open
# woodshed in front of the gable full of split logs; a chopping block with an axe and a sawhorse
# with a log in the work yard, a saw on the wall, an axe sign, faggots of brushwood.
# =================================================================================================
def woodcutter():
    P, p = Plot(2), Parts()
    K.ground(P, p)
    K.patch(p, "grass_patch", "grass", P, 1.75, 0.35, 0.22, 0.14)
    K.patch(p, "grass_patch", "grass", P, 0.4, 1.96, 0.25, 0.04)
    house = (0.1, 0.98, 0.14, 1.4)
    p.footprints = [house, (0.1, 0.98, 1.4, 1.95)]
    K.plinth(p, P, "plinth", house, h=0.24)
    K.log_walls(p, P, "walls", house, 0.24, 1.78, course=0.19)
    roof = Gable(P, "house", house, "gy", 1.78, 3.25, over=0.26, end_over=0.24)
    p.roofs = [roof]
    # The gable: jettied half-timbering over the log walls.
    x0, x1, z0, z1 = P.rect(*house)
    p.add("jetty", "timber", box([x0 - 0.05, 1.84, (z0 + z1) / 2], [0.1, 0.07, (z1 - z0) / 2 + 0.08]), "wall")
    for i in range(5):
        z = z0 + 0.08 + i * (z1 - z0 - 0.16) / 4
        p.add("jetty", "timber", box([x0 - 0.04, 1.72, z], [0.12, 0.05, 0.05]), "wall")
    roof.infill(p, "plaster")
    roof.gable_frame(p)
    roof.roof(p, "shingle", "shingle_dark", course=0.13, spots=("moss", 0.09, 0.16, 4))
    roof.bargeboards(p)
    K.dormer(p, P, roof, "dormer", 0.62)
    K.window_left(p, P, 0.54, x0 - 0.04, 2.3, w=0.3, h=0.32)
    # Stone chimney on the back slope.
    K.chimney(p, P, "chimney", 0.3, 0.55, 1.6, 3.6, w=0.2, mat="stone", cap="stone")
    p["chimney"]["paint"] = [{"material": "stone_dark", "spots": {"scale": 0.07, "density": 0.35, "seed": 9}}]
    # Door, window, sign, lantern, tools on the right face.
    zr = z1
    K.door_right(p, P, "door", 1.1, zr, 0.24, w=0.52, h=1.05, arch=False)
    K.window_right(p, P, 0.48, zr, 0.95, w=0.32, h=0.36)
    K.sign_right(p, P, 1.36, zr, 1.62, axe_sign)
    K.lantern(p, P, 0.86, zr, 1.45)
    saw_x = P.m(0, 0.8)[0]
    p.add("saw", "steel", box([saw_x, 1.45, zr + 0.05], [0.34, 0.06, 0.015]), "prop", priority=2)
    p.paint("saw", "ink", stripes={"axis": "x", "period": 0.07, "width": 0.02})
    for s in (-1, 1):
        p.add("saw_grips", "haft", cyl([saw_x + s * 0.36, 1.37, zr + 0.06], [saw_x + s * 0.36, 1.57, zr + 0.06], 0.03), "prop")
    # Open woodshed in front of the gable, packed with split logs.
    shed = (0.1, 0.98, 1.42, 1.96)
    K.lean_to(p, P, "shed_roof", shed, "-gy", 1.3, 1.7, "shingle", "shingle_dark", over=0.1)
    K.woodpile(p, P, "firewood", 0.16, 0.92, 1.72, 5, r=0.11, along="gx")
    K.log(p, P, (0.12, 1.96), (0.96, 1.96), 0.06, "shed_sill", y=0.06, mat="post")
    # Brushwood faggots against the right wall's back corner.
    for i, gy in enumerate((0.22, 0.34)):
        a, b = P.m(1.06, gy, 0.1), P.m(1.06, gy, 0.85)
        p.add("faggots", "brush", ell([(a[0] + b[0]) / 2, 0.48 - i * 0.04, a[2] + 0.02 * i], [0.12, 0.42, 0.12],
                                      rot=[0, 0, 0.2 - 0.1 * i]), "prop")
        p.add("faggots_tie", "rope", tor([a[0], 0.6 - i * 0.04, a[2]], 0.12, 0.025, rot=[0, 0, 0.2]), "prop")
    p.paint("faggots", "log_groove", stripes={"axis": "y", "period": 0.11, "width": 0.055})
    # Work yard: chopping block with an axe and chips, a sawhorse with a log.
    K.stump(p, P, 1.2, 1.62, r=0.21, h=0.34)
    K.axe_in(p, P, 1.2, 1.62, 0.36, yaw=-0.6, tilt=0.55)
    for i, (gx, gy) in enumerate(((1.1, 1.82), (1.38, 1.74), (1.05, 1.48), (1.32, 1.9), (1.46, 1.58))):
        c = P.m(gx, gy, 0.025)
        p.add("chips", "chips", box(c, [0.07, 0.02, 0.035], rot=[0, i * 1.1, 0]), "prop")
    K.sawhorse(p, P, 1.62, 1.86, along="gx")
    # A bucksaw leaning on the sawhorse, a wheelbarrow with logs by the shed.
    a, b = P.m(1.9, 1.84, 0.0), P.m(1.86, 1.86, 0.62)
    p.add("bucksaw", "haft", cyl(a, b, 0.025), "prop", priority=2, min_cover=2)
    K.tufts(p, P, [(1.9, 0.08), (0.05, 1.98), (1.95, 1.6), (1.02, 0.1)])
    K.stones(p, P, [(1.85, 1.15), (1.97, 0.95)])
    return P, p, 192, 1.6


def axe_sign(p, c):
    """Two crossed axes painted on a sign board."""
    x, y, z = c
    for s in (-1, 1):
        p.add("sign_emblem", "haft", box([x, y, z], [0.02, 0.15, 0.012], rot=[0, 0, s * 0.7]), "wall", priority=3)
        p.add("sign_emblem", "steel", box([x + s * 0.09, y + 0.09, z + 0.005], [0.06, 0.04, 0.012]), "wall", priority=3)


BUILDINGS = {
    "woodcutter": (woodcutter, "Your Kingdom woodcutter (G3 part 3), 2x2 tiles: a log lodge with a jettied "
                   "half-timbered gable under a steep shingle roof, crossed bargeboards, a stone chimney, an "
                   "open woodshed packed with split logs in front of the gable, an axe sign, a saw on the wall, "
                   "a chopping block with an axe and a sawhorse with a log in the work yard"),
}


# --- spec writing and construction stages ---------------------------------------------------------
def head(name, size, cy, summary):
    return {
        "spritekiln": 1,
        "name": name,
        "render": {"outline": "dark", "lines": "depth+normal", "light": "classic", "shading": "toon"},
        "kind": "prop",
        "size": size,
        "directions": ["se"],
        "palette": ["../../palettes/kingdom.yaml", "../../palettes/town.yaml"],
        "camera": {"pitch": 30, "scale": 0.05176, "center": [0, cy, 0]},
        "shadow": None,
        "ramps": RAMPS,
        "brief": {"summary": summary},
        "materials": materials(),
        "channels": {},
        "bones": {},
    }


def stage(P, parts, which, roofs):
    """Construction stage 1 (foundations, stakes, strings, a heap of materials) or 2 (walls half
    way up, scaffolding on the faces the camera sees, bare rafters)."""
    out = Parts()
    keep = {"ground", "found"} | ({"wall"} if which == 2 else set())
    for name, part in parts.items():
        if parts.layer[name] in keep:
            out[name] = copy.deepcopy(part)
            out.layer[name] = parts.layer[name]
    cut_y = 0.85
    for name, rect, h in parts.plinths:     # a ring of stones, not a slab
        x0, x1, z0, z1 = P.rect(*rect)
        out.cut(name, box([(x0 + x1) / 2, h / 2 + 0.1, (z0 + z1) / 2], [(x1 - x0) / 2 - 0.2, h / 2 + 0.08, (z1 - z0) / 2 - 0.2]))
    if which == 2:
        for name in list(out):
            if out.layer[name] == "wall":
                out.cut(name, plane([0, 1, 0], [0, cut_y, 0]))
        for r in roofs:
            r.rafters(out)
        # tall rafter posts at the gable corners so the frame stands on something
    for i, rect in enumerate(parts.footprints):
        x0, x1, z0, z1 = P.rect(*rect)
        if which == 1:
            for (x, z) in ((x0, z0), (x0, z1), (x1, z1), (x1, z0)):
                out.add("stakes", "raw_timber", cyl([x - 0.08, 0, z + 0.08], [x - 0.08, 0.5, z + 0.08], 0.035), "site")
            for a, b in (((x0, z0), (x0, z1)), ((x0, z1), (x1, z1))):
                out.add("strings", "rope", cyl([a[0] - 0.08, 0.42, a[1] + 0.08], [b[0] - 0.08, 0.42, b[1] + 0.08], 0.018),
                        "site", min_cover=1, priority=2)
        else:
            # Scaffold poles and a plank walk along the left and the right face.
            for (x, z) in ((x0 - 0.35, z0), (x0 - 0.35, (z0 + z1) / 2), (x0 - 0.35, z1 + 0.35), ((x0 + x1) / 2, z1 + 0.35),
                           (x1, z1 + 0.35)):
                out.add("scaffold", "raw_timber", cyl([x, 0, z], [x, cut_y + 0.9, z], 0.035), "site", priority=2)
            out.add("scaffold_planks", "raw_timber", box([x0 - 0.35, cut_y - 0.05, (z0 + z1 + 0.35) / 2],
                                                         [0.16, 0.03, (z1 - z0 + 0.4) / 2]), "site")
            out.add("scaffold_planks", "raw_timber", box([(x0 - 0.35 + x1) / 2, cut_y - 0.05, z1 + 0.35],
                                                         [(x1 - x0 + 0.4) / 2, 0.03, 0.16]), "site")
            out.add("scaffold", "raw_timber", box([x0 - 0.35, cut_y + 0.6, (z0 + z1 + 0.35) / 2],
                                                  [0.03, 0.03, (z1 - z0 + 0.4) / 2]), "site")
            out.add("scaffold", "raw_timber", box([(x0 - 0.35 + x1) / 2, cut_y + 0.6, z1 + 0.35],
                                                  [(x1 - x0 + 0.4) / 2, 0.03, 0.03]), "site")
    # A heap of building material on the stack tile: squared beams and stones.
    for k in range(3):
        a, b = P.m(1.3 + k * 0.14, 0.2, 0.08 + 0.0), P.m(1.3 + k * 0.14, 0.75, 0.08)
        out.add("beams", "raw_timber", box([(a[0] + b[0]) / 2, 0.08, a[2]], [abs(a[0] - b[0]) / 2, 0.08, 0.07]), "site")
    a = P.m(1.37, 0.47, 0.24)
    out.add("beams", "raw_timber", box(a, [0.62, 0.08, 0.07]), "site")
    K.stones(out, P, [(1.75, 0.3), (1.82, 0.5), (1.68, 0.45), (1.76, 0.42)], name="stone_heap")
    return out


def write(name, s):
    d = os.path.join(HERE, "art", "specs", "props", name.split("@")[0])
    os.makedirs(d, exist_ok=True)
    fname = s["name"]
    text = yaml.safe_dump(s, sort_keys=False, default_flow_style=None, width=140)
    first, rest = text.split("\n", 1)
    with open(os.path.join(d, fname + ".yaml"), "w") as fh:
        fh.write(first + "\n# Generated by tools/spritekiln/gen_workshops.py; edit the script, not this file.\n" + rest)
    return sum(len(p["prims"]) for p in s["parts"].values())


def main():
    only = [a for a in sys.argv[1:] if not a.startswith("-")]
    for bid, (fn, summary) in BUILDINGS.items():
        if only and bid not in only:
            continue
        P, parts, size, cy = fn()
        s = head(bid, size, cy, summary)
        s["parts"] = dict(parts)
        s["animations"] = {"idle": {"frames": 1, "ms": 500, "channels": {}}}
        n = write(bid, s)
        for k in (1, 2):
            st = stage(P, parts, k, parts.roofs)
            s2 = head(f"{bid}_c{k}", size, cy, summary + f" (construction stage {k})")
            s2["parts"] = dict(st)
            s2["animations"] = s["animations"]
            write(bid, s2)
        print("written", bid, n, "prims")


if __name__ == "__main__":
    main()
