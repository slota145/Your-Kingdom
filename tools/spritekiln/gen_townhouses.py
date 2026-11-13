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
                 origin=(0.0, 0.0), gate=False, front_frame=True, cuts=(), mirror=(1, 1), back_detail=False):
        self.n = name
        # orient: 'z' (front +z), 'mx' (front -x) or an angle in degrees (-45: the chamfer, facing the camera)
        self.yaw = math.radians({"z": 0.0, "mx": -90.0}.get(orient, orient) if isinstance(orient, str) else orient)
        self.origin = origin
        self.gate = gate                # a gateway arch instead of the door (a corner house's passage)
        self.front_frame = front_frame  # timbering on the front's upper floors
        self.cuts = list(cuts)          # cutters added to every part (the chamfered corner)
        self.mx, self.mz = mirror       # -1: the whole house mirrored in x (corner_b) or z (the back views)
        self.back_detail = back_detail  # timbering, windows and a back door on the back wall (the _back views)
        self.uc, self.w, self.vb, self.vf = uc, w, vb, vf
        self.floors = floors            # heights: ground floor first
        self.plaster, self.roof = plaster, roof
        self.pitch = math.radians(pitch)
        self.side_windows = side_windows or ()   # sides ('-u' / '+u') that face a street
        self.side_frame = side_frame
        self.door_u = door_u
        self.chimney = chimney
        self.jetty = JETTY
        self.gable = gable              # plain (timbered), stepped or curved (a masonry show gable)
        self.parts = {}

    # -- mapping from the local frame to SpriteKiln's ------------------------------------
    def pt(self, u, y, v):
        ca, sa = math.cos(self.yaw), math.sin(self.yaw)
        return r4([self.mx * (self.origin[0] + u * ca + v * sa), y, self.mz * (self.origin[1] - u * sa + v * ca)])

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
        r = self.mrot(r)
        if any(abs(x) > 1e-6 for x in r):
            d["rot"] = r4(r)
        if rnd:
            d["round"] = rnd
        return {"box": d}

    def mrot(self, r):
        """A rotation seen in the mirror: mirroring x flips the turns about y and z, mirroring z those about y and x."""
        rx, ry, rz = r
        if self.mx < 0:
            ry, rz = -ry, -rz
        if self.mz < 0:
            ry, rx = -ry, -rx
        return [rx, ry, rz]

    def add(self, part, prim, material=None, **extra):
        p = self.parts.setdefault(f"{self.n}_{part}", {"material": material, "prims": []})
        if material:
            p["material"] = material
        p.update(extra)
        p["prims"].append(prim)

    # -- timber on a face ------------------------------------------------------------------
    def beam_front(self, v, a, b, part="timber", sgn=1):
        """A beam on the front face (plane v; sgn -1: on the back face) from (u, y) a to (u, y) b."""
        (u1, y1), (u2, y2) = a, b
        L = math.hypot(u2 - u1, y2 - y1)
        ang = math.atan2(y2 - y1, u2 - u1)
        self.add(part, self.box(((u1 + u2) / 2, (y1 + y2) / 2, v + sgn * 0.012), (L / 2 + T * 0.6, T, 0.035),
                                rot=self.rot_v(ang)), "timber")

    def beam_side(self, u, a, b, part="timber"):
        """A beam on a side wall (plane u) from (v, y) a to (v, y) b."""
        (v1, y1), (v2, y2) = a, b
        L = math.hypot(v2 - v1, y2 - y1)
        ang = math.atan2(y2 - y1, v2 - v1)
        self.add(part, self.box((u, (y1 + y2) / 2, (v1 + v2) / 2), (0.035, T, L / 2 + T * 0.6),
                                rot=self.rot_u(ang)), "timber")

    def window_front(self, v, uw, ys, ww=0.42, wh=0.68, shutters=False, sgn=1):
        self.add("glass", self.box((uw, ys + wh / 2, v + sgn * 0.004), (ww / 2, wh / 2, 0.02)), "glass")
        self.add("sill", self.box((uw, ys - 0.03, v + sgn * 0.05), (ww / 2 + 0.05, 0.03, 0.06)), "sill_mat")
        if shutters:
            for s in (-1, 1):
                self.add("shutter", self.box((uw + s * (ww / 2 + 0.11), ys + wh / 2, v + sgn * 0.03),
                                             (0.085, wh / 2, 0.02)), "shutter")

    def window_side(self, u, s, vw, ys, ww=0.42, wh=0.68):
        self.add("glass", self.box((u + s * 0.004, ys + wh / 2, vw), (0.02, wh / 2, ww / 2)), "glass")
        self.add("sill", self.box((u + s * 0.05, ys - 0.03, vw), (0.06, 0.03, ww / 2 + 0.05)), "sill_mat")

    # -- the house -----------------------------------------------------------------------
    def build(self):
        uc, w, vb, vf = self.uc, self.w, self.vb, self.vf
        u0, u1 = uc - w / 2, uc + w / 2
        nup = len(self.floors) - 1
        vtop = vf + nup * self.jetty
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
            vfk = vf + k * self.jetty
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
                    g["rot"] = r4(self.mrot([0, self.yaw, 0]))
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
        R = self.gables(E, vtop)
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
        if self.back_detail:
            self.back_face(levels, E, w / 2 * math.tan(self.pitch))
        self.roof_and_chimney(E, R, vtop)
        return self.finish()

    def roof_and_chimney(self, E, R, vtop):
        """The roof: two tiled slabs, a lath under every course, the ridge and a chimney."""
        uc, w, vb = self.uc, self.w, self.vb
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

    def gables(self, E, vtop):
        """The gables: the back one plain; the front one timbered, plain masonry (`masonry`, with a
        stone coping and windows) or a masonry show gable above the roof. Returns the roof's rise."""
        uc, w, vb = self.uc, self.w, self.vb
        u0, u1 = uc - w / 2, uc + w / 2
        R = (w / 2) * math.tan(self.pitch)
        rotg = r4(self.mrot([0, self.yaw, 0])) if abs(self.yaw) > 1e-6 else None

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
        elif self.gable == "masonry":
            self.add("gable", gable_prim(vtop - 0.05, tri, 0.1), self.plaster)
            L = math.hypot(w / 2 + 0.06, R) / 2
            ang = math.atan2(R, w / 2)
            for s in (-1, 1):     # a stone coping along both edges, a finial at the top
                self.add("trim", self.box((uc + s * (w / 4), E + R / 2 + 0.06, vtop - 0.02), (L, 0.06, 0.1),
                                          rot=self.rot_v(-s * ang)), "sill_mat")
            self.add("trim", {"sphere": {"c": self.pt(uc, E + R + 0.12, vtop - 0.02), "r": 0.09}}, "sill_mat")
            nw = 2 if w > 1.4 else 1
            for i in range(nw):
                self.window_rich(v, uc + (i - (nw - 1) / 2) * w * 0.32, E + 0.2, 0.32, 0.55)
            if R > 1.5:
                self.window_rich(v, uc, E + 1.0, 0.22, 0.34)
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
            win = self.window_rich if getattr(self, "rich", False) else self.window_front
            for i in range(nw):
                win(v + 0.04, uc + (i - (nw - 1) / 2) * w * 0.36, E + 0.22, 0.34, 0.5)
            if Rg > 1.6:
                win(v + 0.04, uc, E + 0.98, 0.24, 0.32)
        return R

    def back_face(self, levels, E, R):
        """The back wall: a plain back door, windows, timbering on every floor and on the back gable."""
        uc, w, v = self.uc, self.w, self.vb
        u0, u1 = uc - w / 2, uc + w / 2
        for (ya, yb, _) in levels:
            ground = ya <= PL + 1e-6
            nwin = 1 if ground or w < 1.42 else 2
            cs = [u0 + w * (i + 0.5) / nwin for i in range(nwin)] if not ground else [u1 - 0.45]
            self.beam_front(v, (u0, ya + T), (u1, ya + T), sgn=-1)
            self.beam_front(v, (u0, yb - T), (u1, yb - T), sgn=-1)
            posts = [u0 + T, u1 - T]
            ys = ya + (0.75 if ground else 0.55)
            for c in cs:
                if ground and w < 1.2:
                    break
                self.window_front(v, c, ys, 0.38, 0.6, sgn=-1)
                posts += [c - 0.19 - T, c + 0.19 + T]
            if ground:   # the back door
                dw, dh = 0.24, 1.3
                du = u0 + 0.42
                self.add("door", self.box((du, ya + dh / 2, v - 0.01), (dw, dh / 2, 0.03)), "door_wood")
                posts += [du - dw - T, du + dw + T]
            for p_ in posts:
                self.beam_front(v, (p_, ya), (p_, yb), sgn=-1)
            if not ground:
                left, right = u0 + 2 * T, cs[0] - 0.19 - 2 * T
                if right - left > 0.12:
                    self.beam_front(v, (left, ya + T), (right, yb - T), sgn=-1)
        if self.gable != "tower":
            uc_ = uc
            self.beam_front(v, (u0 + 0.05, E + 0.03), (uc_, E + R - 0.02), sgn=-1)
            self.beam_front(v, (u1 - 0.05, E + 0.03), (uc_, E + R - 0.02), sgn=-1)
            self.beam_front(v, (uc_, E), (uc_, E + R - 0.05), sgn=-1)
            if R > 0.9:
                self.window_front(v, uc_ - 0.3, E + 0.2, 0.26, 0.4, sgn=-1)

    def finish(self):
        for p in self.parts.values():
            if p["material"] is None:
                p.pop("material")
            if self.cuts:
                cuts = [{"plane": {"n": [c["plane"]["n"][0] * self.mx, c["plane"]["n"][1], c["plane"]["n"][2] * self.mz],
                                   "at": c["plane"]["at"]}} for c in self.cuts]
                p.setdefault("cut", []).extend(cuts)
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


class RichHouse(House):
    """A patrician house (hut level 3, G3 part 4a): masonry (ashlar or brick) on a tall stone plinth,
    no jetties, a stone string course at every floor and a cornice, framed cross windows with hood
    moulds, quoins, and either an arcade of round arches (`arcade`) or a stone portal with a coat of
    arms over it; optionally an oriel bay on the upper floors (`bay`). Gables: masonry, stepped or
    curved, or the corner turret ("tower")."""

    rich = True
    AD = 0.62       # depth of the arcade

    def __init__(self, *a, arcade=False, bay=False, arms="red", **k):
        k.setdefault("gable", "masonry")
        k.setdefault("front_frame", False)
        super().__init__(*a, **k)
        self.jetty = 0.0
        self.arcade, self.bay, self.arms = arcade, bay, arms

    # -- details --------------------------------------------------------------------------
    def rotg(self):
        return r4(self.mrot([0, self.yaw, 0])) if abs(self.yaw) > 1e-6 else None

    def ext_front(self, part, mat, u, y, v, poly, depth, **extra):
        g = {"c": self.pt(u, y, v), "depth": depth, "profile": {"polygon": r4p(poly)}}
        if self.rotg():
            g["rot"] = self.rotg()
        self.add(part, {"extrude": g}, mat, **extra)

    def window_rich(self, v, uw, ys, ww=0.42, wh=0.9, sgn=1, frame="sill_mat"):
        """A stone-framed cross window (a mullion and a transom) with a sill and a hood mould."""
        self.add("wframe" + ("_shade" if frame != "sill_mat" else ""),
                 self.box((uw, ys + wh / 2, v + sgn * 0.02), (ww / 2 + 0.07, wh / 2 + 0.07, 0.03)), frame)
        self.add("glass", self.box((uw, ys + wh / 2, v + sgn * 0.04), (ww / 2, wh / 2, 0.02)), "glass")
        if ww > 0.3:
            self.add("mullion", self.box((uw, ys + wh / 2, v + sgn * 0.06), (0.025, wh / 2, 0.02)), "sill_mat")
        if wh > 0.5:
            self.add("mullion", self.box((uw, ys + wh * 0.62, v + sgn * 0.06), (ww / 2, 0.025, 0.02)), "sill_mat")
        self.add("sill", self.box((uw, ys - 0.08, v + sgn * 0.07), (ww / 2 + 0.1, 0.035, 0.07)), "sill_mat")
        self.add("hood", self.box((uw, ys + wh + 0.11, v + sgn * 0.06), (ww / 2 + 0.12, 0.035, 0.06)), "sill_mat")

    def window_side_rich(self, u, s, vw, ys, ww=0.4, wh=0.85):
        self.add("wframe", self.box((u + s * 0.02, ys + wh / 2, vw), (0.03, wh / 2 + 0.07, ww / 2 + 0.07)), "sill_mat")
        self.add("glass", self.box((u + s * 0.04, ys + wh / 2, vw), (0.02, wh / 2, ww / 2)), "glass")
        self.add("mullion", self.box((u + s * 0.06, ys + wh / 2, vw), (0.02, wh / 2, 0.025)), "sill_mat")
        self.add("mullion", self.box((u + s * 0.06, ys + wh * 0.62, vw), (0.02, 0.025, ww / 2)), "sill_mat")
        self.add("sill", self.box((u + s * 0.07, ys - 0.08, vw), (0.07, 0.035, ww / 2 + 0.1)), "sill_mat")
        self.add("hood", self.box((u + s * 0.06, ys + wh + 0.11, vw), (0.06, 0.035, ww / 2 + 0.12)), "sill_mat")

    def course(self, y, v, sgn=1, big=False):
        """A stone string course (or the cornice, `big`) across the front (or back) face."""
        hh, d = (0.07, 0.1) if big else (0.04, 0.06)
        self.add("courses", self.box((self.uc, y, v + sgn * d / 2), (self.w / 2 + (0.03 if big else 0.0), hh, d)), "sill_mat")

    def course_side(self, u, s, y, v0, v1, big=False):
        hh, d = (0.07, 0.1) if big else (0.04, 0.06)
        self.add("courses", self.box((u + s * d / 2, y, (v0 + v1) / 2), (d, hh, (v1 - v0) / 2)), "sill_mat")

    def arms_at(self, u, y, v):
        """A painted coat of arms in a stone frame: a shield with a gold chevron."""
        sh = [[-0.2, 0.22], [0.2, 0.22], [0.2, -0.02], [0.0, -0.26], [-0.2, -0.02]]
        fr = [[x * 1.35, y_ * 1.3 + 0.02] for x, y_ in sh]
        self.ext_front("arms_frame", "sill_mat", u, y, v + 0.03, fr, 0.06)
        self.ext_front("arms_" + self.arms, "herald_" + self.arms, u, y, v + 0.08, sh, 0.06, priority=2)
        self.add("arms_chevron", self.box((u - 0.09, y - 0.02, v + 0.12), (0.12, 0.035, 0.02), rot=self.rot_v(0.7)),
                 "gold_trim", priority=3)
        self.add("arms_chevron", self.box((u + 0.09, y - 0.02, v + 0.12), (0.12, 0.035, 0.02), rot=self.rot_v(-0.7)),
                 "gold_trim", priority=3)

    def arch_poly(self, hw, spring, top=None):
        """An arched opening (half width hw, springing at `spring`), closed at the bottom (y 0)."""
        pts = [[hw * math.cos(math.radians(a)), spring + hw * math.sin(math.radians(a))] for a in range(0, 181, 15)]
        return pts + [[-hw, 0], [hw, 0]]

    def portal(self, u, v, y0, gate=False, frame="sill_mat"):
        """A round-arched stone portal with voussoirs and a plank door (or a dark gateway)."""
        gw = 0.5 if gate else 0.36
        spring = 1.3 if gate else 1.12
        inner = self.arch_poly(gw, spring)
        outer = [[x * (gw + 0.14) / gw, (y_ - spring) * (gw + 0.14) / gw + spring if y_ > spring else y_] for x, y_ in inner]
        outer = [[x, y_] for x, y_ in outer[:-2]] + [[-(gw + 0.14), 0], [gw + 0.14, 0]]
        self.ext_front("portal" + ("_shade" if frame != "sill_mat" else ""), frame, u, y0, v + 0.04, outer, 0.1, priority=2)
        self.ext_front("gate" if gate else "door", "gate_dark" if gate else "door_wood", u, y0, v + 0.07, inner, 0.1,
                       priority=2)
        if not gate:
            self.add("door_line", self.box((u, y0 + spring / 2 + 0.1, v + 0.13), (0.018, spring / 2 + 0.05, 0.02)), "ink")
            for yy in (y0 + 0.35, y0 + 0.95):
                self.add("door_iron", self.box((u, yy, v + 0.13), (gw - 0.06, 0.03, 0.02)), "iron_band", priority=3)
        for k in range(5):      # voussoirs: darker joints on the arch ring
            a = math.radians(30 + k * 30)
            self.add("voussoir", self.box((u + (gw + 0.07) * math.cos(a), y0 + spring + (gw + 0.07) * math.sin(a), v + 0.1),
                                          (0.012, 0.075, 0.02), rot=self.rot_v(a - math.pi / 2)), "stone_joint")
        self.add("step", self.box((u, 0.06, v + 0.25), (gw + 0.2, 0.06, 0.18)), "stone")
        self.add("step", self.box((u, 0.17, v + 0.12), (gw + 0.12, 0.05, 0.1)), "stone")
        return spring + gw + 0.14

    # -- the house ------------------------------------------------------------------------
    def build(self):
        uc, w, vb, vf = self.uc, self.w, self.vb, self.vf
        u0, u1 = uc - w / 2, uc + w / 2
        G = self.floors[0]
        PLH = PL + 0.15                     # a taller plinth of dressed stone
        self.add("plinth", self.box((uc, PLH / 2, (vb + vf) / 2 + 0.03), (w / 2 + 0.01, PLH / 2, (vf - vb) / 2 + 0.03)),
                 "plinth_stone")
        vg = vf - self.AD if self.arcade else vf
        self.add("walls_ground", self.box((uc, PLH + (G - PLH + PL) / 2, (vb + vg) / 2), (w / 2 - 0.02, (G - PLH + PL) / 2,
                                                                                     (vg - vb) / 2)),
                 self.plaster, priority=1)
        if self.arcade:     # the back wall of the arcade lies in deep shade
            self.add("arcade_back", self.box((uc, PL + G / 2, vg + 0.01), (w / 2 - 0.03, G / 2, 0.015)),
                     self.plaster + "_shade", priority=2)
        y = PL + G
        levels = [(PL, y, vf)]
        for fh in self.floors[1:]:
            self.add("walls", self.box((uc, y + fh / 2, (vb + vf) / 2), (w / 2, fh / 2, (vf - vb) / 2)), self.plaster)
            levels.append((y, y + fh, vf))
            y += fh
        E = y
        # string courses and the cornice
        for (ya, _, _) in levels[1:]:
            self.course(ya + 0.02, vf)
        self.course(E - 0.04, vf, big=True)
        # quoins on the two front corners
        k, yq = 0, PLH + 0.1
        while yq < E - 0.25:
            for su in (-1, 1):
                long_ = (k % 2 == 0)
                hu = 0.2 if long_ else 0.12
                self.add("quoins", self.box((uc + su * (w / 2 - hu + 0.02), yq + 0.15, vf + 0.015), (hu, 0.15, 0.03)),
                         "sill_mat")
            k += 1
            yq += 0.34
        # ground floor: an arcade of round arches, or a portal
        if self.arcade:
            nb = max(1, round(w / 0.85))
            bw = w / nb
            spring = min(1.55, PL + G - bw / 2 - 0.35) - PL
            for i in range(nb + 1):
                pu = u0 + i * bw
                pu = min(max(pu, u0 + 0.12), u1 - 0.12)
                self.add("pillars", self.box((pu, PL + (spring + 0.05) / 2, vf - 0.12), (0.12, (spring + 0.05) / 2, 0.12)),
                         "sill_mat")
                self.add("pillars", self.box((pu, PL + spring + 0.06, vf - 0.12), (0.16, 0.05, 0.15)), "sill_mat")
            for i in range(nb):
                cu = u0 + (i + 0.5) * bw
                hb = bw / 2 - 0.12
                poly = [[-hb - 0.12, G], [hb + 0.12, G], [hb + 0.12, spring]]
                poly += [[hb * math.cos(math.radians(a)), spring + hb * math.sin(math.radians(a))] for a in range(0, 181, 15)]
                poly += [[-hb - 0.12, spring]]
                self.ext_front("spandrels", self.plaster, cu, PL, vf - 0.12, poly, 0.24)
                self.add("keystones", self.box((cu, PL + spring + hb + 0.05, vf + 0.01), (0.07, 0.1, 0.03)), "sill_mat")
            # flagstones under the arcade, the door and a shop window in the shade at the back
            self.add("arcade_floor", self.box((uc, PL - 0.02, vf - self.AD / 2), (w / 2 - 0.03, 0.025, self.AD / 2)),
                     "flags")
            du = self.door_u if self.door_u is not None else (u0 + 0.5 if w > 1.4 else uc)
            if self.gate:
                self.portal(du, vg, PL, gate=True, frame="stone_shade")
            else:      # a plank door in the shade, a lantern on a bracket
                self.add("door", self.box((du, PL + 0.62, vg + 0.03), (0.28, 0.62, 0.03)), "door_wood")
                self.add("door_line", self.box((du, PL + 0.62, vg + 0.07), (0.018, 0.57, 0.02)), "ink")
            self.arms_at(uc, PL + G + 0.62 if not self.bay else PL + G - 0.28, vf)
        else:
            du = self.door_u if self.door_u is not None else (u0 + 0.5 if w > 1.4 else uc)
            top = self.portal(du, vf, PL, gate=self.gate)
            self.arms_at(du, PL + top + 0.32, vf)
            if w > 1.4:
                ux = u1 - 0.5 if du < uc else u0 + 0.5
                self.window_rich(vf, ux, PL + 0.75, 0.46, 0.85)
                # a shop counter under the window: a shutter let down on chains
                self.add("counter", self.box((ux, PL + 0.62, vf + 0.16), (0.3, 0.03, 0.16)), "door_wood")
        # upper floors: cross windows (the bay takes the middle of the first two floors)
        for li, (ya, yb, v) in enumerate(levels[1:], start=1):
            nwin = 3 if w > 2.15 else (2 if w > 1.42 else 1)
            cs = [u0 + w * (i + 0.5) / nwin for i in range(nwin)]
            for c in cs:
                if self.bay and li <= 2 and abs(c - uc) < w / (2 * nwin) + 1e-6 and nwin != 2:
                    continue
                if self.bay and nwin == 2 and li <= 2:
                    c = u0 + 0.3 if c < uc else u1 - 0.3
                self.window_rich(v, c, ya + 0.42, 0.4 if nwin > 1 else 0.5, min(0.95, (yb - ya) - 0.75))
        if self.bay:
            self.oriel_bay(levels)
        if self.gable == "tower":
            self.paint_walls()
            return self.oriel(uc, vf, E)
        R = self.gables(E, vf)
        self.paint_walls()
        # side walls: courses where they may show, framed windows where a street passes
        for side in ("-u", "+u"):
            if side not in self.side_frame and side not in self.side_windows:
                continue
            s = -1 if side == "-u" else 1
            u = (u0 if s < 0 else u1)
            for (ya, yb, _) in levels[1:]:
                self.course_side(u, s, ya + 0.02, vb, vf)
            self.course_side(u, s, E - 0.04, vb, vf, big=True)
            if side in self.side_windows:
                span = vf - vb
                nb = max(2, round(span / 1.1))
                for (ya, yb, _) in levels:
                    for i in range(nb):
                        vw = vb + span * (i + 0.5) / nb
                        if ya <= PL + 1e-6 and i == nb - 1 and self.arcade:
                            continue
                        self.window_side_rich(u, s, vw, ya + (0.55 if ya > PL else 0.7), 0.38, min(0.85, yb - ya - 0.75))
        if self.back_detail:
            self.back_rich(levels, E, R)
        self.roof_and_chimney(E, R, vf)
        return self.finish()

    def oriel_bay(self, levels):
        """A stone oriel on a corbel over the first two upper floors, cross windows, a lead roof."""
        uc, vf = self.uc, self.vf
        bw, D = min(0.86, self.w * 0.42), 0.34
        y0 = levels[1][0] + 0.12
        y1 = levels[min(2, len(levels) - 1)][1] - 0.15
        self.add("bay", self.box((uc, (y0 + y1) / 2, vf + D / 2), (bw / 2, (y1 - y0) / 2, D / 2)), self.plaster, priority=2)
        self.add("bay_courses", self.box((uc, y0 + 0.03, vf + D / 2 + 0.02), (bw / 2 + 0.04, 0.05, D / 2 + 0.04)), "sill_mat")
        self.add("bay_courses", self.box((uc, y1 - 0.03, vf + D / 2 + 0.02), (bw / 2 + 0.04, 0.05, D / 2 + 0.04)), "sill_mat")
        self.add("bay_corbel", {"cone": {"a": self.pt(uc, y0 - 0.7, vf + 0.04), "b": self.pt(uc, y0, vf + D / 2),
                                         "r": [0.06, bw / 2]}}, "sill_mat")
        for (ya, yb, _) in levels[1:3]:
            self.window_rich(vf + D, uc, max(ya, y0) + 0.35, bw - 0.3, min(0.85, yb - max(ya, y0) - 0.65))
        self.add("bay_roof", self.box((uc, y1 + 0.18, vf + D / 2 - 0.02), (bw / 2 + 0.05, 0.035, D / 2 + 0.14),
                                      rot=self.rot_u(-0.55)), "lead")

    def paint_walls(self):
        for nm in ("walls", "walls_ground", "gable", "show_gable", "spandrels", "bay"):
            p = self.parts.get(f"{self.n}_{nm}")
            if p is None:
                continue
            mat = p["material"].replace("_shade", "")
            if mat.startswith("brick"):
                p.setdefault("paint", []).append({"material": "brick_line", "stripes": {"axis": "y", "period": 0.13,
                                                                                        "width": 0.055}})
            elif mat.startswith("ashlar"):
                p.setdefault("paint", []).append({"material": mat + "_line", "stripes": {"axis": "y", "period": 0.3,
                                                                                         "width": 0.055, "offset": 0.05}})
                p["paint"].append({"material": mat + "_line", "spots": {"scale": 0.22, "density": 0.12,
                                                                         "seed": sum(map(ord, self.n)) % 31}})

    def back_rich(self, levels, E, R):
        """The back wall: framed windows, a plain back door, string courses, a gable window."""
        uc, w, v = self.uc, self.w, self.vb
        u0, u1 = uc - w / 2, uc + w / 2
        for (ya, yb, _) in levels:
            ground = ya <= PL + 1e-6
            nwin = 1 if (ground or w < 1.42) else 2
            cs = [u1 - 0.5] if ground else [u0 + w * (i + 0.5) / nwin for i in range(nwin)]
            for c in cs:
                if ground and w < 1.2:
                    break
                self.window_rich(v, c, ya + (0.7 if ground else 0.42), 0.38, min(0.8, yb - ya - 0.75), sgn=-1)
            if ground:
                du = u0 + 0.45
                self.add("door", self.box((du, ya + 0.7, v - 0.01), (0.26, 0.6, 0.03)), "door_wood")
                self.add("wframe", self.box((du, ya + 0.72, v + 0.005), (0.33, 0.66, 0.02)), "sill_mat")
            else:
                self.course(ya + 0.02, v, sgn=-1)
        self.course(E - 0.04, v, sgn=-1, big=True)
        if self.gable != "tower" and R > 0.9:
            self.window_rich(v, uc, E + 0.25, 0.28, 0.45, sgn=-1)


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


def row(widths, vfs, floors, plasters, roofs, end=None, extra=None, cls=None):
    """Houses side by side across the plot (orient z), from -x (side b) to +x (side a). The
    patricians' plots (cls RichHouse) touch their neighbours (ART_SPEC 7), the burghers' keep a gap."""
    gap = 0.015 if cls is RichHouse else GAP
    lo, hi = -H + gap, H - gap
    scale = (hi - lo) / sum(widths)
    widths = [w * scale for w in widths]
    houses = []
    u = lo
    for i, w in enumerate(widths):
        sw = ("-u",) if (end in ("b", "both") and i == 0) else ()
        sf = ("-u", "+u") if (end in ("a", "both") and i == len(widths) - 1) else ("-u",)
        houses.append((cls or House)(f"h{i}", "z", u + w / 2, w, -H + 0.16, vfs[i], floors[i], plasters[i], roofs[i],
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


def corner(look, rich=False):
    """Corner fragment (corner_a: joined at side a (+x) and at the back (-z)) with a chamfered corner.
    rich: the patricians' corner (hut level 3: RichHouse, CORNER_LOOKS3, taller floors)."""
    lk = (CORNER_LOOKS3 if rich else CORNER_LOOKS)[look]
    Hs = RichHouse if rich else House
    h1_floors = [2.4, 1.95, 1.8] if rich else [2.0, 1.75, 1.6]
    xk = lk.get("extra", {}) if rich else {}
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
    plain = "masonry" if rich else "plain"
    return [
        Hs("h0", "z", (0.02 + H - GAP) / 2, (H - GAP) - 0.02, -H + 0.16, 1.98, [2.4, 1.95] if rich else [2.0, 1.8],
           plaster0, roof0, side_frame=("-u",), gable=gable0, pitch=56, **xk.get("h0", {})),
        Hs("h1", "mx", h1_uc, h1_w, -0.02, h1_vf, h1_floors, lk["h1"][0], lk["h1"][1], side_windows=("+u",),
           side_frame=(), chimney=0.2, gable=plain, pitch=58, cuts=chamfer, **xk.get("h1", {})),
        Hs("hc", -45.0, 0.0, leg * 1.4142, -1.0, 0.0, h1_floors, lk["h1"][0], bay_roof, side_frame=(),
           chimney=None, pitch=60, origin=mid, **lk["bay"]),
        Hs("h2", "mx", (-H + 0.16 - 0.05) / 2, (H - 0.16) - 0.05, -0.02, H - GAP - 0.14, [2.4, 1.9] if rich else [2.0, 1.7],
           lk["h2"][0], lk["h2"][1], side_frame=(), chimney=0.35, pitch=62, gable=plain, **xk.get("h2", {})),
    ]


C, O, P_, B = "plaster_cream", "plaster_ochre", "plaster_pink", "plaster_blue"
# The game's set (owner 2026-11-09: the burgher houses go into the game): level 2 pieces x 3 looks.
GAME = {
    ("single", 1): lambda: row([2.2, 2.1], [1.96, 2.02], [[2.0, 1.8, 1.6], [2.0, 1.75]], [P_, C], ["tile", "slate"],
                               end="both", extra=[{"gable": "stepped", "pitch": 58}, {"pitch": 54}]),
    ("single", 2): lambda: row([1.5, 1.45, 1.5], [2.0, 1.88, 1.98], [[2.0, 1.8], [2.0, 1.75, 1.6], [1.9, 1.85]],
                               [C, B, O], ["tile", "tile", "slate"], end="both",
                               extra=[{"pitch": 58}, {"gable": "curved", "pitch": 60}, {"pitch": 61}]),
    ("single", 3): lambda: row([2.3, 2.0], [1.92, 2.03], [[2.0, 1.85], [2.0, 1.8, 1.6]], [O, C], ["slate", "tile"],
                               end="both", extra=[{"gable": "curved", "pitch": 57, "front_frame": False}, {"pitch": 56}]),
    ("end_a", 1): FRAGMENTS["end_a"],
    ("end_a", 2): lambda: row([1.5, 1.5, 1.4], [1.9, 2.02, 1.95], [[2.0, 1.85], [2.0, 1.75, 1.6], [2.0, 1.8]],
                              [B, C, P_], ["slate", "tile", "tile"], end="a",
                              extra=[{"pitch": 60}, {"gable": "stepped", "pitch": 62}, {"pitch": 55}]),
    ("end_a", 3): lambda: row([2.1, 2.2], [2.02, 1.92], [[2.0, 1.8], [2.0, 1.8, 1.6]], [C, O], ["tile", "slate"],
                              end="a", extra=[{"pitch": 55}, {"gable": "curved", "pitch": 58, "front_frame": False}]),
    ("middle", 1): FRAGMENTS["middle"],
    ("middle", 2): FRAGMENTS["middle_2"],
    ("middle", 3): FRAGMENTS["middle_3"],
    ("end_b", 1): FRAGMENTS["end_b"],
    ("end_b", 2): FRAGMENTS["end_b_2"],
    ("end_b", 3): lambda: row([1.45, 1.5, 1.5], [1.95, 2.02, 1.88], [[2.0, 1.75], [2.0, 1.85, 1.6], [2.0, 1.8]],
                              [O, C, P_], ["tile", "slate", "tile"], end="b",
                              extra=[{"pitch": 59}, {"gable": "stepped", "pitch": 61}, {"pitch": 54}]),
    ("corner_a", 1): lambda: corner("gate"),
    ("corner_a", 2): lambda: corner("tower"),
    ("corner_a", 3): lambda: corner("shop"),
    # corner_b is corner_a mirrored in x (joined at side b and at the back)
    ("corner_b", 1): lambda: corner("shop"),
    ("corner_b", 2): lambda: corner("gate"),
    ("corner_b", 3): lambda: corner("tower"),
}


AS, AG, BR = "ashlar_sand", "ashlar_grey", "brick_wall"
R3 = RichHouse
F3, F3b, F4 = [2.4, 1.95, 1.8], [2.4, 1.9], [2.4, 1.9, 1.75]
# The patricians' set (hut level 3, G3 part 4a, owner's survey 2026-11-13: rich, of stone): ashlar and
# brick, arcades, portals with coats of arms, oriels, stepped and curved gables; 6 pieces x 3 looks.
GAME3 = {
    ("single", 1): lambda: row([2.2, 2.1], [2.0, 1.96], [F3, F3b], [AS, BR], ["slate", "tile"], end="both", cls=R3,
                               extra=[{"gable": "stepped", "pitch": 58, "arcade": True},
                                      {"pitch": 55, "bay": True, "arms": "blue"}]),
    ("single", 2): lambda: row([2.1, 2.2], [2.0, 1.94], [F3b, F3], [AG, AS], ["tile", "slate"],
                               end="both", cls=R3, extra=[{"gable": "curved", "pitch": 60, "arcade": True},
                                                          {"gable": "stepped", "pitch": 58, "arcade": True,
                                                           "arms": "green"}]),
    ("single", 3): lambda: row([2.3, 2.0], [1.96, 2.02], [F3b, F3], [BR, AG], ["tile", "slate"], end="both", cls=R3,
                               extra=[{"gable": "stepped", "pitch": 57, "bay": True}, {"gable": "curved", "pitch": 58,
                                                                                      "arms": "blue"}]),
    ("end_a", 1): lambda: row([2.0, 2.3], [1.96, 2.02], [F3, F3b], [AS, BR], ["slate", "tile"], end="a", cls=R3,
                              extra=[{"gable": "stepped", "pitch": 58, "arcade": True}, {"pitch": 54, "bay": True}]),
    ("end_a", 2): lambda: row([2.2, 2.1], [1.96, 2.02], [F3, F3b], [BR, AS], ["tile", "slate"],
                              end="a", cls=R3, extra=[{"pitch": 57, "arcade": True},
                                                      {"gable": "curved", "pitch": 59, "arcade": True, "arms": "blue"}]),
    ("end_a", 3): lambda: row([2.1, 2.2], [2.02, 1.96], [F3b, F3], [AG, BR], ["slate", "tile"], end="a", cls=R3,
                              extra=[{"pitch": 55, "arms": "green"}, {"gable": "stepped", "pitch": 58, "bay": True}]),
    ("middle", 1): lambda: row([2.2, 2.1], [1.98, 2.02], [F3, F3b], [BR, AS], ["tile", "slate"], cls=R3,
                               extra=[{"gable": "stepped", "pitch": 59, "arcade": True},
                                      {"gable": "curved", "pitch": 57, "arcade": True, "arms": "blue"}]),
    ("middle", 2): lambda: row([2.15, 2.15], [2.0, 1.94], [F3, F3b], [AG, BR], ["slate", "tile"],
                               cls=R3, extra=[{"pitch": 58, "arcade": True, "arms": "green"},
                                              {"gable": "stepped", "pitch": 60, "arcade": True}]),
    ("middle", 3): lambda: row([2.3, 2.0], [1.96, 2.02], [F3b, F3], [AS, BR], ["tile", "slate"], cls=R3,
                               extra=[{"gable": "curved", "pitch": 56, "bay": True}, {"pitch": 58, "arms": "blue"}]),
    ("end_b", 1): lambda: row([2.15, 2.15], [1.98, 2.02], [F3b, F3], [BR, AG], ["slate", "tile"], end="b", cls=R3,
                              extra=[{"pitch": 55, "bay": True, "arms": "green"}, {"gable": "curved", "pitch": 58,
                                                                                   "arcade": True}]),
    ("end_b", 2): lambda: row([2.0, 2.3], [2.02, 1.96], [F3, F3b], [AS, BR], ["tile", "slate"], end="b", cls=R3,
                              extra=[{"gable": "stepped", "pitch": 58, "arcade": True}, {"pitch": 55, "arcade": True,
                                                                                         "arms": "blue"}]),
    ("end_b", 3): lambda: row([2.1, 2.2], [1.98, 2.02], [F3, F3b], [AG, BR], ["tile", "slate"],
                              end="b", cls=R3, extra=[{"pitch": 57, "bay": True}, {"gable": "curved", "pitch": 58,
                                                                                    "arms": "blue"}]),
    ("corner_a", 1): lambda: corner("gate", rich=True),
    ("corner_a", 2): lambda: corner("tower", rich=True),
    ("corner_a", 3): lambda: corner("shop", rich=True),
    ("corner_b", 1): lambda: corner("shop", rich=True),
    ("corner_b", 2): lambda: corner("gate", rich=True),
    ("corner_b", 3): lambda: corner("tower", rich=True),
}

CORNER_LOOKS3 = {
    "gate": dict(h0=(AS, "slate", "stepped"), h1=(BR, "tile"), h2=(AG, "slate"),
                 bay=dict(gable="curved", gate=True), extra={"h0": {"arcade": True}, "h2": {"arms": "blue"}}),
    "tower": dict(h0=(BR, "tile", "curved"), h1=(AS, "slate"), h2=(BR, "tile"),
                  bay=dict(gable="tower"), extra={"h0": {"arcade": True, "arms": "green"}}),
    "shop": dict(h0=(AG, "tile", "stepped"), h1=(AS, "tile"), h2=(AG, "slate"),
                 bay=dict(gable="stepped"), extra={"h0": {"bay": True}, "h2": {"arcade": True}}),
}


def game_names(level=2):
    out = []
    for (frag, n) in (GAME if level == 2 else GAME3):
        for back in (False, True):
            out.append(f"l{level}_{frag}" + (f"_{n}" if n > 1 else "") + ("_back" if back else ""))
    return out


def game_houses(name):
    """l2_<piece>[_<look>][_back] (or l3_: the patricians) -> houses: corner_b mirrored in x, the back views
    mirrored in z with back walls."""
    rest = name[3:]
    back = rest.endswith("_back")
    if back:
        rest = rest[:-5]
    n = 1
    if rest[-2:] in ("_2", "_3"):
        n, rest = int(rest[-1]), rest[:-2]
    houses = (GAME3 if name.startswith("l3_") else GAME)[(rest, n)]()
    for h in houses:
        h.mx = -1 if rest == "corner_b" else 1
        h.mz = -1 if back else 1
        h.back_detail = back
        if back:   # a street (and the windows) on both sides of a corner house seen from behind
            h.side_windows = tuple(set(h.side_windows) | ({"+u", "-u"} if h.yaw != 0 else set()))
        if rest == "corner_b":   # mirrored in x: the side that shows (-x) was the hidden +x side
            h.side_frame = tuple({"+u": "-u", "-u": "+u"}[x] for x in h.side_frame) if h.yaw == 0 else h.side_frame
    return houses


RAMPS3 = {
    "ashlar_sand": ["#1c160e", "#4a3c28", "#7a6648", "#a89070", "#cab490", "#e4d4b0"],
    "ashlar_grey": ["#141414", "#383836", "#5c5a56", "#82807a", "#a6a49c", "#c8c6bc"],
    "herald_red": ["#2a0606", "#6a1412", "#a42620", "#cc4434"],
    "herald_blue": ["#060c22", "#142456", "#24408a", "#4062b4"],
    "herald_green": ["#061a0c", "#14421e", "#246a30", "#3e9048"],
}


def materials3():
    """The patricians' extra materials (hut level 3)."""
    m = {"brick_wall": {"ramp": "brick", "bands": [2, 4]}, "brick_wall_shade": {"ramp": "brick", "bands": [0, 1]},
         "brick_line": {"ramp": "brick", "bands": [0, 1], "outline": False},
         "plinth_stone": {"ramp": "stone", "bands": [2, 4]}, "flags": {"ramp": "cobble", "bands": [2, 4], "outline": False},
         "gold_trim": {"ramp": "gold", "bands": [3, 5], "finish": "metal"}, "iron_band": {"ramp": "steel", "bands": [1, 2]},
         "stone_joint": {"ramp": "stone", "bands": [0, 1], "outline": False}, "lead": {"ramp": "slate", "bands": [2, 4]},
         "stone_shade": {"ramp": "stone", "bands": [0, 2]}}
    for r in ("ashlar_sand", "ashlar_grey"):
        m[r] = {"ramp": r, "bands": [2, 5]}
        m[r + "_shade"] = {"ramp": r, "bands": [0, 1]}
        m[r + "_line"] = {"ramp": r, "bands": [1, 2], "outline": False}
    for c in ("red", "blue", "green"):
        m["herald_" + c] = {"ramp": "herald_" + c, "bands": [1, 3]}
    return m


def spec(frag):
    parts = plot_parts()
    for h in (game_houses(frag) if frag.startswith(("l2_", "l3_")) else FRAGMENTS[frag]()):
        parts.update(h.build())
    if frag.startswith("l3_"):
        s = spec_base(frag, parts)
        s["brief"]["summary"] = (f"Your Kingdom patrician townhouses (hut level 3, G3 part 4a), fragment {frag} of a row on "
                                 "a 2x2 plot: tall houses of ashlar and brick, arcades, stone portals with coats of arms, "
                                 "oriels, stepped and curved gables, tiled or slate roofs")
        s["materials"].update(materials3())
        rest = {k: v for k, v in s.items() if k not in ("palette", "camera")}
        out = {k: s[k] for k in ("spritekiln", "name", "render", "kind", "size", "directions", "palette", "camera",
                                 "shadow")}
        out["ramps"] = RAMPS3
        out.update({k: v for k, v in rest.items() if k not in out})
        return out
    return spec_base(frag, parts)


def spec_base(frag, parts):
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
    if frags == ["game"]:
        frags = game_names()
    elif frags == ["game3"]:
        frags = game_names(3)
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
