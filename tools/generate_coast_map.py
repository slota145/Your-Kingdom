#!/usr/bin/env python3
"""Draws data/maps/coast.png, the 128x128 "Coast" map of M5 (ROADMAP M5, part 1).

One pixel per tile, coloured like TerrainDef.map_color: the sea along the south-east edges
(the bottom of the screen, so piers and slipways face the camera), a sandy beach, a band of
shallow water 2-3 tiles wide and deep water beyond it, a sheltered bay east of the town with
deep water in the middle, a river from the north edge into the bay (two fords), forests along
the edges, a stony hill with rock clusters in the south-west and a few rocks near the town.
Fish shoals are single sea tiles in a slightly lighter colour (TerrainDef.extra_map_color).
Deterministic: the same seed always draws the same map.

Usage: python3 tools/generate_coast_map.py   (needs Pillow)
"""
import math
import random
from collections import deque

from PIL import Image

SIZE = 128
OUT = "data/maps/coast.png"

GRASS = (79, 138, 58)
MEADOW = (163, 199, 90)
FOREST = (36, 80, 42)
RIVER = (47, 99, 168)
FORD = (120, 168, 208)
STONY = (153, 143, 128)
STONY_ROCK = (102, 97, 92)
SAND = (220, 200, 140)
SHALLOW = (70, 140, 190)
SHALLOW_SHOAL = (80, 150, 200)
DEEP = (20, 60, 120)
DEEP_SHOAL = (30, 70, 130)

# Kept open: the town site (start buildings in data/maps/coast.tres) and the way in from the
# west edge.
TOWN = (42, 54, 68, 80)          # x0, y0, x1, y1
ENTRY_ROAD_Y = 66
# Coastlines run along the grid axes (diagonal on screen), with steps every few tiles, so a
# pier or a slipway (a straight row of tiles) finds a straight stretch of shore. The sea lies
# beyond y = SEA_Y along the bottom-left edge and beyond x = EAST_X along the bottom-right
# edge (south of EAST_FROM_Y); the bay reaches north from the sea towards the town.
SEA_Y = 104
EAST_X = 114
EAST_FROM_Y = 58
BAY_X = (71, 84)                 # west and east shore
BAY_HEAD_Y = 72


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


def distance_field(is_source) -> list:
    """Chebyshev-ish BFS distance (8 neighbours) from every source tile."""
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
    warp = value_noise(13, 8.0)
    patches = value_noise(29, 10.0)
    woods = value_noise(41, 12.0)
    shore = value_noise(53, 6.0)
    img = [[GRASS for _ in range(SIZE)] for _ in range(SIZE)]

    # The sea and the bay (decided first: everything else stays on land). Shores step by a
    # tile now and then (segments of 5-9 tiles) instead of wobbling every tile.
    steps = random.Random(61)

    def stepped(length: int) -> list:
        offsets, value = [], 0
        while len(offsets) < length:
            run = steps.randint(5, 9)
            value = max(-2, min(2, value + steps.choice((-1, 0, 1))))
            offsets.extend([value] * run)
        return offsets[:length]

    south = stepped(SIZE)        # by x
    east = stepped(SIZE)         # by y
    bay_west = stepped(SIZE)     # by y
    bay_head = stepped(SIZE)     # by x
    sea = [[False] * SIZE for _ in range(SIZE)]
    for y in range(SIZE):
        for x in range(SIZE):
            if y > SEA_Y + south[x]:
                sea[y][x] = True
            if y >= EAST_FROM_Y + abs(east[0]) and x > EAST_X + east[y]:
                sea[y][x] = True
            if BAY_X[0] + bay_west[y] <= x <= BAY_X[1] and y >= BAY_HEAD_Y + bay_head[x]:
                sea[y][x] = True

    # Meadows and forests (along the edges away from the sea, and a grove west of the town).
    for y in range(SIZE):
        for x in range(SIZE):
            if patches(x, y) > 0.66:
                img[y][x] = MEADOW
            edge = min(x, y)
            w = woods(x, y) + max(0.0, (14 - edge) / 30.0)
            grove = math.hypot(x - 34, y - 46) < 8 + 4 * warp(x, y)
            if (w > 0.72 or grove) and not in_town(x, y, 4):
                img[y][x] = FOREST

    # Stony hill with rock clusters in the south-west, and a few rocks near the town.
    hill = (24, 86)
    for y in range(SIZE):
        for x in range(SIZE):
            r = math.hypot(x - hill[0], (y - hill[1]) * 1.2)
            if r < 14 + 6 * (warp(x + 50, y) - 0.5) * 2:
                img[y][x] = STONY
    rng = random.Random(7)
    for _ in range(9):
        cx = hill[0] + rng.randint(-8, 8)
        cy = hill[1] + rng.randint(-6, 6)
        w, h = rng.randint(2, 4), rng.randint(2, 4)
        for y in range(cy, cy + h):
            for x in range(cx, cx + w):
                if 0 <= x < SIZE and 0 <= y < SIZE and img[y][x] == STONY:
                    img[y][x] = STONY_ROCK
    for y in range(86, 93):
        for x in range(46, 54):
            img[y][x] = STONY
    for y in range(88, 91):
        for x in range(48, 52):
            img[y][x] = STONY_ROCK

    # The river: from the north edge down to the inner end of the bay, 3 tiles wide.
    points = []
    for i in range(0, 101):
        t = i / 100.0
        x = 52 + 5 * math.sin(t * 7.0) + 22 * t ** 1.3
        y = t * 74
        points.append((x, y))
    river = [[False] * SIZE for _ in range(SIZE)]
    for (x, y) in points:
        for oy in range(-1, 2):
            for ox in range(-1, 2):
                px, py = int(round(x)) + ox, int(round(y)) + oy
                if 0 <= px < SIZE and 0 <= py < SIZE and not sea[py][px]:
                    river[py][px] = True
    fords = [[False] * SIZE for _ in range(SIZE)]
    for (fx, fy) in [points[25], points[62]]:
        for oy in range(-2, 3):
            for ox in range(-2, 3):
                px, py = int(round(fx)) + ox, int(round(fy)) + oy
                if river[py][px]:
                    fords[py][px] = True

    # Sandy beach along the sea (not along the river), 2-3 tiles wide.
    to_sea = distance_field(lambda x, y: sea[y][x])
    for y in range(SIZE):
        for x in range(SIZE):
            if not sea[y][x] and not river[y][x] and to_sea[y][x] <= 2 + (shore(x + 40, y) > 0.6):
                img[y][x] = SAND

    # Shallow water within 2-3 tiles of land (river water counts as land: the river mouth
    # is shallow), deep water beyond.
    to_land = distance_field(lambda x, y: not sea[y][x])
    for y in range(SIZE):
        for x in range(SIZE):
            if sea[y][x]:
                shelf = 2 + (shore(x, y + 40) > 0.55)
                img[y][x] = SHALLOW if to_land[y][x] <= shelf else DEEP
            elif fords[y][x]:
                img[y][x] = FORD
            elif river[y][x]:
                img[y][x] = RIVER

    # Fish shoals: single tiles, 2 in the bay and more along the coast, never next to land.
    shoals = [(77, 86), (79, 97), (30, 114), (50, 118), (70, 113), (92, 116),
              (108, 121), (18, 122), (121, 70), (122, 86), (119, 100), (100, 110)]
    for (x, y) in shoals:
        if not sea[y][x] or to_land[y][x] < 2:
            raise SystemExit("shoal %s is not out at sea" % ((x, y),))
        img[y][x] = SHALLOW_SHOAL if img[y][x] == SHALLOW else DEEP_SHOAL

    # Keep the way in from the west edge and the town site open.
    for x in range(0, TOWN[0]):
        for y in range(ENTRY_ROAD_Y - 1, ENTRY_ROAD_Y + 2):
            if img[y][x] in (FOREST, STONY, STONY_ROCK):
                img[y][x] = GRASS
    for y in range(TOWN[1], TOWN[3]):
        for x in range(TOWN[0], TOWN[2]):
            if not sea[y][x] and not river[y][x]:
                img[y][x] = GRASS if img[y][x] != SAND else SAND

    out = Image.new("RGB", (SIZE, SIZE))
    for y in range(SIZE):
        for x in range(SIZE):
            out.putpixel((x, y), img[y][x])
    out.save(OUT)
    print("written", OUT)


if __name__ == "__main__":
    main()
