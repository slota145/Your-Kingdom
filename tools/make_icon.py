#!/usr/bin/env python3
"""Make the game's icon (owner's choice 2026-11-14: the town hall) from the building's art.

The town hall (assets/buildings/town_hall/base.png) on a sky and a strip of grass, in a rounded
oak frame like the game's panels; written as icon.png (256 px, the window and taskbar icon,
application/config/icon) and icon.ico (16 to 256 px, the .exe icon in the Windows preset).

    python3 tools/make_icon.py
"""
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "assets/buildings/town_hall/base.png"
SIZE = 256
OAK = (94, 62, 36, 255)
OAK_DARK = (58, 38, 22, 255)


def main() -> None:
    sky = Image.new("RGBA", (SIZE, SIZE))
    draw = ImageDraw.Draw(sky)
    for y in range(SIZE):
        t = y / SIZE
        colour = (int(150 + 80 * t), int(186 + 30 * t), int(214 - 30 * t), 255) if t < 0.80 else (104, 140, 64, 255)
        draw.line([(0, y), (SIZE, y)], fill=colour)
    mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).rounded_rectangle([14, 14, SIZE - 15, SIZE - 15], radius=28, fill=255)
    art = Image.open(ART).convert("RGBA")
    art = art.crop(art.getbbox())
    box = int((SIZE - 36) * 0.86)
    scale = min(box / art.width, box / art.height)
    art = art.resize((int(art.width * scale), int(art.height * scale)), Image.LANCZOS)
    scene = sky.copy()
    scene.alpha_composite(art, ((SIZE - art.width) // 2, SIZE - 22 - art.height))
    icon = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ImageDraw.Draw(icon).rounded_rectangle([4, 4, SIZE - 5, SIZE - 5], radius=36, fill=OAK)
    icon.paste(scene, (0, 0), mask)
    ImageDraw.Draw(icon).rounded_rectangle([14, 14, SIZE - 15, SIZE - 15], radius=28, outline=OAK_DARK, width=3)
    icon.save(ROOT / "icon.png")
    icon.save(ROOT / "icon.ico", sizes=[(s, s) for s in (16, 24, 32, 48, 64, 128, 256)])
    print("icon.png, icon.ico")


if __name__ == "__main__":
    main()
