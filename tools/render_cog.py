"""Procedural pixel-art cog in 8 isometric directions (ART_SPEC §9, M5). Moved here from the
ship prototype (src/prototype/ships/cog_render.py) to draw the game's cogs.

Run: python3 tools/render_cog.py <ship id> <faction colour as r,g,b> [--stages]
     (Pillow + numpy, ~3 min per sheet)
     e.g. python3 tools/render_cog.py foreign_cog 40,118,72
          python3 tools/render_cog.py cog 46,84,168            (the player's cog, M5 part 3)
          python3 tools/render_cog.py cog 46,84,168 --stages   (build_0..2 on the slipway)
          python3 tools/render_cog.py warship 168,40,36 --war [--stages]   (the warship, M7 part 3)
Output: assets/ships/<ship id>/idle.png: 8 rows (directions in ART_SPEC order S, SE, E, NE, N,
NW, W, SW) of BOB_FRAMES frames of 220x220 in which the ship rocks gently on the waves; the
ship centre at the waterline is at (110, 168) in every frame (ShipLayer.BIG_FRAMES). The
faction parts (sail stripes, shields, flag) are drawn magenta and painted in the colour given.
With --stages: assets/ships/<ship id>/build_<n>.png, one frame per direction (8 rows), the
ship standing on keel blocks on the slipway, its hull out of the water: 0 = keel, stem and
ribs, 1 = planked hull with the castles, 2 = mast with the sail (the whole ship; the fourth
stage, the launch, slides this one down into the water in the view).

The ship is a set of implicit solids (negative = inside). Every sprite pixel shoots an
orthographic ray from a 2:1 camera (30 deg elevation); the first solid hit gives material and
normal, the normal gives one of 4 light bands, and a dark selective outline is added.
"""
import math
import sys

import numpy as np
from PIL import Image

SHIP_ID = sys.argv[1] if len(sys.argv) > 1 else "foreign_cog"
FACTION = tuple(int(v) for v in (sys.argv[2] if len(sys.argv) > 2 else "40,118,72").split(","))
STAGES = "--stages" in sys.argv
# The warship (M7 part 3): the same cog with a row of shields along both sides of the waist.
WAR = "--war" in sys.argv
# J1 part 3: the hull and rig of a bigger ship (--type=caravel|carrack|galleon); default the cog.
TYPE = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--type=")), "cog")
# Per type: half length, half beam, hull depth, deck height, sheer; stern castle (its front as
# a share of L, its height over the deck), forecastle (from, height; 0 = none); masts as (x as
# a share of L, height over the deck, sail half width, sail height); frame size and pivot.
PROFILES = {
    "cog": dict(L=66.0, W=21.0, D=18.0, ZD=15.0, SHEER=10.0, castle=(0.45, 12.0), fore=(0.52, 6.0),
                masts=[(4.0 / 66.0, 100.0, 33.0, 58.0)], size=220, pivot=(110, 168)),
    # J1 part 3 (owner's references 2026-11-08: the caravel Pinta, the carrack Victoria, a
    # galleon): round, tall hulls drawn by the "big ship" model below (rounded bilge, sides
    # leaning in towards the top, castles rising out of the hull, rails and windows). rig: masts
    # from fore to aft, each {x: share of L, h: height over the waterline-deck, w: sail half
    # width, tiers: square sails one over another} or {x, h, span, lateen: True}; tier2: a second
    # tier of the stern castle (front as a share of L, height); stern: fullness of the stern
    # (higher = squarer, a transom); masts: the main mast only, for the shared code.
    "caravel": dict(L=78.0, W=21.0, D=22.0, ZD=21.0, SHEER=22.0, castle=(0.6, 10.0), fore=(0.8, 6.0),
                    tier2=(0.0, 0.0), stern=3.0,
                    rig=[dict(x=0.5, h=74.0, w=19.0, tiers=1), dict(x=0.04, h=106.0, w=30.0, tiers=1),
                         dict(x=-0.5, h=84.0, span=44.0, lateen=True)],
                    masts=[(0.04, 106.0, 30.0, 56.0)], bowsprit=True, spritsail=False, beak=False, ports=False,
                    emblem="cross", size=270, pivot=(135, 206)),
    "carrack": dict(L=90.0, W=30.0, D=26.0, ZD=25.0, SHEER=22.0, castle=(0.44, 17.0), fore=(0.56, 19.0),
                    tier2=(0.74, 12.0), stern=3.5,
                    rig=[dict(x=0.5, h=100.0, w=26.0, tiers=2), dict(x=0.02, h=140.0, w=40.0, tiers=2),
                         dict(x=-0.46, h=100.0, span=54.0, lateen=True)],
                    masts=[(0.02, 140.0, 40.0, 70.0)], bowsprit=True, spritsail=True, beak=False, ports=False,
                    emblem="cross", size=320, pivot=(160, 246)),
    "galleon": dict(L=108.0, W=31.0, D=28.0, ZD=27.0, SHEER=16.0, castle=(0.38, 17.0), fore=(0.62, 12.0),
                    tier2=(0.66, 14.0), stern=6.0,
                    rig=[dict(x=0.5, h=128.0, w=30.0, tiers=3), dict(x=0.05, h=164.0, w=42.0, tiers=3),
                         dict(x=-0.36, h=112.0, span=56.0, lateen=True), dict(x=-0.66, h=86.0, span=38.0, lateen=True)],
                    masts=[(0.05, 164.0, 42.0, 80.0)], bowsprit=True, spritsail=True, beak=True, ports=True,
                    emblem="cross", size=370, pivot=(185, 290)),
}
PROFILE = PROFILES[TYPE]
# Height of the water (idle) or of the slipway floor (stages) where rays stop.
WATER = 0.0
# Hull cut at the waterline (False on the slipway: the whole hull shows).
CLIP_WATERLINE = True
# Vertical offsets (px) of the rocking frames.
BOB = [0, -1, -1, 0]
SIZE = PROFILE["size"]      # frame canvas (px)
PIVOT = PROFILE["pivot"]    # screen position of the ship centre at the waterline
ELEV = math.radians(30.0)
STEP = 0.3
FAR = 420.0 * SIZE / 220.0

# --- ship dimensions (world units ~ screen px) ---------------------------------------------
L, W, D = PROFILE["L"], PROFILE["W"], PROFILE["D"]   # half length, half beam, depth below deck
ZD = PROFILE["ZD"]           # deck height above water at midships
SHEER = PROFILE["SHEER"]     # deck rises this much at the ends
# Masts: (x, top, yard height, sail half width, sail height); the tallest carries the flag and
# the crow's nest.
MASTS = [(m[0] * L, ZD + m[1], ZD + m[1] - 14.0, m[2], m[3]) for m in PROFILE["masts"] if len(m) == 4]
# Lateen masts: (x, top, sail height); the triangular sail hangs from a yard slanting up aft.
LATEEN = [(m[0] * L, ZD + m[1], m[3]) for m in PROFILE["masts"] if len(m) == 5]
BOWSPRIT = PROFILE.get("bowsprit", False)
# The sails' emblem: the cog's two stripes, or a cross (owner's reference, the Pinta).
EMBLEM = PROFILE.get("emblem", "stripes")
MAIN = max(MASTS, key=lambda m: m[1])
MX = MAIN[0]                 # main mast position
MAST_TOP = MAIN[1]
YARD_Z = MAIN[2]
SAIL_W, SAIL_H, BELLY = MAIN[3], MAIN[4], 8.0
CASTLE_FRONT, CASTLE_RISE = PROFILE["castle"]
FORE_FROM, FORE_RISE = PROFILE["fore"]

MAT = {  # base colours
    "hull": (122, 82, 50), "tar": (60, 42, 30), "deck": (168, 124, 76), "castle": (110, 74, 46),
    "rail": (150, 108, 66), "mast": (92, 61, 34), "sail": (232, 220, 192), "faction": (255, 0, 255),
    "rope": (64, 45, 30), "foam": (226, 236, 236), "rib": (176, 132, 86), "boss": (190, 190, 180), "rim": (70, 60, 52),
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
    shell = np.maximum(outer, -inner_cut)
    return np.maximum(shell, -z - 0.01) if CLIP_WATERLINE else shell


# Bottom of the keel (the hull reaches D below the deck).
KEEL_Z = ZD - D


def f_frame(p):
    """Keel, stem and stern posts and ribs: the first stage on the slipway."""
    x, y, z = p
    ribs = np.abs(((x + L) % 9.0) - 4.5) - 0.9
    shell = np.maximum(f_hull(p), ribs)
    keel = box(p, (-L + 2, -1.6, KEEL_Z - 1), (L - 2, 1.6, KEEL_Z + 3))
    keel = np.maximum(keel, hull_outline(x, y, L + 2, W) - 1.0)
    posts = np.minimum(box(p, (L - 6, -1.4, KEEL_Z + 2), (L - 1, 1.4, ZD + SHEER)),
                       box(p, (-L + 1, -1.4, KEEL_Z + 2), (-L + 6, 1.4, ZD + SHEER)))
    posts = np.maximum(posts, hull_outline(x, y, L + 1.5, W) - 1.0)
    return np.minimum.reduce([shell, keel, posts])


def f_cradle(p):
    """Keel blocks the ship stands on while it is built."""
    out = np.full(p[0].shape, 99.0)
    for xc in np.linspace(-0.55 * L, 0.55 * L, 4 + int(L > 80)):
        out = np.minimum(out, box(p, (xc - 3, -7, KEEL_Z - 7), (xc + 3, 7, KEEL_Z + 1.5)))
    return out


def box(p, lo, hi):
    x, y, z = p
    return np.maximum.reduce([lo[0] - x, x - hi[0], lo[1] - y, y - hi[1], lo[2] - z, z - hi[2]])


def f_castle(p):
    x, y, z = p
    top = ZD + SHEER * 0.5 + CASTLE_RISE
    body = box(p, (-L + 3, -W, ZD - 3), (-L * CASTLE_FRONT, W, top))
    body = np.maximum(body, hull_outline(x, y, L + 1.5, W + 1.0) - 1.0)
    hollow = np.maximum(box(p, (-L + 5.5, -W + 2, top - 2.5), (-L * CASTLE_FRONT - 2.5, W - 2, top + 1)),
                        hull_outline(x, y, L - 1.0, W - 1.5) - 1.0)
    return np.maximum(body, -hollow)


CASTLE_TOP = ZD + SHEER * 0.5 + CASTLE_RISE
CASTLE_X = (-L + 3, -L * CASTLE_FRONT)


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


SHIELD_X = tuple(v * L / 66.0 for v in (-54.0, -43.5, -33.0)) if TYPE == "cog" else \
    tuple(np.linspace(-L + 12.0, -L * CASTLE_FRONT - 5.0, 3 + int(L > 80)))
# The warship's shields along the waist, hung on the rail.
WAIST_X = (tuple(np.arange(-L * CASTLE_FRONT + 8.0, L * (FORE_FROM if FORE_FROM > 0 else 0.7) - 4.0, 10.0))
           if WAR else ())


def f_shields(p):
    x, y, z = p
    out = np.full(x.shape, 99.0)
    for xc in SHIELD_X:
        ys = side_y(np.array(xc)) + 0.4
        zc = ZD + 7.0 if TYPE == "cog" else CASTLE_TOP - 6.0
        d = np.maximum(np.hypot(x - xc, z - zc) - 4.4, np.abs(np.abs(y) - ys - 0.4) - 0.9)
        out = np.minimum(out, d)
    for xc in WAIST_X:
        ys = side_y(np.array(xc)) + 0.4
        zc = deck_z(np.array(xc)) + 1.5
        d = np.maximum(np.hypot(x - xc, z - zc) - 4.0, np.abs(np.abs(y) - ys - 0.4) - 0.9)
        out = np.minimum(out, d)
    return out


def f_forecastle(p):
    x, y, z = p
    if FORE_FROM <= 0.0:
        return np.full(x.shape, 99.0)
    top = ZD + SHEER * 0.6 + FORE_RISE
    body = np.maximum(box(p, (L * FORE_FROM, -W, ZD), (L - 1.5, W, top)), hull_outline(x, y, L + 1.0, W + 0.5) - 1.0)
    hollow = np.maximum(box(p, (L * FORE_FROM + 2.5, -W, top - 2.0), (L, W, top + 1)), hull_outline(x, y, L - 2.0, W - 2.5) - 1.0)
    return np.maximum(body, -hollow)


def cylinder_z(p, cx, cy, r, z0, z1):
    x, y, z = p
    return np.maximum(np.hypot(x - cx, y - cy) - r, np.maximum(z0 - z, z - z1))


def f_mast(p):
    x, y, z = p
    parts = []
    for mx, top_z, yard_z, sail_w, _sail_h in MASTS:
        r = 1.8 if top_z == MAST_TOP else 1.4
        parts.append(cylinder_z(p, mx, 0, r, ZD - 3, top_z))
        parts.append(np.maximum(np.hypot(x - mx - 2.2, z - yard_z) - 1.2, np.abs(y) - sail_w - 4))
    for mx, top_z, sail_h in LATEEN:
        parts.append(cylinder_z(p, mx, 0, 1.3, ZD - 3, top_z))
        a, b = _lateen_yard(mx, top_z, sail_h)
        parts.append(segment(p, a, b, 1.0))
    if BOWSPRIT:
        parts.append(segment(p, np.array([L - 8.0, 0.0, ZD + SHEER + 2.0]), np.array([L + 22.0, 0.0, ZD + SHEER + 14.0]), 1.2))
    parts.append(cylinder_z(p, MX, 0, 3.2, MAST_TOP - 9, MAST_TOP - 5))  # crow's nest
    parts.append(box(p, (-L - 4.0, -1.0, 0.0), (-L + 2.0, 1.0, deck_z(np.array(L)) - 2.0)))  # rudder
    return np.minimum.reduce(parts)


def sail_x(y, z, mx=None, yard_z=None, sail_w=None, sail_h=None):
    mx = MX if mx is None else mx
    yard_z = YARD_Z if yard_z is None else yard_z
    sail_w = SAIL_W if sail_w is None else sail_w
    sail_h = SAIL_H if sail_h is None else sail_h
    t = np.clip((yard_z - 1 - z) / sail_h, 0, 1)
    return mx + 3.0 + BELLY * (1 - (y / sail_w) ** 2) * np.sin(np.pi * (0.25 + 0.75 * t)) * 0.9


def _lateen_yard(mx, top_z, sail_h):
    """The ends of a lateen yard: low before the mast, high behind it."""
    low = np.array([mx + sail_h * 0.45, 0.0, top_z - sail_h * 0.95])
    high = np.array([mx - sail_h * 0.55, 0.0, top_z + sail_h * 0.15])
    return low, high


def f_sail(p):
    x, y, z = p
    out = np.full(x.shape, 99.0)
    for mx, top_z, sail_h in LATEEN:
        # A triangle hanging from the yard, its foot a little above the deck, bellied to one side.
        low, high = _lateen_yard(mx, top_z, sail_h)
        foot_z = ZD + SHEER * 0.3 + 6.0
        t = np.clip((x - low[0]) / (high[0] - low[0]), 0.0, 1.0)
        yard_z = low[2] + (high[2] - low[2]) * t
        bottom = foot_z + (low[2] - foot_z) * (1.0 - np.clip((low[0] - x) / (low[0] - high[0]) * 1.6, 0.0, 1.0))
        inside = np.maximum.reduce([z - yard_z + 0.5, bottom - z, x - low[0], high[0] - x])
        belly = 3.0 * np.sin(np.pi * t) * np.clip((yard_z - z) / sail_h, 0.0, 1.0)
        out = np.minimum(out, np.maximum(np.abs(y - belly) - 0.8, inside))
    for mx, _top, yard_z, sail_w, sail_h in MASTS:
        inside = np.maximum(np.abs(y) - sail_w, np.maximum((yard_z - 1 - sail_h) - z, z - (yard_z - 1)))
        out = np.minimum(out, np.maximum(np.abs(x - sail_x(y, z, mx, yard_z, sail_w, sail_h)) - 0.9, inside))
    return out


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


ROPES = []
for _mx, _top, _yz, _sw, _sh in MASTS:
    ROPES += [(np.array([_mx, 0, _top - 8]), np.array([_mx - 14, s * (W - 1), ZD + 1])) for s in (-1, 1)]
    ROPES += [(np.array([_mx, 0, _top - 8]), np.array([_mx + 12, s * (W - 1), ZD + 1])) for s in (-1, 1)]
for _mx, _top, _sh in LATEEN:
    ROPES += [(np.array([_mx, 0, _top - 6]), np.array([_mx - 10, s * (W - 1), ZD + 1])) for s in (-1, 1)]
# The forestay from the foremost mast to the bow (or to the end of the bowsprit).
_FORE = max(MASTS, key=lambda m: m[0])
ROPES.append((np.array([_FORE[0], 0, _FORE[1] - 8]),
              np.array([L + 20, 0, ZD + SHEER + 13]) if BOWSPRIT else np.array([L + 2, 0, ZD + SHEER + 4])))


def f_rope(p):
    return np.minimum.reduce([segment(p, a, b, 0.5) for a, b in ROPES])


# --- J1 part 3: the big ships (caravel, carrack, galleon) ------------------------------------
# A round, tall hull: the bilge curves in towards the keel, the sides lean in towards the top
# (tumblehome), the deck sweeps up to bow and stern, and the castles rise out of the same hull
# (their sides go on leaning in). Rails with posts, dark wales, stern windows, gunports on the
# galleon. Masts carry square sails one over another with fighting tops between them, lateen
# mizzens, a spritsail under the bowsprit; a pennant on every mast. The cog keeps its own model.
if TYPE != "cog":
    TIER2_FRONT, TIER2_RISE = PROFILE["tier2"]
    STERN_FULL = PROFILE["stern"]
    TUMBLE = 0.24
    MAT["window"] = (236, 196, 104)
    MAT["rail"] = (196, 150, 78)      # an ochre rail along the top of the sides
    MAT["castle"] = (102, 64, 40)     # darker planking of the castles
    MAT["port"] = (34, 24, 18)
    NAMES = list(MAT)

    def deck_z(x):
        return ZD + SHEER * np.clip(np.abs(x) / L, 0, 1) ** 2.0

    def _step(v):
        return np.clip(v / 3.0 + 0.5, 0.0, 1.0)

    def top_z(x):
        """The walking deck: the waist, the stern castle (in one or two tiers), the forecastle."""
        rise = CASTLE_RISE * _step(-L * CASTLE_FRONT - x)
        if TIER2_RISE > 0:
            rise = rise + TIER2_RISE * _step(-L * TIER2_FRONT - x)
        if FORE_FROM > 0:
            rise = rise + FORE_RISE * _step(x - L * FORE_FROM)
        return deck_z(x) + rise

    def keel_z(x):
        # The keel sweeps up into a curved stem at the bow and the stern post aft.
        ax = np.clip(np.abs(x) / L, 0, 1)
        return KEEL_Z + 0.85 * D * np.where(x > 0, ax ** 2.4, ax ** 3.2)

    def half_width(x, z):
        # The upper hull reaches farther than the waterline: bow and stern overhang the water.
        reach = L * (0.84 + 0.16 * np.clip((z + 4.0) / (ZD + 8.0), 0, 1.15))
        ax = np.clip(np.abs(x) / reach, 0, 1)
        power = np.where(x > 0, 2.2, STERN_FULL)
        wx = W * np.sqrt(np.clip(1 - ax ** power, 0, 1))
        zw = ZD * 0.3
        below = np.sqrt(np.clip(1 - ((zw - z) / np.maximum(zw - keel_z(x), 1e-3)) ** 2, 0, 1))
        above = 1 - TUMBLE * np.clip((z - zw) / np.maximum(top_z(x) + 3 - zw, 1e-3), 0, 1.4) ** 2
        return wx * np.where(z < zw, below, above)

    def f_hull(p):
        x, y, z = p
        w = half_width(x, z)
        top = top_z(x)
        outer = np.maximum.reduce([np.abs(y) - w, z - (top + 3.0), keel_z(x) - z, np.abs(x) - L * 1.18])
        inner = np.maximum.reduce([top - z, np.abs(y) - (w - 2.2), np.abs(x) - (L - 5.0)])
        shell = np.maximum(outer, -inner)
        if BEAK:
            beak = segment(p, np.array([L - 6.0, 0.0, deck_z(np.array(L)) - 4.0]),
                           np.array([L + 14.0, 0.0, deck_z(np.array(L)) - 1.0]), 2.4)
            shell = np.minimum(shell, beak)
        return np.maximum(shell, -z - 0.01) if CLIP_WATERLINE else shell

    def f_castle(p):
        return np.full(p[0].shape, 99.0)

    f_forecastle = f_castle
    f_crenels = f_castle

    # The rig: square sails (mast x, yard height, half width, height, carries the emblem).
    BEAK = PROFILE["beak"]
    SAILS = []
    MASTS = []
    LATEEN = []
    TOPS = []   # fighting tops: (x, z)
    for m in PROFILE["rig"]:
        mx = m["x"] * L
        top = ZD + m["h"]
        if m.get("lateen"):
            LATEEN.append((mx, top, m["span"]))
            continue
        base = float(top_z(np.array(mx))) + 12.0
        avail = top - 4.0 - base
        tiers = m["tiers"]
        shares = {1: [0.92], 2: [0.34, 0.54], 3: [0.2, 0.3, 0.38]}[tiers]
        widths = {1: [1.0], 2: [0.72, 1.0], 3: [0.5, 0.74, 1.0]}[tiers]
        yard = top - 4.0
        for k, share in enumerate(shares):
            h = avail * share
            SAILS.append((mx, yard, m["w"] * widths[k], h, k == tiers - 1 or m["w"] * widths[k] >= 26))
            if k < tiers - 1:
                TOPS.append((mx, yard - h - 2.0))
            yard -= h + avail * 0.06
        MASTS.append((mx, top, SAILS[-1][1], m["w"], SAILS[-1][3]))
    if PROFILE["spritsail"]:
        SAILS.append((L + 14.0, ZD + SHEER + 9.0, 12.0, 13.0, False))
    MAIN = max(MASTS, key=lambda m: m[1])
    MX, MAST_TOP = MAIN[0], MAIN[1]
    SHIELD_X = ()
    WAIST_X = (tuple(np.arange(-L * CASTLE_FRONT + 7.0, L * FORE_FROM - 5.0, 9.0)) if WAR else ())

    def f_mast(p):
        x, y, z = p
        parts = []
        for mx, top_z_, _y, _w, _h in MASTS:
            parts.append(cylinder_z(p, mx, 0, 2.0 if top_z_ == MAST_TOP else 1.6, ZD - 3, top_z_))
        for mx, yard, sw, _h, _e in SAILS:
            parts.append(np.maximum(np.hypot(x - mx - 2.2, z - yard) - 1.1, np.abs(y) - sw - 3))
        for mx, zt in TOPS:
            parts.append(cylinder_z(p, mx, 0, 4.2, zt - 1.5, zt + 1.5))
        for mx, top, span in LATEEN:
            parts.append(cylinder_z(p, mx, 0, 1.4, ZD - 3, top))
            a, b = _lateen_yard(mx, top, span)
            parts.append(segment(p, a, b, 1.0))
        if BOWSPRIT:
            parts.append(segment(p, np.array([L - 8.0, 0.0, deck_z(np.array(L)) + 2.0]),
                                 np.array([L + 26.0, 0.0, deck_z(np.array(L)) + 16.0]), 1.4))
        parts.append(box(p, (-L - 2.0, -1.2, -2.0), (-L + 3.0, 1.2, ZD)))  # rudder
        return np.minimum.reduce(parts)

    def f_sail(p):
        x, y, z = p
        out = np.full(x.shape, 99.0)
        for mx, top, span in LATEEN:
            low, high = _lateen_yard(mx, top, span)
            foot_z = float(top_z(np.array(mx))) + 8.0
            t = np.clip((x - low[0]) / (high[0] - low[0]), 0.0, 1.0)
            yard_z = low[2] + (high[2] - low[2]) * t
            bottom = foot_z + (low[2] - foot_z) * (1.0 - np.clip((low[0] - x) / (low[0] - high[0]) * 1.6, 0.0, 1.0))
            inside = np.maximum.reduce([z - yard_z + 0.5, bottom - z, x - low[0], high[0] - x])
            belly = 3.0 * np.sin(np.pi * t) * np.clip((yard_z - z) / span, 0.0, 1.0)
            out = np.minimum(out, np.maximum(np.abs(y - belly) - 0.8, inside))
        for mx, yard, sw, sh, _e in SAILS:
            inside = np.maximum(np.abs(y) - sw, np.maximum((yard - 1 - sh) - z, z - (yard - 1)))
            out = np.minimum(out, np.maximum(np.abs(x - sail_x(y, z, mx, yard, sw, sh)) - 0.9, inside))
        return out

    def f_flag(p):
        """A flag on the main mast, a pennant on every other mast."""
        x, y, z = p
        out = np.full(x.shape, 99.0)
        tops = [(m[0], m[1], 16.0, 4.0) for m in MASTS] + [(m[0], m[1], 10.0, 2.0) for m in LATEEN]
        for mx, top, length, half in tops:
            size = 1.0 if top == MAST_TOP else 0.7
            ln, hf = length * size, half * size
            t = np.clip((x - mx) / ln, 0, 1)
            wave = 1.2 * np.sin((x - mx) * 0.45)
            out = np.minimum(out, np.maximum.reduce([np.abs(y - wave) - 0.7, mx - x, x - (mx + ln),
                                                     np.abs(z - (top - 1 - hf)) - hf * (1 - t) - 0.3]))
        return out

    ROPES = []
    for _mx, _top, _yz, _sw, _sh in MASTS + [(m[0], m[1], 0, 0, 0) for m in LATEEN]:
        _wy = float(half_width(np.array(_mx), np.array(float(top_z(np.array(_mx))) + 3.0)))
        for s in (-1, 1):
            ROPES.append((np.array([_mx, 0, _top - 8]), np.array([_mx - 10, s * (_wy - 0.5), float(top_z(np.array(_mx))) + 3])))
            ROPES.append((np.array([_mx, 0, _top - 8]), np.array([_mx + 8, s * (_wy - 0.5), float(top_z(np.array(_mx))) + 3])))
    _FORE = max(MASTS, key=lambda m: m[0])
    ROPES.append((np.array([_FORE[0], 0, _FORE[1] - 8]), np.array([L + 24, 0, float(deck_z(np.array(L))) + 15])))
    for _a, _b in zip(MASTS, MASTS[1:]):
        ROPES.append((np.array([_b[0], 0, _b[1] - 6]), np.array([_a[0], 0, _a[1] * 0.75])))

    def f_shields(p):
        x, y, z = p
        out = np.full(x.shape, 99.0)
        for xc in WAIST_X:
            zc = float(top_z(np.array(xc))) + 1.5
            ys = float(half_width(np.array(xc), np.array(zc))) + 0.4
            d = np.maximum(np.hypot(x - xc, z - zc) - 3.8, np.abs(np.abs(y) - ys - 0.4) - 0.9)
            out = np.minimum(out, d)
        return out

    def f_cradle(p):
        out = np.full(p[0].shape, 99.0)
        for xc in np.linspace(-0.55 * L, 0.55 * L, 5):
            kz = float(keel_z(np.array(xc)))
            out = np.minimum(out, box(p, (xc - 3, -8, KEEL_Z - 7), (xc + 3, 8, kz + 1.5)))
        return out

    def big_material(name, p, n):
        x, y, z = p
        if name == "hull":
            dz = float(deck_z(np.array(x)))
            tz = float(top_z(np.array(x)))
            if n[2] > 0.75:
                return "deck"
            if z < 3.5:
                return "tar"
            if n[0] < -0.7 and z > dz + 3.0 and (abs(y) % 6.0) < 2.6 and (z % 6.0) < 2.8:
                return "window"
            if PROFILE["ports"] and abs(n[1]) > 0.55 and dz - 8.5 < z < dz - 4.8 and ((x + 400.0) % 10.0) < 3.2 \
                    and abs(x) < L * 0.72:
                return "port"
            if z > tz + 0.3:
                return "rail"
            if z > dz + 2.0:
                return "castle"
            return "hull"
        if name == "shields":
            xc, zc = min(((v, float(top_z(np.array(v))) + 1.5) for v in WAIST_X),
                         key=lambda c: (c[0] - x) ** 2 + (c[1] - z) ** 2)
            r = np.hypot(x - xc, z - zc)
            if r < 1.2:
                return "boss"
            if r > 3.2:
                return "rim"
            return "faction" if (x - xc) * (z - zc) >= 0 else "sail"
        if name == "sail":
            for mx, yard, sw, sh, emblem in SAILS:
                if abs(x - mx) < BELLY + 6.0 and yard - sh - 1 <= z <= yard and abs(y) <= sw + 0.5:
                    if not emblem:
                        return "sail"
                    cz = yard - sh * 0.5
                    arm = min(sw * 0.42, sh * 0.4)
                    if (abs(y) < 2.4 and abs(z - cz) < arm * 1.15) or (abs(z - cz) < 2.4 and abs(y) < arm):
                        return "faction"
                    return "sail"
            return "sail"
        return None


PARTS = [("hull", f_hull), ("castle", f_castle), ("forecastle", f_forecastle), ("mast", f_mast),
         ("sail", f_sail), ("flag", f_flag), ("rope", f_rope), ("crenels", f_crenels), ("shields", f_shields)]


def fields(p):
    return np.stack([f(p) for _, f in PARTS])


def use_stage(stage):
    """Sets PARTS (and the water) for a building stage on the slipway."""
    global PARTS, WATER, CLIP_WATERLINE
    WATER = KEEL_Z - 7.0
    CLIP_WATERLINE = False
    hull = ("frame", f_frame) if stage == 0 else ("hull", f_hull)
    parts = [hull, ("cradle", f_cradle)]
    if stage >= 1:
        parts += [("castle", f_castle), ("forecastle", f_forecastle), ("crenels", f_crenels)]
    if stage >= 2:
        parts += [("mast", f_mast), ("sail", f_sail), ("flag", f_flag), ("rope", f_rope),
                  ("shields", f_shields)]
    PARTS = parts


def material(part, p, n):
    x, y, z = p
    name = PARTS[part][0]
    if TYPE != "cog":
        special = big_material(name, p, n)
        if special is not None:
            return special
    if name == "frame":
        return "rib"
    if name == "cradle":
        return "castle"
    if name == "hull":
        if n[2] > 0.75:
            return "deck"
        if z < 3.5:
            return "tar"
        return "hull"
    if name in ("castle", "forecastle", "crenels"):
        return "rail" if n[2] > 0.75 else "castle"
    if name == "shields":
        zs = ZD + 7.0 if TYPE == "cog" else CASTLE_TOP - 6.0
        centres = [(v, zs) for v in SHIELD_X] + [(v, float(deck_z(np.array(v))) + 1.5) for v in WAIST_X]
        if TYPE == "cog":
            centres = [(v, zs) for v in SHIELD_X]   # the cog's look stays as it was
        xc, zc = min(centres, key=lambda c: (c[0] - x) ** 2 + (c[1] - z) ** 2)
        r = np.hypot(x - xc, z - zc)
        if r < 1.2:
            return "boss"
        if r > 3.5:
            return "rim"
        return "faction" if (x - xc) * (z - zc) >= 0 else "sail"
    if name == "sail":
        if EMBLEM == "cross":
            # A cross in the faction's colour in the middle of each square sail (the Pinta).
            for mx, _top, yard_z, sail_w, sail_h in MASTS:
                if abs(x - mx) < BELLY + 6.0 and yard_z - sail_h - 1 <= z <= yard_z:
                    cz = yard_z - sail_h * 0.5
                    arm = sail_w * 0.42
                    if (abs(y) < 2.6 and abs(z - cz) < arm * 1.1) or (abs(z - cz) < 2.6 and abs(y) < arm):
                        return "faction"
                    return "sail"
            return "sail"
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
        under = (~inside) & (q[2] < WATER)
        ui = idx[under]
        if ui.size and WATER < 0:
            alive[ui] = False
        elif ui.size:
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
        thin = [i for i, (name, _) in enumerate(PARTS) if name in ("sail", "flag", "rope")]
        two_sided = np.isin(hit[hi], thin)
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
            if name == "rail" and TYPE != "cog" and (p[0, k] % 4.0) < 1.0:
                shade *= 0.7   # posts of the rail
            if name == "castle" and TYPE != "cog" and (p[2, k] % 4.0) < 0.6:
                shade *= 0.8   # planks of the castle sides
            if name == "hull" and TYPE != "cog" and any(abs(p[2, k] - (deck_z(p[0, k]) - dz)) < 1.1 for dz in (5.0, 10.0)):
                shade *= 0.35   # dark wales along the side (the Pinta)
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


def paint_faction(frame):
    """Magenta faction parts (shades of (255, 0, 255)) in the faction colour, same shade."""
    rgb = frame[:, :, :3].astype(int)
    magenta = (frame[:, :, 3] > 0) & (rgb[:, :, 1] < 40) & (np.abs(rgb[:, :, 0] - rgb[:, :, 2]) < 12) & (rgb[:, :, 0] > 40)
    shade = rgb[:, :, 0] / 255.0
    out = frame.copy()
    for c in range(3):
        out[:, :, c] = np.where(magenta, np.clip(FACTION[c] * shade * 1.15, 0, 255), frame[:, :, c])
    return out


def bob(frame, dy):
    """The frame moved dy px up or down (the ship rocking), padding with empty pixels."""
    out = np.zeros_like(frame)
    if dy < 0:
        out[:dy] = frame[-dy:]
    elif dy > 0:
        out[dy:] = frame[:-dy]
    else:
        out[:] = frame
    return out


def main():
    import os
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "ships", SHIP_ID)
    os.makedirs(out, exist_ok=True)
    if STAGES:
        headings = [-90, -45, 0, 45, 90, 135, 180, -135]
        # --stage=N renders that stage only (a warship's last stage; the first two are the
        # same as its trading sister's).
        only = next((int(a.split("=", 1)[1]) for a in sys.argv if a.startswith("--stage=")), -1)
        for stage in range(3):
            if only >= 0 and stage != only:
                continue
            use_stage(stage)
            rows = [paint_faction(render(math.radians(h))) for h in headings]
            Image.fromarray(np.concatenate(rows, axis=0), "RGBA").save(os.path.join(out, "build_%d.png" % stage))
            print("stage", stage, "done", flush=True)
        return
    # ART_SPEC order S, SE, E, NE, N, NW, W, SW; on the ground S = towards the camera.
    headings = [-90, -45, 0, 45, 90, 135, 180, -135]
    rows = []
    for i, h in enumerate(headings):
        frame = paint_faction(render(math.radians(h)))
        rows.append(np.concatenate([bob(frame, dy) for dy in BOB], axis=1))
        print("dir", i, "done", flush=True)
    sheet = np.concatenate(rows, axis=0)
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "ships", SHIP_ID)
    os.makedirs(out, exist_ok=True)
    Image.fromarray(sheet, "RGBA").save(os.path.join(out, "idle.png"))


if __name__ == "__main__":
    main()
