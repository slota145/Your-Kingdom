"""SpriteKiln trial: put the burgher row fragments on grass next to the game's current ones.

Layout (game tile coords, plots 2x2): a row along y facing +x (end_a, middle, corner_a), the row
behind the corner along x (mirrored, as the game draws it: middle, end_a), a cobbled street in
front and round the corner, and a short row end_a, middle, end_b to show the free end b.
Left half: assets/buildings/hut/level_2_*; right half: the SpriteKiln renders.

Run: python3 tools/spritekiln/compose_townhouses.py [out.png]
"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageOps

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SK = os.path.join(ROOT, "tools", "spritekiln", "art", "specs", "props")
HUT = os.path.join(ROOT, "assets", "buildings", "hut")

# (plot x, plot y, fragment, mirrored)
PLOTS = [(0, -10, "end_a", False), (0, -8, "middle", False), (0, -6, "end_b", False),
         (0, 0, "end_a", False), (0, 2, "middle", False), (0, 4, "corner_a", False),
         (-2, 4, "middle", True), (-4, 4, "end_a", True)]
STREET = [(x, y) for x in (2, 3) for y in range(-12, 8)] + [(x, y) for x in range(-6, 4) for y in (6, 7)]


def current(frag):
    im = Image.open(os.path.join(HUT, f"level_2_{frag}.png")).convert("RGBA")
    piv = json.load(open(os.path.join(HUT, f"level_2_{frag}.json")))["pivot"]
    return im, (piv[0], piv[1])


def spritekiln(frag):
    d = os.path.join(SK, f"townhouse_{frag}", "out", f"townhouse_{frag}")
    im = Image.open(os.path.join(d, f"townhouse_{frag}.png")).convert("RGBA")
    p = json.load(open(os.path.join(d, f"townhouse_{frag}.json")))["spritekiln"]["pivot"]
    return im, (p["x"], p["y"] + 32)       # SpriteKiln: the plot centre; the game: its front corner


def scene(get, label):
    def scr(x, y):
        return (x - y) * 32, (x + y) * 16
    xs = [scr(x, y) for x in range(-8, 6) for y in range(-14, 10)]
    minx = min(p[0] for p in xs) - 32
    maxx = max(p[0] for p in xs) + 32
    miny = -300
    maxy = max(p[1] for p in xs) + 40
    W, Hh = maxx - minx, maxy - miny
    img = Image.new("RGBA", (W, Hh), (70, 98, 52, 255))
    grass = [Image.open(os.path.join(ROOT, "assets", "terrain", "grass", f)).convert("RGBA")
             for f in ("a.png", "light.png", "dark.png")]
    pave = Image.open(os.path.join(ROOT, "assets", "terrain", "paving", "a.png")).convert("RGBA")
    for x in range(-8, 6):
        for y in range(-14, 10):
            sx, sy = scr(x, y)
            t = pave if (x, y) in STREET else grass[(x * 7 + y * 3) % 3 if (x + y) % 4 == 0 else 0]
            img.alpha_composite(t, (sx - 32 - minx, sy - miny))
    layer = Image.new("RGBA", img.size)
    for (x, y, frag, mir) in sorted(PLOTS, key=lambda p: p[0] + p[1]):
        im, (px, py) = get(frag)
        if mir:
            im = ImageOps.mirror(im)
            px = im.width - px
        sx, sy = scr(x + 2, y + 2)
        layer.alpha_composite(im, (int(round(sx - minx - px)), int(round(sy - miny - py))))
    img.alpha_composite(layer)
    l, t, r, b = layer.getchannel("A").getbbox()
    img = img.crop((l - 40, t - 24, r + 40, b + 40))
    ImageDraw.Draw(img).text((6, 4), label, fill=(255, 255, 255, 255))
    return img


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "tools", "spritekiln", "previews",
                                                             "townhouses_vs_current_2x.png")
    a = scene(current, "current (code-drawn, level 2)")
    b = scene(spritekiln, "SpriteKiln")
    pair = Image.new("RGBA", (a.width * 2 + 8, a.height), (20, 20, 20, 255))
    pair.alpha_composite(a, (0, 0))
    pair.alpha_composite(b, (a.width + 8, 0))
    pair = pair.resize((pair.width * 2, pair.height * 2), Image.NEAREST)
    pair.convert("RGB").save(out)
    print(out, pair.size)


if __name__ == "__main__":
    main()
