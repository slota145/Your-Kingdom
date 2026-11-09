"""SpriteKiln trial: the big ships (J1 part 3) in the SpriteKiln style, from the same proportions as
tools/render_cog.py (PROFILES, there in pixels; here 1 px = 0.05176 units).

Writes art/specs/props/<type>/<type>.yaml for caravel and galleon: 8 directions x 4 rocking frames,
the game's frames (caravel 270 with the waterline centre at (135, 206), galleon 370 at (185, 290)).
Bow = +z, waterline y = 0. Square sails are the front caps of big ellipsoid shells (filled by the
wind), lateen sails flat triangles on slanted yards, a cross in the faction's colour on the sails.

Run: python3 tools/spritekiln/gen_big_ships.py [caravel|galleon]
"""
import math
import os
import sys

import yaml

HERE = os.path.dirname(os.path.abspath(__file__))
PROPS = os.path.join(HERE, "art", "specs", "props")
K = 0.05176

TYPES = {
    # caravel after the owner's Pinta reference (2026-11-09): a long low quarterdeck from just aft of the
    # mainmast with the mizzen on it, a small low forecastle carrying the foremast
    "caravel": dict(L=78, W=21, D=24, S=14, castle=(0.14, 0), tier2=None, fore=(0.46, 0), flush=True, size=270, pivot=206,
                    rig=[dict(z=0.6, h=78, w=19, tiers=1, cross=True), dict(z=0.04, h=106, w=30, tiers=1, cross=True),
                         dict(z=-0.55, h=86, span=44, lateen=True)],
                    spritsail=False, beak=False, ports=False, wales=[0.35, 0.7],
                    profile=dict(zm=0.4, wt=0.62, forefoot=0.3, rake=0.3, fc=(0.46, 0.35, 0.6),
                                 qd=(-0.14, 0.3, 0.95))),
    "galleon": dict(L=108, W=31, D=27, S=16, castle=(0.38, 17), tier2=(0.66, 14), fore=(0.62, 12), size=370,
                    pivot=290,
                    # owner 2026-11-09: no bonaventure mast; main and mizzen further aft, bigger sails,
                    # the lateen filled by the wind
                    rig=[dict(z=0.5, h=134, w=34, tiers=3, cross=True), dict(z=-0.1, h=172, w=48, tiers=3, cross=True),
                         dict(z=-0.52, h=126, span=72, lateen=True, billow=True, y0=1.75)],
                    spritsail=True, beak=True, ports=True, wales=[0.3, 0.55, 0.8],
                    # galleon (owner's references 2026-11-09): tumblehome, a two-tier stern, a beakhead
                    profile=dict(zm=0.25, wt=0.72, forefoot=0.3, rake=0.55, fc=(0.6, 0.7, 0.9), qd=(-0.3, 0.85, 1.05),
                                 poop=(-0.62, 1.55, 1.8), tumble=True), ornate_stern=True),
}


def r3(v):
    return [round(float(x), 3) for x in v] if isinstance(v, (list, tuple)) else round(float(v), 3)


def build(kind, war=False, stage=None):
    """stage None: the ship afloat, rocking; 0/1/2: on the slipway (keel and ribs / planked hull and
    castles / the whole ship), on keel blocks, out of the water. war: red faction and shields."""
    t = TYPES[kind]
    Lh, W, D, S = t["L"] * K, t["W"] * K, t["D"] * K, t["S"] * K
    parts, bones = {}, {"ship": {"parent": "root", "pos": "[0, bob, 0]", "rot": "[pitch, 0, roll]"}}

    def part(name, material, prims, cut=None, **kw):
        p = {"material": material, "space": "ship", "prims": prims}
        if cut:
            p["cut"] = cut
        p.update(kw)
        parts[name] = p

    # The hull (owner's sketches 2026-11-09): the side profile (flat bottom, a convex rounded forefoot,
    # a nearly upright raked transom, a raised forecastle, a low waist, a step up to the quarterdeck
    # rising to the stern) extruded across the ship, then cut to the plan (a pointed bow, widest about a
    # third of the length from the bow, straight sides narrowing to a flat transom).
    pr = t["profile"]
    Y0 = -0.4                                     # below the waterline (cut off)
    zm = pr["zm"] * Lh
    Wt = pr["wt"] * W

    def half_w(z):                                    # the half beam in plan
        if z >= zm:
            u = (z - zm) / (Lh - zm)
            return W * max(0.0, 1 - u * u)
        u = (zm - z) / (zm + Lh)
        return W - (W - Wt) * u ** 1.6

    tum = pr.get("tumble")                        # tumblehome: two planes leaning the sides in above the waist

    # owner 2026-11-09: the galleon's upper (stern) decks narrower: a second, steeper pair of planes
    # that only reaches the high castles
    D2 = 0.85 * W * 0.9 + 0.53 * (D + 0.8)

    def side_x(y):
        if not tum:
            return 99.0
        return min((0.96 * W + 0.28 * D - 0.28 * y) / 0.96, (D2 - 0.53 * y) / 0.85)

    def waist(z):
        return D + 0.1 * (z / Lh) ** 2

    F, Dc = pr["forefoot"] * Lh, D * 0.7
    fz, fcf, fcb = pr["fc"]
    fz *= Lh
    qz, qdf, qde = pr["qd"]
    qz *= Lh
    poop = pr.get("poop")
    stern_top = D + (poop[2] if poop else qde)
    bow_curve = [(Lh - F + F * math.cos(math.radians(a)), Dc + (Dc - Y0) * math.sin(math.radians(a)))
                 for a in range(-90, 1, 15)]
    top = [(Lh, D + fcb), (fz, D + fcf), (fz, waist(fz))]
    top += [(z, waist(z)) for z in [fz + (qz - fz) * k / 4 for k in range(1, 4)]]
    top += [(qz, waist(qz)), (qz, D + qdf)]
    decks = [("waist", qz + 0.1, fz - 0.1, D - 0.45, D + 0.1)]
    if poop:
        pz = poop[0] * Lh
        top += [(pz, D + qde), (pz, D + poop[1]), (-Lh, stern_top)]
        decks += [("quarter", pz + 0.1, qz - 0.1, D + qdf - 0.28, D + qde),
                  ("poop", -Lh + 0.12, pz - 0.1, D + poop[1] - 0.28, stern_top)]
    else:
        top += [(-Lh, stern_top)]
        decks += [("quarter", -Lh + 0.12, qz - 0.1, D + qdf - 0.28, stern_top)]
    decks += [("fore", fz + 0.1, Lh - 0.35, D + fcf - 0.28, D + fcb)]
    rake = pr["rake"]
    profile = [(-Lh + rake, Y0), (Lh - F, Y0)] + bow_curve[1:] + top

    def side_extrude(poly, depth, c=(0, 0, 0)):
        return {"extrude": {"c": r3(list(c)), "rot": [0, -1.5708, 0], "depth": r3(depth),
                            "profile": {"polygon": r3p([[z, y] for (z, y) in poly])}}}

    def plan_extrude(poly, y_lo, y_hi):
        return {"extrude": {"c": r3([0, (y_lo + y_hi) / 2, 0]), "rot": [1.5708, 0, 0], "depth": r3(y_hi - y_lo),
                            "profile": {"polygon": r3p([[x, z] for (x, z) in poly])}}}

    zs = [-Lh + 2 * Lh * k / 12 for k in range(13)]
    outline = [(half_w(z), z) for z in zs]
    right = [(0, Lh + 3), (W + 3, Lh + 3), (W + 3, -Lh - 3), (Wt, -Lh - 3)] + outline
    left = [(-x, z) for (x, z) in reversed(right)]

    def inner(z_a, z_b, y_top, th=0.1):
        pts = []
        for k in range(8):
            z = z_a + (z_b - z_a) * k / 7
            x = min(half_w(z), side_x(y_top)) - th
            if x > 0.08:
                pts.append((x, z))
        return pts + [(-x, z) for (x, z) in reversed(pts)]

    cut = [{"plane": {"n": [0, -1, 0], "at": 0.0}}, plan_extrude(right, -1, 8), plan_extrude(left, -1, 8)]
    if tum:
        cut += [{"plane": {"n": [sx * 0.96, 0.28, 0], "at": r3(0.96 * W + 0.28 * D)}} for sx in (-1, 1)]
        cut += [{"plane": {"n": [sx * 0.85, 0.53, 0], "at": r3(D2)}} for sx in (-1, 1)]
    for (_, za, zb, floor, ytop) in decks:
        cut.append(plan_extrude(inner(za, zb, ytop), floor, floor + 6))

    def curve_band(frac, h, lift=0.0):
        zz = [-Lh - 0.6 + (2 * Lh + 1.2) * k / 10 for k in range(11)]
        f = [D * frac + 0.16 * (z / Lh) ** 2 + 0.3 * max(0.0, -z / Lh) ** 2 + lift for z in zz]
        return [(z, y) for z, y in zip(zz, f)] + [(z, y + h) for z, y in reversed(list(zip(zz, f)))]

    def strip(a, b, h=0.12):                       # a rail band along a straight stretch of the top edge
        return [a, b, (b[0], b[1] - h), (a[0], a[1] - h)]

    rails = [strip(top[0], top[1]), strip((fz, waist(fz)), (qz, waist(qz))), strip(top[-2], top[-1])]
    if poop:
        rails.append(strip((qz, D + qdf), (pz, D + qde)))
    seams = [curve_band(0, 0.055, lift=-0.1 + 0.21 * k) for k in range(int((stern_top + 0.6) / 0.21))]
    paint = [{"material": "strake", "prims": [side_extrude(b, 2 * W + 1) for b in seams]},
             {"material": "wale", "prims": [side_extrude(curve_band(f, 0.13), 2 * W + 1) for f in t["wales"]]},
             {"material": "rail", "prims": [side_extrude(r, 2 * W + 1) for r in rails]}]
    if t["ports"]:   # gun ports along both sides, between the upper wales
        pf = (t["wales"][1] + t["wales"][2]) / 2
        ports = []
        for i in range(7):
            z = -Lh * 0.45 + i * Lh * 0.14
            y = D * pf + 0.16 * (z / Lh) ** 2 + 0.3 * max(0.0, -z / Lh) ** 2 + 0.06
            ports += [{"box": {"c": r3([sx * W, y, z]), "half": [0.5, 0.1, 0.11]}} for sx in (-1, 1)]
        paint.append({"material": "port", "prims": ports})

    def transom_z(y):
        return -Lh + rake * (1 - (y - Y0) / (stern_top - Y0))

    wins = []
    rows = [stern_top - 0.42] + ([stern_top - 0.95] if poop else [])
    for y in rows:
        n = 4 if Wt > 1.0 else 2
        for k in range(n):
            x = (k - (n - 1) / 2) * Wt * 0.42
            wins.append({"box": {"c": r3([x, y, transom_z(y)]), "half": [0.09, 0.13, 0.22]}})
    paint.append({"material": "port", "prims": wins})
    part("hull", "hull", [side_extrude(profile, 2 * W + 0.4)], cut=cut, priority=1, paint=paint)
    part("decks", "deck", [plan_extrude(inner(za, zb, ytop, 0.08), floor - 0.03, floor + 0.03)
                           for (_, za, zb, floor, ytop) in decks],
         paint=[{"material": "deck_seam", "stripes": {"axis": "x", "period": 0.2, "width": 0.06}}])
    H = stern_top * 0.75
    if t.get("ornate_stern"):   # owner 2026-11-09: a richer galleon stern
        def xl(y):
            return min(half_w(-Lh + rake * 0.5), side_x(y)) - 0.06
        yg = stern_top - 1.0          # a stern gallery (balcony) across the transom, under the upper windows
        zg = transom_z(yg)
        part("gallery", "castle", [
            {"box": {"c": r3([0, yg, zg - 0.2]), "half": r3([xl(yg), 0.05, 0.22])}},
            {"box": {"c": r3([0, yg + 0.66, zg - 0.2]), "half": r3([xl(yg + 0.6), 0.04, 0.25])}}])
        part("gallery_rail", "rail", [{"box": {"c": r3([0, yg + 0.17, zg - 0.4]), "half": r3([xl(yg), 0.12, 0.03])}}] +
             [{"box": {"c": r3([sx * xl(yg), yg + 0.35, zg - 0.4]), "half": [0.04, 0.32, 0.04]}} for sx in (-1, 1)],
             paint=[{"material": "rail_dark", "stripes": {"axis": "x", "period": 0.13, "width": 0.05}}])
        # quarter galleries: little bays with windows on both sides of the stern
        zq = -Lh + rake + 0.5
        yq0, yq1 = D + 0.35, stern_top - 0.35
        for sx in (-1, 1):
            xq = sx * (min(half_w(zq), side_x(yq1)) + 0.1)
            part(f"quarter_{'l' if sx < 0 else 'r'}", "rail", [
                {"box": {"c": r3([xq, (yq0 + yq1) / 2, zq]), "half": r3([0.16, (yq1 - yq0) / 2, 0.36]), "round": 0.03}},
                {"ellipsoid": {"c": r3([xq, yq1 + 0.05, zq]), "r": [0.18, 0.22, 0.38]}},
                {"cone": {"a": r3([xq, yq0 + 0.02, zq]), "b": r3([xq - sx * 0.05, yq0 - 0.35, zq]), "r": [0.18, 0.04]}}],
                 paint=[{"material": "port", "prims": [{"box": {"c": r3([xq + sx * 0.16, y, zq + dz]), "half": [0.06, 0.12, 0.08]}}
                                                       for y in (yq0 + 0.35, yq1 - 0.35) for dz in (-0.16, 0.16)]}])
        # the carved top of the transom: an arched ochre crest with the faction's shield, a lantern above
        yt = stern_top
        crest = [[0.0, 0.0]] + [[round(xl(yt) * math.cos(math.radians(a)), 3), round(0.45 * math.sin(math.radians(a)), 3)]
                                for a in range(0, 181, 20)]
        crest = crest[1:]
        part("crest", "rail", [{"extrude": {"c": r3([0, yt - 0.05, transom_z(yt) + 0.06]), "depth": 0.12,
                                             "profile": {"polygon": r3p(crest)}}}],
             paint=[{"material": "rail_dark", "stripes": {"axis": "y", "at": [r3(yt + 0.05)], "width": 0.05}}])
        part("crest_shield", "faction", [{"cylinder": {"a": r3([0, yt + 0.14, transom_z(yt) - 0.02]),
                                                        "b": r3([0, yt + 0.14, transom_z(yt) - 0.08]), "r": 0.17}}], priority=2)
        part("lantern", "rail", [{"cylinder": {"a": r3([0, yt + 0.4, -Lh + 0.25]), "b": r3([0, yt + 0.72, -Lh + 0.25]), "r": 0.1}},
                                 {"cone": {"a": r3([0, yt + 0.72, -Lh + 0.25]), "b": r3([0, yt + 0.95, -Lh + 0.25]), "r": [0.13, 0.02]}}],
             paint=[{"material": "sail", "stripes": {"axis": "y", "at": [r3(yt + 0.56)], "width": 0.12}}])
    part("rudder", "castle", [{"box": {"c": r3([0, H / 2, transom_z(H / 2) - 0.1]), "half": r3([0.06, H / 2, 0.18]),
                                       "rot": r3([-math.atan2(rake, stern_top - Y0), 0, 0])}}])
    if t["beak"]:   # the galleon's beakhead, low in front of the stem
        part("beak", "castle", [side_extrude([(Lh - 0.3, D * 0.5), (Lh + 1.0, D * 0.78), (Lh + 1.05, D * 0.9),
                                              (Lh - 0.2, D + 0.25)], 0.35)])

    def tumble(y):
        return min(W, side_x(y))

    bow_top = D + fcb
    bs_a, bs_b = [0, bow_top - 0.1, Lh - 0.4], [0, bow_top + 0.9, Lh + 1.6]
    part("bowsprit", "mast", [{"cylinder": {"a": r3(bs_a), "b": r3(bs_b), "r": 0.07}}], priority=2, min_cover=2)

    # masts and sails
    ropes = []
    for i, m in enumerate(t["rig"]):
        z, h = m["z"] * Lh, m["h"] * K
        bn = f"mast{i}"
        bones[bn] = {"parent": "ship", "pos": r3([0, 0, z]), "rot": [0, 0.3 if not m.get("lateen") else 0.0, 0]}
        part(f"{bn}_pole", "mast", [{"cylinder": {"a": r3([0, D - 0.2, z]), "b": r3([0, h + 0.3, z]),
                                                  "r": 0.1 if h > 6 else 0.08}}], priority=3, min_cover=2)
        ropes += [{"cylinder": {"a": r3([0, h * 0.92, z]), "b": r3([sx * (min(half_w(z + dz), tumble(D)) - 0.03), D + 0.05, z + dz]), "r": 0.02}}
                  for sx in (-1, 1) for dz in (-0.35, 0.25)]
        # pennant
        parts[f"{bn}_pennant"] = {"material": "faction", "space": "ship", "min_cover": 2, "prims": [
            {"extrude": {"c": r3([0, h + 0.22, z - 0.05]), "rot": [0, 1.5708, 0], "depth": 0.06,
                         "profile": {"polygon": r3p([[-0.3, 0.12], [-0.3, -0.12], [0.7, 0.0]])}}}]}
        if m.get("lateen"):
            s = m["span"] * K
            y0 = D + m["y0"] if "y0" in m else D + S * (0.6 if m["z"] < -0.5 else 0.4) + 0.7
            A, B = (0.5 * s, y0), (-0.62 * s, h)
            C = (-0.5 * s, y0 - 0.1)
            parts[f"{bn}_yard"] = {"material": "mast", "space": bn, "priority": 2, "min_cover": 2, "prims": [
                {"cylinder": {"a": r3([0, A[1] - 0.1, A[0] + 0.15]), "b": r3([0, B[1] + 0.15, B[0] - 0.12]), "r": 0.05}}]}
            if m.get("billow"):   # the cap of a big ellipsoid shell cut to the triangle: filled by a side wind
                tri = [(A[0], A[1]), (B[0], B[1]), (C[0], C[1])]          # (z, y)
                zc, yc = sum(p_[0] for p_ in tri) / 3, sum(p_[1] for p_ in tri) / 3
                Rz = 1.5 * max(abs(p_[0] - zc) for p_ in tri)
                Ry = 1.5 * max(abs(p_[1] - yc) for p_ in tri)
                cuts = [{"plane": {"n": [-1, 0, 0], "at": 0.22}}]      # keep x > -0.22: the cap only
                for (z1, y1), (z2, y2) in zip(tri, tri[1:] + tri[:1]):
                    nz, ny = (y2 - y1), -(z2 - z1)                        # perpendicular to the edge
                    ln = math.hypot(nz, ny)
                    nz, ny = nz / ln, ny / ln
                    if nz * (zc - z1) + ny * (yc - y1) > 0:              # point it away from the middle
                        nz, ny = -nz, -ny
                    cuts.append({"plane": {"n": r3([0, ny, nz]), "at": r3(nz * z1 + ny * y1)}})
                parts[f"{bn}_sail"] = {"material": "sail", "space": bn, "priority": 2, "prims": [
                    {"ellipsoid": {"c": r3([-0.32, yc, zc]), "r": r3([0.62, Ry, Rz]), "shell": 0.11}}], "cut": cuts}
            else:
                parts[f"{bn}_sail"] = {"material": "sail", "space": bn, "priority": 2, "prims": [
                    {"extrude": {"c": [0.05, 0, 0], "rot": [0, 1.5708, 0], "depth": 0.07,
                                 "profile": {"polygon": r3p([[-A[0], A[1]], [-B[0], B[1]], [-C[0], C[1]]])}}}]}
            continue
        hw0, tiers = m["w"] * K, m["tiers"]
        ylo, yhi = D + 0.9, h - 0.25
        th = (yhi - ylo) / tiers
        for k in range(tiers):
            hw = hw0 * (1 - 0.2 * k)
            yb, yt = ylo + k * th + 0.06, ylo + (k + 1) * th - 0.06
            hh = (yt - yb) / 2
            yc = (yt + yb) / 2
            parts[f"{bn}_yard{k}"] = {"material": "mast", "space": bn, "priority": 2, "min_cover": 2, "prims": [
                {"cylinder": {"a": r3([-hw - 0.1, yt + 0.04, 0.18]), "b": r3([hw + 0.1, yt + 0.04, 0.18]), "r": 0.045}}]}
            depth = 0.28 + 0.3 * hw
            cap = {"ellipsoid": {"c": r3([0, yc, 0.1]), "r": r3([hw * 1.41, hh * 1.5, depth]), "shell": 0.08}}
            sail = {"material": "sail", "space": bn, "priority": 2, "prims": [cap], "cut": [
                {"plane": {"n": [0, 0, -1], "at": -0.22}}, {"plane": {"n": [1, 0, 0], "at": r3(hw)}},
                {"plane": {"n": [-1, 0, 0], "at": r3(hw)}}, {"plane": {"n": [0, 1, 0], "at": r3(yt)}},
                {"plane": {"n": [0, -1, 0], "at": r3(-yb)}}]}
            if m.get("cross") and k < 2:
                a = min(hw, hh) * 0.55
                sail["paint"] = [{"material": "faction", "prims": [
                    {"box": {"c": r3([0, yc, 0.5]), "half": r3([0.09, a, 1.0])}},
                    {"box": {"c": r3([0, yc + a * 0.2, 0.5]), "half": r3([a * 0.8, 0.09, 1.0])}}]}]
            parts[f"{bn}_sail{k}"] = sail
            if k == 0 and tiers > 1:   # a crow's nest at the top of the lowest tier
                parts[f"{bn}_top"] = {"material": "castle", "space": "ship", "prims": [
                    {"cylinder": {"a": r3([0, yt + 0.1, z]), "b": r3([0, yt + 0.32, z]), "r": 0.3, "shell": 0.07}}]}
        # stays from the masthead forward
        prev = t["rig"][i - 1] if i > 0 else None
        if i == 0:
            ropes.append({"cylinder": {"a": r3([0, h * 0.95, z]), "b": r3(bs_b), "r": 0.022}})
        elif prev and not prev.get("lateen"):
            ropes.append({"cylinder": {"a": r3([0, h * 0.95, z]), "b": r3([0, prev["h"] * K * 0.55, prev["z"] * Lh]), "r": 0.022}})
    if t["spritsail"]:
        bones["sprit"] = {"parent": "ship", "pos": r3([0, bow_top + 0.6, Lh + 0.9]), "rot": [0, 0.0, 0]}
        parts["spritsail"] = {"material": "sail", "space": "sprit", "priority": 2, "prims": [
            {"ellipsoid": {"c": [0, -0.25, 0.0], "r": [1.1, 0.6, 0.4], "shell": 0.08}}], "cut": [
            {"plane": {"n": [0, 0, -1], "at": -0.12}}, {"plane": {"n": [1, 0, 0], "at": 0.75}},
            {"plane": {"n": [-1, 0, 0], "at": 0.75}}, {"plane": {"n": [0, 1, 0], "at": 0.05}},
            {"plane": {"n": [0, -1, 0], "at": 0.62}}]}
    part("ropes", "rope", ropes, min_cover=2)
    # foam at the waterline (world space, stays on the water while the ship rocks)
    z_ws = -Lh + rake
    z_wb = Lh - F + F * math.cos(math.asin(max(-1.0, (0 - Dc) / (Dc - Y0))))
    fp = [(half_w(z) + 0.13, z) for z in [z_ws - 0.12 + (z_wb - z_ws + 0.12) * k / 8 for k in range(9)]]
    fp = fp + [(0, z_wb + 0.28)] + [(-x, z) for (x, z) in reversed(fp)]
    parts["foam"] = {"material": "foam", "prims": [plan_extrude(fp, 0.0, 0.1),
        {"sphere": {"c": r3([0, 0, z_wb + 0.2]), "r": 0.22}}, {"sphere": {"c": r3([0.25, 0, z_wb]), "r": 0.15}},
        {"sphere": {"c": r3([-0.25, 0, z_wb]), "r": 0.15}}],
        "cut": [{"plane": {"n": [0, -1, 0], "at": 0.0}}],
        "paint": [{"material": "foam_dark", "spots": {"scale": 0.12, "density": 0.3, "seed": 5}}]}

    if war:   # round shields along both sides of the waist, faction red with a white bar
        shields, marks = [], []
        n = 6 if kind == "caravel" else 8
        for k in range(n):
            z = qz + 0.35 + (fz - qz - 0.7) * k / (n - 1)
            y = waist(z) - 0.16
            for sx in (-1, 1):
                x = sx * (half_w(z) + 0.01)
                shields.append({"cylinder": {"a": r3([x, y, z]), "b": r3([x + sx * 0.06, y, z]), "r": 0.17}})
                marks.append({"box": {"c": r3([x + sx * 0.05, y, z]), "half": [0.06, 0.04, 0.12]}})
        parts["shields"] = {"material": "faction", "space": "ship", "priority": 2, "prims": shields,
                            "paint": [{"material": "sail", "prims": marks}]}
    if stage is not None:   # on the slipway: out of the water on keel blocks, no foam
        parts.pop("foam")
        parts["hull"]["cut"][0] = {"plane": {"n": [0, -1, 0], "at": 0.35}}
        parts["blocks"] = {"material": "castle", "prims": [
            {"box": {"c": r3([0, -0.58, z]), "half": [0.55, 0.22, 0.2]}} for z in
            [-Lh * 0.6, -Lh * 0.2, Lh * 0.2, Lh * 0.55]]}
        if stage < 2:
            for name in [n_ for n_ in parts if n_.startswith(("mast", "ropes", "bowsprit", "spritsail", "shields"))]:
                parts.pop(name)
        if stage < 1:   # the bare frame: keel, stem and sternpost, U-shaped ribs along the hull
            for name in ("hull", "decks", "rudder", "beak"):
                parts.pop(name, None)
            tops = sorted(top)

            def top_at(z):
                for (z0, y0_), (z1, y1_) in zip(tops, tops[1:]):
                    if z0 <= z <= z1 and z1 > z0:
                        return y0_ + (y1_ - y0_) * (z - z0) / (z1 - z0)
                return tops[-1][1]
            ribs = []
            for k in range(13):
                z = -Lh + rake + 0.2 + (2 * Lh - rake - F * 0.6) * k / 12
                hb = half_w(z) - 0.04
                if hb < 0.15:
                    continue
                ty = top_at(z) - 0.05
                ribs.append({"tube": {"pts": r3p([[-hb, ty, z], [-hb * 1.02, 0.3, z], [0, -0.42, z],
                                                    [hb * 1.02, 0.3, z], [hb, ty, z]]), "r": 0.055}})
            parts["ribs"] = {"material": "hull", "space": "ship", "prims": ribs}
            parts["keel"] = {"material": "castle", "space": "ship", "prims": [
                {"box": {"c": r3([0, -0.3, (Lh - F - Lh + rake) / 2]), "half": r3([0.12, 0.1, (2 * Lh - F - rake) / 2])}},
                side_extrude(bow_curve + [(Lh, D + fcb), (Lh - 0.2, D + fcb), (Lh - F + 0.05, Y0 + 0.25)], 0.2),
                side_extrude([(-Lh + rake, Y0), (-Lh, stern_top), (-Lh + 0.2, stern_top), (-Lh + rake + 0.2, Y0)], 0.2)],
                "cut": [{"plane": {"n": [0, -1, 0], "at": 0.42}}]}

    size = t["size"]
    cy = (t["pivot"] - size / 2) * K / math.cos(math.radians(30))
    amp = 0.6 if kind == "galleon" else 0.8
    return {
        "spritekiln": 1,
        "name": kind,
        "render": {"outline": "dark", "lines": "depth+normal", "light": "classic", "shading": "toon"},
        "kind": "prop",
        "size": size,
        "directions": 8,
        "mirror": False,
        "palette": ["../../palettes/kingdom.yaml", "../../palettes/town.yaml"],
        "camera": {"pitch": 30, "scale": K, "center": [0, r3(cy), 0]},
        "shadow": None,
        "ramps": {
            "hull": (["#160a06", "#34160c", "#562614", "#76361e", "#94482a", "#b05c38"] if kind == "galleon"
                     else ["#1a0c05", "#3e200e", "#6a3a18", "#94562a", "#b8743c", "#d49458"]),   # oiled wood, darker on the galleon
            "tar": ["#08080a", "#141418", "#202228", "#2e3038", "#40444e", "#565a66"],
            "sail": ["#1a1712", "#4a443a", "#7e7666", "#b4aa94", "#d6cdb6", "#eee8d6"],
            "rope": ["#0e0a06", "#22180e", "#3a2a18", "#54402a"],
            "ochre": ["#1c1308", "#4e3818", "#866228", "#b98c3e", "#d8ae5e", "#ecca86"],
            "foam": ["#1a2a38", "#3a5a70", "#7a9ab0", "#b4cad8", "#dce8f0", "#f8fcff"],
            "faction": (["#1c0606", "#4a1210", "#7a1e1a", "#a82824", "#c8463a", "#e07060"] if war   # 168,40,36
                        else ["#0a0e1c", "#16244c", "#22387a", "#2e54a8", "#4a72c4", "#6e92da"]),   # 46,84,168
        },
        "brief": {"summary": f"Your Kingdom {kind} (J1 part 3) in the SpriteKiln style: a round hull with castles, "
                             "square sails filled by the wind with a faction cross, lateen sails aft, a bowsprit, rocking at anchor",
                  "must_keep": [f"frame {size}, waterline centre at ({size // 2}, {t['pivot']})", "bow = +z"]},
        "materials": {
            "hull": {"ramp": "hull", "bands": [2, 5]},
            "strake": {"ramp": "hull", "bands": [0, 1], "outline": False},
            "wale": {"ramp": "tar", "bands": [1, 3], "outline": False},
            "port": {"ramp": "hull", "bands": [0, 0], "outline": False, "line": False},
            "deck": {"ramp": "wood", "bands": [3, 5]},
            "deck_seam": {"ramp": "wood", "bands": [1, 2], "outline": False},
            "castle": {"ramp": "hull", "bands": [3, 5]},
            "rail": {"ramp": "ochre", "bands": [3, 5]},
            "rail_dark": {"ramp": "ochre", "bands": [1, 2], "outline": False},
            "mast": {"ramp": "wood", "bands": [2, 4]},
            "sail": {"ramp": "sail", "bands": [3, 5], "two_sided": True},
            "faction": {"ramp": "faction", "bands": [2, 4], "two_sided": True},
            "rope": {"ramp": "rope", "bands": [1, 2], "line": False},
            "foam": {"ramp": "foam", "bands": [4, 5], "outline": False, "line": False},
            "foam_dark": {"ramp": "foam", "bands": [3, 3], "outline": False, "line": False},
        },
        "channels": {"bob": 0.0, "pitch": 0.0, "roll": 0.0},
        "bones": bones,
        "parts": parts,
        "animations": ({"idle": {"frames": 1, "ms": 500, "channels": {}}} if stage is not None else
                       {"idle": {"frames": 4, "ms": 280, "channels": {
                           "bob": f"{0.035 * amp:.4f}*sin(p)", "pitch": f"{0.018 * amp:.4f}*sin(p + 1.2)",
                           "roll": f"{0.03 * amp:.4f}*sin(p + 0.5)"}}}),
    }


def r3p(pts):
    return [r3(p) for p in pts]


def main():
    """Names: <type>[_war][_build_<n>], e.g. caravel, caravel_war, caravel_build_0, caravel_war_build_2."""
    for kind in sys.argv[1:] or list(TYPES):
        base = kind.split("_")[0]
        stage = int(kind.rsplit("_", 1)[1]) if "_build_" in kind else None
        d = os.path.join(PROPS, kind)
        os.makedirs(d, exist_ok=True)
        spec = build(base, war="_war" in kind, stage=stage)
        spec["name"] = kind
        text = yaml.safe_dump(spec, sort_keys=False, default_flow_style=None, width=140)
        first, rest = text.split("\n", 1)
        with open(os.path.join(d, kind + ".yaml"), "w") as fh:
            fh.write(first + "\n# Generated by tools/spritekiln/gen_big_ships.py; edit the script, not this file.\n" + rest)
        print(kind)


if __name__ == "__main__":
    main()
