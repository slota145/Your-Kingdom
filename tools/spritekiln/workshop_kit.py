"""Shared building blocks for the G3 part 3 workshops and raw-material buildings (gen_workshops.py).

Everything is placed in GAME coordinates of the plot: (gx, gy) in tiles from the plot's back corner,
y in model units up. Plot.m() turns them into model coordinates for the [se] view:
x = n*T/2 - gy*T, z = gx*T - n*T/2 (+z = game +x, the lower right face; -x = game +y, the lower
left face; origin = plot centre). The two faces the camera sees are the "left" face (gy = gy1, model
normal -x) and the "right" face (gx = gx1, model normal +z).

Parts carry a build layer so one model gives the finished building and its two construction stages
(ROADMAP G3 part 3): "ground" (yard), "found" (plinths, foundations), "wall", "roof", "prop"
(barrels, tools, stacks) and "site" (stakes, strings, scaffolding: only in the stages).
"""
import math

T = 2.343


def r4(v):
    if isinstance(v, (list, tuple)):
        return [round(float(x), 4) for x in v]
    return round(float(v), 4)


# --- primitives ---------------------------------------------------------------------------------
def box(c, half, rot=None, round_=None):
    d = {"c": r4(c), "half": r4(half)}
    if rot:
        d["rot"] = r4(rot)
    if round_:
        d["round"] = round_
    return {"box": d}


def cyl(a, b, r):
    return {"cylinder": {"a": r4(a), "b": r4(b), "r": r4(r)}}


def cone(a, b, r0, r1):
    return {"cone": {"a": r4(a), "b": r4(b), "r": [r4(r0), r4(r1)]}}


def sph(c, r):
    return {"sphere": {"c": r4(c), "r": r4(r)}}


def ell(c, r, rot=None):
    d = {"c": r4(c), "r": r4(r)}
    if rot:
        d["rot"] = r4(rot)
    return {"ellipsoid": d}


def tor(c, R, r, rot=None):
    d = {"c": r4(c), "R": r4(R), "r": r4(r)}
    if rot:
        d["rot"] = r4(rot)
    return {"torus": d}


def ext(c, poly, depth, rot=None):
    d = {"c": r4(c), "depth": r4(depth), "profile": {"polygon": [r4(p) for p in poly]}}
    if rot:
        d["rot"] = r4(rot)
    return {"extrude": d}


def plane(n, c):
    return {"plane": {"n": r4(n), "c": r4(c)}}


class Parts(dict):
    """name -> SpriteKiln part, plus a build layer per part (self.layer)."""

    def __init__(self):
        super().__init__()
        self.layer = {}
        self.footprints = []
        self.roofs = []
        self.plinths = []

    def add(self, name, material, prim, layer="prop", **extra):
        p = self.setdefault(name, {"material": material, "prims": []})
        p.update(extra)
        p["prims"].append(prim)
        self.layer.setdefault(name, layer)
        return p

    def cut(self, name, prim):
        self[name].setdefault("cut", []).append(prim)

    def paint(self, name, material, **kind):
        self[name].setdefault("paint", []).append(dict(material=material, **kind))


class Plot:
    def __init__(self, n):
        self.n = n
        self.h = n * T / 2

    def m(self, gx, gy, y=0.0):
        return [self.h - gy * T, y, gx * T - self.h]

    def rect(self, gx0, gx1, gy0, gy1):
        """Model (x0, x1, z0, z1) of a game rectangle; x0 is the left (front) face, z1 the right."""
        return self.h - gy1 * T, self.h - gy0 * T, gx0 * T - self.h, gx1 * T - self.h


# --- ground ---------------------------------------------------------------------------------------
def ground(P, parts, mat="earth", dark="earth_dark", seed=3):
    parts.add("yard", mat, box([0, 0.01, 0], [P.h - 0.02, 0.01, P.h - 0.02]), "ground")
    parts.paint("yard", dark, spots={"scale": 0.13, "density": 0.3, "seed": seed})


def patch(parts, name, mat, P, gx, gy, rx, rz, y=0.014):
    c = P.m(gx, gy, y)
    parts.add(name, mat, ell(c, [rz * T, 0.012, rx * T]), "ground")


def tufts(parts, P, pts, name="tufts", mat="grass_tuft"):
    """Little grass tufts (three blades each) at game points."""
    for gx, gy in pts:
        x, _, z = P.m(gx, gy)
        for dx, dz, h in ((0, 0, 0.22), (0.07, 0.05, 0.16), (-0.06, 0.04, 0.17)):
            parts.add(name, mat, cone([x + dx, 0, z + dz], [x + dx * 2, h, z + dz * 2], 0.05, 0.012), "ground",
                      min_cover=2)


def stones(parts, P, pts, name="pebbles", mat="stone"):
    for i, (gx, gy) in enumerate(pts):
        x, _, z = P.m(gx, gy)
        r = 0.09 + 0.04 * (i % 3)
        parts.add(name, mat, ell([x, r * 0.5, z], [r * 1.2, r * 0.7, r]), "ground")


# --- walls ----------------------------------------------------------------------------------------
def plinth(parts, P, name, rect, h=0.22, grow=0.06, mat="stone"):
    x0, x1, z0, z1 = P.rect(*rect)
    parts.add(name, mat, box([(x0 + x1) / 2, h / 2, (z0 + z1) / 2], [(x1 - x0) / 2 + grow, h / 2, (z1 - z0) / 2 + grow],
                             round_=0.02), "found")
    parts.paint(name, "stone_dark", spots={"scale": 0.08, "density": 0.3, "seed": 5})
    parts.plinths.append((name, rect, h))


def walls(parts, P, name, rect, y0, y1, mat, layer="wall"):
    x0, x1, z0, z1 = P.rect(*rect)
    parts.add(name, mat, box([(x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2], [(x1 - x0) / 2, (y1 - y0) / 2, (z1 - z0) / 2]),
              layer)


def log_walls(parts, P, name, rect, y0, y1, course=0.2, mat="log", ends=True):
    """Walls of horizontal logs: grooves between courses and the crossed log ends at the corners
    the camera sees."""
    walls(parts, P, name, rect, y0, y1, mat)
    parts.paint(name, "log_groove", stripes={"axis": "y", "period": course, "width": 0.05, "offset": y0})
    if not ends:
        return
    x0, x1, z0, z1 = P.rect(*rect)
    n = int((y1 - y0) / course)
    for k in range(n):
        y = y0 + course * (k + 0.5)
        if k % 2 == 0:      # log running along z sticks out at the left face's corners
            for z in (z0, z1):
                parts.add(name + "_ends", "log_end", cyl([x0 - 0.2, y, z], [x0 + 0.05, y, z], course * 0.55), "wall")
        else:
            for x in (x0, x1):
                parts.add(name + "_ends", "log_end", cyl([x, y, z1 - 0.05], [x, y, z1 + 0.2], course * 0.55), "wall")
    parts.paint(name + "_ends", "log_ring", rings={"axis": "x", "period": 0.06, "width": 0.02})


def board_walls(parts, P, name, rect, y0, y1, mat="board", period=0.2):
    walls(parts, P, name, rect, y0, y1, mat)
    parts.paint(name, "ink", stripes={"axis": "x", "period": period, "width": 0.045})
    parts.paint(name, "ink", stripes={"axis": "z", "period": period, "width": 0.045})


def quoins(parts, P, name, rect, y0, y1, mat="sill_mat", step=0.4):
    """Dressed corner stones on the three corners the camera sees."""
    x0, x1, z0, z1 = P.rect(*rect)
    k, y = 0, y0 + 0.2
    while y < y1 - 0.1:
        long_ = k % 2 == 0
        for (x, z) in ((x0, z0), (x0, z1), (x1, z1)):
            parts.add(name, mat, box([x, y, z], [0.28 if long_ else 0.12, step * 0.42, 0.12 if long_ else 0.28]), "wall")
        k += 1
        y += step


def timber_left(parts, P, name, rect, y0, y1, posts, braces=True, out=0.0):
    """Half-timbering on the left face (plane x = x0)."""
    x0, x1, z0, z1 = P.rect(*rect)
    x = x0 - out
    parts.add(name, "timber", box([x, y0 + 0.06, (z0 + z1) / 2], [0.06, 0.06, (z1 - z0) / 2 + out]), "wall")
    parts.add(name, "timber", box([x, y1 - 0.06, (z0 + z1) / 2], [0.06, 0.06, (z1 - z0) / 2 + out]), "wall")
    parts.add(name, "timber", box([x, (y0 + y1) / 2 + 0.05, (z0 + z1) / 2], [0.06, 0.045, (z1 - z0) / 2 + out]), "wall")
    zs = [z0 - out + (z1 - z0 + 2 * out) * i / posts for i in range(posts + 1)]
    for i, z in enumerate(zs):
        zz = min(max(z, z0 - out + 0.06), z1 + out - 0.06)
        parts.add(name, "timber", box([x, (y0 + y1) / 2, zz], [0.06, (y1 - y0) / 2, 0.06]), "wall")
        if braces and i < posts and i % 2 == 0:
            za, zb = zz, zs[i + 1]
            L = math.hypot(zb - za, y1 - y0 - 0.15)
            ang = math.atan2(y1 - y0 - 0.15, zb - za)
            parts.add(name, "timber", box([x, (y0 + y1) / 2, (za + zb) / 2], [0.06, 0.045, L / 2], rot=[-ang, 0, 0]), "wall")


def timber_right(parts, P, name, rect, y0, y1, posts, braces=True, out=0.0):
    """Half-timbering on the right face (plane z = z1)."""
    x0, x1, z0, z1 = P.rect(*rect)
    z = z1 + out
    parts.add(name, "timber", box([(x0 + x1) / 2, y0 + 0.06, z], [(x1 - x0) / 2 + out, 0.06, 0.06]), "wall")
    parts.add(name, "timber", box([(x0 + x1) / 2, y1 - 0.06, z], [(x1 - x0) / 2 + out, 0.06, 0.06]), "wall")
    parts.add(name, "timber", box([(x0 + x1) / 2, (y0 + y1) / 2 + 0.05, z], [(x1 - x0) / 2 + out, 0.045, 0.06]), "wall")
    xs = [x0 - out + (x1 - x0 + 2 * out) * i / posts for i in range(posts + 1)]
    for i, x in enumerate(xs):
        xx = min(max(x, x0 - out + 0.06), x1 + out - 0.06)
        parts.add(name, "timber", box([xx, (y0 + y1) / 2, z], [0.06, (y1 - y0) / 2, 0.06]), "wall")
        if braces and i < posts and i % 2 == 1:
            xa, xb = xx, xs[i + 1]
            L = math.hypot(xb - xa, y1 - y0 - 0.15)
            ang = math.atan2(y1 - y0 - 0.15, xb - xa)
            parts.add(name, "timber", box([(xa + xb) / 2, (y0 + y1) / 2, z], [L / 2, 0.045, 0.06], rot=[0, 0, ang]), "wall")


# --- roofs ----------------------------------------------------------------------------------------
class Gable:
    """A gabled roof over a game rectangle. axis 'gy': the ridge runs along game y (model x), so
    the gable faces the left face; axis 'gx': along game x (model z), the gable faces the right.

    eave = top of the walls, ridge = apex height. Builds the gable infill (wall material), the
    flared roof and the ridge cap; gable_frame() adds timbering in the visible gable."""

    def __init__(self, P, name, rect, axis, eave, ridge, over=0.32, end_over=0.22, thick=0.16, flare=True):
        self.P, self.n, self.axis, self.eave, self.ridge = P, name, axis, eave, ridge
        x0, x1, z0, z1 = P.rect(*rect)
        self.x0, self.x1, self.z0, self.z1 = x0, x1, z0, z1
        self.xc, self.zc = (x0 + x1) / 2, (z0 + z1) / 2
        if axis == "gy":
            self.hw, self.length = (z1 - z0) / 2, x1 - x0
        else:
            self.hw, self.length = (x1 - x0) / 2, z1 - z0
        self.over, self.end_over, self.thick, self.flare = over, end_over, thick, flare
        self.slope = (ridge - eave) / self.hw

    def _rot(self):
        return [0, 1.5708, 0] if self.axis == "gy" else None

    def infill(self, parts, mat, name=None, y0=None):
        hw = self.hw
        a = self.ridge - 0.12
        bottom = self.eave if y0 is None else y0
        poly = [[-hw, bottom], [hw, bottom], [hw, self.eave], [0, a], [-hw, self.eave]]
        if bottom >= self.eave - 1e-6:      # a bare triangle: repeated points break the extrude
            poly = [[-hw, self.eave], [hw, self.eave], [0, a]]
        parts.add(name or self.n + "_gable", mat, ext([self.xc, 0, self.zc], poly, self.length, self._rot()), "wall")

    def roof(self, parts, mat, dark, course=0.2, spots=None, cap="ridge_cap"):
        hw, o, t, e, r = self.hw, self.over, self.thick, self.eave, self.ridge
        k = hw * 0.25 if self.flare else 0.0
        drop = 0.16 if self.flare else 0.0
        outer = [[-hw - o, e - o * self.slope * (0.45 if self.flare else 1.0) + 0.02], [-hw + k, e + k * self.slope],
                 [0, r], [hw - k, e + k * self.slope], [hw + o, e - o * self.slope * (0.45 if self.flare else 1.0) + 0.02]]
        if not self.flare:
            outer = [outer[0], outer[2], outer[4]]
        inner = [[p[0], p[1] - t] for p in reversed(outer)]
        name = self.n + "_roof"
        parts.add(name, mat, ext([self.xc, 0, self.zc], outer + inner, self.length + 2 * self.end_over, self._rot()), "roof")
        parts.paint(name, dark, stripes={"axis": "y", "period": course, "width": 0.055, "offset": e})
        parts.paint(name, dark, spots={"scale": 0.05, "density": 0.18, "seed": 11})
        if spots:
            parts.paint(name, spots[0], spots={"scale": spots[1], "density": spots[2], "seed": spots[3]})
        # ridge cap
        L = self.length / 2 + self.end_over + 0.02
        if self.axis == "gy":
            parts.add(self.n + "_cap", cap, box([self.xc, r + 0.02, self.zc], [L, 0.07, 0.11]), "roof")
        else:
            parts.add(self.n + "_cap", cap, box([self.xc, r + 0.02, self.zc], [0.11, 0.07, L]), "roof")
        _ = drop

    def bargeboards(self, parts, name=None, mat="timber"):
        """Boards along the visible gable's edges, crossed at the apex (a medieval touch)."""
        hw, o, e, r = self.hw, self.over, self.eave, self.ridge
        L = math.hypot(hw + o, (hw + o) * self.slope) / 2 + 0.1
        ang = math.atan(self.slope)
        nm = name or self.n + "_barge"
        if self.axis == "gy":
            x = self.x0 - self.end_over - 0.03
            for s in (-1, 1):
                cz = self.zc + s * (hw + o) / 2
                cy = r - (hw + o) / 2 * self.slope + 0.06
                parts.add(nm, mat, box([x, cy, cz], [0.04, 0.06, L], rot=[s * ang, 0, 0]), "roof")
            parts.add(nm, mat, box([x, r + 0.14, self.zc - 0.1], [0.04, 0.2, 0.04], rot=[0.6, 0, 0]), "roof")
            parts.add(nm, mat, box([x, r + 0.14, self.zc + 0.1], [0.04, 0.2, 0.04], rot=[-0.6, 0, 0]), "roof")
        else:
            z = self.z1 + self.end_over + 0.03
            for s in (-1, 1):
                cx = self.xc + s * (hw + o) / 2
                cy = r - (hw + o) / 2 * self.slope + 0.06
                parts.add(nm, mat, box([cx, cy, z], [L, 0.06, 0.04], rot=[0, 0, -s * ang]), "roof")
            parts.add(nm, mat, box([self.xc - 0.1, r + 0.14, z], [0.04, 0.2, 0.04], rot=[0, 0, -0.6]), "roof")
            parts.add(nm, mat, box([self.xc + 0.1, r + 0.14, z], [0.04, 0.2, 0.04], rot=[0, 0, 0.6]), "roof")

    def gable_frame(self, parts, name=None):
        """Timbering in the visible gable triangle: tie beam, collar, king post and two struts."""
        hw, e, r = self.hw, self.eave, self.ridge
        nm = name or self.n + "_gframe"
        if self.axis == "gy":
            x = self.x0 - 0.02
            P = lambda u, y: [x, y, self.zc + u]
            parts.add(nm, "timber", box(P(0, e + 0.05), [0.06, 0.06, hw]), "wall")
            cy = e + (r - e) * 0.5
            parts.add(nm, "timber", box(P(0, cy), [0.06, 0.05, hw * 0.5]), "wall")
            parts.add(nm, "timber", box(P(0, (e + r) / 2), [0.06, (r - e) / 2 - 0.1, 0.055]), "wall")
            for s in (-1, 1):
                u0, u1 = s * hw * 0.85, s * hw * 0.15
                y0, y1 = e + 0.1, cy - 0.05
                L = math.hypot(u1 - u0, y1 - y0) / 2
                ang = math.atan2(y1 - y0, u1 - u0)
                parts.add(nm, "timber", box(P((u0 + u1) / 2, (y0 + y1) / 2), [0.055, 0.045, L], rot=[-ang, 0, 0]), "wall")
        else:
            z = self.z1 + 0.02
            P = lambda u, y: [self.xc + u, y, z]
            parts.add(nm, "timber", box(P(0, e + 0.05), [hw, 0.06, 0.06]), "wall")
            cy = e + (r - e) * 0.5
            parts.add(nm, "timber", box(P(0, cy), [hw * 0.5, 0.05, 0.06]), "wall")
            parts.add(nm, "timber", box(P(0, (e + r) / 2), [0.055, (r - e) / 2 - 0.1, 0.06]), "wall")
            for s in (-1, 1):
                u0, u1 = s * hw * 0.85, s * hw * 0.15
                y0, y1 = e + 0.1, cy - 0.05
                L = math.hypot(u1 - u0, y1 - y0) / 2
                ang = math.atan2(y1 - y0, u1 - u0)
                parts.add(nm, "timber", box(P((u0 + u1) / 2, (y0 + y1) / 2), [L, 0.045, 0.055], rot=[0, 0, ang]), "wall")

    def rafters(self, parts, name=None, step=0.55):
        """Bare rafters, ridge beam, corner posts and wall plates (construction stage 2)."""
        hw, e, r = self.hw, self.eave, self.ridge
        nm = name or self.n + "_rafters"
        for (x, z) in ((self.x0, self.z0), (self.x0, self.z1), (self.x1, self.z1), (self.x1, self.z0)):
            parts.add(nm, "raw_timber", box([x + (0.06 if x == self.x0 else -0.06), e / 2, z + (0.06 if z == self.z0 else -0.06)],
                                            [0.06, e / 2, 0.06]), "site")
        parts.add(nm, "raw_timber", box([self.xc, e - 0.05, self.z0 + 0.06], [(self.x1 - self.x0) / 2, 0.06, 0.06]), "site")
        parts.add(nm, "raw_timber", box([self.xc, e - 0.05, self.z1 - 0.06], [(self.x1 - self.x0) / 2, 0.06, 0.06]), "site")
        parts.add(nm, "raw_timber", box([self.x0 + 0.06, e - 0.05, self.zc], [0.06, 0.06, (self.z1 - self.z0) / 2]), "site")
        parts.add(nm, "raw_timber", box([self.x1 - 0.06, e - 0.05, self.zc], [0.06, 0.06, (self.z1 - self.z0) / 2]), "site")
        L = math.hypot(hw + 0.2, (hw + 0.2) * self.slope) / 2
        ang = math.atan(self.slope)
        n = max(2, int(self.length / step))
        for i in range(n + 1):
            u = -self.length / 2 + self.length * i / n
            for s in (-1, 1):
                cy = e + (r - e) / 2 - 0.05
                if self.axis == "gy":
                    parts.add(nm, "raw_timber", box([self.xc + u, cy, self.zc + s * hw / 2], [0.045, 0.045, L],
                                                    rot=[s * ang, 0, 0]), "site")
                else:
                    parts.add(nm, "raw_timber", box([self.xc + s * hw / 2, cy, self.zc + u], [L, 0.045, 0.045],
                                                    rot=[0, 0, -s * ang]), "site")
        if self.axis == "gy":
            parts.add(nm, "raw_timber", box([self.xc, r - 0.05, self.zc], [self.length / 2, 0.05, 0.05]), "site")
        else:
            parts.add(nm, "raw_timber", box([self.xc, r - 0.05, self.zc], [0.05, 0.05, self.length / 2]), "site")


def lean_to(parts, P, name, rect, side, low, high, mat, dark, over=0.2, course=0.2, posts=True, post_mat="post"):
    """A single-slope roof over a game rectangle, high against the wall on `side` ('-gx' = back of
    the rectangle in game x, '-gy' = back in game y) and low at the opposite edge, on posts."""
    x0, x1, z0, z1 = P.rect(*rect)
    t = 0.09
    if side == "-gx":         # wall at z0, low edge at z1
        run = z1 - z0 + over
        ang = math.atan2(high - low, run)
        L = math.hypot(run, high - low) / 2
        c = [(x0 + x1) / 2, (high + low) / 2, z0 + run / 2]
        parts.add(name, mat, box(c, [(x1 - x0) / 2 + over, t, L], rot=[ang, 0, 0]), "roof")
        posts_at = [(x0 + 0.08, z1 - 0.08), (x1 - 0.08, z1 - 0.08)]
    else:                     # wall at x1 (back, small gy... no: -gy = small gy = big model x), low at x0
        run = x1 - x0 + over
        ang = math.atan2(high - low, run)
        L = math.hypot(run, high - low) / 2
        c = [x1 - run / 2, (high + low) / 2, (z0 + z1) / 2]
        parts.add(name, mat, box(c, [L, t, (z1 - z0) / 2 + over], rot=[0, 0, ang]), "roof")
        posts_at = [(x0 + 0.08, z0 + 0.08), (x0 + 0.08, z1 - 0.08)]
    parts.paint(name, dark, stripes={"axis": "y", "period": course * 0.6, "width": 0.055})
    if posts:
        for (x, z) in posts_at:
            parts.add(name + "_posts", post_mat, cyl([x, 0, z], [x, low - 0.02, z], 0.06), "wall")
    return posts_at


def chimney(parts, P, name, gx, gy, y0, y1, w=0.24, mat="brick", cap="stone"):
    x, _, z = P.m(gx, gy)
    parts.add(name, mat, box([x, (y0 + y1) / 2, z], [w, (y1 - y0) / 2, w]), "roof")
    parts.paint(name, "brick_line", stripes={"axis": "y", "period": 0.14, "width": 0.035})
    parts.add(name + "_cap", cap, box([x, y1 + 0.04, z], [w + 0.06, 0.05, w + 0.06]), "roof")
    parts.add(name + "_soot", "soot", box([x, y1 + 0.1, z], [w - 0.06, 0.02, w - 0.06]), "roof")


# --- openings -------------------------------------------------------------------------------------
def door_right(parts, P, name, gy, z, y0, w=0.56, h=1.15, arch=True, mat="door_wood", frame="timber"):
    """A plank door in a right face (plane z), centred at game y = gy."""
    x = P.m(0, gy)[0]
    zz = z + 0.03
    parts.add(name, mat, box([x, y0 + h / 2, zz], [w / 2, h / 2, 0.04]), "wall")
    if arch:
        parts.add(name, mat, cyl([x, y0 + h, zz - 0.04], [x, y0 + h, zz + 0.04], w / 2), "wall")
    parts.paint(name, "ink", stripes={"axis": "x", "period": w / 4, "width": 0.04, "offset": x - w / 2})
    for yy in (y0 + h * 0.25, y0 + h * 0.75):
        parts.add(name + "_iron", "iron", box([x - w * 0.15, yy, zz + 0.05], [w * 0.36, 0.035, 0.02]), "wall", priority=2)
    parts.add(name + "_iron", "iron", sph([x + w * 0.32, y0 + h * 0.5, zz + 0.06], 0.04), "wall")
    top = y0 + h + (w / 2 if arch else 0.0)
    parts.add(name + "_frame", frame, box([x - w / 2 - 0.06, y0 + (top - y0) / 2, zz + 0.01], [0.06, (top - y0) / 2, 0.05]), "wall")
    parts.add(name + "_frame", frame, box([x + w / 2 + 0.06, y0 + (top - y0) / 2, zz + 0.01], [0.06, (top - y0) / 2, 0.05]), "wall")
    parts.add(name + "_frame", frame, box([x, top + 0.05, zz + 0.01], [w / 2 + 0.12, 0.06, 0.05]), "wall")
    parts.add(name + "_step", "stone", box([x, 0.06, zz + 0.16], [w / 2 + 0.1, 0.06, 0.16]), "found")


def door_left(parts, P, name, gx, x, y0, w=0.56, h=1.15, arch=True, mat="door_wood", frame="timber"):
    """A plank door in a left face (plane x), centred at game x = gx."""
    z = P.m(gx, 0)[2]
    xx = x - 0.03
    parts.add(name, mat, box([xx, y0 + h / 2, z], [0.04, h / 2, w / 2]), "wall")
    if arch:
        parts.add(name, mat, cyl([xx - 0.04, y0 + h, z], [xx + 0.04, y0 + h, z], w / 2), "wall")
    parts.paint(name, "ink", stripes={"axis": "z", "period": w / 4, "width": 0.04, "offset": z - w / 2})
    for yy in (y0 + h * 0.25, y0 + h * 0.75):
        parts.add(name + "_iron", "iron", box([xx - 0.05, yy, z + w * 0.15], [0.02, 0.035, w * 0.36]), "wall", priority=2)
    top = y0 + h + (w / 2 if arch else 0.0)
    for s in (-1, 1):
        parts.add(name + "_frame", frame, box([xx - 0.01, y0 + (top - y0) / 2, z + s * (w / 2 + 0.06)], [0.05, (top - y0) / 2, 0.06]), "wall")
    parts.add(name + "_frame", frame, box([xx - 0.01, top + 0.05, z], [0.05, 0.06, w / 2 + 0.12]), "wall")
    parts.add(name + "_step", "stone", box([xx - 0.16, 0.06, z], [0.16, 0.06, w / 2 + 0.1]), "found")


def window_right(parts, P, gy, z, y, w=0.34, h=0.42, shutters=True, open_=True, box_=False):
    x = P.m(0, gy)[0]
    parts.add("glass", "glass", box([x, y, z + 0.02], [w / 2, h / 2, 0.04]), "wall")
    parts.add("muntins", "timber", box([x, y, z + 0.06], [0.025, h / 2, 0.02]), "wall", priority=2)
    parts.add("muntins", "timber", box([x, y, z + 0.06], [w / 2, 0.025, 0.02]), "wall", priority=2)
    parts.add("sills", "sill_mat", box([x, y - h / 2 - 0.04, z + 0.06], [w / 2 + 0.07, 0.04, 0.08]), "wall")
    parts.add("lintels", "timber", box([x, y + h / 2 + 0.04, z + 0.04], [w / 2 + 0.06, 0.04, 0.06]), "wall")
    if shutters:
        for s in (-1, 1):
            if open_:
                parts.add("shutters", "shutter", box([x + s * (w / 2 + 0.1), y, z + 0.05], [0.1, h / 2, 0.025]), "wall")
            else:
                parts.add("shutters", "shutter", box([x + s * w / 4, y, z + 0.07], [w / 4, h / 2, 0.025]), "wall")
    if box_:
        parts.add("flowerbox", "door_wood", box([x, y - h / 2 - 0.12, z + 0.12], [w / 2 + 0.05, 0.07, 0.08]), "prop")
        for i in range(3):
            parts.add("flowers", "bloom", sph([x - w / 3 + i * w / 3, y - h / 2 - 0.02, z + 0.13], 0.07), "prop")


def window_left(parts, P, gx, x, y, w=0.34, h=0.42, shutters=True, open_=True):
    z = P.m(gx, 0)[2]
    parts.add("glass", "glass", box([x - 0.02, y, z], [0.04, h / 2, w / 2]), "wall")
    parts.add("muntins", "timber", box([x - 0.06, y, z], [0.02, h / 2, 0.025]), "wall", priority=2)
    parts.add("muntins", "timber", box([x - 0.06, y, z], [0.02, 0.025, w / 2]), "wall", priority=2)
    parts.add("sills", "sill_mat", box([x - 0.06, y - h / 2 - 0.04, z], [0.08, 0.04, w / 2 + 0.07]), "wall")
    parts.add("lintels", "timber", box([x - 0.04, y + h / 2 + 0.04, z], [0.06, 0.04, w / 2 + 0.06]), "wall")
    if shutters:
        for s in (-1, 1):
            if open_:
                parts.add("shutters", "shutter", box([x - 0.05, y, z + s * (w / 2 + 0.1)], [0.025, h / 2, 0.1]), "wall")
            else:
                parts.add("shutters", "shutter", box([x - 0.07, y, z + s * w / 4], [0.025, h / 2, w / 4]), "wall")


# --- props ----------------------------------------------------------------------------------------
def barrel(parts, P, gx, gy, r=0.2, h=0.5, name="barrels", lying=False, along="x"):
    x, _, z = P.m(gx, gy)
    if lying:
        a, b = ([x - h / 2, r, z], [x + h / 2, r, z]) if along == "x" else ([x, r, z - h / 2], [x, r, z + h / 2])
        parts.add(name, "barrel", ell([(a[0] + b[0]) / 2, r, (a[2] + b[2]) / 2],
                                      [h / 2 if along == "x" else r, r, r if along == "x" else h / 2]), "prop")
        return
    parts.add(name, "barrel", cyl([x, 0, z], [x, h, z], r), "prop")
    parts.add(name, "barrel", ell([x, h * 0.5, z], [r * 1.12, h * 0.38, r * 1.12]), "prop")
    parts.paint(name, "iron", stripes={"axis": "y", "at": [0.08, h - 0.08], "width": 0.04})
    parts.paint(name, "barrel_dark", stripes={"axis": "x", "period": 0.09, "width": 0.025})
    parts.add(name + "_lid", "barrel_lid", cyl([x, h - 0.01, z], [x, h + 0.02, z], r * 0.92), "prop")


def crate(parts, P, gx, gy, s=0.22, h=None, rot=0.0, name="crates", y0=0.0):
    x, _, z = P.m(gx, gy)
    h = h or s
    parts.add(name, "crate", box([x, y0 + h, z], [s, h, s], rot=[0, rot, 0]), "prop")
    parts.paint(name, "ink", stripes={"axis": "y", "period": 0.15, "width": 0.03})


def sack(parts, P, gx, gy, s=0.2, name="sacks", mat="sack", y0=0.0):
    x, _, z = P.m(gx, gy)
    parts.add(name, mat, ell([x, y0 + s * 0.95, z], [s, s, s * 0.8]), "prop", blend=0.04)
    parts.add(name, mat, ell([x, y0 + s * 1.9, z], [s * 0.35, s * 0.25, s * 0.3]), "prop")
    parts.add(name + "_tie", "rope", tor([x, y0 + s * 1.72, z], s * 0.32, 0.03), "prop")


def bucket(parts, P, gx, gy, r=0.12, h=0.22, name="buckets", fill=None):
    x, _, z = P.m(gx, gy)
    parts.add(name, "barrel", cyl([x, 0, z], [x, h, z], r), "prop")
    parts.paint(name, "iron", stripes={"axis": "y", "at": [0.05, h - 0.05], "width": 0.03})
    if fill:
        parts.add(name + "_fill", fill, cyl([x, h - 0.04, z], [x, h - 0.02, z], r * 0.85), "prop")


def log(parts, P, a, b, r, name="logs", y=None, mat="log_bark"):
    """A log between game points a=(gx, gy) and b, lying at height y (default: on the ground)."""
    y = r if y is None else y
    pa, pb = P.m(a[0], a[1], y), P.m(b[0], b[1], y)
    parts.add(name, mat, cyl(pa, pb, r), "prop")
    parts.add(name + "_ends", "log_end", cyl(pa, [pa[0] + (pa[0] - pb[0]) * 0.01, y, pa[2] + (pa[2] - pb[2]) * 0.01], r * 0.92), "prop")
    parts.add(name + "_ends", "log_end", cyl(pb, [pb[0] + (pb[0] - pa[0]) * 0.01, y, pb[2] + (pb[2] - pa[2]) * 0.01], r * 0.92), "prop")


def woodpile(parts, P, name, gx0, gx1, gy, rows, r=0.1, along="gx", y0=0.0, mat="split"):
    """Split firewood stacked in rows, the cut ends facing the camera's left face (along gx: logs
    run along game y) or right face."""
    for row in range(rows):
        y = y0 + r + row * r * 1.75
        span = gx1 - gx0
        n = int(span * T / (r * 2.05))
        for i in range(n):
            u = gx0 + (i + 0.5 + (0.5 if row % 2 else 0)) * span / (n + 0.5)
            if along == "gx":
                a, b = P.m(u, gy - 0.18, y), P.m(u, gy + 0.18, y)
            else:
                a, b = P.m(gy - 0.18, u, y), P.m(gy + 0.18, u, y)
            parts.add(name + ("_a" if (i + row) % 2 else "_b"), mat if (i + row) % 2 else mat + "_alt", cyl(a, b, r), "prop")
    for nm in (name + "_a", name + "_b"):
        if nm in parts:
            parts.paint(nm, "log_ring", rings={"axis": "x" if along == "gx" else "z", "period": 0.11, "width": 0.055})


def stump(parts, P, gx, gy, r=0.22, h=0.32, name="block"):
    x, _, z = P.m(gx, gy)
    parts.add(name, "log_bark", cyl([x, 0, z], [x, h, z], r), "prop")
    parts.add(name, "log_bark", cone([x, 0, z], [x, 0.06, z], r * 1.35, r), "prop")
    parts.add(name + "_top", "log_end", cyl([x, h - 0.01, z], [x, h + 0.01, z], r * 0.92), "prop")
    parts.paint(name + "_top", "log_ring", rings={"axis": "y", "period": 0.11, "width": 0.055})


def axe_in(parts, P, gx, gy, y, name="axe", yaw=0.0, tilt=0.5):
    """An axe stuck in a block at game point (gx, gy), height y."""
    x, _, z = P.m(gx, gy)
    dx, dz = math.cos(yaw), math.sin(yaw)
    L = 0.55
    hx, hy, hz = x + dx * L * math.sin(tilt), y + L * math.cos(tilt), z + dz * L * math.sin(tilt)
    parts.add(name + "_haft", "haft", cyl([x, y - 0.02, z], [hx, hy, hz], 0.03), "prop", priority=2, min_cover=2)
    parts.add(name + "_head", "steel", box([x, y + 0.02, z], [0.11, 0.06, 0.025], rot=[0, -yaw, 0]), "prop", priority=2)


def sawhorse(parts, P, gx, gy, along="gx", h=0.48, name="sawhorse", with_log=True):
    x, _, z = P.m(gx, gy)
    L = 0.42
    for s in (-1, 1):
        if along == "gx":     # beam along z
            zz = z + s * L
            parts.add(name, "post", box([x, h / 2, zz], [0.2, h / 2 + 0.02, 0.035], rot=[0, 0, 0.0]), "prop")
            parts.add(name, "post", box([x, h / 2, zz], [0.03, h / 2 + 0.05, 0.04], rot=[0.0, 0, 0.5]), "prop")
            parts.add(name, "post", box([x, h / 2, zz], [0.03, h / 2 + 0.05, 0.04], rot=[0.0, 0, -0.5]), "prop")
        else:
            xx = x + s * L
            parts.add(name, "post", box([xx, h / 2, z], [0.03, h / 2 + 0.05, 0.04], rot=[0.5, 0, 0]), "prop")
            parts.add(name, "post", box([xx, h / 2, z], [0.03, h / 2 + 0.05, 0.04], rot=[-0.5, 0, 0]), "prop")
    if with_log:
        if along == "gx":
            log(parts, P, (gx - 0.42, gy), (gx + 0.42, gy), 0.15, name + "_log", y=h + 0.12)
        else:
            log(parts, P, (gx, gy - 0.42), (gx, gy + 0.42), 0.15, name + "_log", y=h + 0.12)


def ladder(parts, P, a, b, w=0.36, name="ladder"):
    """A ladder from ground point a=(gx, gy, y) to b, its rungs across the right face."""
    pa, pb = P.m(a[0], a[1], a[2]), P.m(b[0], b[1], b[2])
    for s in (-1, 1):
        parts.add(name, "post", cyl([pa[0] + s * w / 2, pa[1], pa[2]], [pb[0] + s * w / 2, pb[1], pb[2]], 0.035), "prop",
                  priority=2)
    n = int(math.dist(pa, pb) / 0.28)
    for i in range(1, n):
        t = i / n
        p = [pa[k] + (pb[k] - pa[k]) * t for k in range(3)]
        parts.add(name, "post", cyl([p[0] - w / 2, p[1], p[2]], [p[0] + w / 2, p[1], p[2]], 0.025), "prop", priority=2)


def sign_right(parts, P, gy, z, y, emblem, name="sign"):
    """A wrought bracket out of a right face with a hanging board and an emblem on it."""
    x = P.m(0, gy)[0]
    parts.add(name + "_bracket", "iron", box([x, y, z + 0.32], [0.025, 0.025, 0.32]), "wall", priority=2)
    parts.add(name + "_bracket", "iron", box([x, y - 0.15, z + 0.12], [0.02, 0.02, 0.16], rot=[0.75, 0, 0]), "wall")
    parts.add(name + "_bracket", "iron", cyl([x, y, z + 0.5], [x, y - 0.1, z + 0.5], 0.015), "wall", min_cover=1)
    parts.add(name + "_board", "sign_board", box([x, y - 0.32, z + 0.45], [0.27, 0.2, 0.03]), "wall")
    parts.paint(name + "_board", "sign_edge", stripes={"axis": "x", "at": [x - 0.25, x + 0.25], "width": 0.04})
    emblem(parts, [x, y - 0.32, z + 0.49])


def lantern(parts, P, gy, z, y, name="lantern"):
    x = P.m(0, gy)[0]
    parts.add(name, "iron", box([x, y + 0.12, z + 0.12], [0.02, 0.02, 0.12]), "wall")
    parts.add(name, "iron", box([x, y - 0.06, z + 0.22], [0.07, 0.1, 0.07]), "wall")
    parts.add(name + "_light", "flame", box([x, y - 0.06, z + 0.25], [0.045, 0.06, 0.045]), "wall")


def wheelbarrow(parts, P, gx, gy, yaw=0.0, load=None, name="barrow"):
    x, _, z = P.m(gx, gy)
    c, s = math.cos(yaw), math.sin(yaw)

    def at(u, v, y):    # u along the barrow (wheel at +u), v across
        return [x + u * c - v * s, y, z + u * s + v * c]
    parts.add(name, "board", box(at(0, 0, 0.36), [0.36, 0.13, 0.22], rot=[0, -yaw, 0]), "prop")
    parts.add(name + "_wheel", "post", cyl(at(0.48, -0.04, 0.17), at(0.48, 0.04, 0.17), 0.17), "prop")
    for v in (-0.17, 0.17):
        parts.add(name + "_arms", "post", cyl(at(0.5, v, 0.2), at(-0.75, v, 0.38), 0.03), "prop", priority=2)
        parts.add(name + "_arms", "post", cyl(at(-0.2, v, 0.24), at(-0.25, v, 0.0), 0.03), "prop")
    if load:
        load(parts, at(0, 0, 0.5))


def dormer(parts, P, roof, name, gy, w=0.62, h=0.55, mat="plaster", roof_mat="shingle", dark="shingle_dark"):
    """A small gabled dormer on the right slope of a 'gy' roof, at game y = gy, with a window."""
    zf = roof.zc + roof.hw * 0.55
    y0 = roof.ridge - roof.slope * (zf - roof.zc) - 0.05
    x = P.m(0, gy)[0]
    gxf, gxb = (zf + P.h) / T, (roof.zc + P.h) / T
    gy0, gy1 = gy - w / 2 / T, gy + w / 2 / T
    walls(parts, P, name + "_walls", (gxb, gxf, gy0, gy1), y0 - 0.3, y0 + h, mat)
    timber_right(parts, P, name + "_frame", (gxb, gxf, gy0, gy1), y0, y0 + h, 1, braces=False)
    g = Gable(P, name, (gxb, gxf, gy0, gy1), "gx", y0 + h, y0 + h + w * 0.55, over=0.1, end_over=0.1, thick=0.1)
    g.infill(parts, mat)
    g.roof(parts, roof_mat, dark, course=0.13)
    g.bargeboards(parts)
    window_right(parts, P, gy, zf, y0 + h * 0.5, w=w * 0.5, h=h * 0.6, shutters=False)
    return g
