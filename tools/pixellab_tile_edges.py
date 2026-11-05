#!/usr/bin/env python3
"""Evens out the edges of PixelLab isometric ground tiles (ART_SPEC §10.2).

create_tiles_pro draws 64x32 diamonds (on a 64x64 canvas) with darker bottom edges, as if the
tile had thickness. Tiled side by side this shows the grid. For every edge band the colour
is scaled towards the tile's interior mean, fading out inwards. The result is cropped to the
64x32 diamond, the file format of assets/terrain (ART_SPEC §3.1).

Usage: python3 tools/pixellab_tile_edges.py <out_dir> <tile.png> [<tile.png> ...]
Needs Pillow.
"""
import os
import sys

from PIL import Image

BAND = 0.12      # edge band width, as a fraction of the diamond "radius"
FADE = 0.2       # correction fades out at this distance from the edge


def _geometry(x: int, y: int, top: int) -> tuple[float, str]:
    u = (x + 0.5 - 32) / 32
    v = (y - top + 0.5 - 16) / 16
    edge = ("N" if v < 0 else "S") + ("W" if u < 0 else "E")
    return 1 - (abs(u) + abs(v)), edge


def fix(path: str) -> Image.Image:
    tile = Image.open(path).convert("RGBA")
    top = 16 if tile.height == 64 else 0
    px = tile.load()
    sums: dict[str, list[float]] = {}
    for y in range(tile.height):
        for x in range(tile.width):
            if px[x, y][3] == 0:
                continue
            dist, edge = _geometry(x, y, top)
            key = edge if dist < BAND else ("in" if dist > 0.3 else None)
            if key is None:
                continue
            acc = sums.setdefault(key, [0.0, 0.0, 0.0, 0.0])
            for c in range(3):
                acc[c] += px[x, y][c]
            acc[3] += 1
    mean = {k: [a[c] / a[3] for c in range(3)] for k, a in sums.items()}
    out = tile.copy()
    po = out.load()
    for y in range(tile.height):
        for x in range(tile.width):
            p = px[x, y]
            if p[3] == 0:
                continue
            dist, edge = _geometry(x, y, top)
            if edge not in mean or "in" not in mean:
                continue
            weight = max(0.0, min(1.0, (FADE - dist) / BAND))
            rgb = []
            for c in range(3):
                gain = mean["in"][c] / max(mean[edge][c], 1.0)
                rgb.append(max(0, min(255, round(p[c] * (1 + (gain - 1) * weight)))))
            po[x, y] = (*rgb, p[3])
    return out.crop((0, top, 64, top + 32))


def main() -> None:
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    out_dir = sys.argv[1]
    os.makedirs(out_dir, exist_ok=True)
    for path in sys.argv[2:]:
        fix(path).save(os.path.join(out_dir, os.path.basename(path)))


if __name__ == "__main__":
    main()
