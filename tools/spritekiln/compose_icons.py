"""SpriteKiln trial: goods icons next to the game's current ones, on the UI's parchment, at 1x and 3x.

Run after rendering the icon specs (gen_icons.py, `spritekiln render` in each icon_<good> folder):
    python3 tools/spritekiln/compose_icons.py [--export]   -> previews/icons_vs_current.png (--export: into the game)
"""
import os

from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
GOODS = sorted(f[:-4] for f in os.listdir(os.path.join(ROOT, "assets", "goods", "icons")) if f.endswith(".png"))
ROWS = 3   # the goods in 3 bands, each with the current icons above the SpriteKiln ones


def sk(g):
    return Image.open(os.path.join(ROOT, "tools", "spritekiln", "art", "specs", "props", f"icon_{g}", "out",
                                   f"icon_{g}", f"icon_{g}.png")).convert("RGBA")


def cur(g):
    return Image.open(os.path.join(ROOT, "assets", "goods", "icons", f"{g}.png")).convert("RGBA")


def main():
    import sys
    panel = Image.open(os.path.join(ROOT, "assets", "ui", "panel_inset.png")).convert("RGBA")
    bg = panel.getpixel((panel.width // 2, panel.height // 2))
    cell = 40
    per = (len(GOODS) + ROWS - 1) // ROWS
    w = 90 + cell * per
    small = Image.new("RGBA", (w, ROWS * (2 * cell + 10)), bg)
    d = ImageDraw.Draw(small)
    for band in range(ROWS):
        goods = GOODS[band * per:(band + 1) * per]
        y0 = band * (2 * cell + 10)
        for row, (src, label) in enumerate(((cur, "now"), (sk, "SpriteKiln"))):
            d.text((4, y0 + row * cell + 14), label, fill=(60, 40, 20, 255))
            for i, g in enumerate(goods):
                small.alpha_composite(src(g), (90 + i * cell + 4, y0 + row * cell + 4))
    big = small.resize((small.width * 2, small.height * 2), Image.NEAREST)
    path = os.path.join(ROOT, "tools", "spritekiln", "previews", "icons_vs_current.png")
    big.convert("RGB").save(path)
    print(path, big.size)
    if "--export" in sys.argv:   # owner 2026-11-09: the SpriteKiln icons go into the game
        for g in GOODS:
            sk(g).save(os.path.join(ROOT, "assets", "goods", "icons", g + ".png"))
        print(len(GOODS), "icons -> assets/goods/icons")


if __name__ == "__main__":
    main()
