"""The university (E4 part 3): a medieval college on a 4x4 plot, in the school's style (gen_school.py).

At the back a long stone hall (game x 0.2-3.0, y 0.2-1.4) with tall arched windows and a steep
tiled roof; in front of it, to the left, a half-timbered wing with its gable to the street
(game x 0.6-2.4, out to y 3.0) and the arched door on the entrance's line (game x 1.5) with
steps. To the right the cloister: a courtyard with grass and a little well, an arcade of
columns under a lean-to roof along the hall and the wing, two lecterns under it (the scholars'
"desk_1", "desk_2"), a low wall with a gateway at the front and right. At the back right a tall
library tower of stone with a clock face and a slate spire. The entrance tile (game 1, 3) stays free.

Game tile (gx, gy) of the 4x4 plot -> model: x = 4.686 - gy * 2.343, z = gx * 2.343 - 4.686.

Writes art/specs/props/university/university.yaml; edit this script, not that file.
Run (inside tools/spritekiln): python3 gen_university.py, then
  cd art/specs/props/university && spritekiln render university.yaml
  python3 tools/spritekiln/export_building.py university     (from the repository root)
"""
import math
import os

import yaml

import gen_school as gs
from gen_school import Block, Parts, box, cyl, r4, timber_x, timber_z, window_x, window_z, STONE_H, EAVE, JET

HERE = os.path.dirname(os.path.abspath(__file__))
TILE = gs.TILE
gs.HALF = 2.0 * TILE      # the helpers of gen_school map game tiles for a 4x4 plot now
m = gs.m


def arch_window(parts, x, z, y, w=0.4, h=1.0):
    """A tall arched window in a front face (plane x)."""
    parts.add("glass", "glass", box([x - 0.02, y, z], [0.04, h / 2, w / 2]))
    parts.add("glass", "glass", cyl([x - 0.06, y + h / 2, z], [x + 0.02, y + h / 2, z], w / 2))
    parts.add("frames", "sill_mat", box([x - 0.06, y - h / 2 - 0.05, z], [0.08, 0.05, w / 2 + 0.08]), priority=2)


def university():
    parts = Parts()
    parts.add("yard", "earth", box([0, 0.01, 0], [4.69, 0.01, 4.69]))
    parts.paint("yard", "cobble", [box(m(1.5, 3.5, 0.01), [1.3, 0.05, 1.2])])
    parts["yard"]["paint"].append({"material": "grass", "spots": {"scale": 0.15, "density": 0.3, "seed": 4}})
    parts["yard"]["paint"].append({"material": "cobble_dark", "spots": {"scale": 0.07, "density": 0.2, "seed": 6}})

    hall = Block("hall", 0.2, 3.0, 0.2, 1.4, "x", 6.3)
    wing = Block("wing", 0.6, 2.4, 1.3, 3.0, "y", 6.0)
    hall.build(parts)
    wing.build(parts)
    # The hall is all stone (a college): stone upper floor, a stone string course.
    parts["hall_upper"]["material"] = "stone"
    parts["hall_upper"]["paint"] = [{"material": "stone_dark", "spots": {"scale": 0.16, "density": 0.25, "seed": 3}}]
    parts["hall_jetty"]["material"] = "sill_mat"
    parts["wing_upper"]["material"] = "plaster_ochre"
    # Tall arched windows in the hall's front (left of the wing) on both floors.
    for gx in (0.38,):
        z = m(gx, 0)[2]
        arch_window(parts, hall.x0, z, 0.95, w=0.36, h=0.8)
        arch_window(parts, hall.x0 - JET, z, STONE_H + 0.95, w=0.36, h=0.9)
    # Upper windows of the hall above the cloister roof.
    for gx in (2.65,):
        z = m(gx, 0)[2]
        arch_window(parts, hall.x0 - JET, z, STONE_H + 1.0, w=0.36, h=0.9)
    # Half-timbering of the wing: the front gable and the side over the cloister.
    wx = wing.x0 - JET
    beams = timber_x(wx, wing.z0 - JET, wing.z1 + JET, STONE_H + 0.17, EAVE, 4, braces=False)
    gtop = wing.ridge - 0.6
    beams += [box([wx, EAVE + 0.7, wing.zc], [0.07, 0.06, wing.hz * 0.62]),
              box([wx, (EAVE + gtop) / 2, wing.zc], [0.07, (gtop - EAVE) / 2, 0.07])]
    for s in (-1, 1):
        a = [EAVE, wing.zc + s * (wing.hz + JET - 0.1)]
        b = [EAVE + 0.7, wing.zc + s * 0.15]
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        ang = math.atan2(b[0] - a[0], b[1] - a[1])
        beams.append(box([wx, (a[0] + b[0]) / 2, (a[1] + b[1]) / 2], [0.07, 0.05, L / 2], rot=[-ang, 0, 0]))
    parts.paint("wing_upper", "timber", beams)
    parts.paint("wing_upper", "timber", timber_z(wing.z1 + JET, wing.x0 - JET, wing.x1 + JET, STONE_H + 0.17, EAVE, 4))
    # The arched door with steps, windows of the wing.
    dz = m(1.5, 0)[2]
    dx = wing.x0
    parts.add("door_frame", "sill_mat", box([dx - 0.03, 0.8, dz], [0.06, 0.8, 0.62]))
    parts.add("door_frame", "sill_mat", cyl([dx - 0.09, 1.6, dz], [dx + 0.02, 1.6, dz], 0.62))
    parts.add("door", "door_wood", box([dx - 0.08, 0.76, dz], [0.04, 0.76, 0.46]), priority=2)
    parts.add("door", "door_wood", cyl([dx - 0.12, 1.52, dz], [dx - 0.04, 1.52, dz], 0.46), priority=2)
    parts["door"]["paint"] = [{"material": "ink", "stripes": {"axis": "z", "period": 0.3, "width": 0.055,
                                                              "offset": dz}}]
    parts.add("steps", "stone", box([dx - 0.25, 0.08, dz], [0.25, 0.08, 0.78]))
    parts.add("steps", "stone", box([dx - 0.55, 0.04, dz], [0.25, 0.04, 0.88]))
    for gx in (0.95, 2.05):
        window_x(parts, wx, m(gx, 0)[2], STONE_H + 1.05)
    window_x(parts, wx, dz, EAVE + 1.0, w=0.28, h=0.4, shutters=False)
    for gy in (1.8, 2.6):
        window_z(parts, wing.z1 + JET, m(0, gy)[0], STONE_H + 1.05)
    parts.add("chimney", "brick", box([hall.x1 - 0.7, 5.6, m(0.7, 0)[2]], [0.25, 1.3, 0.25]))
    parts.add("chimney", "brick", box([hall.x1 - 0.7, 6.9, m(0.7, 0)[2]], [0.3, 0.08, 0.3]))

    # The cloister: courtyard, an arcade along the hall and the wing, a low wall in front.
    cx0, cx1 = m(0, 3.75)[0], m(0, 1.4)[0]          # courtyard from the front wall to the hall
    cz0, cz1 = m(2.4, 0)[2], m(3.85, 0)[2]
    parts.add("court", "grass_mat", box([(cx0 + cx1) / 2 - 0.4, 0.03, (cz0 + cz1) / 2 + 0.2], [0.95, 0.03, 0.7]))
    arc_h = 2.0
    cols = []
    # Along the hall (columns at game y 1.95), along the wing (columns at game x 2.95).
    for gx in (2.95, 3.4, 3.85):
        p = m(gx, 1.95)
        cols.append(cyl([p[0], 0, p[2]], [p[0], arc_h, p[2]], 0.13))
    for gy in (2.45, 2.95):
        p = m(2.95, gy)
        cols.append(cyl([p[0], 0, p[2]], [p[0], arc_h, p[2]], 0.13))
    parts["columns"] = {"material": "sill_mat", "prims": cols}
    # Lean-to roofs: from the walls down to the columns.
    a0, a1 = m(0, 1.4)[0], m(0, 2.05)[0]
    slope = math.atan2(0.75, a0 - a1)
    roof = [box([(a0 + a1) / 2, arc_h + 0.45, (m(2.4, 0)[2] + cz1) / 2], [(a0 - a1) / 2 + 0.2, 0.09, (cz1 - m(2.4, 0)[2]) / 2 + 0.1],
                rot=[0, 0, -slope])]
    b0, b1 = m(2.4, 0)[2], m(3.05, 0)[2]
    slope2 = math.atan2(0.75, b1 - b0)
    r0, r1 = m(0, 2.05)[0], m(0, 3.15)[0]
    roof.append(box([(r0 + r1) / 2, arc_h + 0.45, (b0 + b1) / 2],
                    [(r0 - r1) / 2, 0.09, (b1 - b0) / 2 + 0.2], rot=[slope2, 0, 0]))
    parts["arcade_roof"] = {"material": "tile", "prims": roof,
                            "paint": [{"material": "tile_dark", "stripes": {"axis": "y", "period": 0.26, "width": 0.06,
                                                                          "offset": arc_h}}]}
    parts.add("arcade_beam", "timber", box([m(0, 1.95)[0], arc_h + 0.05, (m(2.85, 0)[2] + cz1) / 2],
                                           [0.1, 0.1, (cz1 - m(2.85, 0)[2]) / 2 + 0.1]))
    parts.add("arcade_beam", "timber", box([(m(0, 1.95)[0] + m(0, 3.05)[0]) / 2, arc_h + 0.05, m(2.95, 0)[2]],
                                           [(m(0, 1.95)[0] - m(0, 3.05)[0]) / 2, 0.1, 0.1]))
    # Two lecterns under the arcade with open books.
    for gx, gy in ((3.3, 1.7), (2.68, 2.7)):
        p = m(gx, gy)
        parts.add("lecterns", "post", cyl([p[0], 0, p[2]], [p[0], 0.85, p[2]], 0.06), priority=2)
        parts.add("lectern_tops", "plank", box([p[0], 0.92, p[2]], [0.22, 0.05, 0.28], rot=[0, 0, 0.35]))
        parts.add("books", "parchment", box([p[0] - 0.02, 1.0, p[2]], [0.16, 0.03, 0.22], rot=[0, 0, 0.35]))
    # The well in the courtyard.
    w = m(3.45, 2.75)
    parts.add("well", "stone", cyl([w[0], 0, w[2]], [w[0], 0.55, w[2]], 0.42))
    parts.add("well_water", "water", cyl([w[0], 0.5, w[2]], [w[0], 0.57, w[2]], 0.32))
    # A low wall along the front and the right of the cloister with a gateway.
    wall = []
    front_x = m(0, 3.75)[0]
    for z0, z1 in ((m(2.4, 0)[2], m(2.9, 0)[2]), (m(3.35, 0)[2], m(3.9, 0)[2])):
        wall.append(box([front_x, 0.4, (z0 + z1) / 2], [0.13, 0.4, (z1 - z0) / 2]))
    rz = m(3.9, 0)[2]
    wall.append(box([(m(0, 1.4)[0] + front_x) / 2, 0.4, rz], [(m(0, 1.4)[0] - front_x) / 2, 0.4, 0.13]))
    parts["low_wall"] = {"material": "stone", "prims": wall,
                         "paint": [{"material": "sill_mat", "prims": [box([front_x, 0.8, 0], [0.2, 0.06, 9]),
                                                                       box([0, 0.8, rz], [9, 0.06, 0.2])]}]}

    # The library tower with a clock and a slate spire.
    tx0, tx1 = m(0, 1.15)[0], m(0, 0.2)[0]
    tz0, tz1 = m(3.0, 0)[2], m(3.95, 0)[2]
    txc, tzc, thx, thz = (tx0 + tx1) / 2, (tz0 + tz1) / 2, (tx1 - tx0) / 2, (tz1 - tz0) / 2
    shaft = 7.4
    parts.add("tower", "stone", box([txc, shaft / 2, tzc], [thx, shaft / 2, thz]))
    tq = []
    for x in (tx0, tx1):
        for z in (tz0, tz1):
            for k in range(16):
                lx = k % 2 == 0
                tq.append(box([x, 0.25 + k * 0.46, z], [0.32 if lx else 0.14, 0.17, 0.14 if lx else 0.32]))
    parts["tower"]["paint"] = [{"material": "stone_dark", "spots": {"scale": 0.16, "density": 0.25, "seed": 8}},
                               {"material": "sill_mat", "prims": tq}]
    for y in (0.3, 3.2, shaft - 0.08):
        parts.add("courses", "sill_mat", box([txc, y, tzc], [thx + 0.08, 0.1 if y > 1 else 0.3, thz + 0.08]))
    for y in (4.3,):
        arch_window(parts, tx0, tzc, y, w=0.3, h=0.8)
    parts.add("slits", "ink", box([txc, 4.3, tz1 + 0.02], [0.07, 0.35, 0.04]))
    # The clock on the front face (game +x side, plane z = tz1).
    cy = shaft - 1.0
    parts.add("clock", "parchment", cyl([txc, cy, tz1 - 0.02], [txc, cy, tz1 + 0.07], 0.55), priority=2)
    parts.add("clock_rim", "sill_mat", {"torus": {"c": r4([txc, cy, tz1 + 0.05]), "R": 0.56, "r": 0.06,
                                                  "rot": [1.5708, 0, 0]}}, priority=2)
    parts.add("clock_hands", "ink", box([txc, cy + 0.18, tz1 + 0.09], [0.04, 0.2, 0.02]), priority=3)
    parts.add("clock_hands", "ink", box([txc + 0.13, cy + 0.06, tz1 + 0.09], [0.15, 0.04, 0.02], rot=[0, 0, -0.5]),
              priority=3)
    # The spire: a pyramid with flared eaves (as on the school's belfry).
    a = thx + 0.3
    hgt = 3.6
    sb = shaft
    prof = [[-a, sb - 0.05], [-a + 0.3, sb + 0.28], [0, sb + hgt], [a - 0.3, sb + 0.28], [a, sb - 0.05],
            [a - 0.1, sb - 0.2], [-a + 0.1, sb - 0.2]]
    cut = [{"plane": {"n": r4([0, a, hgt]), "c": r4([txc, sb, tzc + a])}},
           {"plane": {"n": r4([0, a, -hgt]), "c": r4([txc, sb, tzc - a])}}]
    parts["spire"] = {"material": "slate", "prims": [{"extrude": {"c": r4([txc, 0, tzc]), "depth": r4(2 * a),
                                                                  "profile": {"polygon": [r4(p) for p in prof]}}}],
                      "cut": cut,
                      "paint": [{"material": "slate_dark", "stripes": {"axis": "y", "period": 0.24, "width": 0.06,
                                                                       "offset": sb}}]}
    parts.add("finial", "bronze", cyl([txc, sb + hgt - 0.2, tzc], [txc, sb + hgt + 0.5, tzc], 0.05),
              priority=3, min_cover=1)
    parts.add("finial", "bronze", {"sphere": {"c": r4([txc, sb + hgt + 0.28, tzc]), "r": 0.09}})
    # A bush by the front.
    t = m(0.35, 3.6)
    parts.add("bush", "leaves", {"ellipsoid": {"c": r4([t[0], 0.42, t[2]]), "r": [0.5, 0.45, 0.5]}})
    return parts


def materials():
    mats = gs.materials()
    mats.update({
        "grass_mat": {"ramp": "grass", "bands": [2, 4], "outline": False},
        "parchment": {"ramp": "chalk", "bands": [3, 4]},
        "plank": {"ramp": "wood", "bands": [2, 5]},
        "water": {"ramp": "water", "bands": [2, 4], "outline": False},
    })
    return mats


def spec():
    s = gs.spec()
    s["name"] = "university"
    s["size"] = 384
    s["camera"] = {"pitch": 30, "scale": 0.05176, "center": [0, 3.8, 0]}
    s["ramps"]["water"] = ["#06121c", "#123048", "#1e4a68", "#2e6a8c", "#4a8cac"]
    s["brief"] = {"summary": "Your Kingdom university (E4 part 3), 4x4 tiles, medieval like the school: a stone hall "
                             "with tall arched windows, a half-timbered front wing with the arched door, a cloister "
                             "with an arcade, lecterns and a well, a tall stone library tower with a clock and a "
                             "slate spire",
                  "must_keep": ["footprint 4x4 tiles (9.37 x 9.37 units)",
                                "entrance tile (game 1, 3) and the steps to the door free",
                                "reads as a medieval college: stone, cloister, clock tower"]}
    s["materials"] = materials()
    s["parts"] = dict(university())
    return s


def main():
    d = os.path.join(HERE, "art", "specs", "props", "university")
    os.makedirs(d, exist_ok=True)
    path = os.path.join(d, "university.yaml")
    s = spec()
    text = yaml.safe_dump(s, sort_keys=False, default_flow_style=None, width=140)
    first, rest = text.split("\n", 1)
    with open(path, "w") as fh:
        fh.write(first + "\n# Generated by tools/spritekiln/gen_university.py; edit the script, not this file.\n" + rest)
    print(path, sum(len(p["prims"]) for p in s["parts"].values()), "prims")


if __name__ == "__main__":
    main()
