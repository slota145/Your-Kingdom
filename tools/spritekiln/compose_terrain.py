"""SpriteKiln trial: cut the rendered terrain patches to the 256x128 diamond and tile them (seam check),
next to the game's current textures. Writes previews/terrain_vs_current_2x.png and the cut textures to
previews/terrain_<id>_256.png.

Run after gen_terrain.py and the renders: python3 tools/spritekiln/compose_terrain.py
"""
import os

from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PROPS = os.path.join(ROOT, "tools", "spritekiln", "art", "specs", "props")
OUT = os.path.join(ROOT, "tools", "spritekiln", "previews")
KINDS = [("grass", "grass/a.png"), ("paving", "paving/a.png"), ("stony", "stony/big_a.png")]


def diamond_mask(w, h):
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).polygon([(w / 2, 0), (w, h / 2), (w / 2, h), (0, h / 2)], fill=255)
    return m


def cut(kind):
    """The middle 256x128 rectangle of the render: the 4x4-tile patch with its neighbours' corners."""
    im = Image.open(os.path.join(PROPS, f"terrain_{kind}", "out", f"terrain_{kind}", f"terrain_{kind}.png")).convert("RGBA")
    return im.crop((0, 64, 256, 192))            # the pivot is the patch centre at (128, 128)


def tile_rect(tex, nx=3, ny=6):
    """Rectangles laid like the game samples them (a grid of 256x128), then a big diamond shown."""
    w, h = tex.size
    img = Image.new("RGBA", (w * nx, h * ny))
    for i in range(nx):
        for j in range(ny):
            img.alpha_composite(tex, (i * w, j * h))
    img = img.crop((0, 0, w * nx, h * nx))
    out = Image.new("RGBA", img.size, (40, 40, 40, 255))
    out.paste(img, (0, 0), diamond_mask(*img.size))
    return out


def tile(tex, n=3):
    """n x n copies of a diamond tile on the iso grid (the game's 64x32 tiles)."""
    w, h = tex.size
    img = Image.new("RGBA", (w * n, h * n), (40, 40, 40, 255))
    for gx in range(n):
        for gy in range(n):
            x = (gx - gy) * w // 2 + (n - 1) * w // 2
            y = (gx + gy) * h // 2
            img.alpha_composite(tex, (x, y))
    return img


def main():
    rows = []
    for kind, cur in KINDS:
        tex = cut(kind)
        tex.save(os.path.join(OUT, f"terrain_{kind}_256.png"))
        c = Image.open(os.path.join(ROOT, "assets", "terrain", cur)).convert("RGBA")
        cur_tiled = tile_rect(c) if c.width == 256 else tile(c, 3 * 256 // c.width)   # the same area
        new_tiled = tile_rect(tex)
        rows.append((cur_tiled, new_tiled))
    W = rows[0][0].width
    H = sum(max(a.height, b.height) for a, b in rows)
    sheet = Image.new("RGBA", (W * 2 + 16, H), (30, 30, 30, 255))
    y = 0
    for a, b in rows:
        sheet.alpha_composite(a, (0, y))
        sheet.alpha_composite(b, (W + 16, y))
        y += max(a.height, b.height)
    ImageDraw.Draw(sheet).text((6, 4), "current", fill=(255, 255, 255, 255))
    ImageDraw.Draw(sheet).text((W + 22, 4), "SpriteKiln (one 256x128 texture repeated 3x3)", fill=(255, 255, 255, 255))
    sheet.resize((sheet.width, sheet.height), Image.NEAREST).convert("RGB").save(os.path.join(OUT, "terrain_vs_current.png"))
    print("ok", sheet.size)


if __name__ == "__main__":
    main()
