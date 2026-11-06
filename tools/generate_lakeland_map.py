#!/usr/bin/env python3
"""Draws data/maps/lakeland.png, the 128x128 map of M4b-3 (ROADMAP M4b-3, part 2).

One pixel per tile, coloured like TerrainDef.map_color: a lake in the north-east fed by a
river from the north edge (two fords), a stony hill with rock clusters in the south-west,
forests around the edges and near the town site, meadows, and open grass in the middle
where the town starts (start buildings in data/maps/lakeland.tres). Deterministic: the same
seed always draws the same map.

Usage: python3 tools/generate_lakeland_map.py   (needs Pillow)
"""
import math
import random

from PIL import Image

SIZE = 128
OUT = "data/maps/lakeland.png"

GRASS = (79, 138, 58)
MEADOW = (163, 199, 90)
FOREST = (36, 80, 42)
RIVER = (47, 99, 168)
FORD = (120, 168, 208)
STONY = (153, 143, 128)
STONY_ROCK = (102, 97, 92)
LAKE = (26, 77, 107)

# Kept open: the town site (start buildings) and the way in from the west edge.
TOWN = (50, 64, 76, 88)          # x0, y0, x1, y1
ENTRY_ROAD_Y = 80


def value_noise(seed: int, scale: float):
    rng = random.Random(seed)
    grid = [[rng.random() for _ in range(34)] for _ in range(34)]

    def smooth(t: float) -> float:
        return t * t * (3 - 2 * t)

    def at(x: float, y: float) -> float:
        gx, gy = x / scale, y / scale
        ix, iy = int(gx), int(gy)
        fx, fy = smooth(gx - ix), smooth(gy - iy)
        a, b = grid[iy][ix], grid[iy][ix + 1]
        c, d = grid[iy + 1][ix], grid[iy + 1][ix + 1]
        return (a + (b - a) * fx) * (1 - fy) + (c + (d - c) * fx) * fy
    return at


def in_town(x: int, y: int, margin: int = 0) -> bool:
    x0, y0, x1, y1 = TOWN
    return x0 - margin <= x < x1 + margin and y0 - margin <= y < y1 + margin


def main() -> None:
    warp = value_noise(11, 8.0)
    patches = value_noise(23, 10.0)
    woods = value_noise(37, 12.0)
    img = [[GRASS for _ in range(SIZE)] for _ in range(SIZE)]

    def put(x: int, y: int, colour) -> None:
        if 0 <= x < SIZE and 0 <= y < SIZE:
            img[y][x] = colour

    # Meadows: soft patches over the grass.
    for y in range(SIZE):
        for x in range(SIZE):
            if patches(x, y) > 0.66:
                img[y][x] = MEADOW

    # Forests: along the edges (stronger near them) and one grove west of the town.
    for y in range(SIZE):
        for x in range(SIZE):
            edge = min(x, y, SIZE - 1 - x, SIZE - 1 - y)
            w = woods(x, y) + max(0.0, (14 - edge) / 30.0)
            grove = math.hypot(x - 40, y - 70) < 9 + 4 * warp(x, y)
            if (w > 0.72 or grove) and not in_town(x, y, 4):
                img[y][x] = FOREST

    # Stony hill in the south-west with rock clusters near its top.
    hill = (30, 102)
    for y in range(SIZE):
        for x in range(SIZE):
            r = math.hypot(x - hill[0], (y - hill[1]) * 1.2)
            if r < 15 + 6 * (warp(x + 50, y) - 0.5) * 2:
                img[y][x] = STONY
    rng = random.Random(5)
    for _ in range(9):
        cx = hill[0] + rng.randint(-9, 9)
        cy = hill[1] + rng.randint(-7, 7)
        w, h = rng.randint(2, 4), rng.randint(2, 4)
        for y in range(cy, cy + h):
            for x in range(cx, cx + w):
                if img[y][x] == STONY:
                    img[y][x] = STONY_ROCK
    # A few rocks closer to the town, for the first quarry.
    for y in range(92, 95):
        for x in range(58, 62):
            img[y][x] = STONY_ROCK
    for y in range(90, 97):
        for x in range(56, 64):
            if img[y][x] != STONY_ROCK:
                img[y][x] = STONY

    # The lake: a warped ellipse in the north-east.
    lake = (90, 40)
    for y in range(SIZE):
        for x in range(SIZE):
            dx, dy = (x - lake[0]) / 20.0, (y - lake[1]) / 15.0
            r = math.hypot(dx, dy) + (warp(x, y + 60) - 0.5) * 0.45
            if r < 1.0:
                img[y][x] = LAKE

    # The river: from the north edge down and east into the lake, 3 tiles wide.
    points = []
    for i in range(0, 101):
        t = i / 100.0
        x = 30 + 7 * math.sin(t * 9.0) + 42 * t ** 1.4
        y = t * 44
        points.append((x, y))
    for (x, y) in points:
        for oy in range(-1, 2):
            for ox in range(-1, 2):
                px, py = int(round(x)) + ox, int(round(y)) + oy
                if 0 <= px < SIZE and 0 <= py < SIZE and img[py][px] != LAKE:
                    img[py][px] = RIVER
    # Two fords across the river.
    for (fx, fy) in [points[30], points[70]]:
        for oy in range(-2, 3):
            for ox in range(-2, 3):
                px, py = int(round(fx)) + ox, int(round(fy)) + oy
                if img[py][px] == RIVER:
                    img[py][px] = FORD

    # Keep the way in from the west edge and the town site open.
    for x in range(0, TOWN[0]):
        for y in range(ENTRY_ROAD_Y - 1, ENTRY_ROAD_Y + 2):
            if img[y][x] in (FOREST, STONY, STONY_ROCK):
                img[y][x] = GRASS
    for y in range(TOWN[1], TOWN[3]):
        for x in range(TOWN[0], TOWN[2]):
            img[y][x] = GRASS

    out = Image.new("RGB", (SIZE, SIZE))
    for y in range(SIZE):
        for x in range(SIZE):
            out.putpixel((x, y), img[y][x])
    out.save(OUT)
    print("written", OUT)


if __name__ == "__main__":
    main()
