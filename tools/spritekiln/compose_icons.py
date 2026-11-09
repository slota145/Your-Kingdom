"""SpriteKiln trial: goods icons next to the game's current ones, on the UI's parchment, at 1x and 3x.

Run after rendering the icon specs (gen_icons.py, `spritekiln render` in each icon_<good> folder):
    python3 tools/spritekiln/compose_icons.py   -> previews/icons_vs_current.png
"""
import os

from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
GOODS = ["wood", "planks", "stone", "bread", "fish", "grain", "flour", "iron", "wine", "sword"]


def sk(g):
    return Image.open(os.path.join(ROOT, "tools", "spritekiln", "art", "specs", "props", f"icon_{g}", "out",
                                   f"icon_{g}", f"icon_{g}.png")).convert("RGBA")


def cur(g):
    return Image.open(os.path.join(ROOT, "assets", "goods", "icons", f"{g}.png")).convert("RGBA")


def main():
    panel = Image.open(os.path.join(ROOT, "assets", "ui", "panel_inset.png")).convert("RGBA")
    bg = panel.getpixel((panel.width // 2, panel.height // 2))
    cell = 40
    w = 90 + cell * len(GOODS)
    small = Image.new("RGBA", (w, 2 * cell + 8), bg)
    d = ImageDraw.Draw(small)
    for row, (src, label) in enumerate(((cur, "now"), (sk, "SpriteKiln"))):
        d.text((4, row * cell + 14), label, fill=(60, 40, 20, 255))
        for i, g in enumerate(GOODS):
            small.alpha_composite(src(g), (90 + i * cell + 4, row * cell + 4))
    big = small.resize((small.width * 3, small.height * 3), Image.NEAREST)
    out = Image.new("RGBA", (big.width, small.height + 12 + big.height), (30, 24, 18, 255))
    out.alpha_composite(small, (0, 0))
    out.alpha_composite(big, (0, small.height + 12))
    path = os.path.join(ROOT, "tools", "spritekiln", "previews", "icons_vs_current.png")
    out.convert("RGB").save(path)
    print(path, out.size)


if __name__ == "__main__":
    main()
