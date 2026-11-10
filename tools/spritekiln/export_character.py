"""Copy a rendered SpriteKiln character into the game's sheets (ART_SPEC 4: assets/characters/<id>/<anim>.png).

The game's sheet: rows = screen directions S, SE, E, NE, N, NW, W, SW (8 rows: nothing mirrored),
columns = frames, 64x64 frames, the feet at (32, 58) (CharacterSheet). A long weapon may take a bigger
frame (the spec's `size`, e.g. 96: the feet at (48, 90), 6 px above the bottom; CharacterSheet.frame_side).
The spec's camera must give that pivot (the script checks it). Animation names map to the game's: idle -> idle, walk -> walk,
attack -> work and work_drill (soldiers fight and drill with the same blow).

Run: python3 tools/spritekiln/export_character.py <spec name> [<game character id>]
     e.g. python3 tools/spritekiln/export_character.py halberdier
Then: "$GODOT" --headless --path . --import and python3 tools/make_unit_icons.py
"""
import json
import os
import sys

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DIRS = ["s", "se", "e", "ne", "n", "nw", "w", "sw"]
GAME_ANIMS = {"idle": ["idle"], "walk": ["walk"], "attack": ["work", "work_drill"]}


def main():
    spec = sys.argv[1]
    char = sys.argv[2] if len(sys.argv) > 2 else spec
    d = os.path.join(ROOT, "tools", "spritekiln", "art", "specs", "characters", spec, "out", spec)
    meta = json.load(open(os.path.join(d, spec + ".json")))
    piv = meta["spritekiln"]["pivot"]
    size = next(iter(meta["frames"].values()))["frame"]["w"]
    if abs(piv["x"] - size / 2) > 0.5 or abs(piv["y"] - (size - 6)) > 0.5:
        sys.exit(f"pivot {piv} is not ({size // 2}, {size - 6}): fix camera.center in the spec")
    atlas = Image.open(os.path.join(d, spec + ".png")).convert("RGBA")
    out_dir = os.path.join(ROOT, "assets", "characters", char)
    for anim, names in GAME_ANIMS.items():
        n = sum(1 for k in meta["frames"] if k.startswith(f"{anim}_s_"))
        if n == 0:
            continue
        sheet = Image.new("RGBA", (size * n, size * len(DIRS)))
        for row, dr in enumerate(DIRS):
            for f in range(n):
                r = meta["frames"][f"{anim}_{dr}_{f}"]["frame"]
                sheet.alpha_composite(atlas.crop((r["x"], r["y"], r["x"] + size, r["y"] + size)), (f * size, row * size))
        for name in names:
            sheet.save(os.path.join(out_dir, name + ".png"))
            print(os.path.join(out_dir, name + ".png"), sheet.size)


if __name__ == "__main__":
    main()
