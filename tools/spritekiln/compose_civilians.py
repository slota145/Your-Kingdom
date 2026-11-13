"""Comparison sheet for SpriteKiln townsfolk (G3): every carry walk with real carried goods drawn the way
the game does (AgentSprite: the good's centre on the anchor, behind the body when the anchor says so,
5-row goods flipped for the W side), old (git HEAD or --old=<rev>) above new (assets/), 3x.

Run: python3 tools/spritekiln/compose_civilians.py <id> [--old=<rev>] [--frame=<n>] [--out=<png>]
"""
import io
import os
import subprocess
import sys

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CATS = {"sack": "flour", "barrel": "beer", "log": "wood", "basket": "bread", "bundle": "wool",
        "crate": "tools", "stone": "stone"}
FOOT = (32, 58)
CELL = 64
ZOOM = 3


def load(path, rev):
    if rev is None:
        return Image.open(os.path.join(ROOT, path)).convert("RGBA")
    try:
        data = subprocess.run(["git", "-C", ROOT, "show", f"{rev}:{path}"], capture_output=True, check=True).stdout
    except subprocess.CalledProcessError:
        return None
    return Image.open(io.BytesIO(data)).convert("RGBA")


def good_image(cat):
    d = os.path.join(ROOT, "assets", "goods", "carried", cat)
    name = CATS[cat] + ".png"
    if not os.path.exists(os.path.join(d, name)):
        name = sorted(f for f in os.listdir(d) if f.endswith(".png"))[0]
    return Image.open(os.path.join(d, name)).convert("RGBA")


def person_frame(sheet, anchors, good, dir_row, frame):
    rows = 8 if sheet.height == 8 * CELL else 5
    frames = sheet.width // CELL
    frame %= frames
    if rows == 8 or dir_row <= 4:
        row, flip = dir_row, False
    else:
        row, flip = 8 - dir_row, True
    cell = sheet.crop((frame * CELL, row * CELL, (frame + 1) * CELL, (row + 1) * CELL))
    if flip:
        cell = cell.transpose(Image.FLIP_LEFT_RIGHT)
    if anchors is None or good is None:
        return cell
    a = anchors.crop((frame * CELL, row * CELL, (frame + 1) * CELL, (row + 1) * CELL))
    px = a.load()
    spot, behind = None, False
    for y in range(CELL):
        for x in range(CELL):
            c = px[x, y]
            if c[3] > 127 and c[:3] == (255, 0, 0):
                spot = (x - FOOT[0], y - FOOT[1])
            elif c[3] > 127 and c[:3] == (0, 0, 255):
                behind = True
    if spot is None:
        return cell
    if flip:
        spot = (-spot[0] - 1, spot[1])
    o_row, o_flip = (dir_row, False) if dir_row <= 4 else (8 - dir_row, True)
    if rows == 5:
        o_row, o_flip = row, flip
    g = good.crop((0, o_row * 24, 24, o_row * 24 + 24))
    if o_flip:
        g = g.transpose(Image.FLIP_LEFT_RIGHT)
    at = (FOOT[0] + spot[0] - 12, FOOT[1] + spot[1] - 12)
    out = Image.new("RGBA", (CELL, CELL))
    if behind:
        out.alpha_composite(g, at)
        out.alpha_composite(cell)
    else:
        out.alpha_composite(cell)
        out.alpha_composite(g, at)
    return out


def strip(pid, anim, rev, cat, frame):
    base = f"assets/characters/{pid}/{anim}"
    sheet = load(base + ".png", rev)
    if sheet is None:
        return None
    anchors = load(base + ".anchors.png", rev) if cat else None
    good = good_image(cat) if cat else None
    out = Image.new("RGBA", (CELL * 8, CELL))
    for d in range(8):
        out.alpha_composite(person_frame(sheet, anchors, good, d, frame), (d * CELL, 0))
    return out


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    pid = args[0]
    opts = dict(a[2:].split("=", 1) for a in sys.argv[1:] if a.startswith("--") and "=" in a)
    old_rev = opts.get("old", "HEAD")
    frame = int(opts.get("frame", "1"))
    anims = [("idle", None), ("walk", None)] + [("walk_carry_" + c, c) for c in CATS]
    folder = os.path.join(ROOT, "assets", "characters", pid)
    anims += [(f[:-4], None) for f in sorted(os.listdir(folder)) if f.startswith("work") and f.endswith(".png")]
    rows = []
    for anim, cat in anims:
        for rev in (old_rev, None):
            s = strip(pid, anim, rev, cat, frame)
            rows.append(s if s is not None else Image.new("RGBA", (CELL * 8, CELL)))
    sheet = Image.new("RGBA", (CELL * 8, CELL * len(rows)), (74, 98, 52, 255))
    for i, r in enumerate(rows):
        if i % 2 == 0:
            sheet.paste((84, 108, 60, 255), (0, i * CELL, CELL * 8, (i + 1) * CELL))
        sheet.alpha_composite(r, (0, i * CELL))
    sheet = sheet.resize((sheet.width * ZOOM, sheet.height * ZOOM), Image.NEAREST)
    out = opts.get("out", os.path.join(ROOT, "tools", "spritekiln", "previews", f"{pid}_vs_current_3x.png"))
    sheet.save(out)
    print(out, sheet.size)


if __name__ == "__main__":
    main()
