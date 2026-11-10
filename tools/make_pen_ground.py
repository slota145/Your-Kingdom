"""Ground of animal pens (Z1): trampled earth with mud, straw and tufts of grass on a 64x32 tile.

Writes assets/terrain/pen/ground.png and ground_2.png (two looks, chosen by the tile in TerrainLayer).
Run: python3 tools/make_pen_ground.py, then "$GODOT" --headless --path . --import
"""
import os
import random

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
W, H = 64, 32
EARTH = [(112, 86, 56), (122, 94, 62), (104, 80, 52), (130, 102, 68)]
MUD = [(78, 58, 40), (70, 52, 36), (86, 64, 44)]
GRASS = [(96, 122, 58), (84, 110, 50), (110, 136, 66)]
STRAW = [(206, 176, 98), (186, 156, 84)]


def inside(x, y):
    return abs(x + 0.5 - W / 2) / (W / 2) + abs(y + 0.5 - H / 2) / (H / 2) <= 1.0


def make(seed):
    rnd = random.Random(seed)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()
    for y in range(H):
        for x in range(W):
            if inside(x, y):
                px[x, y] = rnd.choice(EARTH) + (255,)
    # Mud puddles: soft blobs (iso ellipses).
    for _ in range(rnd.randint(2, 3)):
        cx, cy = rnd.randint(18, 46), rnd.randint(10, 22)
        rx, ry = rnd.randint(5, 9), rnd.randint(2, 4)
        for y in range(cy - ry, cy + ry + 1):
            for x in range(cx - rx, cx + rx + 1):
                if 0 <= x < W and 0 <= y < H and inside(x, y) and ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1:
                    px[x, y] = rnd.choice(MUD) + (255,)
    # Grass tufts near the edges (the fence keeps them), straw bits everywhere.
    for _ in range(26):
        x, y = rnd.randint(0, W - 1), rnd.randint(0, H - 1)
        edge = abs(x + 0.5 - W / 2) / (W / 2) + abs(y + 0.5 - H / 2) / (H / 2)
        if inside(x, y) and edge > 0.7:
            px[x, y] = rnd.choice(GRASS) + (255,)
            if y > 0 and inside(x, y - 1):
                px[x, y - 1] = GRASS[2] + (255,)
    for _ in range(14):
        x, y = rnd.randint(0, W - 2), rnd.randint(0, H - 1)
        if inside(x, y) and inside(x + 1, y):
            c = rnd.choice(STRAW) + (255,)
            px[x, y] = c
            px[x + 1, y] = c
    # Hoof prints: darker dots in pairs.
    for _ in range(10):
        x, y = rnd.randint(2, W - 3), rnd.randint(2, H - 3)
        if inside(x, y) and inside(x + 2, y):
            px[x, y] = (88, 66, 44, 255)
            px[x + 2, y] = (88, 66, 44, 255)
    return img


def main():
    out = os.path.join(ROOT, "assets", "terrain", "pen")
    os.makedirs(out, exist_ok=True)
    make(11).save(os.path.join(out, "ground.png"))
    make(23).save(os.path.join(out, "ground_2.png"))
    print("written", out)


if __name__ == "__main__":
    main()
