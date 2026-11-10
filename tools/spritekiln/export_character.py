"""Copy a rendered SpriteKiln character into the game's sheets (ART_SPEC 4: assets/characters/<id>/<anim>.png).

The game's sheet: rows = screen directions S, SE, E, NE, N, NW, W, SW (8 rows: nothing mirrored),
columns = frames, 64x64 frames, the feet at (32, 58) (CharacterSheet). A long weapon may take a bigger
frame (the spec's `size`, e.g. 96: the feet at (48, 90), 6 px above the bottom; CharacterSheet.frame_side).
Riders take 128 px frames with the feet 16 px above the bottom, (64, 112) (CharacterSheet.foot_margin):
facing the viewer the horse's forelegs reach below the feet.
The spec's camera must give that pivot (the script checks it). Animation names map to the game's: idle -> idle, walk -> walk,
attack -> work and work_drill (soldiers fight and drill with the same blow).

Run: python3 tools/spritekiln/export_character.py <spec name> [<game character id>] [--props] [--anims=<a>[:<b>],...]
     e.g. python3 tools/spritekiln/export_character.py halberdier
--props reads the spec from art/specs/props (the siege engines, gen_siege.py); --anims replaces the
animation mapping: "idle,walk,strike:work" copies idle and walk under their own names and strike as work.
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
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    spec = args[0]
    char = args[1] if len(args) > 1 else spec
    kind = "props" if "--props" in sys.argv else "characters"
    anims = GAME_ANIMS
    for a in sys.argv:
        if a.startswith("--anims="):
            anims = {}
            for item in a.split("=", 1)[1].split(","):
                src, _, dst = item.partition(":")
                anims.setdefault(src, []).append(dst or src)
    d = os.path.join(ROOT, "tools", "spritekiln", "art", "specs", kind, spec, "out", spec)
    meta = json.load(open(os.path.join(d, spec + ".json")))
    piv = meta["spritekiln"]["pivot"]
    size = next(iter(meta["frames"].values()))["frame"]["w"]
    margin = 16 if size >= 128 else 6
    if abs(piv["x"] - size / 2) > 0.5 or abs(piv["y"] - (size - margin)) > 0.5:
        sys.exit(f"pivot {piv} is not ({size // 2}, {size - margin}): fix camera.center in the spec")
    atlas = Image.open(os.path.join(d, spec + ".png")).convert("RGBA")
    out_dir = os.path.join(ROOT, "assets", "characters", char)
    os.makedirs(out_dir, exist_ok=True)
    for anim, names in anims.items():
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
