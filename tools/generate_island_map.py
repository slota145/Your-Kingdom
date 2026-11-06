#!/usr/bin/env python3
"""Draws data/maps/islands.png, the 128x128 "Islands" map of M6 (ROADMAP M6, part 2).

One pixel per tile, coloured like TerrainDef.map_color: one large island with a sheltered
bay on its south-east shore (the bottom of the screen, so piers and slipways face the camera)
and a beach west of it where settlers land, and two small islands. Shores run along the grid
axes with steps every few tiles (like the "Coast"), a sandy beach, a band of shallow water
2-3 tiles wide and deep water beyond. Forests and meadows inland, a stony hill with rocks in
the north-west of the large island, fish shoals out at sea. Reached only by ship (the map has
no land edge). Deterministic: the same seed always draws the same map.

Usage: python3 tools/generate_island_map.py   (needs Pillow); prints the landing tiles for
data/maps/islands.tres.
"""
import math
import random
import sys
import os

sys.path.insert(0, os.path.dirname(__file__))
from generate_coast_map import (value_noise, GRASS, MEADOW, FOREST, STONY, STONY_ROCK, SAND,  # noqa: E402
                                SHALLOW, SHALLOW_SHOAL, DEEP, DEEP_SHOAL)

SIZE = 128
OUT = "data/maps/islands.png"

# The large island: a box with stepped sides and cut corners; the bay reaches north into it
# from its south side.
ISLAND = (18, 14, 100, 92)       # x0, y0, x1, y1
CORNER = 16                      # how much each corner is cut (taxicab)
BAY_X = (64, 76)
BAY_HEAD_Y = 74
SMALL = [(110, 28, 9), (30, 113, 7)]   # centre x, y, half size
SHOALS = [(70, 104), (88, 110), (40, 106), (8, 60), (110, 70), (120, 98), (60, 4), (100, 118),
          (6, 20), (116, 50)]


def distance_field(is_source) -> list:
    from collections import deque
    dist = [[10 ** 6] * SIZE for _ in range(SIZE)]
    queue = deque()
    for y in range(SIZE):
        for x in range(SIZE):
            if is_source(x, y):
                dist[y][x] = 0
                queue.append((x, y))
    while queue:
        x, y = queue.popleft()
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                nx, ny = x + dx, y + dy
                if 0 <= nx < SIZE and 0 <= ny < SIZE and dist[ny][nx] > dist[y][x] + 1:
                    dist[ny][nx] = dist[y][x] + 1
                    queue.append((nx, ny))
    return dist


def main() -> None:
    steps = random.Random(83)

    def stepped(length: int) -> list:
        offsets, value = [], 0
        while len(offsets) < length:
            run = steps.randint(5, 9)
            value = max(-2, min(2, value + steps.choice((-1, 0, 1))))
            offsets.extend([value] * run)
        return offsets[:length]

    west, east, north, south = stepped(SIZE), stepped(SIZE), stepped(SIZE), stepped(SIZE)
    bay_west = stepped(SIZE)
    x0, y0, x1, y1 = ISLAND
    land = [[False] * SIZE for _ in range(SIZE)]
    for y in range(SIZE):
        for x in range(SIZE):
            inside = x0 + west[y] <= x <= x1 + east[y] and y0 + north[x] <= y <= y1 + south[x]
            cut = min(x - x0, x1 - x) + min(y - y0, y1 - y) < CORNER
            bay = BAY_X[0] + bay_west[y] <= x <= BAY_X[1] and y >= BAY_HEAD_Y
            if inside and not cut and not bay:
                land[y][x] = True
            for (cx, cy, h) in SMALL:
                if abs(x - cx) <= h + west[y] // 2 and abs(y - cy) <= h + north[x] // 2 \
                        and abs(x - cx) + abs(y - cy) < h * 1.6:
                    land[y][x] = True

    patches = value_noise(29, 10.0)
    woods = value_noise(41, 12.0)
    warp = value_noise(13, 8.0)
    shore = value_noise(53, 6.0)
    img = [[GRASS for _ in range(SIZE)] for _ in range(SIZE)]
    to_sea = distance_field(lambda x, y: not land[y][x])
    for y in range(SIZE):
        for x in range(SIZE):
            if not land[y][x]:
                continue
            if patches(x, y) > 0.64:
                img[y][x] = MEADOW
            if woods(x, y) > 0.62 and to_sea[y][x] > 4 and math.hypot(x - 58, y - 64) > 12:
                img[y][x] = FOREST
    # Stony hill with rocks in the north-west of the large island.
    hill = (38, 32)
    for y in range(SIZE):
        for x in range(SIZE):
            if land[y][x] and math.hypot(x - hill[0], (y - hill[1]) * 1.2) < 10 + 5 * (warp(x, y) - 0.5) * 2:
                img[y][x] = STONY
    rng = random.Random(11)
    for _ in range(7):
        cx, cy = hill[0] + rng.randint(-6, 6), hill[1] + rng.randint(-5, 5)
        for y in range(cy, cy + rng.randint(2, 3)):
            for x in range(cx, cx + rng.randint(2, 3)):
                if img[y][x] == STONY:
                    img[y][x] = STONY_ROCK
    # Beach, shallow shelf, deep water.
    for y in range(SIZE):
        for x in range(SIZE):
            if land[y][x] and to_sea[y][x] <= 2 + (shore(x + 40, y) > 0.6):
                img[y][x] = SAND
    to_land = distance_field(lambda x, y: land[y][x])
    for y in range(SIZE):
        for x in range(SIZE):
            if not land[y][x]:
                shelf = 2 + (shore(x, y + 40) > 0.55)
                img[y][x] = SHALLOW if to_land[y][x] <= shelf else DEEP
    for (x, y) in SHOALS:
        if land[y][x] or to_land[y][x] < 2:
            raise SystemExit("shoal %s is not out at sea" % ((x, y),))
        img[y][x] = SHALLOW_SHOAL if img[y][x] == SHALLOW else DEEP_SHOAL
    # The landing: the south shore west of the bay; the beach tile is the first sand tile from
    # the sea, the anchorage the first deep tile 3 tiles beyond the shallows.
    lx = 46
    beach = None
    for y in range(SIZE - 1, 0, -1):
        if land[y][lx]:
            beach = (lx, y)
            break
    anchor = None
    for y in range(beach[1] + 1, SIZE):
        if img[y][lx] == DEEP and to_land[y][lx] >= 5:
            anchor = (lx, y)
            break
    out = Image.new("RGB", (SIZE, SIZE))
    for y in range(SIZE):
        for x in range(SIZE):
            out.putpixel((x, y), img[y][x])
    out.save(OUT)
    print("written", OUT, "beach", beach, "anchor", anchor)


from PIL import Image  # noqa: E402

if __name__ == "__main__":
    main()
