#!/usr/bin/env python3
"""Writes the hand-made M6 world (ROADMAP M6, part 1): data/provinces/*.tres and
data/worlds/kingdom.tres. Borders share their corner points, so neighbouring provinces meet
exactly on the world map. Run from the project root: python3 tools/generate_world_data.py"""
import math, os

# Shared border points on the 1200x800 parchment: the coast (C), and the inland lines (I, J).
P = {
    "C0": (430, 60), "C1": (398, 180), "C2": (440, 300), "C3": (408, 410), "C4": (452, 520),
    "C5": (418, 640), "C6": (446, 760),
    "I0": (640, 60), "I1": (662, 170), "I2": (630, 282), "I3": (652, 410), "I4": (622, 540),
    "I5": (652, 652), "I6": (640, 760),
    "J2": (872, 284), "J3": (892, 410), "J4": (878, 540), "J5": (858, 652), "J6": (880, 760),
    "M": (1010, 302), "T": (1150, 60), "R2": (1150, 282), "R6": (1150, 760),
}


def island(cx, cy, rx, ry, seed):
    pts = []
    for i in range(12):
        a = i / 12 * math.tau
        r = 1.0 + 0.16 * math.sin(a * 3 + seed) + 0.08 * math.cos(a * 5 + seed * 2)
        pts.append((round(cx + math.cos(a) * rx * r), round(cy + math.sin(a) * ry * r)))
    return pts


PROVINCES = [
    # id, template, mirrored, richness, rare, owner, neighbours, coastal, island, pos, outline
    ("landing_bay", "coast", False, 2, "", "", ["amber_coast", "willow_vale", "horse_haven"], True, False,
     (530, 410), ["C2", "I2", "I3", "I4", "C4", "C3"]),
    ("amber_coast", "coast", True, 2, "", "", ["landing_bay", "mirror_lakes"], True, False,
     (535, 180), ["C0", "I0", "I1", "I2", "C2", "C1"]),
    ("willow_vale", "riverlands", False, 3, "", "", ["landing_bay", "mirror_lakes", "iron_wold", "vine_hills"], False, False,
     (760, 410), ["I2", "J2", "J3", "J4", "I4", "I3"]),
    ("mirror_lakes", "lakeland", False, 2, "", "", ["amber_coast", "willow_vale", "iron_wold"], False, False,
     (900, 170), ["I0", "T", "R2", "M", "J2", "I2", "I1"]),
    ("vine_hills", "riverlands", True, 2, "vines", "", ["horse_haven", "willow_vale", "iron_wold"], False, False,
     (760, 650), ["I4", "J4", "J5", "J6", "I6", "I5"]),
    ("gull_isle", "islands", False, 2, "vines", "", [], True, True, (220, 250), island(220, 250, 105, 95, 1.0)),
    ("salt_isle", "islands", True, 1, "salt", "", [], True, True, (240, 585), island(240, 585, 95, 85, 2.5)),
    ("iron_wold", "lakeland", False, 2, "iron_ore", "neutral", ["mirror_lakes", "willow_vale", "vine_hills"], False, False,
     (1020, 520), ["J2", "M", "R2", "R6", "J6", "J5", "J4", "J3"]),
    ("horse_haven", "coast", True, 2, "horses", "neutral", ["landing_bay", "vine_hills"], True, False,
     (540, 645), ["C4", "I4", "I5", "I6", "C6", "C5"]),
]


def sname_array(items):
    return "Array[StringName]([%s])" % ", ".join('&"%s"' % i for i in items)


def main():
    os.makedirs("data/provinces", exist_ok=True)
    os.makedirs("data/worlds", exist_ok=True)
    for (pid, template, mirrored, rich, rare, owner, neigh, coastal, isl, pos, outline) in PROVINCES:
        pts = [P[p] if isinstance(p, str) else p for p in outline]
        flat = ", ".join("%d, %d" % pt for pt in pts)
        with open("data/provinces/%s.tres" % pid, "w") as f:
            f.write('[gd_resource type="Resource" script_class="ProvinceDef" format=3]\n\n')
            f.write('[ext_resource type="Script" path="res://src/defs/province_def.gd" id="1_province"]\n\n')
            f.write("[resource]\nscript = ExtResource(\"1_province\")\n")
            f.write('template = &"%s"\n' % template)
            if mirrored:
                f.write("mirrored = true\n")
            f.write("richness = %d\n" % rich)
            if rare:
                f.write('rare_resource = &"%s"\n' % rare)
            if owner:
                f.write('owner = &"%s"\n' % owner)
            f.write("neighbours = %s\n" % sname_array(neigh))
            if coastal:
                f.write("coastal = true\n")
            if isl:
                f.write("island = true\n")
            f.write("world_pos = Vector2(%d, %d)\n" % pos)
            f.write("outline = PackedVector2Array(%s)\n" % flat)
            f.write('id = &"%s"\n' % pid)
    with open("data/worlds/kingdom.tres", "w") as f:
        f.write('[gd_resource type="Resource" script_class="WorldDef" format=3]\n\n')
        f.write('[ext_resource type="Script" path="res://src/defs/world_def.gd" id="1_world"]\n\n')
        f.write("[resource]\nscript = ExtResource(\"1_world\")\n")
        f.write("provinces = %s\n" % sname_array([p[0] for p in PROVINCES]))
        f.write('start_province = &"landing_bay"\n')
        f.write("size = Vector2(1200, 800)\n")
        f.write("ship_speed = 1.3\n")
        f.write("wagon_speed = 1.4\n")
        f.write('id = &"kingdom"\n')


if __name__ == "__main__":
    main()
