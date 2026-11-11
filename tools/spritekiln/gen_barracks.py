"""The small and large barracks (E4 part 4, owner's survey 2026-11-11), in the school's style.

barracks_small (2x2): a wooden guardhouse. A log house on a stone plinth (game x 0.12-1.3,
y 0.12-1.5) with a shingle roof whose ridge runs along the game's y axis, a porch with a lean-to
roof along its right side (the door on the entrance's side, game x 1.3, y 1.25), an archery butt
on a stand in front of the gable, a rack of spears at the right corner, a little red pennant on
the gable. Nobody drills here (the soldiers rest inside).

barracks_large (5x5): stone "castle" barracks shaped like an L at the back, the courtyard open to
the front (towards the camera) so the drilling ranks are never hidden. Wing A along the back right
(game x 0.1-4.9, y 0.1-1.8) and wing B along the back left (x 0.1-1.8, y 1.8-4.9): two stone
floors with arrow slits and windows, steep red tile roofs; a square keep at the back corner with a
parapet on corbels, merlons and a red banner; at the end of each wing a round tower like the owner's
reference (2026-11-11): a crenellated gallery on corbels, a narrower upper stage, a tall pointed roof. The
courtyard (game x 1.8-5, y 1.8-5) is packed sand with a cobbled way in from the gate (game 3, 4);
a weapon rack and an archery butt stand against the wings, out of the ranks' places (the posts of
the courtyard tiles, Barracks.parade_posts). Soldiers in the courtyard are drawn over the building
(BuildingVisualDef.open_tiles), so nothing may stand in front of them.

Game tile (gx, gy) of an n x n plot -> model: x = n/2 * TILE - gy * TILE, z = gx * TILE - n/2 * TILE.

Writes art/specs/props/barracks_small/barracks_small.yaml and art/specs/props/barracks_large/
barracks_large.yaml; edit this script, not those files.
Run (inside tools/spritekiln): python3 gen_barracks.py, then
  cd art/specs/props/barracks_small && spritekiln render barracks_small.yaml   (and barracks_large)
  python3 tools/spritekiln/export_building.py barracks_small     (from the repository root; and barracks_large)
"""
import math
import os
import sys

import yaml

import gen_school as gs
from gen_school import Parts, box, cyl, r4

HERE = os.path.dirname(os.path.abspath(__file__))
TILE = gs.TILE


def mapper(n):
    half = n / 2 * TILE

    def m(gx, gy, y=0.0):
        return [half - gy * TILE, y, gx * TILE - half]
    return m


def gable_house(parts, name, m, gx0, gx1, gy0, gy1, axis, eave, ridge, wall_mat, roof_mat, roof_dark,
                plinth=0.0, o=0.35):
    """A block with walls up to [eave] and a gabled roof up to [ridge] along the game's [axis]."""
    x0, x1 = m(0, gy1)[0], m(0, gy0)[0]
    z0, z1 = m(gx0, 0)[2], m(gx1, 0)[2]
    xc, zc, hx, hz = (x0 + x1) / 2, (z0 + z1) / 2, (x1 - x0) / 2, (z1 - z0) / 2
    if plinth > 0:
        parts.add(f"{name}_plinth", "stone", box([xc, plinth / 2, zc], [hx + 0.06, plinth / 2, hz + 0.06]))
    parts.add(f"{name}_walls", wall_mat, box([xc, eave / 2, zc], [hx, eave / 2, hz]))
    half_w = hx if axis == "x" else hz
    length = 2 * (hz if axis == "x" else hx)
    gable = [[-half_w, eave - 0.02], [half_w, eave - 0.02], [0, ridge - 0.35]]
    g = {"extrude": {"c": r4([xc, 0, zc]), "depth": r4(length), "profile": {"polygon": [r4(p) for p in gable]}}}
    if axis == "y":
        g["extrude"]["rot"] = [0, 1.5708, 0]
    parts.add(f"{name}_gable", wall_mat, g)
    t = 0.18
    outer = [[-half_w - o, eave - 0.25], [0, ridge], [half_w + o, eave - 0.25]]
    inner = [[p[0], p[1] - t] for p in reversed(outer)]
    roof = {"extrude": {"c": r4([xc, 0, zc]), "depth": r4(length + 0.4),
                        "profile": {"polygon": [r4(p) for p in outer + inner]}}}
    if axis == "y":
        roof["extrude"]["rot"] = [0, 1.5708, 0]
    parts.add(f"{name}_roof", roof_mat, roof)
    parts[f"{name}_roof"]["paint"] = [{"material": roof_dark, "stripes": {"axis": "y", "period": 0.26,
                                                                          "width": 0.06, "offset": eave}}]
    return x0, x1, z0, z1


# --- The small barracks -------------------------------------------------------------------------------

def small():
    m = mapper(2)
    parts = Parts()
    parts.add("yard", "earth", box([0, 0.01, 0], [2.34, 0.01, 2.34]))
    parts["yard"]["paint"] = [{"material": "grass", "spots": {"scale": 0.15, "density": 0.35, "seed": 3}},
                              {"material": "cobble", "prims": [box(m(1.55, 1.25, 0.01), [0.35, 0.05, 0.5])]}]
    eave, ridge = 2.35, 4.3
    x0, x1, z0, z1 = gable_house(parts, "house", m, 0.12, 1.3, 0.12, 1.5, "y", eave, ridge,
                                 "logs", "shingle", "shingle_dark", plinth=0.35)
    # Log courses on the two faces seen, and corner notches.
    courses = []
    for k in range(7):
        y = 0.5 + k * 0.28
        courses.append(box([x0 - 0.02, y, (z0 + z1) / 2], [0.04, 0.035, (z1 - z0) / 2]))
        courses.append(box([(x0 + x1) / 2, y, z1 + 0.02], [(x1 - x0) / 2, 0.035, 0.04]))
    parts.paint("house_walls", "log_dark", courses)
    ends = []
    for x in (x0, x1):
        for z in (z0, z1):
            for k in range(7):
                ends.append(cyl([x, 0.5 + k * 0.28, z - 0.12], [x, 0.5 + k * 0.28, z + 0.12], 0.13))
    parts["log_ends"] = {"material": "log_end", "prims": ends}
    # The gable boards in front (game y+ side), a pennant on a pole at its peak.
    parts["house_gable"]["material"] = "planks"
    parts.paint("house_gable", "log_dark", [box([x0 - 0.02, eave + 0.5 + k * 0.4, (z0 + z1) / 2],
                                                [0.04, 0.03, (z1 - z0) / 2]) for k in range(4)])
    zc = (z0 + z1) / 2
    parts.add("pole", "post", cyl([x0 - 0.3, ridge - 0.4, zc], [x0 - 0.3, ridge + 1.3, zc], 0.04), priority=3, min_cover=1)
    parts.add("pennant", "cloth", {"extrude": {"c": r4([x0 - 0.3, 0, zc]), "depth": 0.06,
                                               "profile": {"polygon": [[0, ridge + 1.3], [1.0, ridge + 1.05],
                                                                       [0, ridge + 0.75]]},
                                               "rot": [0, 1.5708, 0]}})
    # A small shuttered window in the gable wall, the door on the porch side.
    parts.add("glass", "glass", box([x0 - 0.03, 1.35, zc], [0.04, 0.22, 0.2]))
    parts.add("frames", "timber", box([x0 - 0.06, 1.1, zc], [0.06, 0.04, 0.28]), priority=2)
    for s in (-1, 1):
        parts.add("shutters", "shutter_wood", box([x0 - 0.06, 1.35, zc + s * 0.32], [0.03, 0.22, 0.11]))
    dx = m(0, 1.2)[0]
    parts.add("door", "door_wood", box([dx, 0.95, z1 + 0.03], [0.32, 0.6, 0.05]), priority=2)
    parts["door"]["paint"] = [{"material": "ink", "stripes": {"axis": "x", "period": 0.21, "width": 0.055,
                                                              "offset": dx}}]
    parts.add("door_frame", "timber", box([dx, 1.6, z1 + 0.05], [0.4, 0.06, 0.06]), priority=2)
    # The porch: two posts, a lean-to roof from the wall down to them, a plank floor.
    pz = m(1.8, 0)[2]
    pxa, pxb = m(0, 1.5)[0], m(0, 0.45)[0]
    for x in (pxa + 0.1, pxb - 0.1):
        parts.add("porch_posts", "post", cyl([x, 0, pz], [x, 1.95, pz], 0.08))
    parts.add("porch_floor", "planks", box([(pxa + pxb) / 2, 0.1, (z1 + pz) / 2], [(pxb - pxa) / 2, 0.1, (pz - z1) / 2 + 0.08]))
    slope = math.atan2(0.45, pz - z1)
    parts.add("porch_roof", "shingle", box([(pxa + pxb) / 2, 2.2, (z1 + pz) / 2 + 0.05],
                                           [(pxb - pxa) / 2 + 0.15, 0.07, (pz - z1) / 2 + 0.3], rot=[slope, 0, 0]))
    parts["porch_roof"]["paint"] = [{"material": "shingle_dark", "stripes": {"axis": "z", "period": 0.24,
                                                                             "width": 0.06, "offset": z1}}]
    parts.add("porch_beam", "timber", box([(pxa + pxb) / 2, 1.95, pz], [(pxb - pxa) / 2 + 0.05, 0.07, 0.07]))
    # The archery butt: a straw disc with rings on a little stand, in front of the gable.
    b = m(0.55, 1.85)
    parts.add("butt_stand", "post", cyl([b[0] + 0.25, 0, b[2] - 0.25], [b[0], 0.95, b[2]], 0.04), priority=2)
    parts.add("butt_stand", "post", cyl([b[0] + 0.25, 0, b[2] + 0.25], [b[0], 0.95, b[2]], 0.04), priority=2)
    parts.add("butt", "straw", cyl([b[0] - 0.08, 0.75, b[2]], [b[0] + 0.08, 0.75, b[2]], 0.42), priority=2)
    parts["butt"]["paint"] = [{"material": "cloth", "prims": [cyl([b[0] - 0.12, 0.75, b[2]], [b[0] - 0.05, 0.75, b[2]], 0.29)]},
                              {"material": "chalk", "prims": [cyl([b[0] - 0.13, 0.75, b[2]], [b[0] - 0.05, 0.75, b[2]], 0.19)]},
                              {"material": "cloth", "prims": [cyl([b[0] - 0.14, 0.75, b[2]], [b[0] - 0.05, 0.75, b[2]], 0.08)]}]
    # A rack of spears in front of the gable, beside the porch.
    r = m(1.3, 1.82)
    for dz in (-0.35, 0.35):
        parts.add("rack", "post", cyl([r[0], 0, r[2] + dz], [r[0], 1.0, r[2] + dz], 0.05))
    parts.add("rack", "post", box([r[0], 0.85, r[2]], [0.05, 0.05, 0.45]))
    spears = []
    tips = []
    for k, dz in enumerate((-0.25, -0.08, 0.09, 0.26)):
        a = [r[0] - 0.3, 0, r[2] + dz]
        b2 = [r[0] + 0.12, 2.1, r[2] + dz]
        spears.append(cyl(a, b2, 0.03))
        tips.append({"cone": {"a": r4(b2), "b": r4([b2[0] + 0.04, b2[1] + 0.28, b2[2]]), "r": [0.06, 0.0]}})
    parts["spears"] = {"material": "post", "prims": spears, "priority": 3, "min_cover": 1}
    parts["spear_tips"] = {"material": "steel_mat", "prims": tips, "priority": 3, "min_cover": 1}
    # A barrel and a bush.
    t = m(0.2, 1.75)
    parts.add("barrel", "barrel_wood", cyl([t[0], 0, t[2]], [t[0], 0.6, t[2]], 0.24))
    return parts


# --- The large barracks -------------------------------------------------------------------------------

def merlons(m, x0, x1, z0, z1, y, faces):
    """Crenellations on top of a block: merlons along the faces named ('front' = plane x0,
    'right' = plane z1, 'back' = x1, 'left' = z0)."""
    out = []
    step = 0.62
    for face in faces:
        if face in ("front", "back"):
            x = x0 if face == "front" else x1
            n = max(2, int((z1 - z0) / step))
            for k in range(n + 1):
                if k % 2 == 0:
                    z = z0 + (z1 - z0) * k / n
                    out.append(box([x, y + 0.3, z], [0.14, 0.3, 0.17]))
        else:
            z = z1 if face == "right" else z0
            n = max(2, int((x1 - x0) / step))
            for k in range(n + 1):
                if k % 2 == 0:
                    x = x0 + (x1 - x0) * k / n
                    out.append(box([x, y + 0.3, z], [0.17, 0.3, 0.14]))
    return out


def crenellated_top(xc, zc, hx, hz, y0):
    """Corbels, a parapet wall standing out by OUT and merlons on it around a square top at y0."""
    out, t = 0.32, 0.24
    ox, oz = hx + out, hz + out
    corbels = []
    for k in range(int(2 * hx / 0.5) + 1):
        z = zc - hz + 0.1 + k * 0.5
        if z < zc + hz:
            corbels.append(box([xc - hx - out / 2, y0 - 0.22, z], [out / 2, 0.2, 0.11]))
    for k in range(int(2 * hx / 0.5) + 1):
        x = xc - hx + 0.1 + k * 0.5
        if x < xc + hx:
            corbels.append(box([x, y0 - 0.22, zc + hz + out / 2], [0.11, 0.2, out / 2]))
    wall_h = 0.7
    yc = y0 + wall_h / 2
    walls = [box([xc - ox + t / 2, yc, zc], [t / 2, wall_h / 2, oz]), box([xc + ox - t / 2, yc, zc], [t / 2, wall_h / 2, oz]),
             box([xc, yc, zc - oz + t / 2], [ox, wall_h / 2, t / 2]), box([xc, yc, zc + oz - t / 2], [ox, wall_h / 2, t / 2])]
    teeth = []
    my, mh, w, gap = y0 + wall_h + 0.25, 0.25, 0.26, 0.3
    n = int(2 * ox / (2 * w + gap))
    span = 2 * ox - 2 * w
    for k in range(n + 1):
        f = -ox + w + span * k / n
        teeth.append(box([xc - ox + t / 2, my, zc + f], [t / 2, mh, w]))
        teeth.append(box([xc + ox - t / 2, my, zc + f], [t / 2, mh, w]))
        teeth.append(box([xc + f, my, zc - oz + t / 2], [w, mh, t / 2]))
        teeth.append(box([xc + f, my, zc + oz - t / 2], [w, mh, t / 2]))
    return {
        "keep_corbels": {"material": "sill_mat", "prims": corbels},
        "keep_ledge": {"material": "sill_mat", "prims": [box([xc, y0 + 0.02, zc], [ox, 0.07, oz])]},
        "keep_parapet": {"material": "stone", "prims": walls},
        "keep_merlons": {"material": "stone", "prims": teeth},
        "keep_walk": {"material": "stone_dark", "prims": [box([xc, y0 + 0.12, zc], [ox - t, 0.04, oz - t])]},
    }


def turret(parts, name, c, tr=1.1, h1=4.6, ur=0.8, h2=2.9, spire=3.9):
    """A round tower like the owner's reference: shaft, gallery on corbels, upper stage, spire."""
    cx, cz = c[0], c[2]
    parts.add(name, "stone", cyl([cx, 0, cz], [cx, h1, cz], tr))
    parts[name]["paint"] = [{"material": "stone_dark", "spots": {"scale": 0.16, "density": 0.25, "seed": 13}}]
    parts.add(name + "_plinth", "sill_mat", cyl([cx, 0, cz], [cx, 0.55, cz], tr + 0.08))
    corbels, teeth = [], []
    for k in range(18):
        a = 2 * math.pi * k / 18
        corbels.append(box([cx + (tr + 0.12) * math.cos(a), h1 - 0.25, cz + (tr + 0.12) * math.sin(a)],
                           [0.15, 0.2, 0.08], rot=[0, -a, 0]))
    for k in range(12):
        a = 2 * math.pi * (k + 0.5) / 12
        teeth.append(box([cx + (tr + 0.2) * math.cos(a), h1 + 0.95, cz + (tr + 0.2) * math.sin(a)],
                         [0.11, 0.25, 0.2], rot=[0, -a, 0]))
    parts[name + "_corbels"] = {"material": "sill_mat", "prims": corbels}
    parts[name + "_gallery"] = {"material": "stone", "prims": [cyl([cx, h1 - 0.05, cz], [cx, h1 + 0.7, cz], tr + 0.31)],
                                "cut": [cyl([cx, h1 + 0.15, cz], [cx, h1 + 1.0, cz], tr + 0.09)]}
    parts[name + "_merlons"] = {"material": "stone", "prims": teeth}
    parts.add(name + "_upper", "stone", cyl([cx, h1, cz], [cx, h1 + h2, cz], ur))
    parts[name + "_upper"]["paint"] = [{"material": "stone_dark", "spots": {"scale": 0.16, "density": 0.25, "seed": 17}}]
    parts.add(name + "_cornice", "sill_mat", cyl([cx, h1 + h2 - 0.12, cz], [cx, h1 + h2 + 0.05, cz], ur + 0.1))
    top = h1 + h2
    # A sharp cone (a revolved triangle: the "cone" primitive is a rounded capsule, it looked like
    # an onion dome), its eaves a little over the wall.
    rr = ur + 0.2
    parts.add(name + "_roof", "tile", {"revolve": {"c": r4([cx, 0, cz]), "profile": {"polygon": [
        [-rr, r4(top - 0.05)], [rr, r4(top - 0.05)], [0, r4(top + spire)]]}}})
    parts[name + "_roof"]["paint"] = [{"material": "tile_dark", "stripes": {"axis": "y", "period": 0.3,
                                                                            "width": 0.06, "offset": top}}]
    parts.add("finial", "post", cyl([cx, top + spire - 0.2, cz], [cx, top + spire + 0.6, cz], 0.04), priority=3, min_cover=1)
    # Small windows: slits in the shaft, little square windows in the upper stage.
    for y in (1.6, 3.4):
        parts.add("slits", "ink", box([cx - tr, y, cz], [0.05, 0.35, 0.07]))
        parts.add("slits", "ink", box([cx, y, cz + tr], [0.07, 0.35, 0.05]))
    for a in (math.pi * 0.85, math.pi * 1.15, math.pi * 0.35, math.pi * 0.65):
        parts.add("slits", "ink", box([cx + ur * math.cos(a), top - 0.6, cz + ur * math.sin(a)], [0.06, 0.15, 0.1],
                                      rot=[0, -a, 0]))


def large():
    m = mapper(5)
    parts = Parts()
    parts.add("yard", "earth", box([0, 0.01, 0], [5.86, 0.01, 5.86]))
    parts["yard"]["paint"] = [{"material": "sand", "prims": [box(m(3.4, 3.4, 0.01), [3.75, 0.05, 3.75])]},
                              {"material": "sand_dark", "spots": {"scale": 0.12, "density": 0.25, "seed": 5}},
                              {"material": "cobble", "prims": [box(m(3.5, 4.55, 0.01), [0.5, 0.05, 0.45])]},
                              {"material": "grass", "prims": [box(m(0.9, 4.9, 0.01), [0.3, 0.05, 1.8]),
                                                              box(m(4.9, 0.9, 0.01), [1.8, 0.05, 0.3])]}]
    eave, ridge = 4.0, 6.4
    # Wing A along the back right (ridge along x), wing B along the back left (ridge along y).
    ax0, ax1, az0, az1 = gable_house(parts, "wing_a", m, 0.15, 4.1, 0.15, 1.8, "x", eave, ridge,
                                     "stone", "tile", "tile_dark", o=0.3)
    bx0, bx1, bz0, bz1 = gable_house(parts, "wing_b", m, 0.15, 1.8, 0.15, 4.1, "y", eave, ridge,
                                     "stone", "tile", "tile_dark", o=0.3)
    for w in ("wing_a_walls", "wing_b_walls", "wing_a_gable", "wing_b_gable"):
        parts[w]["paint"] = [{"material": "stone_dark", "spots": {"scale": 0.16, "density": 0.25, "seed": 11}}]
    # A string course between the floors, on both wings.
    parts.add("courses", "sill_mat", box([(ax0 + ax1) / 2, 2.0, (az0 + az1) / 2], [(ax1 - ax0) / 2 + 0.05, 0.08, (az1 - az0) / 2 + 0.05]))
    parts.add("courses", "sill_mat", box([(bx0 + bx1) / 2, 2.0, (bz0 + bz1) / 2], [(bx1 - bx0) / 2 + 0.05, 0.08, (bz1 - bz0) / 2 + 0.05]))
    # Windows and slits on the courtyard faces: wing A faces game +y (plane x = ax0), wing B faces
    # game +x (plane z = bz1).
    for gx in (2.35, 3.25):
        z = m(gx, 0)[2]
        parts.add("glass", "glass", box([ax0 - 0.03, 2.9, z], [0.04, 0.32, 0.2]))
        parts.add("frames", "sill_mat", box([ax0 - 0.06, 2.55, z], [0.07, 0.05, 0.28]), priority=2)
        parts.add("slits", "ink", box([ax0 - 0.03, 1.15, z], [0.04, 0.38, 0.06]))
    for gy in (2.35, 3.25):
        x = m(0, gy)[0]
        parts.add("glass", "glass", box([x, 2.9, bz1 + 0.03], [0.2, 0.32, 0.04]))
        parts.add("frames", "sill_mat", box([x, 2.55, bz1 + 0.06], [0.28, 0.05, 0.07]), priority=2)
        parts.add("slits", "ink", box([x, 1.15, bz1 + 0.03], [0.06, 0.38, 0.04]))
    # Doors into the wings from the courtyard (arched, with a stone surround).
    dz = m(2.75, 0)[2]
    parts.add("door_frame", "sill_mat", box([ax0 - 0.03, 0.75, dz], [0.06, 0.75, 0.52]))
    parts.add("door_frame", "sill_mat", cyl([ax0 - 0.09, 1.5, dz], [ax0 + 0.02, 1.5, dz], 0.52))
    parts.add("door", "door_wood", box([ax0 - 0.08, 0.7, dz], [0.04, 0.7, 0.38]), priority=2)
    parts.add("door", "door_wood", cyl([ax0 - 0.12, 1.4, dz], [ax0 - 0.04, 1.4, dz], 0.38), priority=2)
    dx = m(0, 2.75)[0]
    parts.add("door_frame", "sill_mat", box([dx, 0.75, bz1 + 0.03], [0.52, 0.75, 0.06]))
    parts.add("door_frame", "sill_mat", cyl([dx, 1.5, bz1 - 0.02], [dx, 1.5, bz1 + 0.09], 0.52))
    parts.add("door", "door_wood", box([dx, 0.7, bz1 + 0.08], [0.38, 0.7, 0.04]), priority=2)
    parts.add("door", "door_wood", cyl([dx, 1.4, bz1 + 0.04], [dx, 1.4, bz1 + 0.12], 0.38), priority=2)
    # Dormers with small windows on the courtyard slopes.
    for gx in (2.75, 3.95):
        z = m(gx, 0)[2]
        parts.add("dormer_glass", "glass", box([ax0 - 0.05, eave + 0.55, z], [0.04, 0.2, 0.15]))
    # The keep at the back corner, taller than the wings, crenellated, with a red banner.
    kx0, kx1 = m(0, 1.95)[0], m(0, 0.05)[0]
    kz0, kz1 = m(0.05, 0)[2], m(1.95, 0)[2]
    kxc, kzc, khx, khz = (kx0 + kx1) / 2, (kz0 + kz1) / 2, (kx1 - kx0) / 2, (kz1 - kz0) / 2
    shaft = 7.6
    parts.add("keep", "stone", box([kxc, shaft / 2, kzc], [khx, shaft / 2, khz]))
    quoins = []
    for x in (kx0, kx1):
        for z in (kz0, kz1):
            for k in range(16):
                lx = k % 2 == 0
                quoins.append(box([x, 0.25 + k * 0.46, z], [0.32 if lx else 0.14, 0.17, 0.14 if lx else 0.32]))
    parts["keep"]["paint"] = [{"material": "stone_dark", "spots": {"scale": 0.16, "density": 0.25, "seed": 7}},
                              {"material": "sill_mat", "prims": quoins}]
    # The crenellated top (owner's review 2026-11-11: a real parapet, not blocks on a flat top): a
    # row of corbels carries a parapet wall that stands out from the shaft; merlons stand on the
    # wall with gaps between them, the wall-walk inside lies lower.
    parts.update(crenellated_top(kxc, kzc, khx, khz, shaft))
    for y in (3.4, 5.6):
        parts.add("slits", "ink", box([kx0 - 0.02, y, kzc], [0.04, 0.35, 0.07]))
        parts.add("slits", "ink", box([kxc, y, kz1 + 0.02], [0.07, 0.35, 0.04]))
    parts.add("flagpole", "post", cyl([kxc, shaft, kzc], [kxc, shaft + 3.0, kzc], 0.05), priority=3, min_cover=1)
    parts.add("banner", "cloth", {"extrude": {"c": r4([kxc, 0, kzc + 0.05]), "depth": 0.06,
                                              "profile": {"polygon": [[0, shaft + 2.95], [1.25, shaft + 2.95],
                                                                      [1.25, shaft + 2.05], [0.62, shaft + 2.3],
                                                                      [0, shaft + 2.05]]},
                                              "rot": [0, 0, 0]}})
    parts["banner"]["paint"] = [{"material": "gold_mat", "prims": [box([kxc + 0.62, shaft + 2.6, kzc + 0.05], [0.12, 0.2, 0.05])]}]
    # Round turrets at the far ends of the wings (owner's reference 2026-11-11): a round shaft, a
    # crenellated gallery on corbels, a narrower upper stage with small windows and a tall steep
    # pointed roof of red tiles.
    for name, (gx, gy) in (("turret_r", (4.4, 0.98)), ("turret_l", (0.98, 4.4))):
        turret(parts, name, m(gx, gy))
    # Against the wings, out of the ranks: a weapon rack (spears, a shield), an archery butt, barrels.
    r = m(2.4, 1.93)
    for dz in (-0.45, 0.45):
        parts.add("rack", "post", cyl([r[0], 0, r[2] + dz], [r[0], 1.0, r[2] + dz], 0.05))
    parts.add("rack", "post", box([r[0], 0.85, r[2]], [0.05, 0.05, 0.55]))
    spears, tips = [], []
    for dz in (-0.33, -0.11, 0.11, 0.33):
        a = [r[0] - 0.05, 0, r[2] + dz]
        b2 = [r[0] + 0.12, 2.2, r[2] + dz]
        spears.append(cyl(a, b2, 0.03))
        tips.append({"cone": {"a": r4(b2), "b": r4([b2[0] + 0.02, b2[1] + 0.28, b2[2]]), "r": [0.06, 0.0]}})
    parts["spears"] = {"material": "post", "prims": spears, "priority": 3, "min_cover": 1}
    parts["spear_tips"] = {"material": "steel_mat", "prims": tips, "priority": 3, "min_cover": 1}
    s = m(3.25, 1.9)
    parts.add("shield", "cloth", cyl([s[0] - 0.02, 0.55, s[2]], [s[0] + 0.08, 0.55, s[2]], 0.36), priority=2)
    parts["shield"]["paint"] = [{"material": "gold_mat", "prims": [box([s[0] - 0.04, 0.55, s[2]], [0.06, 0.3, 0.06]),
                                                                    box([s[0] - 0.04, 0.6, s[2]], [0.06, 0.06, 0.25])]}]
    b = m(1.92, 2.6)
    parts.add("butt", "straw", cyl([b[0], 0.75, b[2] - 0.05], [b[0], 0.75, b[2] + 0.1], 0.42), priority=2)
    parts["butt"]["paint"] = [{"material": "cloth", "prims": [cyl([b[0], 0.75, b[2] + 0.05], [b[0], 0.75, b[2] + 0.14], 0.29)]},
                              {"material": "chalk", "prims": [cyl([b[0], 0.75, b[2] + 0.06], [b[0], 0.75, b[2] + 0.15], 0.19)]},
                              {"material": "cloth", "prims": [cyl([b[0], 0.75, b[2] + 0.07], [b[0], 0.75, b[2] + 0.16], 0.08)]}]
    for gx, gy in ((4.35, 1.95), (1.95, 4.3)):
        t = m(gx, gy)
        parts.add("barrels", "barrel_wood", cyl([t[0], 0, t[2]], [t[0], 0.62, t[2]], 0.24))
    return parts


def materials():
    mats = gs.materials()
    mats.update({
        "logs": {"ramp": "log", "bands": [2, 4]},
        "log_dark": {"ramp": "log", "bands": [1, 2], "outline": False},
        "log_end": {"ramp": "wood", "bands": [3, 5]},
        "planks": {"ramp": "wood", "bands": [2, 4]},
        "shingle": {"ramp": "shingle", "bands": [2, 4]},
        "shingle_dark": {"ramp": "shingle", "bands": [0, 1], "outline": False},
        "shutter_wood": {"ramp": "shutter", "bands": [1, 3], "line": False},
        "cloth": {"ramp": "cloth", "bands": [2, 4], "two_sided": True},
        "straw": {"ramp": "straw", "bands": [2, 4]},
        "steel_mat": {"ramp": "steel", "finish": "metal", "bands": [2, 5]},
        "gold_mat": {"ramp": "gold", "bands": [3, 4], "outline": False},
        "barrel_wood": {"ramp": "wood", "bands": [2, 4]},
        "sand": {"ramp": "sand", "bands": [2, 4], "outline": False},
        "sand_dark": {"ramp": "sand", "bands": [1, 2], "outline": False},
    })
    return mats


def spec(name, size, center, summary, keep):
    s = gs.spec()
    s["name"] = name
    s["size"] = size
    s["camera"] = {"pitch": 30, "scale": 0.05176, "center": center}
    s["ramps"]["straw"] = ["#1c1406", "#4a3a14", "#7a6224", "#a88a3a", "#cdb058", "#e6cf82"]
    s["ramps"]["sand"] = ["#1a150d", "#4a3e2a", "#77684b", "#9a8a66", "#b8a77f", "#d0c098"]
    s["brief"] = {"summary": summary, "must_keep": keep}
    s["materials"] = materials()
    s["parts"] = dict(small() if name == "barracks_small" else large())
    return s


SPECS = {
    "barracks_small": (192, [0, 1.9, 0],
                       "Your Kingdom small barracks (E4 part 4), 2x2 tiles: a wooden guardhouse of logs on a stone "
                       "plinth under a shingle roof, a porch with a lean-to roof by the door, an archery butt, a rack "
                       "of spears, a red pennant",
                       ["footprint 2x2 tiles (4.69 x 4.69 units)", "entrance tile (game 1, 1) free",
                        "reads as a cheap wooden guardhouse of the early game"]),
    "barracks_large": (448, [0, 4.2, 0],
                       "Your Kingdom large barracks (E4 part 4), 5x5 tiles: stone castle barracks in an L at the back "
                       "(two wings with red tile roofs, a crenellated keep with a red banner, round corner turrets with a gallery and a tall spire), the "
                       "sandy courtyard open to the camera for the drilling ranks",
                       ["footprint 5x5 tiles (11.7 x 11.7 units)", "courtyard game x 1.8-5, y 1.8-5 empty of props",
                        "reads as a stone castle barracks, school/university style"]),
}


def main():
    names = sys.argv[1:] or list(SPECS)
    for name in names:
        size, center, summary, keep = SPECS[name]
        d = os.path.join(HERE, "art", "specs", "props", name)
        os.makedirs(d, exist_ok=True)
        path = os.path.join(d, name + ".yaml")
        s = spec(name, size, center, summary, keep)
        text = yaml.safe_dump(s, sort_keys=False, default_flow_style=None, width=140)
        first, rest = text.split("\n", 1)
        with open(path, "w") as fh:
            fh.write(first + "\n# Generated by tools/spritekiln/gen_barracks.py; edit the script, not this file.\n" + rest)
        print(path, sum(len(p["prims"]) for p in s["parts"].values()), "prims")


if __name__ == "__main__":
    main()
