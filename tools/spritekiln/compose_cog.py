"""SpriteKiln trial: the cog in 8 directions on sea tiles, the game's current cog above, SpriteKiln's below.

Writes previews/cog_vs_current_2x.png (frame 0) and previews/cog_rocking_vs_current.gif (the 4 rocking
frames). Run after `spritekiln render cog.yaml` in art/specs/props/cog:
    python3 tools/spritekiln/compose_cog.py [<spec> <ship asset id>]   (default: cog cog; also caravel, galleon)
"""
import sys
import json
import os

from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "tools", "spritekiln", "previews")
DIRS = ["s", "se", "e", "ne", "n", "nw", "w", "sw"]      # ART_SPEC order, the rows of the game's sheet
SPEC = sys.argv[1] if len(sys.argv) > 1 else "cog"
ASSET = sys.argv[2] if len(sys.argv) > 2 else SPEC
SIZE = {"cog": 220, "caravel": 270, "galleon": 370}.get(ASSET, 220)
PIVOT = {"cog": (110, 168), "caravel": (135, 206), "galleon": (185, 290)}.get(ASSET, (110, 168))
SC = SIZE / 220
STEP, ROW_H, TOP = int(168 * SC), int(190 * SC), int(150 * SC)


def current():
    sheet = Image.open(os.path.join(ROOT, "assets", "ships", ASSET, "idle.png")).convert("RGBA")
    nf = sheet.width // SIZE
    return [[(sheet.crop(((f % nf) * SIZE, r * SIZE, (f % nf) * SIZE + SIZE, r * SIZE + SIZE)), PIVOT) for r in range(8)]
            for f in range(4)]


def spritekiln():
    d = os.path.join(ROOT, "tools", "spritekiln", "art", "specs", "props", SPEC, "out", SPEC)
    atlas = Image.open(os.path.join(d, SPEC + ".png")).convert("RGBA")
    meta = json.load(open(os.path.join(d, SPEC + ".json")))
    piv = meta["spritekiln"]["pivot"]
    frames = []
    for f in range(4):
        row = []
        for dr in DIRS:
            r = meta["frames"][f"idle_{dr}_{f}"]["frame"]
            row.append((atlas.crop((r["x"], r["y"], r["x"] + r["w"], r["y"] + r["h"])), (piv["x"], piv["y"])))
        frames.append(row)
    return frames


def water(w, h):
    tiles = [Image.open(os.path.join(ROOT, "assets", "terrain", "sea", f)).convert("RGBA") for f in ("a.png", "b.png")]
    img = Image.new("RGBA", (w, h), (30, 70, 110, 255))
    for ty in range(-1, h // 16 + 2):
        for tx in range(-1, w // 64 + 2):
            x = tx * 64 + (32 if ty % 2 else 0) - 32
            img.alpha_composite(tiles[(tx * 3 + ty) % 2], (x, ty * 16 - 16)) if x > -64 else None
    return img


def frame(cur, sk, f):
    w = STEP * 8 + 60
    img = water(w, TOP + ROW_H * 2 - 40)
    d = ImageDraw.Draw(img)
    for row, (src, label) in enumerate(((cur, "current (tools/render_cog.py)"), (sk, "SpriteKiln"))):
        y0 = TOP + row * ROW_H - 20
        for i, (im, (px, py)) in enumerate(src[f]):
            img.alpha_composite(im, (int(30 + STEP * i + STEP / 2 - px), int(y0 - py + 40 * SC)))
        d.text((6, y0 - 135 if row == 0 else y0 - 80), label, fill=(255, 255, 255, 255))
    for i, dr in enumerate(DIRS):
        d.text((30 + STEP * i + STEP // 2 - 6, img.height - 14), dr.upper(), fill=(255, 255, 255, 255))
    return img


def main():
    cur, sk = current(), spritekiln()
    frames = [frame(cur, sk, f) for f in range(4)]
    big = [im.resize((im.width * 2, im.height * 2), Image.NEAREST) for im in frames]
    big[0].convert("RGB").save(os.path.join(OUT, f"{SPEC}_vs_current_2x.png"))
    pal = [im.convert("RGB").quantize(colors=255, method=Image.Quantize.MEDIANCUT) for im in frames]
    pal[0].save(os.path.join(OUT, f"{SPEC}_rocking_vs_current.gif"), save_all=True, append_images=pal[1:],
                duration=260, loop=0)
    print("ok", big[0].size)


if __name__ == "__main__":
    main()
