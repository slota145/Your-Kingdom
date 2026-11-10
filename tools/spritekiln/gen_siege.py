"""Siege engines from SpriteKiln (owner's survey 2026-11-10): the ram and the ballista, 8 directions.

Writes art/specs/props/<name>/<name>.yaml:
  ram, ram_enemy: a shed on four spoked wheels under a gabled roof of wet hides laced with rope, an
    iron-headed log hung inside on ropes, the legs of six men under the eaves (owner: "nogi pod dachem");
    animations idle, walk (wheels turn, the men walk) and strike (the log drawn back, then swung forward).
  ballista, ballista_enemy: a great crossbow on a two-wheeled cart with a front trestle, two torsion
    springs and arms bound with iron, a winch at the tail; animations idle (drawn, a bolt in the groove),
    walk (wheels turn, still drawn) and reload (the string forward after the shot, the winch turning).
    The two crewmen are a separate character (art/specs/characters/siege_crew), drawn behind the
    machine by the game (SiegeLayer).
The _enemy variants differ only in the pennon (black instead of the kingdom's red).
Frame 128 px with the pivot (the engine's centre on the ground) at (64, 112), like the riders
(CharacterSheet.foot_margin). Model +z = the engine's front (the direction it moves and shoots).
Run: python3 tools/spritekiln/gen_siege.py [name ...]; render each (spritekiln render <name>.yaml in its
folder), then python3 tools/spritekiln/export_character.py <name> --props --anims=idle,walk,strike:work
"""
import math
import os
import sys

import yaml

HERE = os.path.dirname(os.path.abspath(__file__))
PROPS = os.path.join(HERE, "art", "specs", "props")

RAMPS = {
    "hide": ["#120a06", "#2e1a0e", "#4a2c18", "#663e22", "#80522e", "#9a6a3e"],
    "hide2": ["#100b08", "#281c14", "#40301f", "#5a442e", "#74583c", "#8e6e4c"],
    "plank": ["#160d07", "#3a2414", "#5e3c20", "#80562e", "#a3743f", "#c49a5e"],
    "beam": ["#120a05", "#2e1a0c", "#4a2c16", "#683e20", "#86542c", "#a46a3a"],
    "iron": ["#101216", "#2a2f38", "#475060", "#6e7888", "#a0aab6", "#dfe4ea"],
    "rope": ["#1a1408", "#3e321c", "#66553a", "#8c7a58", "#b0a07a", "#d0c49e"],
    "hose": ["#120e0b", "#2e2620", "#4a4035", "#665a4b", "#837563", "#a3937c"],
    "boot": ["#140a05", "#3a2414", "#5e3c20", "#80562e", "#a3743f", "#c49a5e"],
    "coat": ["#1a1208", "#3e2e18", "#64502e", "#8a7448", "#ab9566", "#c9b688"],
    "red": ["#1c0908", "#4a1512", "#7c221b", "#a63026", "#c64a34", "#dc7350"],
    "black": ["#08080a", "#141418", "#222228", "#303038", "#40404a", "#52525e"],
}
MAT = {
    "hide": {"ramp": "hide", "bands": [1, 5]},
    "hide2": {"ramp": "hide2", "bands": [1, 5]},
    "fur": {"ramp": "hide", "bands": [1, 2], "outline": False, "line": False},
    "plank": {"ramp": "plank", "bands": [2, 5]},
    "seam": {"ramp": "plank", "bands": [0, 1], "outline": False, "line": False},
    "beam": {"ramp": "beam", "bands": [1, 4]},
    "iron": {"ramp": "iron", "bands": [1, 4], "finish": "metal"},
    "tyre": {"ramp": "iron", "bands": [0, 2]},
    "rope": {"ramp": "rope", "bands": [2, 4], "line": False},
    "hose": {"ramp": "hose", "bands": [1, 4]},
    "boot": {"ramp": "boot", "bands": [1, 3]},
    "coat": {"ramp": "coat", "bands": [1, 3]},
    "pennon": {"ramp": "red", "bands": [2, 5], "two_sided": True},
}
ENEMY_PENNON = {"ramp": "black", "bands": [1, 5], "two_sided": True}
RENDER = {"outline": "dark", "lines": "depth+normal", "light": "classic", "shading": "toon"}
CAMERA = {"pitch": 30, "scale": 0.05176, "center": [0, 2.869, 0]}   # the pivot at (64, 112), as the riders


def r3(v):
    return [round(float(x), 4) for x in v]


def base(name, summary):
    return {
        "spritekiln": 1,
        "name": name,
        "render": dict(RENDER),
        "kind": "prop",
        "shadow": None,
        "ramps": RAMPS,
        "size": 128,
        "directions": 8,
        "mirror": False,
        "camera": CAMERA,
        "brief": {"summary": summary, "must_keep": ["front = +z", "pivot (64, 112) = the engine's centre on the ground"]},
        "materials": MAT,
    }


def wheel_parts(spec, name, bone, radius, spokes=4, width=0.11):
    """A spoked wheel turning about the model's x axis on [bone] (its hub at the bone's origin)."""
    side = 1.0 if spec["bones"][bone]["pos"][0] > 0 else -1.0
    parts = spec["parts"]
    parts[name + "_rim"] = {"material": "beam", "space": bone, "prims": [
        {"cylinder": {"a": [-width / 2, 0, 0], "b": [width / 2, 0, 0], "r": radius}}],
        "cut": [{"cylinder": {"a": [-1, 0, 0], "b": [1, 0, 0], "r": radius - 0.07}}]}
    parts[name + "_tyre"] = {"material": "tyre", "space": bone, "prims": [
        {"cylinder": {"a": [-width / 2 - 0.005, 0, 0], "b": [width / 2 + 0.005, 0, 0], "r": radius + 0.02}}],
        "cut": [{"cylinder": {"a": [-1, 0, 0], "b": [1, 0, 0], "r": radius - 0.01}}]}
    prims = []
    for k in range(spokes // 2):
        a = k * math.pi / (spokes // 2)
        prims.append({"box": {"c": [0, 0, 0], "half": [0.03, radius - 0.04, 0.035], "rot": [round(a, 4), 0, 0]}})
    parts[name + "_spokes"] = {"material": "plank", "space": bone, "prims": prims}
    parts[name + "_hub"] = {"material": "iron", "space": bone, "prims": [
        {"cylinder": {"a": [-side * 0.02, 0, 0], "b": [side * (width / 2 + 0.06), 0, 0], "r": 0.075}}]}


# ---------------------------------------------------------------- the ram
def ram(name, enemy=False):
    s = base(name, "Your Kingdom battering ram: a shed of planks under wet hides laced with rope on four "
             "spoked wheels, an iron-headed log hung inside, the legs of six men under the eaves")
    HL = 1.62          # half length of the shed
    EX, EY = 0.95, 1.2  # eave: half width, height
    RY = 2.55          # ridge height
    s["channels"] = {"wheel": 0.0, "bob": 0.0, "logz": 0.0, "logp": 0.0, "lunge": 0.0}
    men = [(x, z) for z in (-0.5, 0.0, 0.5) for x in (0.5, -0.5)]
    for i in range(len(men)):
        s["channels"][f"sw{i}"] = 0.0
    bones = {"cart": {"parent": "root", "pos": "[0, bob, 0]"},
             "log": {"parent": "cart", "pos": "[0, 0.9, logz]", "rot": "[logp, 0, 0]"}}
    for tag, z in (("f", 1.02), ("b", -1.02)):
        for sx, sd in ((1, "l"), (-1, "r")):
            bones[f"wheel_{tag}{sd}"] = {"parent": "cart", "pos": [sx * 0.93, 0.34, z], "rot": "[wheel, 0, 0]"}
    for i, (x, z) in enumerate(men):
        bones[f"man{i}"] = {"parent": "root", "pos": f"[{x}, 0, {z} + lunge]"}
        for leg, dx, sgn in (("a", 0.075, 1), ("b", -0.075, -1)):
            bones[f"leg{i}{leg}"] = {"parent": f"man{i}", "pos": [dx, 0.9, 0], "rot": f"[{sgn}*sw{i}, 0, 0]"}
    s["bones"] = bones
    p = s["parts"] = {}
    # the frame: sills along the sides, corner posts, axles
    p["sills"] = {"material": "beam", "space": "cart", "prims": [
        {"box": {"c": [sx * 0.9, 0.42, 0], "half": [0.06, 0.05, HL - 0.05]}} for sx in (1, -1)] + [
        {"box": {"c": [0, 0.42, sz * (HL - 0.1)], "half": [0.9, 0.05, 0.05]}} for sz in (1, -1)]}
    p["posts"] = {"material": "beam", "space": "cart", "prims": [
        {"box": {"c": [sx * 0.9, 0.8, sz * (HL - 0.08)], "half": [0.055, 0.4, 0.055]}} for sx in (1, -1) for sz in (1, -1)]}
    p["axles"] = {"material": "beam", "space": "cart", "prims": [
        {"cylinder": {"a": [-0.93, 0.34, z], "b": [0.93, 0.34, z], "r": 0.06}} for z in (1.02, -1.02)]}
    for b in bones:
        if b.startswith("wheel_"):
            wheel_parts(s, b, b, 0.32)
    # the roof: on each side three hides (separate parts: lines between them), laced with ropes
    ang = math.atan2(RY - EY, EX)        # slope angle
    slope = math.hypot(EX, RY - EY) + 0.12
    segs = [(-HL + 0.52, 0.6), (0.0, 0.6), (HL - 0.52, 0.6)]
    for sx, sd in ((1, "l"), (-1, "r")):
        cx, cy = sx * (EX / 2 + 0.05 * math.cos(ang)), (EY + RY) / 2 - 0.04
        for k, (z, hz) in enumerate(segs):
            lift = 0.02 * (k % 2)
            n = (sx * math.sin(ang), math.cos(ang))
            p[f"hide_{sd}{k}"] = {"material": "hide" if (k + (sx > 0)) % 2 else "hide2", "space": "cart", "blend": 0.0,
                                  "prims": [{"box": {"c": r3([cx + n[0] * lift, cy + n[1] * lift, z]),
                                                     "half": [slope / 2, 0.045, hz], "rot": [0, 0, round(-sx * ang, 4)]}}],
                                  "paint": [{"material": "fur", "spots": {"scale": 0.07, "density": 0.1, "seed": 3 + k * 7 + (sx > 0)}}]}
        ropes = []
        for z in (-HL + 0.18, -0.58, 0.58, HL - 0.18):
            ropes.append({"cylinder": {"a": r3([sx * (EX + 0.07), EY - 0.06, z]), "b": [0, RY + 0.08, z], "r": 0.028}})
        p[f"ropes_{sd}"] = {"material": "rope", "space": "cart", "priority": 2, "prims": ropes}
    p["ridge"] = {"material": "beam", "space": "cart", "prims": [
        {"cylinder": {"a": [0, RY + 0.02, -HL - 0.12], "b": [0, RY + 0.02, HL + 0.12], "r": 0.08}}]}
    # gables of upright planks at both ends (the log passes below the front one)
    for tag, z in (("front", HL), ("back", -HL)):
        p[f"gable_{tag}"] = {"material": "plank", "space": "cart", "prims": [
            {"extrude": {"c": [0, 0, z], "depth": 0.08, "profile": {"polygon": [[-EX + 0.04, EY], [EX - 0.04, EY], [0, RY - 0.02]]}}}],
            "paint": [{"material": "seam", "stripes": {"axis": "x", "period": 0.24, "width": 0.055, "offset": 0.1}}]}
        p[f"gable_beam_{tag}"] = {"material": "beam", "space": "cart", "prims": [
            {"box": {"c": [0, EY + 0.02, z], "half": [EX + 0.02, 0.06, 0.07]}}]}
    # the log, its iron head and bands, the ropes it hangs from
    p["log"] = {"material": "beam", "space": "log", "prims": [
        {"cylinder": {"a": [0, 0, -HL + 0.05], "b": [0, 0, HL + 0.55], "r": 0.15}}]}
    p["log_head"] = {"material": "iron", "space": "log", "prims": [
        {"cylinder": {"a": [0, 0, HL + 0.5], "b": [0, 0, HL + 0.64], "r": 0.2}},
        {"cone": {"a": [0, 0, HL + 0.64], "b": [0, 0, HL + 0.84], "r": [0.18, 0.1]}},
        {"cylinder": {"a": [0, 0, 0.6], "b": [0, 0, 0.68], "r": 0.165}},
        {"cylinder": {"a": [0, 0, -0.68], "b": [0, 0, -0.6], "r": 0.165}}]}
    p["log_ropes"] = {"material": "rope", "space": "log", "priority": 2, "prims": [
        {"cylinder": {"a": [0, 0.12, z], "b": [0, RY - 0.95, z], "r": 0.03}} for z in (-0.64, 0.64)]}
    # the men: legs (hose, boots) and the hem of a quilted coat under the eaves
    for i in range(len(men)):
        p[f"coat{i}"] = {"material": "coat", "space": f"man{i}", "prims": [
            {"ellipsoid": {"c": [0, 1.02, 0.02], "r": [0.17, 0.17, 0.13]}}]}
        for leg in "ab":
            p[f"leg{i}{leg}"] = {"material": "hose", "space": f"leg{i}{leg}", "prims": [
                {"cone": {"a": [0, 0, 0], "b": [0, -0.8, 0], "r": [0.065, 0.05]}}]}
            p[f"boot{i}{leg}"] = {"material": "boot", "space": f"leg{i}{leg}", "prims": [
                {"ellipsoid": {"c": [0, -0.84, 0.04], "r": [0.055, 0.06, 0.1]}}]}
    # the pennon on a pole at the back of the ridge, streaming back
    p["pole"] = {"material": "beam", "space": "cart", "priority": 2, "prims": [
        {"cylinder": {"a": [0, RY, -HL + 0.1], "b": [0, RY + 0.85, -HL + 0.1], "r": 0.03}}]}
    p["pennon"] = {"material": "pennon", "space": "cart", "priority": 2, "prims": [
        {"extrude": {"c": [0, 0, 0], "rot": [0, -1.5708, 0], "depth": 0.03,
                     "profile": {"polygon": [[-HL + 0.1, RY + 0.84], [-HL - 0.45, RY + 0.72], [-HL + 0.1, RY + 0.56]]}}}]}
    if enemy:
        s["materials"] = dict(MAT, pennon=ENEMY_PENNON)
    walk_men = {f"sw{i}": f"0.38*sin(p + {round((i // 2) * 1.2 + (i % 2) * math.pi, 3)})" for i in range(len(men))}
    s["animations"] = {
        "idle": {"frames": 1, "ms": 200, "channels": {}},
        "walk": {"frames": 8, "ms": 110, "channels": dict(walk_men, wheel="-p/4")},
        # a 1.5 s blow: drawn back slowly, then swung forward hard (SiegeLayer plays it while drilling)
        "strike": {"frames": 10, "ms": 150, "events": {6: "hit"}, "channels": {
            "logz": "0.42*(-smoothstep(0, 3.8, p) + smoothstep(3.8, 4.4, p)*1.6 - smoothstep(4.6, 6.3, p)*0.6)",
            "logp": "0.03*sin(p)",
            "lunge": "0.06*(-smoothstep(0, 3.8, p) + smoothstep(3.8, 4.4, p)*1.6 - smoothstep(4.6, 6.3, p)*0.6)",
            **{f"sw{i}": "0.3" for i in range(len(men))}}},
    }
    return s


# ---------------------------------------------------------------- the ballista
def ballista(name, enemy=False):
    s = base(name, "Your Kingdom ballista: a great crossbow on a two-wheeled cart with a front trestle, two "
             "torsion springs, arms bound with iron, a winch at the tail and a bolt in the groove")
    TAIL, NOSE = -1.45, 1.35
    YT, YN = 0.86, 1.2            # stock height at the tail and at the nose
    slope = math.atan2(YN - YT, NOSE - TAIL)

    def stock_y(z):
        return YT + (YN - YT) * (z - TAIL) / (NOSE - TAIL)

    SZ = 0.95                      # the spring frame along the stock
    s["channels"] = {"wheel": 0.0, "draw": 1.0, "nutz": -1.05, "bolt": 1.0, "crank": 0.0}
    bones = {"cart": {"parent": "root", "pos": [0, 0, 0]},
             "nut": {"parent": "cart", "pos": f"[0, {YT + 0.12:.3f} + ({YN - YT:.3f})*(nutz - ({TAIL}))/({NOSE - TAIL:.3f}), nutz]"},
             "bolt": {"parent": "cart", "pos": [0, 0, 0], "scale": "max(bolt, 0.001)"},
             "winch": {"parent": "cart", "pos": [0, stock_y(-1.28) + 0.02, -1.28], "rot": "[crank, 0, 0]"}}
    for sx, sd in ((1, "l"), (-1, "r")):
        bones[f"wheel_{sd}"] = {"parent": "cart", "pos": [sx * 0.8, 0.42, -0.35], "rot": "[wheel, 0, 0]"}
        # an arm swings back about the vertical spring as the string is drawn
        bones[f"arm_{sd}"] = {"parent": "cart", "pos": r3([sx * 0.26, stock_y(SZ) + 0.12, SZ]),
                              "rot": f"[0, {-sx}*(0.12 + 0.42*draw), 0]"}
        bones[f"tip_{sd}"] = {"parent": f"arm_{sd}", "pos": [sx * 0.92, 0.04, 0]}
    s["bones"] = bones
    p = s["parts"] = {}
    for sx, sd in ((1, "l"), (-1, "r")):
        wheel_parts(s, f"wheel_{sd}", f"wheel_{sd}", 0.42, spokes=6, width=0.1)
    # the cart: two rails on the axle, the axle, a trestle under the front
    p["rails"] = {"material": "beam", "space": "cart", "prims": [
        {"box": {"c": [sx * 0.36, 0.56, -0.25], "half": [0.065, 0.065, 1.05]}} for sx in (1, -1)] + [
        {"box": {"c": [0, 0.56, z], "half": [0.36, 0.055, 0.06]}} for z in (-1.2, 0.7)]}
    p["axle"] = {"material": "beam", "space": "cart", "prims": [
        {"cylinder": {"a": [-0.82, 0.42, -0.35], "b": [0.82, 0.42, -0.35], "r": 0.06}}]}
    p["trestle"] = {"material": "beam", "space": "cart", "prims": [
        {"cylinder": {"a": [sx * 0.42, 0.0, 0.98], "b": [sx * 0.08, stock_y(0.8) - 0.04, 0.8], "r": 0.055}} for sx in (1, -1)] + [
        {"box": {"c": [0, 0.25, 0.94], "half": [0.36, 0.04, 0.04]}}]}
    p["post"] = {"material": "beam", "space": "cart", "prims": [
        {"cylinder": {"a": [0, 0.56, -0.25], "b": [0, stock_y(-0.25) - 0.05, -0.25], "r": 0.07}}]}
    # the stock with a dark groove on top
    mid = (TAIL + NOSE) / 2
    p["stock"] = {"material": "beam", "space": "cart", "prims": [
        {"box": {"c": r3([0, (YT + YN) / 2, mid]), "half": [0.12, 0.085, (NOSE - TAIL) / 2 / math.cos(slope)],
                 "rot": [round(-slope, 4), 0, 0]}}]}
    p["groove"] = {"material": "seam", "space": "cart", "prims": [
        {"box": {"c": r3([0, (YT + YN) / 2 + 0.075, mid]), "half": [0.03, 0.012, (NOSE - TAIL) / 2 / math.cos(slope) - 0.05],
                 "rot": [round(-slope, 4), 0, 0]}}]}
    # the spring frame: an iron-bound box across the stock with a twisted rope skein on each side
    p["frame"] = {"material": "plank", "space": "cart", "prims": [
        {"box": {"c": r3([0, stock_y(SZ) + 0.33, SZ]), "half": [0.42, 0.05, 0.1]}},
        {"box": {"c": r3([0, stock_y(SZ) - 0.08, SZ]), "half": [0.42, 0.05, 0.1]}}] + [
        {"box": {"c": r3([sx * 0.42, stock_y(SZ) + 0.12, SZ]), "half": [0.05, 0.25, 0.1]}} for sx in (1, -1)]}
    p["frame_iron"] = {"material": "iron", "space": "cart", "prims": [
        {"box": {"c": r3([sx * 0.42, stock_y(SZ) + 0.12, SZ]), "half": [0.06, 0.27, 0.035]}} for sx in (1, -1)]}
    p["skeins"] = {"material": "rope", "space": "cart", "prims": [
        {"cylinder": {"a": r3([sx * 0.26, stock_y(SZ) - 0.04, SZ]), "b": r3([sx * 0.26, stock_y(SZ) + 0.3, SZ]), "r": 0.085}} for sx in (1, -1)]}
    # the arms: tapered beams with iron bands, the string from tip to nut
    for sx, sd in ((1, "l"), (-1, "r")):
        p[f"arm_{sd}"] = {"material": "beam", "space": f"arm_{sd}", "prims": [
            {"cone": {"a": [0, 0, 0], "b": [sx * 0.94, 0.04, 0], "r": [0.095, 0.055]}}]}
        p[f"arm_iron_{sd}"] = {"material": "iron", "space": f"arm_{sd}", "prims": [
            {"cylinder": {"a": [sx * a, 0.0, 0], "b": [sx * (a + 0.05), 0.0, 0], "r": 0.08 - 0.03 * a}} for a in (0.3, 0.62)] + [
            {"sphere": {"c": [sx * 0.94, 0.04, 0], "r": 0.05}}]}
        p[f"string_{sd}"] = {"material": "rope", "space": "cart", "priority": 3, "min_cover": 2, "prims": [
            {"cylinder": {"a": f"@tip_{sd}", "b": "@nut", "r": 0.024}}]}
    p["nut"] = {"material": "iron", "space": "nut", "prims": [{"box": {"c": [0, 0, 0], "half": [0.08, 0.05, 0.06]}}]}
    # the winch: a drum across the tail with four handspikes at each end
    p["winch_drum"] = {"material": "beam", "space": "winch", "prims": [
        {"cylinder": {"a": [-0.34, 0, 0], "b": [0.34, 0, 0], "r": 0.1}}]}
    p["winch_rope"] = {"material": "rope", "space": "winch", "prims": [
        {"cylinder": {"a": [-0.12, 0, 0], "b": [0.12, 0, 0], "r": 0.115}}]}
    p["handspikes"] = {"material": "plank", "space": "winch", "prims": [
        {"box": {"c": [sx * 0.36, 0, 0], "half": [0.025, 0.3, 0.03], "rot": [a, 0, 0]}} for sx in (1, -1) for a in (0, 1.5708)]}
    p["winch_cord"] = {"material": "rope", "space": "cart", "priority": 2, "prims": [
        {"cylinder": {"a": r3([0, stock_y(-1.28) + 0.1, -1.28]), "b": "@nut", "r": 0.022}}]}
    # the bolt in the groove while loaded: a shaft, an iron head, vanes at the back
    ln = 1.9
    p["bolt"] = {"material": "plank", "space": "bolt", "priority": 2, "prims": [
        {"cylinder": {"a": r3([0, stock_y(-0.95) + 0.13, -0.95]), "b": r3([0, stock_y(-0.95 + ln) + 0.13, -0.95 + ln]), "r": 0.035}}]}
    p["bolt_head"] = {"material": "iron", "space": "bolt", "priority": 2, "prims": [
        {"cone": {"a": r3([0, stock_y(-0.95 + ln) + 0.13, -0.95 + ln]), "b": r3([0, stock_y(-0.75 + ln) + 0.135, -0.75 + ln]), "r": [0.06, 0.01]}}]}
    p["bolt_vanes"] = {"material": "rope", "space": "bolt", "prims": [
        {"box": {"c": r3([0, stock_y(-0.8) + 0.16, -0.8]), "half": [0.07, 0.01, 0.12], "rot": [round(-slope, 4), 0, 0]}}]}
    # the pennon on a pole at the back of the left rail
    p["pole"] = {"material": "beam", "space": "cart", "priority": 2, "prims": [
        {"cylinder": {"a": [0.36, 0.6, -1.2], "b": [0.36, 1.95, -1.2], "r": 0.03}}]}
    p["pennon"] = {"material": "pennon", "space": "cart", "priority": 2, "prims": [
        {"extrude": {"c": [0.36, 0, 0], "rot": [0, -1.5708, 0], "depth": 0.03,
                     "profile": {"polygon": [[-1.2, 1.94], [-1.62, 1.82], [-1.2, 1.67]]}}}]}
    if enemy:
        s["materials"] = dict(MAT, pennon=ENEMY_PENNON)
    s["animations"] = {
        "idle": {"frames": 1, "ms": 200, "channels": {}},
        "walk": {"frames": 8, "ms": 110, "channels": {"wheel": "-p/6"}},
        # after the shot: the string and the arms forward, no bolt, the winch turning (looped)
        "reload": {"frames": 6, "ms": 140, "channels": {"draw": 0.0, "nutz": 0.86, "bolt": 0.0, "crank": "-p/4"}},
    }
    return s


SPECS = {"ram": lambda: ram("ram"), "ram_enemy": lambda: ram("ram_enemy", True),
         "ballista": lambda: ballista("ballista"), "ballista_enemy": lambda: ballista("ballista_enemy", True)}


def main():
    names = sys.argv[1:] or list(SPECS)
    for n in names:
        spec = SPECS[n]()
        d = os.path.join(PROPS, n)
        os.makedirs(d, exist_ok=True)
        text = "# Generated by tools/spritekiln/gen_siege.py; edit the script, not this file.\n"
        text += yaml.safe_dump(spec, sort_keys=False, width=140, default_flow_style=None, allow_unicode=True)
        with open(os.path.join(d, n + ".yaml"), "w") as f:
            f.write(text)
        print(os.path.join(d, n + ".yaml"))


if __name__ == "__main__":
    main()
