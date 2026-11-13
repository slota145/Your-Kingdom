"""G3 part 4a: the hut (house level 1) from SpriteKiln (ROADMAP G3, "Część 4, plan").

Three looks, each designed anew (owner's survey 2026-11-13: very detailed and clearly medieval):
  1  a log cottage under a steep hipped thatch, a clay chimney, a wattle-fenced cabbage patch,
  2  a whitewashed half-timbered cottage under red tiles with a dormer and a woodshed lean-to,
  3  a fieldstone cottage with quoins under mossy shingles, its gable to the street, an outside
     stone chimney and a pentice over the door.
Every look also has a back view (`_back`: the house turned with its door away from the camera,
the game shows it for orientations 2 and 3): the same house with no door on the visible faces.
The construction stages (shared by the three looks, as before) come from look 2; the upgrade
scaffold (drawn over a house while it becomes a burgher house) is a separate model.

Plot (2x2, entrance (1, 1), door side +x): the house fills most of the plot, its door in the
right face (game x ~1.5) at game y ~1.3, so the door looks at the tile in front of the entrance.

Writes art/specs/props/hut/<name>.yaml (hut, hut_2, hut_3, hut_back, hut_2_back, hut_3_back,
hut_c1, hut_c2, hut_back_c1, hut_back_c2, hut_scaffold); edit this script.
Run (inside tools/spritekiln):  python3 gen_homes.py && tools/spritekiln/build_homes.sh
"""
import os
import sys

import workshop_kit as K
from workshop_kit import Gable, Parts, Plot, box, cone, cyl, ell, sph, tor
from gen_workshops import head, stage, write

HERE = os.path.dirname(os.path.abspath(__file__))
SIZE, CY = 192, 1.6


def cabbages(p, P, pts, name="cabbages"):
    for i, (gx, gy) in enumerate(pts):
        x, _, z = P.m(gx, gy)
        r = 0.12 + 0.02 * (i % 2)
        p.add(name, "hop_green", ell([x, r * 0.7, z], [r, r * 0.75, r]), "prop")
        p.add(name + "_leaves", "leaves", ell([x, r * 0.35, z], [r * 1.45, r * 0.3, r * 1.45]), "prop")


def flowers(p, P, pts, name="flowers"):
    for i, (gx, gy) in enumerate(pts):
        x, _, z = P.m(gx, gy)
        p.add(name + "_stems", "leaves", ell([x, 0.12, z], [0.1, 0.13, 0.1]), "prop")
        p.add(name, "bloom" if i % 2 else "paint_red", sph([x + 0.03, 0.24, z - 0.02], 0.055), "prop")


def bench_right(p, P, gy0, gy1, z, name="bench"):
    """A plank bench against a right face (plane z) between game y gy0 and gy1."""
    xa, xb = P.m(0, gy0)[0], P.m(0, gy1)[0]
    xc, L = (xa + xb) / 2, abs(xa - xb) / 2
    p.add(name, "board", box([xc, 0.4, z + 0.2], [L, 0.035, 0.12]), "prop")
    for s in (-1, 1):
        p.add(name + "_legs", "post", box([xc + s * (L - 0.07), 0.2, z + 0.2], [0.04, 0.2, 0.1]), "prop")


def pitchfork(p, P, gx, gy, z_off=0.0, name="fork"):
    x, _, z = P.m(gx, gy)
    p.add(name, "haft", cyl([x, 0.05, z + z_off], [x + 0.08, 1.2, z + z_off - 0.12], 0.025), "prop", priority=2, min_cover=2)
    for dx in (-0.05, 0.0, 0.05):
        p.add(name + "_tines", "iron", cyl([x + 0.08 + dx, 1.2, z + z_off - 0.12], [x + 0.08 + dx * 1.4, 1.42, z + z_off - 0.14],
                                           0.014), "prop", priority=2, min_cover=1)


def hens(p, P, pts, name="hens"):
    for i, (gx, gy) in enumerate(pts):
        x, _, z = P.m(gx, gy)
        mat = "bone" if i % 2 else "split"
        p.add(name + "_" + mat, mat, ell([x, 0.14, z], [0.1, 0.08, 0.07]), "prop")
        p.add(name + "_" + mat, mat, sph([x + 0.08, 0.24, z + 0.02], 0.045), "prop")
        p.add(name + "_combs", "paint_red", sph([x + 0.09, 0.29, z + 0.02], 0.022), "prop", min_cover=1)


# =================================================================================================
# Look 1: a log cottage under a steep hipped thatch with moss, a clay-daubed chimney through the
# ridge, a bench by the door, firewood stacked under the eaves of the front gable end, a rain
# barrel, a wattle-fenced cabbage patch and hens.
# =================================================================================================
def hut_1(back=False):
    P, p = Plot(2), Parts()
    K.ground(P, p, seed=21)
    K.patch(p, "grass_patch", "grass", P, 1.75, 0.35, 0.28, 0.3)
    K.patch(p, "grass_patch", "grass", P, 0.4, 1.95, 0.3, 0.05)
    house = (0.16, 1.5, 0.18, 1.76)
    p.footprints = [house]
    K.plinth(p, P, "plinth", house, h=0.22, mat="fieldstone")
    K.log_walls(p, P, "walls", house, 0.22, 1.74, course=0.19)
    K.hip_roof(p, P, "roof", house, 1.72, 3.4, "thatch", "thatch_dark", over=0.28, course=0.15,
               spots=("moss", 0.1, 0.2, 7 + back))
    # A clay-daubed chimney with a stone cap through the ridge.
    K.chimney(p, P, "chimney", 0.62, 0.75, 2.5, 3.85, w=0.17, mat="clay_light", cap="stone")
    p["chimney"]["paint"] = [{"material": "clay_dark", "spots": {"scale": 0.06, "density": 0.3, "seed": 2}}]
    x0, x1, z0, z1 = P.rect(*house)
    # Right face: the door (or, from the back, a second window), a window with a flower box.
    if back:
        K.window_right(p, P, 1.3, z1, 0.95, w=0.3, h=0.34, open_=False)
        K.window_right(p, P, 0.55, z1, 0.95, w=0.3, h=0.34)
        bench_right(p, P, 0.85, 1.12, z1)
    else:
        K.door_right(p, P, "door", 1.3, z1, 0.22, w=0.5, h=0.98, arch=False)
        K.window_right(p, P, 0.55, z1, 0.95, w=0.3, h=0.34, box_=True)
        bench_right(p, P, 0.78, 1.08, z1)
        # A horseshoe over the door for luck.
        xd = P.m(0, 1.3)[0]
        p.add("horseshoe", "iron", tor([xd, 1.38, z1 + 0.06], 0.07, 0.018, rot=[1.5708, 0, 0]), "wall", priority=2)
    # Left face (the hipped end): a small window, firewood stacked under the eaves.
    K.window_left(p, P, 0.62, x0, 1.0, w=0.28, h=0.3)
    K.woodpile(p, P, "firewood", 0.95, 1.45, 1.9, 4, r=0.09, along="gx")
    # A rain barrel at the front corner, a pitchfork against the wall.
    K.barrel(p, P, 1.66, 1.88, r=0.17, h=0.46)
    p.add("barrel_water", "water", cyl(P.m(1.66, 1.88, 0.44), P.m(1.66, 1.88, 0.46), 0.15), "prop")
    pitchfork(p, P, 1.56, 1.62, z_off=0.05)
    # The cabbage patch behind a wattle fence on the right strip, hens by the door.
    K.fence(p, P, [(1.56, 0.06), (1.96, 0.06), (1.96, 0.66), (1.56, 0.66)], name="garden_fence", h=0.38, mat="post",
            wattle=True)
    p.add("garden_soil", "soil", box(P.m(1.76, 0.36, 0.02), [0.3 * K.T * 0.95, 0.02, 0.2 * K.T * 0.95]), "ground")
    cabbages(p, P, [(1.66, 0.18), (1.66, 0.4), (1.86, 0.28), (1.86, 0.5), (1.68, 0.56)])
    hens(p, P, [(1.82, 1.15), (1.9, 0.95)] if not back else [(1.85, 1.3)])
    K.tufts(p, P, [(1.95, 1.95), (0.05, 1.95), (1.98, 0.8), (0.1, 0.06)])
    p.heap = (1.82, 1.2)
    return P, p


# =================================================================================================
# Look 2: a whitewashed half-timbered cottage on a stone plinth under red tiles, the timbered gable
# to the front with crossed bargeboards, a dormer, a brick chimney; a woodshed lean-to with
# firewood, a flower bed, a bench and a bucket by the door.
# =================================================================================================
def hut_2(back=False):
    P, p = Plot(2), Parts()
    K.ground(P, p, seed=23)
    K.patch(p, "grass_patch", "grass", P, 1.8, 1.7, 0.2, 0.25)
    K.patch(p, "grass_patch", "grass", P, 0.3, 1.94, 0.25, 0.05)
    house = (0.16, 1.46, 0.18, 1.74)
    p.footprints = [house]
    K.plinth(p, P, "plinth", house, h=0.22)
    K.walls(p, P, "walls", house, 0.22, 1.72, "plaster")
    K.timber_left(p, P, "frame_l", house, 0.22, 1.72, 3)
    K.timber_right(p, P, "frame_r", house, 0.22, 1.72, 4)
    g = Gable(P, "house", house, "gy", 1.72, 3.2, over=0.3, end_over=0.24)
    g.infill(p, "plaster")
    g.gable_frame(p)
    g.roof(p, "tile", "tile_dark", course=0.13, spots=("moss", 0.08, 0.1, 5 + back))
    g.bargeboards(p)
    p.roofs = [g]
    K.dormer(p, P, g, "dormer", 0.62, roof_mat="tile", dark="tile_dark")
    K.chimney(p, P, "chimney", 0.5, 1.25, 2.4, 3.6, w=0.16)
    x0, x1, z0, z1 = P.rect(*house)
    if back:
        K.window_right(p, P, 1.32, z1, 1.0, w=0.3, h=0.36)
        K.window_right(p, P, 0.55, z1, 1.0, w=0.3, h=0.36, box_=True)
        K.barrel(p, P, 1.62, 1.3, r=0.16, h=0.44)
    else:
        K.door_right(p, P, "door", 1.32, z1, 0.22, w=0.5, h=1.0, arch=True)
        K.window_right(p, P, 0.55, z1, 1.0, w=0.3, h=0.36, box_=True)
        K.lantern(p, P, 1.08, z1, 1.45)
        K.bucket(p, P, 1.62, 1.62, fill="water")
    bench_right(p, P, 0.82, 1.08, z1)
    K.window_left(p, P, 0.5, x0, 1.0, w=0.28, h=0.34)
    K.window_left(p, P, 1.08, x0, 1.0, w=0.28, h=0.34)
    K.window_left(p, P, 0.81, x0 - 0.02, 2.3, w=0.24, h=0.3, shutters=False)
    # A woodshed lean-to against the back of the right strip.
    shed = (1.5, 1.94, 0.08, 0.66)
    K.lean_to(p, P, "shed_roof", shed, "-gy", 1.05, 1.4, "shingle", "shingle_dark", over=0.08)
    K.woodpile(p, P, "firewood", 0.12, 0.6, 1.72, 4, r=0.09, along="gy")
    K.stump(p, P, 1.8, 0.88, r=0.16, h=0.26)
    K.axe_in(p, P, 1.8, 0.88, 0.28, yaw=-0.6, tilt=0.5)
    # A flower bed and a little picket fence before the gable end.
    a, b = P.m(0.3, 1.88), P.m(1.3, 1.88)
    p.add("bed", "soil", box([(a[0] + b[0]) / 2, 0.03, (a[2] + b[2]) / 2], [0.12, 0.03, abs(b[2] - a[2]) / 2]), "ground")
    flowers(p, P, [(0.4, 1.88), (0.62, 1.88), (0.84, 1.88), (1.06, 1.88), (1.24, 1.88)])
    K.fence(p, P, [(0.2, 1.98), (1.42, 1.98)], name="picket", h=0.32, mat="post")
    hens(p, P, [(1.88, 1.9)])
    K.tufts(p, P, [(1.97, 1.45), (0.06, 1.96), (1.6, 1.98)])
    p.heap = (1.8, 1.2)
    return P, p


# =================================================================================================
# Look 3: a fieldstone cottage with dressed quoins under mossy shingles, its boarded gable to the
# street (the right face) with a shingled pentice over the door, a big outside stone chimney on
# the long wall, a beehive skep on a stand, a cart wheel leaning, a fenced garden with beans.
# =================================================================================================
def hut_3(back=False):
    P, p = Plot(2), Parts()
    K.ground(P, p, seed=25)
    K.patch(p, "grass_patch", "grass", P, 0.3, 1.9, 0.3, 0.1)
    K.patch(p, "grass_patch", "grass", P, 1.8, 0.4, 0.2, 0.35)
    house = (0.14, 1.52, 0.22, 1.7)
    p.footprints = [house]
    K.plinth(p, P, "plinth", house, h=0.2, mat="fieldstone")
    K.walls(p, P, "walls", house, 0.2, 1.62, "fieldstone")
    p.paint("walls", "stone_dark", spots={"scale": 0.07, "density": 0.4, "seed": 13})
    K.quoins(p, P, "quoins", house, 0.2, 1.62)
    g = Gable(P, "house", house, "gx", 1.62, 3.15, over=0.3, end_over=0.26)
    g.infill(p, "board")
    p.paint("house_gable", "ink", stripes={"axis": "x", "period": 0.17, "width": 0.04})
    g.roof(p, "shingle", "shingle_dark", course=0.13, spots=("moss", 0.1, 0.22, 3 + back))
    g.bargeboards(p)
    p.roofs = [g]
    x0, x1, z0, z1 = P.rect(*house)
    # A gable window with a shutter, the door under a pentice (front) or a window (back).
    K.window_right(p, P, 0.96, z1 + 0.02, 2.15, w=0.26, h=0.3, shutters=False)
    if back:
        K.window_right(p, P, 1.25, z1, 0.95, w=0.3, h=0.34, open_=False)
        K.window_right(p, P, 0.6, z1, 0.95, w=0.3, h=0.34)
        K.woodpile(p, P, "firewood", 0.95, 1.45, 1.66, 3, r=0.09, along="gy")
    else:
        K.door_right(p, P, "door", 1.3, z1, 0.2, w=0.5, h=1.0, arch=True, frame="sill_mat")
        K.window_right(p, P, 0.6, z1, 0.95, w=0.3, h=0.34, box_=True)
        xd = P.m(0, 1.3)[0]
        p.add("pentice", "shingle", box([xd, 1.62, z1 + 0.22], [0.42, 0.04, 0.26], rot=[0.4, 0, 0]), "roof")
        p.paint("pentice", "shingle_dark", stripes={"axis": "y", "period": 0.08, "width": 0.03})
        for s in (-1, 1):
            p.add("pentice_brackets", "timber", box([xd + s * 0.36, 1.48, z1 + 0.14], [0.03, 0.03, 0.16], rot=[-0.7, 0, 0]), "wall")
    # Left face (the long wall): two shuttered windows and a big outside chimney.
    K.window_left(p, P, 0.5, x0, 1.0, w=0.28, h=0.34)
    xc, _, zc = P.m(0.95, 1.7)
    p.add("chimney", "fieldstone", box([xc - 0.18, 0.75, zc], [0.18, 0.75, 0.34]), "wall")
    p.add("chimney", "fieldstone", cone([xc - 0.16, 1.5, zc], [xc - 0.13, 1.85, zc], 0.3, 0.17), "wall")
    p.add("chimney", "fieldstone", box([xc - 0.13, 2.45, zc], [0.13, 0.62, 0.17]), "wall")
    p.paint("chimney", "stone_dark", spots={"scale": 0.07, "density": 0.4, "seed": 17})
    p.add("chimney_cap", "stone", box([xc - 0.13, 3.1, zc], [0.17, 0.04, 0.21]), "roof")
    p.add("chimney_soot", "soot", box([xc - 0.13, 3.15, zc], [0.08, 0.02, 0.1]), "roof")
    # A beehive skep on a little stand, a cart wheel leaning on the wall, a garden with bean poles.
    x, _, z = P.m(0.45, 1.9)
    p.add("skep_stand", "post", box([x, 0.22, z], [0.15, 0.03, 0.15]), "prop")
    for s in (-1, 1):
        p.add("skep_stand", "post", cyl([x + s * 0.1, 0, z], [x + s * 0.1, 0.22, z], 0.03), "prop")
    p.add("skep", "thatch", cone([x, 0.25, z], [x, 0.6, z], 0.15, 0.05), "prop")
    p.paint("skep", "thatch_dark", stripes={"axis": "y", "period": 0.06, "width": 0.02})
    p.add("skep_hole", "dark_hole", sph([x - 0.12, 0.3, z + 0.05], 0.03), "prop")
    wx, _, wz = P.m(1.56, 0.42)
    p.add("wheel", "post", tor([wx, 0.4, wz + 0.04], 0.32, 0.04, rot=[1.5708, 0, 0.2]), "prop")
    p.add("wheel_hub", "iron", cyl([wx, 0.4, wz], [wx, 0.4, wz + 0.1], 0.06), "prop")
    for k in range(4):
        import math
        a = k * math.pi / 4
        p.add("wheel_spokes", "post", cyl([wx + math.cos(a) * 0.3, 0.4 + math.sin(a) * 0.3, wz + 0.04],
                                          [wx - math.cos(a) * 0.3, 0.4 - math.sin(a) * 0.3, wz + 0.04], 0.02), "prop")
    K.fence(p, P, [(1.62, 0.7), (1.97, 0.7), (1.97, 0.04), (1.62, 0.04)], name="garden_fence", h=0.4, mat="post")
    p.add("garden_soil", "soil", box(P.m(1.8, 0.37, 0.02), [0.3 * K.T * 0.9, 0.02, 0.16 * K.T * 0.9]), "ground")
    for gx, gy in ((1.72, 0.18), (1.72, 0.5), (1.88, 0.34)):
        x, _, z = P.m(gx, gy)
        p.add("bean_poles", "post", cyl([x, 0, z], [x, 1.0, z], 0.022), "prop", min_cover=2)
        p.add("beans", "leaves", ell([x, 0.55, z], [0.09, 0.4, 0.09]), "prop")
    if not back:
        K.stones(p, P, [(1.62, 1.18), (1.7, 1.42), (1.85, 1.3)], name="path_stones")
        hens(p, P, [(1.86, 1.74)])
    K.tufts(p, P, [(1.97, 1.9), (0.06, 1.97), (1.1, 1.95)])
    p.heap = (1.8, 1.2)
    return P, p


# =================================================================================================
# The upgrade scaffold: poles, ledgers, putlogs and plank walks on three lifts along the two faces
# the camera sees, two ladders, a gin wheel with a bucket on a rope at the front corner. Drawn over
# the house while it is rebuilt (the burgher houses are up to three storeys).
# =================================================================================================
def scaffold():
    P, p = Plot(2), Parts()
    e = 0.06            # just inside the plot's front edges
    gx1, gy1 = 2 - e, 2 - e
    lifts = (1.35, 2.85, 4.35)
    top = 5.1
    poles_r = [(gx1, gy) for gy in (0.1, 0.72, 1.34, gy1)]
    poles_l = [(gx, gy1) for gx in (0.1, 0.72, 1.34)]
    for i, (gx, gy) in enumerate(poles_r + poles_l):
        h = top - 0.25 * (i % 3)
        p.add("poles", "raw_timber", cyl(P.m(gx, gy, 0), P.m(gx, gy, h), 0.045), "site", priority=2)
        p.add("pole_feet", "board", box(P.m(gx, gy, 0.03), [0.12, 0.03, 0.12]), "site")
    for y in lifts:
        a, b = P.m(gx1, 0.06, y), P.m(gx1, gy1, y)
        p.add("ledgers", "raw_timber", cyl(a, b, 0.035), "site", priority=2)
        a2, b2 = P.m(0.06, gy1, y), P.m(gx1, gy1, y)
        p.add("ledgers", "raw_timber", cyl(a2, b2, 0.035), "site", priority=2)
        # plank walks resting on putlogs into the wall
        xa, xb = P.m(0, 0.08)[0], P.m(0, gy1)[0]
        z = P.m(gx1, 0)[2]
        p.add("planks", "plank", box([(xa + xb) / 2, y + 0.06, z - 0.22], [abs(xb - xa) / 2, 0.025, 0.13]), "site")
        za, zb = P.m(0.08, 0)[2], P.m(gx1, 0)[2]
        x = P.m(0, gy1)[0]
        p.add("planks", "plank", box([x + 0.22, y + 0.06, (za + zb) / 2], [0.13, 0.025, abs(zb - za) / 2]), "site")
        p.paint("planks", "ink", stripes={"axis": "y", "at": [y + 0.06], "width": 0.02})
        # guard rail
        p.add("rails", "raw_timber", cyl(P.m(gx1, 0.08, y + 0.75), P.m(gx1, gy1, y + 0.75), 0.025), "site", priority=2)
        p.add("rails", "raw_timber", cyl(P.m(0.08, gy1, y + 0.75), P.m(gx1, gy1, y + 0.75), 0.025), "site", priority=2)
    # diagonal braces on both faces
    p.add("braces", "raw_timber", cyl(P.m(gx1, 0.1, 0.2), P.m(gx1, 0.72, lifts[0]), 0.03), "site", priority=2)
    p.add("braces", "raw_timber", cyl(P.m(gx1, 1.34, lifts[0]), P.m(gx1, gy1, lifts[1]), 0.03), "site", priority=2)
    p.add("braces", "raw_timber", cyl(P.m(0.1, gy1, 0.2), P.m(0.72, gy1, lifts[0]), 0.03), "site", priority=2)
    # ladders from the ground to the first lift and between lifts
    K.ladder(p, P, (gx1 + 0.08, 0.42, 0.0), (gx1 + 0.08, 0.42, lifts[0] + 0.5), w=0.3)
    K.ladder(p, P, (gx1 + 0.08, 1.05, lifts[0]), (gx1 + 0.08, 1.05, lifts[1] + 0.5), w=0.3)
    for nm in ("ladder",):
        p.layer[nm] = "site"
    # a gin wheel on a jib at the top of the front corner pole, a rope and a bucket of mortar
    c = P.m(gx1, gy1, top - 0.1)
    p.add("jib", "raw_timber", cyl(c, [c[0] - 0.4, c[1] + 0.05, c[2] + 0.4], 0.035), "site")
    w = [c[0] - 0.4, c[1] - 0.05, c[2] + 0.4]
    p.add("gin_wheel", "iron", tor(w, 0.1, 0.025, rot=[1.5708, 0.785, 0]), "site")
    p.add("hoist_rope", "rope", cyl([w[0], w[1] - 0.1, w[2]], [w[0], 1.6, w[2]], 0.015), "site", min_cover=1, priority=2)
    p.add("hoist_bucket", "barrel", cyl([w[0], 1.32, w[2]], [w[0], 1.6, w[2]], 0.12), "site")
    p.add("hoist_bucket_fill", "flour", cyl([w[0], 1.57, w[2]], [w[0], 1.59, w[2]], 0.1), "site")
    p.paint("hoist_bucket", "iron", stripes={"axis": "y", "at": [1.38, 1.54], "width": 0.055})
    # a few stones and a mortar trough on the lowest walk
    x, _, z = P.m(gx1, 0.95)
    p.add("trough", "board", box([x, lifts[0] + 0.14, z - 0.2], [0.22, 0.06, 0.12]), "site")
    p.add("trough_mortar", "flour", box([x, lifts[0] + 0.2, z - 0.2], [0.19, 0.01, 0.09]), "site")
    return P, p


LOOKS = {"hut": hut_1, "hut_2": hut_2, "hut_3": hut_3}
SUMMARY = {
    "hut": "Your Kingdom hut, look 1 (G3 part 4a), 2x2 tiles: a log cottage under a steep hipped mossy thatch, a "
           "clay chimney, a bench, firewood, a rain barrel, a wattle-fenced cabbage patch, hens",
    "hut_2": "Your Kingdom hut, look 2 (G3 part 4a), 2x2 tiles: a whitewashed half-timbered cottage on a stone plinth "
             "under red tiles with a dormer, crossed bargeboards, a brick chimney, a woodshed lean-to, a flower bed",
    "hut_3": "Your Kingdom hut, look 3 (G3 part 4a), 2x2 tiles: a fieldstone cottage with quoins under mossy "
             "shingles, a boarded gable to the street, a pentice over the door, an outside stone chimney, a skep, "
             "a cart wheel, bean poles",
}


def spec_of(name, parts, summary):
    s = head(name, SIZE, CY, summary)
    s["parts"] = dict(parts)
    s["animations"] = {"idle": {"frames": 1, "ms": 500, "channels": {}}}
    return s


def main():
    only = [a for a in sys.argv[1:] if not a.startswith("-")]
    for look, fn in LOOKS.items():
        for back in (False, True):
            name = look + ("_back" if back else "")
            if only and name not in only and look not in only:
                continue
            P, parts = fn(back)
            n = write("hut", spec_of(name, parts, SUMMARY[look] + (" (back view)" if back else "")))
            print("written", name, n, "prims")
            if look == "hut_2":     # the construction stages of every look come from look 2
                for k in (1, 2):
                    st = stage(P, parts, k, parts.roofs)
                    for nm_ in [n_ for n_ in st if n_.startswith(("dormer", "lantern"))]:
                        del st[nm_]
                    nm = "hut%s_c%d" % ("_back" if back else "", k)
                    write("hut", spec_of(nm, st, SUMMARY[look] + f" (construction stage {k})"))
                    print("written", nm)
    if not only or "hut_scaffold" in only:
        P, parts = scaffold()
        n = write("hut", spec_of("hut_scaffold", parts, "Your Kingdom house upgrade scaffold (G3 part 4a): poles, "
                                 "ledgers, plank walks on three lifts, ladders and a gin wheel along the two faces "
                                 "the camera sees"))
        print("written hut_scaffold", n, "prims")


if __name__ == "__main__":
    main()
