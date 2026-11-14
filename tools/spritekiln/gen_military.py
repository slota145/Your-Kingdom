"""G3 part 5b: the military workshops from SpriteKiln (ROADMAP G3, "Część 5, plan").

Each designed anew (very detailed and clearly medieval, like parts 3 to 5a): the armourer, the
bowyer, the armoury and the siege workshop. Same kit, spec head, stages and writer as the harbour
(gen_port.py). Sizes, entrances and rules unchanged; the workers' spots (forge, bench) moved to
the new work places.

Writes art/specs/props/<id>/<id>.yaml, <id>_c1.yaml, <id>_c2.yaml; edit this script.
Run (inside tools/spritekiln): python3 gen_military.py [<id>...], then build_port.sh-like:
tools/spritekiln/build_military.sh <id>...
"""
import math
import sys

import gen_port as GP
import gen_town as TOWN
import workshop_kit as K
from workshop_kit import Gable, Parts, Plot, box, cone, cyl, ell, ext, plane, sph, tor


# --- emblems and small military things -----------------------------------------------------------
def emblem_helmet(p, c):
    x, y, z = c
    p.add("emblem", "steel", sph([x, y + 0.02, z + 0.02], 0.11), "wall", priority=2)
    p.cut("emblem", plane([0, -1, 0], [0, y - 0.02, 0]))
    p.add("emblem_rim", "steel", box([x, y - 0.03, z + 0.03], [0.14, 0.02, 0.02]), "wall", priority=3)
    p.add("emblem_rim", "steel", box([x, y - 0.08, z + 0.05], [0.015, 0.06, 0.015]), "wall", priority=3)


def emblem_bow(p, c):
    x, y, z = c
    p.add("emblem", "haft", tor([x - 0.05, y, z + 0.02], 0.15, 0.018, rot=[1.5708, 0, 0]), "wall", priority=2)
    p.cut("emblem", plane([1, 0, 0], [x - 0.02, 0, 0]))
    p.add("emblem_string", "rope", box([x - 0.03, y, z + 0.03], [0.008, 0.15, 0.008]), "wall", priority=3)
    p.add("emblem_arrow", "iron", box([x + 0.02, y, z + 0.03], [0.1, 0.01, 0.01]), "wall", priority=3)


def helmet(p, P, gx, gy, y, name="helmets", r=0.11):
    x, _, z = P.m(gx, gy)
    p.add(name, "steel", sph([x, y, z], r), "prop")
    p.cut(name, plane([0, -1, 0], [0, y - r * 0.15, 0]))
    p.add(name + "_rim", "steel", tor([x, y - r * 0.15, z], r * 1.05, 0.02), "prop")
    p.add(name + "_nasal", "steel", box([x, y - r * 0.45, z + r * 0.9], [0.015, r * 0.35, 0.012]), "prop", priority=2)


def armour_stand(p, P, gx, gy, name="stand"):
    """A wooden stand with a mail shirt, a red surcoat over it and a helmet on top."""
    x, _, z = P.m(gx, gy)
    p.add(name, "post", cyl([x, 0, z], [x, 1.25, z], 0.03), "prop")
    p.add(name, "post", box([x, 0.03, z], [0.18, 0.03, 0.18]), "prop")
    p.add(name, "post", box([x, 1.1, z], [0.04, 0.03, 0.24]), "prop")
    p.add(name + "_mail", "steel", ell([x, 0.85, z], [0.14, 0.32, 0.22]), "prop")
    p.paint(name + "_mail", "iron", stripes={"axis": "y", "period": 0.06, "width": 0.055})
    p.add(name + "_coat", "cloth_red", box([x - 0.12, 0.78, z], [0.03, 0.25, 0.16]), "prop", priority=2)
    p.add(name + "_cross", "gilt", box([x - 0.16, 0.85, z], [0.01, 0.12, 0.025]), "prop", priority=3)
    p.add(name + "_cross", "gilt", box([x - 0.16, 0.88, z], [0.01, 0.025, 0.08]), "prop", priority=3)
    helmet(p, P, gx, gy, 1.36, name=name + "_helm", r=0.12)


def shield(p, x, y, z, mat="cloth_red", name="shields", face="-x", r=0.2, charge="gilt"):
    """A kite-ish round-topped shield hung flat on a face (face '-x': the left face, '+z': right)."""
    rot = [0, 0, 1.5708] if face == "-x" else [1.5708, 0, 0]
    p.add(name, mat, cyl([x, y, z], [x - 0.03, y, z] if face == "-x" else [x, y, z + 0.03], r), "wall")
    p.add(name + "_boss", "iron", sph([x - 0.04, y, z] if face == "-x" else [x, y, z + 0.04], r * 0.25), "wall", priority=2)
    p.add(name + "_charge", charge, box([x - 0.035, y, z] if face == "-x" else [x, y, z + 0.035],
                                        [0.01, r * 0.75, 0.03] if face == "-x" else [0.03, r * 0.75, 0.01]), "wall", priority=2)
    _ = rot


def spear_rack(p, P, gx0, gx1, gy, n=6, name="spear_rack", h=1.9):
    """A frame with spears standing upright along game x at gy."""
    a, b = P.m(gx0, gy), P.m(gx1, gy)
    for q in (a, b):
        p.add(name, "post", cyl([q[0], 0, q[2]], [q[0], 1.0, q[2]], 0.04), "prop")
    p.add(name, "post", cyl([a[0], 0.95, a[2]], [b[0], 0.95, b[2]], 0.03), "prop")
    p.add(name, "post", cyl([a[0], 0.2, a[2]], [b[0], 0.2, b[2]], 0.03), "prop")
    for k in range(n):
        t = (k + 0.5) / n
        x, z = a[0] + (b[0] - a[0]) * t, a[2] + (b[2] - a[2]) * t
        p.add(name + "_shafts", "haft", cyl([x, 0.05, z], [x, h, z], 0.018), "prop", priority=2)
        p.add(name + "_heads", "steel", cone([x, h, z], [x, h + 0.2, z], 0.035, 0.0), "prop", priority=2)


def bow_rack(p, x, z0, z1, y0, name="bow_rack"):
    """Bows hanging upright against a right face (plane x... model z range at model x)."""
    p.add(name, "post", box([x, y0 + 1.05, (z0 + z1) / 2], [0.03, 0.03, (z1 - z0) / 2 + 0.05]), "wall")
    n = 4
    for k in range(n):
        z = z0 + (z1 - z0) * (k + 0.5) / n
        p.add(name + "_bows", "haft", tor([x, y0 + 0.62, z - 0.06], 0.45, 0.02, rot=[0, 0, 1.5708]), "wall", priority=2)
        p.cut(name + "_bows", plane([0, 0, -1], [0, 0, z - 0.04]))
        p.add(name + "_strings", "rope", cyl([x, y0 + 0.2, z - 0.04], [x, y0 + 1.05, z - 0.04], 0.008), "wall", priority=3,
              min_cover=1)


def grindstone(p, P, gx, gy, name="grindstone"):
    x, _, z = P.m(gx, gy)
    for s in (-1, 1):
        p.add(name + "_frame", "post", box([x + s * 0.12, 0.3, z], [0.03, 0.3, 0.2]), "prop")
    p.add(name, "stone", cyl([x - 0.08, 0.5, z], [x + 0.08, 0.5, z], 0.26), "prop")
    p.add(name + "_axle", "iron", cyl([x - 0.22, 0.5, z], [x + 0.26, 0.5, z], 0.025), "prop")
    p.add(name + "_crank", "iron", box([x + 0.26, 0.42, z + 0.05], [0.015, 0.09, 0.015]), "prop", priority=2)
    p.add(name + "_trough", "barrel", box([x, 0.1, z], [0.1, 0.1, 0.22]), "prop")


def workbench(p, P, gx, gy, along="gx", name="bench", h=0.62, L=0.42, W_=0.2):
    x, _, z = P.m(gx, gy)
    half = [W_, 0.04, L] if along == "gx" else [L, 0.04, W_]
    p.add(name, "board", box([x, h, z], half), "prop")
    for sx in (-1, 1):
        for sz in (-1, 1):
            p.add(name + "_legs", "post", box([x + sx * (half[0] - 0.04), h / 2, z + sz * (half[2] - 0.04)], [0.03, h / 2, 0.03]), "prop")
    return [x, h + 0.04, z]


# =================================================================================================
# Armourer (2x2, door in the right face; the chainmail is stacked on the yard tile (1, 0)): a narrow
# house, fieldstone below and ochre half-timbering above under red tiles with a chimney; a brick
# forge with a glowing hearth under its own little roof out of the right face, bellows; a heavy
# bench with a helmet and mail on it, an armour stand with a mail shirt, surcoat and helmet, a
# grindstone, shields on the wall, a helmet sign.
# =================================================================================================
def armourer():
    P, p = Plot(2), Parts()
    K.patch(p, "soot_ground", "charcoal", P, 1.3, 1.25, 0.2, 0.14, y=0.013)
    house = (0.1, 0.95, 0.1, 1.5)
    g, eave, top = K.house(p, P, "house", house, ground="fieldstone", ground_h=1.6, upper="plaster_ochre", upper_h=0.95,
                           axis="gy", rise=1.3, roof_mat="tile", roof_dark="tile_dark", posts=(3, 3), with_quoins=True)
    x0, x1, z0, z1 = P.rect(*house)
    tx0, tx1, tz0, tz1 = P.rect(*top)
    K.chimney(p, P, "chimney", 0.75, 1.15, 2.5, 4.3, w=0.22)
    # the forge out of the right face, under a pentice
    fx = P.m(0, 1.15)[0]
    p.add("forge", "brick", box([fx, 0.4, z1 + 0.3], [0.36, 0.4, 0.3]), "wall")
    p.paint("forge", "brick_line", stripes={"axis": "y", "period": 0.12, "width": 0.055})
    p.add("coals", "charcoal", box([fx, 0.82, z1 + 0.32], [0.28, 0.03, 0.2]), "wall")
    p.add("coals_glow", "flame", ell([fx, 0.85, z1 + 0.38], [0.15, 0.05, 0.1]), "wall")
    p.add("forge_hood", "brick", ext([fx, 0, z1 + 0.3], [[-0.36, 1.3], [0.36, 1.3], [0.16, 1.75], [-0.16, 1.75]], 0.6,
                                     rot=[0, 1.5708, 0]), "wall")
    K.lean_to(p, P, "pentice", (0.95, 1.4, 0.82, 1.48), "-gx", 1.55, 1.85, "tile", "tile_dark", over=0.1, posts=True)
    bx = fx + 0.52
    p.add("bellows", "leather", ext([bx, 0.8, z1 + 0.3], [[-0.28, -0.11], [0.22, -0.03], [0.22, 0.03], [-0.28, 0.11]], 0.32,
                                    rot=[0, 1.5708, 0]), "wall")
    p.add("bellows_arm", "post", cyl([bx + 0.28, 1.25, z1 + 0.3], [bx - 0.15, 1.0, z1 + 0.3], 0.03), "wall")
    K.door_right(p, P, "door", 0.45, z1, 0.2, w=0.48, h=1.0, arch=True, frame="sill_mat")
    K.window_left(p, P, 0.55, x0, 1.0, w=0.3, h=0.32, open_=False)
    K.window_left(p, P, 0.5, tx0, 2.05, w=0.28, h=0.3)
    K.window_right(p, P, 0.85, tz1, 2.05, w=0.26, h=0.28)
    K.sign_right(p, P, 0.15, z1, 1.5, emblem_helmet)
    for i, gx in enumerate((0.3, 0.7)):
        shield(p, x0 - 0.04, 1.25, P.m(gx, 0)[2], mat="cloth_blue" if i else "cloth_red")
    # the bench by the door: a helmet and a mail shirt, hammers; the armour stand and grindstone
    top_ = workbench(p, P, 1.75, 1.72, along="gy", L=0.32, W_=0.2)
    p.add("bench_mail", "steel", ell([top_[0] + 0.05, top_[1] + 0.04, top_[2] - 0.1], [0.14, 0.04, 0.14]), "prop")
    p.paint("bench_mail", "iron", stripes={"axis": "x", "period": 0.05, "width": 0.055})
    helmet(p, P, 1.72, 1.82, top_[1] + 0.09, name="bench_helm", r=0.09)
    p.add("bench_hammer", "haft", box([top_[0] - 0.08, top_[1] + 0.02, top_[2] + 0.18], [0.12, 0.015, 0.015]), "prop", priority=2)
    p.add("bench_hammer", "iron", box([top_[0] - 0.19, top_[1] + 0.03, top_[2] + 0.18], [0.03, 0.03, 0.04]), "prop")
    armour_stand(p, P, 0.4, 1.82)
    grindstone(p, P, 1.05, 1.88)
    K.tub(p, P, "quench", 1.85, 1.15, 0.15, 0.36, fill="water")
    p.spots = {"forge": (1.38, 1.15), "bench": (1.48, 1.72)}
    K.tufts(p, P, [(1.95, 0.6), (0.05, 1.97), (1.97, 1.97)])
    p.heap = (1.5, 0.5)
    return P, p, 240, 2.1


# =================================================================================================
# Bowyer (2x2, door in the right face; bows stacked on the yard tile (1, 0)): a log workshop under a
# steep shingle roof with deep eaves on the left face where yew staves hang drying in rows, bundles
# of staves leaning against the wall, a rack of strung bows on the right face, a shaving bench with
# a bow on it by the door, a straw target with painted rings on an easel, a barrel of arrows, a bow
# sign.
# =================================================================================================
def bowyer():
    P, p = Plot(2), Parts()
    house = (0.1, 0.95, 0.12, 1.4)
    K.plinth(p, P, "plinth", house, h=0.2, mat="fieldstone")
    K.log_walls(p, P, "walls", house, 0.2, 1.65, course=0.19)
    g = Gable(P, "house", house, "gy", 1.65, 3.0, over=0.5, end_over=0.24)
    g.infill(p, "board")
    g.gable_frame(p)
    g.roof(p, "shingle", "shingle_dark", course=0.12, spots=("moss", 0.1, 0.2, 31))
    g.bargeboards(p)
    p.footprints = [house]
    p.roofs = [g]
    x0, x1, z0, z1 = P.rect(*house)
    K.door_right(p, P, "door", 0.45, z1, 0.2, w=0.48, h=1.0, arch=False)
    K.window_left(p, P, 0.5, x0, 1.0, w=0.3, h=0.3)
    K.sign_right(p, P, 1.12, z1, 1.45, emblem_bow)
    K.chimney(p, P, "chimney", 0.3, 0.45, 2.0, 3.4, w=0.18, mat="fieldstone")
    p["chimney"]["paint"] = [{"material": "stone_dark", "spots": {"scale": 0.07, "density": 0.38, "seed": 9}}]
    # staves drying under the deep eaves of the left face: a pole with rows of hanging staves
    pole_x = x0 - 0.32
    p.add("stave_pole", "post", box([pole_x, 1.55, (z0 + z1) / 2], [0.03, 0.03, (z1 - z0) / 2 + 0.1]), "wall")
    for k in range(9):
        z = z0 + 0.08 + k * (z1 - z0 - 0.16) / 8
        p.add("staves", "split" if k % 2 else "haft", box([pole_x, 1.0, z], [0.02, 0.52, 0.025]), "wall", priority=2)
    for k in range(5):
        x, _, z = P.m(0.12 + k * 0.08, 1.62)
        p.add("stave_bundle", "haft", cyl([x, 0, z], [x - 0.12, 1.25, z + 0.02 * k], 0.025), "prop", priority=2)
    p.add("stave_bundle_tie", "rope", tor(P.m(0.28, 1.62, 0.6), 0.16, 0.02), "prop")
    bow_rack(p, z1 + 0.04, P.m(0, 0.25)[0], P.m(0, 1.0)[0], 0.25) if False else None
    # a rack of strung bows against the right face (planes of game x, model z)
    rx0, rx1 = P.m(0, 0.25)[0], P.m(0, 0.95)[0]
    p.add("bow_rack", "post", box([(rx0 + rx1) / 2, 1.3, z1 + 0.05], [abs(rx1 - rx0) / 2 + 0.05, 0.03, 0.03]), "wall")
    for k in range(4):
        x = rx0 + (rx1 - rx0) * (k + 0.5) / 4
        p.add("bows", "haft", tor([x, 0.85, z1 + 0.12], 0.4, 0.022, rot=[0, 1.5708, 1.5708]), "wall", priority=2)
        p.cut("bows", plane([0, 0, -1], [0, 0, z1 + 0.1]))
        p.add("bow_strings", "rope", cyl([x, 0.47, z1 + 0.1], [x, 1.23, z1 + 0.1], 0.008), "wall", priority=3, min_cover=1)
    # a shaving bench with a bow by the door, a straw target, a barrel of arrows
    top_ = workbench(p, P, 1.75, 1.6, along="gy", L=0.36, W_=0.16, h=0.55)
    a, b = [top_[0], top_[1] + 0.03, top_[2] - 0.32], [top_[0], top_[1] + 0.03, top_[2] + 0.32]
    p.add("bench_bow", "haft", cyl(a, b, 0.025), "prop", priority=2)
    p.add("bench_knife", "steel", box([top_[0] - 0.08, top_[1] + 0.02, top_[2]], [0.04, 0.01, 0.12]), "prop")
    tx, _, tz = P.m(0.55, 1.85)
    for s in (-1, 1):
        p.add("target_easel", "post", cyl([tx + 0.12, 0, tz + s * 0.3], [tx, 1.0, tz + s * 0.1], 0.03), "prop")
    p.add("target", "hay", cyl([tx - 0.02, 0.75, tz], [tx - 0.18, 0.72, tz], 0.36), "prop")
    p.paint("target", "cloth_red", rings={"axis": "x", "center": [tx, 0.74, tz], "period": 0.2, "width": 0.07})
    p.add("target_bull", "gilt", cyl([tx - 0.17, 0.72, tz], [tx - 0.19, 0.72, tz], 0.07), "prop", priority=2)
    for k, (dy, dz) in enumerate(((0.1, 0.05), (-0.12, -0.08), (0.02, 0.15))):
        p.add("target_arrows", "haft", cyl([tx - 0.18, 0.74 + dy, tz + dz], [tx - 0.45, 0.78 + dy, tz + dz + 0.03], 0.012), "prop",
              priority=2, min_cover=1)
    bx, _, bz = P.m(1.85, 1.05)
    p.add("arrow_barrel", "barrel", cyl([bx, 0, bz], [bx, 0.45, bz], 0.14), "prop")
    p.paint("arrow_barrel", "iron", stripes={"axis": "y", "at": [0.08, 0.38], "width": 0.055})
    for k in range(7):
        a = k * 0.9
        p.add("arrows", "haft", cyl([bx, 0.4, bz], [bx + 0.08 * math.cos(a), 0.78, bz + 0.08 * math.sin(a)], 0.01), "prop",
              priority=2, min_cover=1)
        p.add("fletching", "flour", sph([bx + 0.08 * math.cos(a), 0.78, bz + 0.08 * math.sin(a)], 0.025), "prop")
    p.spots = {"bench": (1.45, 1.6)}
    K.tufts(p, P, [(1.95, 0.6), (0.05, 1.97), (1.97, 1.97)])
    p.heap = (1.5, 0.5)
    return P, p, 240, 2.0


# =================================================================================================
# Armoury (3x3, door in the right face at game y 1.5): the king's arsenal, a stout two-storey hall of
# ashlar with quoins and a string course under a hipped slate roof with a little lantern turret,
# barred windows, an iron-bound double door in a round-arched portal with the kingdom's arms and two
# banners over it; a pentice on the right side over a rack of spears, shields stacked against the
# wall, a cart with bundled spears, a sentry box.
# =================================================================================================
def armoury():
    P, p = Plot(3), Parts()
    hall = (0.15, 2.0, 0.15, 2.8)
    K.plinth(p, P, "plinth", hall, h=0.3, mat="ashlar")
    K.walls(p, P, "walls", hall, 0.3, 3.2, "fieldstone")
    p.paint("walls", "stone_dark", spots={"scale": 0.07, "density": 0.42, "seed": 17})
    K.quoins(p, P, "quoins", hall, 0.3, 3.2)
    x0, x1, z0, z1 = P.rect(*hall)
    for gx in (0.75, 1.45):
        TOWN.buttress_left(p, P, gx, x0, 1.8, name="buttresses")
    TOWN.buttress_right(p, P, 0.7, z1, 1.8, name="buttresses")
    TOWN.buttress_right(p, P, 2.3, z1, 1.8, name="buttresses")
    p.add("string_course", "ashlar", box([(x0 + x1) / 2, 1.75, (z0 + z1) / 2], [(x1 - x0) / 2 + 0.05, 0.05, (z1 - z0) / 2 + 0.05]),
          "wall")
    K.hip_roof(p, P, "roof", hall, 3.2, 4.6, "slate", "slate_dark", over=0.22, course=0.14, along="gy",
               spots=("slate_light", 0.12, 0.2, 13))
    p.footprints = [hall]
    p.roofs = []
    # a lantern turret on the ridge with a little spire and a vane
    TOWN.spire(p, P, "turret_spire", (0.85, 1.3, 1.25, 1.7), 4.95, 0.9, mat="slate", dark="slate_dark", finial="gilt")
    K.walls(p, P, "turret", (0.88, 1.27, 1.28, 1.67), 4.3, 4.95, "timber")
    for gx, gy in ((1.07, 1.67), (1.27, 1.47)):
        x, _, z = P.m(gx, gy)
        p.add("turret_louvre", "dark_hole", box([x - 0.01 if gy > 1.6 else x, 4.62, z + (0.01 if gy < 1.6 else 0)],
                                                [0.02 if gy > 1.6 else 0.09, 0.15, 0.09 if gy > 1.6 else 0.02]), "wall", priority=2)
    # the portal with the arms and banners, in the right face at game y 1.5
    TOWN.portal_right(p, P, 1.5, z1, 0.3, w=0.78, h=1.15, pointed=False)
    xd = P.m(0, 1.5)[0]
    shield(p, xd, 2.25, z1 + 0.06, mat="cloth_red", face="+z", r=0.26)
    for gy in (1.05, 1.95):
        x = P.m(0, gy)[0]
        p.add("banners_pole", "iron", cyl([x, 2.6, z1 + 0.02], [x, 2.75, z1 + 0.45], 0.02), "wall", priority=2, min_cover=1)
        p.add("banners", "cloth_red", ext([x, 2.72, z1 + 0.42], [[-0.12, 0], [0.12, 0], [0.12, -0.7], [0, -0.56], [-0.12, -0.7]], 0.03),
              "wall")
        p.add("banners_charge", "gilt", sph([x, 2.35, z1 + 0.45], 0.06), "wall", priority=2)
    # barred windows on both faces, two storeys
    for gx in (0.5, 1.05, 1.6):
        for y in (1.15, 2.45):
            z = P.m(gx, 0)[2]
            p.add("windows", "dark_hole", box([x0 - 0.02, y, z], [0.03, 0.22, 0.13]), "wall", priority=2)
            p.add("window_frames", "ashlar_light", box([x0 - 0.02, y - 0.25, z], [0.05, 0.03, 0.18]), "wall")
            for dz in (-0.06, 0.06):
                p.add("window_bars", "iron", box([x0 - 0.06, y, z + dz], [0.012, 0.22, 0.012]), "wall", priority=3)
    for gy in (0.55, 2.4):
        for y in (1.15, 2.45):
            x = P.m(0, gy)[0]
            p.add("windows", "dark_hole", box([x, y, z1 + 0.02], [0.13, 0.22, 0.03]), "wall", priority=2)
            p.add("window_frames", "ashlar_light", box([x, y - 0.25, z1 + 0.02], [0.18, 0.03, 0.05]), "wall")
            for dx in (-0.06, 0.06):
                p.add("window_bars", "iron", box([x + dx, y, z1 + 0.06], [0.012, 0.22, 0.012]), "wall", priority=3)
    # on the right side: a pentice over a spear rack at the back, shields, a cart with spears, a sentry box
    K.lean_to(p, P, "pentice", (2.0, 2.85, 0.15, 0.9), "-gx", 1.9, 2.4, "shingle", "shingle_dark", over=0.12)
    spear_rack(p, P, 2.15, 2.75, 0.55, n=7, h=1.75)
    for k in range(3):
        x, _, z = P.m(2.15 + k * 0.03, 2.45 + k * 0.17)
        shield(p, x, 0.32, z1 + 0.08 + k * 0.03 if False else z, mat=("cloth_red", "cloth_blue", "cloth_red")[k], face="+z",
               r=0.24, name="leaning_shields")
    K.cart(p, P, 2.5, 2.55, yaw=1.57, name="cart")
    for k in range(5):
        a, b = P.m(2.2, 2.4 + k * 0.06, 0.75), P.m(2.8, 2.4 + k * 0.06, 0.82)
        p.add("cart_spears", "haft", cyl(a, b, 0.02), "prop", priority=2)
    p.add("cart_spears_tie", "rope", tor(P.m(2.5, 2.52, 0.78), 0.14, 0.02, rot=[1.5708, 0, 0]), "prop")
    K.tufts(p, P, [(2.95, 1.2), (0.05, 2.97), (2.95, 2.95)])
    p.heap = (2.5, 1.5)
    return P, p, 320, 2.7


# =================================================================================================
# Siege workshop (3x3, door at the right; the yard tile (2, 0) stays free): a great open timber shed
# on stout posts with braces under a steep shingle roof with king-post trusses showing in the gable,
# a board back wall with tools; inside a ram being built on trestles (the iron-headed beam, half the
# shed's rafters); outside a ballista's bow arms on a trestle, a big spoked wheel and spare wheels
# leaning, a windlass, squared timber, a lifting frame with a block.
# =================================================================================================
def siege_workshop():
    P, p = Plot(3), Parts()
    shed = (0.15, 1.95, 0.15, 2.85)
    x0, x1, z0, z1 = P.rect(*shed)
    g = Gable(P, "shed", shed, "gy", 2.6, 4.0, over=0.22, end_over=0.2)
    g.roof(p, "shingle", "shingle_dark", course=0.13, spots=("moss", 0.1, 0.2, 37))
    g.bargeboards(p)
    p.footprints = [shed]
    p.roofs = [g]
    # posts with knee braces along both long sides, tie beams and king posts in each bay
    for gy in (0.2, 1.05, 1.95, 2.8):
        x = P.m(0, gy)[0]
        for z in (z0 + 0.06, z1 - 0.06):
            p.add("posts", "timber", box([x, 1.3, z], [0.07, 1.3, 0.07]), "wall")
            s = 1 if z < 0 else -1
            p.add("braces", "timber", cyl([x, 2.05, z], [x, 2.55, z + s * 0.45], 0.04), "wall")
        p.add("ties", "timber", box([x, 2.57, (z0 + z1) / 2], [0.06, 0.06, (z1 - z0) / 2 + 0.05]), "wall")
        p.add("king_posts", "timber", box([x, 3.25, (z0 + z1) / 2], [0.05, 0.65, 0.05]), "wall")
        for s in (-1, 1):
            p.add("struts", "timber", cyl([x, 2.65, (z0 + z1) / 2], [x, 3.35, (z0 + z1) / 2 + s * 0.6], 0.035), "wall")
    for z in (z0 + 0.06, z1 - 0.06):
        p.add("plates", "timber", box([(x0 + x1) / 2, 2.6, z], [(x1 - x0) / 2 + 0.05, 0.06, 0.07]), "wall")
    K.board_walls(p, P, "back_wall", (0.15, 0.25, 0.15, 2.85), 0.0, 2.55)
    # tools on the back wall
    for k in range(4):
        x = P.m(0, 0.6 + k * 0.4)[0]
        zz = z0 + 0.15
        p.add("wall_tools", "haft", box([x, 1.2, zz], [0.02, 0.35, 0.02]), "wall", priority=2)
        p.add("wall_tools", "steel", box([x, 1.55 if k % 2 else 0.88, zz + 0.02], [0.08, 0.04, 0.02]), "wall")
    # the ram on trestles: a great beam with an iron head, half its roof frame, in the shed
    RX = 1.4
    a, b = P.m(RX, 0.55, 0.7), P.m(RX, 2.5, 0.7)
    for gy in (0.8, 2.2):
        tx, _, tz = P.m(RX, gy)
        for s in (-1, 1):
            p.add("trestles", "post", cyl([tx, 0, tz + s * 0.28], [tx, 0.6, tz], 0.04), "prop")
        p.add("trestles", "post", box([tx, 0.58, tz], [0.05, 0.04, 0.2]), "prop")
    p.add("ram_beam", "log_bark", cyl(a, b, 0.17), "prop")
    p.add("ram_head", "iron", cone([b[0], 0.7, b[2]], [b[0] - 0.35, 0.7, b[2]], 0.21, 0.12), "prop")
    p.add("ram_bands", "iron", tor([b[0] + 0.12, 0.7, b[2]], 0.18, 0.03, rot=[0, 0, 1.5708]), "prop")
    p.add("ram_bands", "iron", tor([a[0] - 0.4, 0.7, a[2]], 0.18, 0.03, rot=[0, 0, 1.5708]), "prop")
    for gy in (0.6, 1.1, 1.6):
        x, _, z = P.m(RX, gy)
        for s in (-1, 1):
            p.add("ram_rafters", "raw_timber", cyl([x, 0.0, z + s * 0.62], [x, 1.55, z], 0.045), "prop")
    p.add("ram_ridge", "raw_timber", cyl(P.m(RX, 0.6, 1.55), P.m(RX, 1.6, 1.55), 0.045), "prop")
    hx, _, hz = P.m(RX, 0.85)
    p.add("ram_hides", "leather", box([hx, 1.2, hz - 0.33], [0.32, 0.02, 0.3], rot=[0.0, 0.0, 0.0]), "prop")
    p.add("ram_hides", "leather", box([hx, 1.2, hz + 0.33], [0.32, 0.02, 0.3]), "prop")
    p.cut("ram_hides", box([hx, 1.2, hz], [0.4, 0.1, 0.03]))
    # outside: a big wheel and spare wheels leaning, a ballista's arms on a trestle, a windlass, timber
    for k, (gx, gy) in enumerate(((2.25, 2.15), (2.4, 2.35))):
        x, _, z = P.m(gx, gy)
        p.add("wheels", "timber", tor([x, 0.42, z], 0.38, 0.05, rot=[0, 0, 1.5708 - 0.25]), "prop")
        for i in range(4):
            ang = i * math.pi / 4
            p.add("wheel_spokes", "timber", cyl([x - 0.09 * math.sin(ang), 0.42 - 0.38 * math.cos(ang), z - 0.36 * math.sin(ang)],
                                                [x + 0.09 * math.sin(ang), 0.42 + 0.38 * math.cos(ang), z + 0.36 * math.sin(ang)], 0.025),
                  "prop")
        p.add("wheel_hubs", "iron", cyl([x - 0.08, 0.42, z], [x + 0.08, 0.42, z], 0.07), "prop")
    tx, _, tz = P.m(2.55, 2.75)
    for s in (-1, 1):
        p.add("arm_trestle", "post", cyl([tx + s * 0.2, 0, tz], [tx, 0.5, tz], 0.035), "prop")
    p.add("arm_trestle", "post", box([tx, 0.5, tz], [0.06, 0.04, 0.3]), "prop")
    p.add("ballista_arms", "haft", cyl([tx, 0.56, tz - 0.6], [tx, 0.6, tz + 0.6], 0.04), "prop")
    p.add("ballista_skein", "rope", cyl([tx, 0.45, tz], [tx, 0.72, tz], 0.09), "prop")
    p.add("ballista_bands", "iron", tor([tx, 0.6, tz - 0.45], 0.05, 0.015, rot=[1.5708, 0, 0]), "prop")
    for k in range(3):
        a2, b2 = P.m(2.2 + k * 0.17, 1.45, 0.09 + 0.17 * (k == 1)), P.m(2.2 + k * 0.17, 2.0, 0.09 + 0.17 * (k == 1))
        if k == 1:
            a2, b2 = P.m(2.3, 1.5, 0.27), P.m(2.6, 1.95, 0.27)
        p.add("timber_baulks", "raw_timber", box(list(map(lambda v, w: (v + w) / 2, a2, b2)),
                                                 [0.08, 0.08, abs(b2[2] - a2[2]) / 2 + 0.25] if k != 1 else [0.25, 0.08, 0.08]), "prop")
    GP.capstan(p, P, 2.6, 1.0, name="windlass")
    K.tufts(p, P, [(2.95, 0.4), (0.05, 2.97), (2.95, 2.95)])
    p.heap = (2.5, 0.5)
    return P, p, 320, 2.4


BUILDINGS = {
    "armourer": (armourer, "Your Kingdom armourer (G3 part 5b), 2x2 tiles: a narrow house, fieldstone and ochre half-"
                 "timbering under red tiles, a brick forge with a glowing hearth under a pentice, bellows, a bench with a "
                 "helmet and mail, an armour stand with mail, surcoat and helmet, a grindstone, shields, a helmet sign"),
    "bowyer": (bowyer, "Your Kingdom bowyer (G3 part 5b), 2x2 tiles: a log workshop under a steep shingle roof with deep "
               "eaves where yew staves hang drying, stave bundles, a rack of strung bows, a shaving bench with a bow, a "
               "straw target with arrows, a barrel of arrows, a bow sign"),
    "armoury": (armoury, "Your Kingdom armoury (G3 part 5b), 3x3 tiles: a stout two-storey ashlar arsenal with quoins "
                "under a hipped slate roof with a lantern turret, barred windows, a round-arched portal with the kingdom's "
                "arms and banners, a pentice over a spear rack, shields, a cart with bundled spears"),
    "siege_workshop": (siege_workshop, "Your Kingdom siege workshop (G3 part 5b), 3x3 tiles: a great open timber shed "
                       "with king-post trusses under shingles, a ram being built on trestles inside, spare wheels, a "
                       "ballista's arms on a trestle, a windlass, squared timber"),
}
ENTRANCES = {"armourer": (1, 1), "bowyer": (1, 1), "armoury": (2, 1), "siege_workshop": (2, 1)}


if __name__ == "__main__":
    GP.run(BUILDINGS, ENTRANCES, sys.argv[1:])
