#!/usr/bin/env python3
"""Large seamless ground textures (review fixes 2026-11-07, batch 3; ART_SPEC §8.1, §10.2).

The organic ground shader samples most terrains from a 64x32 diamond repeated every tile, so a
strong pattern (lake ripples, rocks) shows a lattice, and rocks cut at the diamond's edge make
seams. These textures repeat only every 4x4 tiles: each is a 256x128 picture of a 4x4 tile
diamond, filled from a pattern that wraps around in grid space (a torus), so the copies meet
without a seam. Three variants of each are mixed by the shader in soft patches.

  lake/big_{a,b,c}.png   lake water: calm base with darker patches, short ripple strokes and
                         a few light glints, in the palette of the PixelLab lake tile (lake/a.png),
  stony/big_{a,b,c}.png  stony ground: bare earth in the palette of the PixelLab stony tiles,
  stony/rocks_{a,b}.png  transparent layers with pebbles and whole rocks cut out of those tiles
                         (stony/a, stony/b) scattered at random, repeating every 5 and 7 tiles
                         (320x160, 448x224); a rock that crosses the edge wraps to the other
                         side, so no rock is ever cut, and the layers are never mixed by
                         pattern, so no rock is cut by a variant edge either.

Run from the project root: python3 tools/generate_terrain_variants.py (needs Pillow)."""
import math
import random

from PIL import Image

OUT = "assets/terrain/"
VARIANTS = "abc"
## Tiles per repeat of the ground textures; the two rock layers repeat every 5 and 7 tiles, so
## together they repeat only every 35 tiles.
GROUND_PERIOD = 4
ROCK_PERIODS = {"a": 5, "b": 7}

PERIOD = W = H = 0
SHIFTS = []


def set_period(period):
    """Picture size and wrap-around for a texture repeating every period x period tiles."""
    global PERIOD, W, H, SHIFTS
    PERIOD, W, H = period, 64 * period, 32 * period
    # Lattice shifts that map the picture onto itself (one period along each grid axis).
    SHIFTS = [(a * 32 * period - b * 32 * period, (a + b) * 16 * period)
              for a in range(-2, 3) for b in range(-2, 3)]


# --- grid <-> picture -------------------------------------------------------------------
# Same projection as the shader: grid (x, y) -> screen ((x - y) * 32, (x + y) * 16); the
# picture holds the diamond of grid [0, PERIOD)^2 with its top corner at (W / 2, 0).

def to_grid(px, py):
    sx, sy = px - W / 2, py
    return (sx / 32.0 + sy / 16.0) * 0.5, (sy / 16.0 - sx / 32.0) * 0.5


def put(img, x, y, colour):
    """Sets a picture pixel and all its copies one period away, so stamps wrap seamlessly."""
    px = img.load()
    for dx, dy in SHIFTS:
        tx, ty = x + dx, y + dy
        if 0 <= tx < W and 0 <= ty < H:
            px[tx, ty] = colour


# --- noise on the torus -----------------------------------------------------------------

class TorusNoise:
    """Smooth value noise over the grid, repeating every PERIOD tiles."""

    def __init__(self, seed, cells):
        rng = random.Random(seed)
        self.cells = cells
        self.values = [[rng.random() for _ in range(cells)] for _ in range(cells)]

    def at(self, gx, gy):
        u = gx / PERIOD * self.cells
        v = gy / PERIOD * self.cells
        i, j = math.floor(u), math.floor(v)
        fu, fv = u - i, v - j
        fu = fu * fu * (3 - 2 * fu)
        fv = fv * fv * (3 - 2 * fv)
        n = self.cells
        a = self.values[i % n][j % n]
        b = self.values[(i + 1) % n][j % n]
        c = self.values[i % n][(j + 1) % n]
        d = self.values[(i + 1) % n][(j + 1) % n]
        return (a * (1 - fu) + b * fu) * (1 - fv) + (c * (1 - fu) + d * fu) * fv


def fbm(layers, gx, gy):
    total, weight = 0.0, 0.0
    for noise, w in layers:
        total += noise.at(gx, gy) * w
        weight += w
    return total / weight


BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def bayer(x, y):
    return (BAYER[y % 4][x % 4] + 0.5) / 16.0


# --- lake -------------------------------------------------------------------------------

LAKE_BASE = (40, 82, 93, 255)
LAKE_MID = (36, 69, 78, 255)
LAKE_DARK = (27, 66, 77, 255)
LAKE_LIGHT = (50, 96, 106, 255)


def lake(seed):
    rng = random.Random(seed)
    img = Image.new("RGBA", (W, H))
    px = img.load()
    shade = [(TorusNoise(seed * 7 + 1, 4), 0.6), (TorusNoise(seed * 7 + 2, 8), 0.3),
             (TorusNoise(seed * 7 + 3, 16), 0.1)]
    calm = [(TorusNoise(seed * 7 + 4, 8), 1.0)]
    for y in range(H):
        for x in range(W):
            gx, gy = to_grid(x + 0.5, y + 0.5)
            # Deeper, darker patches with a narrow dithered edge.
            px[x, y] = LAKE_MID if (fbm(shade, gx, gy) - 0.55) * 14.0 > bayer(x, y) else LAKE_BASE
    # Ripples: short flat strokes, dark in light water and light in the dark patches, now and
    # then a lighter crest pixel over a stroke; fewer where the water is calm. Every stroke may
    # cross the picture's edge (it wraps), so nothing lines up with the tiles.
    strokes = 0
    for _ in range(20000):
        if strokes >= 22 * PERIOD * PERIOD:
            break
        x, y = rng.randrange(W), rng.randrange(H)
        if fbm(calm, *to_grid(x, y)) < rng.random():
            continue
        length = rng.choice((2, 3, 3, 4, 4, 5, 6))
        under = px[x % W, y % H]
        colour = LAKE_DARK if under == LAKE_BASE else LAKE_BASE
        for k in range(length):
            put(img, x + k, y, colour)
        if length >= 4 and rng.random() < 0.3:
            put(img, x + 1 + rng.randrange(length - 2), y - 1, LAKE_LIGHT)
        strokes += 1
    return img


# --- stony ground -----------------------------------------------------------------------

SOIL = [(150, 129, 95, 255), (146, 126, 93, 255), (143, 124, 93, 255), (137, 115, 83, 255),
        (163, 136, 105, 255), (155, 136, 105, 255)]
PEBBLE_LIGHT = [(192, 183, 161, 255), (217, 211, 183, 255), (190, 173, 145, 255)]
PEBBLE_SHADOW = (55, 49, 45, 255)


def is_rock(c):
    """Anything that is not bare earth: grey stone, its light top, dark outline and moss."""
    r, g, b, a = c
    if a == 0:
        return False
    return not (125 <= r <= 172 and 38 <= r - b <= 78)


def cut_rocks(path, allow_edge=False):
    """Rocks (connected blobs of at least 20 px that are not bare earth) as lists of
    (dx, dy, colour) from their top-left corner. With allow_edge, also blobs next to the
    diamond's edge (checked by eye: in stony/a and stony/b these are whole rocks too)."""
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    px = img.load()
    seen = set()
    rocks = []
    for y in range(h):
        for x in range(w):
            if (x, y) in seen or not is_rock(px[x, y]):
                continue
            blob, stack, touches = [], [(x, y)], False
            seen.add((x, y))
            while stack:
                cx, cy = stack.pop()
                blob.append((cx, cy))
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)):
                    nx, ny = cx + dx, cy + dy
                    if not (0 <= nx < w and 0 <= ny < h) or px[nx, ny][3] == 0:
                        touches = True
                        continue
                    if (nx, ny) not in seen and is_rock(px[nx, ny]):
                        seen.add((nx, ny))
                        stack.append((nx, ny))
            if len(blob) >= 20 and (allow_edge or not touches):
                left = min(p[0] for p in blob)
                top = min(p[1] for p in blob)
                rocks.append([(bx - left, by - top, px[bx, by]) for bx, by in blob])
    return rocks


def stony_soil(seed):
    """Bare earth only (no rocks, so the shader may mix variants pixel by pixel)."""
    rng = random.Random(seed)
    img = Image.new("RGBA", (W, H))
    px = img.load()
    patches = [(TorusNoise(seed * 5 + 1, 8), 0.6), (TorusNoise(seed * 5 + 2, 16), 0.4)]
    grain = [(TorusNoise(seed * 5 + 3, 32), 1.0)]
    for y in range(H):
        for x in range(W):
            gx, gy = to_grid(x + 0.5, y + 0.5)
            p = fbm(patches, gx, gy)
            q = fbm(grain, gx, gy)
            colour = SOIL[0]
            if (p - 0.58) * 5.0 > bayer(x, y):
                colour = SOIL[4]            # lighter, dusty earth
            elif (0.42 - p) * 5.0 > bayer(x, y):
                colour = SOIL[3]            # darker, damper earth
            elif rng.random() < 0.18:
                colour = SOIL[1 + int(q * 2.99)]
            px[x, y] = colour
    return img


def stony_rocks(seed, rocks):
    """A transparent layer of whole rocks and pebbles; the shader lays two of them (different
    periods) over the soil."""
    rng = random.Random(seed)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    clusters = [(TorusNoise(seed * 5 + 4, 2 * PERIOD), 1.0)]
    taken = set()

    def free(cells):
        return not any((cx % W, cy % H) in taken for cx, cy in cells)

    def take(cells):
        for cx, cy in cells:
            for sx, sy in SHIFTS:
                taken.add(((cx + sx) % W, (cy + sy) % H))

    # Rocks: about 1.3 a tile in each of the two layers, gathered in loose clusters with
    # barer ground between them.
    placed = 0
    for _ in range(40000):
        if placed >= 1.3 * PERIOD * PERIOD:
            break
        rock = rng.choice(rocks)
        x, y = rng.randrange(W), rng.randrange(H)
        if fbm(clusters, *to_grid(x, y)) < rng.random() * 0.8 + 0.2:
            continue
        cells = [(x + dx + ex, y + dy + ey) for dx, dy, _ in rock for ex in (-1, 0, 1) for ey in (-1, 0, 1)]
        if not free(cells):
            continue
        mirror = rng.random() < 0.5
        width = max(dx for dx, _, _ in rock)
        for dx, dy, c in rock:
            put(img, x + (width - dx if mirror else dx), y + dy, c)
        take(cells)
        placed += 1
    # Pebbles: a light pixel or two with a dark one under it, about 6 a tile.
    for _ in range(6 * PERIOD * PERIOD):
        x, y = rng.randrange(W), rng.randrange(H)
        if not free([(x, y), (x + 1, y), (x, y + 1), (x + 1, y + 1)]):
            continue
        light = rng.choice(PEBBLE_LIGHT)
        put(img, x, y, light)
        if rng.random() < 0.4:
            put(img, x + 1, y, light)
        put(img, x, y + 1, PEBBLE_SHADOW)
        take([(x, y)])
    return img


def main():
    rocks = cut_rocks(OUT + "stony/a.png", True) + cut_rocks(OUT + "stony/b.png", True)
    set_period(GROUND_PERIOD)
    for i, v in enumerate(VARIANTS):
        lake(11 + i).save(OUT + "lake/big_%s.png" % v)
        stony_soil(23 + i).save(OUT + "stony/big_%s.png" % v)
    for i, (v, period) in enumerate(ROCK_PERIODS.items()):
        set_period(period)
        stony_rocks(41 + i, rocks).save(OUT + "stony/rocks_%s.png" % v)
    print("written lake/big_{a,b,c}, stony/big_{a,b,c}, stony/rocks_{a,b} (%d rocks cut)" % len(rocks))


if __name__ == "__main__":
    main()
