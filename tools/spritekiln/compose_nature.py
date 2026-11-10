"""SpriteKiln trial: trees, rocks and the pig next to the game's current ones, on grass.

Writes previews/nature_vs_current_3x.png (tree and rock in their 3 states), previews/pig_vs_current_4x.png
(the current led-pig views above, SpriteKiln's 8 directions below) and previews/pig_<anim>.gif.
Run after gen_nature.py and the renders: python3 tools/spritekiln/compose_nature.py
"""
import json
import os

from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PROPS = os.path.join(ROOT, "tools", "spritekiln", "art", "specs", "props")
OUT = os.path.join(ROOT, "tools", "spritekiln", "previews")
DIRS = ["s", "se", "e", "ne", "n", "nw", "w", "sw"]


def grass(w, h):
    g = Image.open(os.path.join(ROOT, "assets", "terrain", "grass", "a.png")).convert("RGBA")
    img = Image.new("RGBA", (w, h), (90, 120, 64, 255))
    for y in range(-16, h, 16):
        for x in range(-64, w, 64):
            img.alpha_composite(g, (x + (32 if (y // 16) % 2 else 0), y))
    return img


def sk_frame(name, anim="idle", d="se", f=0):
    base = os.path.join(PROPS, name, "out", name)
    meta = json.load(open(os.path.join(base, name + ".json")))
    r = meta["frames"][f"{anim}_{d}_{f}"]["frame"]
    atlas = Image.open(os.path.join(base, name + ".png")).convert("RGBA")
    return atlas.crop((r["x"], r["y"], r["x"] + r["w"], r["y"] + r["h"])), meta["spritekiln"]["pivot"]


def nature_sheet():
    states = ["grown", "felled", "stump"]
    img = grass(64 * 6 + 40, 96 * 2 + 20)
    d = ImageDraw.Draw(img)
    for col, thing in enumerate(["tree", "rock"]):
        for i, st in enumerate(states):
            x = col * (64 * 3 + 20) + i * 64
            cur = Image.open(os.path.join(ROOT, "assets", "nature", thing, st + ".png")).convert("RGBA")
            img.alpha_composite(cur, (x, 4))
            sk, _ = sk_frame(f"{thing}_{st}")
            img.alpha_composite(sk.crop((16, 0, 80, 96)), (x, 96 + 16))
    d.text((2, 2), "now", fill=(255, 255, 255, 255))
    d.text((2, 100), "SpriteKiln", fill=(255, 255, 255, 255))
    img = img.resize((img.width * 3, img.height * 3), Image.NEAREST)
    img.convert("RGB").save(os.path.join(OUT, "nature_vs_current_3x.png"))


def pig_sheet():
    cur = Image.open(os.path.join(ROOT, "assets", "goods", "carried", "animal", "pig.png")).convert("RGBA")
    img = grass(8 * 40 + 8, 110)
    for i in range(5):
        img.alpha_composite(cur.crop((0, i * 24, 24, i * 24 + 24)), (8 + i * 40, 10))
    for i, d in enumerate(DIRS):
        fr, _ = sk_frame("pig", "walk", d, 1)
        img.alpha_composite(fr, (4 + i * 40, 50))
        fr, _ = sk_frame("pig", "root", d, 2)
        img.alpha_composite(fr, (4 + i * 40, 76))
    img.resize((img.width * 4, img.height * 4), Image.NEAREST).convert("RGB").save(os.path.join(OUT, "pig_vs_current_4x.png"))
    for anim, n, ms in (("idle", 8, 150), ("walk", 8, 95), ("root", 8, 130)):
        frames = []
        for f in range(n):
            g = grass(8 * 36 + 8, 44)
            for i, d in enumerate(DIRS):
                fr, _ = sk_frame("pig", anim, d, f)
                g.alpha_composite(fr, (6 + i * 36, 6))
            frames.append(g.resize((g.width * 3, g.height * 3), Image.NEAREST).convert("RGB")
                          .quantize(colors=255, method=Image.Quantize.MEDIANCUT))
        frames[0].save(os.path.join(OUT, f"pig_{anim}.gif"), save_all=True, append_images=frames[1:], duration=ms, loop=0)


if __name__ == "__main__":
    nature_sheet()
    pig_sheet()
    print("ok")
