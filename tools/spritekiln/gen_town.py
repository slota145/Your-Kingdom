"""G3 part 4b: the town's buildings from SpriteKiln (ROADMAP G3, "Część 4, plan").

Each building designed anew (owner's survey 2026-11-13: very detailed and clearly medieval): the
well, chapel, church, market, tavern, town hall, trading post, builders' hut, pioneer camp and the
warehouse's roofed shed. Same kit, spec head and construction stages as the workshops
(workshop_kit.py, gen_workshops.py). Sizes, entrances and rules unchanged.

Doors: an entrance tile on the plot's +x edge (2x2 buildings, entrance (1, 1)) puts the door in the
right face; on the +y edge (3x3 and 4x4: entrance (1, 2) / (1, 3)) in the left face, at game x 1.5.

Writes art/specs/props/<id>/<id>.yaml, <id>_c1.yaml and <id>_c2.yaml; edit this script.
Run (inside tools/spritekiln): python3 gen_town.py [<id>...], then render and
python3 export_building.py <id> --stages (or build_town.sh <id>...).
"""
import json
import math
import os
import sys

import gen_workshops as W
import workshop_kit as K
from workshop_kit import Gable, Parts, Plot, box, cone, cyl, ell, ext, sph, tor

HERE = os.path.dirname(os.path.abspath(__file__))

RAMPS = dict(W.RAMPS)
RAMPS.update({
    "canvas_red": ["#2a0806", "#6e1a12", "#a8321e", "#d0583a", "#e8846a"],
    "canvas_blue": ["#0a1028", "#1c2e5e", "#30508e", "#5076b4", "#7a9ccc"],
    "canvas_yellow": ["#2a1c04", "#6a4a10", "#a88020", "#d8b040", "#f0d470"],
    "canvas_white": ["#4a4436", "#8a826c", "#bcb49a", "#dcd6c0", "#f2eedc"],
    "gilt": ["#2a1a04", "#6a4410", "#a8781e", "#d8aa3a", "#f4d878"],
    "apple": ["#2a0604", "#6a1410", "#a42a1c", "#cc4a30", "#e87a50"],
    "cabbage": ["#0e1a08", "#2a4416", "#466e24", "#6a9634", "#94bc52"],
    "yew": ["#04100a", "#0c2416", "#163a22", "#22502e", "#2e663a"],
    "copper_roof": ["#0a1612", "#1a3a30", "#2c5a4a", "#3f7a64", "#5c9a80", "#86bca2"],
})


def materials():
    m = W.materials()
    m.update({
        "canvas_red": {"ramp": "canvas_red", "bands": [1, 4], "two_sided": True},
        "canvas_blue": {"ramp": "canvas_blue", "bands": [1, 4], "two_sided": True},
        "canvas_yellow": {"ramp": "canvas_yellow", "bands": [1, 4], "two_sided": True},
        "canvas_white": {"ramp": "canvas_white", "bands": [1, 4], "two_sided": True},
        "gilt": {"ramp": "gilt", "bands": [2, 4], "finish": "metal"},
        "apple": {"ramp": "apple", "bands": [1, 4]},
        "cabbage": {"ramp": "cabbage", "bands": [1, 4]},
        "yew": {"ramp": "yew", "bands": [1, 4]},
        "ashlar_light": {"ramp": "ashlar", "bands": [3, 5]},
        "bell": {"ramp": "brass", "bands": [1, 3], "finish": "metal"},
        "clock_face": {"ramp": "flour", "bands": [2, 4]},
        "copper_roof": {"ramp": "copper_roof", "bands": [2, 4]},
        "copper_roof_dark": {"ramp": "copper_roof", "bands": [0, 1], "outline": False},
        "copper_roof_light": {"ramp": "copper_roof", "bands": [3, 5], "outline": False},
    })
    return m


def head(name, size, cy, summary):
    s = W.head(name, size, cy, summary)
    s["ramps"] = RAMPS
    s["materials"] = materials()
    return s


# --- shared pieces ---------------------------------------------------------------------------------
def lancet_left(p, P, gx, x, y, w=0.26, h=0.7, name="lancets"):
    """A pointed (lancet) window with a stone surround in a left face (plane x)."""
    z = P.m(gx, 0)[2]
    p.add(name + "_frame", "ashlar_light", box([x - 0.02, y + h / 2, z], [0.03, h / 2 + 0.06, w / 2 + 0.07]), "wall")
    p.add(name + "_frame", "ashlar_light", ext([x - 0.02, y + h, z], [[-w / 2 - 0.07, 0], [w / 2 + 0.07, 0], [0, w * 0.95]], 0.06,
                                               rot=[0, 1.5708, 0]), "wall")
    p.add(name, "glass", box([x - 0.05, y + h / 2, z], [0.02, h / 2, w / 2]), "wall", priority=2)
    p.add(name, "glass", ext([x - 0.05, y + h - 0.01, z], [[-w / 2, 0], [w / 2, 0], [0, w * 0.75]], 0.04, rot=[0, 1.5708, 0]),
          "wall", priority=2)
    p.add(name + "_bar", "iron", box([x - 0.07, y + h * 0.45, z], [0.012, 0.012, w / 2]), "wall", priority=3)


def lancet_right(p, P, gy, z, y, w=0.26, h=0.7, name="lancets"):
    x = P.m(0, gy)[0]
    p.add(name + "_frame", "ashlar_light", box([x, y + h / 2, z + 0.02], [w / 2 + 0.07, h / 2 + 0.06, 0.03]), "wall")
    p.add(name + "_frame", "ashlar_light", ext([x, y + h, z + 0.02], [[-w / 2 - 0.07, 0], [w / 2 + 0.07, 0], [0, w * 0.95]], 0.06),
          "wall")
    p.add(name, "glass", box([x, y + h / 2, z + 0.05], [w / 2, h / 2, 0.02]), "wall", priority=2)
    p.add(name, "glass", ext([x, y + h - 0.01, z + 0.05], [[-w / 2, 0], [w / 2, 0], [0, w * 0.75]], 0.04), "wall", priority=2)
    p.add(name + "_bar", "iron", box([x, y + h * 0.45, z + 0.07], [w / 2, 0.012, 0.012]), "wall", priority=3)


def portal_left(p, P, gx, x, y0, w=0.62, h=1.2, name="portal", pointed=True):
    """A deep stone portal with a pointed (or round) arch and a plank door with iron straps, in a left face."""
    z = P.m(gx, 0)[2]
    hw = w / 2
    arch = ([[hw * 1.4 * math.cos(math.radians(a)) - (hw * 0.4 if a < 90 else -hw * 0.4) * 0, 0] for a in ()] or [])
    top = [[-hw - 0.16, 0], [hw + 0.16, 0], [hw + 0.16, h], [0, h + (hw + 0.16) * (1.25 if pointed else 1.0)], [-hw - 0.16, h]]
    p.add(name + "_frame", "ashlar_light", ext([x - 0.04, y0, z], top, 0.12, rot=[0, 1.5708, 0]), "wall", priority=2)
    inner = [[-hw, 0], [hw, 0], [hw, h], [0, h + hw * (1.25 if pointed else 1.0)], [-hw, h]]
    p.add(name + "_door", "door_wood", ext([x - 0.08, y0, z], inner, 0.06, rot=[0, 1.5708, 0]), "wall", priority=3)
    p.paint(name + "_door", "ink", stripes={"axis": "z", "period": w / 4, "width": 0.055, "offset": z - hw})
    for yy in (y0 + h * 0.3, y0 + h * 0.75):
        p.add(name + "_iron", "iron", box([x - 0.12, yy, z], [0.02, 0.035, hw - 0.05]), "wall", priority=3)
    p.add(name + "_step", "stone", box([x - 0.2, 0.06, z], [0.2, 0.06, hw + 0.25]), "found")
    _ = arch


def portal_right(p, P, gy, z, y0, w=0.62, h=1.2, name="portal", pointed=True):
    x = P.m(0, gy)[0]
    hw = w / 2
    top = [[-hw - 0.16, 0], [hw + 0.16, 0], [hw + 0.16, h], [0, h + (hw + 0.16) * (1.25 if pointed else 1.0)], [-hw - 0.16, h]]
    p.add(name + "_frame", "ashlar_light", ext([x, y0, z + 0.04], top, 0.12), "wall", priority=2)
    inner = [[-hw, 0], [hw, 0], [hw, h], [0, h + hw * (1.25 if pointed else 1.0)], [-hw, h]]
    p.add(name + "_door", "door_wood", ext([x, y0, z + 0.08], inner, 0.06), "wall", priority=3)
    p.paint(name + "_door", "ink", stripes={"axis": "x", "period": w / 4, "width": 0.055, "offset": x - hw})
    for yy in (y0 + h * 0.3, y0 + h * 0.75):
        p.add(name + "_iron", "iron", box([x, yy, z + 0.12], [hw - 0.05, 0.035, 0.02]), "wall", priority=3)
    p.add(name + "_step", "stone", box([x, 0.06, z + 0.2], [hw + 0.25, 0.06, 0.2]), "found")


def buttress_right(p, P, gy, z, h, name="buttress"):
    """A stepped buttress against a right face (plane z)."""
    x = P.m(0, gy)[0]
    p.add(name, "ashlar", box([x, h * 0.35, z + 0.2], [0.13, h * 0.35, 0.2]), "wall")
    p.add(name, "ashlar", box([x, h * 0.75, z + 0.12], [0.12, h * 0.2, 0.12]), "wall")
    p.add(name, "ashlar", box([x, h * 0.72, z + 0.3], [0.13, 0.05, 0.16], rot=[0.7, 0, 0]), "wall")
    p.add(name, "ashlar", box([x, h * 0.96, z + 0.14], [0.12, 0.05, 0.12], rot=[0.7, 0, 0]), "wall")


def buttress_left(p, P, gx, x, h, name="buttress"):
    z = P.m(gx, 0)[2]
    p.add(name, "ashlar", box([x - 0.2, h * 0.35, z], [0.2, h * 0.35, 0.13]), "wall")
    p.add(name, "ashlar", box([x - 0.12, h * 0.75, z], [0.12, h * 0.2, 0.12]), "wall")
    p.add(name, "ashlar", box([x - 0.3, h * 0.72, z], [0.16, 0.05, 0.13], rot=[0, 0, 0.7]), "wall")


def spire(p, P, name, rect, y0, h, mat="slate", dark="slate_dark", finial="gilt", over=0.12):
    """A steep pyramid spire over a square game rectangle, a gilt ball and a cross or vane on top."""
    K.hip_roof(p, P, name, rect, y0, y0 + h, mat, dark, over=over, course=0.16, along="gy")
    x0, x1, z0, z1 = P.rect(*rect)
    c = [(x0 + x1) / 2, y0 + h, (z0 + z1) / 2]
    p.add(name + "_finial", finial, sph([c[0], c[1] + 0.12, c[2]], 0.1), "roof")
    p.add(name + "_finial", "iron", cyl([c[0], c[1], c[2]], [c[0], c[1] + 0.65, c[2]], 0.025), "roof", min_cover=1)
    p.add(name + "_finial", "iron", cyl([c[0], c[1] + 0.48, c[2] - 0.15], [c[0], c[1] + 0.48, c[2] + 0.15], 0.022), "roof",
          min_cover=1)


def bell(p, c, r=0.16, name="bell"):
    x, y, z = c
    p.add(name, "bell", cone([x, y - r * 1.2, z], [x, y, z], r, r * 0.45), "wall", priority=2)
    p.add(name, "bell", sph([x, y, z], r * 0.45), "wall", priority=2)
    p.add(name + "_beam", "timber", cyl([x - 0.25, y + 0.08, z], [x + 0.25, y + 0.08, z], 0.04), "wall")


def gravestone(p, P, gx, gy, kind=0, name="graves"):
    x, _, z = P.m(gx, gy)
    if kind == 0:
        p.add(name, "stone", box([x, 0.22, z], [0.04, 0.22, 0.13]), "prop")
        p.add(name, "stone", cyl([x - 0.04, 0.44, z], [x + 0.04, 0.44, z], 0.13), "prop")
    else:
        p.add(name + "_cross", "timber", box([x, 0.3, z], [0.035, 0.3, 0.035]), "prop")
        p.add(name + "_cross", "timber", box([x, 0.45, z], [0.035, 0.035, 0.14]), "prop")
    p.add(name + "_mound", "grass", ell([x - 0.25, 0.02, z], [0.28, 0.05, 0.14]), "ground")


def bench(p, P, a, b, name="bench", h=0.36):
    pa, pb = P.m(a[0], a[1], h), P.m(b[0], b[1], h)
    L = math.dist([pa[0], pa[2]], [pb[0], pb[2]]) / 2
    ang = math.atan2(pb[2] - pa[2], pb[0] - pa[0])
    c = [(pa[0] + pb[0]) / 2, h, (pa[2] + pb[2]) / 2]
    p.add(name, "board", box(c, [L, 0.035, 0.12], rot=[0, -ang, 0]), "prop")
    for t in (-0.8, 0.8):
        q = [c[0] + math.cos(ang) * L * t, h / 2, c[2] + math.sin(ang) * L * t]
        p.add(name + "_legs", "post", box(q, [0.04, h / 2, 0.1], rot=[0, -ang, 0]), "prop")


def table(p, P, gx, gy, name="table", r=0.32):
    x, _, z = P.m(gx, gy)
    p.add(name, "board", box([x, 0.55, z], [r, 0.035, r * 0.65]), "prop")
    p.add(name + "_legs", "post", box([x, 0.27, z], [r * 0.7, 0.27, 0.04]), "prop")
    p.add(name + "_legs", "post", box([x, 0.27, z], [0.04, 0.27, r * 0.45]), "prop")


def yew(p, P, gx, gy, h=2.8, name="yew"):
    """A dark churchyard yew: a short trunk and a dense, pointed crown of stacked blobs."""
    x, _, z = P.m(gx, gy)
    p.add(name + "_trunk", "log_bark", cone([x, 0, z], [x, 0.6, z], 0.14, 0.1), "prop")
    for i, (fy, r) in enumerate(((0.3, 0.62), (0.5, 0.52), (0.68, 0.4), (0.84, 0.26))):
        p.add(name, "yew", ell([x + 0.03 * (i % 2), h * fy, z - 0.02 * i], [r, h * 0.16, r]), "prop", blend=0.08)
    p.add(name, "yew", cone([x, h * 0.9, z], [x, h * 1.08, z], 0.14, 0.0), "prop")
    p.paint(name, "leaves_dark", spots={"scale": 0.1, "density": 0.3, "seed": 8})


def mug(p, c, name="mugs"):
    p.add(name, "pewter", cyl([c[0], c[1], c[2]], [c[0], c[1] + 0.12, c[2]], 0.045), "prop", priority=2)


# =================================================================================================
# Well (1x1): a round fieldstone shaft with a stone coping under a little shingled roof on two
# posts, a windlass with a crank, a rope and a bucket; a trough and a bucket beside.
# =================================================================================================
def well():
    P, p = Plot(1), Parts()
    K.ground(P, p, mat="cobble_ground", dark="earth_dark", seed=31)
    c = P.m(0.48, 0.48)
    p.add("shaft", "fieldstone", cyl([c[0], 0, c[2]], [c[0], 0.62, c[2]], 0.5), "wall")
    p.paint("shaft", "stone_dark", spots={"scale": 0.07, "density": 0.45, "seed": 2})
    p.add("coping", "ashlar_light", tor([c[0], 0.66, c[2]], 0.44, 0.08), "wall")
    p.add("water", "water", cyl([c[0], 0.5, c[2]], [c[0], 0.52, c[2]], 0.38), "wall")
    for s in (-1, 1):
        p.add("posts", "post", box([c[0] + s * 0.5, 1.0, c[2]], [0.06, 1.0, 0.06]), "wall")
    p.add("windlass", "log_bark", cyl([c[0] - 0.5, 1.12, c[2]], [c[0] + 0.5, 1.12, c[2]], 0.08), "wall")
    p.add("rope_coil", "rope", cyl([c[0] - 0.2, 1.12, c[2]], [c[0] + 0.15, 1.12, c[2]], 0.1), "wall")
    p.add("crank", "iron", box([c[0] + 0.62, 1.04, c[2]], [0.02, 0.1, 0.02]), "wall", priority=2)
    p.add("crank", "iron", box([c[0] + 0.68, 0.96, c[2] + 0.05], [0.02, 0.02, 0.06]), "wall", priority=2)
    p.add("rope", "rope", cyl([c[0], 1.05, c[2] + 0.1], [c[0], 0.86, c[2] + 0.1], 0.015), "wall", min_cover=1)
    p.add("bucket", "barrel", cyl([c[0], 0.7, c[2] + 0.1], [c[0], 0.86, c[2] + 0.1], 0.1), "wall")
    p.paint("bucket", "iron", stripes={"axis": "y", "at": [0.74, 0.83], "width": 0.055})
    roof = Gable(P, "roof", (0.18, 0.78, 0.2, 0.76), "gy", 1.9, 2.45, over=0.12, end_over=0.12, thick=0.08)
    roof.roof(p, "shingle", "shingle_dark", course=0.11, spots=("moss", 0.08, 0.18, 3))
    roof.bargeboards(p)
    p.add("tie", "post", box([c[0], 1.93, c[2]], [0.62, 0.05, 0.05]), "wall")
    x, _, z = P.m(0.9, 0.62)
    p.add("trough", "fieldstone", box([x, 0.16, z], [0.12, 0.16, 0.3]), "prop")
    p.add("trough_water", "water", box([x, 0.31, z], [0.08, 0.01, 0.25]), "prop")
    K.bucket(p, P, 0.85, 0.12, fill="water")
    p.footprints = [(0.2, 0.78, 0.2, 0.78)]
    p.roofs = []
    p.heap = (0.78, 0.82)
    return P, p, 128, 1.05


# =================================================================================================
# Chapel (2x2): a fieldstone nave with ashlar quoins under steep slate, its gable with a pointed
# portal and a round window to the street (the right face), a timber bell-cote with a bell and a
# little spire on the ridge, lancet windows and buttresses on the long wall, a wayside cross under
# a little roof, a bench and flowers.
# =================================================================================================
def chapel():
    P, p = Plot(2), Parts()
    K.ground(P, p, mat="grass", dark="leaves_dark", seed=33)
    K.patch(p, "path", "earth", P, 1.75, 1.15, 0.25, 0.14)
    nave = (0.12, 1.86, 0.5, 1.72)
    p.footprints = [nave]
    K.plinth(p, P, "plinth", nave, h=0.24)
    K.walls(p, P, "walls", nave, 0.24, 1.85, "fieldstone")
    p.paint("walls", "stone_dark", spots={"scale": 0.08, "density": 0.4, "seed": 9})
    K.quoins(p, P, "quoins", nave, 0.24, 1.85)
    g = Gable(P, "nave", nave, "gx", 1.85, 3.55, over=0.22, end_over=0.2, flare=False)
    g.infill(p, "fieldstone")
    p.paint("nave_gable", "stone_dark", spots={"scale": 0.08, "density": 0.4, "seed": 10})
    g.roof(p, "slate", "slate_dark", course=0.12, spots=("slate_light", 0.12, 0.2, 7))
    p.roofs = [g]
    x0, x1, z0, z1 = P.rect(*nave)
    xc = (x0 + x1) / 2
    gyc = (nave[2] + nave[3]) / 2
    portal_right(p, P, gyc, z1, 0.24, w=0.52, h=0.95)
    # a round window over the door, a stone cross on the gable
    p.add("rose", "ashlar_light", cyl([xc, 2.55, z1 + 0.01], [xc, 2.55, z1 + 0.06], 0.24), "wall")
    p.add("rose_glass", "glass", cyl([xc, 2.55, z1 + 0.05], [xc, 2.55, z1 + 0.08], 0.17), "wall", priority=2)
    p.add("rose_bars", "ashlar_light", box([xc, 2.55, z1 + 0.09], [0.17, 0.02, 0.01]), "wall", priority=3)
    p.add("rose_bars", "ashlar_light", box([xc, 2.55, z1 + 0.09], [0.02, 0.17, 0.01]), "wall", priority=3)
    p.add("gable_cross", "ashlar_light", box([xc, 3.85, z1 + 0.05], [0.04, 0.3, 0.04]), "roof")
    p.add("gable_cross", "ashlar_light", box([xc, 3.92, z1 + 0.05], [0.16, 0.04, 0.04]), "roof")
    # long wall: lancets between buttresses
    for gx in (0.5, 1.15):
        lancet_left(p, P, gx, x0, 0.75, w=0.22, h=0.62)
    for gx in (0.18, 0.82, 1.5):
        buttress_left(p, P, gx, x0, 1.7)
    # bell-cote on the ridge near the front gable
    bz = z1 - 0.45
    for dx in (-0.2, 0.2):
        for dz in (-0.2, 0.2):
            p.add("cote_posts", "timber", box([xc + dx, 3.75, bz + dz], [0.04, 0.4, 0.04]), "roof")
    bell(p, [xc, 3.95, bz], r=0.13)
    spire(p, P, "cote_roof", ((bz + P.h - 0.3) / K.T, (bz + P.h + 0.3) / K.T, (P.h - xc - 0.3) / K.T,
                             (P.h - xc + 0.3) / K.T), 4.15, 1.0, over=0.08)
    # wayside cross under a little roof, a bench, flowers by the door
    x, _, z = P.m(1.7, 1.86)
    p.add("wayside", "timber", box([x, 0.75, z], [0.05, 0.75, 0.05]), "prop")
    p.add("wayside", "timber", box([x, 1.15, z], [0.05, 0.05, 0.28]), "prop")
    p.add("wayside_roof", "shingle", box([x - 0.08, 1.62, z], [0.2, 0.03, 0.36], rot=[0, 0, 0.5]), "prop")
    p.add("wayside_roof", "shingle", box([x + 0.08, 1.62, z], [0.2, 0.03, 0.36], rot=[0, 0, -0.5]), "prop")
    p.add("wayside_wreath", "leaves", tor([x - 0.06, 1.0, z], 0.1, 0.03, rot=[0, 0, 1.5708]), "prop")
    bench(p, P, (1.95, 0.55), (1.95, 0.9))
    for i, gy in enumerate((0.62, 0.8, 1.5, 1.6)):
        x, _, z = P.m(1.93, gy)
        p.add("flower_stems", "leaves", ell([x, 0.1, z - 0.15], [0.09, 0.12, 0.09]), "prop")
        p.add("flowers", "bloom" if i % 2 else "paint_red", sph([x, 0.22, z - 0.15], 0.05), "prop")
    K.tufts(p, P, [(0.1, 1.95), (1.95, 0.1), (1.0, 1.95)])
    p.heap = (1.8, 0.3)
    return P, p, 224, 2.1


# =================================================================================================
# Church (3x3): an ashlar nave under steep slate, its west front with a deep pointed portal, a rose
# window and pinnacles towards the street (the left face), buttresses and tall lancets along the
# long wall, a square tower at the back corner with louvred belfry openings, a clock and a tall
# spire with a gilt ball; a churchyard with gravestones, crosses and a yew.
# =================================================================================================
def church():
    P, p = Plot(3), Parts()
    K.ground(P, p, mat="grass", dark="leaves_dark", seed=35)
    nave = (0.75, 2.25, 0.85, 2.72)
    tower = (0.72, 1.7, 0.08, 0.95)
    p.footprints = [nave, tower]
    for nm, r, top in (("nave", nave, 2.9), ("tower", tower, 6.7)):
        K.plinth(p, P, nm + "_plinth", r, h=0.28)
        K.walls(p, P, nm + "_walls", r, 0.28, top, "ashlar")
        p.paint(nm + "_walls", "ashlar_line", stripes={"axis": "y", "period": 0.28, "width": 0.055, "offset": 0.3})
        p.paint(nm + "_walls", "stone_dark", spots={"scale": 0.15, "density": 0.12, "seed": 4})
    K.quoins(p, P, "tower_quoins", tower, 0.28, 6.7)
    g = Gable(P, "nave", nave, "gy", 2.9, 5.0, over=0.24, end_over=0.18, flare=False)
    g.infill(p, "ashlar")
    p.paint("nave_gable", "ashlar_line", stripes={"axis": "y", "period": 0.28, "width": 0.055, "offset": 0.3})
    g.roof(p, "slate", "slate_dark", course=0.13, spots=("slate_light", 0.12, 0.22, 3))
    p.roofs = [g]
    x0, x1, z0, z1 = P.rect(*nave)
    zc = (z0 + z1) / 2
    # west front: portal, rose window, pinnacles on the corners, a cross on the apex
    portal_left(p, P, 1.5, x0, 0.28, w=0.72, h=1.35)
    p.add("rose", "ashlar_light", cyl([x0 - 0.01, 3.55, zc], [x0 - 0.07, 3.55, zc], 0.42), "wall")
    p.add("rose_glass", "glass", cyl([x0 - 0.05, 3.55, zc], [x0 - 0.09, 3.55, zc], 0.32), "wall", priority=2)
    for k in range(4):
        a = k * math.pi / 4
        p.add("rose_tracery", "ashlar_light", box([x0 - 0.1, 3.55, zc], [0.012, 0.32, 0.025], rot=[a, 0, 0]), "wall", priority=3)
    for z in (z0 + 0.06, z1 - 0.06):
        p.add("pinnacles", "ashlar", box([x0 - 0.12, 1.6, z], [0.14, 1.6, 0.14]), "wall")
        p.add("pinnacles", "ashlar_light", cone([x0 - 0.12, 3.2, z], [x0 - 0.12, 3.95, z], 0.15, 0.02), "roof")
    p.add("apex_cross", "ashlar_light", box([x0 - 0.18, 5.35, zc], [0.04, 0.35, 0.04]), "roof")
    p.add("apex_cross", "ashlar_light", box([x0 - 0.18, 5.45, zc], [0.04, 0.04, 0.18]), "roof")
    # long wall (right face): buttresses and tall lancets
    for gy in (1.0, 1.62, 2.24):
        lancet_right(p, P, gy + 0.31, z1, 0.95, w=0.3, h=1.35)
    for gy in (1.0, 1.62, 2.24, 2.68):
        buttress_right(p, P, gy, z1, 2.7)
    # tower: belfry openings with louvres, a clock, a string course, the spire
    tx0, tx1, tz0, tz1 = P.rect(*tower)
    txc, tzc = (tx0 + tx1) / 2, (tz0 + tz1) / 2
    for y in (2.9, 4.4, 5.45):
        p.add("tower_course", "ashlar_light", box([txc, y, tzc], [(tx1 - tx0) / 2 + 0.04, 0.05, (tz1 - tz0) / 2 + 0.04]), "wall")
    for s, (cx, cz, along) in enumerate(((tx0 - 0.02, tzc, "z"), (txc, tz1 + 0.02, "x"))):
        for k in (-1, 1):
            off = 0.24 * k
            c = [cx, 6.05, cz + off] if along == "z" else [cx + off, 6.05, cz]
            hh = [0.04, 0.4, 0.13] if along == "z" else [0.13, 0.4, 0.04]
            p.add("belfry", "dark_hole", box(c, hh), "wall", priority=2)
            for j in range(4):
                cc = list(c)
                cc[1] = 5.8 + j * 0.16
                p.add("louvres", "timber", box(cc, [hh[0] + 0.01, 0.025, hh[2] + 0.01] if along == "z" else
                                               [hh[0] + 0.01, 0.025, hh[2] + 0.01]), "wall", priority=3)
    p.add("clock", "clock_face", cyl([txc, 4.95, tz1 + 0.02], [txc, 4.95, tz1 + 0.07], 0.3), "wall")
    p.add("clock_rim", "gilt", tor([txc, 4.95, tz1 + 0.06], 0.3, 0.035, rot=[1.5708, 0, 0]), "wall")
    p.add("clock_hands", "ink", box([txc, 5.05, tz1 + 0.09], [0.02, 0.12, 0.01]), "wall")
    p.add("clock_hands", "ink", box([txc + 0.08, 4.95, tz1 + 0.09], [0.09, 0.02, 0.01]), "wall")
    lancet_right(p, P, (tower[2] + tower[3]) / 2, tz1, 1.5, w=0.18, h=0.55)
    spire(p, P, "spire", tower, 6.7, 3.1, over=0.18)
    # churchyard: graves, crosses, a yew, a low stone wall along the right edge
    for i, (gx, gy) in enumerate(((2.55, 1.0), (2.6, 1.55), (2.55, 2.1), (2.65, 2.6), (2.0, 0.4), (2.5, 0.45))):
        gravestone(p, P, gx, gy, kind=i % 2)
    yew(p, P, 2.55, 0.22)
    for i in range(10):
        gy = 0.15 + i * 0.28
        x, _, z = P.m(2.95, gy)
        p.add("yard_wall", "fieldstone", box([x, 0.22, z], [0.15, 0.22, 0.09]), "prop")
    p.paint("yard_wall", "stone_dark", spots={"scale": 0.07, "density": 0.4, "seed": 6})
    K.stones(p, P, [(1.3, 2.9), (1.7, 2.92)], name="path_stones")
    K.tufts(p, P, [(0.1, 2.9), (2.9, 2.95), (0.3, 1.2), (0.2, 0.3)])
    p.heap = (0.35, 2.2)
    return P, p, 352, 4.1


# =================================================================================================
# Tavern (2x2): a two-storey inn, the ground floor of fieldstone with timber posts, a jettied
# half-timbered upper floor under red tiles with a dormer, a big chimney; over the door an ale
# stake with a bush and a hanging sign with a tankard; in the yard a serving counter with casks
# behind the tapster (spot "bar"), a table with benches and mugs, a barrel table, a lantern.
# =================================================================================================
def tavern():
    P, p = Plot(2), Parts()
    K.ground(P, p, mat="cobble_ground", seed=37)
    house = (0.1, 1.0, 0.1, 1.9)
    g, eave, top = K.house(p, P, "house", house, ground="fieldstone", ground_h=1.55, upper="plaster", upper_h=1.1,
                           axis="gy", rise=1.5, roof_mat="tile", roof_dark="tile_dark", posts=(3, 5))
    K.dormer(p, P, g, "dormer", 0.75, roof_mat="tile", dark="tile_dark")
    K.chimney(p, P, "chimney", 0.35, 1.45, 2.8, 4.5, w=0.2)
    x0, x1, z0, z1 = P.rect(*house)
    tx0, tx1, tz0, tz1 = P.rect(*top)
    K.door_right(p, P, "door", 1.5, z1, 0.2, w=0.52, h=1.05, arch=True)
    K.window_right(p, P, 0.45, z1, 0.95, w=0.36, h=0.42)
    for gy in (0.4, 1.0, 1.55):
        K.window_right(p, P, gy, tz1, 2.15, w=0.32, h=0.38, box_=gy == 1.0)
    K.window_left(p, P, 0.55, tx0, 2.15, w=0.32, h=0.38)
    K.window_left(p, P, 0.55, x0, 0.95, w=0.32, h=0.38)
    K.sign_right(p, P, 1.12, z1, 1.85, W.emblem_tankard)
    # the ale stake: a pole out of the wall with a bush of greenery
    xs = P.m(0, 1.78)[0]
    p.add("ale_stake", "post", cyl([xs, 1.9, z1 + 0.05], [xs, 2.0, z1 + 0.75], 0.035), "wall", priority=2)
    p.add("ale_bush", "leaves", ell([xs, 1.9, z1 + 0.8], [0.18, 0.2, 0.18]), "wall")
    K.lantern(p, P, 0.85, z1, 1.45)
    # serving counter with casks behind the tapster
    a, b = P.m(1.62, 0.75, 0.5), P.m(1.62, 1.35, 0.5)
    p.add("counter", "board", box([(a[0] + b[0]) / 2, 0.52, a[2]], [abs(b[0] - a[0]) / 2, 0.05, 0.16]), "prop")
    p.add("counter_front", "barrel", box([(a[0] + b[0]) / 2, 0.25, a[2] + 0.1], [abs(b[0] - a[0]) / 2, 0.25, 0.04]), "prop")
    p.paint("counter_front", "barrel_dark", stripes={"axis": "x", "period": 0.12, "width": 0.055})
    for i, gy in enumerate((0.85, 1.1)):
        mug(p, P.m(1.62, gy, 0.57))
    for gy in (0.72, 1.02):
        K.barrel(p, P, 1.1, gy, r=0.16, h=0.42, lying=True, along="z")
    x, _, z = P.m(1.1, 0.87)
    p.add("cask_stand", "post", box([x, 0.12, z], [0.18, 0.12, 0.32]), "prop")
    # a table with benches, a barrel table, mugs
    table(p, P, 1.6, 1.78)
    bench(p, P, (1.32, 1.62), (1.32, 1.94), name="bench_a")
    bench(p, P, (1.88, 1.62), (1.88, 1.94), name="bench_b")
    mug(p, P.m(1.6, 1.7, 0.59))
    mug(p, P.m(1.55, 1.88, 0.59))
    K.barrel(p, P, 1.7, 0.25, r=0.2, h=0.55)
    mug(p, P.m(1.7, 0.25, 0.58))
    K.barrel(p, P, 1.9, 0.5, r=0.16, h=0.44)
    p.spots = {"bar": (1.375, 1.125)}
    K.tufts(p, P, [(1.98, 1.4), (1.05, 0.05)])
    p.heap = (1.6, 0.4)
    return P, p, 240, 2.25


# =================================================================================================
# Builders' hut (2x2): a carpenter's lodge, half-timbered on a stone plinth under shingles, a
# lean-to stacked with squared beams; in the yard a sawhorse with a beam, a ladder against the
# wall, bundled scaffold poles, a pile of planks, a hand barrow with stones, a plumb line on a post.
# =================================================================================================
def builders_hut():
    P, p = Plot(2), Parts()
    K.ground(P, p, seed=39)
    K.patch(p, "sawdust", "chips", P, 1.55, 1.5, 0.3, 0.2)
    house = (0.1, 1.0, 0.12, 1.3)
    g, eave, top = K.house(p, P, "house", house, ground="plaster", ground_h=1.6, axis="gy", rise=1.45,
                           roof_mat="shingle", roof_dark="shingle_dark", frame_ground=True, posts=(2, 3),
                           roof_spots=("moss", 0.09, 0.15, 6))
    K.chimney(p, P, "chimney", 0.35, 0.4, 2.0, 3.3, w=0.15, mat="stone")
    x0, x1, z0, z1 = P.rect(*house)
    K.door_right(p, P, "door", 1.05, z1, 0.2, w=0.5, h=1.02, arch=False)
    K.window_right(p, P, 0.42, z1, 0.95, w=0.32, h=0.36)
    K.window_left(p, P, 0.55, x0, 0.95, w=0.3, h=0.34)
    # lean-to with stacked beams in front of the gable
    shed = (0.1, 1.0, 1.32, 1.95)
    K.lean_to(p, P, "shed_roof", shed, "-gy", 1.25, 1.6, "shingle", "shingle_dark", over=0.1)
    for row in range(3):
        for i in range(4):
            a = P.m(0.2 + i * 0.2, 1.4, 0.1 + row * 0.18)
            b = P.m(0.2 + i * 0.2, 1.9, 0.1 + row * 0.18)
            p.add("beams_stack", "raw_timber" if (i + row) % 2 else "plank", box([(a[0] + b[0]) / 2, a[1], a[2]],
                                                                                 [abs(b[0] - a[0]) / 2, 0.08, 0.08]), "prop")
    p.paint("beams_stack", "ink", stripes={"axis": "y", "period": 0.18, "width": 0.055, "offset": 0.02})
    # yard: sawhorse with a beam, ladder, scaffold poles, planks, a hand barrow, a plumb line
    K.sawhorse(p, P, 1.55, 1.7, along="gy", with_log=False)
    a, b = P.m(1.55, 1.25, 0.62), P.m(1.55, 2.0, 0.62)
    p.add("beam_on_horse", "raw_timber", box([(a[0] + b[0]) / 2, 0.62, a[2]], [abs(b[0] - a[0]) / 2, 0.08, 0.08]), "prop")
    K.ladder(p, P, (1.08, 0.28, 0.0), (1.02, 0.28, 1.6), w=0.3)
    for i in range(5):
        x, _, z = P.m(1.25 + (i % 3) * 0.03, 0.62 + i * 0.03)
        p.add("poles", "raw_timber", cyl([x, 0, z], [x - 0.12, 1.9, z + 0.05 * (i - 2)], 0.035), "prop", priority=2)
    p.add("poles_tie", "rope", tor(P.m(1.27, 0.68, 1.2), 0.1, 0.02), "prop")
    for k in range(4):
        a, b = P.m(1.55, 0.15, 0.05 + k * 0.06), P.m(1.95, 0.15, 0.05 + k * 0.06)
        p.add("planks", "plank" if k % 2 else "plank_alt", box([(a[0] + b[0]) / 2, a[1], a[2] + 0.02 * k],
                                                               [0.22, 0.03, abs(b[2] - a[2]) / 2]), "prop")
    K.wheelbarrow(p, P, 1.85, 0.9, yaw=1.2)
    K.stones(p, P, [(1.82, 0.92), (1.88, 0.86)], name="barrow_stones")
    x, _, z = P.m(1.95, 1.3)
    p.add("plumb_post", "post", cyl([x, 0, z], [x, 1.05, z], 0.04), "prop")
    p.add("plumb_line", "rope", cyl([x, 1.0, z + 0.1], [x, 0.55, z + 0.1], 0.012), "prop", min_cover=1)
    p.add("plumb_bob", "iron", cone([x, 0.45, z + 0.1], [x, 0.56, z + 0.1], 0.0, 0.05), "prop")
    p.add("plumb_post", "post", box([x, 1.02, z + 0.06], [0.03, 0.03, 0.08]), "prop")
    p.spots = {}
    K.tufts(p, P, [(1.97, 1.97), (1.05, 0.05)])
    p.heap = (1.6, 0.45)
    return P, p, 224, 1.9


def arcade_left(p, P, x, gxs, y0, spring, top, depth=0.28, mat="ashlar", name="arcade"):
    """Round arches on pillars in a left face (plane x), between consecutive game x in `gxs`."""
    for gx in gxs:
        z = P.m(gx, 0)[2]
        p.add(name + "_pillars", "ashlar_light", box([x - depth / 2, (y0 + spring) / 2, z], [depth / 2, (spring - y0) / 2, 0.11]),
              "wall")
        p.add(name + "_pillars", "ashlar_light", box([x - depth / 2, spring + 0.04, z], [depth / 2 + 0.03, 0.05, 0.15]), "wall")
    for a, b in zip(gxs, gxs[1:]):
        za, zb = P.m(a, 0)[2] + 0.11, P.m(b, 0)[2] - 0.11
        hb = (zb - za) / 2
        poly = [[-hb - 0.11, top - y0], [hb + 0.11, top - y0], [hb + 0.11, spring - y0]]
        poly += [[hb * math.cos(math.radians(t)), spring - y0 + hb * 0.8 * math.sin(math.radians(t))] for t in range(0, 181, 15)]
        poly += [[-hb - 0.11, spring - y0]]
        p.add(name + "_spandrels", mat, ext([x - depth / 2, y0, (za + zb) / 2], poly, depth, rot=[0, 1.5708, 0]), "wall")


def banner_left(p, P, gx, x, y, mat="cloth_red", name="banners"):
    z = P.m(gx, 0)[2]
    p.add(name + "_pole", "iron", cyl([x - 0.02, y, z], [x - 0.45, y + 0.2, z], 0.022), "wall", priority=2, min_cover=1)
    p.add(name, mat, ext([x - 0.42, y + 0.18, z], [[-0.13, 0], [0.13, 0], [0.13, -0.75], [0, -0.6], [-0.13, -0.75]], 0.03,
                         rot=[0, 1.5708, 0]), "wall")
    p.add(name + "_charge", "gilt", sph([x - 0.43, y - 0.2, z], 0.06), "wall", priority=2)


# =================================================================================================
# Town hall (4x4): an ashlar ground floor opening in an arcade towards the square (the left face),
# a brick upper floor with tall stone-framed windows and string courses under a steep copper roof
# with dormers and a stepped brick gable to the side street; a clock tower over the gate in the
# middle of the front: gate with a coat of arms, a clock on two faces, an open belfry, a copper
# spire with a gilt ball and a pennant; banners, lanterns, steps and a paved forecourt.
# =================================================================================================
def town_hall():
    P, p = Plot(4), Parts()
    K.ground(P, p, mat="cobble_ground", seed=41)
    hall = (0.2, 3.75, 0.3, 2.8)
    tower = (1.08, 1.92, 2.15, 3.2)
    p.footprints = [hall, tower]
    K.plinth(p, P, "hall_plinth", hall, h=0.25)
    G, E = 2.35, 3.95
    back = (hall[0], hall[1], hall[2], 2.38)              # the ground floor, set back behind the arcade
    K.walls(p, P, "ground", back, 0.25, G, "ashlar")
    p.paint("ground", "ashlar_line", stripes={"axis": "y", "period": 0.28, "width": 0.055, "offset": 0.3})
    p.add("arcade_floor", "stone", box(P.m((hall[0] + hall[1]) / 2, 2.6, 0.27), [0.22, 0.02, (hall[1] - hall[0]) * K.T / 2]),
          "found")
    K.walls(p, P, "upper", hall, G, E, "brick")
    p.paint("upper", "brick_line", stripes={"axis": "y", "period": 0.13, "width": 0.055})
    x0, x1, z0, z1 = P.rect(*hall)
    p.add("courses", "ashlar_light", box([(x0 + x1) / 2, G + 0.03, (z0 + z1) / 2], [(x1 - x0) / 2 + 0.05, 0.06, (z1 - z0) / 2 + 0.05]),
          "wall")
    p.add("courses", "ashlar_light", box([(x0 + x1) / 2, E - 0.05, (z0 + z1) / 2], [(x1 - x0) / 2 + 0.08, 0.08, (z1 - z0) / 2 + 0.08]),
          "wall")
    K.quoins(p, P, "quoins", hall, G, E)
    arcade_left(p, P, x0, [0.28, 0.68, 1.06], 0.25, 1.65, G)
    arcade_left(p, P, x0, [1.94, 2.38, 2.84, 3.3, 3.68], 0.25, 1.65, G, name="arcade_b")
    xb = P.rect(*back)[0]
    for gx in (0.47, 0.87, 2.16, 3.07):
        K.window_left(p, P, gx, xb, 0.95, w=0.28, h=0.5, shutters=False)
    K.door_left(p, P, "side_door", 2.61, xb, 0.25, w=0.4, h=1.0, arch=True)
    # upper floor windows: tall, stone-framed, with a mullion
    for gx in (0.45, 0.85, 2.2, 2.6, 3.0, 3.4):
        K.window_left(p, P, gx, x0, 3.05, w=0.3, h=0.7, shutters=False)
        z = P.m(gx, 0)[2]
        p.add("wframes", "ashlar_light", box([x0 - 0.01, 3.05, z], [0.025, 0.44, 0.22]), "wall")
    for gy in (0.7, 1.3, 1.9):
        K.window_right(p, P, gy, z1, 3.05, w=0.3, h=0.7, shutters=False)
        K.window_right(p, P, gy, z1, 1.25, w=0.3, h=0.55, shutters=False)
    banner_left(p, P, 0.65, x0, 3.75)
    banner_left(p, P, 2.4, x0, 3.75, mat="cloth_blue")
    banner_left(p, P, 3.2, x0, 3.75)
    # roof: ridge along game x, a stepped brick gable to the side street, dormers
    g = Gable(P, "roof", hall, "gx", E, E + 2.25, over=0.2, end_over=0.12, flare=False)
    g.infill(p, "brick")
    p.paint("roof_gable", "brick_line", stripes={"axis": "y", "period": 0.13, "width": 0.055})
    g.roof(p, "copper_roof", "copper_roof_dark", course=0.15, spots=("copper_roof_light", 0.14, 0.25, 9))
    p.roofs = [g]
    xc = (x0 + x1) / 2
    hw = (x1 - x0) / 2
    steps = 5
    for i in range(steps):          # the stepped gable: brick blocks rising above the roof line
        f = i / steps
        h0 = E + 2.25 * f
        w_ = hw * (1 - f) + 0.08
        p.add("show_gable", "brick", box([xc, h0 + 0.25, z1 + 0.06], [w_, 2.25 / steps / 2 + 0.25, 0.1]), "wall")
        p.add("show_gable_caps", "ashlar_light", box([xc + w_ - 0.06, h0 + 2.25 / steps + 0.48, z1 + 0.06], [0.1, 0.04, 0.13]),
              "roof")
        p.add("show_gable_caps", "ashlar_light", box([xc - w_ + 0.06, h0 + 2.25 / steps + 0.48, z1 + 0.06], [0.1, 0.04, 0.13]),
              "roof")
    p.paint("show_gable", "brick_line", stripes={"axis": "y", "period": 0.13, "width": 0.055})
    K.window_right(p, P, (hall[2] + hall[3]) / 2, z1 + 0.16, 4.5, w=0.3, h=0.45, shutters=False)
    for gx in (0.6, 2.7, 3.35):     # small round lucarnes in the roof
        x, _, z = P.m(gx, 0)
        xs = x0 + 0.95
        ys = E + 2.25 * (1 - (xs - x0) / hw) * 0.98
        p.add("lucarnes", "copper_roof", box([xs - 0.12, ys, z], [0.18, 0.2, 0.2]), "roof")
        p.add("lucarnes", "copper_roof", cyl([xs - 0.3, ys + 0.2, z - 0.2], [xs - 0.3, ys + 0.2, z + 0.2], 0.2), "roof")
        p.add("lucarne_glass", "glass", cyl([xs - 0.31, ys + 0.05, z], [xs - 0.33, ys + 0.05, z], 0.11), "roof", priority=2)
    K.chimney(p, P, "chimney", 3.2, 0.8, 5.0, 6.6, w=0.17)
    # the clock tower over the gate
    tx0, tx1, tz0, tz1 = P.rect(*tower)
    txc, tzc = (tx0 + tx1) / 2, (tz0 + tz1) / 2
    T_TOP = 7.6
    K.plinth(p, P, "tower_plinth", tower, h=0.25)
    K.walls(p, P, "tower", tower, 0.25, T_TOP, "ashlar")
    p.paint("tower", "ashlar_line", stripes={"axis": "y", "period": 0.28, "width": 0.055, "offset": 0.3})
    K.quoins(p, P, "tower_quoins", tower, 0.25, T_TOP)
    for y in (G + 0.03, E - 0.05, 6.15):
        p.add("tower_courses", "ashlar_light", box([txc, y, tzc], [(tx1 - tx0) / 2 + 0.05, 0.06, (tz1 - tz0) / 2 + 0.05]), "wall")
    portal_left(p, P, 1.5, tx0, 0.25, w=0.8, h=1.2, pointed=False)
    # a coat of arms over the gate
    zg = P.m(1.5, 0)[2]
    p.add("arms_frame", "ashlar_light", ext([tx0 - 0.03, 2.7, zg], [[-0.3, 0.35], [0.3, 0.35], [0.3, 0], [0, -0.38], [-0.3, 0]], 0.06,
                                            rot=[0, 1.5708, 0]), "wall")
    p.add("arms_field", "cloth_red", ext([tx0 - 0.07, 2.72, zg], [[-0.22, 0.28], [0.22, 0.28], [0.22, 0], [0, -0.28], [-0.22, 0]],
                                         0.04, rot=[0, 1.5708, 0]), "wall", priority=2)
    p.add("arms_charge", "gilt", box([tx0 - 0.1, 2.75, zg], [0.02, 0.16, 0.05]), "wall", priority=3)
    p.add("arms_charge", "gilt", box([tx0 - 0.1, 2.82, zg], [0.02, 0.05, 0.14]), "wall", priority=3)
    # window over the arms, the clocks on the two faces the camera sees
    K.window_left(p, P, 1.5, tx0, 3.35, w=0.3, h=0.55, shutters=False)
    for face in ("l", "r"):
        if face == "l":
            c0, c1, rot = [tx0 - 0.02, 5.2, tzc], [tx0 - 0.08, 5.2, tzc], [0, 0, 1.5708]
            hand = ([tx0 - 0.1, 5.32, tzc], [0.01, 0.13, 0.025]), ([tx0 - 0.1, 5.2, tzc + 0.09], [0.01, 0.025, 0.1])
        else:
            c0, c1, rot = [txc, 5.2, tz1 + 0.02], [txc, 5.2, tz1 + 0.08], [1.5708, 0, 0]
            hand = ([txc, 5.32, tz1 + 0.1], [0.025, 0.13, 0.01]), ([txc + 0.09, 5.2, tz1 + 0.1], [0.1, 0.025, 0.01])
        p.add("clock", "clock_face", cyl(c0, c1, 0.34), "wall")
        p.add("clock_rim", "gilt", tor([(c0[0] + c1[0]) / 2, 5.2, (c0[2] + c1[2]) / 2], 0.34, 0.04, rot=rot), "wall")
        for hc, hh in hand:
            p.add("clock_hands", "ink", box(hc, hh), "wall")
    # open belfry with a bell, the copper spire, a pennant
    for cx, cz, hh in ((tx0 - 0.02, tzc, [0.04, 0.42, 0.22]), (txc, tz1 + 0.02, [0.22, 0.42, 0.04])):
        p.add("belfry", "dark_hole", box([cx, 6.75, cz], hh), "wall", priority=2)
    bell(p, [txc - 0.15, 6.95, tzc + 0.15], r=0.18)
    spire(p, P, "spire", tower, T_TOP, 2.6, mat="copper_roof", dark="copper_roof_dark", over=0.16)
    top = [txc, T_TOP + 3.25, tzc]
    p.add("pennant", "cloth_red", ext([top[0], top[1], top[2] + 0.02], [[0, 0], [0.55, -0.08], [0, -0.22]], 0.02), "roof")
    # forecourt: steps along the arcade, lanterns on posts by the gate, flower tubs
    for gx in (0.85, 2.15):
        x, _, z = P.m(gx, 3.45)
        p.add("lamp_posts", "iron", cyl([x, 0, z], [x, 1.5, z], 0.035), "prop")
        p.add("lamp", "iron", box([x, 1.6, z], [0.08, 0.11, 0.08]), "prop")
        p.add("lamp_light", "flame", box([x, 1.6, z], [0.05, 0.07, 0.05]), "prop", priority=2)
    for gx in (0.3, 3.6):
        W.K.tub(p, P, "tubs_%d" % int(gx * 10), gx, 3.1, 0.2, 0.32, fill="soil")
        x, _, z = P.m(gx, 3.1)
        p.add("tub_flowers", "bloom", ell([x, 0.42, z], [0.18, 0.12, 0.18]), "prop")
    K.tufts(p, P, [(3.95, 3.95), (0.05, 3.95)])
    p.heap = (2.8, 3.5)
    return P, p, 448, 4.6


# =================================================================================================
# Trading post (3x3): a merchant's counting house, fieldstone below and half-timbered above under
# red tiles, its gable to the side with a loft door and a hoist beam with a bale on a rope, a wide
# double door with a balance sign to the street; a great beam balance on a frame with weights, a
# covered trade wagon, crates, bales of cloth, barrels and sacks.
# =================================================================================================
def trading_post():
    P, p = Plot(3), Parts()
    K.ground(P, p, mat="cobble_ground", seed=43)
    K.patch(p, "trodden", "earth", P, 1.5, 2.5, 0.45, 0.4)
    house = (0.15, 2.05, 0.15, 1.85)
    g, eave, top = K.house(p, P, "house", house, ground="fieldstone", ground_h=1.7, upper="plaster_ochre", upper_h=1.25,
                           axis="gx", rise=1.6, roof_mat="tile", roof_dark="tile_dark", posts=(5, 4))
    x0, x1, z0, z1 = P.rect(*house)
    tx0, tx1, tz0, tz1 = P.rect(*top)
    K.door_left(p, P, "door", 1.5, x0, 0.2, w=0.9, h=1.2, arch=False)
    zd = P.m(1.5, 0)[2]
    p.add("door_split", "ink", box([x0 - 0.09, 0.8, zd], [0.02, 0.58, 0.015]), "wall", priority=3)
    for gx in (0.55, 2.45 - 0.6):
        K.window_left(p, P, gx, x0, 1.0, w=0.32, h=0.42)
    for gx in (0.5, 1.1, 1.7):
        K.window_left(p, P, gx, tx0, 2.35, w=0.3, h=0.4)
    # the side gable: a loft door, a hoist beam, a bale hanging on a rope
    gyc = (house[2] + house[3]) / 2
    xg = P.m(0, gyc)[0]
    p.add("loft_door", "door_wood", box([xg, 3.25, tz1 + 0.03], [0.32, 0.4, 0.03]), "wall")
    p.paint("loft_door", "ink", stripes={"axis": "x", "period": 0.16, "width": 0.055})
    p.add("hoist_beam", "timber", box([xg, 4.05, tz1 + 0.4], [0.07, 0.07, 0.45]), "roof")
    p.add("hoist_rope", "rope", cyl([xg, 3.98, tz1 + 0.75], [xg, 2.3, tz1 + 0.75], 0.016), "wall", min_cover=1, priority=2)
    p.add("hoist_bale", "sailcloth", box([xg, 2.05, tz1 + 0.75], [0.2, 0.22, 0.2], round_=0.05), "wall")
    p.add("hoist_bale_tie", "rope", box([xg, 2.05, tz1 + 0.75], [0.21, 0.025, 0.21]), "wall")
    K.window_right(p, P, 0.55, z1, 1.0, w=0.3, h=0.38)
    K.window_right(p, P, 1.45, z1, 1.0, w=0.3, h=0.38)
    K.chimney(p, P, "chimney", 0.6, 0.6, 3.6, 5.0, w=0.16)
    # a sign with a balance over the door
    xs = P.m(0, 2.1)[0]
    p.add("sign_bracket", "iron", box([x0 - 0.3, 2.0, P.m(2.1, 0)[2]], [0.3, 0.025, 0.025]), "wall", priority=2)
    p.add("sign_board", "sign_board", box([x0 - 0.45, 1.72, P.m(2.1, 0)[2]], [0.03, 0.2, 0.26]), "wall")
    zb = P.m(2.1, 0)[2]
    p.add("sign_emblem", "brass", box([x0 - 0.49, 1.8, zb], [0.012, 0.015, 0.17]), "wall", priority=3)
    p.add("sign_emblem", "brass", box([x0 - 0.49, 1.7, zb], [0.012, 0.1, 0.012]), "wall", priority=3)
    for dz in (-0.15, 0.15):
        p.add("sign_emblem", "brass", ell([x0 - 0.49, 1.63, zb + dz], [0.012, 0.03, 0.06]), "wall", priority=3)
    _ = xs
    # a great beam balance on a frame, weights
    x, _, z = P.m(0.55, 2.45)
    for dz in (-0.35, 0.35):
        p.add("balance_frame", "post", box([x, 0.75, z + dz], [0.06, 0.75, 0.06]), "prop")
    p.add("balance_frame", "post", box([x, 1.52, z], [0.07, 0.07, 0.45]), "prop")
    p.add("balance_beam", "iron", box([x, 1.3, z], [0.03, 0.03, 0.42]), "prop", priority=2)
    for dz in (-0.38, 0.38):
        p.add("balance_chains", "iron", cyl([x, 1.28, z + dz], [x, 0.72, z + dz], 0.012), "prop", min_cover=1)
        p.add("balance_pans", "brass", cyl([x, 0.68, z + dz], [x, 0.72, z + dz], 0.15), "prop")
    K.sack(p, P, 0.55, 2.29, s=0.13, y0=0.72)
    for i in range(3):
        xx, _, zz = P.m(0.3 + i * 0.1, 2.85)
        p.add("weights", "iron", cyl([xx, 0, zz], [xx, 0.1 + i * 0.03, zz], 0.06 + i * 0.015), "prop")
    # a covered trade wagon on the right strip
    K.cart(p, P, 2.55, 1.0, yaw=1.5708, load=None)
    cx, _, cz = P.m(2.55, 1.0)
    for k in range(4):
        dz = -0.45 + k * 0.3
        p.add("wagon_hoops", "post", tor([cx, 0.85, cz + dz], 0.38, 0.025, rot=[1.5708, 0, 0]), "prop")
    p.add("wagon_canvas", "sailcloth", ell([cx, 0.95, cz], [0.4, 0.42, 0.62]), "prop")
    p.cut("wagon_canvas", box([cx, 0.45, cz], [0.6, 0.5, 0.8]))
    # crates, cloth bales, barrels, sacks
    K.crate(p, P, 2.4, 2.1, s=0.2)
    K.crate(p, P, 2.4, 2.1, s=0.16, y0=0.4, rot=0.4)
    K.crate(p, P, 2.7, 2.3, s=0.2)
    for i, mat in enumerate(("cloth_red", "cloth_blue", "cloth_green")):
        x, _, z = P.m(2.75, 1.85 - i * 0.02)
        p.add("bales_" + mat, mat, cyl([x - 0.25, 0.14 + 0.17 * i, z], [x + 0.25, 0.14 + 0.17 * i, z], 0.09), "prop")
    K.barrel(p, P, 2.4, 2.7, r=0.18, h=0.5)
    K.barrel(p, P, 2.75, 2.75, r=0.18, h=0.5)
    K.sack(p, P, 2.05, 2.75, s=0.16)
    K.sack(p, P, 2.15, 2.55, s=0.15)
    K.tufts(p, P, [(2.95, 0.1), (0.05, 2.95), (2.95, 2.95)])
    p.heap = (2.5, 2.3)
    return P, p, 336, 3.0


def tent(p, P, gx, gy, along="gy", L=0.9, w=0.8, h=0.95, mat="sailcloth", name="tent"):
    """An A-frame canvas tent: two sloping cloths, a ridge pole, a dark open flap at the front end."""
    x, _, z = P.m(gx, gy)
    ang = math.atan2(h, w / 2)
    sl = math.hypot(h, w / 2) / 2
    for s in (-1, 1):
        if along == "gy":      # ridge along model x
            p.add(name, mat, box([x, h / 2, z + s * w / 4], [L / 2, 0.025, sl], rot=[s * ang, 0, 0]), "prop")
        else:
            p.add(name, mat, box([x + s * w / 4, h / 2, z], [sl, 0.025, L / 2], rot=[0, 0, -s * ang]), "prop")
    p.paint(name, "rope", stripes={"axis": "y", "at": [h * 0.5], "width": 0.055})
    if along == "gy":
        p.add(name + "_pole", "post", cyl([x - L / 2 - 0.1, h + 0.02, z], [x + L / 2 + 0.1, h + 0.02, z], 0.03), "prop")
        p.add(name + "_flap", "dark_hole", ext([x - L / 2 - 0.01, 0, z], [[-w * 0.3, 0], [w * 0.3, 0], [0, h * 0.75]], 0.02,
                                               rot=[0, 1.5708, 0]), "prop", priority=2)
        for s in (-1, 1):
            p.add(name + "_pegs", "rope", cyl([x - L / 2 - 0.1, h, z], [x - L / 2 - 0.45, 0, z + s * 0.2], 0.012), "prop",
                  min_cover=1)
    else:
        p.add(name + "_pole", "post", cyl([x, h + 0.02, z - L / 2 - 0.1], [x, h + 0.02, z + L / 2 + 0.1], 0.03), "prop")
        p.add(name + "_flap", "dark_hole", ext([x, 0, z + L / 2 + 0.01], [[-w * 0.3, 0], [w * 0.3, 0], [0, h * 0.75]], 0.02),
              "prop", priority=2)


def campfire(p, P, gx, gy, name="fire"):
    x, _, z = P.m(gx, gy)
    for k in range(8):
        a = k * math.pi / 4
        p.add(name + "_ring", "stone", ell([x + 0.32 * math.cos(a), 0.06, z + 0.32 * math.sin(a)], [0.09, 0.07, 0.08]), "prop")
    for k in range(3):
        a = k * math.pi / 3
        p.add(name + "_logs", "log_bark", cyl([x - 0.22 * math.cos(a), 0.06, z - 0.22 * math.sin(a)],
                                               [x + 0.22 * math.cos(a), 0.1, z + 0.22 * math.sin(a)], 0.045), "prop")
    p.add(name + "_flame", "flame", cone([x, 0.08, z], [x, 0.42, z], 0.14, 0.0), "prop")
    for k in range(3):        # a tripod with a pot
        a = k * 2 * math.pi / 3
        p.add(name + "_tripod", "post", cyl([x + 0.38 * math.cos(a), 0, z + 0.38 * math.sin(a)], [x, 0.85, z], 0.022), "prop",
              priority=2)
    p.add(name + "_chain", "iron", cyl([x, 0.85, z], [x, 0.6, z], 0.012), "prop", min_cover=1)
    p.add(name + "_pot", "iron", ell([x, 0.5, z], [0.14, 0.11, 0.14]), "prop")
    W.K.wisp(p, [x, 0.95, z], 0.9, seed=3)


# =================================================================================================
# Pioneer camp (3x3): the first settlers' camp: a new log cabin with a bark-shingled roof and a stone
# chimney, two canvas tents, a covered settlers' wagon, a campfire with a pot on a tripod, the
# kingdom's banner on a pole, crates, barrels, sacks, a log pile and an axe in a stump.
# =================================================================================================
def pioneer_camp():
    P, p = Plot(3), Parts()
    K.ground(P, p, seed=45)
    K.patch(p, "grass_a", "grass", P, 0.4, 0.4, 0.4, 0.4)
    K.patch(p, "grass_b", "grass", P, 2.7, 2.6, 0.3, 0.35)
    cabin = (0.95, 2.15, 0.2, 1.55)
    p.footprints = [cabin]
    K.plinth(p, P, "plinth", cabin, h=0.16, mat="fieldstone")
    K.log_walls(p, P, "walls", cabin, 0.16, 1.5, course=0.19)
    g = Gable(P, "cabin", cabin, "gy", 1.5, 2.75, over=0.24, end_over=0.2)
    g.infill(p, "log")
    p.paint("cabin_gable", "log_groove", stripes={"axis": "y", "period": 0.19, "width": 0.055})
    g.roof(p, "shingle", "shingle_dark", course=0.15, spots=("moss", 0.1, 0.15, 2))
    g.bargeboards(p)
    p.roofs = [g]
    x0, x1, z0, z1 = P.rect(*cabin)
    K.door_left(p, P, "door", 1.5, x0, 0.16, w=0.48, h=0.95, arch=False)
    K.window_right(p, P, 0.85, z1, 0.85, w=0.28, h=0.3)
    K.chimney(p, P, "chimney", 2.0, 0.55, 1.2, 3.1, w=0.17, mat="fieldstone", cap="stone")
    p["chimney"]["paint"] = [{"material": "stone_dark", "spots": {"scale": 0.07, "density": 0.4, "seed": 5}}]
    W.K.wisp(p, P.m(2.0, 0.55, 3.2), 0.9, seed=7, name="chimney_smoke")
    tent(p, P, 0.45, 0.65, along="gx", L=1.15, w=1.0, h=1.15)
    tent(p, P, 0.42, 1.75, along="gy", L=1.05, w=0.95, h=1.1, mat="canvas_white", name="tent_b")
    campfire(p, P, 0.55, 2.45)
    bench(p, P, (0.15, 2.05), (0.15, 2.75), name="log_bench", h=0.25)
    # a covered settlers' wagon
    K.cart(p, P, 2.5, 2.3, yaw=0.3)
    cx, _, cz = P.m(2.5, 2.3)
    p.add("wagon_canvas", "canvas_white", ell([cx, 0.95, cz], [0.62, 0.42, 0.42], rot=[0, -0.3, 0]), "prop")
    p.cut("wagon_canvas", box([cx, 0.45, cz], [0.8, 0.5, 0.6]))
    # the banner on a pole
    x, _, z = P.m(2.7, 0.3)
    p.add("flagpole", "post", cyl([x, 0, z], [x, 3.0, z], 0.04), "prop")
    p.add("flag", "cloth_red", ext([x, 2.95, z + 0.03], [[0, 0], [0.7, -0.05], [0.6, -0.25], [0.7, -0.45], [0, -0.45]], 0.02,
                                   rot=[0, 0.4, 0]), "prop")
    p.add("flag_charge", "gilt", sph([x + 0.25, 2.72, z + 0.05], 0.07), "prop", priority=2)
    # supplies, logs, an axe
    K.crate(p, P, 2.55, 1.85, s=0.2)
    K.crate(p, P, 2.75, 1.65, s=0.18, rot=0.5)
    K.barrel(p, P, 2.75, 1.25, r=0.17, h=0.46)
    K.sack(p, P, 2.45, 1.4, s=0.15)
    K.sack(p, P, 2.5, 1.62, s=0.14)
    for i in range(3):
        K.log(p, P, (1.2, 1.75 + i * 0.12), (2.0, 1.75 + i * 0.12), 0.1, "logpile", y=0.1 + (0.17 if i == 1 else 0))
    K.stump(p, P, 0.95, 2.15, r=0.18, h=0.3)
    K.axe_in(p, P, 0.95, 2.15, 0.32, yaw=0.6)
    K.tufts(p, P, [(2.95, 0.9), (0.05, 2.95), (1.5, 0.05)])
    p.heap = (2.0, 2.6)
    return P, p, 320, 2.6


def stall(p, P, gx0, gx1, gy, canvas, goods, name, facing="+y", depth=0.5):
    """A market stall: a counter (facing +y: along game x at game y gy, the stallholder behind it at
    smaller y; facing +x: along game y, gx0/gx1 read as gy0/gy1 and gy as gx) with posts and a striped
    awning sloping to the customers, goods on the counter."""
    if facing == "+y":
        a, b = P.m(gx0, gy), P.m(gx1, gy)
        back = P.m(gx0, gy - depth)
        cx, cz, L = (a[0] + b[0]) / 2, a[2], abs(b[2] - a[2]) / 2
        bx = back[0]
        p.add(name + "_counter", "board", box([cx, 0.62, (a[2] + b[2]) / 2], [0.16, 0.04, L]), "prop")
        p.add(name + "_front", "plank", box([cx - 0.12, 0.31, (a[2] + b[2]) / 2], [0.03, 0.3, L]), "prop")
        p.paint(name + "_front", "ink", stripes={"axis": "z", "period": 0.15, "width": 0.055})
        for zz in (a[2], b[2]):
            for xx, hh in ((cx - 0.1, 1.45), (bx, 1.75)):
                p.add(name + "_posts", "post", cyl([xx, 0, zz], [xx, hh, zz], 0.035), "prop")
        ang = math.atan2(1.75 - 1.4, bx - cx + 0.3)
        Lr = math.hypot(bx - cx + 0.35, 0.35) / 2
        p.add(name + "_awning", canvas, box([(bx + cx - 0.35) / 2, 1.6, (a[2] + b[2]) / 2], [Lr, 0.025, L + 0.08],
                                            rot=[0, 0, ang]), "prop")
        p.paint(name + "_awning", "canvas_white", stripes={"axis": "z", "period": 0.3, "width": 0.15})
        p.add(name + "_valance", canvas, box([cx - 0.36, 1.36, (a[2] + b[2]) / 2], [0.015, 0.08, L + 0.08]), "prop")
        for i in range(len(goods)):
            t = (i + 0.5) / len(goods)
            goods[i](p, [cx, 0.66, a[2] + (b[2] - a[2]) * t])
    else:
        a, b = P.m(gy, gx0), P.m(gy, gx1)
        back = P.m(gy - depth, gx0)
        cz, L = a[2], abs(b[0] - a[0]) / 2
        cx = (a[0] + b[0]) / 2
        bz = back[2]
        p.add(name + "_counter", "board", box([cx, 0.62, cz], [L, 0.04, 0.16]), "prop")
        p.add(name + "_front", "plank", box([cx, 0.31, cz + 0.12], [L, 0.3, 0.03]), "prop")
        p.paint(name + "_front", "ink", stripes={"axis": "x", "period": 0.15, "width": 0.055})
        for xx in (a[0], b[0]):
            for zz, hh in ((cz + 0.1, 1.45), (bz, 1.75)):
                p.add(name + "_posts", "post", cyl([xx, 0, zz], [xx, hh, zz], 0.035), "prop")
        ang = math.atan2(1.75 - 1.4, cz - bz + 0.3)
        Lr = math.hypot(cz - bz + 0.35, 0.35) / 2
        p.add(name + "_awning", canvas, box([cx, 1.6, (bz + cz + 0.35) / 2], [L + 0.08, 0.025, Lr], rot=[ang, 0, 0]), "prop")
        p.paint(name + "_awning", "canvas_white", stripes={"axis": "x", "period": 0.3, "width": 0.15})
        p.add(name + "_valance", canvas, box([cx, 1.36, cz + 0.36], [L + 0.08, 0.08, 0.015]), "prop")
        for i in range(len(goods)):
            t = (i + 0.5) / len(goods)
            goods[i](p, [a[0] + (b[0] - a[0]) * t, 0.66, cz])


def g_apples(p, c):
    x, y, z = c
    p.add("basket", "wicker", cyl([x, y, z], [x, y + 0.12, z], 0.15), "prop")
    for k in range(5):
        a = k * 1.25
        p.add("apples", "apple", sph([x + 0.07 * math.cos(a), y + 0.15, z + 0.07 * math.sin(a)], 0.055), "prop")


def g_bread(p, c):
    x, y, z = c
    for k in range(3):
        p.add("loaves", "bread", ell([x, y + 0.06, z - 0.15 + k * 0.15], [0.09, 0.06, 0.07]), "prop")


def g_fish(p, c):
    x, y, z = c
    p.add("fish_tray", "board", box([x, y + 0.02, z], [0.12, 0.02, 0.2]), "prop")
    for k in range(3):
        p.add("fish", "fish", ell([x, y + 0.06, z - 0.12 + k * 0.12], [0.1, 0.035, 0.045]), "prop")


def g_cloth(p, c):
    x, y, z = c
    for k, mat in enumerate(("cloth_red", "cloth_blue", "cloth_green")):
        p.add("cloth_" + mat, mat, box([x, y + 0.03 + 0.06 * k, z], [0.1, 0.03, 0.14]), "prop")


def g_cabbage(p, c):
    x, y, z = c
    for k in range(3):
        p.add("cabbages", "cabbage", sph([x + 0.04 * (k % 2), y + 0.09, z - 0.12 + k * 0.12], 0.09), "prop")


def g_jugs(p, c):
    x, y, z = c
    for k in range(2):
        zz = z - 0.08 + k * 0.16
        p.add("jugs", "clay", ell([x, y + 0.12, zz], [0.08, 0.12, 0.08]), "prop")
        p.add("jugs", "clay", cyl([x, y + 0.22, zz], [x, y + 0.3, zz], 0.035), "prop")


# =================================================================================================
# Market (3x3): a cobbled square with three stalls under striped awnings (red: apples and cabbages,
# by the entrance where a stallholder stands; blue: bread and jugs; yellow: fish and cloth), a stone
# market cross on stepped base in the middle, baskets, barrels and a hand cart with sacks.
# =================================================================================================
def market():
    P, p = Plot(3), Parts()
    K.ground(P, p, mat="cobble_ground", seed=47)
    stall(p, P, 0.45, 1.5, 2.55, "canvas_red", [g_apples, g_cabbage, g_apples], "stall_a", depth=0.45)
    stall(p, P, 0.3, 1.45, 0.75, "canvas_blue", [g_bread, g_jugs, g_bread], "stall_b")
    stall(p, P, 0.6, 1.8, 2.65, "canvas_yellow", [g_fish, g_cloth, g_fish], "stall_c", facing="+x")
    # market cross on a stepped base
    x, _, z = P.m(1.75, 1.45)
    for i, (r, h) in enumerate(((0.55, 0.14), (0.42, 0.28), (0.3, 0.42))):
        p.add("cross_steps", "ashlar_light" if i % 2 else "ashlar", box([x, h / 2, z], [r, h / 2, r]), "wall")
    p.add("cross_shaft", "ashlar", box([x, 1.35, z], [0.09, 0.95, 0.09]), "wall")
    p.add("cross_head", "ashlar_light", box([x, 2.35, z], [0.07, 0.25, 0.07]), "wall")
    p.add("cross_head", "ashlar_light", box([x, 2.42, z], [0.22, 0.06, 0.07]), "wall")
    p.add("cross_head", "ashlar_light", box([x, 2.42, z], [0.07, 0.06, 0.22]), "wall")
    p.add("cross_cap", "ashlar_light", box([x, 2.22, z], [0.14, 0.04, 0.14]), "wall")
    # baskets, barrels, a hand cart with sacks
    for gx, gy in ((0.25, 2.25), (0.3, 1.95)):
        x, _, z = P.m(gx, gy)
        p.add("baskets", "wicker", cyl([x, 0, z], [x, 0.3, z], 0.17), "prop")
        p.add("basket_fill", "apple", sph([x, 0.3, z], 0.13), "prop")
    K.barrel(p, P, 2.75, 0.3, r=0.18, h=0.5)
    K.barrel(p, P, 2.45, 0.25, r=0.16, h=0.44)
    K.wheelbarrow(p, P, 2.3, 2.6, yaw=0.9)
    K.sack(p, P, 2.3, 2.6, s=0.12, y0=0.45)
    K.crate(p, P, 0.2, 1.35, s=0.18)
    K.crate(p, P, 0.2, 1.35, s=0.14, y0=0.36, rot=0.6)
    K.tufts(p, P, [(2.95, 2.95), (0.05, 0.05), (2.95, 0.05)])
    p.spots = {"stall": (1.0, 2.25)}
    p.footprints = [(0.3, 2.7, 0.4, 2.7)]
    p.roofs = []
    p.heap = (2.2, 1.8)
    return P, p, 320, 1.9


# =================================================================================================
# Warehouse shed (4x4, the stockpile): a tall open lean-to shed along the two back edges of the
# yard, board walls behind and stout posts with knee braces in front, a shingled roof falling
# towards the yard; a hoist beam with a block and rope, a ladder, a lantern. Only the shed: the
# game draws the timber deck and the goods stacks under it (StockpileView).
# =================================================================================================
def stockpile():
    P, p = Plot(4), Parts()
    K.ground(P, p, seed=49)          # only in the construction stages (removed from the pieces)
    back_row = (0.04, 3.96, 0.04, 1.0)
    back_col = (0.04, 1.0, 1.0, 3.96)
    p.footprints = [(0.04, 3.96, 0.04, 3.96)]
    K.board_walls(p, P, "shed_a_wall", (0.04, 3.96, 0.04, 0.12), 0.0, 3.0)
    K.board_walls(p, P, "shed_b_wall", (0.04, 0.12, 0.04, 3.96), 0.0, 3.0)
    K.lean_to(p, P, "shed_a_roof", back_row, "-gy", 2.35, 3.05, "shingle", "shingle_dark", over=0.18, posts=False)
    K.lean_to(p, P, "shed_b_roof", back_col, "-gx", 2.35, 3.05, "shingle", "shingle_dark", over=0.18, posts=False)
    # posts and a wall plate along the front edges of the shed (few: the stacks stand behind them)
    for gx in (1.0, 2.48, 3.94):
        x, _, z = P.m(gx, 1.0)
        p.add("posts_a", "post", box([x, 1.18, z], [0.07, 1.18, 0.07]), "wall")
    for gy in (2.48, 3.94):
        x, _, z = P.m(1.0, gy)
        p.add("posts_b", "post", box([x, 1.18, z], [0.07, 1.18, 0.07]), "wall")
    a, b = P.m(1.0, 1.0, 2.33), P.m(3.96, 1.0, 2.33)
    p.add("plates_a", "timber", box([(a[0] + b[0]) / 2, 2.33, a[2]], [abs(b[0] - a[0]) / 2 + 0.08, 0.07, 0.08]), "wall")
    a, b = P.m(1.0, 1.0, 2.33), P.m(1.0, 3.96, 2.33)
    p.add("plates_b", "timber", box([a[0], 2.33, (a[2] + b[2]) / 2], [0.08, 0.07, abs(b[2] - a[2]) / 2 + 0.08]), "wall")
    # a hoist beam with a block and a short rope at the corner
    x, _, z = P.m(1.0, 1.0)
    p.add("hoist", "timber", box([x - 0.3, 2.9, z + 0.3], [0.06, 0.06, 0.45], rot=[0, 0.785, 0]), "roof")
    p.add("hoist_block", "iron", sph([x - 0.6, 2.8, z + 0.6], 0.07), "roof")
    p.add("hoist_rope", "rope", cyl([x - 0.6, 2.75, z + 0.6], [x - 0.6, 2.2, z + 0.6], 0.015), "roof", min_cover=1)
    p.add("hoist_hook", "iron", tor([x - 0.6, 2.15, z + 0.6], 0.05, 0.015), "roof")
    p.roofs = []
    p.heap = (2.5, 2.5)
    # The shed is drawn as four pieces, each sorted on its own footprint (in tiles from the yard's
    # origin), so the goods stacks of the yard sort between them: the back walls behind every
    # stack (footprints just outside the yard), the posts and roofs in front of the back row only.
    p.pieces = {
        "shed_a_back": ((0, -1), (4, 1), ["shed_a_wall"]),
        "shed_b_back": ((-1, 0), (1, 4), ["shed_b_wall"]),
        "shed_a_front": ((0, 0), (4, 1), ["shed_a_roof", "shed_a_roof_posts", "posts_a", "plates_a", "plates_b", "hoist",
                                          "hoist_block", "hoist_rope", "hoist_hook"]),
        "shed_b_front": ((0, 1), (1, 3), ["shed_b_roof", "shed_b_roof_posts", "posts_b"]),
    }
    return P, p, 448, 3.0

BUILDINGS = {
    "well": (well, "Your Kingdom well (G3 part 4b), 1x1 tile: a round fieldstone shaft with a stone coping under a "
             "little shingled roof on two posts, a windlass with a crank, a rope and a bucket, a stone trough"),
    "chapel": (chapel, "Your Kingdom chapel (G3 part 4b), 2x2 tiles: a fieldstone nave with quoins under steep slate, "
               "a pointed portal and a round window in the street gable, a timber bell-cote with a bell and a spire, "
               "lancets and buttresses, a wayside cross, a bench, flowers"),
    "church": (church, "Your Kingdom church (G3 part 4b), 3x3 tiles: an ashlar nave under steep slate with a west front "
               "(deep pointed portal, rose window, pinnacles), buttresses and tall lancets, a square tower with belfry "
               "louvres, a clock and a tall spire with a gilt ball; a churchyard with graves and a yew"),
    "tavern": (tavern, "Your Kingdom tavern (G3 part 4b), 2x2 tiles: a two-storey inn, fieldstone below and jettied "
               "half-timbering above under red tiles, a dormer, a big chimney, an ale stake with a bush, a tankard sign, "
               "a serving counter with casks, a table with benches and mugs, barrels"),
    "builders_hut": (builders_hut, "Your Kingdom builders' hut (G3 part 4b), 2x2 tiles: a half-timbered carpenter's lodge "
                     "under shingles, a lean-to stacked with beams, a sawhorse with a beam, a ladder, scaffold poles, "
                     "planks, a wheelbarrow with stones, a plumb line"),
}
BUILDINGS.update({
    "town_hall": (town_hall, "Your Kingdom town hall (G3 part 4b), 4x4 tiles: an ashlar arcade to the square, a brick upper "
                  "floor with tall stone-framed windows under a steep copper roof with dormers and a stepped gable, a "
                  "clock tower over the gate with a coat of arms, clocks, an open belfry and a copper spire, banners"),
    "trading_post": (trading_post, "Your Kingdom trading post (G3 part 4b), 3x3 tiles: a merchant's counting house, "
                     "fieldstone and ochre half-timbering under red tiles, a loft door with a hoist and a bale, a wide "
                     "double door with a balance sign, a great beam balance, a covered trade wagon, crates, cloth, barrels"),
    "pioneer_camp": (pioneer_camp, "Your Kingdom pioneer camp (G3 part 4b), 3x3 tiles: a new log cabin under shingles "
                     "with a stone chimney, two canvas tents, a covered wagon, a campfire with a pot on a tripod, the "
                     "kingdom's banner, supplies, logs, an axe in a stump"),
    "market": (market, "Your Kingdom market (G3 part 4b), 3x3 tiles: a cobbled square with three stalls under striped "
               "awnings (apples and cabbages, bread and jugs, fish and cloth), a stone market cross on steps, baskets, "
               "barrels, a wheelbarrow"),
    "stockpile": (stockpile, "Your Kingdom warehouse shed (G3 part 4b), 4x4 tiles: a tall open lean-to shed along the "
                  "two back edges, board walls, posts with knee braces, a shingled roof, a hoist; the game draws the deck "
                  "and the goods stacks"),
})
ENTRANCES = {"well": (0, 0), "church": (1, 2), "market": (1, 2), "town_hall": (1, 3), "trading_post": (1, 2),
             "pioneer_camp": (1, 2), "stockpile": (1, 3)}


def main():
    only = [a for a in sys.argv[1:] if not a.startswith("-")]
    W.ENTRANCES.update(ENTRANCES)
    for bid, (fn, summary) in BUILDINGS.items():
        if only and bid not in only:
            continue
        P, parts, size, cy = fn()
        s = head(bid, size, cy, summary)
        s["parts"] = dict(parts)
        s["animations"] = {"idle": {"frames": 1, "ms": 500, "channels": {}}}
        n = W.write(bid, s)
        for piece, (_off, _fp, names) in getattr(parts, "pieces", {}).items():
            sp = head(f"{bid}_{piece}", size, cy, summary + f" (piece {piece})")
            sp["parts"] = {k: v for k, v in parts.items() if k in names}
            sp["animations"] = s["animations"]
            W.write(bid, sp)
            with open(os.path.join(HERE, "art", "specs", "props", bid, "pieces.json"), "w") as fh:
                json.dump({k: {"offset": v[0], "footprint": v[1]} for k, v in parts.pieces.items()}, fh)
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
