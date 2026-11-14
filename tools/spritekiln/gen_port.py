"""G3 part 5a: the harbour's buildings from SpriteKiln (ROADMAP G3, "Część 5, plan").

Each designed anew (owner's survey 2026-11-14: very detailed and clearly medieval, like parts 3
and 4): the bollard, the mooring, the cargo crane, the port, the fishing wharf, the shipyard and
the large shipyard, the dockers' hut and house, and the roofed sheds of the port warehouses.
Same kit, spec head and construction stages as the workshops and the town (workshop_kit.py,
gen_workshops.py, gen_town.py). Sizes, entrances, water tiles and rules unchanged.

What the game draws itself and the art must fit (ART_SPEC 10.31):
- the timber pier or the stone quay over the water tiles and under buildings on piles (QuayLayer):
  its deck is at land height (model y = 0), the water lies WATER_Y lower;
- the port's quay yard (planks and goods stacks) on its land tiles (QuayYard): those tiles stay
  empty in the art, the shed over the back row is drawn as pieces sorted on their own;
- the crane's jib, rope, hook and load (CraneLayer): the mast foot, the collar height and the
  treadwheel's axle must stay where CraneLayer expects them (MAST_FOOT, HEEL_HEIGHT...);
- the ship being built on a shipyard's slipway (ShipLayer).

Writes art/specs/props/<id>/<id>.yaml, <id>_c1.yaml, <id>_c2.yaml (and <id>_<piece>.yaml with
pieces.json for buildings drawn in pieces); edit this script.
Run (inside tools/spritekiln): python3 gen_port.py [<id>...], then build_port.sh <id>...
"""
import json
import math
import os
import sys

import gen_town as TOWN
import gen_workshops as W
import workshop_kit as K
from workshop_kit import Gable, Parts, Plot, box, cone, cyl, ell, ext, plane, sph, tor

HERE = os.path.dirname(os.path.abspath(__file__))

# Model units per screen pixel of height (pitch 30: heights shrink by cos 30).
PX = 0.05176 / math.cos(math.radians(30))
# The water surface under a timber pier (QuayLayer: the pier's side is 14 px high).
WATER_Y = -14 * PX

RAMPS = dict(TOWN.RAMPS)
RAMPS.update({
    "tarred": ["#060404", "#1a120c", "#2c2016", "#3e2e20", "#52402c"],
    "bale": ["#2a2214", "#5e4e30", "#8c784e", "#b4a070", "#d4c294"],
    "verdigris": ["#0a1a16", "#1e4238", "#346856", "#4e8c74", "#76b49a"],
})


def materials():
    m = TOWN.materials()
    m.update({
        "tarred": {"ramp": "tarred", "bands": [1, 4]},
        "tarred_dark": {"ramp": "tarred", "bands": [0, 1], "outline": False},
        "bale": {"ramp": "bale", "bands": [1, 4]},
        "verdigris": {"ramp": "verdigris", "bands": [1, 4], "finish": "metal"},
        "water_edge": {"ramp": "water", "bands": [1, 3], "outline": False},
    })
    return m


def head(name, size, cy, summary):
    s = W.head(name, size, cy, summary)
    s["ramps"] = RAMPS
    s["materials"] = materials()
    return s


# --- shared harbour pieces (game coordinates of the plot) -----------------------------------------
def iron_bollard(p, P, gx, gy, name="bollards", r=0.13, h=0.36, y0=0.0):
    """A squat mooring bollard with a mushroom head, on a little stone block."""
    x, _, z = P.m(gx, gy)
    p.add(name + "_block", "ashlar", box([x, y0 + 0.05, z], [r + 0.08, 0.05, r + 0.08]), "found")
    p.add(name, "iron", cyl([x, y0 + 0.08, z], [x, y0 + h, z], r), "wall")
    p.add(name, "iron", ell([x, y0 + h + 0.02, z], [r * 1.45, 0.08, r * 1.45]), "wall")


def timber_bollard(p, P, gx, gy, name="posts", r=0.11, h=0.6, y0=0.0):
    """A thick tarred oak post with an iron cap, rope burn on it."""
    x, _, z = P.m(gx, gy)
    p.add(name, "tarred", cyl([x, WATER_Y, z], [x, y0 + h, z], r), "wall")
    p.add(name + "_cap", "iron", cyl([x, y0 + h, z], [x, y0 + h + 0.05, z], r * 1.05), "wall")
    p.add(name + "_cap", "iron", tor([x, y0 + h * 0.6, z], r, 0.025), "wall")


def rope_coil(p, P, gx, gy, r=0.16, turns=3, name="rope_coils", y0=0.0):
    x, _, z = P.m(gx, gy)
    for k in range(turns):
        p.add(name, "rope", tor([x, y0 + 0.03 + k * 0.045, z], r - k * 0.02, 0.03), "prop")


def hawser(p, a, b, sag=0.15, name="hawsers", n=6):
    """A rope hanging between two model points."""
    pts = []
    for i in range(n + 1):
        t = i / n
        pts.append([a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t - sag * 4 * t * (1 - t), a[2] + (b[2] - a[2]) * t])
    for i in range(n):
        p.add(name, "rope", cyl(pts[i], pts[i + 1], 0.022), "prop", min_cover=1, priority=2)


def lantern_post(p, P, gx, gy, h=1.7, name="lantern_post", mat="tarred"):
    """A post with an iron arm and a hanging lantern (lit)."""
    x, _, z = P.m(gx, gy)
    p.add(name, mat, box([x, h / 2, z], [0.05, h / 2, 0.05]), "wall")
    p.add(name, "stone", box([x, 0.06, z], [0.1, 0.06, 0.1]), "found")
    p.add(name + "_arm", "iron", box([x - 0.16, h - 0.04, z], [0.18, 0.02, 0.02]), "wall", priority=2)
    p.add(name + "_arm", "iron", box([x - 0.08, h - 0.15, z], [0.12, 0.015, 0.015], rot=[0, 0, 0.8]), "wall")
    p.add(name + "_lamp", "iron", box([x - 0.3, h - 0.2, z], [0.07, 0.09, 0.07]), "wall")
    p.add(name + "_lamp", "iron", cone([x - 0.3, h - 0.11, z], [x - 0.3, h - 0.02, z], 0.09, 0.02), "wall")
    p.add(name + "_light", "flame", box([x - 0.3, h - 0.2, z], [0.05, 0.06, 0.075]), "wall")


def bale(p, P, gx, gy, along="gx", s=0.2, name="bales", y0=0.0):
    """A bale of cloth or wool wrapped in sacking and roped crosswise."""
    x, _, z = P.m(gx, gy)
    if along == "gx":
        half = [s * 0.8, s * 0.75, s * 1.25]
    else:
        half = [s * 1.25, s * 0.75, s * 0.8]
    p.add(name, "bale", box([x, y0 + half[1], z], half, round_=0.05), "prop")
    p.paint(name, "rope", stripes={"axis": "z" if along == "gx" else "x", "period": s * 0.9, "width": 0.035})


def amphora_free_cargo(p, P, gx, gy, kind, **kw):
    """One piece of cargo: 'barrel', 'crate', 'sack', 'bale' (helper for heaps)."""
    if kind == "barrel":
        K.barrel(p, P, gx, gy, r=kw.get("r", 0.17), h=kw.get("h", 0.44))
    elif kind == "barrel_lying":
        K.barrel(p, P, gx, gy, r=kw.get("r", 0.16), h=kw.get("h", 0.42), lying=True, along=kw.get("along", "x"))
    elif kind == "crate":
        K.crate(p, P, gx, gy, s=kw.get("s", 0.18), rot=kw.get("rot", 0.0), y0=kw.get("y0", 0.0))
    elif kind == "sack":
        K.sack(p, P, gx, gy, s=kw.get("s", 0.16), y0=kw.get("y0", 0.0))
    elif kind == "bale":
        bale(p, P, gx, gy, along=kw.get("along", "gx"), s=kw.get("s", 0.2), y0=kw.get("y0", 0.0))


def capstan(p, P, gx, gy, name="capstan"):
    """A timber capstan (for warping ships in) with its bars, a rope round the drum."""
    x, _, z = P.m(gx, gy)
    p.add(name + "_base", "tarred", cyl([x, 0, z], [x, 0.1, z], 0.3), "wall")
    p.add(name, "timber", cone([x, 0.1, z], [x, 0.55, z], 0.17, 0.13), "wall")
    p.add(name, "timber", cyl([x, 0.55, z], [x, 0.66, z], 0.2), "wall")
    p.add(name + "_rope", "rope", tor([x, 0.3, z], 0.17, 0.035), "wall")
    for k in range(4):
        a = k * math.pi / 4
        dx, dz = math.cos(a) * 0.55, math.sin(a) * 0.55
        p.add(name + "_bars", "haft", cyl([x - dx, 0.61, z - dz], [x + dx, 0.61, z + dz], 0.025), "wall", priority=2)


def treadwheel(p, P, gx, gy, axle_y, r, width=0.42, name="wheel", dir_=(1.0, 1.0)):
    """A great treadwheel: two rims with spokes and a planked walking floor, its axle along the game
    direction dir_ (so the wheel turns in the plane across it), on heavy trestles."""
    x, _, z = P.m(gx, gy)
    # Game direction (dgx, dgy) -> model direction (dx, dz): x = -gy, z = +gx.
    dgx, dgy = dir_
    L = math.hypot(dgx, dgy)
    ax = [-dgy / L, 0.0, dgx / L]                 # axle direction (model)
    up = [0.0, 1.0, 0.0]
    side = [ax[2], 0.0, -ax[0]]                    # in the wheel's plane, horizontal
    for s in (-1, 1):
        cx, cz = x + ax[0] * s * width / 2, z + ax[2] * s * width / 2
        rot = [0, math.atan2(ax[0], ax[2]), 0]
        # rim: a torus around the axle (torus axis is local y, turned to the axle by rot below)
        p.add(name + "_rims", "timber", tor([cx, axle_y, cz], r, 0.07, rot=[1.5708, rot[1], 0]), "wall")
        for k in range(8):
            a = k * math.pi / 8
            dx = [side[0] * math.cos(a), math.sin(a), side[2] * math.cos(a)]
            p.add(name + "_spokes", "timber", cyl([cx - dx[0] * r, axle_y - dx[1] * r, cz - dx[2] * r],
                                                  [cx + dx[0] * r, axle_y + dx[1] * r, cz + dx[2] * r], 0.035),
                  "wall", priority=2)
    # walking floor: slats across the rims, every 15 degrees
    for k in range(24):
        a = k * 2 * math.pi / 24
        c = [x + side[0] * math.cos(a) * (r - 0.02), axle_y + math.sin(a) * (r - 0.02), z + side[2] * math.cos(a) * (r - 0.02)]
        p.add(name + "_slats", "board", cyl([c[0] - ax[0] * width / 2, c[1], c[2] - ax[2] * width / 2],
                                            [c[0] + ax[0] * width / 2, c[1], c[2] + ax[2] * width / 2], 0.035), "wall")
    # the axle (drum with rope) and the A-frame trestles at both ends
    a0 = [x - ax[0] * (width / 2 + 0.25), axle_y, z - ax[2] * (width / 2 + 0.25)]
    a1 = [x + ax[0] * (width / 2 + 0.25), axle_y, z + ax[2] * (width / 2 + 0.25)]
    p.add(name + "_axle", "log_bark", cyl(a0, a1, 0.09), "wall")
    p.add(name + "_drum", "rope", cyl([x - ax[0] * 0.12, axle_y, z - ax[2] * 0.12], [x + ax[0] * 0.12, axle_y, z + ax[2] * 0.12], 0.15),
          "wall")
    for end in (a0, a1):
        for s in (-1, 1):
            foot = [end[0] + side[0] * s * r * 0.75, 0.0, end[2] + side[2] * s * r * 0.75]
            p.add(name + "_trestles", "timber", cyl(foot, [end[0], axle_y + 0.08, end[2]], 0.07), "wall")
        sill0 = [end[0] - side[0] * r * 0.85, 0.07, end[2] - side[2] * r * 0.85]
        sill1 = [end[0] + side[0] * r * 0.85, 0.07, end[2] + side[2] * r * 0.85]
        p.add(name + "_sills", "tarred", cyl(sill0, sill1, 0.08), "found")


# =================================================================================================
# Bollard (1x1, on the edge of a stone quay; the ship lies along the left face, berth (0, 1)): a
# squat iron bollard on an ashlar block with a hawser round it running over the edge, a second
# rope coiled on the stones, a lantern post at the back, a little heap of crates waiting.
# =================================================================================================
def bollard():
    P, p = Plot(1), Parts()
    iron_bollard(p, P, 0.55, 0.72, r=0.15, h=0.4)
    x, _, z = P.m(0.55, 0.72)
    p.add("hawser_turns", "rope", tor([x, 0.3, z], 0.17, 0.035), "prop")
    hawser(p, [x - 0.15, 0.3, z], P.m(0.45, 1.08, -0.1), sag=0.04, n=3)
    rope_coil(p, P, 0.2, 0.62, r=0.15)
    lantern_post(p, P, 0.82, 0.22, h=1.55)
    K.crate(p, P, 0.22, 0.22, s=0.15)
    K.crate(p, P, 0.22, 0.22, s=0.12, y0=0.3, rot=0.5)
    K.barrel(p, P, 0.45, 0.16, r=0.12, h=0.32)
    p.footprints = [(0.2, 0.8, 0.2, 0.8)]
    p.roofs = []
    p.heap = (0.5, 0.5)
    return P, p, 128, 0.9


# =================================================================================================
# Mooring (2x2 on the quay; the ship lies beyond the left face, berth (1, 2)): two pile clusters
# (dolphins: three tarred piles bound with rope) at the water edge with a hawser between them, a
# capstan for warping ships in, iron bollards, coiled ropes, a lantern post, a few barrels and a
# net drying over a rail at the back.
# =================================================================================================
def mooring():
    P, p = Plot(2), Parts()
    for gx in (0.3, 1.7):
        for dx, dy in ((0, 0), (0.13, 0.08), (-0.1, 0.1)):
            timber_bollard(p, P, gx + dx, 1.86 + dy * 0.6, r=0.08, h=0.75 - dy)
        x, _, z = P.m(gx, 1.9)
        p.add("dolphin_lashing", "rope", tor([x, 0.5, z], 0.17, 0.035), "wall")
    hawser(p, P.m(0.3, 1.9, 0.62), P.m(1.7, 1.9, 0.62), sag=0.25, n=8)
    capstan(p, P, 1.0, 1.3)
    iron_bollard(p, P, 0.35, 1.25)
    iron_bollard(p, P, 1.65, 1.25)
    rope_coil(p, P, 1.62, 0.95)
    rope_coil(p, P, 0.4, 0.9, r=0.14)
    lantern_post(p, P, 1.75, 0.25, h=1.75)
    K.barrel(p, P, 0.45, 0.3, r=0.16, h=0.42)
    K.barrel(p, P, 0.75, 0.25, r=0.15, h=0.4)
    K.barrel(p, P, 0.6, 0.55, lying=True, along="z", r=0.14, h=0.38)
    # a rail with a net drying on it, along the back edge
    K.fence(p, P, [(0.05, 1.0), (0.05, 1.7)], name="net_rail", h=0.7, mat="tarred")
    x0, _, z0 = P.m(0.05, 1.0)
    x1, _, z1 = P.m(0.05, 1.7)
    p.add("net", "net", box([(x0 + x1) / 2, 0.45, z0 - 0.02], [abs(x1 - x0) / 2 - 0.05, 0.28, 0.015]), "prop", priority=2)
    p.paint("net", "rope", stripes={"axis": "y", "period": 0.09, "width": 0.02})
    p.paint("net", "rope", stripes={"axis": "x", "period": 0.09, "width": 0.02})
    p.footprints = [(0.2, 1.8, 0.2, 1.8)]
    p.roofs = []
    p.heap = (1.0, 0.6)
    return P, p, 192, 1.0


# =================================================================================================
# Cargo crane (2x2): a stone base with a timber platform, a great squared mast with iron bands on
# four raking struts, a slewing collar at the jib's heel and a little shingled hood over the
# sheave at the top; a treadwheel on heavy trestles by the door, where the operator walks. The
# jib, ropes, hook and load are drawn by the game (CraneLayer: mast foot (1.15, 0.85), heel 95 px,
# cap 118 px, wheel (0.5, 1.5) with its axle 25 px up).
# =================================================================================================
MAST_FOOT = (1.15, 0.85)
WHEEL_FOOT = (0.5, 1.5)


def crane():
    P, p = Plot(2), Parts()
    mx, _, mz = P.m(*MAST_FOOT)
    heel, cap = 95 * PX, 118 * PX
    # stone base and a timber platform round the mast
    p.add("base", "ashlar", box([mx, 0.14, mz], [0.62, 0.14, 0.62], round_=0.02), "found")
    p.paint("base", "ashlar_line", stripes={"axis": "y", "period": 0.14, "width": 0.035})
    p.add("platform", "plank", box([mx, 0.32, mz], [0.56, 0.04, 0.56]), "found")
    p.paint("platform", "ink", stripes={"axis": "x", "period": 0.16, "width": 0.025})
    # the mast: a squared oak post with iron bands
    p.add("mast", "timber", box([mx, (0.36 + cap) / 2, mz], [0.15, (cap - 0.36) / 2, 0.15]), "wall")
    p.paint("mast", "iron", stripes={"axis": "y", "at": [1.1, 2.3, 3.5, 4.6, heel - 0.35, cap - 0.6], "width": 0.06})
    # four raking struts with a cross brace
    for sx, sz in ((-1, -1), (-1, 1), (1, -1), (1, 1)):
        foot = [mx + sx * 0.52, 0.36, mz + sz * 0.52]
        top = [mx + sx * 0.12, 2.6, mz + sz * 0.12]
        p.add("struts", "timber", cyl(foot, top, 0.06), "wall")
        p.add("strut_irons", "iron", box([foot[0], 0.42, foot[2]], [0.08, 0.05, 0.08]), "wall")
    for sx, sz in ((-1, 0), (0, 1)):
        p.add("braces", "timber", cyl([mx + sx * 0.32 - (0 if sx else 0.32), 1.2, mz + sz * 0.32 - (0 if sz else -0.32)],
                                      [mx + sx * 0.32 + (0 if sx else 0.32), 1.2, mz + sz * 0.32 + (0 if sz else -0.32)], 0.04), "wall")
    # the slewing collar where the jib's heel sits, with an iron ring
    p.add("collar", "timber", cyl([mx, heel - 0.22, mz], [mx, heel + 0.1, mz], 0.24), "wall")
    p.add("collar", "iron", tor([mx, heel - 0.05, mz], 0.24, 0.04), "wall")
    p.add("collar", "iron", tor([mx, heel - 0.2, mz], 0.24, 0.035), "wall")
    # the sheave block and a little hood of shingles on the cap
    p.add("cap_block", "timber", box([mx, cap - 0.18, mz], [0.2, 0.16, 0.2]), "wall")
    p.add("sheave", "iron", cyl([mx - 0.24, cap - 0.18, mz], [mx + 0.24, cap - 0.18, mz], 0.1), "wall")
    p.add("hood", "shingle", {"revolve": {"c": K.r4([mx, cap - 0.04, mz]), "profile": {"polygon": [[0, 0], [0.42, 0], [0, 0.55]]}}},
          "roof")
    p.paint("hood", "shingle_dark", stripes={"axis": "y", "period": 0.1, "width": 0.04, "offset": cap})
    p.add("finial", "iron", cyl([mx, cap + 0.5, mz], [mx, cap + 0.75, mz], 0.025), "roof", min_cover=1)
    p.add("finial", "verdigris", sph([mx, cap + 0.78, mz], 0.05), "roof")
    # the treadwheel by the door: the operator walks in it, axle 25 px up
    treadwheel(p, P, WHEEL_FOOT[0], WHEEL_FOOT[1], 25 * PX, 1.25, width=0.44, dir_=(1.0, 1.0))
    # small things: barrels and a crate on the platform side, a bollard at the back corner
    K.barrel(p, P, 1.72, 1.78, r=0.15, h=0.4)
    K.barrel(p, P, 1.85, 1.5, r=0.13, h=0.36)
    K.crate(p, P, 1.55, 1.6, s=0.13)
    iron_bollard(p, P, 1.85, 0.25)
    rope_coil(p, P, 1.75, 0.6, r=0.14)
    p.footprints = [(0.55, 1.75, 0.25, 1.45)]
    p.roofs = []
    p.heap = (1.6, 1.6)
    return P, p, 256, 3.2



def derrick(p, P, gx, gy, to, h=2.6, name="derrick"):
    """A hand derrick: a stayed post with a slanting boom towards game point `to`, a block and
    tackle hoisting a net with two barrels."""
    x, _, z = P.m(gx, gy)
    p.add(name, "tarred", cyl([x, 0, z], [x, h, z], 0.07), "wall")
    p.add(name + "_foot", "ashlar", box([x, 0.08, z], [0.16, 0.08, 0.16]), "found")
    for dx, dz in ((0.6, -0.45), (0.5, 0.55)):
        p.add(name + "_stays", "rope", cyl([x, h - 0.05, z], [x + dx, 0.05, z + dz], 0.018), "wall", min_cover=1)
    tx, _, tz = P.m(*to)
    head = [tx, h + 0.35, tz]
    p.add(name + "_boom", "timber", cyl([x, 0.9, z], head, 0.055), "wall")
    p.add(name + "_block", "iron", sph([head[0], head[1] - 0.1, head[2]], 0.07), "wall")
    load_y = 1.0
    p.add(name + "_rope", "rope", cyl([head[0], head[1] - 0.12, head[2]], [head[0], load_y + 0.42, head[2]], 0.016), "wall",
          min_cover=1)
    p.add(name + "_net", "net", ell([head[0], load_y + 0.18, head[2]], [0.26, 0.24, 0.26]), "prop")
    p.paint(name + "_net", "rope", stripes={"axis": "y", "period": 0.07, "width": 0.02})
    p.add(name + "_load", "barrel", cyl([head[0] - 0.08, load_y + 0.02, head[2]], [head[0] - 0.08, load_y + 0.36, head[2]], 0.11),
          "prop")
    p.add(name + "_load", "barrel", cyl([head[0] + 0.1, load_y + 0.02, head[2] + 0.06], [head[0] + 0.1, load_y + 0.32, head[2] + 0.06],
                                       0.1), "prop")


def fire_beacon(p, P, gx, gy, h=2.5, name="beacon"):
    """A harbour light: a round ashlar pillar with a moulded cap and an iron fire basket, lit."""
    x, _, z = P.m(gx, gy)
    p.add(name + "_base", "ashlar", box([x, 0.15, z], [0.3, 0.15, 0.3]), "found")
    p.add(name, "ashlar", cyl([x, 0.3, z], [x, h - 0.25, z], 0.2), "wall")
    p.paint(name, "ashlar_line", stripes={"axis": "y", "period": 0.3, "width": 0.04, "offset": 0.3})
    p.add(name + "_cap", "ashlar_light", cyl([x, h - 0.25, z], [x, h - 0.12, z], 0.28), "wall")
    p.add(name + "_basket", "iron", cone([x, h - 0.12, z], [x, h + 0.2, z], 0.12, 0.25), "wall")
    p.add(name + "_fire", "flame", ell([x, h + 0.3, z], [0.2, 0.22, 0.2]), "wall")
    p.add(name + "_fire", "flame", cone([x, h + 0.4, z], [x + 0.04, h + 0.85, z], 0.14, 0.01), "wall")


def flagpole(p, P, gx, gy, h=3.2, mat="cloth_red", name="flag"):
    x, _, z = P.m(gx, gy)
    p.add(name + "_pole", "post", cyl([x, 0, z], [x, h, z], 0.04), "wall", priority=2)
    p.add(name + "_pole", "gilt", sph([x, h + 0.04, z], 0.06), "wall")
    p.add(name, mat, box([x - 0.42, h - 0.32, z], [0.4, 0.22, 0.02]), "wall")
    p.add(name + "_charge", "gilt", sph([x - 0.42, h - 0.32, z - 0.03], 0.08), "wall", priority=2)


def cargo_heap(p, P, items):
    for kind, gx, gy, kw in items:
        amphora_free_cargo(p, P, gx, gy, kind, **kw)


def stepped_gable_facade(p, P, gx0, gx1, gy, y0, h, name="facade", steps=5):
    """A crow-stepped brick gable standing on a wall along game x at `gy`, facing the yard (game +y),
    with ashlar copings, a blind pointed window and a gilt coat of arms."""
    x = P.m(0, gy)[0]
    za, zb = P.m(gx0, 0)[2], P.m(gx1, 0)[2]
    zc, half = (za + zb) / 2, (zb - za) / 2
    for i in range(steps):
        w = half * (1 - i / steps)
        yb = y0 + h * i / steps
        p.add(name, "brick", box([x, yb + h / steps / 2, zc], [0.12, h / steps / 2, w]), "wall")
        for s in (-1, 1):
            p.add(name + "_caps", "ashlar_light", box([x, yb + h / steps + 0.03, zc + s * (w - 0.08)], [0.15, 0.04, 0.11]), "wall")
    p.paint(name, "brick_line", stripes={"axis": "y", "period": 0.12, "width": 0.035})
    p.add(name + "_window", "dark_hole", box([x - 0.13, y0 + h * 0.42, zc], [0.02, h * 0.17, 0.17]), "wall", priority=2)
    p.add(name + "_window", "dark_hole", ext([x - 0.13, y0 + h * 0.59, zc], [[-0.17, 0], [0.17, 0], [0, 0.22]], 0.04,
                                             rot=[0, 1.5708, 0]), "wall", priority=2)
    p.add(name + "_arms", "cloth_red", box([x - 0.14, y0 + h * 0.16, zc], [0.02, 0.17, 0.14]), "wall", priority=2)
    p.add(name + "_arms", "cloth_red", ext([x - 0.14, y0 + h * 0.16 - 0.17, zc], [[-0.14, 0], [0.14, 0], [0, -0.14]], 0.04,
                                           rot=[0, 1.5708, 0]), "wall", priority=2)
    p.add(name + "_arms_charge", "gilt", sph([x - 0.17, y0 + h * 0.16, zc], 0.07), "wall", priority=3)
    p.add(name + "_finial", "gilt", cyl([x, y0 + h + 0.05, zc], [x, y0 + h + 0.4, zc], 0.025), "wall", min_cover=1)
    p.add(name + "_finial", "gilt", sph([x, y0 + h + 0.42, zc], 0.06), "wall")


def quay_shed(p, P, n, both, wall="fieldstone", roof="slate", low=2.35, high=3.05, posts=(1.0, None), stone_posts=False):
    """The roofed shed of a port yard (port, port warehouses): back walls along the two back edges
    (or one), stout posts along the front of the back row (and column), a lean-to roof falling
    towards the yard, a hoist. Parts named like the warehouse shed's pieces (gen_town.stockpile)."""
    e = n - 0.04
    K.walls(p, P, "shed_a_wall", (0.04, e, 0.04, 0.16), 0.0, high - 0.05, wall)
    p.paint("shed_a_wall", "stone_dark", spots={"scale": 0.08, "density": 0.4, "seed": 21})
    p.paint("shed_a_wall", "ashlar_line", stripes={"axis": "y", "at": [0.3, high - 0.25], "width": 0.06})
    K.lean_to(p, P, "shed_a_roof", (0.04, e, 0.04, 1.0), "-gy", low, high, roof, roof + "_dark", over=0.18, posts=False)
    if both:
        K.walls(p, P, "shed_b_wall", (0.04, 0.16, 0.04, e), 0.0, high - 0.05, wall)
        p.paint("shed_b_wall", "stone_dark", spots={"scale": 0.08, "density": 0.4, "seed": 22})
        p.paint("shed_b_wall", "ashlar_line", stripes={"axis": "y", "at": [0.3, high - 0.25], "width": 0.06})
        K.lean_to(p, P, "shed_b_roof", (0.04, 1.0, 1.0, e), "-gx", low, high, roof, roof + "_dark", over=0.18, posts=False)
    mat = "ashlar" if stone_posts else "post"
    w = 0.1 if stone_posts else 0.07
    xs = [1.0, (1.0 + e) / 2, e - 0.02] if both else [0.08, n / 2, e - 0.04]
    for gx in xs:
        x, _, z = P.m(gx, 1.0)
        p.add("posts_a", mat, box([x, (low - 0.02) / 2, z], [w, (low - 0.02) / 2, w]), "wall")
        if stone_posts:
            p.add("posts_a", "ashlar_light", box([x, low - 0.12, z], [w + 0.04, 0.05, w + 0.04]), "wall")
    a, b = P.m(xs[0], 1.0, low), P.m(e, 1.0, low)
    p.add("plates_a", "timber", box([(a[0] + b[0]) / 2, low - 0.02, (a[2] + b[2]) / 2],
                                    [0.08, 0.07, abs(b[2] - a[2]) / 2 + 0.08]), "wall")
    if both:
        for gy in ((1.0 + e) / 2, e - 0.02):
            x, _, z = P.m(1.0, gy)
            p.add("posts_b", mat, box([x, (low - 0.02) / 2, z], [w, (low - 0.02) / 2, w]), "wall")
        a, b = P.m(1.0, 1.0, low), P.m(1.0, e, low)
        p.add("plates_b", "timber", box([(a[0] + b[0]) / 2, low - 0.02, (a[2] + b[2]) / 2],
                                        [abs(b[0] - a[0]) / 2 + 0.08, 0.07, 0.08]), "wall")
    # a lantern on the corner post and a hoist with a block over the yard
    x, _, z = P.m(xs[0], 1.0)
    p.add("hoist", "timber", box([x - 0.25, high - 0.1, z + 0.25], [0.06, 0.06, 0.4], rot=[0, 0.785, 0]), "roof")
    p.add("hoist_block", "iron", sph([x - 0.5, high - 0.2, z + 0.5], 0.07), "roof")
    p.add("hoist_rope", "rope", cyl([x - 0.5, high - 0.25, z + 0.5], [x - 0.5, low - 0.1, z + 0.5], 0.015), "roof", min_cover=1)
    p.add("hoist_hook", "iron", tor([x - 0.5, low - 0.15, z + 0.5], 0.05, 0.015), "roof")
    p.roofs = []
    pieces = {
        "shed_a_back": ((0, -1), (n, 1), ["shed_a_wall"]),
        "shed_a_front": ((0, 0), (n, 1), ["shed_a_roof", "posts_a", "plates_a", "hoist", "hoist_block", "hoist_rope",
                                          "hoist_hook"]),
    }
    if both:
        pieces["shed_b_back"] = ((-1, 0), (1, n), ["shed_b_wall"])
        pieces["shed_a_front"][2].append("plates_b")
        pieces["shed_b_front"] = ((0, 1), (1, n - 1), ["shed_b_roof", "posts_b"])
    return pieces


# =================================================================================================
# Port (4x4; land rows 0-1 are the quay yard drawn by the game, water rows 2-3 its pier, the ship
# moors beyond the left face, berth (2, 4)). The art: a weigh-house shed along the back edge of the
# yard (a fieldstone wall with a crow-stepped brick gable over it, a coat of arms and a gilt vane;
# stone pillars and a slate lean-to over the back row, a hoist), drawn as pieces; on the pier a
# hand derrick hoisting a net of barrels, a harbour light with a burning fire basket, iron
# bollards along the edge with hawsers, the kingdom's flag, cargo waiting by the yard.
# =================================================================================================
def port():
    P, p = Plot(4), Parts()
    p.footprints = [(0.1, 3.9, 0.1, 1.9)]
    pieces = quay_shed(p, P, 4, False, wall="fieldstone", roof="slate", low=2.45, high=3.15, stone_posts=True)
    stepped_gable_facade(p, P, 1.1, 2.9, 0.1, 3.0, 2.0, name="shed_a_facade")
    pieces["shed_a_back"][2].extend(["shed_a_facade", "shed_a_facade_caps", "shed_a_facade_window", "shed_a_facade_arms",
                                     "shed_a_facade_arms_charge", "shed_a_facade_finial"])
    # the pier: bollards along the edge, a derrick, a harbour light, the flag, cargo by the yard
    for gx in (0.45, 1.7, 3.0):
        iron_bollard(p, P, gx, 3.82)
    rope_coil(p, P, 1.35, 3.75, r=0.14)
    hawser(p, P.m(1.7, 3.82, 0.3), P.m(1.9, 4.25, -0.2), sag=0.05, n=3)
    derrick(p, P, 0.4, 2.45, (0.95, 3.25))
    fire_beacon(p, P, 3.62, 3.62)
    flagpole(p, P, 3.7, 2.25)
    cargo_heap(p, P, [("barrel", 1.25, 2.3, {}), ("barrel", 1.55, 2.25, {"r": 0.15, "h": 0.4}),
                      ("barrel_lying", 1.4, 2.6, {"along": "z"}), ("bale", 0.95, 2.3, {"along": "gy"}),
                      ("crate", 1.85, 2.3, {"s": 0.17}), ("crate", 1.85, 2.3, {"s": 0.13, "y0": 0.34, "rot": 0.5}),
                      ("sack", 0.7, 2.75, {})])
    p.roofs = []
    p.pieces = pieces
    p.heap = (2.5, 1.5)
    return P, p, 384, 2.2


# =================================================================================================
# Port warehouses (yards on the quay): a fieldstone shed with a slate lean-to over the back row
# (and the back column on the large one), drawn as pieces like the warehouse's shed; the port
# store (1x1) has no shed (only its construction stages come from a model: stone slabs, posts).
# =================================================================================================
def yard_floor(p, P, n):
    """Stone slabs over the yard: only in the construction stages (the game draws the floor)."""
    p.add("slabs", "stone", box([0, 0.04, 0], [n * K.T / 2 - 0.06, 0.04, n * K.T / 2 - 0.06]), "found")
    p.paint("slabs", "stone_dark", stripes={"axis": "x", "period": 0.58, "width": 0.055})
    p.paint("slabs", "stone_dark", stripes={"axis": "z", "period": 0.58, "width": 0.055})


def port_warehouse():
    P, p = Plot(3), Parts()
    p.footprints = [(0.04, 2.96, 0.04, 2.96)]
    yard_floor(p, P, 3)
    p.pieces = quay_shed(p, P, 3, True, low=2.3, high=3.0)
    p.heap = (2.0, 2.0)
    return P, p, 320, 2.4


def port_warehouse_small():
    P, p = Plot(2), Parts()
    p.footprints = [(0.04, 1.96, 0.04, 1.96)]
    yard_floor(p, P, 2)
    p.pieces = quay_shed(p, P, 2, False, low=2.2, high=2.85)
    p.heap = (1.4, 1.5)
    return P, p, 256, 1.9


def port_store():
    P, p = Plot(1), Parts()
    x, _, z = P.m(0.5, 0.5)
    p.add("slabs", "stone", box([x, 0.04, z], [K.T / 2 - 0.08, 0.04, K.T / 2 - 0.08]), "found")
    p.paint("slabs", "stone_dark", stripes={"axis": "x", "period": 0.58, "width": 0.055})
    p.paint("slabs", "stone_dark", stripes={"axis": "z", "period": 0.58, "width": 0.055})
    for gx, gy in ((0.1, 0.1), (0.9, 0.1), (0.1, 0.9)):
        timber_bollard(p, P, gx, gy, r=0.06, h=0.55)
    p.footprints = [(0.1, 0.9, 0.1, 0.9)]
    p.roofs = []
    p.heap = (0.5, 0.5)
    return P, p, 128, 0.8


# =================================================================================================
# Fishing wharf (3x3; water row 2 is its pier, the boat moors beyond the left face, berth (1, 3);
# the catch is stacked on the yard tile (2, 0), which stays free). A fisherman's house of grey
# boards on a fieldstone plinth under a heavy reed thatch with a smoke hole, a little fieldstone
# smokehouse with smoke, racks of fish drying, an upturned boat on trestles, oars, creels; on the
# pier nets drying on poles, a gutting table with fish, bollards, a barrel of salt herring.
# =================================================================================================
def fishing_wharf():
    P, p = Plot(3), Parts()
    house = (0.12, 1.35, 0.12, 1.4)
    K.plinth(p, P, "plinth", house, h=0.2, mat="fieldstone")
    K.board_walls(p, P, "walls", house, 0.2, 1.4, mat="weathered")
    K.timber_left(p, P, "frame_l", house, 0.2, 1.4, 3, braces=False)
    K.timber_right(p, P, "frame_r", house, 0.2, 1.4, 3, braces=False)
    g = Gable(P, "house", house, "gx", 1.4, 2.65, over=0.3, end_over=0.22)
    g.infill(p, "weathered")
    g.roof(p, "thatch", "thatch_dark", course=0.15, spots=("moss", 0.1, 0.22, 11))
    g.bargeboards(p)
    p.footprints = [house]
    p.roofs = [g]
    x0, x1, z0, z1 = P.rect(*house)
    K.door_right(p, P, "door", 0.95, z1, 0.2, w=0.46, h=0.95, arch=False)
    K.window_right(p, P, 0.4, z1, 0.95, w=0.26, h=0.28)
    K.window_left(p, P, 0.45, x0, 0.9, w=0.28, h=0.28)
    K.window_left(p, P, 1.0, x0, 0.9, w=0.28, h=0.28)
    p.add("smoke_hood", "thatch", box([(x0 + x1) / 2, 2.62, P.m(0.6, 0)[2]], [0.14, 0.1, 0.18]), "roof")
    K.wisp(p, [(x0 + x1) / 2, 2.72, P.m(0.6, 0)[2]], 0.7, seed=5, name="hearth_smoke")
    # a lean-to with nets and floats on the gable end towards the yard
    K.lean_to(p, P, "lean", (1.35, 1.8, 0.2, 1.3), "-gx", 1.0, 1.35, "thatch", "thatch_dark", over=0.12)
    p.add("lean_net", "net", box(P.m(1.4, 0.75, 0.65), [0.4, 0.3, 0.02]), "prop", priority=2)
    # the smokehouse at the back between the house and the yard tile: fieldstone under turf, smoking
    sh = (1.85, 2.0, 0.0, 0.0)
    sx, _, sz = P.m(1.9, 0.6)
    p.add("smokehouse", "fieldstone", box([sx, 0.5, sz], [0.32, 0.5, 0.22]), "wall")
    p.paint("smokehouse", "stone_dark", spots={"scale": 0.07, "density": 0.4, "seed": 6})
    p.add("smokehouse_roof", "turf", ext([sx, 1.0, sz], [[-0.42, 0], [0.42, 0], [0, 0.42]], 0.55, rot=[0, 1.5708, 0]), "roof")
    p.paint("smokehouse_roof", "moss", spots={"scale": 0.08, "density": 0.3, "seed": 2})
    p.add("smokehouse_door", "door_wood", box([sx, 0.38, sz + 0.23], [0.15, 0.32, 0.02]), "wall")
    p.add("smokehouse_vent", "fieldstone", box([sx, 1.48, sz], [0.08, 0.08, 0.08]), "roof")
    K.wisp(p, [sx, 1.58, sz], 1.1, seed=3)
    _ = sh
    p.footprints.append((1.75, 2.0, 0.3, 0.9))
    # fish drying on a rack along the yard path, in front of the lean-to
    for gy in (1.45, 1.95):
        a = P.m(1.75, gy)
        p.add("fish_rack", "post", cyl([a[0], 0, a[2]], [a[0], 1.05, a[2]], 0.035), "prop")
    a, b = P.m(1.75, 1.45, 1.0), P.m(1.75, 1.95, 1.0)
    p.add("fish_rack", "post", cyl(a, b, 0.03), "prop")
    for k in range(4):
        c = P.m(1.75, 1.52 + k * 0.13, 0.78)
        p.add("drying_fish", "fish", ell(c, [0.03, 0.18, 0.05]), "prop")
    # an upturned boat on trestles in front of the house, oars against the wall, creels
    bc = P.m(0.7, 1.75, 0.62)
    p.add("boat", "tarred", ell(bc, [0.24, 0.22, 0.62]), "prop")
    p.cut("boat", plane([0, -1, 0], [0, 0.55, 0]))
    p.paint("boat", "board", stripes={"axis": "y", "period": 0.09, "width": 0.055})
    for d in (-0.4, 0.4):
        p.add("boat_trestles", "post", box([bc[0], 0.3, bc[2] + d], [0.22, 0.03, 0.04]), "prop")
        for sgn in (-1, 1):
            p.add("boat_trestles", "post", cyl([bc[0] + sgn * 0.2, 0, bc[2] + d], [bc[0] + sgn * 0.08, 0.3, bc[2] + d], 0.025),
                  "prop")
    for k in range(2):
        a, b = P.m(1.42, 1.0 + k * 0.1), P.m(1.38, 0.98 + k * 0.1, 1.45)
        p.add("oars", "haft", cyl(a, b, 0.022), "prop", priority=2)
        p.add("oars", "haft", box([a[0], 0.2, a[2] + 0.03], [0.06, 0.16, 0.025]), "prop")
    for gx, gy in ((0.2, 1.65), (0.25, 1.9)):
        x, _, z = P.m(gx, gy)
        p.add("creels", "wicker", cone([x, 0, z], [x, 0.3, z], 0.11, 0.14), "prop")
    # the pier: nets on poles, a gutting table, bollards, a barrel of herring, floats
    for gx in (0.2, 0.62, 1.04):
        x, _, z = P.m(gx, 2.55)
        p.add("net_poles", "post", cyl([x, 0, z], [x, 1.2, z], 0.03), "prop")
    a, b = P.m(0.2, 2.55, 1.15), P.m(1.04, 2.55, 1.15)
    p.add("net_poles", "post", cyl(a, b, 0.025), "prop")
    p.add("nets", "net", box([(a[0] + b[0]) / 2, 0.75, (a[2] + b[2]) / 2], [0.02, 0.38, abs(b[2] - a[2]) / 2 - 0.03]), "prop",
          priority=2)
    p.paint("nets", "rope", stripes={"axis": "y", "period": 0.08, "width": 0.055})
    for k in range(3):
        c = P.m(0.4 + k * 0.28, 2.58, 0.42 - 0.08 * k)
        p.add("floats", "barrel_lid", sph(c, 0.05), "prop")
    t = P.m(2.45, 2.35)
    p.add("gut_table", "board", box([t[0], 0.6, t[2]], [0.22, 0.04, 0.38]), "prop")
    for dz in (-0.3, 0.3):
        p.add("gut_table", "post", box([t[0], 0.3, t[2] + dz], [0.18, 0.3, 0.03]), "prop")
    for k in range(3):
        p.add("table_fish", "fish", ell([t[0] - 0.05 + 0.05 * k, 0.67, t[2] - 0.2 + 0.18 * k], [0.04, 0.035, 0.13]), "prop")
    p.add("table_knife", "steel", box([t[0] + 0.1, 0.66, t[2] + 0.25], [0.012, 0.01, 0.08]), "prop")
    K.tub(p, P, "herring_tub", 2.75, 2.7, 0.17, 0.42, fill="fish")
    iron_bollard(p, P, 0.5, 2.85)
    iron_bollard(p, P, 2.4, 2.85)
    rope_coil(p, P, 2.0, 2.8, r=0.13)
    p.heap = (2.5, 0.5)
    return P, p, 288, 1.7


def slipway(p, P, gx0, gx1, gy0, gy1, y0=0.45, y1=-0.3, water_from=2.0, name="slip"):
    """A slipway of tarred planks falling from the land into the water, two greased ways on top,
    keel blocks along the middle, piles under its part over the water."""
    def y_at(gy):
        return y0 + (y1 - y0) * (gy - gy0) / (gy1 - gy0)
    a, b = P.m((gx0 + gx1) / 2, gy0), P.m((gx0 + gx1) / 2, gy1)
    ang = math.atan2(y0 - y1, a[0] - b[0])
    L = math.hypot(a[0] - b[0], y0 - y1) / 2
    w = (gx1 - gx0) * K.T / 2
    c = [(a[0] + b[0]) / 2, (y0 + y1) / 2 - 0.05, a[2]]
    p.add(name, "tarred", box(c, [L, 0.06, w], rot=[0, 0, ang]), "found")
    p.paint(name, "board", stripes={"axis": "z", "period": 0.28, "width": 0.03})
    for gx in (gx0 + (gx1 - gx0) * 0.28, gx0 + (gx1 - gx0) * 0.72):
        z = P.m(gx, 0)[2]
        p.add(name + "_ways", "timber", box([c[0], c[1] + 0.09, z], [L, 0.05, 0.08], rot=[0, 0, ang]), "found")
    # sleepers sticking out at the sides
    k = 0
    gy = gy0 + 0.2
    while gy < gy1 - 0.1:
        x, _, z = P.m((gx0 + gx1) / 2, gy)
        p.add(name + "_sleepers", "timber", box([x, y_at(gy) - 0.06, z], [0.07, 0.05, w + 0.12]), "found")
        if gy > water_from:
            for s in (-1, 1):
                p.add(name + "_piles", "tarred", cyl([x, y_at(gy) - 0.1, z + s * (w + 0.05)], [x, WATER_Y - 0.15, z + s * (w + 0.05)],
                                                    0.065), "found")
        gy += 0.42
        k += 1
    # keel blocks (stacked baulks) along the middle
    zc = P.m((gx0 + gx1) / 2, 0)[2]
    gy = gy0 + 0.6
    while gy < gy1 - 0.5:
        x = P.m(0, gy)[0]
        for i in range(3):
            p.add(name + "_blocks", "raw_timber", box([x, y_at(gy) + 0.06 + i * 0.1, zc], [0.09 + 0.02 * (i % 2), 0.05, 0.2 - 0.03 * i]),
                  "found")
        gy += 0.65


def shear_legs(p, P, a, b, top_y, name="shears"):
    """Two poles leaning together over the slip with a block and tackle."""
    pa, pb = P.m(*a), P.m(*b)
    top = [(pa[0] + pb[0]) / 2 - 0.5, top_y, (pa[2] + pb[2]) / 2]
    for q in (pa, pb):
        p.add(name, "raw_timber", cyl([q[0], 0, q[2]], top, 0.065), "wall")
    p.add(name + "_lash", "rope", sph(top, 0.09), "wall")
    p.add(name + "_block", "iron", sph([top[0], top[1] - 0.25, top[2]], 0.07), "wall")
    p.add(name + "_rope", "rope", cyl([top[0], top[1] - 0.3, top[2]], [top[0], 0.9, top[2]], 0.015), "wall", min_cover=1)
    p.add(name + "_rope", "rope", cyl([top[0], top[1] - 0.1, top[2]], [pa[0] + 0.6, 0.05, pa[2]], 0.015), "wall", min_cover=1)
    p.add(name + "_hook", "iron", tor([top[0], 0.85, top[2]], 0.05, 0.015), "wall")


def tar_kettle(p, P, gx, gy, name="tar_kettle"):
    x, _, z = P.m(gx, gy)
    for k in range(3):
        a = k * 2.1
        p.add(name + "_stones", "fieldstone", ell([x + 0.22 * math.cos(a), 0.06, z + 0.22 * math.sin(a)], [0.1, 0.07, 0.1]), "prop")
    p.add(name + "_fire", "flame", ell([x, 0.08, z], [0.14, 0.08, 0.14]), "prop")
    p.add(name, "iron", ell([x, 0.32, z], [0.22, 0.18, 0.22]), "prop")
    p.cut(name, plane([0, 1, 0], [0, 0.42, 0]))
    p.add(name + "_tar", "tar", cyl([x, 0.39, z], [x, 0.41, z], 0.19), "prop")
    p.add(name + "_stick", "haft", cyl([x + 0.05, 0.35, z], [x + 0.25, 0.85, z + 0.1], 0.02), "prop", priority=2)
    K.wisp(p, [x, 0.5, z], 0.8, seed=7, name=name + "_smoke")


def anchor(p, P, gx, gy, name="anchor"):
    x, _, z = P.m(gx, gy)
    p.add(name, "iron", cyl([x, 0.1, z], [x + 0.1, 1.0, z], 0.035), "prop")
    p.add(name, "iron", box([x + 0.09, 0.9, z], [0.04, 0.025, 0.2]), "prop")
    p.add(name, "iron", tor([x, 0.15, z], 0.25, 0.03, rot=[1.5708, 0, 0]), "prop")
    p.cut(name, plane([0, 1, 0], [0, 0.18, 0]))
    p.add(name + "_ring", "iron", tor([x + 0.11, 1.08, z], 0.06, 0.015, rot=[1.5708, 0, 0]), "prop")


def planks_stack(p, P, gx, gy, along="gy", layers=4, length=0.9, name="plank_stack"):
    x, _, z = P.m(gx, gy)
    for i in range(layers):
        if along == "gy":
            half = [length / 2, 0.035, 0.22]
        else:
            half = [0.22, 0.035, length / 2]
        p.add(name, "plank" if i % 2 else "plank_alt", box([x, 0.06 + i * 0.1, z], half), "prop")
        if i < layers - 1:
            for s in (-1, 1):
                if along == "gy":
                    p.add(name + "_sticks", "raw_timber", box([x + s * length * 0.35, 0.11 + i * 0.1, z], [0.03, 0.015, 0.24]), "prop")
                else:
                    p.add(name + "_sticks", "raw_timber", box([x, 0.11 + i * 0.1, z + s * length * 0.35], [0.24, 0.015, 0.03]), "prop")


# =================================================================================================
# Shipyard (4x4; water rows 2-3: the slipway, a pier strip on the right (QuayLayer); the hull being
# built lies on the slip (ShipLayer); the timber stack on the yard tile (3, 0) under the shed). A
# shipwright's lodge, fieldstone below and half-timbered above under shingles with a chimney and a
# loft hoist; an open saw shed with a spare mast on trestles and planks drying on sticks; the
# slipway with ways, keel blocks and piles; a tar kettle on a fire, a log pile, an anchor.
# =================================================================================================
def shipyard():
    P, p = Plot(4), Parts()
    lodge = (0.12, 1.95, 0.12, 1.3)
    g, eave, top = K.house(p, P, "lodge", lodge, ground="fieldstone", ground_h=1.45, upper="plaster", upper_h=1.0,
                           axis="gx", roof_mat="shingle", roof_dark="shingle_dark", rise=1.3, posts=(5, 3),
                           roof_spots=("moss", 0.1, 0.2, 13))
    K.chimney(p, P, "chimney", 0.55, 0.5, 2.6, 4.0)
    x0, x1, z0, z1 = P.rect(*lodge)
    K.door_left(p, P, "door", 1.45, x0, 0.2, w=0.5, h=1.0)
    K.window_left(p, P, 0.6, x0, 0.9, w=0.3, h=0.32)
    K.window_left(p, P, 0.5, top and P.rect(*top)[0], 1.95, w=0.3, h=0.3)
    K.window_left(p, P, 1.4, P.rect(*top)[0], 1.95, w=0.3, h=0.3)
    K.window_right(p, P, 0.7, P.rect(*top)[3], 1.95, w=0.3, h=0.3)
    K.sign_right(p, P, 1.05, z1, 1.3, W.emblem_saw)
    # the open saw shed beside it
    shed = (2.05, 3.9, 0.12, 1.3)
    K.lean_to(p, P, "shed_roof", shed, "-gy", 2.0, 2.85, "shingle", "shingle_dark", over=0.2)
    K.board_walls(p, P, "shed_back", (2.05, 3.9, 0.12, 0.2), 0.0, 2.8)
    p.footprints.append(shed)
    for gx in (2.2, 2.95):
        a = P.m(gx, 0.85)
        for s in (-1, 1):
            p.add("trestles", "post", cyl([a[0] + s * 0.18, 0, a[2]], [a[0], 0.55, a[2]], 0.04), "prop")
    K.log(p, P, (2.05, 0.85), (3.05, 0.85), 0.12, name="spare_mast", y=0.62, mat="raw_timber")
    planks_stack(p, P, 2.5, 0.45, along="gx", layers=4, length=0.8)
    # the slipway
    slipway(p, P, 1.06, 2.94, 1.45, 3.98, y0=0.42, y1=-0.32)
    # tar kettle, log pile, anchor, a bollard on the pier strip
    tar_kettle(p, P, 0.45, 1.55)
    for k in range(3):
        K.log(p, P, (0.08, 1.75 + k * 0.08 - 0.05 * (k == 2)), (0.78, 1.75 + k * 0.08 - 0.05 * (k == 2)), 0.08, y=0.08 + 0.13 * (k == 2))
    anchor(p, P, 3.75, 1.75)
    iron_bollard(p, P, 3.5, 3.82)
    rope_coil(p, P, 3.3, 2.4, r=0.13)
    p.heap = (3.5, 1.5)
    return P, p, 352, 2.4


# =================================================================================================
# Large shipyard (6x6; water rows 3-5: a wide slipway between two pier strips (QuayLayer), the big
# hull on it (ShipLayer); the timber stack on the yard tile (5, 0) under the shed). A great boat
# hall of two storeys, fieldstone and half-timbering under shingles with a sail loft and a hoist,
# a long open shed with planks drying on sticks and a mast on trestles, two shear legs over the
# head of the slip, tar kettles, log piles, anchors, coils of cable.
# =================================================================================================
def large_shipyard():
    P, p = Plot(6), Parts()
    hall = (0.12, 3.15, 0.12, 2.15)
    g, eave, top = K.house(p, P, "hall", hall, ground="fieldstone", ground_h=1.6, upper="plaster", upper_h=1.25,
                           axis="gx", roof_mat="shingle", roof_dark="shingle_dark", rise=1.9, posts=(8, 5),
                           roof_spots=("moss", 0.1, 0.2, 17), with_quoins=True)
    K.chimney(p, P, "chimney", 0.6, 0.8, 3.4, 5.0)
    x0, x1, z0, z1 = P.rect(*hall)
    tx0, tx1, tz0, tz1 = P.rect(*top)
    K.door_left(p, P, "door", 2.5, x0, 0.2, w=0.7, h=1.2)
    for gx in (0.5, 1.2, 1.9):
        K.window_left(p, P, gx, x0, 1.0, w=0.3, h=0.34)
    for gx in (0.45, 1.05, 1.65, 2.25, 2.85):
        K.window_left(p, P, gx, tx0, 2.2, w=0.3, h=0.32)
    K.window_right(p, P, 0.6, tz1, 2.2, w=0.3, h=0.32)
    K.window_right(p, P, 1.6, tz1, 2.2, w=0.3, h=0.32)
    # the sail loft door in the gable with a hoist beam
    p.add("loft_door", "door_wood", box([(tx0 + tx1) / 2, 3.35, tz1 + 0.03], [0.3, 0.35, 0.04]), "wall")
    p.add("loft_hoist", "timber", box([(tx0 + tx1) / 2, 3.95, tz1 + 0.4], [0.06, 0.06, 0.45]), "roof")
    p.add("loft_rope", "rope", cyl([(tx0 + tx1) / 2, 3.9, tz1 + 0.75], [(tx0 + tx1) / 2, 2.6, tz1 + 0.75], 0.016), "roof", min_cover=1)
    p.add("sail_bundle", "sailcloth", ell([(tx0 + tx1) / 2, 2.45, tz1 + 0.75], [0.16, 0.2, 0.16]), "roof")
    K.sign_right(p, P, 1.4, z1, 1.45, W.emblem_saw)
    shed = (3.3, 5.9, 0.12, 2.1)
    K.lean_to(p, P, "shed_roof", shed, "-gy", 2.3, 3.3, "shingle", "shingle_dark", over=0.22)
    K.board_walls(p, P, "shed_back", (3.3, 5.9, 0.12, 0.2), 0.0, 3.25)
    p.footprints.append(shed)
    sx0, sx1, sz0, sz1 = P.rect(*shed)
    x, _, z = P.m(4.6, 2.1)
    p.add("shed_mid_post", "post", cyl([x + 0.08, 0, z], [x + 0.08, 2.28, z], 0.06), "wall")
    planks_stack(p, P, 3.8, 0.6, along="gx", layers=5, length=0.9)
    planks_stack(p, P, 4.55, 1.35, along="gx", layers=3, length=0.9)
    for gx in (3.5, 4.6):
        a = P.m(gx, 1.75)
        for s in (-1, 1):
            p.add("trestles", "post", cyl([a[0] + s * 0.18, 0, a[2]], [a[0], 0.55, a[2]], 0.04), "prop")
    K.log(p, P, (3.35, 1.75), (4.9, 1.75), 0.14, name="spare_mast", y=0.64, mat="raw_timber")
    # the slipway between the two pier strips
    slipway(p, P, 1.06, 4.94, 2.45, 5.98, y0=0.5, y1=-0.35, water_from=3.0)
    shear_legs(p, P, (0.75, 2.3), (0.75, 3.3), 4.6, name="shears_a")
    shear_legs(p, P, (5.25, 2.3), (5.25, 3.3), 4.6, name="shears_b")
    tar_kettle(p, P, 0.45, 2.75)
    for k in range(3):
        K.log(p, P, (3.4 + 0.1 * k, 2.32 - 0.07 * (k == 2)), (4.6 + 0.1 * k, 2.32 - 0.07 * (k == 2)), 0.09,
              y=0.09 + 0.15 * (k == 2), name="logs")
    anchor(p, P, 0.35, 2.3)
    for gx, gy in ((0.5, 5.75), (5.5, 5.75), (0.5, 3.6), (5.5, 3.6)):
        iron_bollard(p, P, gx, gy)
    rope_coil(p, P, 5.4, 4.3, r=0.17, turns=4)
    p.heap = (5.5, 2.5)
    return P, p, 512, 3.2


# =================================================================================================
# Dockers' hut (2x2, may stand a row on piles; doors in the left face at game x 0.5 and opposite):
# a weatherboarded cottage on a fieldstone plinth under a hipped shingle roof with a chimney, an
# open lean-to with coiled ropes, sacks and a hand cart, nets drying, crates, oars.
# =================================================================================================
def docker_hut():
    P, p = Plot(2), Parts()
    house = (0.12, 1.3, 0.12, 1.88)
    K.plinth(p, P, "plinth", house, h=0.2, mat="fieldstone")
    K.board_walls(p, P, "walls", house, 0.2, 1.55, mat="weathered")
    K.timber_left(p, P, "frame_l", house, 0.2, 1.55, 3, braces=False)
    K.timber_right(p, P, "frame_r", house, 0.2, 1.55, 2, braces=False)
    K.hip_roof(p, P, "roof", house, 1.55, 2.75, "shingle", "shingle_dark", over=0.24, course=0.14, along="gy",
               spots=("moss", 0.1, 0.22, 19))
    K.chimney(p, P, "chimney", 0.75, 0.55, 2.2, 3.15, w=0.18)
    p.footprints = [house]
    x0, x1, z0, z1 = P.rect(*house)
    K.door_left(p, P, "door", 0.55, x0, 0.2, w=0.46, h=0.95, arch=False)
    K.window_left(p, P, 1.05, x0, 0.95, w=0.26, h=0.28)
    K.window_right(p, P, 0.7, z1, 0.95, w=0.26, h=0.28)
    K.window_right(p, P, 1.4, z1, 0.95, w=0.26, h=0.28)
    lean = (1.36, 1.9, 0.2, 1.3)
    K.lean_to(p, P, "lean_roof", lean, "-gx", 1.2, 1.6, "shingle", "shingle_dark", over=0.14)
    p.footprints.append(lean)
    rope_coil(p, P, 1.62, 0.5, r=0.16, turns=4)
    K.sack(p, P, 1.6, 0.95, s=0.15)
    K.sack(p, P, 1.72, 0.75, s=0.13)
    # a hand cart with crates, oars against the wall, a net on a pole, a lantern
    K.cart(p, P, 1.55, 1.62, yaw=1.57) if False else K.wheelbarrow(p, P, 1.55, 1.6, yaw=0.5)
    K.crate(p, P, 1.62, 1.72, s=0.13, y0=0.36)
    for k in range(2):
        a, b = P.m(0.3 + k * 0.1, 1.95), P.m(0.25 + k * 0.1, 1.92, 1.4)
        p.add("oars", "haft", cyl(a, b, 0.022), "prop", priority=2)
    K.lantern(p, P, 0.95, z1, 1.35)
    p.heap = (1.6, 1.0)
    return P, p, 224, 1.6


# =================================================================================================
# Dockers' house (3x3, stands on the stone quay; doors in the left face at game x 1.5 and the
# opposite face): the foreman's house, a fieldstone ground floor with a jettied half-timbered upper
# floor under red tiles with a dormer, a weatherboarded back wing, a lookout tower at the back
# corner with a slate spire and a pennant, an open loading shed with sacks, barrels and coiled
# ropes, a hand crane (davit) with a block at the front corner, crates, a lantern.
# =================================================================================================
def docker_house():
    P, p = Plot(3), Parts()
    front = (0.14, 2.05, 1.05, 2.86)
    g, eave, top = K.house(p, P, "house", front, ground="fieldstone", ground_h=1.5, upper="plaster", upper_h=1.05,
                           axis="gx", roof_mat="tile", roof_dark="tile_dark", rise=1.35, posts=(5, 4))
    x0, x1, z0, z1 = P.rect(*front)
    tx0, tx1, tz0, tz1 = P.rect(*top)
    TOWN.portal_left(p, P, 1.5, x0, 0.2, w=0.5, h=0.95, pointed=False)
    K.window_left(p, P, 0.6, x0, 0.95, w=0.3, h=0.32)
    for gx in (0.5, 1.1, 1.7):
        K.window_left(p, P, gx, tx0, 2.05, w=0.28, h=0.3)
    K.window_right(p, P, 1.6, tz1, 2.05, w=0.28, h=0.3)
    K.window_right(p, P, 2.35, tz1, 2.05, w=0.28, h=0.3)
    K.chimney(p, P, "chimney", 1.4, 1.95, 3.0, 4.2)
    wing = (0.92, 2.86, 0.14, 0.98)
    K.plinth(p, P, "wing_plinth", wing, h=0.2, mat="fieldstone")
    K.board_walls(p, P, "wing_walls", wing, 0.2, 1.6, mat="weathered")
    gw = Gable(P, "wing", wing, "gx", 1.6, 2.7, over=0.26, end_over=0.22)
    gw.infill(p, "weathered")
    gw.roof(p, "shingle", "shingle_dark", course=0.13, spots=("moss", 0.1, 0.2, 23))
    gw.bargeboards(p)
    p.footprints.append(wing)
    p.roofs.append(gw)
    wx0, wx1, wz0, wz1 = P.rect(*wing)
    p.add("wing_door", "door_wood", box([(wx0 + wx1) / 2, 0.75, wz1 + 0.03], [0.32, 0.55, 0.04]), "wall")
    p.paint("wing_door", "ink", stripes={"axis": "x", "period": 0.16, "width": 0.04})
    # the lookout tower at the back corner
    tw = (0.16, 0.86, 0.16, 0.86)
    K.walls(p, P, "tower", tw, 0.0, 3.9, "fieldstone")
    p.paint("tower", "stone_dark", spots={"scale": 0.07, "density": 0.4, "seed": 8})
    K.quoins(p, P, "tower_quoins", tw, 0.0, 3.9)
    K.walls(p, P, "tower_top", (0.1, 0.92, 0.1, 0.92), 3.9, 4.75, "plaster")
    K.timber_left(p, P, "tower_frame", (0.1, 0.92, 0.1, 0.92), 3.9, 4.75, 2)
    K.timber_right(p, P, "tower_frame_r", (0.1, 0.92, 0.1, 0.92), 3.9, 4.75, 2)
    p.add("tower_jetty", "timber", box(P.m(0.51, 0.51, 3.9), [0.05 + 0.41 * K.T, 0.05, 0.05 + 0.41 * K.T]), "wall")
    tx = P.rect(0.1, 0.92, 0.1, 0.92)
    for gx in (0.51,):
        p.add("tower_window", "dark_hole", box([tx[0] - 0.02, 4.35, P.m(gx, 0)[2]], [0.03, 0.2, 0.2]), "wall", priority=2)
    p.add("tower_window", "dark_hole", box([P.m(0, 0.51)[0], 4.35, tx[3] + 0.02], [0.2, 0.2, 0.03]), "wall", priority=2)
    TOWN.spire(p, P, "tower_spire", (0.06, 0.96, 0.06, 0.96), 4.75, 1.6, mat="slate", dark="slate_dark", finial="gilt")
    p.footprints.append(tw)
    # the open loading shed in front of the right face
    shed = (2.12, 2.9, 1.05, 2.86)
    K.lean_to(p, P, "shed_roof", shed, "-gx", 1.35, 1.95, "shingle", "shingle_dark", over=0.16)
    p.footprints.append(shed)
    K.sack(p, P, 2.45, 1.35, s=0.16)
    K.sack(p, P, 2.62, 1.6, s=0.15)
    K.barrel(p, P, 2.5, 2.25, r=0.16, h=0.42)
    K.barrel(p, P, 2.55, 2.6, r=0.15, h=0.4)
    rope_coil(p, P, 2.4, 1.95, r=0.15, turns=4)
    # a hand crane at the front corner, crates by the door, a lantern
    x, _, z = P.m(2.95, 2.95)
    p.add("davit", "tarred", cyl([x, 0, z], [x, 1.9, z], 0.06), "wall")
    p.add("davit", "tarred", cyl([x, 1.85, z], [x - 0.45, 2.0, z + 0.3], 0.045), "wall")
    p.add("davit", "tarred", cyl([x, 1.2, z], [x - 0.3, 1.95, z + 0.2], 0.035), "wall")
    p.add("davit_rope", "rope", cyl([x - 0.45, 1.95, z + 0.3], [x - 0.45, 0.9, z + 0.3], 0.015), "wall", min_cover=1)
    p.add("davit_hook", "iron", tor([x - 0.45, 0.86, z + 0.3], 0.05, 0.015), "wall")
    K.crate(p, P, 0.3, 2.92, s=0.16)
    K.crate(p, P, 0.55, 2.95, s=0.14)
    K.crate(p, P, 0.42, 2.92, s=0.12, y0=0.32, rot=0.4)
    K.lantern(p, P, 1.0, z1, 1.4)
    p.heap = (1.5, 2.6)
    return P, p, 320, 2.6

BUILDINGS = {
    "bollard": (bollard, "Your Kingdom bollard (G3 part 5a), 1x1 tile on a stone quay: a squat iron bollard on an ashlar "
                "block with a hawser round it, a coiled rope, a lantern post, crates and a barrel waiting"),
    "mooring": (mooring, "Your Kingdom mooring (G3 part 5a), 2x2 tiles on the quay: two pile dolphins bound with rope "
                "and a hawser between them, a capstan, iron bollards, coiled ropes, a lantern post, barrels, a net on a rail"),
    "crane": (crane, "Your Kingdom cargo crane (G3 part 5a), 2x2 tiles: a stone base with a timber platform, a great "
              "squared mast with iron bands on four raking struts, a slewing collar, a shingled hood over the sheave, a "
              "treadwheel on trestles by the door; the jib and the load are drawn by the game"),
}
BUILDINGS.update({
    "port": (port, "Your Kingdom port (G3 part 5a), 4x4 tiles: a weigh-house shed along the back of the quay yard, a "
             "fieldstone wall with a crow-stepped brick gable, a coat of arms and a gilt finial, stone pillars and a slate "
             "lean-to; on the pier a hand derrick hoisting barrels, a harbour light with a fire basket, bollards with "
             "hawsers, the kingdom's flag and cargo; the game draws the yard, the pier and the goods"),
    "port_warehouse": (port_warehouse, "Your Kingdom port warehouse shed (G3 part 5a), 3x3 tiles: fieldstone back walls and "
                       "a slate lean-to on posts over the back row and column, a hoist; the game draws the floor and stacks"),
    "port_warehouse_small": (port_warehouse_small, "Your Kingdom small port warehouse shed (G3 part 5a), 2x2 tiles: a "
                             "fieldstone back wall and a slate lean-to on posts over the back row, a hoist"),
    "port_store": (port_store, "Your Kingdom port store (G3 part 5a), 1x1 tile: stone slabs and tarred posts (its "
                   "construction stages; the game draws the floor and the stacks)"),
    "fishing_wharf": (fishing_wharf, "Your Kingdom fishing wharf (G3 part 5a), 3x3 tiles: a fisherman's house of grey "
                      "boards under a heavy reed thatch, a fieldstone smokehouse with smoke, fish drying on a rack, an "
                      "upturned boat on trestles, oars, creels; on the pier nets on poles, a gutting table, a herring tub"),
    "shipyard": (shipyard, "Your Kingdom shipyard (G3 part 5a), 4x4 tiles: a shipwright's lodge, fieldstone and "
                 "half-timbering under shingles, an open saw shed with a spare mast and planks drying on sticks, a "
                 "slipway with ways, keel blocks and piles, a tar kettle on a fire, logs, an anchor"),
    "large_shipyard": (large_shipyard, "Your Kingdom large shipyard (G3 part 5a), 6x6 tiles: a great two-storey boat "
                       "hall with a sail loft and a hoist, a long open shed with planks and a mast on trestles, a wide "
                       "slipway between two piers, two shear legs, a tar kettle, logs, an anchor, cables"),
    "docker_hut": (docker_hut, "Your Kingdom dockers' hut (G3 part 5a), 2x2 tiles: a weatherboarded cottage under a "
                   "hipped shingle roof with a chimney, an open lean-to with ropes and sacks, a barrow with crates, oars"),
    "docker_house": (docker_house, "Your Kingdom dockers' house (G3 part 5a), 3x3 tiles on the stone quay: a fieldstone "
                     "and half-timbered house under red tiles, a weatherboarded back wing, a lookout tower with a slate "
                     "spire, an open loading shed with sacks and barrels, a hand crane, crates, a lantern"),
})
ENTRANCES = {"bollard": (0, 0), "mooring": (0, 0), "crane": (0, 1), "port": (3, 1), "port_warehouse": (1, 2),
             "port_warehouse_small": (0, 1), "port_store": (0, 0), "fishing_wharf": (2, 1), "shipyard": (3, 1),
             "large_shipyard": (5, 1), "docker_hut": (0, 1), "docker_house": (1, 2)}
# Yards: only the construction stages and the shed pieces are exported (no base art).
YARDS = {"port_warehouse", "port_warehouse_small", "port_store"}


def main():
    only = [a for a in sys.argv[1:] if not a.startswith("-")]
    W.ENTRANCES.update(ENTRANCES)
    for bid, (fn, summary) in BUILDINGS.items():
        if only and bid not in only:
            continue
        P, parts, size, cy = fn()
        s = head(bid, size, cy, summary)
        pieces = getattr(parts, "pieces", {})
        in_pieces = {k for v in pieces.values() for k in v[2]}
        # A building drawn partly in pieces: its base art leaves the pieces out.
        s["parts"] = {k: v for k, v in parts.items() if k not in in_pieces}
        s["animations"] = {"idle": {"frames": 1, "ms": 500, "channels": {}}}
        n = W.write(bid, s)
        for piece, (_off, _fp, names) in pieces.items():
            sp = head(f"{bid}_{piece}", size, cy, summary + f" (piece {piece})")
            sp["parts"] = {k: v for k, v in parts.items() if k in names}
            sp["animations"] = s["animations"]
            W.write(bid, sp)
        if pieces:
            with open(os.path.join(HERE, "art", "specs", "props", bid, "pieces.json"), "w") as fh:
                json.dump({k: {"offset": v[0], "footprint": v[1]} for k, v in pieces.items()}, fh)
        for k in (1, 2):
            st = W.stage(P, parts, k, parts.roofs)
            s2 = head(f"{bid}_c{k}", size, cy, summary + f" (construction stage {k})")
            s2["parts"] = dict(st)
            s2["animations"] = s["animations"]
            W.write(bid, s2)
        if getattr(parts, "spots", None):
            W.write_spots(bid, P, parts)
        print("written", bid, n, "prims")


if __name__ == "__main__":
    main()
