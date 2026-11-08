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
# W1: open ground between the town site and the landing beach on the bay (no forest there).
BEACH_GROUND = (56, 78, 72, 94)
ENTRY_ROAD_Y = 66
# W1 (owner's request 2026-11-08): natural coastlines of gentle bays and headlands instead of
# straight runs with steps (quays now go in 8 directions, so a pier no longer needs a straight
# shore). The sea lies beyond about y = SEA_Y along the bottom-left edge and beyond about
# x = EAST_X along the bottom-right edge (south of EAST_FROM_Y). The bay is a wide, round
# horseshoe opening to the south: centre BAY_CX, half-width BAY_HALF, its round head at
# BAY_HEAD_Y (about twice as wide and a third shorter than before, owner's survey).
SEA_Y = 104
EAST_X = 114
EAST_FROM_Y = 58
BAY_CX = 81
BAY_HALF = 13
BAY_HEAD_Y = 82
BAY_ROUND = 10                   # how far down from the head the round end reaches


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

    # The sea and the bay (decided first: everything else stays on land). Shores wander in
    # long gentle curves (two scales of noise), with a headland or a cove now and then.
    big = value_noise(61, 22.0)
    small = value_noise(67, 7.0)

    def wander(t: float, other: float) -> float:
        return 12.0 * (big(t, other) - 0.5) + 3.0 * (small(t, other) - 0.5)

    sea = [[False] * SIZE for _ in range(SIZE)]
    for y in range(SIZE):
        for x in range(SIZE):
            if y > SEA_Y + wander(x, 3.0):
                sea[y][x] = True
            # The east coast bends round into the south coast instead of meeting it at a corner.
            east_from = EAST_FROM_Y + 3.0 * wander(y, 40.0) / 7.0
            if y >= east_from and x > EAST_X + wander(y, 80.0) + max(0.0, 6.0 - (y - east_from)) ** 2 / 6.0:
                sea[y][x] = True
            # The bay: a round head, then sides opening slightly towards the sea.
            # A horseshoe with a flat head and round corners (a superellipse): harbour buildings
            # that cannot turn on the water (fishing wharf, shipyard) need a straight shore
            # facing the bay, and find it along the head.
            half = BAY_HALF + 1.6 * (small(x + 30.0, y + 30.0) - 0.5) * 2.0
            centre_y = BAY_HEAD_Y + BAY_ROUND
            if y >= centre_y:
                half *= 1.0 + 0.012 * (y - centre_y)
                inside = abs(x - BAY_CX) <= half
            else:
                inside = abs((x - BAY_CX) / half) ** 2.8 + abs((y - centre_y) / BAY_ROUND) ** 2.8 <= 1.0
            if inside and y >= BAY_HEAD_Y - 1:
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
        x = 52 + 5 * math.sin(t * 7.0) + (BAY_CX - 52) * t ** 1.3
        y = t * (BAY_HEAD_Y + 2)
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
    shoals = [(75, 92), (87, 96), (30, 114), (50, 118), (70, 113), (92, 116),
              (108, 121), (18, 122), (121, 70), (122, 86), (119, 100), (100, 110)]
    for (wx, wy) in shoals:
        # The nearest tile out at sea (2-6 tiles from land) to where it is wanted.
        best = None
        for y in range(SIZE):
            for x in range(SIZE):
                if sea[y][x] and 2 <= to_land[y][x] <= 6:
                    d = (x - wx) ** 2 + (y - wy) ** 2
                    if best is None or d < best[0]:
                        best = (d, x, y)
        _, x, y = best
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
    for y in range(BEACH_GROUND[1], BEACH_GROUND[3]):
        for x in range(BEACH_GROUND[0], BEACH_GROUND[2]):
            if img[y][x] == FOREST:
                img[y][x] = GRASS

    # Where the settlers' cog anchors and the beach they wade to (data/maps/coast.tres): on the
    # bay's west shore, the first deep water east of the beach.
    for row in (86, 87, 88, 85, 89):
        xs = [x for x in range(60, BAY_CX) if sea[row][x]]
        if not xs:
            continue
        beach = (xs[0] - 1, row)
        deep = [x for x in range(xs[0], BAY_CX + 4) if img[row][x] in (DEEP, DEEP_SHOAL)]
        if img[row][beach[0]] == SAND and deep:
            print("landing_tile", (deep[0], row), "beach_tile", beach)
            break

    out = Image.new("RGB", (SIZE, SIZE))
    for y in range(SIZE):
        for x in range(SIZE):
            out.putpixel((x, y), img[y][x])
    out.save(OUT)
    print("written", OUT)


if __name__ == "__main__":
    main()
