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
                 side_windows=None, side_frame=("-u",), door_u=None, chimney=0.25, gable="plain",
                 origin=(0.0, 0.0), gate=False, front_frame=True, cuts=()):
        self.n = name
        # orient: 'z' (front +z), 'mx' (front -x) or an angle in degrees (-45: the chamfer, facing the camera)
        self.yaw = math.radians({"z": 0.0, "mx": -90.0}.get(orient, orient) if isinstance(orient, str) else orient)
        self.origin = origin
        self.gate = gate                # a gateway arch instead of the door (a corner house's passage)
        self.front_frame = front_frame  # timbering on the front's upper floors
        self.cuts = list(cuts)          # cutters added to every part (the chamfered corner)
        self.uc, self.w, self.vb, self.vf = uc, w, vb, vf
        self.floors = floors            # heights: ground floor first
        self.plaster, self.roof = plaster, roof
        self.pitch = math.radians(pitch)
        self.side_windows = side_windows or ()   # sides ('-u' / '+u') that face a street
        self.side_frame = side_frame
        self.door_u = door_u
        self.chimney = chimney
        self.gable = gable              # plain (timbered), stepped or curved (a masonry show gable)
        self.parts = {}

    # -- mapping from the local frame to SpriteKiln's ------------------------------------
    def pt(self, u, y, v):
        ca, sa = math.cos(self.yaw), math.sin(self.yaw)
        return r4([self.origin[0] + u * ca + v * sa, y, self.origin[1] - u * sa + v * ca])

    def half(self, hu, hy, hv):
        return r4([hu, hy, hv])

    def rot_v(self, a):      # a turn in the u-y plane (front face, roof slabs)
        return [0, 0, a]

    def rot_u(self, a):      # a turn in the v-y plane (side walls)
        return [-a, 0, 0]

    def box(self, c, h, rot=None, rnd=None):
        d = {"c": self.pt(*c), "half": self.half(*h)}
        r = list(rot) if rot is not None else [0, 0, 0]
        r[1] = self.yaw
        if any(abs(x) > 1e-6 for x in r):
            d["rot"] = r4(r)
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
        if self.gate:      # a round-arched gateway with a stone frame (the passage under a corner house)
            gw, gh = min(0.5, w / 2 - 0.12), 1.75
            arch = [[gw * math.cos(math.radians(a_)), gh - gw + gw * math.sin(math.radians(a_))] for a_ in range(0, 181, 30)]
            frame = [[x * (gw + 0.12) / gw, (y_ - (gh - gw)) * (gw + 0.12) / gw + gh - gw] for x, y_ in arch]
            for poly, mat, dz in ((frame + [[-gw - 0.12, 0], [gw + 0.12, 0]], "sill_mat", 0.02),
                                  (arch + [[-gw, 0], [gw, 0]], "gate_dark", 0.05)):
                g = {"c": self.pt(uc, y0 - 0.05, v + dz), "depth": 0.1, "profile": {"polygon": r4p(poly)}}
                if abs(self.yaw) > 1e-6:
                    g["rot"] = r4([0, self.yaw, 0])
                self.add("gate" if mat == "gate_dark" else "gate_frame", {"extrude": g}, mat, priority=2)
        else:
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
            if not self.front_frame:     # a plastered front: windows with shutters only
                for c in cs:
                    self.window_front(v, c, ys, ww, wh, shutters=w > 1.1)
                continue
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
        if self.gable == "tower":       # an oriel turret on the corner: no gable or roof of its own
            return self.oriel(uc, vf, E)
        # gables: the back one plain; the front one timbered, or a masonry show gable above the roof
        R = (w / 2) * math.tan(self.pitch)
        rotg = r4([0, self.yaw, 0]) if abs(self.yaw) > 1e-6 else None

        def gable_prim(vv, poly, depth):
            g = {"c": self.pt(uc, E, vv), "depth": depth, "profile": {"polygon": r4p(poly)}}
            if rotg:
                g["rot"] = rotg
            return {"extrude": g}

        tri = [[-w / 2, 0], [w / 2, 0], [0, R]]
        self.add("gable", gable_prim(vb + 0.05, tri, 0.1), self.plaster)
        v = vtop
        if self.gable == "plain":
            self.add("gable", gable_prim(vtop - 0.05, tri, 0.1), self.plaster)
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
        else:
            hw = w / 2 + 0.04
            if self.gable == "stepped":
                Rg = R + 0.32
                n = 4 if w > 1.5 else 3
                sw, sh = hw / (n + 0.5), Rg / (n + 1)
                right = [[hw, 0]]
                for i in range(n):
                    x = hw - i * sw
                    right += [[x, (i + 1) * sh], [x - sw, (i + 1) * sh]]
                right += [[sw / 2, Rg]]
            else:   # curved: a volute at the bottom, a ledge, a round crown with a finial
                Rg = R + 0.38
                rx, ry, cy = 0.45 * hw, 0.32 * R, 0.62 * R
                right = [[hw, 0]]
                for k in range(7):
                    a_ = math.radians(270 - 15 * k)
                    right.append([hw + rx * math.cos(a_), cy + ry * math.sin(a_)])
                right += [[0.55 * hw, 0.86 * R], [0.34 * hw, 0.86 * R]]
                rc = 0.34 * hw
                for k in range(7):
                    a_ = math.radians(15 * k)
                    right.append([rc * math.cos(a_), Rg - rc + rc * math.sin(a_)])
            left = [[-x, y] for (x, y) in reversed(right)]
            if self.gable == "curved":
                right[-1] = [0.0, Rg]             # the crown's top point is shared by both halves
            poly = [r4(p_) for p_ in right + (left[1:] if right[-1][0] == 0 else left)]
            poly = [p_ for i, p_ in enumerate(poly) if i == 0 or p_ != poly[i - 1]]   # no zero-length edges
            self.add("show_gable", gable_prim(vtop - 0.04, poly, 0.16), self.plaster, priority=2)
            self.add("trim", self.box((uc, E + 0.03, vtop + 0.06), (hw + 0.04, 0.04, 0.06)), "sill_mat")
            self.add("trim", {"sphere": {"c": self.pt(uc, E + Rg + 0.06, vtop - 0.04), "r": 0.08}}, "sill_mat")
            nw = 2 if w > 1.4 else 1
            for i in range(nw):
                self.window_front(v + 0.04, uc + (i - (nw - 1) / 2) * w * 0.36, E + 0.22, 0.34, 0.5)
            if Rg > 1.6:
                self.window_front(v + 0.04, uc, E + 0.98, 0.24, 0.32)
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
        v0, v1 = vb - 0.06, (vtop + 0.09 if self.gable == "plain" else vtop - 0.06)
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
        return self.finish()

    def finish(self):
        for p in self.parts.values():
            if p["material"] is None:
                p.pop("material")
            if self.cuts:
                p.setdefault("cut", []).extend(self.cuts)
        return self.parts

    def oriel(self, uc, vf, E):
        """A round turret from the first floor up, on a corbel, with a pointed roof and a finial."""
        G = self.floors[0]
        r, cv = 0.66, vf + 0.3
        y0, y1 = PL + G - 0.05, E + 0.3
        self.add("turret", {"cylinder": {"a": self.pt(uc, y0, cv), "b": self.pt(uc, y1, cv), "r": r}}, self.plaster,
                 priority=2)
        tp = self.parts[f"{self.n}_turret"]
        tp["paint"] = [{"material": "sill_mat", "stripes": {"axis": "y", "at": r4([y0 + 0.05, E - self.floors[-1] + 0.02, y1 - 0.05]),
                                                            "width": 0.08}},
                       {"material": "glass", "prims": [self.box((uc + du, yy, cv + r), (0.13, 0.3, 0.3))
                                                       for yy in (PL + G + 0.95, E - self.floors[-1] + 0.85)
                                                       for du in (-0.36, 0.0, 0.36)]}]
        self.add("corbel", {"cone": {"a": self.pt(uc, y0 - 0.75, cv - 0.1), "b": self.pt(uc, y0, cv), "r": [0.08, r]}},
                 "sill_mat")
        self.add("turret_roof", {"cone": {"a": self.pt(uc, y1, cv), "b": self.pt(uc, y1 + 1.9, cv), "r": [r + 0.12, 0.02]}},
                 self.roof)
        self.parts[f"{self.n}_turret_roof"]["paint"] = [
            {"material": self.roof + "_dark", "stripes": {"axis": "y", "period": 0.2, "width": 0.05, "offset": y1}}]
        self.add("turret_roof", {"sphere": {"c": self.pt(uc, y1 + 1.98, cv), "r": 0.08}}, "sill_mat")
        return self.finish()


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
        "gate_dark": {"ramp": "timber", "bands": [0, 1], "line": False},
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


def row(widths, vfs, floors, plasters, roofs, end=None, extra=None):
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
                            side_windows=sw, side_frame=sf, chimney=0.3 + 0.15 * (i % 2),
                            **((extra or [{}] * len(widths))[i])))
        u += w
    return houses


FRAGMENTS = {
    # heights differ in one plot: 2 or 3 storeys, different floor heights and roof pitches, show gables
    "middle": lambda: row([1.55, 1.5, 1.45], [1.98, 1.84, 2.03], [[2.0, 1.75], [2.0, 1.75, 1.6], [1.9, 1.85]],
                          ["plaster_cream", "plaster_ochre", "plaster_pink"], ["tile", "slate", "tile"],
                          extra=[{"pitch": 57}, {"gable": "curved", "pitch": 60}, {"gable": "stepped", "pitch": 63}]),
    "end_a": lambda: row([2.0, 2.3], [1.94, 2.02], [[2.0, 1.8, 1.6], [2.0, 1.7]],
                         ["plaster_cream", "plaster_pink"], ["tile", "tile"], end="a",
                         extra=[{"gable": "stepped", "pitch": 58}, {"pitch": 52}]),
    "end_b": lambda: row([2.15, 2.15], [1.9, 2.02], [[2.0, 1.8], [2.0, 1.85, 1.6]],
                         ["plaster_cream", "plaster_blue"], ["slate", "tile"], end="b",
                         extra=[{"pitch": 55}, {"gable": "curved", "pitch": 58}]),
    # more row variants (owner 2026-11-09): plastered fronts, more storeys, other gables
    "middle_2": lambda: row([2.4, 1.9], [1.95, 2.03], [[2.0, 1.8, 1.65], [2.0, 1.8]],
                            ["plaster_ochre", "plaster_cream"], ["tile", "slate"],
                            extra=[{"gable": "curved", "pitch": 56, "front_frame": False}, {"pitch": 54}]),
    "middle_3": lambda: row([1.4, 1.65, 1.45], [2.0, 1.86, 1.96], [[2.0, 1.75, 1.6], [1.9, 1.8], [2.0, 1.95]],
                            ["plaster_pink", "plaster_cream", "plaster_blue"], ["tile", "tile", "slate"],
                            extra=[{"gable": "stepped", "pitch": 62}, {"pitch": 52}, {"gable": "curved", "pitch": 60,
                                                                                     "front_frame": False}]),
    "end_b_2": lambda: row([2.0, 2.3], [2.02, 1.9], [[2.0, 1.8, 1.6], [2.0, 1.75]],
                           ["plaster_cream", "plaster_ochre"], ["tile", "slate"], end="b",
                           extra=[{"pitch": 57}, {"gable": "stepped", "pitch": 60, "front_frame": False}]),
    # chamfered corners: the corner house's corner cut at 45 degrees, a narrow bay facing the camera on the cut
    "corner_a": lambda: corner("gate"),
    "corner_a_2": lambda: corner("tower"),
    "corner_a_3": lambda: corner("shop"),
}

CORNER_LOOKS = {
    "gate": dict(h0=("plaster_cream", "tile", "stepped"), h1=("plaster_ochre", "tile"), h2=("plaster_cream", "slate"),
                 bay=dict(gable="curved", gate=True, front_frame=False)),
    "tower": dict(h0=("plaster_cream", "slate", "plain"), h1=("plaster_pink", "tile"), h2=("plaster_blue", "tile"),
                  bay=dict(gable="tower", front_frame=False)),
    "shop": dict(h0=("plaster_pink", "tile", "curved"), h1=("plaster_cream", "slate"), h2=("plaster_ochre", "tile"),
                 bay=dict(gable="stepped", front_frame=True)),
}


def corner(look):
    """Corner fragment (corner_a: joined at side a (+x) and at the back (-z)) with a chamfered corner."""
    lk = CORNER_LOOKS[look]
    h1_floors = [2.0, 1.75, 1.6]
    h1_vf = H - GAP - 0.2
    h1_uc, h1_w = (-0.05 + H - 0.04) / 2 - 0.05, (H - 0.04) + 0.05 - 0.1
    cx, cz = -(h1_vf + 2 * JETTY), h1_uc + h1_w / 2         # the corner's outer point (x, z)
    leg = 0.95
    n = [-0.7071, 0, 0.7071]
    at = ((-cx - leg) + cz) * 0.7071
    mid = (cx + leg / 2, cz - leg / 2)
    chamfer = [{"plane": {"n": n, "at": round(at, 4)}}]
    plaster0, roof0, gable0 = lk["h0"]
    bay_roof = lk["h1"][1] if look != "tower" else "slate"
    return [
        House("h0", "z", (0.02 + H - GAP) / 2, (H - GAP) - 0.02, -H + 0.16, 1.98, [2.0, 1.8], plaster0, roof0,
              side_frame=("-u",), gable=gable0, pitch=56),
        House("h1", "mx", h1_uc, h1_w, -0.02, h1_vf, h1_floors, lk["h1"][0], lk["h1"][1], side_windows=("+u",),
              side_frame=(), chimney=0.2, gable="plain", pitch=58, cuts=chamfer),
        House("hc", -45.0, 0.0, leg * 1.4142, -1.0, 0.0, h1_floors, lk["h1"][0], bay_roof, side_frame=(),
              chimney=None, pitch=60, origin=mid, **lk["bay"]),
        House("h2", "mx", (-H + 0.16 - 0.05) / 2, (H - 0.16) - 0.05, -0.02, H - GAP - 0.14, [2.0, 1.7],
              lk["h2"][0], lk["h2"][1], side_frame=(), chimney=0.35, pitch=62),
    ]


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
