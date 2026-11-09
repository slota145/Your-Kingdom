"""SpriteKiln trial (ART_SPEC 10.20): burgher townhouses with half-timbering (mur pruski).

Writes one prop spec per row fragment (2x2 plot, the game's hut level 2):
    art/specs/props/townhouse_<fragment>/townhouse_<fragment>.yaml
Fragments: middle, end_a, end_b, corner_a (ART_SPEC 7: the row runs along the game's y axis,
the fronts face +x; a = the end with the smaller y).

SpriteKiln axes with `directions: [se]` (yaw 45): +z = the game's +x (the lower right wall, the
street front), +x = the game's -y (towards the upper right), so the game's side b (+y) is the
spec's -x (the lower left wall, visible). One tile = 2.343 units.

Run: python3 tools/spritekiln/gen_townhouses.py  (then `spritekiln render` in each folder)
"""
import math
import os

import yaml

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "art", "specs", "props")
H = 2.343            # half a 2x2 plot
GAP = 0.09           # narrow gap between burgher plots
T = 0.045            # half thickness of a timber beam (0.09 = about 1.7 px)
PL = 0.20            # stone plinth height
JETTY = 0.10         # each upper floor sticks out this much at the front


def r4(v):
    return [round(float(x), 4) for x in v] if isinstance(v, (list, tuple)) else round(float(v), 4)


class House:
    """One narrow townhouse, modelled in a local frame: u across the front, v from back to front
    (the front gable faces +v), y up. orient 'z': front faces +z; 'mx': front faces -x."""

    def __init__(self, name, orient, uc, w, vb, vf, floors, plaster, roof, pitch=61.0,
                 side_windows=None, side_frame=("-u",), door_u=None, chimney=0.25):
        self.n = name
        self.o = orient
        self.uc, self.w, self.vb, self.vf = uc, w, vb, vf
        self.floors = floors            # heights: ground floor first
        self.plaster, self.roof = plaster, roof
        self.pitch = math.radians(pitch)
        self.side_windows = side_windows or ()   # sides ('-u' / '+u') that face a street
        self.side_frame = side_frame
        self.door_u = door_u
        self.chimney = chimney
        self.parts = {}

    # -- mapping from the local frame to SpriteKiln's ------------------------------------
    def pt(self, u, y, v):
        return r4([u, y, v] if self.o == "z" else [-v, y, u])

    def half(self, hu, hy, hv):
        return r4([hu, hy, hv] if self.o == "z" else [hv, hy, hu])

    def rot_v(self, a):      # a turn in the u-y plane (front face, roof slabs)
        return r4([0, 0, a] if self.o == "z" else [-a, 0, 0])

    def rot_u(self, a):      # a turn in the v-y plane (side walls)
        return r4([-a, 0, 0] if self.o == "z" else [0, 0, -a])

    def box(self, c, h, rot=None, rnd=None):
        d = {"c": self.pt(*c), "half": self.half(*h)}
        if rot is not None:
            d["rot"] = rot
        if rnd:
            d["round"] = rnd
        return {"box": d}

    def add(self, part, prim, material=None, **extra):
        p = self.parts.setdefault(f"{self.n}_{part}", {"material": material, "prims": []})
        if material:
            p["material"] = material
        p.update(extra)
        p["prims"].append(prim)

    # -- timber on a face ------------------------------------------------------------------
    def beam_front(self, v, a, b, part="timber"):
        """A beam on the front face (plane v) from (u, y) a to (u, y) b."""
        (u1, y1), (u2, y2) = a, b
        L = math.hypot(u2 - u1, y2 - y1)
        ang = math.atan2(y2 - y1, u2 - u1)
        self.add(part, self.box(((u1 + u2) / 2, (y1 + y2) / 2, v + 0.012), (L / 2 + T * 0.6, T, 0.035),
                                rot=self.rot_v(ang)), "timber")

    def beam_side(self, u, a, b, part="timber"):
        """A beam on a side wall (plane u) from (v, y) a to (v, y) b."""
        (v1, y1), (v2, y2) = a, b
        L = math.hypot(v2 - v1, y2 - y1)
        ang = math.atan2(y2 - y1, v2 - v1)
        self.add(part, self.box((u, (y1 + y2) / 2, (v1 + v2) / 2), (0.035, T, L / 2 + T * 0.6),
                                rot=self.rot_u(ang)), "timber")

    def window_front(self, v, uw, ys, ww=0.42, wh=0.68, shutters=False):
        self.add("glass", self.box((uw, ys + wh / 2, v + 0.004), (ww / 2, wh / 2, 0.02)), "glass")
        self.add("sill", self.box((uw, ys - 0.03, v + 0.05), (ww / 2 + 0.05, 0.03, 0.06)), "sill_mat")
        if shutters:
            for s in (-1, 1):
                self.add("shutter", self.box((uw + s * (ww / 2 + 0.11), ys + wh / 2, v + 0.03),
                                             (0.085, wh / 2, 0.02)), "shutter")

    def window_side(self, u, s, vw, ys, ww=0.42, wh=0.68):
        self.add("glass", self.box((u + s * 0.004, ys + wh / 2, vw), (0.02, wh / 2, ww / 2)), "glass")
        self.add("sill", self.box((u + s * 0.05, ys - 0.03, vw), (0.06, 0.03, ww / 2 + 0.05)), "sill_mat")

    # -- the house -----------------------------------------------------------------------
    def build(self):
        uc, w, vb, vf = self.uc, self.w, self.vb, self.vf
        u0, u1 = uc - w / 2, uc + w / 2
        nup = len(self.floors) - 1
        vtop = vf + nup * JETTY
        G = self.floors[0]
        # plinth and ground floor
        self.add("plinth", self.box((uc, PL / 2, (vb + vf) / 2 + 0.02), (w / 2, PL / 2, (vf - vb) / 2 + 0.02)),
                 "stone")
        y = PL
        self.add("walls", self.box((uc, y + G / 2, (vb + vf) / 2), (w / 2 - 0.02, G / 2, (vf - vb) / 2)),
                 self.plaster, priority=1)
        levels = [(y, y + G, vf)]
        y += G
        for k, fh in enumerate(self.floors[1:], start=1):
            vfk = vf + k * JETTY
            self.add("walls", self.box((uc, y + fh / 2, (vb + vfk) / 2), (w / 2, fh / 2, (vfk - vb) / 2)),
                     self.plaster)
            # the jetty: a dark beam end line under the overhang
            self.add("timber", self.box((uc, y + 0.04, vfk - 0.02), (w / 2 + 0.02, 0.05, 0.05)), "timber")
            levels.append((y, y + fh, vfk))
            y += fh
        E = y
        # front: ground floor (corner posts, door, a window)
        y0, y1, v = levels[0]
        self.beam_front(v, (u0, y1 - T), (u1, y1 - T))
        du = self.door_u if self.door_u is not None else (u0 + 0.5 if w > 1.3 else uc)
        dw, dh = 0.27, 1.38
        self.add("door", self.box((du, y0 + dh / 2, v + 0.01), (dw, dh / 2, 0.03)), "door_wood")
        self.add("door_line", self.box((du, y0 + dh / 2, v + 0.03), (0.018, dh / 2 - 0.05, 0.02)), "ink")
        for s in (-1, 1):
            self.beam_front(v, (du + s * (dw + T), y0), (du + s * (dw + T), y0 + dh + T))
        self.beam_front(v, (du - dw - 2 * T, y0 + dh + T), (du + dw + 2 * T, y0 + dh + T))
        self.add("step", self.box((du, 0.06, v + 0.22), (dw + 0.08, 0.06, 0.16)), "stone")
        if w > 1.25:
            ux = u1 - 0.42 if du < uc else u0 + 0.42
            self.window_front(v, ux, y0 + 0.75, shutters=True)
        # front: upper floors (posts, rails, windows, braces)
        for (ya, yb, v) in levels[1:]:
            nwin = 3 if w > 2.15 else (2 if w > 1.42 else 1)
            ww, wh = 0.42, 0.68
            ys = ya + 0.55
            cs = [u0 + w * (i + 0.5) / nwin for i in range(nwin)]
            self.beam_front(v, (u0, ya + T), (u1, ya + T))
            self.beam_front(v, (u0, yb - T), (u1, yb - T))
            self.beam_front(v, (u0, ys - T), (u1, ys - T))
            posts = [u0 + T, u1 - T]
            for c in cs:
                posts += [c - ww / 2 - T, c + ww / 2 + T]
                self.window_front(v, c, ys, ww, wh)
                # St Andrew's cross under the window
                a0, a1 = c - ww / 2, c + ww / 2
                self.beam_front(v, (a0, ya + 2 * T), (a1, ys - 2 * T))
                self.beam_front(v, (a1, ya + 2 * T), (a0, ys - 2 * T))
            for p in posts:
                self.beam_front(v, (p, ya), (p, yb))
            # braces in the corner bays
            left, right = u0 + 2 * T, cs[0] - ww / 2 - 2 * T
            if right - left > 0.12:
                self.beam_front(v, (left, ya + T), (right, yb - T))
            left, right = cs[-1] + ww / 2 + 2 * T, u1 - 2 * T
            if right - left > 0.12:
                self.beam_front(v, (right, ya + T), (left, yb - T))
        # gables (front with timber, back plain)
        R = (w / 2) * math.tan(self.pitch)
        prof = {"polygon": r4p([[-w / 2, 0], [w / 2, 0], [0, R]])}
        rotg = None if self.o == "z" else [0, -1.5708, 0]
        for vv in (vtop - 0.05, vb + 0.05):
            g = {"c": self.pt(uc, E, vv), "depth": 0.1, "profile": prof}
            if rotg:
                g["rot"] = rotg
            self.add("gable", {"extrude": g}, self.plaster)
        v = vtop
        self.beam_front(v, (u0, E + T), (u1, E + T))
        self.beam_front(v, (u0 + 0.05, E + 0.03), (uc, E + R - 0.02))
        self.beam_front(v, (u1 - 0.05, E + 0.03), (uc, E + R - 0.02))
        yc = E + R * 0.48
        hc = (w / 2) * (1 - 0.48)
        self.beam_front(v, (uc - hc, yc), (uc + hc, yc))
        self.beam_front(v, (uc, yc), (uc, E + R - 0.05))
        if R > 0.9:
            gw = 0.34
            self.window_front(v, uc, E + 0.18, gw, min(0.5, yc - E - 0.3))
            for s in (-1, 1):
                self.beam_front(v, (uc + s * (gw / 2 + T), E), (uc + s * (gw / 2 + T), yc))
        # side walls: timber where the wall may show, windows where it faces a street
        for side in ("-u", "+u"):
            if side not in self.side_frame and side not in self.side_windows:
                continue
            s = -1 if side == "-u" else 1
            u = (u0 if s < 0 else u1) + s * 0.012
            for (ya, yb, vfk) in levels:
                span = vfk - vb
                nb = max(2, round(span / 0.85))
                self.beam_side(u, (vb, ya + T), (vfk, ya + T))
                self.beam_side(u, (vb, yb - T), (vfk, yb - T))
                for i in range(nb + 1):
                    pv = vb + T + (span - 2 * T) * i / nb
                    self.beam_side(u, (pv, ya), (pv, yb))
                for i in range(nb):
                    a = vb + T + (span - 2 * T) * i / nb
                    b = vb + T + (span - 2 * T) * (i + 1) / nb
                    if side in self.side_windows and i % 2 == (1 if ya > PL else 0):
                        self.window_side(u, s, (a + b) / 2, ya + (0.55 if ya > PL else 0.75), min(0.42, b - a - 0.2))
                    elif i % 2 == 0:
                        self.beam_side(u, (a, ya + T), (b, yb - T))
                    else:
                        self.beam_side(u, (b, ya + T), (a, yb - T))
        # roof: two tiled slabs, a lath under every course, the ridge and a chimney
        ov = 0.17
        th = self.pitch
        Lr = math.hypot(w / 2 + ov, (w / 2 + ov) * math.tan(th))
        v0, v1 = vb - 0.06, vtop + 0.09
        roof_dark = self.roof + "_dark"
        for s in (-1, 1):
            eu, ey = uc + s * (w / 2 + ov), E - ov * math.tan(th)
            cu, cy = (eu + uc) / 2, (ey + E + R) / 2
            lift = 0.05 / math.cos(th)
            ang = th if s < 0 else -th
            self.add(f"roof_{'l' if s < 0 else 'r'}",
                     self.box((cu, cy + lift, (v0 + v1) / 2), (Lr / 2, 0.05, (v1 - v0) / 2), rot=self.rot_v(ang),
                              rnd=0.01), self.roof)
            p = self.parts[f"{self.n}_roof_{'l' if s < 0 else 'r'}"]
            p["paint"] = [{"material": self.roof + "_light", "spots": {"scale": 0.18, "density": 0.2,
                                                                         "seed": sum(map(ord, self.n)) % 97 + (s > 0)}}]
            # courses: thin dark laths along v, one every 0.21 up the slope
            k = 1
            while True:
                t = k * 0.21
                if t > Lr - 0.12:
                    break
                fu = eu - s * t * math.cos(th)
                fy = ey + t * math.sin(th) + 0.11 / math.cos(th)
                self.add("courses", {"cylinder": {"a": self.pt(fu, fy, v0), "b": self.pt(fu, fy, v1), "r": 0.026}},
                         roof_dark)
                k += 1
        self.add("ridge", {"cylinder": {"a": self.pt(uc, E + R + 0.1, v0), "b": self.pt(uc, E + R + 0.1, v1),
                                         "r": 0.07}}, roof_dark)
        if self.chimney is not None:
            cv = vb + (vtop - vb) * self.chimney
            cu = uc + w * 0.18
            ytop = E + R + 0.45
            yb_ = E + R * 0.4
            self.add("chimney", self.box((cu, (ytop + yb_) / 2, cv), (0.13, (ytop - yb_) / 2, 0.13)), "brick")
            self.add("chimney", self.box((cu, ytop, cv), (0.16, 0.04, 0.16)), "brick")
        for p in self.parts.values():
            if p["material"] is None:
                p.pop("material")
        return self.parts


def r4p(pts):
    return [r4(p) for p in pts]


PLASTERS = ["plaster_cream", "plaster_ochre", "plaster_pink", "plaster_blue"]


def materials():
    m = {
        "timber": {"ramp": "timber", "bands": [2, 4], "line": False},
        "glass": {"ramp": "glass", "bands": [2, 4], "finish": "glossy", "line": False},
        "sill_mat": {"ramp": "stone", "bands": [3, 5], "line": False},
        "shutter": {"ramp": "shutter", "bands": [2, 4], "line": False},
        "door_wood": {"ramp": "wood", "bands": [1, 3]},
        "stone": {"ramp": "stone", "bands": [2, 4]},
        "brick": {"ramp": "brick"},
        "cobble": {"ramp": "cobble", "bands": [3, 4], "outline": False},
        "cobble_dark": {"ramp": "cobble", "bands": [2, 3], "outline": False},
        "ink": {"ramp": "timber", "bands": [0, 1], "outline": False},
    }
    for p in PLASTERS:
        m[p] = {"ramp": p}
    for r in ("tile", "slate"):
        m[r] = {"ramp": r, "bands": [2, 4]}
        m[r + "_light"] = {"ramp": r, "bands": [3, 5]}
        m[r + "_dark"] = {"ramp": r, "bands": [0, 1], "outline": False}
    return m


def plot_parts():
    return {"yard": {"material": "cobble", "prims": [{"box": {"c": [0, 0.01, 0], "half": [H, 0.01, H]}}],
                     "paint": [{"material": "cobble_dark", "spots": {"scale": 0.09, "density": 0.35, "seed": 3}}]}}


def row(widths, vfs, floors, plasters, roofs, end=None):
    """Houses side by side across the plot (orient z), from -x (side b) to +x (side a)."""
    lo, hi = -H + GAP, H - GAP
    scale = (hi - lo) / sum(widths)
    widths = [w * scale for w in widths]
    houses = []
    u = lo
    for i, w in enumerate(widths):
        sw = ("-u",) if (end == "b" and i == 0) else ()
        sf = ("-u", "+u") if (end == "a" and i == len(widths) - 1) else ("-u",)
        houses.append(House(f"h{i}", "z", u + w / 2, w, -H + 0.16, vfs[i], floors[i], plasters[i], roofs[i],
                            side_windows=sw, side_frame=sf, chimney=0.3 + 0.15 * (i % 2)))
        u += w
    return houses


FRAGMENTS = {
    "middle": lambda: row([1.6, 1.35, 1.55], [1.98, 1.86, 2.03], [[2.0, 1.75], [2.0, 1.95], [1.9, 1.7]],
                          ["plaster_cream", "plaster_ochre", "plaster_cream"], ["tile", "slate", "tile"]),
    "end_a": lambda: row([2.0, 2.3], [2.0, 1.88], [[2.0, 1.85], [2.0, 1.7]],
                         ["plaster_pink", "plaster_cream"], ["tile", "tile"], end="a"),
    "end_b": lambda: row([2.25, 2.05], [1.9, 2.02], [[2.0, 1.8], [2.0, 1.95]],
                         ["plaster_cream", "plaster_blue"], ["slate", "tile"], end="b"),
    "corner_a": lambda: [
        # on the front street, joined to the row at side a (+x)
        House("h0", "z", (0.02 + H - GAP) / 2, (H - GAP) - 0.02, -H + 0.16, 1.98, [2.0, 1.8], "plaster_cream",
              "tile", side_frame=("-u",)),
        # the corner house: gable to the side street (-x), eaves side on the front street (+z)
        House("h1", "mx", (-0.05 + H - 0.04) / 2 - 0.05, (H - 0.04) + 0.05 - 0.1, -0.02, H - GAP - 0.2,
              [2.0, 1.75, 1.6], "plaster_ochre", "tile", side_windows=("+u",), side_frame=(), chimney=0.2),
        # behind it, also gable to the side street; the row behind the corner joins at the back (-z)
        House("h2", "mx", (-H + 0.16 - 0.05) / 2, (H - 0.16) - 0.05, -0.02, H - GAP - 0.14, [2.0, 1.8],
              "plaster_cream", "slate", side_frame=(), chimney=0.35),
    ],
}


def spec(frag):
    parts = plot_parts()
    for h in FRAGMENTS[frag]():
        parts.update(h.build())
    return {
        "spritekiln": 1,
        "name": f"townhouse_{frag}",
        "render": {"outline": "dark", "lines": "depth+normal", "light": "classic", "shading": "toon"},
        "kind": "prop",
        "size": 256,
        "directions": ["se"],
        "palette": ["../../palettes/kingdom.yaml", "../../palettes/town.yaml"],
        "camera": {"pitch": 30, "scale": 0.05176, "center": [0, 2.8, 0]},
        "shadow": None,
        "brief": {"summary": f"Your Kingdom burgher townhouses (hut level 2), fragment {frag} of a row on a 2x2 "
                             "plot: narrow half-timbered houses, gables to the street, tiled or slate roofs",
                  "must_keep": ["footprint 2x2 tiles (4.69 x 4.69 units)", "door about 26 px tall"]},
        "materials": materials(),
        "channels": {},
        "bones": {},
        "parts": parts,
        "animations": {"idle": {"frames": 1, "ms": 500, "channels": {}}},
    }


def main():
    import sys
    frags = sys.argv[1:] or list(FRAGMENTS)
    for f in frags:
        d = os.path.join(OUT, f"townhouse_{f}")
        os.makedirs(d, exist_ok=True)
        path = os.path.join(d, f"townhouse_{f}.yaml")
        with open(path, "w") as fh:
            text = yaml.safe_dump(spec(f), sort_keys=False, default_flow_style=None, width=140)
            first, rest = text.split("\n", 1)
            fh.write(first + "\n# Generated by tools/spritekiln/gen_townhouses.py; edit the script, not this file.\n" + rest)
        n = sum(len(p["prims"]) for p in spec(f)["parts"].values())
        print(path, n, "prims")


if __name__ == "__main__":
    main()
