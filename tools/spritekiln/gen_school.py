"""The school (E4 part 2): a medieval town school on a 3x3 plot (owner's references 2026-11-11).

A long hall at the back (game x 0.1-2.1, y 0.15-1.4): a ground floor of rubble stone with lighter
quoins, a jettied upper floor of half-timbering (posts, rails, K braces), a steep tiled roof with
flared eaves and a brick chimney. A front wing with its gable to the street (game x 1.0-2.0, out
to y 1.85) holds the arched door on the entrance's line (game x 1.5) with two stone steps, an
upper window and a little window high in the gable. At the right a square stone bell tower (game
x 2.25-2.95, y 0.55-1.25) with string courses and slit windows, an open timber belfry with arched
openings and a bronze bell inside, and a steep pyramid spire with a finial. In front: paving
stones and packed earth, a blackboard leaning by the door (the teacher's spot "board"), a bush at
the right. No pupils (owner 2026-11-11). The entrance tile (game 1, 2) stays free.

Game tile (gx, gy) of the 3x3 plot -> model: x = 3.515 - gy * 2.343, z = gx * 2.343 - 3.515
(with directions [se]: +z = game +x, +x = game -y; origin = plot centre).

Writes art/specs/props/school/school.yaml; edit this script, not that file.
Run (inside tools/spritekiln): python3 gen_school.py, then
  cd art/specs/props/school && spritekiln render school.yaml
  python3 tools/spritekiln/export_building.py school     (from the repository root)
"""
import math
import os

import yaml

from gen_townhouses import materials as town_materials

HERE = os.path.dirname(os.path.abspath(__file__))
TILE = 2.343
HALF = 1.5 * TILE

STONE_H = 1.9        # ground floor (stone)
EAVE = 3.9           # top of the half-timbered upper floor
JET = 0.1            # the upper floor sticks out this much


def m(gx, gy, y=0.0):
    """Model point of game tile point (gx, gy) at height y."""
    return [HALF - gy * TILE, y, gx * TILE - HALF]


def r4(v):
    return [round(float(x), 4) for x in v] if isinstance(v, (list, tuple)) else round(float(v), 4)


def box(c, half, rot=None):
    d = {"c": r4(c), "half": r4(half)}
    if rot:
        d["rot"] = r4(rot)
    return {"box": d}


def cyl(a, b, r):
    return {"cylinder": {"a": r4(a), "b": r4(b), "r": r}}


class Parts(dict):
    def add(self, name, material, prim, **extra):
        p = self.setdefault(name, {"material": material, "prims": []})
        p.update(extra)
        p["prims"].append(prim)

    def paint(self, name, material, prims):
        self[name].setdefault("paint", []).append({"material": material, "prims": prims})


class Block:
    """A gabled block between game x gx0-gx1 and y gy0-gy1; ridge along the game's x axis
    (axis 'x') or y axis ('y'). Model extents: x from front (big gy) to back, z from gx0 to gx1."""

    def __init__(self, name, gx0, gx1, gy0, gy1, axis, ridge):
        self.n, self.axis, self.ridge = name, axis, ridge
        self.x0, self.x1 = m(0, gy1)[0], m(0, gy0)[0]     # x0 = front (lower left wall)
        self.z0, self.z1 = m(gx0, 0)[2], m(gx1, 0)[2]     # z1 = the lower right wall
        self.xc, self.zc = (self.x0 + self.x1) / 2, (self.z0 + self.z1) / 2
        self.hx, self.hz = (self.x1 - self.x0) / 2, (self.z1 - self.z0) / 2

    def build(self, parts):
        n = self.n
        # Stone ground floor with quoins.
        parts.add(f"{n}_stone", "stone", box([self.xc, STONE_H / 2, self.zc], [self.hx, STONE_H / 2, self.hz]))
        quoins = []
        for x in (self.x0, self.x1):
            for z in (self.z0, self.z1):
                for k in range(4):
                    y = 0.25 + k * 0.45
                    long_x = k % 2 == 0
                    quoins.append(box([x, y, z], [0.32 if long_x else 0.14, 0.17, 0.14 if long_x else 0.32]))
        parts.paint(f"{n}_stone", "sill_mat", quoins)
        parts[f"{n}_stone"].setdefault("paint", []).insert(0, {"material": "stone_dark", "spots": {
            "scale": 0.16, "density": 0.25, "seed": 7}})
        # The jetty beam and the upper floor with its gables (one extrusion of the cross-section).
        hx, hz = self.hx + JET, self.hz + JET
        parts.add(f"{n}_jetty", "timber", box([self.xc, STONE_H + 0.08, self.zc], [hx + 0.06, 0.09, hz + 0.06]))
        half_w = hx if self.axis == "x" else hz
        length = 2 * (hz if self.axis == "x" else hx)
        profile = [[-half_w, STONE_H + 0.17], [half_w, STONE_H + 0.17], [half_w, EAVE - 0.15], [0, self.ridge - 0.55],
                   [-half_w, EAVE - 0.15]]
        upper = {"extrude": {"c": r4([self.xc, 0, self.zc]), "depth": r4(length),
                             "profile": {"polygon": [r4(p) for p in profile]}}}
        if self.axis == "y":
            upper["extrude"]["rot"] = [0, 1.5708, 0]
        parts.add(f"{n}_upper", "plaster_cream", upper)
        # The roof: a flared chevron extruded along the ridge.
        o, t = 0.42, 0.2
        slope = (self.ridge - EAVE) / half_w
        k = half_w * 0.22
        outer = [[-half_w - o, EAVE - 0.2], [-half_w + k, EAVE + k * slope], [0, self.ridge],
                 [half_w - k, EAVE + k * slope], [half_w + o, EAVE - 0.2]]
        inner = [[p[0], p[1] - t] for p in reversed(outer)]
        roof = {"extrude": {"c": r4([self.xc, 0, self.zc]), "depth": r4(length + 0.5),
                            "profile": {"polygon": [r4(p) for p in outer + inner]}}}
        if self.axis == "y":
            roof["extrude"]["rot"] = [0, 1.5708, 0]
        parts.add(f"{n}_roof", "tile", roof)
        parts[f"{n}_roof"]["paint"] = [{"material": "tile_dark", "stripes": {"axis": "y", "period": 0.26,
                                                                             "width": 0.06, "offset": EAVE}}]


def timber_x(plane_x, z0, z1, y0, y1, posts, braces=True):
    """Beams on a face in the plane x = plane_x (the front, facing the lower left)."""
    out = [box([plane_x, y0 + 0.07, (z0 + z1) / 2], [0.07, 0.07, (z1 - z0) / 2]),
           box([plane_x, y1 - 0.07, (z0 + z1) / 2], [0.07, 0.07, (z1 - z0) / 2]),
           box([plane_x, (y0 + y1) / 2 + 0.1, (z0 + z1) / 2], [0.07, 0.05, (z1 - z0) / 2])]
    zs = [z0 + (z1 - z0) * i / posts for i in range(posts + 1)]
    for i, z in enumerate(zs):
        zz = min(max(z, z0 + 0.07), z1 - 0.07)
        out.append(box([plane_x, (y0 + y1) / 2, zz], [0.07, (y1 - y0) / 2, 0.07]))
        if braces and i < posts and i % 2 == 0:
            za, zb = zz, zs[i + 1]
            L = math.hypot(zb - za, y1 - y0 - 0.2)
            ang = math.atan2(y1 - y0 - 0.2, zb - za)
            out.append(box([plane_x, (y0 + y1) / 2, (za + zb) / 2], [0.07, 0.05, L / 2], rot=[-ang, 0, 0]))
    return out


def timber_z(plane_z, x0, x1, y0, y1, posts, braces=True):
    """Beams on a face in the plane z = plane_z (facing the lower right)."""
    out = [box([(x0 + x1) / 2, y0 + 0.07, plane_z], [(x1 - x0) / 2, 0.07, 0.07]),
           box([(x0 + x1) / 2, y1 - 0.07, plane_z], [(x1 - x0) / 2, 0.07, 0.07])]
    xs = [x0 + (x1 - x0) * i / posts for i in range(posts + 1)]
    for i, x in enumerate(xs):
        xx = min(max(x, x0 + 0.07), x1 - 0.07)
        out.append(box([xx, (y0 + y1) / 2, plane_z], [0.07, (y1 - y0) / 2, 0.07]))
        if braces and i < posts and i % 2 == 1:
            xa, xb = xx, xs[i + 1]
            L = math.hypot(xb - xa, y1 - y0 - 0.2)
            ang = math.atan2(y1 - y0 - 0.2, xb - xa)
            out.append(box([(xa + xb) / 2, (y0 + y1) / 2, plane_z], [L / 2, 0.05, 0.07], rot=[0, 0, ang]))
    return out


def window_x(parts, x, z, y, w=0.36, h=0.6, shutters=True, arch=False):
    """A window in a front face (plane x), its glass a little proud of the wall."""
    parts.add("glass", "glass", box([x - 0.02, y, z], [0.04, h / 2, w / 2]))
    if arch:
        parts.add("glass", "glass", cyl([x - 0.06, y + h / 2, z], [x + 0.02, y + h / 2, z], w / 2))
    parts.add("frames", "timber", box([x - 0.05, y - h / 2 - 0.04, z], [0.07, 0.04, w / 2 + 0.07]), priority=2)
    if shutters:
        for s in (-1, 1):
            parts.add("shutters", "shutter", box([x - 0.05, y, z + s * (w / 2 + 0.13)], [0.03, h / 2, 0.12]))


def window_z(parts, z, x, y, w=0.36, h=0.6, shutters=True):
    parts.add("glass", "glass", box([x, y, z + 0.02], [w / 2, h / 2, 0.04]))
    parts.add("frames", "timber", box([x, y - h / 2 - 0.04, z + 0.05], [w / 2 + 0.07, 0.04, 0.07]), priority=2)
    if shutters:
        for s in (-1, 1):
            parts.add("shutters", "shutter", box([x + s * (w / 2 + 0.13), y, z + 0.05], [0.12, h / 2, 0.03]))


def school():
    parts = Parts()
    # The ground: packed earth, paving stones in front of the door.
    parts.add("yard", "earth", box([0, 0.01, 0], [3.5, 0.01, 3.5]))
    parts.paint("yard", "cobble", [box(m(1.5, 2.3, 0.01), [1.3, 0.05, 1.1]), box(m(2.6, 1.6, 0.01), [0.5, 0.05, 0.45])])
    parts["yard"]["paint"].append({"material": "grass", "spots": {"scale": 0.15, "density": 0.32, "seed": 5}})
    parts["yard"]["paint"].append({"material": "cobble_dark", "spots": {"scale": 0.07, "density": 0.2, "seed": 2}})

    hall = Block("hall", 0.1, 2.15, 0.15, 1.4, "x", 6.1)
    wing = Block("wing", 1.0, 2.0, 0.9, 1.85, "y", 5.5)
    hall.build(parts)
    wing.build(parts)
    # Half-timbering on the visible faces of the upper floors.
    xf = hall.x0 - JET
    parts.paint("hall_upper", "timber", timber_x(xf, hall.z0 - JET, wing.z0 - JET, STONE_H + 0.17, EAVE, 3))
    wx = wing.x0 - JET
    beams = timber_x(wx, wing.z0 - JET, wing.z1 + JET, STONE_H + 0.17, EAVE, 4, braces=False)
    # The front gable: a collar beam, a king post and two struts.
    gtop = wing.ridge - 0.6
    beams += [box([wx, EAVE + 0.6, wing.zc], [0.07, 0.06, wing.hz * 0.62]),
              box([wx, (EAVE + gtop) / 2, wing.zc], [0.07, (gtop - EAVE) / 2, 0.07])]
    for s in (-1, 1):
        a = [EAVE, wing.zc + s * (wing.hz + JET - 0.1)]
        b = [EAVE + 0.6, wing.zc + s * 0.15]
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        ang = math.atan2(b[0] - a[0], b[1] - a[1])
        beams.append(box([wx, (a[0] + b[0]) / 2, (a[1] + b[1]) / 2], [0.07, 0.05, L / 2], rot=[-ang, 0, 0]))
    parts.paint("wing_upper", "timber", beams)
    zr = wing.z1 + JET
    parts.paint("wing_upper", "timber", timber_z(zr, wing.x0 - JET, wing.x1 + JET, STONE_H + 0.17, EAVE, 3))
    parts.paint("hall_upper", "timber", timber_z(hall.z1 + JET, hall.x0 - JET, wing.x1, STONE_H + 0.17, EAVE, 2))
    # The arched door with a stone surround and two steps.
    dz = m(1.5, 0)[2]
    dx = wing.x0
    parts.add("door_frame", "sill_mat", box([dx - 0.03, 0.75, dz], [0.06, 0.75, 0.58]))
    parts.add("door_frame", "sill_mat", cyl([dx - 0.09, 1.5, dz], [dx + 0.02, 1.5, dz], 0.58))
    parts.add("door", "door_wood", box([dx - 0.08, 0.72, dz], [0.04, 0.72, 0.42]), priority=2)
    parts.add("door", "door_wood", cyl([dx - 0.12, 1.44, dz], [dx - 0.04, 1.44, dz], 0.42), priority=2)
    parts["door"]["paint"] = [{"material": "ink", "stripes": {"axis": "z", "period": 0.28, "width": 0.055,
                                                              "offset": dz}}]
    parts.add("steps", "stone", box([dx - 0.25, 0.08, dz], [0.25, 0.08, 0.72]))
    parts.add("steps", "stone", box([dx - 0.55, 0.04, dz], [0.25, 0.04, 0.82]))
    # Windows.
    window_x(parts, wx, dz, STONE_H + 1.05, w=0.5, h=0.7)
    window_x(parts, wx, dz, EAVE + 0.95, w=0.26, h=0.36, shutters=False)
    for gx in (0.42,):
        z = m(gx, 0)[2]
        window_x(parts, hall.x0, z, 1.05, w=0.3, h=0.5, shutters=False, arch=True)
        window_x(parts, xf, z, STONE_H + 1.05)
    window_z(parts, wing.z1 + JET, wing.xc, STONE_H + 1.05)
    window_z(parts, wing.z1, wing.xc, 1.0, w=0.3, h=0.5, shutters=False)
    # The chimney on the back slope.
    parts.add("chimney", "brick", box([hall.x1 - 0.6, 5.3, m(0.55, 0)[2]], [0.25, 1.3, 0.25]))
    parts.add("chimney", "brick", box([hall.x1 - 0.6, 6.6, m(0.55, 0)[2]], [0.3, 0.08, 0.3]))

    # The bell tower.
    tx0, tx1 = m(0, 1.25)[0], m(0, 0.55)[0]
    tz0, tz1 = m(2.25, 0)[2], m(2.95, 0)[2]
    txc, tzc, thx, thz = (tx0 + tx1) / 2, (tz0 + tz1) / 2, (tx1 - tx0) / 2, (tz1 - tz0) / 2
    shaft = 4.7
    parts.add("tower", "stone", box([txc, shaft / 2, tzc], [thx, shaft / 2, thz]))
    tq = []
    for x in (tx0, tx1):
        for z in (tz0, tz1):
            for k in range(10):
                y = 0.25 + k * 0.46
                lx = k % 2 == 0
                tq.append(box([x, y, z], [0.3 if lx else 0.13, 0.17, 0.13 if lx else 0.3]))
    parts["tower"]["paint"] = [{"material": "stone_dark", "spots": {"scale": 0.16, "density": 0.25, "seed": 9}},
                               {"material": "sill_mat", "prims": tq}]
    for y in (0.3, 2.5, shaft - 0.08):
        parts.add("courses", "sill_mat", box([txc, y, tzc], [thx + 0.08, 0.1 if y > 1 else 0.3, thz + 0.08]))
    for y in (1.6, 3.4):
        parts.add("slits", "ink", box([tx0 - 0.02, y, tzc], [0.04, 0.3, 0.07]))
        parts.add("slits", "ink", box([txc, y, tz1 + 0.02], [0.07, 0.3, 0.04]))
    # The open timber belfry: corner posts on a floor, arched openings, the bell inside.
    b0, b1 = shaft + 0.1, shaft + 2.0
    posts = []
    for x in (tx0 + 0.12, tx1 - 0.12):
        for z in (tz0 + 0.12, tz1 - 0.12):
            posts.append(cyl([x, b0, z], [x, b1, z], 0.12))
    parts["belfry"] = {"material": "timber", "prims": posts}
    parts.add("belfry_rail", "timber", box([txc, b0 + 0.45, tzc], [thx, 0.06, thz]))
    parts.add("belfry_head", "timber", box([txc, b1 - 0.12, tzc], [thx + 0.04, 0.12, thz + 0.04]))
    # Arched heads of the openings on the two faces seen: a plank with a round hole.
    parts["belfry_arch"] = {"material": "timber", "prims": [
        box([tx0 + 0.06, b1 - 0.45, tzc], [0.05, 0.3, thz - 0.1]),
        box([txc, b1 - 0.45, tz1 - 0.06], [thx - 0.1, 0.3, 0.05])],
        "cut": [{"cylinder": {"a": r4([tx0 - 0.2, b1 - 0.75, tzc]), "b": r4([tx0 + 0.3, b1 - 0.75, tzc]), "r": thz - 0.25}},
                {"cylinder": {"a": r4([txc, b1 - 0.75, tz1 - 0.3]), "b": r4([txc, b1 - 0.75, tz1 + 0.2]), "r": thx - 0.25}}]}
    parts.add("bell_inside", "ink", box([txc + 0.25, (b0 + b1) / 2, tzc - 0.25], [thx - 0.4, 0.85, thz - 0.4]))
    parts.add("bell", "bronze", {"cone": {"a": r4([txc, b0 + 0.6, tzc]), "b": r4([txc, b0 + 1.3, tzc]),
                                          "r": [0.42, 0.2]}}, priority=2)
    parts.add("bell", "bronze", {"sphere": {"c": r4([txc, b0 + 1.33, tzc]), "r": 0.2}})
    parts.add("yoke", "timber", box([txc, b0 + 1.55, tzc], [0.08, 0.08, thz - 0.05]))
    # The spire: a tent with flared eaves, cut by two slanted planes into a pyramid.
    a = thx + 0.22
    hgt = 3.3
    sb = b1
    prof = [[-a, sb - 0.05], [-a + 0.3, sb + 0.25], [0, sb + hgt], [a - 0.3, sb + 0.25], [a, sb - 0.05],
            [a - 0.1, sb - 0.2], [-a + 0.1, sb - 0.2]]
    cut = [{"plane": {"n": r4([0, a, hgt]), "c": r4([txc, sb, tzc + a])}},
           {"plane": {"n": r4([0, a, -hgt]), "c": r4([txc, sb, tzc - a])}}]
    parts["spire"] = {"material": "tile", "prims": [{"extrude": {"c": r4([txc, 0, tzc]), "depth": r4(2 * a),
                                                                 "profile": {"polygon": [r4(p) for p in prof]}}}],
                      "cut": cut,
                      "paint": [{"material": "tile_dark", "stripes": {"axis": "y", "period": 0.24, "width": 0.06,
                                                                      "offset": sb}}]}
    parts.add("finial", "bronze", cyl([txc, sb + hgt - 0.2, tzc], [txc, sb + hgt + 0.45, tzc], 0.05),
              priority=3, min_cover=1)
    parts.add("finial", "bronze", {"sphere": {"c": r4([txc, sb + hgt + 0.25, tzc]), "r": 0.09}})

    # A blackboard leaning by the door, a bush at the right corner.
    bb = m(0.42, 1.62)
    parts.add("board", "slate_board", box([bb[0], 0.75, bb[2]], [0.06, 0.55, 0.42], rot=[0, 0, -0.18]))
    parts.paint("board", "chalk", [box([bb[0] - 0.07, 0.95, bb[2] - 0.1], [0.06, 0.02, 0.2]),
                                   box([bb[0] - 0.07, 0.75, bb[2] + 0.05], [0.06, 0.02, 0.28]),
                                   box([bb[0] - 0.07, 0.55, bb[2] - 0.05], [0.06, 0.02, 0.22])])
    parts.add("board_frame", "post", box([bb[0] + 0.02, 0.75, bb[2]], [0.05, 0.6, 0.48], rot=[0, 0, -0.18]))
    t = m(2.75, 2.7)
    parts.add("bush", "leaves", {"ellipsoid": {"c": r4([t[0], 0.42, t[2]]), "r": [0.5, 0.45, 0.5]}})
    parts.add("bush", "leaves", {"ellipsoid": {"c": r4([t[0] + 0.45, 0.32, t[2] - 0.38]), "r": [0.36, 0.32, 0.36]}})
    return parts


def materials():
    mats = town_materials()
    mats.update({
        "earth": {"ramp": "earth", "outline": False},
        "grass": {"ramp": "grass", "outline": False},
        "stone_dark": {"ramp": "stone", "bands": [1, 2], "outline": False},
        "post": {"ramp": "log", "bands": [1, 4]},
        "slate_board": {"ramp": "board", "bands": [1, 2], "line": False},
        "chalk": {"ramp": "chalk", "bands": [3, 4], "outline": False},
        "bronze": {"ramp": "bronze", "finish": "metal"},
        "leaves": {"ramp": "leaves", "bands": [1, 4]},
    })
    return mats


def spec():
    return {
        "spritekiln": 1,
        "name": "school",
        "render": {"outline": "dark", "lines": "depth+normal", "light": "classic", "shading": "toon"},
        "kind": "prop",
        "size": 320,
        "directions": ["se"],
        "palette": ["../../palettes/kingdom.yaml", "../../palettes/town.yaml"],
        "camera": {"pitch": 30, "scale": 0.05176, "center": [0, 3.4, 0]},
        "shadow": None,
        "ramps": {
            "earth": ["#16120e", "#3a3028", "#54463a", "#6c5c4c", "#86745f"],
            "grass": ["#0e160a", "#24361a", "#3a5226", "#4f6c32", "#68883f"],
            "board": ["#08100c", "#1a2a22", "#2a3e32", "#3a5244"],
            "chalk": ["#5c5c58", "#8c8c86", "#b8b8b0", "#dcdcd4", "#f0f0e8"],
            "bronze": ["#1a1006", "#4a3010", "#7a5418", "#a87a2a", "#d0a448", "#ecca78"],
            "leaves": ["#0a1408", "#1e3414", "#30501e", "#46702a", "#5e8c36", "#7aa648"],
        },
        "brief": {"summary": "Your Kingdom school (E4 part 2), 3x3 tiles, medieval (owner's references): a hall "
                             "with a stone ground floor and a jettied half-timbered upper floor under a steep "
                             "flared tiled roof, a front gable wing with an arched door and steps, a square stone "
                             "bell tower with an open timber belfry, a bronze bell and a pyramid spire",
                  "must_keep": ["footprint 3x3 tiles (7.03 x 7.03 units)",
                                "entrance tile (game 1, 2) and the steps to the door free",
                                "reads as medieval: stone, half-timbering, steep roofs, the bell tower"]},
        "materials": materials(),
        "channels": {},
        "bones": {},
        "parts": dict(school()),
        "animations": {"idle": {"frames": 1, "ms": 500, "channels": {}}},
    }


def main():
    d = os.path.join(HERE, "art", "specs", "props", "school")
    os.makedirs(d, exist_ok=True)
    path = os.path.join(d, "school.yaml")
    s = spec()
    text = yaml.safe_dump(s, sort_keys=False, default_flow_style=None, width=140)
    first, rest = text.split("\n", 1)
    with open(path, "w") as fh:
        fh.write(first + "\n# Generated by tools/spritekiln/gen_school.py; edit the script, not this file.\n" + rest)
    print(path, sum(len(p["prims"]) for p in s["parts"].values()), "prims")


if __name__ == "__main__":
    main()
