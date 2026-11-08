#!/usr/bin/env python3
"""Builds the stacks of goods from one piece of each good drawn by PixelLab (G2, owner's
decision 2026-11-07): the stack grows by one piece for every piece in store.

Pieces: tools/pixellab_src/goods/<good>.png (Pixen, 24x24, no ground). Their colours are
evened out with the buildings' tool (tools/harmonize_pixellab.py: materials pulled to the
set's hues, greys warmed; brightness kept, so white flour stays white).

Output: assets/goods/stacks/<good>.png, a sheet of stack_size frames side by side, frame
FRAME_W x FRAME_H, frame k (0-based) showing k + 1 pieces. The tile diamond lies in the
bottom 32 px of a frame, its centre at (FRAME_W / 2, FRAME_H - 16) (ART_SPEC §8).

Layouts are designed by hand per good (LAYOUTS): layers of pieces in a grid on the tile
(tile units, centre 0), each layer lifted by part of a piece's height and shifted half a
step so it rests in the gaps below. Pieces are laid layer by layer, from the back to the
front, so every new piece is in sight; they are drawn back to front.

Run: python3 tools/compose_pixellab_stacks.py [<good>...]  (needs Pillow). The number of
frames must match the good's stack_size in data/goods/<good>.tres (checked here and by
test_goods_stack_sheets)."""
import os
import re
import sys
import tempfile

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from brighten_pixellab import brighten  # noqa: E402
from harmonize_pixellab import harmonize  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tools", "pixellab_src", "goods")
OUT = os.path.join(ROOT, "assets", "goods", "stacks")
DATA = os.path.join(ROOT, "data", "goods")
FRAME_W = 64
FRAME_H = 96

# Layout kinds: (layers as (columns along x, rows along y), step in tiles, lift as a part
# of the piece height). A layer with one row is a row of pieces lying along y (logs).
PILE = ([(3, 3), (3, 3), (2, 1)], 0.27, 0.5)          # 20: sacks, baskets, blocks
PILE_LOW = ([(3, 3), (3, 3), (2, 1)], 0.27, 0.35)     # 20: flat things (hides, clothes)
BARRELS = ([(3, 2), (2, 2), (2, 1)], 0.3, 0.72)       # 12: barrels standing on barrels
BOLTS = ([(3, 3), (2, 2), (2, 1), (1, 1)], 0.27, 0.45)  # 16: rolls of cloth
SHEAVES = ([(4, 3), (3, 2), (2, 1)], 0.22, 0.45)      # 20: upright sheaves
LOGS = ([(6, 1), (5, 1), (4, 1), (3, 1), (2, 1)], 0.13, 0.3)   # 20: a pyramid of logs
# 20 boards crosswise (owner 2026-11-07): the board as drawn lies along x; a layer of them
# side by side over the whole tile, the next one across (mirrored, along y), then along x
# again. A layer here is (columns, rows, step along x, step along y, mirrored).
PLANKS = ([(2, 4, 0.5, 0.2, False), (4, 2, 0.2, 0.5, True), (2, 2, 0.5, 0.2, False)], 0.0, 0.3)

# 20 bows in neat rows, all the same way (crosswise they tangle).
BOWS = ([(2, 4, 0.5, 0.2, False), (2, 4, 0.5, 0.2, False), (2, 2, 0.5, 0.2, False)], 0.0, 0.35)

# Pieces drawn darker than the old stacks: brightened by this gamma (lower = brighter).
GAMMA = {"stone": 0.6}

LAYOUTS = {
    "wood": LOGS, "planks": PLANKS, "stone": PILE, "bricks": PILE, "clay": PILE,
    "flour": PILE, "grain": SHEAVES, "bread": PILE, "fish": PILE, "grapes": PILE,
    "meat": PILE, "hides": PILE_LOW, "wool": PILE, "cloth": BOLTS, "clothes": PILE_LOW,
    "hops": PILE, "beer": BARRELS, "wine": BARRELS, "mead": BARRELS, "honey": BARRELS,
    "tar": BARRELS,
}
G2_SET = list(LAYOUTS.keys())
# M7 part 1: metals and weapons (ART_SPEC §10.14); long weapons crosswise like boards.
LAYOUTS.update({
    "charcoal": PILE, "iron_ore": PILE, "iron": PILE_LOW, "chainmail": PILE_LOW,
    "spear": PLANKS, "sword": PLANKS, "bow": BOWS,
})
# J1 part 1: the new weapons, their pieces drawn by code (tools/draw_weapon_pieces.py).
LAYOUTS.update({"halberd": PLANKS, "crossbow": BOWS, "morning_star": PILE})


def stack_size(good):
    text = open(os.path.join(DATA, good + ".tres")).read()
    return int(re.search(r"stack_size = (\d+)", text).group(1))


def spots(layout, count, piece_h):
    """[(layer, gx, gy, lift px)] in the order pieces are laid down."""
    layers, step, lift = layout
    result = []
    for layer, spec in enumerate(layers):
        nx, ny = spec[0], spec[1]
        sx, sy = (spec[2], spec[3]) if len(spec) > 2 else (step, step)
        mirrored = len(spec) > 4 and spec[4]
        cells = []
        for i in range(nx):
            for j in range(ny):
                gx = (i - (nx - 1) / 2.0) * sx
                gy = (j - (ny - 1) / 2.0) * sy
                cells.append((gx + gy, gx - gy, gx, gy))
        for _depth, _side, gx, gy in sorted(cells):      # back to front
            result.append((layer, gx, gy, round(layer * lift * piece_h), mirrored))
    if len(result) < count:
        raise SystemExit("layout too small: %d spots for %d pieces" % (len(result), count))
    return result[:count]


def sheet(piece, count, layout):
    piece = piece.crop(piece.getbbox())
    flipped = piece.transpose(Image.FLIP_LEFT_RIGHT)
    places = spots(layout, count, piece.height)
    out = Image.new("RGBA", (FRAME_W * count, FRAME_H), (0, 0, 0, 0))
    for k in range(count):
        frame = Image.new("RGBA", (FRAME_W, FRAME_H), (0, 0, 0, 0))
        laid = places[:k + 1]
        for layer, gx, gy, lift, mirrored in sorted(laid, key=lambda p: (p[0], p[1] + p[2], p[1] - p[2])):
            fx = FRAME_W / 2 + (gx - gy) * 32
            fy = FRAME_H - 16 + (gx + gy) * 16 - lift
            img = flipped if mirrored else piece
            frame.alpha_composite(img, (round(fx - img.width / 2), round(fy - img.height + 3)))
        out.paste(frame, (FRAME_W * k, 0))
    return out


def main():
    only = sys.argv[1:]
    tmp = tempfile.mkdtemp(prefix="goods_")
    groups = {g: [(os.path.join(SRC, g + ".png"), os.path.join(tmp, g + ".png"))] for g in LAYOUTS}
    # The common colours are those of the accepted G2 set (M7: new goods join it).
    harmonize(groups, value_strength=0.0, reference=lambda name: name in G2_SET)
    for good, layout in LAYOUTS.items():
        if only and good not in only:
            continue
        count = stack_size(good)
        piece = Image.open(os.path.join(tmp, good + ".png")).convert("RGBA")
        if good in GAMMA:
            piece = brighten(piece, GAMMA[good], 1.0)
        sheet(piece, count, layout).save(
            os.path.join(OUT, good + ".png"))
        print(good, count)


if __name__ == "__main__":
    main()
