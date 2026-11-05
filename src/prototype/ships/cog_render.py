"""SHIPS PROTOTYPE: procedural pixel-art cog in 8 isometric directions (ART_SPEC order S, SE,
E, NE, N, NW, W, SW). Made for fun ahead of M5; a base for the caravel, carrack and big warship
of the ship tree idea (docs/IDEAS.md). Faction parts (sail stripes, shields, flag) are magenta
for the faction shader (ART_SPEC §1).

Run: python3 src/prototype/ships/cog_render.py src/prototype/ships   (Pillow + numpy, ~3 min)
Output: cog_sheet.png, 8 frames of 220x220 in a row; the ship centre at the waterline is
at (110, 168) in every frame. cog_preview.png shows red and blue factions on the sea.

The ship is a set of implicit solids (negative = inside). Every sprite pixel shoots an
orthographic ray from a 2:1 camera (30 deg elevation); the first solid hit gives material and
normal, the normal gives one of 4 light bands, and a dark selective outline is added.
"""
import math
import sys

import numpy as np
from PIL import Image

OUT = sys.argv[1] if len(sys.argv) > 1 else "."
SIZE = 220          # frame canvas (px)
PIVOT = (110, 168)  # screen position of the ship centre at the waterline
ELEV = math.radians(30.0)
STEP = 0.3
FAR = 420.0

# --- ship dimensions (world units ~ screen px) ---------------------------------------------
L, W, D = 66.0, 21.0, 18.0   # half length, half beam, hull depth below deck
ZD = 15.0                    # deck height above water at midships
SHEER = 10.0                  # deck rises this much at the ends
MX = 4.0                     # mast position
MAST_TOP = ZD + 100.0
YARD_Z = ZD + 86.0
SAIL_W, SAIL_H, BELLY = 33.0, 58.0, 8.0

MAT = {  # base colours
    "hull": (122, 82, 50), "tar": (60, 42, 30), "deck": (168, 124, 76), "castle": (110, 74, 46),
    "rail": (150, 108, 66), "mast": (92, 61, 34), "sail": (232, 220, 192), "faction": (255, 0, 255),
    "rope": (64, 45, 30), "foam": (226, 236, 236), "boss": (190, 190, 180), "rim": (70, 60, 52),
}
NAMES = list(MAT)
BANDS = np.array([0.58, 0.74, 0.88, 1.02])
LIGHT = np.array([-0.35, -0.55, 1.0])
LIGHT = LIGHT / np.linalg.norm(LIGHT)


def deck_z(x):
    return ZD + SHEER * np.clip(np.abs(x) / L, 0, 1) ** 4


def hull_outline(x, y, l, w):
    return (np.abs(x) / l) ** 3 + (y / w) ** 2


def f_hull(p):
    x, y, z = p
    dz = deck_z(x)
    g_xy = hull_outline(x, y, L, W)
    below = g_xy + ((dz - z) / D) ** 2 * (z < dz)
    outer = np.maximum(below - 1.0, z - dz)
    inner_cut = np.maximum(hull_outline(x, y, L - 3.0, W - 2.5) - 1.0, (dz - 3.0) - z)
    return np.maximum(np.maximum(outer, -inner_cut), -z - 0.01)


def box(p, lo, hi):
    x, y, z = p
    return np.maximum.reduce([lo[0] - x, x - hi[0], lo[1] - y, y - hi[1], lo[2] - z, z - hi[2]])


def f_castle(p):
    x, y, z = p
    top = ZD + SHEER * 0.5 + 12.0
    body = box(p, (-L + 3, -W, ZD - 3), (-L * 0.45, W, top))
    body = np.maximum(body, hull_outline(x, y, L + 1.5, W + 1.0) - 1.0)
    hollow = np.maximum(box(p, (-L + 5.5, -W + 2, top - 2.5), (-L * 0.45 - 2.5, W - 2, top + 1)),
                        hull_outline(x, y, L - 1.0, W - 1.5) - 1.0)
    return np.maximum(body, -hollow)


CASTLE_TOP = ZD + SHEER * 0.5 + 12.0
CASTLE_X = (-L + 3, -L * 0.45)


def side_y(x, l=L + 1.5, w=W + 1.0):
    return w * np.sqrt(np.clip(1 - (np.abs(x) / l) ** 3, 0, 1))


def f_crenels(p):
    x, y, z = p
    rim = box(p, (CASTLE_X[0], -W, CASTLE_TOP - 0.5), (CASTLE_X[1], W, CASTLE_TOP + 3.5))
    rim = np.maximum(rim, hull_outline(x, y, L + 1.5, W + 1.0) - 1.0)
    inner = np.maximum(box(p, (CASTLE_X[0] + 2.5, -W + 2, CASTLE_TOP - 1), (CASTLE_X[1] - 2.5, W - 2, CASTLE_TOP + 5)),
                       hull_outline(x, y, L - 1.0, W - 1.5) - 1.0)
    merlon = ((np.floor(x / 3.5) + np.floor(y / 3.5)) % 2) == 0
    return np.maximum.reduce([rim, -inner, np.where(merlon, -1.0, 1.0)])


SHIELD_X = (-54.0, -43.5, -33.0)


def f_shields(p):
    x, y, z = p
    out = np.full(x.shape, 99.0)
    for xc in SHIELD_X:
        ys = side_y(np.array(xc)) + 0.4
        d = np.maximum(np.hypot(x - xc, z - (ZD + 7.0)) - 4.4, np.abs(np.abs(y) - ys - 0.4) - 0.9)
        out = np.minimum(out, d)
    return out


def f_forecastle(p):
    x, y, z = p
    top = ZD + SHEER * 0.6 + 6.0
    body = np.maximum(box(p, (L * 0.52, -W, ZD), (L - 1.5, W, top)), hull_outline(x, y, L + 1.0, W + 0.5) - 1.0)
    hollow = np.maximum(box(p, (L * 0.52 + 2.5, -W, top - 2.0), (L, W, top + 1)), hull_outline(x, y, L - 2.0, W - 2.5) - 1.0)
    return np.maximum(body, -hollow)


def cylinder_z(p, cx, cy, r, z0, z1):
    x, y, z = p
    return np.maximum(np.hypot(x - cx, y - cy) - r, np.maximum(z0 - z, z - z1))


def f_mast(p):
    x, y, z = p
    mast = cylinder_z(p, MX, 0, 1.8, ZD - 3, MAST_TOP)
    top = cylinder_z(p, MX, 0, 3.2, MAST_TOP - 9, MAST_TOP - 5)  # crow's nest
    yard = np.maximum(np.hypot(x - MX - 2.2, z - YARD_Z) - 1.2, np.abs(y) - SAIL_W - 4)
    rudder = box(p, (-L - 4.0, -1.0, 0.0), (-L + 2.0, 1.0, deck_z(np.array(L)) - 2.0))
    return np.minimum.reduce([mast, top, yard, rudder])


def sail_x(y, z):
    t = np.clip((YARD_Z - 1 - z) / SAIL_H, 0, 1)
    return MX + 3.0 + BELLY * (1 - (y / SAIL_W) ** 2) * np.sin(np.pi * (0.25 + 0.75 * t)) * 0.9


def f_sail(p):
    x, y, z = p
    inside = np.maximum(np.abs(y) - SAIL_W, np.maximum((YARD_Z - 1 - SAIL_H) - z, z - (YARD_Z - 1)))
    return np.maximum(np.abs(x - sail_x(y, z)) - 0.9, inside)


def f_flag(p):
    x, y, z = p
    zt = MAST_TOP - 1
    t = np.clip((x - MX) / 16.0, 0, 1)
    wave = 1.2 * np.sin((x - MX) * 0.45)
    return np.maximum.reduce([np.abs(y - wave) - 0.7, MX - x, x - (MX + 16), np.abs(z - (zt - 4)) - 4.0 * (1 - t) - 0.3])


def segment(p, a, b, r):
    pa = np.stack(p) - a[:, None]
    ba = b - a
    h = np.clip((pa.T @ ba) / (ba @ ba), 0, 1)
    d = pa - ba[:, None] * h[None, :]
    return np.linalg.norm(d, axis=0) - r


ROPES = [
    (np.array([MX, 0, MAST_TOP - 8]), np.array([MX - 14, s * (W - 1), ZD + 1])) for s in (-1, 1)
] + [
    (np.array([MX, 0, MAST_TOP - 8]), np.array([MX + 12, s * (W - 1), ZD + 1])) for s in (-1, 1)
] + [
    (np.array([MX, 0, MAST_TOP - 8]), np.array([L + 2, 0, ZD + SHEER + 4])),
]


def f_rope(p):
    return np.minimum.reduce([segment(p, a, b, 0.5) for a, b in ROPES])


PARTS = [("hull", f_hull), ("castle", f_castle), ("forecastle", f_forecastle), ("mast", f_mast),
         ("sail", f_sail), ("flag", f_flag), ("rope", f_rope), ("crenels", f_crenels), ("shields", f_shields)]


def fields(p):
    return np.stack([f(p) for _, f in PARTS])


def material(part, p, n):
    x, y, z = p
    name = PARTS[part][0]
    if name == "hull":
        if n[2] > 0.75:
            return "deck"
        if z < 3.5:
            return "tar"
        return "hull"
    if name in ("castle", "forecastle", "crenels"):
        return "rail" if n[2] > 0.75 else "castle"
    if name == "shields":
        xc = min(SHIELD_X, key=lambda v: abs(v - x))
        r = np.hypot(x - xc, z - (ZD + 7.0))
        if r < 1.2:
            return "boss"
        if r > 3.5:
            return "rim"
        return "faction" if (x - xc) * (z - ZD - 7.0) >= 0 else "sail"
    if name == "sail":
        # Two faction-coloured stripes (magenta, swapped by the faction shader, ART_SPEC §1).
        return "faction" if (np.abs(y) % 24.0) < 8.0 else "sail"
    if name == "flag":
        return "faction"
    if name == "rope":
        return "rope"
    return "mast"


def render(heading):
    """heading: angle of the bow on the ground (0 = screen right, i.e. E)."""
    ys, xs = np.mgrid[0:SIZE, 0:SIZE]
    sx = (xs + 0.5 - PIVOT[0]).ravel().astype(float)
    sy = (ys + 0.5 - PIVOT[1]).ravel().astype(float)
    fwd = np.array([0.0, math.cos(ELEV), -math.sin(ELEV)])   # into the screen and down
    up = np.array([0.0, math.sin(ELEV), math.cos(ELEV)])
    right = np.array([1.0, 0.0, 0.0])
    origin = right[:, None] * sx + up[:, None] * (-sy) - fwd[:, None] * (FAR / 2)
    c, s = math.cos(-heading), math.sin(-heading)

    def to_ship(q):
        return np.stack([c * q[0] - s * q[1], s * q[0] + c * q[1], q[2]])

    n = sx.size
    hit = np.full(n, -1)
    hit_t = np.zeros(n)
    foam = np.zeros(n, bool)
    alive = np.ones(n, bool)
    t = 0.0
    while t < FAR and alive.any():
        idx = np.nonzero(alive)[0]
        q = origin[:, idx] + fwd[:, None] * t
        p = to_ship(q)
        f = fields(p)
        best = f.min(axis=0)
        inside = best < 0
        got = idx[inside]
        hit[got] = f[:, inside].argmin(axis=0)
        hit_t[got] = t
        alive[got] = False
        # Ray went below the water: foam if the hull is close at the waterline, else empty.
        under = (~inside) & (q[2] < 0)
        ui = idx[under]
        if ui.size:
            pu = p[:, under]
            pu[2] = 0.3
            foam[ui] = f_hull(pu) < 0.12 + 0.06 * np.sin(pu[0] * 0.7)
            alive[ui] = False
        t += STEP
    img = np.zeros((n, 4), np.uint8)
    mats = np.full(n, -1)
    hi = np.nonzero(hit >= 0)[0]
    if hi.size:
        q = origin[:, hi] + fwd[:, None] * hit_t[hi]
        p = to_ship(q)
        eps = 0.35
        grads = []
        for axis in range(3):
            d = np.zeros((3, 1))
            d[axis] = eps
            fp = fields(p + d)
            fm = fields(p - d)
            parts = hit[hi]
            grads.append(fp[parts, np.arange(hi.size)] - fm[parts, np.arange(hi.size)])
        nrm = np.stack(grads)
        nrm /= np.linalg.norm(nrm, axis=0) + 1e-9
        # back to world for lighting
        nw = np.stack([c * nrm[0] + s * nrm[1], -s * nrm[0] + c * nrm[1], nrm[2]])
        # thin parts (sail, flag, rope) are lit from both sides
        lam = nw.T @ LIGHT
        two_sided = np.isin(hit[hi], [4, 5, 6])
        lam = np.where(two_sided, np.abs(lam), lam)
        band = np.clip(((lam + 0.15) / 1.15 * 4).astype(int), 0, 3)
        for k, i in enumerate(hi):
            name = material(hit[i], p[:, k], nrm[:, k])
            base = np.array(MAT[name], float)
            shade = BANDS[band[k]]
            if name == "hull" and (p[2, k] % 3.4) < 0.6:   # plank seams
                shade *= 0.72
            if name == "hull" and abs(p[2, k] - (deck_z(p[0, k]) - 2.0)) < 0.8:  # wale
                shade *= 0.62
            if name == "deck" and (abs(p[1, k]) % 3.0) < 0.5:
                shade *= 0.85
            if name == "faction":
                shade = [1.0, 0.8, 0.6, 0.4][3 - band[k]]
            img[i, :3] = np.clip(base * shade, 0, 255)
            img[i, 3] = 255
            mats[i] = NAMES.index(name)
    fi = np.nonzero(foam & (hit < 0))[0]
    img[fi, :3] = MAT["foam"]
    img[fi, 3] = 255
    mats[fi] = NAMES.index("foam")
    img = img.reshape(SIZE, SIZE, 4)
    mats = mats.reshape(SIZE, SIZE)
    return outline(img, mats)


def outline(img, mats):
    """1 px selective outline: object pixels touching empty space get a darker version."""
    solid = img[:, :, 3] > 0
    edge = np.zeros_like(solid)
    for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
        edge |= solid & ~np.roll(np.roll(solid, dy, 0), dx, 1)
    out = img.copy()
    foam = mats == NAMES.index("foam")
    darken = edge & ~foam
    out[darken, :3] = (out[darken, :3] * 0.38 + np.array([20, 12, 8]) * 0.62 * 0.4).astype(np.uint8)
    return out


def main():
    # ART_SPEC order S, SE, E, NE, N, NW, W, SW; on the ground S = towards the camera.
    headings = [-90, -45, 0, 45, 90, 135, 180, -135]
    frames = []
    for i, h in enumerate(headings):
        frames.append(render(math.radians(h)))
        print("dir", i, "done", flush=True)
    sheet = np.concatenate(frames, axis=1)
    Image.fromarray(sheet, "RGBA").save(f"{OUT}/cog_sheet.png")


if __name__ == "__main__":
    main()
