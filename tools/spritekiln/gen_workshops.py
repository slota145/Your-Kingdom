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
import json
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
    "wicker": ["#1a1006", "#4a3216", "#74522a", "#9a7038", "#be9250"],
    "weathered": ["#14181a", "#2e3436", "#4a5052", "#686e6c", "#888c86"],
    "net": ["#1c1a14", "#3e3a2c", "#5e5844"],
    "fish": ["#1a2228", "#4a5a64", "#7e909a", "#b4c2c8", "#e0e8ea"],
    "ore": ["#1a0c06", "#4a2210", "#7a3a1a", "#a0522a", "#c07040"],
    "clay": ["#1e0e06", "#4e2a14", "#7a4422", "#9e5e32", "#bc7a48"],
    "ashlar": ["#1c1a18", "#4a4640", "#6e6860", "#948c80", "#b8afa0", "#d6cebe"],
    "fieldstone": ["#141414", "#383634", "#5a5650", "#7a756c", "#9c968a"],
    "soil": ["#0e0a06", "#24180e", "#3a2818", "#4e3822"],
    "water": ["#0a1a24", "#14324a", "#22506a", "#3a7090", "#6a9ab4"],
    "charcoal": ["#050505", "#121212", "#222222", "#343434"],
    "antler": ["#2a2218", "#5a4c38", "#8c7c62", "#b8aa8c", "#dcd2b8"],
    "smoke": ["#4a4844", "#6e6c66", "#94928a", "#b8b6ae", "#d6d4cc"],
    "hop_green": ["#0e1a06", "#2a4410", "#467018", "#6a9a28", "#94c048"],
    "hay": ["#1c1406", "#4a3812", "#7a6020", "#a88a34", "#cdb050", "#ecd47a"],
    "grape": ["#12061a", "#341040", "#561c64", "#782c86", "#9a46a4"],
    "flour": ["#6a6458", "#a8a294", "#d4cfc2", "#ece8de", "#faf8f2"],
    "sailcloth": ["#4a4234", "#8a7e66", "#bcb092", "#dcd2b6", "#f0e8d2"],
    "bread": ["#2a1404", "#6a3a10", "#a0621e", "#c88a38", "#e4b462"],
    "dough": ["#6a5c48", "#a8987c", "#d4c4a4", "#ece0c4"],
    "copper": ["#2a0e06", "#6a2a10", "#a4481e", "#d06a32", "#ec9a5a"],
    "beer": ["#1a0c02", "#4a2a08", "#7a4a12"],
    "pewter": ["#2a2c2e", "#5e6266", "#9298a0", "#c6ccd2"],
    "brass": ["#2a1c04", "#6a4a10", "#a8801e", "#d8b040"],
    "leather": ["#1a0c06", "#3e2412", "#64401e", "#8a5e30"],
    "cobble": ["#1e1c1a", "#3e3a36", "#5a5650", "#76716a", "#928c84"],
    "cloth_red": ["#2a0606", "#6a1412", "#a42620", "#cc4434"],
    "cloth_blue": ["#060c22", "#142456", "#24408a", "#4062b4"],
    "cloth_green": ["#061a0c", "#14421e", "#246a30", "#3e9048"],
    "meat": ["#2a0606", "#6a1614", "#a42e26", "#cc5a48", "#e88a78"],
    "tar": ["#030202", "#0e0a08", "#1e1612", "#2e241c"],
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
        "slate": {"ramp": "slate", "bands": [1, 3]},
        "slate_dark": {"ramp": "slate", "bands": [0, 1], "outline": False},
        "slate_light": {"ramp": "slate", "bands": [3, 4], "outline": False},
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
        "leaves_dark": {"ramp": "leaves", "bands": [0, 2], "outline": False},
        "wicker": {"ramp": "wicker", "bands": [2, 4]},
        "weathered": {"ramp": "weathered", "bands": [1, 4]},
        "net": {"ramp": "net", "bands": [0, 2], "two_sided": True, "outline": False},
        "fish": {"ramp": "fish", "bands": [1, 4], "finish": "glossy"},
        "ore": {"ramp": "ore", "bands": [1, 4]},
        "clay": {"ramp": "clay", "bands": [1, 4]},
        "clay_dark": {"ramp": "clay", "bands": [0, 1], "outline": False},
        "ashlar": {"ramp": "ashlar", "bands": [2, 5]},
        "ashlar_line": {"ramp": "ashlar", "bands": [0, 1], "outline": False},
        "fieldstone": {"ramp": "fieldstone", "bands": [1, 4]},
        "soil": {"ramp": "soil", "outline": False},
        "water": {"ramp": "water", "bands": [2, 4], "finish": "glossy", "outline": False},
        "charcoal": {"ramp": "charcoal", "bands": [1, 3]},
        "tar": {"ramp": "tar", "bands": [1, 3], "finish": "glossy"},
        "dark_hole": {"ramp": "soot", "bands": [0, 1], "outline": False, "line": False},
        "turf": {"ramp": "grass", "bands": [1, 4]},
        "antler": {"ramp": "antler", "bands": [2, 4]},
        "bread": {"ramp": "bread", "bands": [1, 4]},
        "dough": {"ramp": "dough", "bands": [1, 3]},
        "copper": {"ramp": "copper", "bands": [1, 4], "finish": "metal"},
        "beer": {"ramp": "beer", "bands": [0, 2], "finish": "glossy", "outline": False},
        "pewter": {"ramp": "pewter", "bands": [1, 3], "finish": "metal"},
        "brass": {"ramp": "brass", "bands": [1, 3], "finish": "metal"},
        "leather": {"ramp": "leather", "bands": [1, 3]},
        "cobble_ground": {"ramp": "cobble", "bands": [2, 4], "outline": False},
        "cloth_red": {"ramp": "cloth_red", "bands": [1, 3]},
        "cloth_blue": {"ramp": "cloth_blue", "bands": [1, 3]},
        "cloth_green": {"ramp": "cloth_green", "bands": [1, 3]},
        "meat": {"ramp": "meat", "bands": [1, 4]},
        "honey": {"ramp": "straw", "bands": [3, 5], "finish": "glossy"},
        "bone": {"ramp": "bone", "bands": [2, 4]},
        "plank": {"ramp": "wood", "bands": [2, 5]},
        "plank_alt": {"ramp": "wood", "bands": [3, 5]},
        "clay_light": {"ramp": "clay", "bands": [2, 4]},
        "brick_alt": {"ramp": "brick", "bands": [2, 4]},
        "wool": {"ramp": "flour", "bands": [1, 4]},
        "hide": {"ramp": "leather", "bands": [1, 3]},
        "meat_dark": {"ramp": "meat", "bands": [0, 1], "outline": False},
        "flour": {"ramp": "flour", "bands": [2, 4], "outline": False},
        "flour_sack": {"ramp": "flour", "bands": [1, 4]},
        "sailcloth": {"ramp": "sailcloth", "bands": [1, 4], "two_sided": True},
        "grape": {"ramp": "grape", "bands": [1, 4]},
        "grape_dark": {"ramp": "grape", "bands": [0, 1], "outline": False},
        "smoke": {"ramp": "smoke", "bands": [1, 3], "outline": False},
        "hop_green": {"ramp": "hop_green", "bands": [1, 4]},
        "hay": {"ramp": "hay", "bands": [2, 5]},
        "stone_chips": {"ramp": "ashlar", "bands": [3, 5], "outline": False},
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


# =================================================================================================
# Forester: a keeper's lodge, a fieldstone ground floor and an ochre half-timbered upper floor
# under a steep hipped thatch, a brick chimney, a board tool shed with tools on its wall, an old oak
# behind the house; a nursery bed with saplings, a watering can and a spade in the work yard.
# =================================================================================================
def forester():
    P, p = Plot(2), Parts()
    K.ground(P, p, seed=6)
    K.patch(p, "grass_patch", "grass", P, 1.6, 0.4, 0.3, 0.2)
    K.patch(p, "grass_patch", "grass", P, 0.3, 1.95, 0.3, 0.05)
    K.tree(p, P, "oak", 0.45, 0.06, h=4.7, crown=1.15, seed=2)
    house = (0.12, 0.96, 0.16, 1.32)
    p.footprints = [house, (0.12, 0.96, 1.32, 1.94)]
    K.plinth(p, P, "plinth", house, h=0.2)
    K.walls(p, P, "ground_floor", house, 0.2, 1.15, "fieldstone")
    p.paint("ground_floor", "stone_dark", spots={"scale": 0.07, "density": 0.4, "seed": 3})
    K.quoins(p, P, "quoins", house, 0.2, 1.15)
    x0, x1, z0, z1 = P.rect(*house)
    up = (house[0] - 0.04, house[1] + 0.04, house[2] - 0.04, house[3] + 0.04)
    p.add("jetty", "timber", box([(x0 + x1) / 2, 1.2, (z0 + z1) / 2], [(x1 - x0) / 2 + 0.12, 0.06, (z1 - z0) / 2 + 0.12]), "wall")
    K.walls(p, P, "upper", up, 1.25, 2.1, "plaster")
    K.timber_left(p, P, "upper_frame", up, 1.25, 2.1, 2)
    K.timber_right(p, P, "upper_frame", up, 1.25, 2.1, 4)
    K.hip_roof(p, P, "roof", up, 2.08, 3.45, "thatch", "thatch_dark", over=0.3, course=0.16, spots=("moss", 0.1, 0.18, 6))
    K.chimney(p, P, "chimney", 0.42, 0.5, 2.2, 3.7, w=0.17)
    xl = P.rect(*up)[0]
    zr = P.rect(*up)[3]
    K.window_left(p, P, 0.54, xl - 0.02, 1.7, w=0.3, h=0.34)
    K.window_right(p, P, 0.45, zr, 1.7, w=0.3, h=0.34)
    K.window_right(p, P, 1.05, zr, 1.7, w=0.3, h=0.34, box_=True)
    K.window_right(p, P, 0.5, z1, 0.7, w=0.26, h=0.3, open_=False)
    K.door_right(p, P, "door", 1.02, z1, 0.2, w=0.5, h=0.85, arch=True)
    # Antlers over the door.
    xd = P.m(0, 1.02)[0]
    p.add("antlers", "antler", sph([xd, 1.38, z1 + 0.08], 0.06), "wall", priority=2, min_cover=2)
    for sx in (-1, 1):
        p.add("antlers", "antler", cone([xd + sx * 0.04, 1.4, z1 + 0.08], [xd + sx * 0.28, 1.62, z1 + 0.1], 0.03, 0.018),
              "wall", priority=2, min_cover=2)
        p.add("antlers", "antler", cone([xd + sx * 0.16, 1.5, z1 + 0.09], [xd + sx * 0.14, 1.66, z1 + 0.1], 0.022, 0.014),
              "wall", priority=2, min_cover=2)
    # The tool shed in front of the house: boards, a lean-to roof, tools on its right wall.
    shed = (0.12, 0.92, 1.36, 1.92)
    K.board_walls(p, P, "shed", shed, 0.0, 1.05, mat="board")
    K.lean_to(p, P, "shed_roof", shed, "-gy", 1.05, 1.45, "shingle", "shingle_dark", over=0.12, posts=False)
    sx0, sx1, sz0, sz1 = P.rect(*shed)
    for i, (gy, kind) in enumerate(((1.48, "spade"), (1.62, "rake"), (1.76, "saw"))):
        x = P.m(0, gy)[0]
        if kind == "saw":
            p.add("tools", "steel", box([x, 0.62, sz1 + 0.04], [0.1, 0.18, 0.015]), "prop", priority=2)
            p.add("tools_h", "haft", box([x, 0.85, sz1 + 0.05], [0.03, 0.06, 0.02]), "prop", priority=2)
            continue
        p.add("tools_h", "haft", cyl([x, 0.15, sz1 + 0.05], [x, 1.0, sz1 + 0.05], 0.025), "prop", priority=2, min_cover=2)
        if kind == "spade":
            p.add("tools", "steel", box([x, 0.2, sz1 + 0.05], [0.08, 0.12, 0.015]), "prop", priority=2)
        else:
            p.add("tools", "iron", box([x, 0.98, sz1 + 0.05], [0.14, 0.025, 0.02]), "prop", priority=2)
    K.window_left(p, P, 0.5, sx0, 0.65, w=0.24, h=0.24, shutters=False)
    # Nursery bed along the front edge of the work yard: a plank frame, dark soil, saplings.
    a = P.m(1.08, 1.82)
    b = P.m(1.9, 1.82)
    cx, cz = (a[0] + b[0]) / 2, (a[2] + b[2]) / 2
    p.add("bed", "board", box([cx, 0.09, cz], [0.22, 0.09, abs(b[2] - a[2]) / 2]), "prop")
    p.add("bed_soil", "soil", box([cx, 0.17, cz], [0.18, 0.02, abs(b[2] - a[2]) / 2 - 0.05]), "prop")
    for i in range(6):
        gx = 1.15 + i * 0.13
        x, _, z = P.m(gx, 1.82)
        h = 0.32 + 0.05 * (i % 3)
        p.add("saplings", "log_bark", cyl([x, 0.15, z], [x, h, z], 0.018), "prop", min_cover=2)
        p.add("sapling_leaves", "leaves", ell([x, h, z], [0.09, 0.1, 0.09]), "prop")
    # A watering can and a sack of acorns.
    x, _, z = P.m(1.2, 1.55)
    p.add("can", "iron", cyl([x, 0, z], [x, 0.24, z], 0.1), "prop")
    p.add("can", "iron", cone([x - 0.08, 0.1, z], [x - 0.3, 0.3, z], 0.035, 0.02), "prop", priority=2)
    p.add("can", "iron", tor([x, 0.28, z], 0.08, 0.02, rot=[1.5708, 0, 0]), "prop")
    K.sack(p, P, 1.88, 1.35, s=0.16)
    x, _, z = P.m(1.55, 1.95)
    p.add("spade_h", "haft", cyl([x, 0.1, z], [x + 0.05, 0.85, z - 0.05], 0.025), "prop", priority=2, min_cover=2)
    p.add("spade_b", "steel", box([x, 0.08, z], [0.08, 0.1, 0.015]), "prop", priority=2)
    # A bird box on a pole by the stack tile's back edge.
    x, _, z = P.m(1.9, 0.08)
    p.add("birdbox_pole", "post", cyl([x, 0, z], [x, 1.5, z], 0.04), "prop")
    p.add("birdbox", "board", box([x, 1.55, z], [0.1, 0.12, 0.1]), "prop")
    p.add("birdbox_roof", "shingle", box([x, 1.7, z], [0.14, 0.03, 0.14]), "prop")
    p.add("birdbox_hole", "dark_hole", sph([x - 0.02, 1.58, z + 0.1], 0.035), "prop")
    K.tufts(p, P, [(1.95, 0.6), (1.05, 0.12), (0.06, 1.98), (1.4, 1.05)])
    p.roofs = []
    return P, p, 224, 1.9


# =================================================================================================
# Quarry: a stonecutter's lodge of dressed ashlar under slate, the gable with its door towards the
# yard, quoins, a carved stone over the door; an open masons' lodge (slate lean-to) with a banker
# and a half-dressed block, shear legs with a block on a chain, blocks and stone chips.
# =================================================================================================
def quarry():
    P, p = Plot(2), Parts()
    K.ground(P, p, seed=8)
    for i, (gx, gy) in enumerate(((1.3, 1.6), (1.6, 1.25), (0.5, 1.7), (1.15, 1.9), (1.75, 1.75))):
        K.patch(p, "chips_ground", "stone_chips", P, gx, gy, 0.12 + 0.03 * (i % 2), 0.08)
    house = (0.1, 0.98, 0.14, 1.22)
    p.footprints = [house, (0.1, 0.98, 1.24, 1.94)]
    K.plinth(p, P, "plinth", house, h=0.2, mat="ashlar")
    K.walls(p, P, "walls", house, 0.2, 1.75, "ashlar")
    p.paint("walls", "ashlar_line", stripes={"axis": "y", "period": 0.25, "width": 0.05, "offset": 0.2})
    p.paint("walls", "ashlar_line", stripes={"axis": "x", "period": 0.45, "width": 0.05})
    p.paint("walls", "ashlar_line", stripes={"axis": "z", "period": 0.45, "width": 0.05})
    K.quoins(p, P, "quoins", house, 0.2, 1.75, step=0.36)
    roof = Gable(P, "house", house, "gx", 1.75, 3.15, over=0.22, end_over=0.2)
    roof.infill(p, "ashlar")
    p.paint("house_gable", "ashlar_line", stripes={"axis": "y", "period": 0.25, "width": 0.05, "offset": 0.2})
    roof.roof(p, "slate", "slate_dark", course=0.11, spots=("slate_light", 0.06, 0.12, 7))
    # Stone coping on the gable instead of bargeboards, and a finial cross of stone.
    zf = P.rect(*house)[3] + 0.24
    xc = roof.xc
    L = math.hypot(roof.hw + 0.22, (roof.hw + 0.22) * roof.slope) / 2
    for sgn in (-1, 1):
        p.add("coping", "ashlar", box([xc + sgn * (roof.hw + 0.22) / 2, 3.15 - (roof.hw + 0.22) / 2 * roof.slope + 0.08, zf - 0.04],
                                      [L, 0.08, 0.1], rot=[0, 0, -sgn * math.atan(roof.slope)]), "roof")
    p.add("coping", "ashlar", box([xc, 3.3, zf - 0.04], [0.05, 0.16, 0.05]), "roof")
    p.add("coping", "ashlar", box([xc, 3.34, zf - 0.04], [0.12, 0.04, 0.05]), "roof")
    K.chimney(p, P, "chimney", 0.4, 0.3, 2.4, 3.55, w=0.18, mat="ashlar", cap="ashlar")
    x0, x1, z0, z1 = P.rect(*house)
    K.door_right(p, P, "door", 0.68, z1, 0.2, w=0.56, h=1.0, arch=True, frame="ashlar")
    xd = P.m(0, 0.68)[0]
    p.add("carving", "ashlar", box([xd, 1.62, z1 + 0.05], [0.18, 0.1, 0.03]), "wall")
    p.add("carving_mark", "ashlar_line", box([xd, 1.62, z1 + 0.08], [0.1, 0.02, 0.01]), "wall", priority=3)
    p.add("carving_mark", "ashlar_line", box([xd, 1.62, z1 + 0.08], [0.02, 0.07, 0.01]), "wall", priority=3)
    K.window_right(p, P, 0.68, z1, 2.3, w=0.24, h=0.3, shutters=False)
    K.window_right(p, P, 0.3, z1, 1.0, w=0.26, h=0.36)
    K.window_left(p, P, 0.55, x0, 1.0, w=0.28, h=0.36)
    # The masons' lodge: an open slate lean-to on stone piers over a banker.
    lodge = (0.1, 0.98, 1.24, 1.94)
    K.lean_to(p, P, "lodge_roof", lodge, "-gy", 1.45, 1.72, "slate", "slate_dark", over=0.05, post_mat="timber")
    lx0, lx1, lz0, lz1 = P.rect(*lodge)
    bx, bz = (lx0 + lx1) / 2, (lz0 + lz1) / 2
    p.add("banker", "ashlar", box([bx, 0.3, bz], [0.22, 0.3, 0.32]), "prop")
    p.add("banker_top", "ashlar", box([bx, 0.62, bz], [0.26, 0.04, 0.38]), "prop")
    p.add("work_block", "stone", box([bx, 0.8, bz + 0.05], [0.18, 0.15, 0.24]), "prop")
    p.add("work_block_dressed", "ashlar", box([bx - 0.01, 0.8, bz + 0.3], [0.17, 0.14, 0.02]), "prop")
    p.add("mallet", "haft", cyl([bx - 0.1, 0.68, bz - 0.25], [bx - 0.1, 0.68, bz - 0.05], 0.02), "prop", priority=2)
    p.add("mallet", "post", cyl([bx - 0.1, 0.66, bz - 0.32], [bx - 0.1, 0.74, bz - 0.32], 0.07), "prop")
    p.add("chisels", "steel", box([bx + 0.12, 0.67, bz - 0.2], [0.02, 0.01, 0.1]), "prop", priority=2)
    # Shear legs over the yard's front corner with a block hanging on a chain.
    a, b = P.m(1.25, 1.95, 0.0), P.m(1.95, 1.4, 0.0)
    top = P.m(1.55, 1.6, 2.0)
    p.add("shear_legs", "post", cyl(a, top, 0.05), "prop", priority=2)
    p.add("shear_legs", "post", cyl(b, top, 0.05), "prop", priority=2)
    p.add("shear_legs", "post", cyl(P.m(1.1, 1.2, 0.0), top, 0.04), "prop", priority=2)
    p.add("chain", "iron", cyl(top, [top[0], 1.0, top[2]], 0.02), "prop", min_cover=1, priority=2)
    p.add("hook_block", "stone", box([top[0], 0.85, top[2]], [0.16, 0.13, 0.2]), "prop")
    p.add("windlass", "post", cyl(P.m(1.32, 1.85, 0.6), P.m(1.88, 1.48, 0.6), 0.06), "prop")
    p.paint("windlass", "rope", stripes={"axis": "y", "at": [0.6], "width": 0.08})
    # Rough blocks and a wedge on the stack tile's back edge (low), chips at the banker.
    for i, (gx, gy, s) in enumerate(((1.15, 0.12, 0.2), (1.45, 0.1, 0.16), (1.9, 0.35, 0.14))):
        x, _, z = P.m(gx, gy)
        p.add("rough_blocks", "stone", box([x, s, z], [s * 1.2, s, s], rot=[0, 0.3 * i, 0], round_=0.03), "prop")
    K.tufts(p, P, [(1.95, 0.95), (0.05, 1.97), (1.05, 0.1)])
    p.roofs = [roof]
    return P, p, 208, 1.8


# =================================================================================================
# Fishing hut: a weathered board hut on fieldstone under a heavy reed thatch with a smoke hood,
# a lean-to smokehouse with its own chimney, nets drying on poles, a rack of drying fish, an
# upturned boat on trestles, oars and creels.
# =================================================================================================
def fishing_hut():
    P, p = Plot(2), Parts()
    K.ground(P, p, seed=10)
    K.patch(p, "sand", "chips", P, 1.4, 1.55, 0.35, 0.2)
    house = (0.12, 0.96, 0.14, 1.25)
    p.footprints = [house, (0.12, 0.96, 1.25, 1.92)]
    K.plinth(p, P, "plinth", house, h=0.26, mat="fieldstone")
    K.board_walls(p, P, "walls", house, 0.26, 1.45, mat="weathered", period=0.17)
    x0, x1, z0, z1 = P.rect(*house)
    for (x, z) in ((x0, z0), (x0, z1), (x1, z1)):
        p.add("corner_posts", "timber", box([x, 0.85, z], [0.07, 0.62, 0.07]), "wall")
    roof = Gable(P, "house", house, "gy", 1.45, 3.05, over=0.36, end_over=0.3, thick=0.24)
    roof.infill(p, "weathered")
    roof.roof(p, "thatch", "thatch_dark", course=0.14, spots=("moss", 0.1, 0.14, 2))
    roof.bargeboards(p)
    # Smoke hood at the ridge: a little gabled cap over a vent.
    xc, zc = roof.xc, roof.zc
    p.add("smoke_hood", "thatch_dark", box([xc + 0.3, 3.12, zc], [0.18, 0.1, 0.22]), "roof")
    p.add("smoke_hood_hole", "dark_hole", box([xc + 0.11, 3.1, zc], [0.02, 0.06, 0.14]), "roof")
    K.door_right(p, P, "door", 0.98, z1, 0.26, w=0.5, h=0.95, arch=False, mat="weathered")
    K.window_right(p, P, 0.45, z1, 0.95, w=0.28, h=0.3, open_=False)
    K.window_left(p, P, 0.54, x0, 2.0, w=0.24, h=0.24, shutters=False)
    # Oars and a boat hook against the right wall.
    for i, gy in enumerate((0.7, 0.76)):
        a, b = P.m(1.0, gy, 0.0), P.m(0.98, gy - 0.05, 1.5)
        p.add("oars", "haft", cyl(a, b, 0.025), "prop", priority=2, min_cover=2)
        p.add("oar_blades", "haft", box([a[0], 0.2, a[2]], [0.05, 0.2, 0.015]), "prop", priority=2)
    # Smokehouse lean-to in front of the gable, its door open, a fish-smoke chimney.
    smoke = (0.12, 0.96, 1.27, 1.9)
    K.walls(p, P, "smokehouse", smoke, 0.0, 1.05, "fieldstone")
    p.paint("smokehouse", "stone_dark", spots={"scale": 0.07, "density": 0.4, "seed": 9})
    K.lean_to(p, P, "smoke_roof", smoke, "-gy", 1.1, 1.45, "thatch", "thatch_dark", over=0.12, posts=False)
    K.chimney(p, P, "smoke_chimney", 0.3, 1.45, 0.9, 1.95, w=0.14, mat="fieldstone", cap="fieldstone")
    sx0, sx1, sz0, sz1 = P.rect(*smoke)
    K.door_right(p, P, "smoke_door", 1.6, sz1, 0.0, w=0.4, h=0.7, arch=False, mat="weathered")
    # Net drying on two poles at the front-left edge.
    a, b = P.m(0.05, 1.98), P.m(0.95, 1.98)
    for q in (a, b):
        p.add("net_poles", "post", cyl([q[0] - 0.1, 0, q[2]], [q[0] - 0.1, 1.25, q[2]], 0.04), "prop")
    p.add("net_line", "rope", cyl([a[0] - 0.1, 1.2, a[2]], [b[0] - 0.1, 1.2, b[2]], 0.02), "prop", min_cover=1)
    p.add("net", "net", box([a[0] - 0.12, 0.78, (a[2] + b[2]) / 2], [0.015, 0.42, abs(b[2] - a[2]) / 2 - 0.08]), "prop")
    p.paint("net", "ink", grid={"axes": ["y", "z"], "spacing": [0.12, 0.12], "r": 0.03})
    for i in range(5):
        z = a[2] + 0.2 + i * (b[2] - a[2] - 0.4) / 4
        p.add("net_floats", "barrel_lid", sph([a[0] - 0.14, 1.12, z], 0.045), "prop")
    # A rack of drying fish at the yard's right edge.
    r0, r1 = P.m(1.92, 1.1), P.m(1.92, 1.75)
    for q in (r0, r1):
        p.add("rack", "post", cyl([q[0], 0, q[2]], [q[0], 1.0, q[2]], 0.04), "prop")
    p.add("rack", "post", cyl([r0[0], 0.98, r0[2]], [r1[0], 0.98, r1[2]], 0.03), "prop")
    for i in range(6):
        x = r0[0] + (r1[0] - r0[0]) * (i + 0.5) / 6
        p.add("dried_fish", "fish", ell([x, 0.78, r0[2]], [0.05, 0.16, 0.03]), "prop")
    # Upturned boat on trestles at the stack tile's back edge.
    bx0, bx1 = P.m(1.15, 0.12), P.m(1.95, 0.12)
    cx, cz = (bx0[0] + bx1[0]) / 2, bx0[2] + (bx1[2] - bx0[2]) / 2
    for t in (bx0[2] + 0.35, bx1[2] - 0.35):
        p.add("trestles", "post", box([cx, 0.2, t], [0.22, 0.2, 0.04]), "prop")
    p.add("boat", "board", ell([cx, 0.42, cz], [0.32, 0.28, 0.95]), "prop")
    p.cut("boat", plane([0, -1, 0], [0, 0.42, 0]))
    p.paint("boat", "ink", stripes={"axis": "y", "period": 0.09, "width": 0.05, "offset": 0.42})
    p.add("keel", "timber", box([cx, 0.71, cz], [0.03, 0.02, 0.92]), "prop")
    # Creels and a barrel of salted fish by the door.
    for gx, gy in ((1.12, 1.35), (1.25, 1.42)):
        x, _, z = P.m(gx, gy)
        p.add("creels", "wicker", cone([x, 0, z], [x, 0.32, z], 0.13, 0.16), "prop")
        p.add("creel_fish", "fish", ell([x, 0.33, z], [0.12, 0.04, 0.12]), "prop")
    p.paint("creels", "log_groove", stripes={"axis": "y", "period": 0.08, "width": 0.055})
    K.barrel(p, P, 1.12, 1.92, r=0.18, h=0.45)
    K.tufts(p, P, [(1.95, 0.9), (0.08, 0.1), (1.6, 1.95)])
    p.roofs = [roof]
    return P, p, 208, 1.75


# =================================================================================================
# Mine: an adit driven into a rocky knoll that fills the back of the plot: a timbered portal with
# a dark mouth and a lantern, rails out to a tipped cart, an ore heap, a pile of pit props, a
# small miners' hut with a shingle roof built against the rock, a windlass for the waste bucket.
# =================================================================================================
def mine():
    P, p = Plot(2), Parts()
    K.ground(P, p, mat="earth", seed=12)
    K.patch(p, "ore_dust", "ore", P, 1.35, 0.9, 0.3, 0.2, y=0.013)
    knoll = [(0.35, 0.35, 0.5, 1.1, 1.3, 1.0), (0.55, 0.9, 0.3, 1.0, 1.0, 0.9), (0.2, 1.05, 0.2, 0.9, 0.85, 0.8),
             (0.55, 0.25, 1.2, 0.8, 1.0, 0.8), (0.2, 0.55, 1.4, 0.7, 0.9, 0.6), (0.85, 0.5, 0.2, 0.6, 0.7, 0.6),
             (0.15, 0.2, 1.9, 0.5, 0.55, 0.5)]
    K.mound(p, P, "knoll", knoll, mat="fieldstone", layer="found")
    for i, (gx, gy, y, hx, hy, hz, ry, rz) in enumerate((
            (0.95, 0.25, 0.35, 0.35, 0.35, 0.3, 0.4, 0.15), (0.9, 1.0, 0.3, 0.3, 0.3, 0.35, -0.3, -0.1),
            (0.65, 0.7, 1.1, 0.3, 0.25, 0.4, 0.8, 0.2), (0.3, 1.2, 0.7, 0.4, 0.3, 0.3, 0.2, -0.2),
            (0.75, 0.15, 1.3, 0.25, 0.25, 0.3, -0.6, 0.3), (0.4, 0.95, 1.5, 0.3, 0.22, 0.25, 0.5, 0.1))):
        x, _, z = P.m(gx, gy)
        p.add("crags", "fieldstone", box([x, y, z], [hx, hy, hz], rot=[0.1 * i, ry, rz], round_=0.04), "found")
    p.paint("crags", "stone_dark", stripes={"axis": "y", "period": 0.16, "width": 0.055})
    for gx, gy, y, r in ((0.3, 0.35, 2.15, 0.4), (0.15, 0.85, 1.55, 0.35), (0.55, 0.25, 2.0, 0.3)):
        x, _, z = P.m(gx, gy)
        p.add("knoll_turf", "turf", ell([x, y, z], [r, r * 0.4, r]), "found", blend=0.1)
    for i, (gx, gy, y) in enumerate(((0.75, 0.35, 1.6), (0.3, 1.1, 1.25), (0.85, 0.85, 0.85))):
        x, _, z = P.m(gx, gy)
        p.add("bushes", "leaves", ell([x, y, z], [0.26, 0.2, 0.26]), "found", blend=0.05)
        p.add("bushes", "leaves", ell([x + 0.15, y - 0.05, z + 0.12], [0.18, 0.15, 0.18]), "found", blend=0.05)
    p.paint("bushes", "leaves_dark", spots={"scale": 0.08, "density": 0.3, "seed": 3})
    p.footprints = [(0.1, 1.0, 0.15, 1.2), (0.1, 0.9, 1.25, 1.92)]
    # Timbered portal in the knoll, facing the work yard (right face, game x ~1.05).
    gy_p = 0.62
    xp = P.m(0, gy_p)[0]
    zp = P.m(1.05, 0)[2]
    p.add("mouth", "dark_hole", box([xp, 0.6, zp - 0.15], [0.42, 0.6, 0.3]), "wall")
    for sx in (-1, 1):
        p.add("portal", "timber", box([xp + sx * 0.48, 0.66, zp + 0.05], [0.08, 0.66, 0.08]), "wall")
    p.add("portal", "timber", box([xp, 1.36, zp + 0.06], [0.66, 0.1, 0.1]), "wall")
    p.add("portal", "timber", box([xp, 1.36, zp + 0.06], [0.06, 0.06, 0.06]), "wall")
    for sx in (-1, 1):
        p.add("portal_braces", "timber", box([xp + sx * 0.36, 1.18, zp + 0.07], [0.16, 0.04, 0.04], rot=[0, 0, -sx * 0.7]), "wall")
    p.add("portal_roof", "shingle", box([xp, 1.55, zp + 0.18], [0.75, 0.05, 0.32], rot=[0.35, 0, 0]), "roof")
    p.paint("portal_roof", "shingle_dark", stripes={"axis": "z", "period": 0.1, "width": 0.055})
    K.lantern(p, P, gy_p + 0.28, zp + 0.06, 1.15)
    # Rails from the mouth to the yard and a cart tipped over the ore heap.
    for sx in (-0.17, 0.17):
        p.add("rails", "iron", box([xp + sx, 0.04, zp + 0.55], [0.025, 0.025, 0.85]), "prop")
    for i in range(7):
        p.add("sleepers", "post", box([xp, 0.02, zp - 0.1 + i * 0.25], [0.27, 0.02, 0.05]), "prop")
    x, _, z = P.m(1.55, gy_p)
    p.add("tub", "board", box([x, 0.42, z], [0.25, 0.2, 0.32]), "prop")
    p.paint("tub", "iron", stripes={"axis": "z", "at": [z - 0.25, z + 0.25], "width": 0.06})
    p.add("tub_ore", "ore", ell([x, 0.6, z], [0.22, 0.1, 0.28]), "prop")
    for sz in (-0.2, 0.2):
        for sx in (-0.17, 0.17):
            p.add("tub_wheels", "iron", cyl([x + sx - 0.03, 0.12, z + sz], [x + sx + 0.03, 0.12, z + sz], 0.1), "prop")
    # Ore heap on the yard's back edge (the stack tile keeps its middle free).
    x, _, z = P.m(1.25, 0.15)
    p.add("ore_heap", "ore", ell([x, 0.1, z], [0.38, 0.32, 0.38]), "prop", blend=0.06)
    p.add("ore_heap", "ore", ell([x - 0.2, 0.05, z + 0.25], [0.25, 0.2, 0.25]), "prop", blend=0.06)
    p.paint("ore_heap", "stone_dark", spots={"scale": 0.05, "density": 0.35, "seed": 3})
    # Miners' hut against the knoll at the front-left: log walls, shingle lean-to, door to the yard.
    hut = (0.12, 0.9, 1.3, 1.92)
    K.log_walls(p, P, "hut", hut, 0.0, 1.2, course=0.18)
    K.lean_to(p, P, "hut_roof", hut, "-gy", 1.2, 1.65, "shingle", "shingle_dark", over=0.12, posts=False)
    hx0, hx1, hz0, hz1 = P.rect(*hut)
    K.door_right(p, P, "hut_door", 1.55, hz1, 0.0, w=0.42, h=0.9, arch=False)
    K.window_left(p, P, 0.5, hx0, 0.7, w=0.24, h=0.24)
    K.chimney(p, P, "hut_chimney", 0.2, 1.55, 1.2, 2.05, w=0.12)
    # Pit props stacked against the hut's left face, their cut ends to the camera.
    for k in range(3):
        y = 0.09 + k * 0.15
        for j in range(4 - k):
            pa = P.m(0.2 + j * 0.17 + k * 0.08, 1.95, y)
            p.add("pit_props", "log_bark", cyl([pa[0] - 0.12, y, pa[2]], [pa[0], y, pa[2]], 0.075), "prop")
            p.add("pit_props_ends", "log_end", cyl([pa[0] - 0.13, y, pa[2]], [pa[0] - 0.12, y, pa[2]], 0.068), "prop")
    # Picks and a shovel leaning by the portal.
    for i, gy in enumerate((gy_p + 0.4, gy_p + 0.46)):
        a, b = P.m(1.1, gy, 0.0), P.m(1.07, gy, 1.0)
        p.add("pick_hafts", "haft", cyl(a, b, 0.025), "prop", priority=2, min_cover=2)
        p.add("pick_heads", "iron", box([b[0], 0.98, b[2]], [0.03, 0.03, 0.18], rot=[0.2, 0, 0]), "prop", priority=2)
    K.tufts(p, P, [(1.92, 0.08), (1.95, 1.9), (1.4, 1.95)])
    K.stones(p, P, [(1.8, 1.3), (1.6, 1.85), (1.15, 1.75), (1.9, 0.6)])
    p.roofs = []
    return P, p, 224, 1.9


# =================================================================================================
# Clay pit: a dug pit with layered clay banks and a pool at the bottom, a plank ramp, a well sweep
# to bail the water, clay blocks drying on boards, a turf-roofed digger's hut, a barrow of clay.
# =================================================================================================
def clay_pit():
    P, p = Plot(2), Parts()
    K.ground(P, p, seed=14)
    pit = (0.08, 1.02, 0.1, 1.2)
    x0, x1, z0, z1 = P.rect(*pit)
    p.footprints = [pit, (0.12, 0.92, 1.3, 1.92)]
    p.add("pit_floor", "clay_dark", box([(x0 + x1) / 2, 0.015, (z0 + z1) / 2], [(x1 - x0) / 2, 0.012, (z1 - z0) / 2]), "ground")
    # Banks on the back and left sides, cut in layers; low lips on the open sides.
    p.add("banks", "clay", box([x1 - 0.25, 0.42, (z0 + z1) / 2], [0.28, 0.42, (z1 - z0) / 2]), "found")
    p.add("banks", "clay", box([(x0 + x1) / 2, 0.42, z0 + 0.25], [(x1 - x0) / 2, 0.42, 0.28]), "found")
    p.add("banks", "clay", box([x0 + 0.08, 0.1, (z0 + z1) / 2], [0.12, 0.1, (z1 - z0) / 2]), "found")
    p.add("banks", "clay", box([(x0 + x1) / 2, 0.1, z1 - 0.08], [(x1 - x0) / 2, 0.1, 0.12]), "found")
    p.paint("banks", "clay_dark", stripes={"axis": "y", "period": 0.17, "width": 0.055})
    p.add("bank_turf", "turf", box([x1 - 0.25, 0.86, (z0 + z1) / 2], [0.3, 0.04, (z1 - z0) / 2 + 0.02]), "found")
    p.add("bank_turf", "turf", box([(x0 + x1) / 2, 0.86, z0 + 0.25], [(x1 - x0) / 2 + 0.02, 0.04, 0.3]), "found")
    p.add("pool", "water", box([(x0 + x1) / 2 - 0.2, 0.035, (z0 + z1) / 2 - 0.2], [0.5, 0.01, 0.55]), "ground")
    # Spade marks: a stepped dig in the back bank.
    p.add("steps_dug", "clay", box([x1 - 0.6, 0.22, (z0 + z1) / 2 + 0.3], [0.12, 0.22, 0.35]), "found")
    # Plank ramp out of the pit to the work yard.
    a, b = P.m(0.55, 0.85, 0.04), P.m(1.25, 0.85, 0.12)
    L = math.dist(a, b) / 2
    p.add("ramp", "board", box([(a[0] + b[0]) / 2, 0.1, (a[2] + b[2]) / 2], [0.18, 0.03, L], rot=[-0.06, 0, 0]), "prop")
    p.paint("ramp", "ink", stripes={"axis": "z", "period": 0.16, "width": 0.055})
    # The well sweep: a forked post, a long beam with a counterweight stone and a bucket on a pole.
    px, _, pz = P.m(1.1, 0.12)
    p.add("sweep_post", "log_bark", cyl([px, 0, pz], [px, 1.5, pz], 0.08), "prop")
    tip = [px - 1.2, 2.3, pz - 0.2]
    tail = [px + 0.8, 0.95, pz + 0.13]
    p.add("sweep_beam", "post", cyl(tail, tip, 0.045), "prop", priority=2)
    p.add("sweep_weight", "stone", ell(tail, [0.16, 0.14, 0.16]), "prop")
    bucket_y = 0.6
    p.add("sweep_pole", "post", cyl(tip, [tip[0], bucket_y + 0.25, tip[2]], 0.025), "prop", priority=2, min_cover=1)
    p.add("sweep_bucket", "barrel", cyl([tip[0], bucket_y, tip[2]], [tip[0], bucket_y + 0.24, tip[2]], 0.12), "prop")
    p.paint("sweep_bucket", "iron", stripes={"axis": "y", "at": [bucket_y + 0.05, bucket_y + 0.19], "width": 0.04})
    # Digger's hut: wattle and daub under a turf roof at the front-left.
    hut = (0.12, 0.92, 1.32, 1.92)
    K.plinth(p, P, "hut_plinth", hut, h=0.15, mat="fieldstone")
    K.walls(p, P, "hut", hut, 0.15, 1.1, "plaster")
    hx0, hx1, hz0, hz1 = P.rect(*hut)
    K.timber_left(p, P, "hut_frame", hut, 0.15, 1.1, 2, braces=True)
    K.timber_right(p, P, "hut_frame", hut, 0.15, 1.1, 2, braces=False)
    hroof = Gable(P, "hut", hut, "gx", 1.1, 2.0, over=0.2, end_over=0.18, thick=0.2, flare=False)
    hroof.infill(p, "board")
    hroof.roof(p, "turf", "leaves_dark", course=0.2, spots=("bloom", 0.04, 0.08, 3))
    K.door_right(p, P, "hut_door", 1.62, hz1, 0.15, w=0.42, h=0.78, arch=False)
    K.window_left(p, P, 0.52, hx0, 0.65, w=0.22, h=0.22)
    # Clay blocks drying on boards along the yard's right edge, a heap of fresh clay and a barrow.
    for row in range(2):
        a = P.m(1.88 - row * 0.2, 1.2)
        b = P.m(1.88 - row * 0.2, 1.85)
        p.add("drying_boards", "board", box([a[0] - (b[0] - a[0]) * 0 + (b[0] - a[0]) / 2, 0.05, a[2]],
                                            [abs(b[0] - a[0]) / 2, 0.03, 0.12]), "prop")
        for i in range(5):
            x = a[0] + (b[0] - a[0]) * (i + 0.5) / 5
            p.add("clay_blocks", "clay", box([x, 0.15, a[2]], [0.08, 0.07, 0.1]), "prop")
    x, _, z = P.m(1.3, 1.85)
    p.add("clay_heap", "clay", ell([x, 0.05, z], [0.32, 0.3, 0.3]), "prop", blend=0.05)
    p.paint("clay_heap", "clay_dark", spots={"scale": 0.06, "density": 0.3, "seed": 2})
    a, b = P.m(1.42, 1.78, 0.0), P.m(1.45, 1.7, 0.9)
    p.add("spade_h", "haft", cyl([a[0], 0.2, a[2]], b, 0.025), "prop", priority=2, min_cover=2)
    p.add("spade_b", "steel", box([a[0], 0.18, a[2]], [0.08, 0.1, 0.015]), "prop", priority=2)
    K.wheelbarrow(p, P, 1.2, 1.35, yaw=0.9, load=clay_load)
    K.tufts(p, P, [(1.95, 0.6), (1.6, 0.1), (0.05, 1.98)])
    p.roofs = [hroof]
    return P, p, 208, 1.7


def clay_load(p, c):
    p.add("barrow_clay", "clay", ell([c[0], c[1] - 0.02, c[2]], [0.28, 0.12, 0.2]), "prop")


# =================================================================================================
# Farm: a big plank barn under a half-hipped thatch with its double door and a hay loft towards the
# yard, a weather vane, a granary on staddle stones with steps, a cart with sheaves, a pitchfork, a
# flail and a dovecote on a pole.
# =================================================================================================
def farm():
    P, p = Plot(2), Parts()
    K.ground(P, p, seed=16)
    K.patch(p, "straw_ground", "thatch", P, 1.35, 1.5, 0.3, 0.2)
    barn = (0.08, 1.0, 0.1, 1.28)
    p.footprints = [barn, (0.2, 0.85, 1.45, 1.9)]
    K.plinth(p, P, "plinth", barn, h=0.22, mat="fieldstone")
    K.board_walls(p, P, "barn", barn, 0.22, 1.6, mat="board", period=0.18)
    x0, x1, z0, z1 = P.rect(*barn)
    K.timber_right(p, P, "barn_frame", barn, 0.22, 1.6, 4, braces=True)
    K.timber_left(p, P, "barn_frame", barn, 0.22, 1.6, 2, braces=True)
    roof = Gable(P, "barn", barn, "gx", 1.6, 3.35, over=0.32, end_over=0.24, thick=0.26)
    roof.infill(p, "board")
    roof.roof(p, "thatch", "thatch_dark", course=0.15, spots=("moss", 0.1, 0.16, 8))
    # Half hip: cut the top of the gable towards the yard.
    p.cut("barn_roof", plane([0, 0.7, 0.7], [0, 2.85, z1 + 0.1]))
    p.cut("barn_gable", plane([0, 0.7, 0.7], [0, 2.85, z1 + 0.05]))
    # Great double door on the gable end, a loft hatch with hay.
    xd = P.m(0, 0.68)[0]
    p.add("barn_door", "door_wood", box([xd, 0.95, z1 + 0.04], [0.56, 0.73, 0.04]), "wall")
    p.paint("barn_door", "ink", stripes={"axis": "x", "at": [xd], "width": 0.06})
    p.paint("barn_door", "ink", stripes={"axis": "x", "period": 0.14, "width": 0.04})
    for sx in (-1, 1):
        p.add("barn_door_brace", "timber", box([xd + sx * 0.28, 0.95, z1 + 0.09], [0.32, 0.04, 0.02], rot=[0, 0, sx * 1.0]), "wall")
        p.add("barn_door_iron", "iron", box([xd + sx * 0.4, 0.5, z1 + 0.09], [0.14, 0.03, 0.02]), "wall")
        p.add("barn_door_iron", "iron", box([xd + sx * 0.4, 1.4, z1 + 0.09], [0.14, 0.03, 0.02]), "wall")
    p.add("loft", "dark_hole", box([xd, 2.05, z1 + 0.02], [0.24, 0.24, 0.03]), "wall")
    p.add("loft_hay", "hay", ell([xd, 1.88, z1 + 0.1], [0.24, 0.1, 0.1]), "wall", blend=0.04)
    p.add("loft_beam", "timber", box([xd, 2.48, z1 + 0.3], [0.05, 0.05, 0.36]), "wall")
    p.add("loft_rope", "rope", cyl([xd, 2.45, z1 + 0.6], [xd, 1.7, z1 + 0.6], 0.02), "wall", min_cover=1)
    K.window_left(p, P, 0.55, x0, 1.0, w=0.26, h=0.28, open_=False)
    # Vane on the ridge (a cockerel).
    vx = roof.xc
    p.add("vane", "iron", cyl([vx, 3.35, (z0 + z1) / 2], [vx, 3.85, (z0 + z1) / 2], 0.025), "roof", priority=2, min_cover=2)
    p.add("vane", "iron", ext([vx, 3.85, (z0 + z1) / 2], [[-0.14, 0], [0.12, 0], [0.16, 0.14], [0.05, 0.08], [-0.06, 0.18],
                                                         [-0.12, 0.08]], 0.03), "roof", priority=2)
    # The granary on staddle stones in front.
    gr = (0.25, 0.85, 1.45, 1.9)
    gx0, gx1, gz0, gz1 = P.rect(*gr)
    for (x, z) in ((gx0 + 0.1, gz0 + 0.1), (gx0 + 0.1, gz1 - 0.1), (gx1 - 0.1, gz1 - 0.1), (gx1 - 0.1, gz0 + 0.1)):
        p.add("staddles", "stone", cone([x, 0, z], [x, 0.36, z], 0.08, 0.05), "found")
        p.add("staddle_caps", "stone", cyl([x, 0.36, z], [x, 0.42, z], 0.15), "found")
    K.board_walls(p, P, "granary", gr, 0.42, 1.25, mat="board", period=0.15)
    K.timber_left(p, P, "granary_frame", gr, 0.42, 1.25, 2, braces=True)
    groof = Gable(P, "granary", gr, "gy", 1.25, 1.95, over=0.16, end_over=0.14, thick=0.14)
    groof.infill(p, "board")
    groof.roof(p, "shingle", "shingle_dark", course=0.12)
    K.door_right(p, P, "granary_door", 1.67, gz1, 0.42, w=0.3, h=0.55, arch=False)
    for i in range(3):
        x = P.m(0, 1.67)[0]
        p.add("granary_steps", "stone", box([x, 0.07 + i * 0.12, gz1 + 0.42 - i * 0.12], [0.18, 0.06, 0.1]), "found")
    # Cart with sheaves on the stack tile's back edge (low), a pitchfork and a flail.
    K.cart(p, P, 1.45, 0.25, yaw=-1.5708, load=sheaf_load)
    a, b = P.m(1.05, 1.42, 0.0), P.m(1.04, 1.32, 1.35)
    p.add("pitchfork", "haft", cyl(a, b, 0.025), "prop", priority=2, min_cover=2)
    p.add("pitchfork_tines", "iron", box([b[0], 1.42, b[2]], [0.02, 0.1, 0.08]), "prop", priority=2)
    for i, gx in enumerate((1.25, 1.4)):
        x, _, z = P.m(gx, 1.88)
        p.add("sheaves", "hay", cone([x, 0, z], [x, 0.5, z], 0.16, 0.09), "prop")
        p.add("sheaf_ties", "rope", tor([x, 0.28, z], 0.12, 0.025), "prop")
    p.paint("sheaves", "thatch_dark", stripes={"axis": "x", "period": 0.06, "width": 0.055})
    # A dovecote on a pole by the yard's right edge.
    x, _, z = P.m(1.92, 1.25)
    p.add("dovecote_pole", "post", cyl([x, 0, z], [x, 1.7, z], 0.05), "prop")
    p.add("dovecote", "plaster", box([x, 1.88, z], [0.18, 0.2, 0.18]), "prop")
    p.add("dovecote_holes", "dark_hole", box([x - 0.19, 1.92, z], [0.01, 0.04, 0.1]), "prop")
    K.cone_roof(p, P, "dovecote_roof", 1.92, 1.25, 2.06, 0.3, 0.35, "shingle", "shingle_dark", course=0.1)
    K.tufts(p, P, [(1.95, 0.55), (0.04, 1.97), (1.62, 1.95), (1.05, 0.05)])
    p.roofs = [roof, groof]
    return P, p, 224, 1.95


def sheaf_load(p, c):
    for i, dz in enumerate((-0.2, 0.0, 0.2)):
        p.add("cart_sheaves", "hay", ell([c[0], c[1] + 0.15 + 0.05 * (i % 2), c[2] + dz], [0.38, 0.14, 0.12]), "prop")
    p.add("cart_sheaves", "hay", ell([c[0], c[1] + 0.35, c[2]], [0.36, 0.13, 0.13]), "prop")
    p.paint("cart_sheaves", "thatch_dark", stripes={"axis": "x", "period": 0.25, "width": 0.055})


# =================================================================================================
# Hop farm: an oast house, a round brick kiln with a steep conical roof and a white cowl, joined to
# a half-timbered drying barn with a loading door, a hoist beam and a hop pocket on the rope;
# bundled hop poles, long pockets of hops and baskets of green cones in the yard.
# =================================================================================================
def hop_farm():
    P, p = Plot(2), Parts()
    K.ground(P, p, seed=18)
    K.patch(p, "grass_patch", "grass", P, 1.6, 0.3, 0.25, 0.2)
    barn = (0.1, 0.96, 0.12, 1.15)
    p.footprints = [barn, (0.15, 0.9, 1.2, 1.9)]
    K.plinth(p, P, "plinth", barn, h=0.2, mat="brick")
    K.walls(p, P, "barn", barn, 0.2, 1.0, "brick")
    p.paint("barn", "brick_line", stripes={"axis": "y", "period": 0.12, "width": 0.035})
    x0, x1, z0, z1 = P.rect(*barn)
    up = (0.08, 0.98, 0.1, 1.17)
    p.add("jetty", "timber", box([(x0 + x1) / 2, 1.04, (z0 + z1) / 2], [(x1 - x0) / 2 + 0.1, 0.05, (z1 - z0) / 2 + 0.1]), "wall")
    K.walls(p, P, "upper", up, 1.08, 1.95, "plaster")
    K.timber_right(p, P, "upper_frame", up, 1.08, 1.95, 4)
    K.timber_left(p, P, "upper_frame", up, 1.08, 1.95, 2)
    roof = Gable(P, "barn", up, "gy", 1.95, 3.2, over=0.28, end_over=0.22)
    roof.infill(p, "plaster")
    roof.gable_frame(p)
    roof.roof(p, "tile", "tile_dark", course=0.13)
    roof.bargeboards(p)
    zr = P.rect(*up)[3]
    # Loading door on the upper floor with a hoist beam and a pocket on the rope.
    xd = P.m(0, 0.6)[0]
    p.add("loading_door", "door_wood", box([xd, 1.5, zr + 0.04], [0.26, 0.36, 0.04]), "wall")
    p.paint("loading_door", "ink", stripes={"axis": "x", "period": 0.12, "width": 0.04})
    p.add("hoist", "timber", box([xd, 2.15, zr + 0.35], [0.05, 0.05, 0.4]), "wall")
    p.add("hoist_rope", "rope", cyl([xd, 2.1, zr + 0.68], [xd, 1.05, zr + 0.68], 0.02), "wall", min_cover=1)
    p.add("pocket_hung", "sack", ell([xd, 0.82, zr + 0.68], [0.14, 0.26, 0.14]), "prop")
    K.door_right(p, P, "door", 0.98, z1, 0.2, w=0.44, h=0.78, arch=True)
    K.window_right(p, P, 0.3, z1, 0.6, w=0.24, h=0.28)
    K.window_left(p, P, 0.54, P.rect(*up)[0], 1.55, w=0.28, h=0.32)
    # The round kiln in front, its cone and cowl.
    kx, ky = 0.55, 1.56
    x, _, z = P.m(kx, ky)
    r = 0.62
    p.add("kiln", "brick", cyl([x, 0, z], [x, 1.9, z], r), "wall")
    p.paint("kiln", "brick_line", stripes={"axis": "y", "period": 0.12, "width": 0.035})
    p.add("kiln_band", "stone", cyl([x, 1.9, z], [x, 1.98, z], r + 0.05), "wall")
    K.cone_roof(p, P, "kiln_roof", kx, ky, 1.95, r + 0.1, 1.55, "tile", "tile_dark", course=0.13)
    p.add("cowl", "plaster", cyl([x, 3.35, z], [x, 3.75, z], 0.16), "roof")
    p.add("cowl", "plaster", box([x - 0.05, 3.75, z + 0.06], [0.2, 0.12, 0.2], rot=[0, 0.8, 0.5]), "roof")
    p.add("cowl_vane", "door_wood", box([x - 0.25, 3.8, z - 0.15], [0.2, 0.03, 0.03], rot=[0, 0.8, 0]), "roof")
    p.add("kiln_door", "door_wood", box([x - 0.05, 0.42, z + r - 0.02], [0.18, 0.42, 0.06]), "wall")
    p.add("kiln_door_arch", "brick", box([x - 0.05, 0.9, z + r], [0.24, 0.06, 0.06]), "wall")
    # Hop poles in a tied bundle against the barn, pockets of hops, baskets of green cones.
    for i in range(7):
        a = P.m(1.02, 0.18 + i * 0.03, 0.0)
        b = P.m(1.0, 0.28 + i * 0.015, 2.1 + 0.04 * (i % 3))
        p.add("hop_poles", "post", cyl([a[0], 0, a[2] + 0.05 * (i % 2)], b, 0.03), "prop", priority=2)
    p.add("hop_poles_tie", "rope", tor(P.m(1.0, 0.27, 1.2), 0.12, 0.025), "prop")
    for i, gy in enumerate((1.3, 1.52)):
        x, _, z = P.m(1.15, gy)
        p.add("pockets", "sack", cyl([x, 0.17, z - 0.25], [x, 0.17, z + 0.25], 0.17), "prop")
        p.add("pocket_mark", "paint_red", box([x - 0.17, 0.2, z], [0.01, 0.06, 0.06]), "prop", priority=2)
    p.add("pocket_up", "sack", cyl(P.m(1.25, 1.42, 0.34), P.m(1.25, 1.42, 0.9), 0.15), "prop")
    for gx, gy in ((1.6, 1.88), (1.85, 1.62)):
        x, _, z = P.m(gx, gy)
        p.add("baskets", "wicker", cone([x, 0, z], [x, 0.3, z], 0.17, 0.21), "prop")
        p.add("green_hops", "hop_green", ell([x, 0.32, z], [0.19, 0.08, 0.19]), "prop")
        p.paint("green_hops", "leaves_dark", spots={"scale": 0.03, "density": 0.3, "seed": 2})
    p.paint("baskets", "log_groove", stripes={"axis": "y", "period": 0.08, "width": 0.055})
    K.tufts(p, P, [(1.95, 0.9), (0.05, 1.97), (1.55, 1.05)])
    p.roofs = [roof]
    return P, p, 224, 1.95


# =================================================================================================
# Charcoal burner: a big turf-covered clamp smoking at its vents with a ladder on it, the collier's
# conical hut of poles and bark, cordwood stacked at the back, a rake, sacks and a basket of charcoal.
# The worker tends the clamp from the work yard (spot "kiln").
# =================================================================================================
def charcoal_burner():
    P, p = Plot(2), Parts()
    K.ground(P, p, mat="earth", seed=20)
    K.patch(p, "char_dust", "charcoal", P, 0.75, 1.3, 0.55, 0.45, y=0.013)
    p.footprints = [(0.15, 0.95, 0.9, 1.85), (0.1, 0.9, 0.1, 0.8)]
    # The clamp: a dome of turf and earth with dark vents and curls of smoke.
    cx, _, cz = P.m(0.62, 1.32)
    p.add("clamp", "turf", ell([cx, 0.0, cz], [1.0, 1.0, 0.95]), "wall")
    p.cut("clamp", plane([0, -1, 0], [0, 0.0, 0]))
    p.paint("clamp", "soil", spots={"scale": 0.1, "density": 0.25, "seed": 7})
    p.add("clamp_ring", "soil", tor([cx, 0.05, cz], 0.98, 0.1), "wall")
    for i, (ang, y) in enumerate(((0.3, 0.55), (1.2, 0.5), (2.0, 0.62), (0.8, 0.85))):
        vx, vz = cx - math.cos(ang) * 0.82 * math.cos(y), cz + math.sin(ang) * 0.82 * math.cos(y)
        p.add("vents", "dark_hole", sph([vx, y + 0.15, vz], 0.07), "prop")
        if i % 2 == 0:
            K.wisp(p, [vx - 0.05, y + 0.25, vz], 0.55, i)
    K.wisp(p, [cx, 1.05, cz], 0.9, 7)
    K.ladder(p, P, (1.12, 1.25, 0.0), (0.75, 1.25, 0.98), w=0.3)
    # The collier's hut: a cone of poles with bark slabs, a dark doorway.
    hx, hy = 0.42, 0.42
    x, _, z = P.m(hx, hy)
    p.add("hut", "log_bark", {"revolve": {"c": [round(x, 4), 0, round(z, 4)], "profile": {"polygon": [[0, 0], [0.75, 0], [0, 2.1]]}}}, "wall")
    p.paint("hut", "brush", stripes={"axis": "y", "period": 0.2, "width": 0.055})
    p.paint("hut", "turf", spots={"scale": 0.1, "density": 0.2, "seed": 2})
    for k in range(6):
        ang = k * math.pi / 3 + 0.3
        p.add("hut_poles", "post", cyl([x + math.cos(ang) * 0.1, 1.95, z + math.sin(ang) * 0.1],
                                        [x + math.cos(ang) * 0.25, 2.45, z + math.sin(ang) * 0.25], 0.03), "roof", min_cover=2)
    p.add("hut_door", "dark_hole", ext([x + 0.1, 0.0, z + 0.62], [[-0.2, 0], [0.2, 0], [0.0, 0.75]], 0.1), "wall")
    # Cordwood stacked along the back edges, a rake, sacks, a basket of charcoal.
    K.woodpile(p, P, "cordwood", 1.05, 1.95, 0.12, 4, r=0.09, along="gy")
    x, _, z = P.m(1.25, 1.85)
    p.add("charcoal_basket", "wicker", cone([x, 0, z], [x, 0.3, z], 0.18, 0.22), "prop")
    p.paint("charcoal_basket", "log_groove", stripes={"axis": "y", "period": 0.08, "width": 0.055})
    p.add("charcoal_pile", "charcoal", ell([x, 0.32, z], [0.2, 0.09, 0.2]), "prop")
    K.sack(p, P, 1.5, 1.9, s=0.17, mat="charcoal")
    K.sack(p, P, 1.7, 1.85, s=0.15, mat="charcoal")
    a, b = P.m(1.9, 1.3, 0.0), P.m(1.85, 1.2, 1.4)
    p.add("rake", "haft", cyl(a, b, 0.025), "prop", priority=2, min_cover=2)
    p.add("rake_head", "iron", box([a[0], 0.06, a[2]], [0.15, 0.03, 0.03]), "prop", priority=2)
    K.tufts(p, P, [(1.95, 0.75), (0.05, 1.97), (1.1, 1.95)])
    p.roofs = []
    return P, p, 208, 1.75


# =================================================================================================
# Tar kiln: a domed fieldstone kiln with an iron-banded firing door, smoke from its crown, a gutter
# from its foot to a tar pit and a barrel catching the tar, stacks of resinous pine stumps, tar
# barrels stacked by a small log hut with a plank roof. The worker stands by the pit (spot "pit").
# =================================================================================================
def tar_kiln():
    P, p = Plot(2), Parts()
    K.ground(P, p, seed=22)
    K.patch(p, "tar_stain", "tar", P, 1.15, 1.25, 0.18, 0.12, y=0.013)
    p.footprints = [(0.15, 0.95, 0.85, 1.8), (0.1, 0.9, 0.1, 0.75)]
    kx, ky = 0.58, 1.25
    x, _, z = P.m(kx, ky)
    p.add("kiln", "fieldstone", {"revolve": {"c": [round(x, 4), 0, round(z, 4)], "profile": {"bezier": [
        [0, 0], [0.45, 0], [0.86, 0], [0.9, 0.6], [0.92, 1.2], [0.6, 1.45], [0.3, 1.65], [0.2, 1.75], [0, 1.75], [0, 0.9]]}}}, "wall")
    p.paint("kiln", "stone_dark", spots={"scale": 0.07, "density": 0.4, "seed": 4})
    p.paint("kiln", "iron", stripes={"axis": "y", "at": [0.5, 1.0], "width": 0.06})
    p.add("kiln_crown", "clay", cyl([x, 1.7, z], [x, 1.85, z], 0.24), "wall")
    p.add("kiln_mouth", "dark_hole", cyl([x, 1.8, z], [x, 1.88, z], 0.16), "wall")
    K.wisp(p, [x, 1.9, z], 0.9, 3)
    # Firing door towards the left, glowing.
    p.add("fire_door", "iron", box([x - 0.82, 0.38, z], [0.06, 0.3, 0.26]), "wall")
    p.add("fire_glow", "flame", box([x - 0.86, 0.3, z], [0.03, 0.16, 0.16]), "wall")
    # Gutter from the kiln's foot to the pit and the barrel in the work yard.
    a, b = P.m(0.98, ky, 0.12), P.m(1.25, ky, 0.05)
    p.add("gutter", "post", box([(a[0] + b[0]) / 2, 0.09, (a[2] + b[2]) / 2], [0.07, 0.04, abs(b[2] - a[2]) / 2 + 0.05], rot=[0.12, 0, 0]), "prop")
    p.add("gutter_tar", "tar", box([(a[0] + b[0]) / 2, 0.13, (a[2] + b[2]) / 2], [0.035, 0.01, abs(b[2] - a[2]) / 2], rot=[0.12, 0, 0]), "prop")
    x2, _, z2 = P.m(1.3, ky)
    p.add("pit_rim", "fieldstone", tor([x2, 0.04, z2], 0.24, 0.07), "prop")
    p.add("pit_tar", "tar", cyl([x2, 0.0, z2], [x2, 0.04, z2], 0.22), "prop")
    K.barrel(p, P, 1.3, ky + 0.3, r=0.17, h=0.42)
    # Barrels of tar stacked by the hut, pine stumps on the stack tile's back edge.
    for i, (gx, gy) in enumerate(((1.15, 1.9), (1.4, 1.92), (1.27, 1.9))):
        if i < 2:
            K.barrel(p, P, gx, gy, r=0.17, h=0.42, name="tar_barrels")
        else:
            x3, _, z3 = P.m(gx, gy)
            p.add("tar_barrels_top", "barrel", cyl([x3, 0.44, z3], [x3, 0.86, z3], 0.17), "prop")
            p.paint("tar_barrels_top", "iron", stripes={"axis": "y", "at": [0.52, 0.78], "width": 0.04})
    p.paint("tar_barrels", "tar", stripes={"axis": "y", "at": [0.42], "width": 0.06})
    for i, (gx, gy) in enumerate(((1.15, 0.12), (1.4, 0.15), (1.7, 0.12), (1.3, 0.3))):
        x4, _, z4 = P.m(gx, gy)
        p.add("stumps", "log_bark", cyl([x4, 0, z4], [x4, 0.22, z4], 0.13), "prop")
        for k in range(3):
            ang = k * 2.1 + i
            p.add("roots", "log_bark", cone([x4, 0.08, z4], [x4 + math.cos(ang) * 0.24, 0.0, z4 + math.sin(ang) * 0.24], 0.05, 0.02), "prop")
    # The tar burner's hut: logs under a plank roof weighted with stones.
    hut = (0.12, 0.88, 0.12, 0.72)
    K.log_walls(p, P, "hut", hut, 0.0, 1.15, course=0.18)
    hroof = Gable(P, "hut", hut, "gy", 1.15, 1.85, over=0.2, end_over=0.16, flare=False)
    hroof.infill(p, "board")
    hroof.roof(p, "board", "log_groove", course=0.12)
    p.paint("hut_roof", "log_groove", stripes={"axis": "x", "period": 0.16, "width": 0.055})
    for gx, gy in ((0.75, 0.3), (0.75, 0.55)):
        x5, _, z5 = P.m(gx, gy)
        p.add("roof_stones", "stone", ell([x5, 1.38, z5], [0.1, 0.07, 0.1]), "roof")
    hx0, hx1, hz0, hz1 = P.rect(*hut)
    K.door_right(p, P, "hut_door", 0.42, hz1, 0.0, w=0.4, h=0.85, arch=False)
    K.tufts(p, P, [(1.95, 0.75), (0.05, 1.97), (1.62, 1.6)])
    p.roofs = [hroof]
    return P, p, 208, 1.7


# =================================================================================================
# Vineyard (3x3, entrance (2, 1), stack (2, 0)): a vintner's house in an L: a long hall with a stone
# ground floor and a half-timbered upper floor under red tiles, a front wing with its gable to the
# street, an arched cellar door and an oriel; a press house under a lean-to with a beam press
# towards the yard; a pergola heavy with grapes over a bench, baskets, casks.
# =================================================================================================
def vineyard():
    P, p = Plot(3), Parts()
    K.ground(P, p, seed=24)
    K.patch(p, "grass_patch", "grass", P, 0.6, 2.75, 0.5, 0.18)
    K.patch(p, "grass_patch", "grass", P, 2.7, 2.6, 0.25, 0.3)
    hall = (0.1, 1.95, 0.12, 1.25)
    wing = (0.1, 1.15, 1.25, 2.25)
    p.footprints = [hall, wing]
    for nm, r in (("hall", hall), ("wing", wing)):
        K.plinth(p, P, nm + "_plinth", r, h=0.22)
        K.walls(p, P, nm + "_stone", r, 0.22, 1.45, "fieldstone")
        p.paint(nm + "_stone", "stone_dark", spots={"scale": 0.07, "density": 0.38, "seed": 3})
        K.quoins(p, P, nm + "_quoins", r, 0.22, 1.45)
    hup = (0.07, 1.98, 0.09, 1.28)
    wup = (0.07, 1.18, 1.22, 2.29)
    for nm, r in (("hall", hup), ("wing", wup)):
        rx0, rx1, rz0, rz1 = P.rect(*r)
        p.add(nm + "_jetty", "timber", box([(rx0 + rx1) / 2, 1.5, (rz0 + rz1) / 2], [(rx1 - rx0) / 2 + 0.04, 0.06, (rz1 - rz0) / 2 + 0.04]), "wall")
        K.walls(p, P, nm + "_upper", r, 1.55, 2.45, "plaster")
    K.timber_right(p, P, "hall_frame", hup, 1.55, 2.45, 6)
    K.timber_left(p, P, "wing_frame", wup, 1.55, 2.45, 3)
    K.timber_right(p, P, "wing_frame", wup, 1.55, 2.45, 3)
    hroof = Gable(P, "hall", hup, "gx", 2.45, 3.85, over=0.3, end_over=0.25)
    hroof.infill(p, "plaster")
    hroof.gable_frame(p)
    hroof.roof(p, "tile", "tile_dark", course=0.13)
    hroof.bargeboards(p)
    wroof = Gable(P, "wing", wup, "gy", 2.45, 3.75, over=0.28, end_over=0.25)
    wroof.infill(p, "plaster")
    wroof.gable_frame(p)
    wroof.roof(p, "tile", "tile_dark", course=0.13)
    wroof.bargeboards(p)
    K.chimney(p, P, "chimney", 0.45, 0.55, 3.0, 4.3, w=0.2)
    K.chimney(p, P, "chimney2", 0.5, 2.0, 2.8, 4.05, w=0.16)
    hx0, hx1, hz0, hz1 = P.rect(*hall)
    wx0, wx1, wz0, wz1 = P.rect(*wing)
    # Front door to the work yard, windows, a sign with a bunch of grapes.
    K.door_right(p, P, "door", 1.0, hz1, 0.22, w=0.56, h=1.05, arch=True, frame="sill_mat")
    K.sign_right(p, P, 0.62, hz1, 1.4, grape_sign)
    for gy in (0.3, 0.75):
        K.window_right(p, P, gy, P.rect(*hup)[3], 2.0, w=0.3, h=0.38, box_=gy == 0.75)
    K.window_right(p, P, 0.3, hz1, 0.85, w=0.28, h=0.34, open_=False)
    K.window_right(p, P, 1.55, P.rect(*wup)[3], 2.0, w=0.28, h=0.36)
    # The wing's gable: an arched cellar door down two steps and an oriel above it.
    K.door_left(p, P, "cellar_door", 0.62, wx0, 0.0, w=0.62, h=0.75, arch=True, frame="sill_mat")
    xo = P.rect(*wup)[0]
    zo = P.m(0.62, 0)[2]
    p.add("oriel", "plaster", box([xo - 0.18, 2.0, zo], [0.2, 0.32, 0.32]), "wall")
    p.add("oriel_base", "timber", cone([xo - 0.15, 1.45, zo], [xo - 0.18, 1.7, zo], 0.05, 0.3), "wall")
    p.add("oriel_roof", "tile", box([xo - 0.2, 2.38, zo], [0.24, 0.06, 0.36], rot=[0, 0, -0.35]), "wall")
    K.window_left(p, P, 0.62, xo - 0.38, 2.0, w=0.3, h=0.36, shutters=False)
    K.window_left(p, P, 1.0, wx0, 0.9, w=0.26, h=0.32, open_=False)
    K.window_left(p, P, 0.3, xo, 3.0, w=0.24, h=0.26, shutters=False)
    # The press house: an open tiled lean-to between the wing and the yard, a beam press inside.
    press = (1.15, 1.95, 1.25, 2.25)
    K.lean_to(p, P, "press_roof", press, "-gx", 1.6, 1.95, "tile", "tile_dark", over=0.05, post_mat="timber")
    px0, px1, pz0, pz1 = P.rect(*press)
    cx, cz = (px0 + px1) / 2, (pz0 + pz1) / 2 + 0.05
    p.add("press_tub", "barrel", cyl([cx, 0, cz], [cx, 0.42, cz], 0.38), "prop")
    p.paint("press_tub", "iron", stripes={"axis": "y", "at": [0.08, 0.34], "width": 0.045})
    p.add("press_must", "grape", cyl([cx, 0.4, cz], [cx, 0.44, cz], 0.33), "prop")
    for sx in (-1, 1):
        p.add("press_posts", "timber", box([cx + sx * 0.52, 0.8, cz], [0.07, 0.8, 0.07]), "prop")
    p.add("press_beam", "timber", box([cx, 1.25, cz], [0.6, 0.09, 0.09]), "prop")
    p.add("press_screw", "post", cyl([cx, 0.5, cz], [cx, 1.4, cz], 0.06), "prop")
    p.paint("press_screw", "ink", stripes={"axis": "y", "period": 0.08, "width": 0.055})
    p.add("press_bar", "haft", cyl([cx, 1.05, cz - 0.45], [cx, 1.05, cz + 0.45], 0.03), "prop", priority=2)
    # Casks in the press house and by the yard.
    for i, gy in enumerate((1.4, 1.75)):
        K.barrel(p, P, 1.3, gy, r=0.2, h=0.5, name="casks")
    K.barrel(p, P, 2.85, 2.8, r=0.2, lying=True, h=0.55, along="z", name="cask_lying")
    # The pergola along the front: posts, rails, vines, hanging bunches, a bench beneath.
    a, b = P.m(0.15, 2.55), P.m(1.85, 2.55)
    a2, b2 = P.m(0.15, 2.9), P.m(1.85, 2.9)
    for q in (a, b, a2, b2, P.m(1.0, 2.9), P.m(1.0, 2.55)):
        p.add("pergola_posts", "post", cyl([q[0], 0, q[2]], [q[0], 1.55, q[2]], 0.05), "prop")
    for q0, q1 in ((a, b), (a2, b2)):
        p.add("pergola_rails", "post", cyl([q0[0], 1.55, q0[2]], [q1[0], 1.55, q1[2]], 0.04), "prop")
    for k in range(6):
        q = P.m(0.25 + k * 0.3, 2.72)
        p.add("pergola_rails", "post", cyl([q[0] + 0.45, 1.6, q[2]], [q[0] - 0.45, 1.6, q[2]], 0.03), "prop")
    for k in range(7):
        q = P.m(0.2 + k * 0.27, 2.72)
        p.add("pergola_leaves", "leaves", ell([q[0] + 0.05 * (k % 2), 1.68, q[2]], [0.42, 0.12, 0.2]), "prop", blend=0.05)
        if k % 2 == 0:
            p.add("grapes", "grape", ell([q[0] - 0.3, 1.38, q[2]], [0.06, 0.12, 0.06]), "prop")
            p.add("grapes", "grape", ell([q[0] + 0.2, 1.4, q[2] + 0.1], [0.06, 0.11, 0.06]), "prop")
    p.paint("pergola_leaves", "leaves_dark", spots={"scale": 0.06, "density": 0.3, "seed": 6})
    for q in (a, a2, b):
        p.add("vine_stems", "log_bark", cyl([q[0] - 0.08, 0, q[2] + 0.06], [q[0] - 0.05, 1.6, q[2] + 0.02], 0.035), "prop")
    bq = P.m(1.0, 2.72)
    p.add("bench", "board", box([bq[0], 0.4, bq[2]], [0.14, 0.04, 0.6]), "prop")
    for dz in (-0.5, 0.5):
        p.add("bench", "board", box([bq[0], 0.2, bq[2] + dz], [0.12, 0.2, 0.04]), "prop")
    # Grape baskets on the work yard's front edge.
    for gx, gy in ((2.2, 2.75), (2.45, 2.85)):
        x, _, z = P.m(gx, gy)
        p.add("baskets", "wicker", cone([x, 0, z], [x, 0.3, z], 0.17, 0.21), "prop")
        p.add("basket_grapes", "grape", ell([x, 0.32, z], [0.19, 0.09, 0.19]), "prop")
    p.paint("baskets", "log_groove", stripes={"axis": "y", "period": 0.08, "width": 0.055})
    p.paint("basket_grapes", "grape_dark", spots={"scale": 0.035, "density": 0.4, "seed": 3})
    K.tufts(p, P, [(2.9, 0.1), (2.95, 1.0), (0.05, 2.95), (2.6, 2.95)])
    p.roofs = [hroof, wroof]
    p.heap = (2.5, 0.45)
    return P, p, 288, 2.35


def grape_sign(p, c):
    x, y, z = c
    for i, (dx, dy) in enumerate(((0, 0.06), (-0.06, 0.02), (0.06, 0.02), (-0.03, -0.04), (0.03, -0.04), (0, -0.1))):
        p.add("sign_emblem", "grape", sph([x + dx, y + dy, z + 0.01], 0.04), "wall", priority=3)
    p.add("sign_emblem", "leaves", box([x + 0.05, y + 0.12, z + 0.01], [0.05, 0.03, 0.01]), "wall", priority=3)


# =================================================================================================
# Stable (3x3, entrance (1, 2) with the door on the left face, stack (0, 2)): a long timber-framed
# stable on a stone plinth under a steep thatch with a hay loft door and hoist in the right gable,
# a horse vane, a wide braced stable door; an open cart shed with a wagon; a railed paddock with a
# trough and a hay rack on the front-right tile; a hitching rail and a horseshoe sign.
# =================================================================================================
def stable():
    P, p = Plot(3), Parts()
    K.ground(P, p, seed=26)
    K.patch(p, "straw_ground", "thatch", P, 2.5, 2.4, 0.3, 0.3)
    K.patch(p, "grass_patch", "grass", P, 0.4, 2.8, 0.3, 0.15)
    st = (0.1, 2.05, 0.12, 1.85)
    p.footprints = [st, (2.1, 2.92, 0.15, 1.35)]
    K.plinth(p, P, "plinth", st, h=0.3, mat="fieldstone")
    K.walls(p, P, "walls", st, 0.3, 1.85, "plaster")
    K.timber_left(p, P, "frame", st, 0.3, 1.85, 6)
    K.timber_right(p, P, "frame", st, 0.3, 1.85, 5)
    roof = Gable(P, "stable", st, "gx", 1.85, 3.9, over=0.32, end_over=0.25, thick=0.26)
    roof.infill(p, "plaster")
    roof.gable_frame(p)
    roof.roof(p, "thatch", "thatch_dark", course=0.15, spots=("moss", 0.1, 0.15, 5))
    roof.bargeboards(p)
    for i, gx in enumerate((0.55, 1.45)):
        K.dormer_left(p, P, roof, "dormer%d" % i, gx, roof_mat="thatch", dark="thatch_dark")
    x0, x1, z0, z1 = P.rect(*st)
    # Loft door with hay and a hoist in the right gable.
    xc = roof.xc
    p.add("loft", "dark_hole", box([xc, 2.45, z1 + 0.02], [0.28, 0.3, 0.03]), "wall")
    p.add("loft_hay", "hay", ell([xc, 2.24, z1 + 0.1], [0.28, 0.12, 0.12]), "wall", blend=0.04)
    p.add("loft_doors", "door_wood", box([xc - 0.42, 2.45, z1 + 0.06], [0.13, 0.3, 0.03]), "wall")
    p.add("loft_doors", "door_wood", box([xc + 0.42, 2.45, z1 + 0.06], [0.13, 0.3, 0.03]), "wall")
    p.add("hoist", "timber", box([xc, 3.0, z1 + 0.3], [0.05, 0.05, 0.4]), "wall")
    p.add("hoist_rope", "rope", cyl([xc, 2.95, z1 + 0.62], [xc, 1.7, z1 + 0.62], 0.02), "wall", min_cover=1)
    p.add("hoist_bale", "hay", box([xc, 1.55, z1 + 0.62], [0.2, 0.14, 0.14], round_=0.03), "prop")
    # The big stable door in the left face (towards the entrance tile, game x 1.5).
    zd = P.m(1.5, 0)[2]
    p.add("stable_door", "door_wood", box([x0 - 0.04, 0.95, zd], [0.04, 0.66, 0.5]), "wall")
    p.paint("stable_door", "ink", stripes={"axis": "z", "period": 0.12, "width": 0.04})
    p.paint("stable_door", "ink", stripes={"axis": "y", "at": [0.95], "width": 0.06})
    for sz in (-1, 1):
        p.add("stable_door_brace", "timber", box([x0 - 0.09, 0.95, zd + sz * 0.25], [0.02, 0.04, 0.3], rot=[sz * 1.0, 0, 0]), "wall")
    p.add("stable_door_frame", "timber", box([x0 - 0.06, 1.68, zd], [0.06, 0.07, 0.62]), "wall")
    p.add("horseshoe", "iron", tor([x0 - 0.1, 1.85, zd], 0.09, 0.025, rot=[0, 0, 1.5708]), "wall", priority=2)
    for gx in (0.45, 0.85, 2.0):
        K.window_left(p, P, gx, x0, 1.2, w=0.3, h=0.26, shutters=gx != 2.0)
    for gy in (0.5, 1.4):
        K.window_right(p, P, gy, z1, 1.15, w=0.3, h=0.3, open_=False)
    # Weather vane: a horse.
    vz = roof.zc
    p.add("vane", "iron", cyl([xc, 3.9, vz], [xc, 4.45, vz], 0.025), "roof", priority=2, min_cover=2)
    p.add("vane", "iron", ext([xc, 4.42, vz], [[-0.2, 0], [0.18, 0], [0.24, 0.16], [0.16, 0.22], [0.1, 0.1], [-0.14, 0.1],
                                             [-0.24, 0.18]], 0.03, rot=[0, 1.5708, 0]), "roof", priority=2)
    # The cart shed at the right end with a wagon.
    shed = (2.1, 2.92, 0.15, 1.35)
    K.lean_to(p, P, "shed_roof", shed, "-gx", 1.5, 2.0, "shingle", "shingle_dark", over=0.12)
    sx0, sx1, sz0, sz1 = P.rect(*shed)
    p.add("shed_back", "board", box([(sx0 + sx1) / 2, 0.85, sz0 + 0.04], [(sx1 - sx0) / 2, 0.85, 0.04]), "wall")
    p.add("shed_back", "board", box([sx1 - 0.04, 0.8, (sz0 + sz1) / 2], [0.04, 0.8, (sz1 - sz0) / 2]), "wall")
    p.paint("shed_back", "ink", stripes={"axis": "x", "period": 0.18, "width": 0.045})
    K.cart(p, P, 2.5, 0.75, yaw=1.5708 + 3.1416, name="wagon")
    # Paddock on the front-right tile: rails, a trough and a hay rack.
    pts = [(2.05, 2.0), (2.95, 2.0), (2.95, 2.95), (2.05, 2.95)]
    K.fence(p, P, [(2.05, 1.95), (2.97, 1.95), (2.97, 2.97), (2.05, 2.97)], name="paddock", h=0.55)
    x, _, z = P.m(2.5, 2.2)
    p.add("trough", "board", box([x, 0.18, z], [0.18, 0.18, 0.45]), "prop")
    p.cut("trough", box([x, 0.3, z], [0.12, 0.12, 0.39]))
    p.add("trough_water", "water", box([x, 0.27, z], [0.12, 0.01, 0.39]), "prop")
    x, _, z = P.m(2.85, 2.6)
    p.add("hay_rack", "post", box([x, 0.55, z], [0.05, 0.55, 0.3]), "prop")
    p.paint("hay_rack", "ink", stripes={"axis": "z", "period": 0.1, "width": 0.055})
    p.add("rack_hay", "hay", ell([x - 0.08, 0.95, z], [0.14, 0.2, 0.3]), "prop")
    # Hitching rail and a water bucket by the door; bales on the stack tile's back edge.
    a, b = P.m(1.15, 2.55), P.m(1.85, 2.55)
    for q in (a, b):
        p.add("hitch", "post", cyl([q[0], 0, q[2]], [q[0], 0.75, q[2]], 0.05), "prop")
    p.add("hitch", "post", cyl([a[0], 0.72, a[2]], [b[0], 0.72, b[2]], 0.04), "prop")
    K.bucket(p, P, 1.3, 2.75, fill="water")
    for i, (gx, gy) in enumerate(((0.25, 2.1), (0.55, 2.08))):
        x, _, z = P.m(gx, gy)
        p.add("bales", "hay", box([x, 0.2, z], [0.18, 0.2, 0.28], round_=0.04), "prop")
    p.paint("bales", "thatch_dark", stripes={"axis": "z", "period": 0.2, "width": 0.055})
    K.tufts(p, P, [(0.05, 2.95), (2.0, 2.95), (2.9, 1.6)])
    p.roofs = [roof]
    p.heap = (0.5, 2.5)
    return P, p, 304, 2.6


# =================================================================================================
# Mill: a post mill (koźlak). The weatherboarded buck stands on a great post held by a trestle of
# crosstrees and quarter bars on brick piers; a curved roof, the breast with the windshaft towards
# the camera's left, steps and the tail pole with a cart wheel down to the work yard; sacks of grain
# and flour, a spare millstone. The sails are not in the base art: they turn in base_anim
# (mill_sails(), 8 frames over a quarter turn, BuildingView plays them).
# =================================================================================================
MILL_C = (0.52, 0.98)       # game point of the post
MILL_FLOOR = 1.6
MILL_HUB = None             # model point of the hub, set by mill()


def mill():
    global MILL_HUB
    P, p = Plot(2), Parts()
    K.ground(P, p, seed=28)
    K.patch(p, "grass_patch", "grass", P, 0.3, 0.3, 0.3, 0.25)
    K.patch(p, "grass_patch", "grass", P, 1.75, 0.35, 0.25, 0.2)
    K.patch(p, "flour_dust", "flour", P, 1.4, 1.45, 0.2, 0.15, y=0.013)
    cx, _, cz = P.m(*MILL_C)
    p.footprints = [(0.12, 0.92, 0.5, 1.45)]
    # Trestle: brick piers, crossed crosstrees, quarter bars, the post.
    for dx, dz in ((0.95, 0), (-0.95, 0), (0, 0.95), (0, -0.95)):
        p.add("piers", "brick", box([cx + dx, 0.18, cz + dz], [0.17, 0.18, 0.17]), "found")
    p.paint("piers", "brick_line", stripes={"axis": "y", "period": 0.12, "width": 0.035})
    p.add("crosstrees", "timber", box([cx, 0.44, cz], [1.05, 0.08, 0.08]), "wall")
    p.add("crosstrees", "timber", box([cx, 0.44, cz], [0.08, 0.08, 1.05]), "wall")
    for dx, dz in ((0.85, 0), (-0.85, 0), (0, 0.85), (0, -0.85)):
        p.add("quarter_bars", "timber", cyl([cx + dx, 0.5, cz + dz], [cx + dx * 0.12, 1.35, cz + dz * 0.12], 0.06), "wall")
    p.add("post", "log", cyl([cx, 0.4, cz], [cx, MILL_FLOOR + 0.1, cz], 0.16), "wall")
    # The buck: weatherboards, corner posts, a curved roof running front to back.
    bx0, bx1 = cx - 0.95, cx + 0.95
    bz0, bz1 = cz - 0.72, cz + 0.72
    top = 3.45
    p.add("buck", "board", box([cx, (MILL_FLOOR + top) / 2, cz], [0.95, (top - MILL_FLOOR) / 2, 0.72]), "wall")
    p.paint("buck", "ink", stripes={"axis": "y", "period": 0.16, "width": 0.045})
    p.add("buck_base", "timber", box([cx, MILL_FLOOR + 0.06, cz], [1.0, 0.08, 0.77]), "wall")
    for (x, z) in ((bx0, bz0), (bx0, bz1), (bx1, bz1)):
        p.add("buck_posts", "timber", box([x, (MILL_FLOOR + top) / 2, z], [0.06, (top - MILL_FLOOR) / 2, 0.06]), "wall")
    p.add("buck_posts", "timber", box([bx0, top - 0.05, cz], [0.06, 0.06, 0.74]), "wall")
    arch = [[-0.86 + 1.72 * i / 10, top + 0.62 * math.sin(math.pi * i / 10)] for i in range(11)]
    inner = [[q[0], q[1] - 0.12] for q in reversed(arch)]
    p.add("buck_roof", "shingle", ext([cx, 0, cz], arch + inner, 2.1, rot=[0, 1.5708, 0]), "roof")
    p.paint("buck_roof", "shingle_dark", stripes={"axis": "x", "period": 0.16, "width": 0.055})
    p.add("buck_gable", "board", ext([cx, 0, cz], [[-0.72, top], [0.72, top]] +
                                     [[0.72 - 1.44 * i / 8, top + 0.55 * math.sin(math.pi * (1 - i / 8))] for i in range(1, 8)],
                                     1.9, rot=[0, 1.5708, 0]), "wall")
    # The breast: the windshaft's hub out of the front, a little window.
    MILL_HUB = [bx0 - 0.32, 3.05, cz]
    p.add("windshaft", "log", cyl([bx0 + 0.3, 3.0, cz], MILL_HUB, 0.12), "wall")
    p.add("hub", "iron", cyl([MILL_HUB[0] + 0.06, 3.05, cz], [MILL_HUB[0] - 0.06, 3.05, cz], 0.17), "wall")
    K.window_left(p, P, (cz + P.h) / K.T, bx0, 2.3, w=0.26, h=0.26, shutters=False)
    # Door, steps and tail pole down to the work yard (right side).
    xd = cx + 0.35
    p.add("door", "door_wood", box([xd, MILL_FLOOR + 0.62, bz1 + 0.03], [0.26, 0.5, 0.04]), "wall")
    p.paint("door", "ink", stripes={"axis": "x", "period": 0.13, "width": 0.04})
    p.add("door_iron", "iron", box([xd - 0.05, MILL_FLOOR + 0.8, bz1 + 0.08], [0.18, 0.03, 0.02]), "wall")
    sz0, sz1 = bz1 + 0.05, bz1 + 1.45
    for sx in (-0.26, 0.26):
        p.add("steps_side", "timber", cyl([xd + sx, MILL_FLOOR + 0.05, sz0], [xd + sx, 0.0, sz1], 0.05), "wall", priority=2)
    for i in range(1, 7):
        t = i / 7
        p.add("steps", "board", box([xd, MILL_FLOOR * (1 - t), sz0 + (sz1 - sz0) * t], [0.25, 0.025, 0.08]), "wall")
    p.add("rail", "timber", cyl([xd + 0.28, MILL_FLOOR + 0.75, sz0], [xd + 0.28, 0.7, sz1], 0.03), "wall", priority=2)
    p.add("tail_pole", "log", cyl([cx + 0.95, MILL_FLOOR + 0.2, cz + 0.2], [cx + 1.25, 0.35, bz1 + 1.6], 0.07), "wall",
          priority=2)
    w = [cx + 1.25, 0.35, bz1 + 1.6]
    p.add("tail_wheel", "post", tor(w, 0.3, 0.045, rot=[0, 0, 1.5708]), "prop")
    p.add("tail_wheel", "iron", cyl([w[0] - 0.05, w[1], w[2]], [w[0] + 0.05, w[1], w[2]], 0.06), "prop")
    # Sacks: grain under the trestle, flour on the yard's front edge; a spare millstone.
    for i, (gx, gy) in enumerate(((0.2, 1.6), (0.35, 1.72), (0.28, 1.55))):
        K.sack(p, P, gx, gy, s=0.17, y0=0.0 if i < 2 else 0.3)
    for gx, gy in ((1.7, 1.88), (1.86, 1.75)):
        K.sack(p, P, gx, gy, s=0.17, mat="flour_sack")
    x, _, z = P.m(0.15, 0.3)
    p.add("millstone", "stone", cyl([x, 0.4, z - 0.08], [x, 0.4, z + 0.08], 0.38), "prop")
    p.add("millstone_eye", "dark_hole", cyl([x, 0.4, z + 0.07], [x, 0.4, z + 0.09], 0.08), "prop")
    p.paint("millstone", "stone_dark", rings={"axis": "z", "period": 0.12, "width": 0.055})
    K.tufts(p, P, [(1.95, 0.9), (0.05, 1.97), (1.1, 0.1)])
    p.spots = {"hopper": (1.35, 1.22)}
    p.roofs = []
    return P, p, 288, 2.6


def mill_sails(angle):
    """The four lattice sails turned by `angle` (radians) about the windshaft."""
    P = mill()[0]      # sets MILL_HUB; only the sails are kept
    p = Parts()
    h = MILL_HUB
    R, r0, wide = 2.15, 0.45, 0.46
    for k in range(4):
        a = angle + k * math.pi / 2
        d = (0.0, math.cos(a), math.sin(a))
        e = (0.0, -math.sin(a), math.cos(a))

        def at(r, u, dx=0.0):
            return [h[0] + dx, h[1] + d[1] * r + e[1] * u, h[2] + d[2] * r + e[2] * u]
        p.add("stocks", "timber", box(at(R / 2, 0, -0.04), [0.05, R / 2, 0.055], rot=[a, 0, 0]), "prop")
        p.add("sailcloth", "sailcloth", box(at((r0 + R) / 2, wide / 2, 0.02), [0.015, (R - r0) / 2, wide / 2], rot=[a, 0, 0]),
              "prop")
        p.add("rails", "timber", box(at((r0 + R) / 2, wide, -0.02), [0.025, (R - r0) / 2, 0.025], rot=[a, 0, 0]), "prop",
              min_cover=2)
        for i in range(6):
            r = r0 + (R - r0) * i / 5
            p.add("bars", "timber", box(at(r, wide / 2, -0.03), [0.022, 0.022, wide / 2 + 0.02], rot=[a, 0, 0]), "prop",
                  min_cover=2)
    p.add("hub_cap", "iron", cyl([h[0] - 0.02, h[1], h[2]], [h[0] - 0.12, h[1], h[2]], 0.15), "prop")
    return P, p


# --- emblems for the sign boards (a few pixels each) -----------------------------------------------
def emblem_pretzel(p, c):
    x, y, z = c
    p.add("sign_emblem", "bread", tor([x, y, z + 0.01], 0.09, 0.03, rot=[1.5708, 0, 0]), "wall", priority=3)
    p.add("sign_emblem", "bread", tor([x - 0.05, y - 0.03, z + 0.01], 0.05, 0.025, rot=[1.5708, 0, 0]), "wall", priority=3)
    p.add("sign_emblem", "bread", tor([x + 0.05, y - 0.03, z + 0.01], 0.05, 0.025, rot=[1.5708, 0, 0]), "wall", priority=3)


def emblem_tankard(p, c):
    x, y, z = c
    p.add("sign_emblem", "pewter", box([x, y, z + 0.01], [0.07, 0.1, 0.012]), "wall", priority=3)
    p.add("sign_emblem", "pewter", tor([x + 0.09, y, z + 0.01], 0.05, 0.018, rot=[1.5708, 0, 0]), "wall", priority=3)
    p.add("sign_emblem", "flour", box([x, y + 0.11, z + 0.012], [0.08, 0.03, 0.012]), "wall", priority=3)


def emblem_jug(p, c):
    x, y, z = c
    p.add("sign_emblem", "honey", ell([x, y - 0.02, z + 0.01], [0.08, 0.09, 0.012]), "wall", priority=3)
    p.add("sign_emblem", "honey", box([x, y + 0.08, z + 0.01], [0.035, 0.04, 0.012]), "wall", priority=3)


def emblem_grapes(p, c):
    grape_sign(p, c)


def emblem_saw(p, c):
    x, y, z = c
    p.add("sign_emblem", "steel", box([x, y, z + 0.01], [0.15, 0.05, 0.012]), "wall", priority=3)
    p.add("sign_emblem", "haft", box([x - 0.17, y, z + 0.01], [0.03, 0.07, 0.012]), "wall", priority=3)


def emblem_horseshoe(p, c):
    x, y, z = c
    p.add("sign_emblem", "iron", tor([x, y, z + 0.01], 0.08, 0.025, rot=[1.5708, 0, 0]), "wall", priority=3)
    p.add("sign_emblem", "sign_board", box([x, y - 0.08, z + 0.015], [0.06, 0.04, 0.012]), "wall", priority=3)


def emblem_shears(p, c):
    x, y, z = c
    for s in (-1, 1):
        p.add("sign_emblem", "steel", box([x, y, z + 0.01], [0.02, 0.13, 0.012], rot=[0, 0, s * 0.4]), "wall", priority=3)
        p.add("sign_emblem", "steel", tor([x + s * 0.06, y - 0.13, z + 0.01], 0.035, 0.015, rot=[1.5708, 0, 0]), "wall", priority=3)


def emblem_shuttle(p, c):
    x, y, z = c
    p.add("sign_emblem", "cloth_blue", box([x, y, z + 0.01], [0.13, 0.08, 0.012]), "wall", priority=3)
    p.add("sign_emblem", "cloth_red", box([x, y, z + 0.015], [0.13, 0.025, 0.012]), "wall", priority=3)


def emblem_ox(p, c):
    x, y, z = c
    p.add("sign_emblem", "bone", box([x, y - 0.02, z + 0.01], [0.07, 0.08, 0.012]), "wall", priority=3)
    for s in (-1, 1):
        p.add("sign_emblem", "bone", box([x + s * 0.1, y + 0.08, z + 0.01], [0.05, 0.02, 0.012], rot=[0, 0, s * 0.5]), "wall",
              priority=3)


# =================================================================================================
# Bakery: a half-timbered town house with a jettied upper floor under red tiles, a dormer, a brick
# chimney; a great clay bread oven built out into the work yard with its own little roof and
# chimney; a kneading table with dough and loaves, a peel, a bread rack, firewood, a pretzel sign.
# =================================================================================================
def bakery():
    P, p = Plot(2), Parts()
    K.ground(P, p, mat="cobble_ground", dark="earth_dark", seed=30)
    house = (0.1, 0.95, 0.12, 1.25)
    g, eave, top = K.house(p, P, "house", house, ground="plaster_ochre", ground_h=1.45, upper="plaster", upper_h=0.85,
                           axis="gy", rise=1.35, frame_ground=True, posts=(2, 4))
    K.dormer(p, P, g, "dormer", 0.6, roof_mat="tile", dark="tile_dark")
    K.chimney(p, P, "chimney", 0.3, 0.45, 2.5, 4.0, w=0.18)
    x0, x1, z0, z1 = P.rect(*house)
    K.door_right(p, P, "door", 0.95, z1, 0.2, w=0.5, h=0.95, arch=True)
    K.window_right(p, P, 0.35, z1, 0.95, w=0.3, h=0.36, open_=False)
    K.window_right(p, P, 0.4, P.rect(*top)[3], 1.85, w=0.3, h=0.34, box_=True)
    K.window_right(p, P, 1.0, P.rect(*top)[3], 1.85, w=0.3, h=0.34)
    K.window_left(p, P, 0.53, P.rect(*top)[0], 1.85, w=0.3, h=0.34)
    K.sign_right(p, P, 1.2, z1, 1.4, emblem_pretzel)
    # The oven: a clay dome on a stone base in front of the house, a little tiled roof over it.
    og = (0.55, 1.62)
    ox, _, oz = P.m(*og)
    p.add("oven_base", "fieldstone", box([ox, 0.25, oz], [0.62, 0.25, 0.62]), "wall")
    p.paint("oven_base", "stone_dark", spots={"scale": 0.07, "density": 0.38, "seed": 5})
    p.footprints.append((0.2, 0.9, 1.3, 1.95))
    K.dome(p, P, "oven", og[0], og[1], 0.55, 0.68, "clay", y0=0.5)
    p.paint("oven", "clay_dark", spots={"scale": 0.06, "density": 0.25, "seed": 2})
    p.add("oven_mouth", "dark_hole", box([ox, 0.68, oz + 0.5], [0.16, 0.13, 0.06]), "wall")
    p.add("oven_glow", "flame", box([ox, 0.62, oz + 0.53], [0.1, 0.06, 0.03]), "wall")
    p.add("oven_arch", "brick", box([ox, 0.86, oz + 0.53], [0.22, 0.05, 0.05]), "wall")
    p.add("oven_flue", "brick", box([ox - 0.2, 1.35, oz - 0.15], [0.1, 0.25, 0.1]), "roof")
    K.lean_to(p, P, "oven_roof", (0.18, 0.92, 1.3, 1.95), "-gy", 1.55, 1.9, "tile", "tile_dark", over=0.08)
    # Kneading table on the yard's right edge, loaves on a rack, a peel, firewood under the oven roof.
    tx, _, tz = P.m(1.6, 1.9)
    p.add("table", "board", box([tx, 0.5, tz], [0.18, 0.04, 0.42]), "prop")
    for dz in (-0.36, 0.36):
        p.add("table_legs", "post", box([tx, 0.24, tz + dz], [0.14, 0.24, 0.04]), "prop")
    p.add("dough", "dough", ell([tx, 0.58, tz + 0.1], [0.1, 0.06, 0.15]), "prop")
    for dz in (-0.25, -0.1):
        p.add("loaves", "bread", ell([tx + 0.02, 0.58, tz + dz], [0.1, 0.05, 0.07]), "prop")
    p.add("flour_bin", "flour_sack", ell([tx - 0.3, 0.16, tz - 0.25], [0.14, 0.16, 0.16]), "prop")
    a, b = P.m(1.05, 1.95, 0.0), P.m(1.08, 1.9, 1.3)
    p.add("peel", "haft", cyl(a, b, 0.022), "prop", priority=2, min_cover=2)
    p.add("peel_blade", "board", box([b[0], 1.3, b[2]], [0.1, 0.12, 0.015]), "prop", priority=2)
    K.woodpile(p, P, "oven_wood", 0.2, 0.9, 1.92, 2, r=0.08, along="gx", mat="split")
    p.spots = {"oven": (1.35, 1.6), "table": (1.62, 1.68)}
    K.tufts(p, P, [(1.95, 0.95), (1.1, 0.06)])
    return P, p, 240, 2.1


# =================================================================================================
# Brewery: a stone brewhouse with a louvred smoke lantern on the ridge and a tall chimney, malt
# floor window and hoist; in the yard a copper kettle on a brick hearth with fire, the mash tun with
# a paddle, casks and sacks of malt; an ale stake (a bush on a pole) over the door.
# =================================================================================================
def brewery():
    P, p = Plot(2), Parts()
    K.ground(P, p, seed=32)
    house = (0.1, 0.96, 0.1, 1.5)
    g, eave, top = K.house(p, P, "house", house, ground="fieldstone", ground_h=2.0, axis="gx", rise=1.55,
                           roof_mat="tile", roof_dark="tile_dark", with_quoins=True)
    x0, x1, z0, z1 = P.rect(*house)
    # Louvred lantern on the ridge.
    lx = P.m(0, 0.75)[0]
    p.add("lantern_walls", "board", box([lx, eave + 1.55, g.zc], [0.22, 0.2, 0.22]), "roof")
    p.paint("lantern_walls", "ink", stripes={"axis": "y", "period": 0.08, "width": 0.055})
    K.cone_roof(p, P, "lantern_roof", (g.zc + P.h) / K.T, 0.75, eave + 1.72, 0.36, 0.42, "tile", "tile_dark", course=0.1)
    K.chimney(p, P, "chimney", 0.5, 0.25, 2.8, 4.35, w=0.2)
    K.door_right(p, P, "door", 1.15, z1, 0.2, w=0.56, h=1.1, arch=True, frame="sill_mat")
    K.window_right(p, P, 0.45, z1, 1.1, w=0.3, h=0.42)
    K.window_left(p, P, 0.5, x0, 1.2, w=0.3, h=0.42, open_=False)
    xd = P.m(0, 0.7)[0]
    p.add("malt_door", "door_wood", box([xd, 2.45, z1 + 0.25], [0.22, 0.28, 0.04]), "wall")
    # Ale stake: a pole out over the door with a bush hung on it.
    pz = z1 + 0.05
    p.add("ale_stake", "post", cyl([P.m(0, 1.35)[0], 2.0, pz], [P.m(0, 1.35)[0], 2.0, pz + 0.75], 0.035), "wall")
    p.add("ale_bush", "leaves", ell([P.m(0, 1.35)[0], 1.82, pz + 0.72], [0.14, 0.17, 0.14]), "wall")
    # Yard: brick hearth with a copper kettle and fire, the mash tun and paddle, casks, malt sacks.
    hx, _, hz = P.m(1.22, 1.22)
    p.add("hearth", "brick", box([hx, 0.3, hz], [0.32, 0.3, 0.32]), "prop")
    p.paint("hearth", "brick_line", stripes={"axis": "y", "period": 0.12, "width": 0.035})
    p.add("hearth_fire", "flame", box([hx - 0.1, 0.18, hz + 0.33], [0.15, 0.1, 0.02]), "prop")
    p.add("hearth_mouth", "dark_hole", box([hx - 0.1, 0.2, hz + 0.32], [0.19, 0.14, 0.015]), "prop")
    p.add("kettle", "copper", {"revolve": {"c": K.r4([hx, 0.6, hz]), "profile": {"polygon": [
        [0, 0], [0.22, 0], [0.33, 0.06], [0.36, 0.22], [0.33, 0.38], [0.3, 0.42], [0, 0.42]]}}}, "prop")
    p.add("kettle_brew", "beer", cyl([hx, 0.98, hz], [hx, 1.01, hz], 0.28), "prop")
    K.wisp(p, [hx, 1.05, hz], 0.6, 2)
    K.tub(p, P, "mash_tun", 1.72, 1.72, 0.32, 0.55, fill="beer")
    a = P.m(1.72, 1.72, 0.55)
    p.add("paddle", "haft", cyl([a[0] - 0.1, 0.5, a[2] + 0.05], [a[0] + 0.15, 1.2, a[2] - 0.1], 0.025), "prop", priority=2)
    for i, gy in enumerate((1.3, 1.52)):
        K.barrel(p, P, 1.88, gy, r=0.17, h=0.42, name="casks")
    K.barrel(p, P, 1.88, 1.41, r=0.16, h=0.38, name="casks_top", lying=True, along="z")
    p["casks_top"]["prims"][0]["ellipsoid"]["c"][1] = 0.58
    K.sack(p, P, 1.12, 1.9, s=0.16)
    K.sack(p, P, 1.3, 1.94, s=0.15)
    p.spots = {"kettle": (1.48, 1.32), "vat": (1.48, 1.72)}
    K.tufts(p, P, [(1.95, 0.6), (1.1, 0.05), (0.05, 1.97)])
    return P, p, 256, 2.2


# =================================================================================================
# Meadery: a low wattle-and-daub house under a heavy thatch with a hipped end, an open shelter with
# a shelf of skeps; in the yard a honey vat with a ladle, a trestle of casks, crocks of honey and a
# jug sign.
# =================================================================================================
def meadery():
    P, p = Plot(2), Parts()
    K.ground(P, p, seed=34)
    K.patch(p, "grass_patch", "grass", P, 0.4, 1.9, 0.35, 0.08)
    house = (0.1, 0.95, 0.12, 1.3)
    p.footprints.append(house)
    K.plinth(p, P, "plinth", house, h=0.18, mat="fieldstone")
    K.walls(p, P, "walls", house, 0.18, 1.4, "plaster_ochre")
    K.timber_left(p, P, "frame_l", house, 0.18, 1.4, 2)
    K.timber_right(p, P, "frame_r", house, 0.18, 1.4, 4)
    K.hip_roof(p, P, "roof", house, 1.38, 2.95, "thatch", "thatch_dark", over=0.34, course=0.15, spots=("moss", 0.1, 0.16, 3))
    K.chimney(p, P, "chimney", 0.5, 0.4, 2.0, 3.25, w=0.15, mat="fieldstone", cap="fieldstone")
    x0, x1, z0, z1 = P.rect(*house)
    K.door_right(p, P, "door", 1.0, z1, 0.18, w=0.48, h=0.9, arch=False)
    K.window_right(p, P, 0.42, z1, 0.85, w=0.28, h=0.3, box_=True)
    K.window_left(p, P, 0.53, x0, 0.85, w=0.28, h=0.3)
    K.sign_right(p, P, 1.22, z1, 1.25, emblem_jug)
    # Skep shelter in front of the house.
    sh = (0.15, 0.92, 1.38, 1.95)
    K.lean_to(p, P, "shelter_roof", sh, "-gy", 1.05, 1.35, "thatch", "thatch_dark", over=0.08)
    sx0, sx1, sz0, sz1 = P.rect(*sh)
    p.add("shelf", "board", box([(sx0 + sx1) / 2, 0.42, (sz0 + sz1) / 2], [0.2, 0.04, (sz1 - sz0) / 2 - 0.05]), "prop")
    for i in range(3):
        z = sz0 + 0.3 + i * (sz1 - sz0 - 0.6) / 2
        p.add("skeps", "hay", ell([(sx0 + sx1) / 2, 0.66, z], [0.2, 0.25, 0.2]), "prop")
        p.add("skep_doors", "dark_hole", box([(sx0 + sx1) / 2 - 0.2, 0.5, z], [0.02, 0.03, 0.05]), "prop")
    p.cut("skeps", plane([0, -1, 0], [0, 0.46, 0]))
    p.paint("skeps", "thatch_dark", rings={"axis": "y", "period": 0.1, "width": 0.055})
    # Yard: honey vat with a ladle, casks on a trestle, crocks.
    K.tub(p, P, "honey_vat", 1.2, 1.72, 0.3, 0.5, fill="honey")
    a = P.m(1.2, 1.72, 0.5)
    p.add("ladle", "haft", cyl([a[0], 0.45, a[2]], [a[0] + 0.2, 0.95, a[2] + 0.1], 0.022), "prop", priority=2)
    tx, _, tz = P.m(1.85, 1.35)
    p.add("cask_trestle", "post", box([tx, 0.15, tz], [0.18, 0.15, 0.45]), "prop")
    for dz in (-0.22, 0.22):
        p.add("mead_casks", "barrel", ell([tx, 0.45, tz + dz], [0.3, 0.17, 0.17]), "prop")
        p.add("mead_cask_ends", "barrel_lid", cyl([tx - 0.28, 0.45, tz + dz], [tx - 0.3, 0.45, tz + dz], 0.13), "prop")
        p.add("mead_taps", "brass", box([tx - 0.32, 0.4, tz + dz], [0.03, 0.02, 0.02]), "prop")
    p.paint("mead_casks", "iron", stripes={"axis": "x", "at": [tx - 0.16, tx + 0.16], "width": 0.045})
    for i, (gx, gy) in enumerate(((1.15, 1.32), (1.27, 1.25), (1.32, 1.4))):
        x, _, z = P.m(gx, gy)
        p.add("crocks", "clay", ell([x, 0.13, z], [0.1, 0.13, 0.1]), "prop")
        p.add("crock_lids", "honey", cyl([x, 0.24, z], [x, 0.27, z], 0.06), "prop")
    p.spots = {"vat": (1.45, 1.75), "cask": (1.62, 1.32)}
    K.tufts(p, P, [(1.95, 0.6), (1.1, 0.05)])
    return P, p, 224, 1.9


# =================================================================================================
# Wine press: a stone press house with a red-tiled roof, the gable to the yard, an arched cellar
# door; in the yard a screw press on a wooden tub with a tray of crushed grapes, casks on chocks,
# baskets of grapes, a sign with a bunch of grapes.
# =================================================================================================
def wine_press():
    P, p = Plot(2), Parts()
    K.ground(P, p, seed=36)
    K.patch(p, "must_stain", "grape_dark", P, 1.35, 1.6, 0.18, 0.12, y=0.013)
    house = (0.1, 0.96, 0.12, 1.35)
    g, eave, top = K.house(p, P, "house", house, ground="fieldstone", ground_h=1.5, upper="plaster", upper_h=0.8,
                           axis="gx", rise=1.25, with_quoins=True, posts=(3, 2))
    x0, x1, z0, z1 = P.rect(*house)
    K.door_right(p, P, "door", 0.7, z1, 0.2, w=0.6, h=0.95, arch=True, frame="sill_mat")
    K.window_right(p, P, 0.72, P.rect(*top)[3], 1.95, w=0.3, h=0.32)
    K.window_left(p, P, 0.5, P.rect(*top)[0], 1.95, w=0.3, h=0.32, open_=False)
    K.window_left(p, P, 0.5, x0, 0.9, w=0.24, h=0.26, shutters=False)
    K.sign_right(p, P, 1.22, z1, 1.3, emblem_grapes)
    K.chimney(p, P, "chimney", 0.25, 0.3, 2.4, 3.8, w=0.17)
    # A vine climbing the house's left face on a trellis.
    for i in range(4):
        q = P.m(0.15 + i * 0.22, 1.37)
        p.add("vine", "leaves", ell([q[0] - 0.06, 0.9 + 0.25 * (i % 2), q[2]], [0.08, 0.32, 0.18]), "prop")
    p.add("vine_bunches", "grape", ell(P.m(0.4, 1.38, 0.7), [0.05, 0.1, 0.06]), "prop")
    p.add("vine_bunches", "grape", ell(P.m(0.75, 1.38, 0.75), [0.05, 0.1, 0.06]), "prop")
    # The screw press: a tub, two posts, a beam, the screw and its bar.
    cx, _, cz = P.m(1.3, 1.65)
    p.add("press_tub", "barrel", cyl([cx, 0, cz], [cx, 0.4, cz], 0.34), "prop")
    p.paint("press_tub", "iron", stripes={"axis": "y", "at": [0.08, 0.32], "width": 0.045})
    p.add("press_must", "grape", cyl([cx, 0.38, cz], [cx, 0.42, cz], 0.3), "prop")
    for dx in (-0.42, 0.42):
        p.add("press_posts", "timber", box([cx + dx, 0.65, cz], [0.06, 0.65, 0.06]), "prop")
    p.add("press_beam", "timber", box([cx, 1.25, cz], [0.5, 0.07, 0.07]), "prop")
    p.add("press_screw", "post", cyl([cx, 0.45, cz], [cx, 1.38, cz], 0.05), "prop")
    p.paint("press_screw", "ink", stripes={"axis": "y", "period": 0.08, "width": 0.055})
    p.add("press_block", "board", box([cx, 0.5, cz], [0.26, 0.06, 0.26]), "prop")
    p.add("press_bar", "haft", cyl([cx - 0.35, 0.95, cz], [cx + 0.35, 0.95, cz], 0.025), "prop", priority=2)
    # Casks on chocks along the yard's right edge, baskets of grapes.
    for i, gy in enumerate((1.25, 1.55)):
        x, _, z = P.m(1.85, gy)
        p.add("casks", "barrel", ell([x, 0.27, z], [0.3, 0.22, 0.22]), "prop")
        p.add("cask_ends", "barrel_lid", cyl([x - 0.28, 0.27, z], [x - 0.3, 0.27, z], 0.18), "prop")
        p.add("chocks", "post", box([x, 0.04, z], [0.25, 0.04, 0.2]), "prop")
    p.paint("casks", "iron", stripes={"axis": "x", "period": 0.18, "width": 0.045})
    for gx, gy in ((1.62, 1.92), (1.85, 1.85)):
        x, _, z = P.m(gx, gy)
        p.add("baskets", "wicker", cone([x, 0, z], [x, 0.28, z], 0.15, 0.19), "prop")
        p.add("basket_grapes", "grape", ell([x, 0.3, z], [0.17, 0.08, 0.17]), "prop")
    p.paint("baskets", "log_groove", stripes={"axis": "y", "period": 0.08, "width": 0.055})
    p.spots = {"press": (1.42, 1.38), "cask": (1.62, 1.4)}
    K.tufts(p, P, [(1.95, 0.6), (1.05, 0.05)])
    return P, p, 240, 2.0


# =================================================================================================
# Sawmill: a plank saw-house with a long shingle roof and a loft hatch, an open drying shed with
# stacked planks on sticks in front; in the work yard a log on high trestles with a two-man frame
# saw in it, sawdust, a log pile at the back edge, a saw sign.
# =================================================================================================
def sawmill():
    P, p = Plot(2), Parts()
    K.ground(P, p, seed=38)
    for gx, gy in ((1.35, 1.75), (1.6, 1.5)):
        K.patch(p, "sawdust", "chips", P, gx, gy, 0.15, 0.1)
    house = (0.1, 0.95, 0.12, 1.15)
    g, eave, top = K.house(p, P, "house", house, ground="board", ground_h=1.8, axis="gy", rise=1.3,
                           roof_mat="shingle", roof_dark="shingle_dark", plinth_mat="fieldstone", roof_spots=("moss", 0.09, 0.12, 5))
    x0, x1, z0, z1 = P.rect(*house)
    for (x, z) in ((x0, z0), (x0, z1), (x1, z1)):
        p.add("corner_posts", "timber", box([x, 1.0, z], [0.07, 0.8, 0.07]), "wall")
    p.add("loft_hatch", "door_wood", box([x0 - 0.04, 2.25, (z0 + z1) / 2], [0.04, 0.24, 0.2]), "wall")
    K.door_right(p, P, "door", 0.85, z1, 0.2, w=0.7, h=1.2, arch=False)
    K.window_right(p, P, 0.35, z1, 1.1, w=0.3, h=0.3)
    K.sign_right(p, P, 1.12, z1, 1.6, emblem_saw)
    # Drying shed: posts and a shingle roof over planks stacked with sticks between.
    shed = (0.12, 0.92, 1.2, 1.95)
    K.lean_to(p, P, "shed_roof", shed, "-gy", 1.25, 1.75, "shingle", "shingle_dark", over=0.08)
    sx0, sx1, sz0, sz1 = P.rect(*shed)
    for k in range(5):
        y = 0.1 + k * 0.12
        p.add("planks_%s" % ("a" if k % 2 else "b"), "plank" if k % 2 else "plank_alt",
              box([(sx0 + sx1) / 2 + 0.05, y, (sz0 + sz1) / 2], [(sx1 - sx0) / 2 - 0.15, 0.045, (sz1 - sz0) / 2 - 0.15]), "prop")
        for dz in (-0.5, 0.0, 0.5):
            p.add("sticks", "post", box([(sx0 + sx1) / 2 + 0.05, y + 0.06, (sz0 + sz1) / 2 + dz], [(sx1 - sx0) / 2 - 0.12, 0.015, 0.03]),
                  "prop")
    # Saw trestles with a log and a frame saw in the work yard.
    a, b = P.m(1.15, 1.72), P.m(1.88, 1.72)
    for q in (P.m(1.25, 1.72), P.m(1.78, 1.72)):
        for s in (-1, 1):
            p.add("trestles", "post", box([q[0], 0.4, q[2]], [0.035, 0.45, 0.035], rot=[s * 0.35, 0, 0]), "prop")
        p.add("trestles", "post", box([q[0], 0.82, q[2]], [0.06, 0.04, 0.2]), "prop")
    K.log(p, P, (1.08, 1.72), (1.95, 1.72), 0.17, "saw_log", y=1.0)
    m = P.m(1.5, 1.72)
    p.add("frame_saw", "post", box([m[0], 1.0, m[2]], [0.02, 0.55, 0.3]), "prop", priority=2)
    p.cut("frame_saw", box([m[0], 1.0, m[2]], [0.05, 0.5, 0.25]))
    p.add("saw_blade", "steel", box([m[0], 1.0, m[2]], [0.01, 0.55, 0.02]), "prop", priority=2, min_cover=2)
    # A log pile on the stack tile's back edge (low) and a cant hook.
    for k, (gx, r) in enumerate(((1.2, 0.14), (1.5, 0.14), (1.35, 0.13))):
        y = r if k < 2 else 0.38
        K.log(p, P, (gx, 0.08), (gx, 0.5), r, "log_pile", y=y)
    K.tufts(p, P, [(1.95, 0.75), (0.05, 1.97)])
    p.spots = {"bench": (1.38, 1.52)}
    return P, p, 224, 1.9


# =================================================================================================
# Blacksmith: a fieldstone smithy with a great chimney and a hooded open forge facing the yard
# (glowing coals, leather bellows), a red-tiled roof; an anvil on its stump, a quenching trough, a
# rack of tongs and hammers, horseshoes on the wall, a horseshoe sign.
# =================================================================================================
def blacksmith():
    P, p = Plot(2), Parts()
    K.ground(P, p, seed=40)
    K.patch(p, "soot_ground", "charcoal", P, 1.3, 1.35, 0.22, 0.15, y=0.013)
    house = (0.1, 0.92, 0.12, 1.45)
    g, eave, top = K.house(p, P, "house", house, ground="fieldstone", ground_h=1.75, axis="gy", rise=1.3,
                           roof_mat="tile", roof_dark="tile_dark", with_quoins=True)
    x0, x1, z0, z1 = P.rect(*house)
    # Forge: a stone hearth built out from the right face, its hood up into a great chimney.
    fz = z1
    fx = P.m(0, 1.12)[0]
    p.add("forge", "fieldstone", box([fx, 0.38, fz + 0.3], [0.38, 0.38, 0.3]), "wall")
    p.paint("forge", "stone_dark", spots={"scale": 0.06, "density": 0.4, "seed": 8})
    p.add("coals", "charcoal", box([fx, 0.78, fz + 0.32], [0.3, 0.03, 0.22]), "wall")
    p.add("coals_glow", "flame", ell([fx, 0.8, fz + 0.38], [0.16, 0.05, 0.1]), "wall")
    p.add("hood", "fieldstone", ext([fx, 0, fz + 0.32], [[-0.42, 1.35], [0.42, 1.35], [0.2, 1.85], [-0.2, 1.85]], 0.62,
                                    rot=[0, 1.5708, 0]), "wall")
    p.add("hood", "fieldstone", ext([fx, 0, fz + 0.32], [[-0.4, 1.35], [0.4, 1.35], [0.18, 1.85], [-0.18, 1.85]], 0.8), "wall")
    for dx in (-0.36, 0.36):
        p.add("hood_posts", "timber", box([fx + dx, 1.08, fz + 0.55], [0.05, 0.3, 0.05]), "wall")
    K.chimney(p, P, "chimney", 0.82, 1.12, 1.85, 3.9, w=0.24, mat="fieldstone", cap="stone")
    p["chimney"]["paint"] = [{"material": "stone_dark", "spots": {"scale": 0.07, "density": 0.38, "seed": 9}}]
    bx = fx + 0.55
    p.add("bellows", "leather", ext([bx, 0.75, fz + 0.3], [[-0.3, -0.12], [0.25, -0.03], [0.25, 0.03], [-0.3, 0.12]], 0.35,
                                    rot=[0, 1.5708, 0]), "wall")
    p.add("bellows_arm", "post", cyl([bx + 0.3, 1.2, fz + 0.3], [bx - 0.2, 0.95, fz + 0.3], 0.03), "wall")
    K.door_right(p, P, "door", 0.45, z1, 0.2, w=0.5, h=1.0, arch=True, frame="sill_mat")
    K.window_left(p, P, 0.5, x0, 1.05, w=0.3, h=0.32, open_=False)
    for i, y in enumerate((1.25, 1.4)):
        q = P.m(0, 0.82 + 0.1 * i)
        p.add("shoes_on_wall", "iron", tor([q[0], y, z1 + 0.04], 0.07, 0.02, rot=[1.5708, 0, 0]), "wall", priority=2)
    K.sign_right(p, P, 0.2, z1, 1.55, emblem_horseshoe)
    # Anvil on its stump, the quenching trough, a tool rack.
    ax, _, az = P.m(1.55, 1.55)
    p.add("anvil_stump", "log_bark", cyl([ax, 0, az], [ax, 0.36, az], 0.2), "prop")
    p.add("anvil", "iron", box([ax, 0.45, az], [0.09, 0.09, 0.2]), "prop")
    p.add("anvil", "iron", box([ax, 0.55, az], [0.12, 0.04, 0.24]), "prop")
    p.add("anvil", "iron", cone([ax, 0.55, az + 0.24], [ax, 0.55, az + 0.42], 0.05, 0.01), "prop")
    p.add("hot_iron", "flame", box([ax, 0.6, az - 0.05], [0.02, 0.015, 0.12]), "prop")
    tx, _, tz = P.m(1.85, 1.85)
    p.add("trough", "board", box([tx, 0.2, tz], [0.4, 0.2, 0.17]), "prop")
    p.cut("trough", box([tx, 0.32, tz], [0.34, 0.12, 0.11]))
    p.add("trough_water", "water", box([tx, 0.3, tz], [0.34, 0.01, 0.11]), "prop")
    rx, _, rz = P.m(1.9, 1.15)
    p.add("tool_rack", "post", box([rx, 0.55, rz], [0.04, 0.55, 0.3]), "prop")
    p.add("tool_rack", "post", box([rx, 0.9, rz], [0.05, 0.03, 0.34]), "prop")
    for i in range(4):
        p.add("tongs", "iron", box([rx - 0.05, 0.62, rz - 0.22 + i * 0.15], [0.015, 0.28, 0.02]), "prop", priority=2)
    p.spots = {"forge": (1.38, 1.15), "anvil": (1.42, 1.72)}
    K.tufts(p, P, [(1.95, 0.6), (1.05, 0.05), (0.05, 1.97)])
    return P, p, 240, 2.05


# =================================================================================================
# Smelter: a squat bloomery tower of stone and clay, wider at the foot, iron bands, a glowing
# tapping arch and a flame at the throat, a great double bellows worked from a shed; heaps of ore
# and charcoal, iron blooms on a stone, slag; a brick-and-timber hut for the smelters.
# =================================================================================================
def smelter():
    P, p = Plot(2), Parts()
    K.ground(P, p, seed=42)
    K.patch(p, "slag_ground", "charcoal", P, 1.3, 1.5, 0.3, 0.2, y=0.013)
    hut = (0.1, 0.92, 0.12, 0.95)
    g, eave, top = K.house(p, P, "hut", hut, ground="brick", ground_h=1.35, upper="plaster", upper_h=0.7, axis="gx",
                           rise=1.1, roof_mat="slate", roof_dark="slate_dark", posts=(2, 2))
    x0, x1, z0, z1 = P.rect(*hut)
    K.door_right(p, P, "door", 0.5, z1, 0.2, w=0.46, h=0.9, arch=True, frame="brick")
    K.window_left(p, P, 0.5, x0, 0.85, w=0.26, h=0.28, open_=False)
    # The furnace tower in front of the hut.
    fg = (0.55, 1.45)
    fx, _, fz = P.m(*fg)
    p.add("furnace", "fieldstone", {"revolve": {"c": K.r4([fx, 0, fz]), "profile": {"polygon": [
        [0, 0], [0.72, 0], [0.7, 0.4], [0.55, 1.6], [0.42, 2.25], [0.3, 2.3], [0, 2.3]]}}}, "wall")
    p.paint("furnace", "stone_dark", spots={"scale": 0.07, "density": 0.4, "seed": 6})
    p.paint("furnace", "iron", stripes={"axis": "y", "at": [0.7, 1.35, 1.95], "width": 0.06})
    p.footprints.append((0.2, 0.9, 1.1, 1.8))
    p.add("throat_glow", "flame", cyl([fx, 2.28, fz], [fx, 2.32, fz], 0.22), "wall")
    K.wisp(p, [fx, 2.35, fz], 0.8, 5)
    p.add("tap_arch", "brick", box([fx, 0.38, fz + 0.66], [0.26, 0.38, 0.08]), "wall")
    p.add("tap_hole", "dark_hole", box([fx, 0.28, fz + 0.72], [0.15, 0.22, 0.03]), "wall")
    p.add("tap_glow", "flame", box([fx, 0.18, fz + 0.74], [0.1, 0.1, 0.02]), "wall")
    p.add("tap_slag", "charcoal", ell([fx, 0.03, fz + 0.95], [0.25, 0.04, 0.2]), "prop")
    # Bellows shed against the furnace's left side: two great bellows under a lean-to.
    for i, dz in enumerate((-0.25, 0.22)):
        p.add("bellows", "leather", ext([fx - 0.95, 0.45 + 0.08 * i, fz + dz],
                                        [[-0.4, -0.13], [0.3, -0.03], [0.3, 0.03], [-0.4, 0.13]], 0.32, rot=[0, 1.5708, 0]), "prop")
        p.add("bellows_board", "board", box([fx - 1.05, 0.6 + 0.08 * i, fz + dz], [0.38, 0.03, 0.18], rot=[0, 0, 0.15]), "prop")
    p.add("bellows_beam", "post", box([fx - 1.1, 1.15, fz], [0.05, 0.05, 0.5]), "prop")
    for dz in (-0.45, 0.45):
        p.add("bellows_posts", "post", cyl([fx - 1.1, 0, fz + dz], [fx - 1.1, 1.15, fz + dz], 0.05), "prop")
    # Heaps of ore and charcoal on the yard's right edge, blooms on a stone, a long rake.
    for (gx, gy, mat) in ((1.85, 1.3, "ore"), (1.82, 1.75, "charcoal")):
        x, _, z = P.m(gx, gy)
        p.add("heap_" + mat, mat, ell([x, 0.05, z], [0.3, 0.32, 0.3]), "prop", blend=0.05)
        p.paint("heap_" + mat, "stone_dark", spots={"scale": 0.05, "density": 0.3, "seed": 3})
    x, _, z = P.m(1.25, 1.9)
    p.add("bloom_stone", "stone", box([x, 0.15, z], [0.22, 0.15, 0.22], round_=0.03), "prop")
    for dz in (-0.08, 0.1):
        p.add("blooms", "iron", ell([x, 0.36, z + dz], [0.1, 0.07, 0.09]), "prop")
    a, b = P.m(1.05, 1.15, 0.0), P.m(1.05, 1.0, 1.5)
    p.add("rake", "haft", cyl(a, b, 0.025), "prop", priority=2, min_cover=2)
    p.spots = {"furnace": (1.38, 1.55)}
    K.tufts(p, P, [(1.95, 0.6), (1.05, 0.05)])
    return P, p, 240, 2.05


# =================================================================================================
# Brickworks: a moulders' shed of planks with a long low roof over racks of green bricks drying, a
# vaulted brick kiln with two arched fire-holes towards the yard and a short stack; a moulding
# table with a mould and a lump of clay, a stack of fired bricks, a water tub, a clay heap.
# =================================================================================================
def brickworks():
    P, p = Plot(2), Parts()
    K.ground(P, p, seed=44)
    K.patch(p, "clay_ground", "clay_dark", P, 1.5, 1.4, 0.3, 0.2, y=0.013)
    shed = (0.1, 0.95, 0.1, 0.95)
    p.footprints.append(shed)
    K.plinth(p, P, "shed_plinth", shed, h=0.15, mat="brick")
    sx0, sx1, sz0, sz1 = P.rect(*shed)
    p.add("shed_back", "board", box([sx1 - 0.05, 0.75, (sz0 + sz1) / 2], [0.05, 0.75, (sz1 - sz0) / 2]), "wall")
    p.add("shed_back", "board", box([(sx0 + sx1) / 2, 0.75, sz0 + 0.05], [(sx1 - sx0) / 2, 0.75, 0.05]), "wall")
    p.paint("shed_back", "ink", stripes={"axis": "x", "period": 0.18, "width": 0.045})
    p.paint("shed_back", "ink", stripes={"axis": "z", "period": 0.18, "width": 0.045})
    K.hip_roof(p, P, "shed_roof", shed, 1.45, 2.45, "tile", "tile_dark", over=0.22, course=0.13)
    for (x, z) in ((sx0 + 0.08, sz0 + 0.08), (sx0 + 0.08, sz1 - 0.08), (sx1 - 0.08, sz1 - 0.08)):
        p.add("shed_posts", "timber", box([x, 0.75, z], [0.06, 0.75, 0.06]), "wall")
    for k in range(3):
        y = 0.25 + k * 0.38
        p.add("racks", "board", box([(sx0 + sx1) / 2, y, (sz0 + sz1) / 2], [(sx1 - sx0) / 2 - 0.25, 0.025, (sz1 - sz0) / 2 - 0.25]), "prop")
        for i in range(6):
            for j in range(2):
                p.add("green_bricks_%d" % ((i + j) % 2), "clay" if (i + j) % 2 else "clay_light",
                      box([sx0 + 0.45 + j * 0.45, y + 0.08, sz0 + 0.35 + i * 0.27], [0.18, 0.055, 0.09]), "prop")
    # The kiln in front: a brick vault, arched fire-holes on the yard side, a stack.
    kiln = (0.12, 0.95, 1.1, 1.92)
    kx0, kx1, kz0, kz1 = P.rect(*kiln)
    kc = [(kx0 + kx1) / 2, 0, (kz0 + kz1) / 2]
    p.footprints.append(kiln)
    p.add("kiln", "brick", box([kc[0], 0.55, kc[2]], [(kx1 - kx0) / 2, 0.55, (kz1 - kz0) / 2]), "wall")
    p.add("kiln", "brick", cyl([kx0, 1.1, kc[2]], [kx1, 1.1, kc[2]], (kz1 - kz0) / 2 - 0.02), "wall")
    p.cut("kiln", plane([0, -1, 0], [0, 0.02, 0]))
    p.paint("kiln", "brick_line", stripes={"axis": "y", "period": 0.12, "width": 0.035})
    p.add("kiln_ends", "brick", ext([kx0 - 0.02, 0, kc[2]], [[-(kz1 - kz0) / 2 - 0.05, 0], [(kz1 - kz0) / 2 + 0.05, 0],
                                                            [(kz1 - kz0) / 2 + 0.05, 1.1], [0, 1.95], [-(kz1 - kz0) / 2 - 0.05, 1.1]],
                                    0.08, rot=[0, 1.5708, 0]), "wall")
    for dx in (-0.4, 0.4):
        p.add("fire_holes", "dark_hole", box([kc[0] + dx, 0.3, kz1 + 0.01], [0.16, 0.2, 0.03]), "wall")
        p.add("fire_holes", "dark_hole", cyl([kc[0] + dx, 0.5, kz1 - 0.02], [kc[0] + dx, 0.5, kz1 + 0.04], 0.16), "wall")
        p.add("fire_glow", "flame", box([kc[0] + dx, 0.2, kz1 + 0.04], [0.1, 0.1, 0.01]), "wall")
    K.chimney(p, P, "kiln_stack", 0.55, 1.5, 1.7, 2.8, w=0.18)
    K.wisp(p, [P.m(0.55, 1.5)[0], 2.95, P.m(0.55, 1.5)[2]], 0.7, 4)
    # Moulding table, fired bricks, water tub, clay heap.
    tx, _, tz = P.m(1.82, 1.38)
    p.add("mould_table", "board", box([tx, 0.5, tz], [0.38, 0.04, 0.2]), "prop")
    for dx in (-0.32, 0.32):
        p.add("mould_table_legs", "post", box([tx + dx, 0.24, tz], [0.04, 0.24, 0.16]), "prop")
    p.add("mould", "board", box([tx + 0.1, 0.58, tz], [0.14, 0.04, 0.08]), "prop")
    p.add("clay_lump", "clay", ell([tx - 0.15, 0.6, tz], [0.12, 0.08, 0.1]), "prop")
    x, _, z = P.m(1.25, 1.92)
    for k in range(4):
        p.add("fired_bricks_%d" % (k % 2), "brick" if k % 2 else "brick_alt",
              box([x, 0.07 + k * 0.13, z], [0.2, 0.06, 0.3]), "prop")
    K.tub(p, P, "water_tub", 1.78, 1.85, 0.2, 0.36, fill="water")
    x, _, z = P.m(1.2, 1.12)
    p.add("clay_heap", "clay", ell([x, 0.05, z], [0.28, 0.28, 0.28]), "prop", blend=0.05)
    p.spots = {"table": (1.62, 1.38), "kiln": (1.35, 1.72)}
    K.tufts(p, P, [(1.95, 0.6), (1.05, 0.05)])
    return P, p, 224, 1.8


# =================================================================================================
# Weaver: a tall narrow town house, a jettied half-timbered upper floor with big windows for light,
# a steep slate roof with a hoist gable; an open pentice in front sheltering a great floor loom
# with cloth on the beam; a spinning wheel and baskets of wool in the yard, dyed cloth drying on a
# pole, a sign with a striped bolt.
# =================================================================================================
def weaver():
    P, p = Plot(2), Parts()
    K.ground(P, p, mat="cobble_ground", seed=46)
    house = (0.1, 0.95, 0.12, 1.15)
    g, eave, top = K.house(p, P, "house", house, ground="plaster", ground_h=1.5, upper="plaster", upper_h=1.0, axis="gx",
                           rise=1.45, roof_mat="slate", roof_dark="slate_dark", frame_ground=True, posts=(3, 3))
    x0, x1, z0, z1 = P.rect(*house)
    tz1 = P.rect(*top)[3]
    K.door_right(p, P, "door", 0.65, z1, 0.2, w=0.46, h=0.95, arch=False)
    for gy in (0.3, 0.75):
        K.window_right(p, P, gy, tz1, 2.05, w=0.36, h=0.45, shutters=False)
    K.window_left(p, P, 0.53, P.rect(*top)[0], 2.05, w=0.42, h=0.45, shutters=False)
    K.window_left(p, P, 0.53, x0, 0.95, w=0.36, h=0.36)
    K.sign_right(p, P, 1.05, z1, 1.35, emblem_shuttle)
    K.chimney(p, P, "chimney", 0.2, 0.3, 2.8, 4.1, w=0.16)
    # Pentice with the loom.
    pen = (0.12, 0.95, 1.18, 1.92)
    K.lean_to(p, P, "pentice", pen, "-gy", 1.4, 1.75, "slate", "slate_dark", over=0.06)
    px0, px1, pz0, pz1 = P.rect(*pen)
    lx, lz = (px0 + px1) / 2, (pz0 + pz1) / 2
    for dz in (-0.45, 0.45):
        for dx in (-0.3, 0.3):
            p.add("loom_frame", "post", box([lx + dx, 0.6, lz + dz], [0.04, 0.6, 0.04]), "prop")
        p.add("loom_frame", "post", box([lx, 1.18, lz + dz], [0.34, 0.04, 0.04]), "prop")
    for dx in (-0.3, 0.3):
        p.add("loom_beams", "post", cyl([lx + dx, 0.75, lz - 0.48], [lx + dx, 0.75, lz + 0.48], 0.05), "prop")
    p.add("warp", "cloth_red", box([lx, 0.76, lz], [0.3, 0.012, 0.42]), "prop")
    p.paint("warp", "cloth_blue", stripes={"axis": "z", "period": 0.12, "width": 0.055})
    p.add("cloth_roll", "cloth_red", cyl([lx - 0.3, 0.7, lz - 0.4], [lx - 0.3, 0.7, lz + 0.4], 0.09), "prop")
    p.add("heddles", "post", box([lx, 1.0, lz], [0.03, 0.15, 0.44]), "prop")
    # Spinning wheel, wool baskets, cloth drying on a pole.
    wx, _, wz = P.m(1.75, 1.35)
    p.add("wheel_bench", "board", box([wx, 0.35, wz], [0.32, 0.04, 0.1], rot=[0, 0.3, 0]), "prop")
    for dx in (-0.25, 0.25):
        p.add("wheel_legs", "post", box([wx + dx, 0.17, wz], [0.03, 0.17, 0.03]), "prop")
    p.add("spin_wheel", "post", tor([wx + 0.15, 0.68, wz - 0.05], 0.26, 0.03, rot=[0, 0, 1.5708]), "prop")
    p.add("spin_wheel", "post", cyl([wx + 0.15, 0.4, wz - 0.05], [wx + 0.15, 0.68, wz - 0.05], 0.025), "prop")
    p.add("distaff", "wool", ell([wx - 0.2, 0.62, wz], [0.06, 0.1, 0.06]), "prop")
    for gx, gy in ((1.18, 1.9), (1.4, 1.95)):
        x, _, z = P.m(gx, gy)
        p.add("wool_baskets", "wicker", cone([x, 0, z], [x, 0.28, z], 0.15, 0.18), "prop")
        p.add("wool_in", "wool", ell([x, 0.3, z], [0.17, 0.09, 0.17]), "prop")
    a, b = P.m(1.92, 1.6), P.m(1.92, 1.95)
    for q in (a, b):
        p.add("dry_poles", "post", cyl([q[0], 0, q[2]], [q[0], 1.2, q[2]], 0.035), "prop")
    p.add("dry_poles", "post", cyl([a[0], 1.18, a[2]], [b[0], 1.18, b[2]], 0.03), "prop")
    p.add("dyed_cloth", "cloth_blue", box([(a[0] + b[0]) / 2, 0.85, a[2]], [abs(b[0] - a[0]) / 2 - 0.05, 0.32, 0.015]), "prop")
    p.add("dyed_cloth2", "cloth_green", box([(a[0] + b[0]) / 2 + 0.02, 0.95, a[2] - 0.05], [abs(b[0] - a[0]) / 2 - 0.12, 0.22, 0.015]),
          "prop")
    p.spots = {"loom": (1.1, 1.62), "wheel": (1.55, 1.38)}
    K.tufts(p, P, [(1.95, 0.6), (1.05, 0.05)])
    return P, p, 256, 2.25


# =================================================================================================
# Tailor: a narrow town house with two jettied upper floors under red tiles, a shop front whose
# lower shutter folds down into a counter with folded cloth; a cutting table in the yard with a bolt,
# shears and a chalk line, a dressmaker's dummy, garments on a line, a sign with shears.
# =================================================================================================
def tailor():
    P, p = Plot(2), Parts()
    K.ground(P, p, mat="cobble_ground", seed=48)
    house = (0.12, 0.95, 0.14, 1.2)
    g, eave, top = K.house(p, P, "house", house, ground="plaster_ochre", ground_h=1.45, upper="plaster", upper_h=0.85,
                           axis="gy", rise=1.5, frame_ground=True, posts=(2, 4))
    # A second jettied floor.
    j = 0.1 / K.T
    top2 = (top[0] - j, top[1] + j, top[2] - j, top[3] + j)
    x0, x1, z0, z1 = P.rect(*house)
    t0, t1, tz0, tz1 = P.rect(*top2)
    p.add("jetty2", "timber", box([(t0 + t1) / 2, eave + 0.02, (tz0 + tz1) / 2], [(t1 - t0) / 2 + 0.03, 0.06, (tz1 - tz0) / 2 + 0.03]), "wall")
    K.walls(p, P, "upper2", top2, eave + 0.06, eave + 0.8, "plaster")
    K.timber_left(p, P, "upper2_frame", top2, eave + 0.06, eave + 0.8, 2)
    K.timber_right(p, P, "upper2_frame", top2, eave + 0.06, eave + 0.8, 4)
    # Raise the roof onto the second floor.
    for nm in ("house_roof", "house_cap", "house_barge", "house_gable", "house_gframe"):
        del p[nm]
    p.roofs.pop()
    g2 = Gable(P, "house2", top2, "gy", eave + 0.8, eave + 2.25, over=0.3, end_over=0.24)
    g2.infill(p, "plaster")
    g2.gable_frame(p)
    g2.roof(p, "tile", "tile_dark", course=0.13)
    g2.bargeboards(p)
    p.roofs.append(g2)
    K.chimney(p, P, "chimney", 0.3, 0.45, 3.4, 4.75, w=0.17)
    for gy in (0.4, 0.95):
        K.window_right(p, P, gy, P.rect(*top)[3], 1.85, w=0.3, h=0.34, box_=gy == 0.4)
        K.window_right(p, P, gy, tz1, 2.7, w=0.28, h=0.3)
    K.window_left(p, P, 0.53, t0, 2.7, w=0.28, h=0.3)
    K.window_left(p, P, 0.53, P.rect(*top)[0], 1.85, w=0.3, h=0.34)
    # Shop front: an opening with the upper shutter propped up and the lower one as a counter.
    sx = P.m(0, 0.45)[0]
    p.add("shop_opening", "dark_hole", box([sx, 0.95, z1 + 0.01], [0.32, 0.28, 0.03]), "wall")
    p.add("shop_counter", "board", box([sx, 0.66, z1 + 0.2], [0.34, 0.035, 0.2]), "wall")
    p.add("shop_shutter", "shutter", box([sx, 1.32, z1 + 0.17], [0.34, 0.035, 0.18], rot=[-0.6, 0, 0]), "wall")
    for dx, mat in ((-0.18, "cloth_red"), (0.0, "cloth_blue"), (0.18, "cloth_green")):
        p.add("counter_cloth_" + mat, mat, box([sx + dx, 0.73, z1 + 0.22], [0.08, 0.035, 0.13]), "wall")
    K.door_right(p, P, "door", 1.0, z1, 0.2, w=0.44, h=0.92, arch=False)
    K.sign_right(p, P, 1.18, z1, 1.6, emblem_shears)
    # Cutting table, dummy, garments on a line.
    tx, _, tz = P.m(1.55, 1.75)
    p.add("cut_table", "board", box([tx, 0.5, tz], [0.22, 0.04, 0.42]), "prop")
    for dz in (-0.36, 0.36):
        p.add("cut_table_legs", "post", box([tx, 0.24, tz + dz], [0.18, 0.24, 0.04]), "prop")
    p.add("cut_cloth", "cloth_red", box([tx, 0.56, tz + 0.1], [0.18, 0.015, 0.26]), "prop")
    p.add("cut_bolt", "cloth_blue", cyl([tx - 0.12, 0.6, tz - 0.4], [tx + 0.12, 0.6, tz - 0.4], 0.07), "prop")
    p.add("shears", "steel", box([tx, 0.58, tz + 0.05], [0.02, 0.01, 0.1]), "prop", priority=2)
    x, _, z = P.m(1.9, 1.35)
    p.add("dummy", "post", cyl([x, 0, z], [x, 0.85, z], 0.03), "prop")
    p.add("dummy", "post", cone([x - 0.08, 0, z], [x, 0.1, z], 0.15, 0.02), "prop")
    p.add("dummy_body", "cloth_green", ell([x, 1.05, z], [0.15, 0.24, 0.12]), "prop")
    a, b = P.m(1.15, 1.97), P.m(1.95, 1.97)
    for q in (a, b):
        p.add("line_posts", "post", cyl([q[0], 0, q[2]], [q[0], 1.15, q[2]], 0.035), "prop")
    p.add("line", "rope", cyl([a[0], 1.1, a[2]], [b[0], 1.1, b[2]], 0.015), "prop", min_cover=1)
    for i, mat in enumerate(("cloth_red", "bone", "cloth_blue")):
        z = a[2] + 0.35 + i * 0.55
        p.add("garments_" + mat, mat, ext([a[0], 0, z], [[-0.18, 1.08], [0.18, 1.08], [0.15, 0.65], [-0.15, 0.65]], 0.03,
                                          rot=[0, 1.5708, 0]), "prop")
    p.spots = {"table": (1.35, 1.72)}
    K.tufts(p, P, [(1.95, 0.6), (1.05, 0.05)])
    return P, p, 288, 2.55


# =================================================================================================
# Slaughterhouse: a long fieldstone building with a half-timbered gable under red tiles, a wide door
# and a drain gutter running out to a stone basin; a gallows rack with carcasses and a hide stretched
# on a frame; a chopping block with a cleaver, a tub of salt, barrels, an ox-head sign.
# =================================================================================================
def slaughterhouse():
    P, p = Plot(2), Parts()
    K.ground(P, p, seed=50)
    K.patch(p, "stain", "meat_dark", P, 1.35, 1.75, 0.14, 0.1, y=0.013)
    house = (0.1, 0.92, 0.1, 1.45)
    g, eave, top = K.house(p, P, "house", house, ground="fieldstone", ground_h=1.6, axis="gy", rise=1.3, with_quoins=True)
    x0, x1, z0, z1 = P.rect(*house)
    K.door_right(p, P, "door", 0.95, z1, 0.2, w=0.6, h=1.0, arch=True, frame="sill_mat")
    K.window_right(p, P, 0.35, z1, 1.05, w=0.28, h=0.3, open_=False)
    K.window_left(p, P, 0.5, x0, 2.15, w=0.26, h=0.3, shutters=False)
    K.sign_right(p, P, 1.32, z1, 1.45, emblem_ox)
    K.dormer(p, P, g, "dormer", 0.45, roof_mat="tile", dark="tile_dark")
    # Drain gutter from the door to a stone basin.
    a = P.m(1.0, 0.95)
    p.add("gutter", "stone", box([a[0], 0.03, a[2] + 0.4], [0.09, 0.03, 0.42]), "prop")
    p.add("gutter_blood", "meat_dark", box([a[0], 0.065, a[2] + 0.4], [0.04, 0.01, 0.38]), "prop")
    # Gallows rack with carcasses at the yard's right edge.
    r0, r1 = P.m(1.9, 1.05), P.m(1.9, 1.6)
    for q in (r0, r1):
        p.add("rack", "timber", box([q[0], 0.85, q[2]], [0.05, 0.85, 0.05]), "prop")
    p.add("rack", "timber", box([(r0[0] + r1[0]) / 2, 1.68, r0[2]], [abs(r1[0] - r0[0]) / 2 + 0.06, 0.05, 0.05]), "prop")
    for i in range(2):
        x = r0[0] + (r1[0] - r0[0]) * (0.3 + 0.4 * i)
        p.add("hooks", "iron", cyl([x, 1.63, r0[2]], [x, 1.45, r0[2]], 0.015), "prop", min_cover=1)
        p.add("carcasses", "meat", ell([x, 1.05, r0[2]], [0.13, 0.38, 0.11]), "prop")
        p.add("carcass_fat", "bone", ell([x, 1.3, r0[2] + 0.03], [0.1, 0.12, 0.09]), "prop")
    # Hide on a frame by the front edge, chopping block with a cleaver, salt tub, barrels.
    a, b = P.m(1.3, 1.97), P.m(1.85, 1.97)
    for q in (a, b):
        p.add("hide_frame", "post", cyl([q[0], 0, q[2]], [q[0], 1.0, q[2]], 0.035), "prop")
    p.add("hide_frame", "post", cyl([a[0], 0.95, a[2]], [b[0], 0.95, b[2]], 0.03), "prop")
    p.add("hide", "hide", box([(a[0] + b[0]) / 2, 0.58, a[2]], [abs(b[0] - a[0]) / 2 - 0.1, 0.3, 0.015]), "prop")
    K.stump(p, P, 1.38, 1.62, r=0.24, h=0.42, name="block")
    x, _, z = P.m(1.38, 1.62)
    p.add("cleaver", "steel", box([x - 0.05, 0.5, z + 0.05], [0.1, 0.07, 0.015], rot=[0, 0.5, 0.2]), "prop", priority=2)
    K.tub(p, P, "salt_tub", 1.12, 1.88, 0.18, 0.32, fill="flour")
    K.barrel(p, P, 1.12, 1.3, r=0.17, h=0.42)
    p.spots = {"block": (1.55, 1.72), "rack": (1.7, 1.32)}
    K.tufts(p, P, [(1.95, 0.6), (1.05, 0.05)])
    return P, p, 240, 2.0


def axe_sign(p, c):
    """Two crossed axes painted on a sign board."""
    x, y, z = c
    for s in (-1, 1):
        p.add("sign_emblem", "haft", box([x, y, z], [0.02, 0.15, 0.012], rot=[0, 0, s * 0.7]), "wall", priority=3)
        p.add("sign_emblem", "steel", box([x + s * 0.09, y + 0.09, z + 0.005], [0.06, 0.04, 0.012]), "wall", priority=3)


BUILDINGS = {
    "smelter": (smelter, "Your Kingdom smelter (G3 part 3b), 2x2 tiles: a bloomery tower of fieldstone with iron "
                "bands, a glowing tapping arch and throat, great double bellows, heaps of ore and charcoal, iron "
                "blooms on a stone, a brick hut with a half-timbered gable under slate"),
    "brickworks": (brickworks, "Your Kingdom brickworks (G3 part 3b), 2x2 tiles: an open moulders' shed under a hipped "
                   "tile roof with racks of green bricks, a vaulted brick kiln with glowing fire-holes and a stack, a "
                   "moulding table, fired bricks, a water tub, a clay heap"),
    "weaver": (weaver, "Your Kingdom weaver (G3 part 3b), 2x2 tiles: a tall half-timbered town house with big windows "
               "under slate, a pentice over a great floor loom, a spinning wheel, baskets of wool, dyed cloth drying"),
    "tailor": (tailor, "Your Kingdom tailor (G3 part 3b), 2x2 tiles: a narrow town house with two jettied floors under "
               "red tiles, a shop front with a counter of folded cloth, a cutting table, a dummy, garments on a line, a "
               "shears sign"),
    "slaughterhouse": (slaughterhouse, "Your Kingdom slaughterhouse (G3 part 3b), 2x2 tiles: a long fieldstone building "
                       "under red tiles with a dormer, a drain gutter, a gallows rack with carcasses, a hide on a frame, "
                       "a chopping block with a cleaver, a salt tub, an ox-head sign"),
    "bakery": (bakery, "Your Kingdom bakery (G3 part 3b), 2x2 tiles: a half-timbered town house with a jettied upper "
               "floor under red tiles, a dormer, a great clay bread oven with a glowing mouth under its own roof, a "
               "kneading table with dough and loaves, a peel, a pretzel sign"),
    "brewery": (brewery, "Your Kingdom brewery (G3 part 3b), 2x2 tiles: a fieldstone brewhouse with quoins, a louvred "
                "lantern on the ridge, a tall chimney, an ale stake with a bush, a copper kettle on a brick hearth with "
                "fire, a mash tun with a paddle, casks and malt sacks"),
    "meadery": (meadery, "Your Kingdom meadery (G3 part 3b), 2x2 tiles: a wattle-and-daub house under a hipped thatch, "
                "a shelter with straw skeps, a honey vat with a ladle, casks on a trestle, honey crocks, a jug sign"),
    "wine_press": (wine_press, "Your Kingdom wine press (G3 part 3b), 2x2 tiles: a fieldstone press house with a half-"
                   "timbered gable to the yard, an arched door, a vine on a trellis, a screw press on a tub of must, "
                   "casks on chocks, baskets of grapes"),
    "sawmill": (sawmill, "Your Kingdom sawmill (G3 part 3b), 2x2 tiles: a plank saw-house under shingles with a loft "
                "hatch, a drying shed with planks stacked on sticks, a log on high trestles with a frame saw, sawdust, "
                "a log pile, a saw sign"),
    "blacksmith": (blacksmith, "Your Kingdom blacksmith (G3 part 3b), 2x2 tiles: a fieldstone smithy under red tiles, "
                   "an open hooded forge with glowing coals and leather bellows, a great chimney, an anvil on a stump, "
                   "a quenching trough, a rack of tongs, horseshoes on the wall"),
    "mill": (mill, "Your Kingdom mill (G3 part 3b), 2x2 tiles: a medieval post mill, a weatherboarded buck with a "
             "curved shingle roof on a great post, a trestle of crosstrees and quarter bars on brick piers, steps and "
             "a tail pole with a cart wheel down to the yard, sacks of grain and flour, a spare millstone; the four "
             "lattice sails turn in a separate animation"),
    "vineyard": (vineyard, "Your Kingdom vineyard (G3 part 3), 3x3 tiles: a vintner's house in an L, a stone ground "
                 "floor and a half-timbered upper floor under red tiles, an arched cellar door and an oriel in the "
                 "wing's gable, a press house with a beam press and casks, a pergola heavy with grapes over a bench"),
    "stable": (stable, "Your Kingdom stable (G3 part 3), 3x3 tiles: a long half-timbered stable on a stone plinth "
               "under a steep thatch, a hay loft door with a hoist and a bale, a horse vane, a wide braced stable "
               "door with a horseshoe, an open cart shed with a wagon, a railed paddock with a trough and a hay rack"),
    "clay_pit": (clay_pit, "Your Kingdom clay pit (G3 part 3), 2x2 tiles: a dug pit with layered clay banks and a "
                 "pool, a plank ramp, a well sweep with a bucket, clay blocks drying on boards, a heap of clay with "
                 "a spade, a wheelbarrow, a wattle-and-daub hut under a turf roof"),
    "farm": (farm, "Your Kingdom farm (G3 part 3), 2x2 tiles: a big plank barn under a half-hipped thatch with a "
             "braced double door, a hay loft with a hoist and a cockerel vane, a granary on staddle stones, a cart "
             "with sheaves, a pitchfork, sheaves and a dovecote on a pole"),
    "hop_farm": (hop_farm, "Your Kingdom hop farm (G3 part 3), 2x2 tiles: an oast house, a round brick kiln with a "
                 "steep conical tiled roof and a white cowl, joined to a half-timbered drying barn with a loading "
                 "door and a hoist, bundled hop poles, hop pockets and baskets of green hops"),
    "charcoal_burner": (charcoal_burner, "Your Kingdom charcoal burner (G3 part 3), 2x2 tiles: a big smoking "
                        "turf-covered clamp with a ladder, the collier's conical bark hut, cordwood, sacks and a "
                        "basket of charcoal, a rake"),
    "tar_kiln": (tar_kiln, "Your Kingdom tar kiln (G3 part 3), 2x2 tiles: a domed fieldstone kiln with iron bands, "
                 "a glowing firing door and smoke, a gutter to a tar pit and a barrel, stacked tar barrels, pine "
                 "stumps, a log hut under a plank roof weighted with stones"),
    "forester": (forester, "Your Kingdom forester (G3 part 3), 2x2 tiles: a keeper's lodge with a fieldstone "
                 "ground floor and an ochre half-timbered upper floor under a steep hipped thatch, an old oak, a "
                 "board tool shed with tools on its wall, a nursery bed with saplings, antlers over the door"),
    "quarry": (quarry, "Your Kingdom quarry (G3 part 3), 2x2 tiles: a stonecutter's lodge of dressed ashlar under "
               "slate with a coped stone gable towards the yard, an open masons' lodge with a banker and a "
               "half-dressed block, shear legs with a block on a chain, rough blocks and stone chips"),
    "fishing_hut": (fishing_hut, "Your Kingdom fishing hut (G3 part 3), 2x2 tiles: a weathered board hut under a "
                    "heavy reed thatch with a smoke hood, a fieldstone smokehouse, nets drying on poles, a rack "
                    "of drying fish, an upturned boat on trestles, oars, creels and a barrel"),
    "mine": (mine, "Your Kingdom mine (G3 part 3), 2x2 tiles: an adit with a timbered portal driven into a rocky "
             "knoll with a pine, rails out to an ore tub, an ore heap, a miners' log hut with a chimney, "
             "stacked pit props, picks by the portal"),
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
    hx, hy = getattr(parts, "heap", (1.5, 0.45))
    for k in range(3):
        a = P.m(hx - 0.2 + k * 0.14, hy - 0.25, 0.08)
        b = P.m(hx - 0.2 + k * 0.14, hy + 0.3, 0.08)
        out.add("beams", "raw_timber", box([(a[0] + b[0]) / 2, 0.08, a[2]], [abs(a[0] - b[0]) / 2, 0.08, 0.07]), "site")
    out.add("beams", "raw_timber", box(P.m(hx - 0.13, hy + 0.02, 0.24), [0.62, 0.08, 0.07]), "site")
    K.stones(out, P, [(hx + 0.25, hy - 0.15), (hx + 0.32, hy + 0.05), (hx + 0.18, hy), (hx + 0.26, hy - 0.03)], name="stone_heap")
    return out


SAIL_FRAMES = 8          # frames over a quarter turn (four sails)
SAIL_FPS = 4.0           # a quarter turn in 2 s: 7.5 turns a minute, slow
VISUALS = os.path.join(HERE, "..", "..", "data", "visuals", "buildings")


def write_spots(bid, P, parts):
    """Writes the work spots (game points on the plot) into data/visuals/buildings/<id>.tres as
    pixel offsets from the entrance tile's centre (BuildingVisualDef.spot_offsets)."""
    import re
    path = os.path.join(VISUALS, bid + ".tres")
    text = open(path).read()
    ent = ENTRANCES.get(bid, (1, 1))
    ex, ey = ent[0] + 0.5, ent[1] + 0.5
    rows = []
    for name, (gx, gy) in parts.spots.items():
        dx, dy = gx - ex, gy - ey
        rows.append('&"%s": Vector2(%d, %d)' % (name, round((dx - dy) * 32), round((dx + dy) * 16)))
    block = "spot_offsets = Dictionary[StringName, Vector2]({\n" + ",\n".join(rows) + "\n})\n"
    text = re.sub(r"spot_offsets = Dictionary\[StringName, Vector2\]\(\{.*?\}\)\n", "", text, flags=re.S)
    text = text.rstrip("\n") + "\n" + block
    open(path, "w").write(text)


ENTRANCES = {"vineyard": (2, 1), "stable": (1, 2)}


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
        if bid == "mill":
            for k in range(SAIL_FRAMES):
                _, sp = mill_sails(k * (math.pi / 2) / SAIL_FRAMES)
                s3 = head(f"mill_anim_{k}", size, cy, "the mill's sails, frame %d" % k)
                s3["parts"] = dict(sp)
                s3["animations"] = s["animations"]
                write(bid, s3)
            # Sorted just in front of the plot's front corner: the sails stand before the whole buck
            # (sorted at the ground under the hub, the buck's strips covered them).
            anim = {"frames": SAIL_FRAMES, "fps": SAIL_FPS, "sort_tile": [2.02, 2.02]}
            with open(os.path.join(HERE, "art", "specs", "props", bid, "anim.json"), "w") as fh:
                json.dump(anim, fh)
        if getattr(parts, "spots", None):
            write_spots(bid, P, parts)
        print("written", bid, n, "prims")


if __name__ == "__main__":
    main()
