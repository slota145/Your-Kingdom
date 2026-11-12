"""Copy rendered SpriteKiln townsfolk into the game (G3, ART_SPEC 4 and 5): assets/characters/<id>/<anim>.png.

Sheets as export_character.py: rows S, SE, E, NE, N, NW, W, SW (nothing mirrored), 64 px frames, the feet
at (32, 58). Clip names map to the game's: idle, walk, carry_<category> -> walk_carry_<category> (with
<anim>.anchors.png), work_<activity> -> work_<activity>, and the profession's first activity also -> work
(the game's fallback for activities without their own clip).

Carry anchors come from the spec's `load` socket ([x, y, depth] px from the feet per frame): a red pixel
where the good's centre goes and, when the socket is behind the body (depth < BEHIND_DEPTH), a blue pixel
in the frame's corner (CharacterSheet reads both).

Run: python3 tools/spritekiln/export_civilian.py <id> [<id> ...]   (after `spritekiln render <id>.yaml`)
Then: "$GODOT" --headless --path . --import
"""
import json
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_civilians  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DIRS = ["s", "se", "e", "ne", "n", "nw", "w", "sw"]
FOOT = (32, 58)
BEHIND_DEPTH = -1.0


def game_names(clip, first_activity):
    if clip.startswith("carry_"):
        return ["walk_" + clip]
    names = [clip]
    if clip == "work_" + first_activity:
        names.append("work")
    return names


def export(pid):
    d = os.path.join(ROOT, "tools", "spritekiln", "art", "specs", "characters", pid, "out", pid)
    meta = json.load(open(os.path.join(d, pid + ".json")))
    sk = meta["spritekiln"]
    size = sk["frame_size"]
    piv = sk["pivot"]
    if size != 64 or abs(piv["x"] - FOOT[0]) > 0.5 or abs(piv["y"] - FOOT[1]) > 0.5:
        sys.exit(f"{pid}: frame {size}, pivot {piv}: expected 64 and {FOOT}")
    atlas = Image.open(os.path.join(d, pid + ".png")).convert("RGBA")
    out_dir = os.path.join(ROOT, "assets", "characters", pid)
    os.makedirs(out_dir, exist_ok=True)
    # Old sheets of clips the new model no longer has (the code-drawn generic ones) must not linger.
    first = gen_civilians.PROFESSIONS[pid]["activities"][0]
    written = set()
    for clip, info in sk["animations"].items():
        n = len(info["directions"]["s"]["frames"])
        sheet = Image.new("RGBA", (64 * n, 64 * len(DIRS)))
        anchors = Image.new("RGBA", sheet.size) if clip.startswith("carry_") else None
        for row, dr in enumerate(DIRS):
            dinfo = info["directions"][dr]
            for f, key in enumerate(dinfo["frames"]):
                r = meta["frames"][key]["frame"]
                sheet.alpha_composite(atlas.crop((r["x"], r["y"], r["x"] + 64, r["y"] + 64)), (f * 64, row * 64))
                if anchors is not None:
                    x, y, depth = dinfo["sockets"]["load"][f]
                    ax, ay = round(FOOT[0] + x), round(FOOT[1] + y)
                    anchors.putpixel((f * 64 + ax, row * 64 + ay), (255, 0, 0, 255))
                    if depth < BEHIND_DEPTH:
                        anchors.putpixel((f * 64, row * 64), (0, 0, 255, 255))
        for name in game_names(clip, first):
            sheet.save(os.path.join(out_dir, name + ".png"))
            written.add(name)
            if anchors is not None:
                anchors.save(os.path.join(out_dir, name + ".anchors.png"))
            print(os.path.join(out_dir, name + ".png"), sheet.size)
    for f in sorted(os.listdir(out_dir)):
        base = f.split(".")[0]
        if f.endswith(".png") and base not in written:
            print("stale (not written by the new model):", os.path.join(out_dir, f))


def main():
    for pid in sys.argv[1:]:
        export(pid)


if __name__ == "__main__":
    main()
