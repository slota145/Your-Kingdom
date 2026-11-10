"""Sheep farm, stud farm (Z1 part 2) and apiary (part 3) from the pigsty spec: the same 2x2 plot, hut, roof and
lean-to (art/specs/props/pigsty/pigsty.yaml is the hand-written base), other walls, roof and
props. Writes art/specs/props/<id>/<id>.yaml; edit this script, not those files.

Run (inside tools/spritekiln): python3 gen_farms.py, then for each:
  cd art/specs/props/<id> && spritekiln render <id>.yaml
  python3 tools/spritekiln/export_building.py <id>     (from the repository root)
"""
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
BASE = os.path.join(HERE, "art", "specs", "props", "pigsty", "pigsty.yaml")


def part_block(text, name):
    """(start, end) of the part `name` in the parts: section (up to the next part)."""
    m = re.compile(r"\n  %s:[ \n]" % re.escape(name)).search(text, text.index("\nparts:"))
    a = m.start() + 1
    b = a + 1
    while True:
        nl = text.index("\n", b)
        line = text[nl + 1:text.index("\n", nl + 1)]
        if re.match(r"^  [a-z_]+:( |$)", line) or not line.startswith(" "):
            return a, nl + 1
        b = nl + 1


def drop(text, names):
    for n in names:
        a, b = part_block(text, n)
        text = text[:a] + text[b:]
    return text


def add_parts(text, block):
    i = text.index("\nanimations:")
    return text[:i] + "\n" + block.rstrip("\n") + "\n" + text[i:]


def sheep_farm(base):
    s = base.replace("name: pigsty", "name: sheep_farm")
    s = s.replace("Your Kingdom pigsty (Z1), 2x2 tiles, no pen of its own (the pens are tiles beside it): a plank hut with a thick thatched gable roof on the back half, the door in the wall facing the lower right, an open lean-to with hay bales and sacks, a trough with slop, feed baskets, a bucket and a pitchfork in the muddy yard",
                  "Your Kingdom sheep farm (Z1 part 2), 2x2 tiles, the flock in pens beside it: a whitewashed wattle-and-daub hut in a dark timber frame with a thatched roof, an open shearing shed with wool sacks and a shearing bench, a hay rack, a basket of fleece and a shepherd's crook in a grassy yard")
    s = s.replace("  board: {ramp: log, bands: [2, 5]}", "  board: {ramp: plaster_cream, bands: [2, 5]}\n  wool: {ramp: wool, bands: [2, 5]}\n  grass: {ramp: grass, outline: false}")
    s = s.replace("  wicker: ['#1a1006', '#4a3216', '#74522a', '#9a7038', '#be9250']",
                  "  wicker: ['#1a1006', '#4a3216', '#74522a', '#9a7038', '#be9250']\n  wool:   ['#2a241c', '#6e6452', '#a39784', '#c8bea8', '#e2dac6', '#f4efe2']\n  grass:  ['#14200c', '#26381a', '#34481e', '#3e5424', '#4a602a']")
    s = s.replace("palette: ../../palettes/kingdom.yaml", "palette: [../../palettes/kingdom.yaml, ../../palettes/town.yaml]")
    # Daub walls between timbers: no board lines; the timber frame is the posts plus braces.
    a, b = part_block(s, "walls")
    s = s[:a] + """  walls:             # whitewashed daub
    material: board
    prims:
      - box: {c: [0.42, 1.05, -1.0], half: [1.55, 0.92, 0.97]}
""" + s[b:]
    s = drop(s, ["trough", "slop", "puddle", "bucket", "fork_haft", "fork_tines", "hay", "sacks", "baskets", "feed"])
    s = add_parts(s, """  braces:            # the dark timber frame in the daub
    material: post
    prims:
      - box: {c: [0.42, 1.05, 0.0], half: [0.06, 0.92, 0.05]}
      - box: {c: [1.2, 1.05, 0.0], half: [0.86, 0.05, 0.05], rot: [0, 0, 0.75]}
      - box: {c: [0.42, 1.05, -2.0], half: [0.06, 0.92, 0.05]}
  grass_patches:
    material: grass
    prims:
      - ellipsoid: {c: [0.9, 0.014, 1.55], r: [0.35, 0.013, 0.22]}
      - ellipsoid: {c: [-0.4, 0.014, 1.85], r: [0.28, 0.013, 0.18]}
  wool_sacks:        # stuffed sacks of fleece under the shed
    material: wool
    blend: 0.05
    prims:
      - ellipsoid: {c: [-1.6, 0.3, -1.4], r: [0.3, 0.32, 0.3]}
      - ellipsoid: {c: [-1.6, 0.28, -0.8], r: [0.28, 0.3, 0.27]}
      - ellipsoid: {c: [-1.85, 0.62, -1.15], r: [0.24, 0.24, 0.24]}
    paint:
      - material: ink
        stripes: {axis: y, at: [0.55], width: 0.055}
  bench:             # the shearing bench in the shed
    material: plank
    prims:
      - box: {c: [-1.6, 0.36, -0.2], half: [0.3, 0.05, 0.2]}
      - box: {c: [-1.85, 0.17, -0.2], half: [0.04, 0.17, 0.16]}
      - box: {c: [-1.35, 0.17, -0.2], half: [0.04, 0.17, 0.16]}
  fleece:            # a basket of fresh fleece by the door
    material: wicker
    prims:
      - cylinder: {a: [-1.45, 0.0, 0.65], b: [-1.45, 0.24, 0.65], r: 0.26}
    paint:
      - material: ink
        rings: {axis: y, period: 0.09, width: 0.055}
  fleece_top:
    material: wool
    prims:
      - ellipsoid: {c: [-1.45, 0.27, 0.65], r: [0.24, 0.1, 0.24]}
  hay_rack:          # a hay rack against the wall, right of the door
    material: post
    prims:
      - box: {c: [1.2, 0.45, 0.35], half: [0.55, 0.04, 0.04]}
      - box: {c: [0.7, 0.3, 0.35], half: [0.04, 0.3, 0.04]}
      - box: {c: [1.7, 0.3, 0.35], half: [0.04, 0.3, 0.04]}
      - box: {c: [1.2, 0.85, 0.15], half: [0.55, 0.04, 0.04]}
  rack_hay:
    material: hay
    blend: 0.04
    prims:
      - ellipsoid: {c: [1.2, 0.68, 0.22], r: [0.5, 0.2, 0.16]}
  crook:             # the shepherd's crook leaning on the wall
    material: post
    priority: 2
    prims:
      - cylinder: {a: [0.25, 0.0, 0.3], b: [0.1, 1.5, 0.06], r: 0.03}
      - torus: {c: [0.04, 1.58, 0.06], R: 0.08, r: 0.025, rot: [0, 0, 1.5708]}
""")
    return s


def stud_farm(base):
    s = base.replace("name: pigsty", "name: stud_farm")
    s = s.replace("Your Kingdom pigsty (Z1), 2x2 tiles, no pen of its own (the pens are tiles beside it): a plank hut with a thick thatched gable roof on the back half, the door in the wall facing the lower right, an open lean-to with hay bales and sacks, a trough with slop, feed baskets, a bucket and a pitchfork in the muddy yard",
                  "Your Kingdom stud farm (Z1 part 2), 2x2 tiles, the horses in pens beside it: a stable of dark planks on a tall stone base with a shingle roof, a wide double door, a hay loft hatch, an open tack shed with a saddle on a rail and hay, a stone water trough and a mounting block in the yard")
    s = s.replace("palette: ../../palettes/kingdom.yaml", "palette: [../../palettes/kingdom.yaml, ../../palettes/town.yaml]")
    s = s.replace("  thatch: {ramp: straw, bands: [1, 5]}\n  thatch_dark: {ramp: straw, bands: [0, 2]}",
                  "  thatch: {ramp: shingle, bands: [1, 5]}\n  thatch_dark: {ramp: shingle, bands: [0, 2]}\n  tack: {ramp: tack, bands: [1, 4]}\n  water: {ramp: water, outline: false}")
    s = s.replace("  wicker: ['#1a1006', '#4a3216', '#74522a', '#9a7038', '#be9250']",
                  "  wicker: ['#1a1006', '#4a3216', '#74522a', '#9a7038', '#be9250']\n  tack:   ['#120a05', '#2e1a0c', '#4a2c16', '#683e20', '#86542c']\n  water:  ['#0a1418', '#1a3440', '#2a5060', '#3e6c80', '#5a8aa0']")
    s = s.replace("  board: {ramp: log, bands: [2, 5]}", "  board: {ramp: timber, bands: [2, 5]}")
    # A taller stone base under the planks.
    a, b = part_block(s, "plinth")
    s = s[:a] + """  plinth:
    material: stone
    prims:
      - box: {c: [0.42, 0.2, -1.0], half: [1.62, 0.2, 1.03], round: 0.02}
    paint:
      - material: ink
        grid: {axes: [x, z], spacing: [0.3, 0.2], r: 0.03}
""" + s[b:]
    # A wide double door instead of the narrow one.
    a, b = part_block(s, "door")
    s = s[:a] + """  door:
    material: plank
    prims:
      - box: {c: [-0.45, 0.9, 0.0], half: [0.52, 0.78, 0.035]}
    paint:
      - material: ink
        stripes: {axis: x, period: 0.17, width: 0.055}
      - material: ink
        stripes: {axis: x, at: [-0.45], width: 0.08}
""" + s[b:]
    a, b = part_block(s, "door_frame")
    s = s[:a] + """  door_frame:
    material: post
    prims:
      - box: {c: [-1.0, 0.95, 0.02], half: [0.06, 0.85, 0.06]}
      - box: {c: [0.1, 0.95, 0.02], half: [0.06, 0.85, 0.06]}
      - box: {c: [-0.45, 1.75, 0.02], half: [0.6, 0.06, 0.06]}
""" + s[b:]
    a, b = part_block(s, "door_bands")
    s = s[:a] + """  door_bands:        # a Z brace on each leaf
    material: post
    prims:
      - box: {c: [-0.71, 0.9, 0.05], half: [0.03, 0.62, 0.012], rot: [0, 0, 0.42]}
      - box: {c: [-0.19, 0.9, 0.05], half: [0.03, 0.62, 0.012], rot: [0, 0, -0.42]}
""" + s[b:]
    s = drop(s, ["window", "shutter", "trough", "slop", "baskets", "feed", "fork_haft", "fork_tines", "sacks"])
    s = add_parts(s, """  loft:              # the hay loft hatch high in the gable, hay sticking out
    material: ink
    prims:
      - box: {c: [2.0, 2.35, -1.0], half: [0.03, 0.22, 0.24]}
  loft_hay:
    material: hay
    prims:
      - ellipsoid: {c: [2.05, 2.2, -1.0], r: [0.1, 0.1, 0.26]}
  rail:              # a rail under the shed with a saddle on it
    material: post
    prims:
      - box: {c: [-1.7, 0.6, -0.45], half: [0.04, 0.04, 0.42]}
      - box: {c: [-1.7, 0.3, -0.85], half: [0.04, 0.3, 0.04]}
      - box: {c: [-1.7, 0.3, -0.05], half: [0.04, 0.3, 0.04]}
  saddle:
    material: tack
    blend: 0.03
    prims:
      - ellipsoid: {c: [-1.7, 0.7, -0.45], r: [0.22, 0.09, 0.26]}
      - ellipsoid: {c: [-1.7, 0.78, -0.25], r: [0.09, 0.07, 0.05]}
  trough:            # a stone water trough in the yard
    material: stone
    prims:
      - box: {c: [1.15, 0.2, 1.15], half: [0.6, 0.2, 0.26], round: 0.03}
    cut:
      - box: {c: [1.15, 0.34, 1.15], half: [0.5, 0.16, 0.17]}
  water:
    material: water
    prims:
      - box: {c: [1.15, 0.3, 1.15], half: [0.5, 0.02, 0.17]}
  block:             # a mounting block by the door
    material: stone
    prims:
      - box: {c: [0.45, 0.14, 0.55], half: [0.2, 0.14, 0.2], round: 0.03}
      - box: {c: [0.45, 0.06, 0.82], half: [0.2, 0.06, 0.1], round: 0.02}
""")
    return s


def apiary(base):
    s = base.replace("name: pigsty", "name: apiary")
    s = s.replace("Your Kingdom pigsty (Z1), 2x2 tiles, no pen of its own (the pens are tiles beside it): a plank hut with a thick thatched gable roof on the back half, the door in the wall facing the lower right, an open lean-to with hay bales and sacks, a trough with slop, feed baskets, a bucket and a pitchfork in the muddy yard",
                  "Your Kingdom apiary (Z1 part 3), 2x2 tiles, the hives on tiles beside it: a small ochre-daubed beekeeper's hut in a dark timber frame with a thatched roof, an open shed with a shelf of spare skeps and honey pots, a bench with jars, a smoker pot, flowers in a grassy yard")
    s = s.replace("palette: ../../palettes/kingdom.yaml", "palette: [../../palettes/kingdom.yaml, ../../palettes/town.yaml]")
    s = s.replace("  board: {ramp: log, bands: [2, 5]}", "  board: {ramp: plaster_ochre, bands: [2, 5]}\n  honey: {ramp: honey, bands: [2, 5], finish: glossy}\n  pot: {ramp: pot, bands: [1, 4]}\n  grass: {ramp: grass, outline: false}\n  flower: {ramp: flower, bands: [3, 4], outline: false}")
    s = s.replace("  wicker: ['#1a1006', '#4a3216', '#74522a', '#9a7038', '#be9250']",
                  "  wicker: ['#1a1006', '#4a3216', '#74522a', '#9a7038', '#be9250']\n  honey:  ['#2a1404', '#6a3a08', '#a8640e', '#d8901c', '#f0b83a', '#fcd870']\n  pot:    ['#1a0e08', '#4a2a18', '#7a4628', '#a6643a', '#c88452']\n  grass:  ['#14200c', '#26381a', '#34481e', '#3e5424', '#4a602a']\n  flower: ['#2a2410', '#8a7a30', '#d8c450', '#f0e070', '#fff4a0']")
    a, b = part_block(s, "walls")
    s = s[:a] + """  walls:             # daub between timbers
    material: board
    prims:
      - box: {c: [0.42, 1.05, -1.0], half: [1.55, 0.92, 0.97]}
""" + s[b:]
    s = drop(s, ["trough", "slop", "puddle", "fork_haft", "fork_tines", "hay", "sacks", "baskets", "feed"])
    s = add_parts(s, """  braces:
    material: post
    prims:
      - box: {c: [0.42, 1.05, 0.0], half: [0.06, 0.92, 0.05]}
      - box: {c: [1.2, 1.05, 0.0], half: [0.86, 0.05, 0.05], rot: [0, 0, -0.75]}
  grass_patches:
    material: grass
    prims:
      - ellipsoid: {c: [0.8, 0.014, 1.4], r: [0.6, 0.013, 0.45]}
      - ellipsoid: {c: [-0.5, 0.014, 1.8], r: [0.4, 0.013, 0.3]}
    paint:
      - material: flower
        spots: {scale: 0.05, density: 0.25, seed: 9}
  shelf:             # a shelf under the shed with spare skeps
    material: plank
    prims:
      - box: {c: [-1.65, 0.5, -1.0], half: [0.32, 0.04, 0.85]}
      - box: {c: [-1.65, 0.25, -1.75], half: [0.04, 0.25, 0.04]}
      - box: {c: [-1.65, 0.25, -0.25], half: [0.04, 0.25, 0.04]}
  spare_skeps:
    material: thatch
    prims:
      - ellipsoid: {c: [-1.65, 0.75, -1.45], r: [0.24, 0.26, 0.24]}
      - ellipsoid: {c: [-1.65, 0.75, -0.85], r: [0.24, 0.26, 0.24]}
    paint:
      - material: thatch_dark
        stripes: {axis: y, period: 0.1, width: 0.055}
  pots:              # honey pots under the shelf
    material: pot
    prims:
      - cylinder: {a: [-1.6, 0.0, -1.2], b: [-1.6, 0.26, -1.2], r: 0.15}
      - cylinder: {a: [-1.65, 0.0, -0.75], b: [-1.65, 0.22, -0.75], r: 0.13}
  bench:             # a bench by the door with jars of honey
    material: plank
    prims:
      - box: {c: [1.15, 0.36, 0.45], half: [0.5, 0.04, 0.16]}
      - box: {c: [0.75, 0.18, 0.45], half: [0.04, 0.18, 0.12]}
      - box: {c: [1.55, 0.18, 0.45], half: [0.04, 0.18, 0.12]}
  jars:
    material: honey
    prims:
      - cylinder: {a: [0.9, 0.4, 0.45], b: [0.9, 0.6, 0.45], r: 0.09}
      - cylinder: {a: [1.15, 0.4, 0.45], b: [1.15, 0.64, 0.45], r: 0.1}
      - cylinder: {a: [1.4, 0.4, 0.45], b: [1.4, 0.58, 0.45], r: 0.08}
  smoker:            # a clay smoker pot by the door
    material: pot
    prims:
      - cylinder: {a: [-1.4, 0.0, 0.7], b: [-1.4, 0.3, 0.7], r: 0.12}
      - cone: {a: [-1.4, 0.3, 0.7], b: [-1.4, 0.42, 0.7], r: [0.1, 0.03]}
""")
    return s


def main():
    base = open(BASE).read()
    for name, make in [("sheep_farm", sheep_farm), ("stud_farm", stud_farm), ("apiary", apiary)]:
        d = os.path.join(HERE, "art", "specs", "props", name)
        os.makedirs(d, exist_ok=True)
        with open(os.path.join(d, name + ".yaml"), "w") as f:
            f.write(make(base))
        print("written", name)


if __name__ == "__main__":
    main()
