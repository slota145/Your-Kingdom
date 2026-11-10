"""Porters' hut (E1 part 1, 2x2) from the pigsty spec: the same plot, hut, roof and lean-to
(art/specs/props/pigsty/pigsty.yaml is the hand-written base); instead of the pig's yard a
handcart, crates, barrels and sacks waiting to be carried, a carrying frame by the door.
The porters' house (3x3) is hand-written: art/specs/props/porters_house/porters_house.yaml.
Writes art/specs/props/porters_hut/porters_hut.yaml; edit this script, not that file.

Run (inside tools/spritekiln): python3 gen_porters.py, then
  cd art/specs/props/porters_hut && spritekiln render porters_hut.yaml
  python3 tools/spritekiln/export_building.py porters_hut     (from the repository root)
"""
import os

from gen_farms import add_parts, drop, part_block

HERE = os.path.dirname(os.path.abspath(__file__))
BASE = os.path.join(HERE, "art", "specs", "props", "pigsty", "pigsty.yaml")

# A two-wheeled handcart, crates and barrels: shared with the house (written there by hand).
YARD = """  cart_box:          # the handcart in the yard, handles towards the door
    material: plank
    prims:
      - box: {c: [1.1, 0.42, 1.25], half: [0.34, 0.14, 0.5]}
    cut:
      - box: {c: [1.1, 0.52, 1.25], half: [0.28, 0.12, 0.44]}
    paint:
      - material: ink
        stripes: {axis: y, at: [0.42], width: 0.055}
  cart_load:         # two sacks in the cart
    material: sack
    blend: 0.04
    prims:
      - ellipsoid: {c: [1.1, 0.58, 1.05], r: [0.24, 0.17, 0.2]}
      - ellipsoid: {c: [1.08, 0.6, 1.45], r: [0.22, 0.16, 0.2]}
  cart_handles:
    material: post
    priority: 2
    prims:
      - cylinder: {a: [0.82, 0.42, 1.7], b: [0.82, 0.12, 2.25], r: 0.04}
      - cylinder: {a: [1.38, 0.42, 1.7], b: [1.38, 0.12, 2.25], r: 0.04}
  cart_wheels:
    material: post
    prims:
      - cylinder: {a: [0.70, 0.3, 1.2], b: [0.64, 0.3, 1.2], r: 0.3}
      - cylinder: {a: [1.50, 0.3, 1.2], b: [1.56, 0.3, 1.2], r: 0.3}
    paint:
      - material: steel
        rings: {axis: x, at: [0.0], width: 0.055}
  crates:            # crates stacked by the lean-to
    material: plank
    prims:
      - box: {c: [-1.55, 0.22, 0.75], half: [0.24, 0.22, 0.24]}
      - box: {c: [-1.95, 0.22, 1.1], half: [0.22, 0.22, 0.22]}
      - box: {c: [-1.6, 0.62, 0.78], half: [0.2, 0.18, 0.2], rot: [0, 0.3, 0]}
    paint:
      - material: ink
        stripes: {axis: y, period: 0.15, width: 0.055}
  barrels:           # barrels under the lean-to
    material: plank
    prims:
      - cylinder: {a: [-1.62, 0.0, -1.4], b: [-1.62, 0.55, -1.4], r: 0.26, round: 0.04}
      - cylinder: {a: [-1.68, 0.0, -0.8], b: [-1.68, 0.5, -0.8], r: 0.24, round: 0.04}
    paint:
      - material: steel
        rings: {axis: y, period: 0.24, width: 0.055}
  frame:             # a porter's carrying frame leaning by the door
    material: post
    priority: 2
    prims:
      - cylinder: {a: [0.22, 0.0, 0.3], b: [0.12, 1.25, 0.08], r: 0.035}
      - cylinder: {a: [0.52, 0.0, 0.3], b: [0.42, 1.25, 0.08], r: 0.035}
      - box: {c: [0.32, 0.55, 0.22], half: [0.17, 0.03, 0.03]}
      - box: {c: [0.28, 0.95, 0.14], half: [0.17, 0.03, 0.03]}
"""


def porters_hut(base):
    s = base.replace("name: pigsty", "name: porters_hut")
    s = s.replace("Your Kingdom pigsty (Z1), 2x2 tiles, no pen of its own (the pens are tiles beside it): a plank hut with a thick thatched gable roof on the back half, the door in the wall facing the lower right, an open lean-to with hay bales and sacks, a trough with slop, feed baskets, a bucket and a pitchfork in the muddy yard",
                  "Your Kingdom porters' hut (E1), 2x2 tiles: a plank hut with a thick thatched gable roof on the back half, the door in the wall facing the lower right, an open lean-to with barrels and sacks, crates by it, a two-wheeled handcart loaded with sacks in the trodden yard and a carrying frame leaning by the door")
    s = drop(s, ["trough", "slop", "puddle", "bucket", "fork_haft", "fork_tines", "hay", "baskets", "feed"])
    return add_parts(s, YARD)


def main():
    base = open(BASE).read()
    d = os.path.join(HERE, "art", "specs", "props", "porters_hut")
    os.makedirs(d, exist_ok=True)
    with open(os.path.join(d, "porters_hut.yaml"), "w") as f:
        f.write(porters_hut(base))
    print("written porters_hut")


if __name__ == "__main__":
    main()
