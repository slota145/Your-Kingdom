"""Write the SpriteKiln specs of the townsfolk (G3, ART_SPEC 10.27): art/specs/characters/<id>/<id>.yaml.

Every profession extends the common model art/specs/characters/civilian/civilian.yaml (clothes, idle, walk
and the 7 carry walks with the `load` socket) and adds its own colours, headwear, apron, tool and work moves.
Work moves are shared patterns (MOVES: a hammer blow, a hoe stroke, a reap...) played with the profession's
tool; the game's activity names (work_plow, work_build...) map onto them in ACTIVITIES.

Run: python3 tools/spritekiln/gen_civilians.py [<id> ...]
Then render each: cd tools/spritekiln/art/specs/characters/<id> && spritekiln render <id>.yaml
and copy into the game: python3 tools/spritekiln/export_civilian.py <id> ...
"""
import colorsys
import math as _m
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SPECS = os.path.join(HERE, "art", "specs", "characters")

# Six-tone ramps (index 0 = outline) for clothes.
RAMPS = {
    "brown": ["#140c06", "#33200f", "#55371b", "#77502a", "#996b3c", "#b88a55"],
    "straw": ["#1e1608", "#4a3a18", "#7a6630", "#a8904a", "#cdb46a", "#e8d48e"],
    "flax": ["#1a1610", "#463e30", "#73685a", "#9f927e", "#c4b8a0", "#e2d8c2"],
    "grey": ["#121212", "#2e2e30", "#4c4c50", "#6c6c70", "#8e8e92", "#b0b0b4"],
    "red": ["#1c0908", "#4a1512", "#7c221b", "#a63026", "#c64a34", "#dc7350"],
    "green": ["#0c140a", "#1e3418", "#2f5226", "#447036", "#5d8e4a", "#7caa64"],
    "leather": ["#120a05", "#2e1b0e", "#4a2e18", "#663f22", "#83552e", "#a06c3c"],
    "hose_dark": ["#120e0b", "#2a221c", "#40362c", "#584a3c", "#706050", "#8a7864"],
    "hose": ["#120e0b", "#2e2620", "#4a4035", "#665a4b", "#837563", "#a3937c"],
}



def ramp_from(rgb):
    """Six tones (index 0 = outline) around an old code-drawn colour (generate_characters.gd PEOPLE),
    the colour itself near tone 4; darker tones a little more saturated and shifted warm."""
    h, sat, v = colorsys.rgb_to_hsv(*rgb)
    tones = []
    for k, (vm, sm, dh) in enumerate([(0.17, 1.15, -0.02), (0.40, 1.10, -0.014), (0.62, 1.05, -0.007),
                                      (0.82, 1.0, 0.0), (1.0, 0.95, 0.004), (1.17, 0.85, 0.008)]):
        r, g, b = colorsys.hsv_to_rgb((h + dh) % 1.0, min(1.0, sat * sm), min(1.0, v * vm))
        tones.append("#%02x%02x%02x" % (round(r * 255), round(g * 255), round(b * 255)))
    return tones


# Shared work moves. Tools turn in the torso's frame at the fist (tool_pitch tips the haft forward from
# upright: 1.57 level ahead, more points it down to the ground; tool_yaw turns it about the body's axis).
# Each is a list of keys for an `animations.<clip>` block (the game plays work at
# 8 fps, so every key is one 125 ms frame and the clip loops). Hands are in the torso's space
# ([out from the body, up from the hips, forward]), feet on the ground ([out, up, forward]).
STANCE = "foot_L: [0.15, 0, 0.10], foot_R: [0.15, 0, -0.08]"
MOVES = {
    # one-handed hammer blows on something at chest height in front (builder, shipwright, smith)
    "hammer": [
        f"hand_R: [0.20, 0.36, 0.30], hand_L: [0.18, 0.30, 0.34], tool_pitch: 1.9, lean: 0.10, {STANCE}",
        f"hand_R: [0.24, 0.60, 0.12], hand_L: [0.18, 0.30, 0.34], tool_pitch: 0.6, lean: 0.02, {STANCE}",
        f"hand_R: [0.24, 0.80, -0.04], hand_L: [0.18, 0.30, 0.34], tool_pitch: -0.5, lean: -0.04, head_pitch: -0.06, {STANCE}",
        f"hand_R: [0.24, 0.80, -0.04], hand_L: [0.18, 0.30, 0.34], tool_pitch: -0.7, lean: -0.05, head_pitch: -0.06, {STANCE}",
        f"hand_R: [0.22, 0.52, 0.24], hand_L: [0.18, 0.30, 0.34], tool_pitch: 0.9, lean: 0.08, {STANCE}",
        f"hand_R: [0.20, 0.34, 0.32], hand_L: [0.18, 0.30, 0.34], tool_pitch: 2.0, lean: 0.12, bob: -0.01, {STANCE}",
    ],
    # a two-handed hoe raised over the shoulder and driven into the soil in front (plough, dig)
    "till": [
        f"hand_R: [0.14, 0.30, 0.28], hand_L: [0.08, 0.10, 0.36], tool_pitch: 2.5, lean: 0.30, bob: -0.03, {STANCE}",
        f"hand_R: [0.16, 0.48, 0.16], hand_L: [0.10, 0.30, 0.26], tool_pitch: 1.3, lean: 0.14, {STANCE}",
        f"hand_R: [0.16, 0.70, 0.02], hand_L: [0.10, 0.54, 0.12], tool_pitch: -0.4, lean: -0.02, head_pitch: -0.05, {STANCE}",
        f"hand_R: [0.16, 0.74, -0.02], hand_L: [0.10, 0.58, 0.08], tool_pitch: -0.6, lean: -0.04, head_pitch: -0.05, {STANCE}",
        f"hand_R: [0.15, 0.46, 0.22], hand_L: [0.09, 0.26, 0.32], tool_pitch: 1.6, lean: 0.20, {STANCE}",
        f"hand_R: [0.14, 0.28, 0.30], hand_L: [0.08, 0.08, 0.38], tool_pitch: 2.6, lean: 0.34, bob: -0.04, {STANCE}",
    ],
    # bent over, short pulls of the hoe through the soil (weeding)
    "scrape": [
        f"hand_R: [0.14, 0.24, 0.28], hand_L: [0.08, 0.06, 0.34], tool_pitch: 2.65, lean: 0.40, bob: -0.05, {STANCE}",
        f"hand_R: [0.14, 0.22, 0.25], hand_L: [0.08, 0.04, 0.31], tool_pitch: 2.75, lean: 0.40, bob: -0.05, {STANCE}",
        f"hand_R: [0.14, 0.20, 0.21], hand_L: [0.08, 0.02, 0.27], tool_pitch: 2.85, lean: 0.38, bob: -0.05, {STANCE}",
        f"hand_R: [0.14, 0.22, 0.25], hand_L: [0.08, 0.04, 0.31], tool_pitch: 2.75, lean: 0.40, bob: -0.05, {STANCE}",
    ],
    # bent low, the left hand gathers stalks, the sickle sweeps across under it (harvest)
    "reap": [
        f"hand_R: [0.34, 0.06, 0.20], hand_L: [0.10, 0.02, 0.40], tool_yaw: -0.9, tool_pitch: 1.5, twist: -0.25, lean: 0.48, bob: -0.08, {STANCE}",
        f"hand_R: [0.26, 0.02, 0.34], hand_L: [0.06, 0.04, 0.42], tool_yaw: -0.4, tool_pitch: 1.6, twist: -0.10, lean: 0.50, bob: -0.08, {STANCE}",
        f"hand_R: [0.04, 0.00, 0.42], hand_L: [0.06, 0.06, 0.40], tool_yaw: 0.3, tool_pitch: 1.6, twist: 0.12, lean: 0.52, bob: -0.08, {STANCE}",
        f"hand_R: [-0.06, 0.04, 0.36], hand_L: [0.10, 0.10, 0.36], tool_yaw: 0.8, tool_pitch: 1.5, twist: 0.20, lean: 0.48, bob: -0.08, {STANCE}",
        f"hand_R: [0.12, 0.10, 0.28], hand_L: [0.20, 0.16, 0.26], tool_yaw: 0.2, tool_pitch: 1.4, twist: 0.0, lean: 0.40, bob: -0.07, {STANCE}",
        f"hand_R: [0.30, 0.10, 0.18], hand_L: [0.12, 0.04, 0.38], tool_yaw: -0.6, tool_pitch: 1.5, twist: -0.20, lean: 0.46, bob: -0.08, {STANCE}",
    ],
    # sowing from a bag on the left hip: the right hand dips in, then flings the seed out in an arc
    "sow": [
        f"hand_R: [-0.02, 0.10, 0.18], hand_L: [0.26, 0.10, 0.10], seedbag: 1, twist: -0.18, lean: 0.10, {STANCE}",
        f"hand_R: [0.10, 0.30, 0.30], hand_L: [0.26, 0.10, 0.10], seedbag: 1, twist: -0.05, lean: 0.06, {STANCE}",
        f"hand_R: [0.34, 0.42, 0.30], hand_L: [0.26, 0.10, 0.10], seedbag: 1, twist: 0.15, lean: 0.04, {STANCE}",
        f"hand_R: [0.46, 0.36, 0.14], hand_L: [0.26, 0.10, 0.10], seedbag: 1, twist: 0.25, lean: 0.04, {STANCE}",
        f"hand_R: [0.34, 0.18, 0.08], hand_L: [0.26, 0.10, 0.10], seedbag: 1, twist: 0.10, lean: 0.06, {STANCE}",
        f"hand_R: [0.10, 0.08, 0.12], hand_L: [0.26, 0.10, 0.10], seedbag: 1, twist: -0.10, lean: 0.08, {STANCE}",
    ],
    # squat down to something on the ground, work at it with both hands, rise (bind a sheaf, plant)
    "stoop": [
        f"hand_R: [0.24, 0.10, 0.24], hand_L: [0.24, 0.10, 0.24], lean: 0.25, bob: -0.08, {STANCE}",
        f"hand_R: [0.18, -0.14, 0.40], hand_L: [0.18, -0.14, 0.40], lean: 0.55, bob: -0.20, head_pitch: 0.15, {STANCE}",
        f"hand_R: [0.06, -0.18, 0.42], hand_L: [0.20, -0.14, 0.38], lean: 0.58, bob: -0.22, head_pitch: 0.15, {STANCE}",
        f"hand_R: [0.20, -0.14, 0.38], hand_L: [0.06, -0.18, 0.42], lean: 0.58, bob: -0.22, head_pitch: 0.15, {STANCE}",
        f"hand_R: [0.06, -0.18, 0.42], hand_L: [0.20, -0.14, 0.38], lean: 0.58, bob: -0.22, head_pitch: 0.15, {STANCE}",
        f"hand_R: [0.18, -0.12, 0.40], hand_L: [0.18, -0.12, 0.40], lean: 0.50, bob: -0.18, head_pitch: 0.12, {STANCE}",
    ],
    # bend, grab a load from the ground with both hands, lift it to the chest and heave it forward (load, hand over)
    "lift": [
        f"hand_R: [0.20, -0.12, 0.36], hand_L: [0.20, -0.12, 0.36], lean: 0.55, bob: -0.20, head_pitch: 0.12, {STANCE}",
        f"hand_R: [0.20, -0.12, 0.36], hand_L: [0.20, -0.12, 0.36], lean: 0.55, bob: -0.21, head_pitch: 0.12, {STANCE}",
        f"hand_R: [0.20, 0.10, 0.30], hand_L: [0.20, 0.10, 0.30], lean: 0.30, bob: -0.10, {STANCE}",
        f"hand_R: [0.20, 0.32, 0.26], hand_L: [0.20, 0.32, 0.26], lean: 0.02, bob: 0.0, head_pitch: -0.05, {STANCE}",
        f"hand_R: [0.20, 0.42, 0.44], hand_L: [0.20, 0.42, 0.44], lean: 0.12, bob: 0.01, {STANCE}",
        f"hand_R: [0.24, 0.20, 0.30], hand_L: [0.24, 0.20, 0.30], lean: 0.25, bob: -0.08, {STANCE}",
    ],
}

MOVES.update({
    # a two-handed overhead swing (an axe at a trunk, a pick at the rock face)
    "chop": [
        f"hand_R: [0.10, 0.30, 0.36], hand_L: [0.04, 0.24, 0.34], tool_pitch: 1.6, lean: 0.24, bob: -0.03, {STANCE}",
        f"hand_R: [0.10, 0.62, 0.14], hand_L: [0.04, 0.56, 0.12], tool_pitch: 0.4, lean: 0.04, {STANCE}",
        f"hand_R: [0.09, 0.86, -0.08], hand_L: [0.04, 0.80, -0.08], tool_pitch: -0.7, lean: -0.08, head_pitch: -0.08, squash: 0.98, {STANCE}",
        f"hand_R: [0.09, 0.88, -0.10], hand_L: [0.04, 0.82, -0.10], tool_pitch: -0.9, lean: -0.10, head_pitch: -0.08, squash: 0.97, {STANCE}",
        f"hand_R: [0.08, 0.50, 0.30], hand_L: [0.04, 0.44, 0.28], tool_pitch: 0.9, lean: 0.16, squash: 1.02, {STANCE}",
        f"hand_R: [0.08, 0.26, 0.40], hand_L: [0.03, 0.20, 0.38], tool_pitch: 1.75, lean: 0.30, bob: -0.04, {STANCE}",
    ],
    # bent over a block at knee height: short hammer taps on a chisel held in the left hand (dressing stone, ore)
    "knock": [
        f"hand_R: [0.16, 0.02, 0.38], hand_L: [0.06, -0.04, 0.40], tool_pitch: 2.1, lean: 0.48, bob: -0.12, head_pitch: 0.15, {STANCE}",
        f"hand_R: [0.18, 0.16, 0.32], hand_L: [0.06, -0.04, 0.40], tool_pitch: 1.4, lean: 0.46, bob: -0.12, head_pitch: 0.15, {STANCE}",
        f"hand_R: [0.18, 0.26, 0.26], hand_L: [0.06, -0.04, 0.40], tool_pitch: 0.8, lean: 0.44, bob: -0.12, head_pitch: 0.15, {STANCE}",
        f"hand_R: [0.16, 0.04, 0.38], hand_L: [0.06, -0.04, 0.40], tool_pitch: 2.1, lean: 0.48, bob: -0.13, head_pitch: 0.15, {STANCE}",
    ],
    # both hands turn a winch handle round in front at waist height (hoist, wind)
    "crank": [
        f"hand_R: [0.12, 0.38, 0.34], hand_L: [0.04, 0.38, 0.34], lean: 0.12, {STANCE}",
        f"hand_R: [0.12, 0.30, 0.44], hand_L: [0.04, 0.30, 0.44], lean: 0.18, {STANCE}",
        f"hand_R: [0.12, 0.18, 0.44], hand_L: [0.04, 0.18, 0.44], lean: 0.22, bob: -0.02, {STANCE}",
        f"hand_R: [0.12, 0.10, 0.34], hand_L: [0.04, 0.10, 0.34], lean: 0.20, bob: -0.03, {STANCE}",
        f"hand_R: [0.12, 0.18, 0.24], hand_L: [0.04, 0.18, 0.24], lean: 0.14, bob: -0.02, {STANCE}",
        f"hand_R: [0.12, 0.30, 0.24], hand_L: [0.04, 0.30, 0.24], lean: 0.10, {STANCE}",
    ],
    # a spade: drive it in, lever the soil up and throw it aside (dig, muck out)
    "dig": [
        f"hand_R: [0.12, 0.26, 0.26], hand_L: [0.08, 0.06, 0.28], tool_pitch: 2.95, lean: 0.22, {STANCE}",
        f"hand_R: [0.12, 0.24, 0.27], hand_L: [0.08, 0.04, 0.29], tool_pitch: 3.0, lean: 0.26, bob: -0.05, {STANCE}",
        f"hand_R: [0.12, 0.36, 0.16], hand_L: [0.08, 0.20, 0.26], tool_pitch: 2.4, lean: 0.30, bob: -0.04, {STANCE}",
        f"hand_R: [0.14, 0.34, 0.18], hand_L: [0.08, 0.20, 0.28], tool_pitch: 2.1, lean: 0.20, {STANCE}",
        f"hand_R: [0.20, 0.40, 0.14], hand_L: [0.14, 0.26, 0.26], tool_pitch: 1.9, tool_yaw: 0.8, twist: 0.3, lean: 0.14, {STANCE}",
        f"hand_R: [0.12, 0.30, 0.20], hand_L: [0.08, 0.10, 0.26], tool_pitch: 2.7, twist: 0.1, lean: 0.18, {STANCE}",
    ],
    # standing at ease, both hands on top of a tool planted in the ground in front (a rest, the shepherd's watch)
    "lean": [
        f"hand_R: [0.10, 0.22, 0.30], hand_L: [0.06, 0.24, 0.30], tool_pitch: 3.05, lean: 0.06, head_yaw: 0.2, {STANCE}",
        f"hand_R: [0.10, 0.22, 0.30], hand_L: [0.06, 0.24, 0.30], tool_pitch: 3.05, lean: 0.06, head_yaw: 0.1, bob: -0.01, {STANCE}",
        f"hand_R: [0.10, 0.22, 0.30], hand_L: [0.06, 0.24, 0.30], tool_pitch: 3.05, lean: 0.06, head_yaw: -0.15, {STANCE}",
        f"hand_R: [0.10, 0.22, 0.30], hand_L: [0.06, 0.24, 0.30], tool_pitch: 3.05, lean: 0.06, head_yaw: -0.25, bob: -0.01, {STANCE}",
    ],
    # a staff upright at the side, the hand high on it, looking round over the flock
    "watch": [
        f"hand_R: [0.30, 0.30, 0.16], hand_L: [0.30, 0.04, 0.02], tool_pitch: 0.1, head_yaw: 0.3, {STANCE}",
        f"hand_R: [0.30, 0.30, 0.16], hand_L: [0.30, 0.04, 0.02], tool_pitch: 0.1, head_yaw: 0.1, bob: -0.01, {STANCE}",
        f"hand_R: [0.30, 0.30, 0.16], hand_L: [0.30, 0.04, 0.02], tool_pitch: 0.1, head_yaw: -0.15, {STANCE}",
        f"hand_R: [0.30, 0.30, 0.16], hand_L: [0.30, 0.04, 0.02], tool_pitch: 0.1, head_yaw: -0.3, bob: -0.01, {STANCE}",
    ],
    # a fishing rod swung back over the shoulder and whipped out over the water
    "cast": [
        f"hand_R: [0.18, 0.36, 0.30], hand_L: [0.10, 0.24, 0.26], tool_yaw: 0.4, tool_pitch: 1.0, lean: 0.08, {STANCE}",
        f"hand_R: [0.18, 0.62, 0.12], hand_L: [0.10, 0.30, 0.22], tool_pitch: 0.0, lean: -0.02, {STANCE}",
        f"hand_R: [0.18, 0.74, -0.02], hand_L: [0.10, 0.30, 0.22], tool_pitch: -0.7, lean: -0.08, head_pitch: -0.06, {STANCE}",
        f"hand_R: [0.18, 0.58, 0.24], hand_L: [0.10, 0.30, 0.24], tool_pitch: 0.6, lean: 0.10, {STANCE}",
        f"hand_R: [0.18, 0.40, 0.38], hand_L: [0.10, 0.28, 0.28], tool_yaw: 0.4, tool_pitch: 0.95, lean: 0.16, {STANCE}",
        f"hand_R: [0.18, 0.36, 0.34], hand_L: [0.10, 0.24, 0.28], tool_yaw: 0.4, tool_pitch: 1.0, lean: 0.10, {STANCE}",
    ],
    # holding the rod out still, waiting for a bite
    "hold": [
        f"hand_R: [0.18, 0.34, 0.32], hand_L: [0.10, 0.22, 0.28], tool_yaw: 0.4, tool_pitch: 1.15, lean: 0.06, {STANCE}",
        f"hand_R: [0.18, 0.34, 0.32], hand_L: [0.10, 0.22, 0.28], tool_yaw: 0.4, tool_pitch: 1.12, lean: 0.06, bob: -0.01, {STANCE}",
        f"hand_R: [0.18, 0.34, 0.32], hand_L: [0.10, 0.22, 0.28], tool_yaw: 0.4, tool_pitch: 1.15, lean: 0.06, head_yaw: 0.1, {STANCE}",
        f"hand_R: [0.18, 0.34, 0.32], hand_L: [0.10, 0.22, 0.28], tool_yaw: 0.4, tool_pitch: 1.18, lean: 0.06, bob: -0.01, {STANCE}",
    ],
    # the rod raised, the left hand winding the line in
    "reel": [
        f"hand_R: [0.18, 0.40, 0.30], hand_L: [0.08, 0.30, 0.30], tool_yaw: 0.4, tool_pitch: 0.8, lean: 0.0, {STANCE}",
        f"hand_R: [0.18, 0.40, 0.30], hand_L: [0.08, 0.24, 0.36], tool_yaw: 0.4, tool_pitch: 0.78, lean: 0.0, {STANCE}",
        f"hand_R: [0.18, 0.40, 0.30], hand_L: [0.08, 0.18, 0.30], tool_yaw: 0.4, tool_pitch: 0.76, lean: 0.02, {STANCE}",
        f"hand_R: [0.18, 0.40, 0.30], hand_L: [0.08, 0.24, 0.24], tool_yaw: 0.4, tool_pitch: 0.78, lean: 0.0, {STANCE}",
    ],
    # a knife at chest height, short strokes away from the body along a piece held in the left hand
    "whittle": [
        f"hand_R: [0.06, 0.34, 0.30], hand_L: [0.10, 0.34, 0.32], tool_pitch: 1.4, lean: 0.14, head_pitch: 0.15, {STANCE}",
        f"hand_R: [0.14, 0.34, 0.36], hand_L: [0.10, 0.34, 0.32], tool_pitch: 1.5, lean: 0.14, head_pitch: 0.15, {STANCE}",
        f"hand_R: [0.24, 0.32, 0.40], hand_L: [0.10, 0.34, 0.32], tool_pitch: 1.6, lean: 0.14, head_pitch: 0.15, {STANCE}",
        f"hand_R: [0.10, 0.34, 0.32], hand_L: [0.10, 0.34, 0.32], tool_pitch: 1.4, lean: 0.14, head_pitch: 0.15, {STANCE}",
    ],
    # long brush strokes along something at chest height in front (a horse's flank)
    "brush": [
        f"hand_R: [0.06, 0.42, 0.42], hand_L: [0.24, 0.46, 0.44], tool_pitch: 1.6, tool_yaw: -0.4, lean: 0.12, {STANCE}",
        f"hand_R: [0.16, 0.38, 0.44], hand_L: [0.24, 0.46, 0.44], tool_pitch: 1.6, tool_yaw: 0.0, lean: 0.12, {STANCE}",
        f"hand_R: [0.28, 0.32, 0.42], hand_L: [0.24, 0.46, 0.44], tool_pitch: 1.6, tool_yaw: 0.4, lean: 0.14, {STANCE}",
        f"hand_R: [0.18, 0.40, 0.40], hand_L: [0.24, 0.46, 0.44], tool_pitch: 1.6, tool_yaw: 0.1, lean: 0.12, {STANCE}",
    ],
    # a smoker held out over a hive, gently swung, the left hand lifting the lid
    "tend": [
        f"hand_R: [0.20, 0.18, 0.36], hand_L: [0.10, 0.10, 0.40], tool_pitch: 0.4, lean: 0.20, head_pitch: 0.1, {STANCE}",
        f"hand_R: [0.24, 0.24, 0.38], hand_L: [0.10, 0.12, 0.40], tool_pitch: 0.6, lean: 0.20, head_pitch: 0.1, {STANCE}",
        f"hand_R: [0.26, 0.28, 0.36], hand_L: [0.10, 0.14, 0.40], tool_pitch: 0.7, lean: 0.20, head_pitch: 0.1, {STANCE}",
        f"hand_R: [0.22, 0.22, 0.36], hand_L: [0.10, 0.12, 0.40], tool_pitch: 0.5, lean: 0.20, head_pitch: 0.1, {STANCE}",
    ],
    # the archer's draw (archer.yaml attack): nock, raise, draw to the cheek, hold, loose, lower
    "aim": [
        "arrow: 1, bow_x: -0.25, bow_z: 0.75, hand_L: [0.2, 0.18, 0.18], hand_R: [0.12, 0.2, 0.12]",
        "arrow: 1, bow_x: 0.25, bow_z: 2.75, bow_roll: -1.57, hand_L: [0.1, 0.42, 0.38], hand_R: [0.04, 0.4, 0.18], twist: -0.2",
        "arrow: 1, bow_x: 0, bow_z: 1.25, bow_roll: -1.57, hand_L: [0.05, 0.47, 0.5], hand_R: [-0.02, 0.5, -0.02], twist: -0.45, lean: -0.05, foot_L: [0.16, 0, 0.14], foot_R: [0.14, 0, -0.12]",
        "arrow: 1, bow_x: 0, bow_z: 1.25, bow_roll: -1.57, hand_L: [0.05, 0.47, 0.52], hand_R: [-0.03, 0.5, -0.06], twist: -0.5, lean: -0.05, foot_L: [0.16, 0, 0.14], foot_R: [0.14, 0, -0.12]",
        "arrow: 0, bow_x: 0, bow_z: 1.25, bow_roll: -1.57, hand_L: [0.05, 0.47, 0.54], hand_R: [-0.12, 0.52, -0.14], twist: -0.5, foot_L: [0.16, 0, 0.14], foot_R: [0.14, 0, -0.12]",
        "arrow: 0, bow_x: -0.25, bow_z: 1.25, bow_roll: 0, hand_L: [0.18, 0.22, 0.2], hand_R: [0.14, 0.16, 0.1]",
    ],
})

def _cycle(n, fn):
    """n keys of a periodic move: fn(k, a) with a = the key's angle round the cycle (0..2pi)."""
    return [fn(k, 2 * _m.pi * k / n) for k in range(n)]


def _f(x):
    return f"{x:.3f}".rstrip("0").rstrip(".") if abs(x) >= 0.0005 else "0"


# G3 part 2b: crafts and the town
MOVES.update({
    # both hands press and roll dough or clay on a table at waist height in front (knead, mould)
    "knead": [
        f"hand_R: [0.10, 0.24, 0.30], hand_L: [0.10, 0.24, 0.30], lean: 0.22, head_pitch: 0.12, {STANCE}",
        f"hand_R: [0.08, 0.18, 0.40], hand_L: [0.08, 0.18, 0.40], lean: 0.30, bob: -0.02, head_pitch: 0.15, {STANCE}",
        f"hand_R: [0.08, 0.14, 0.44], hand_L: [0.08, 0.14, 0.44], lean: 0.34, bob: -0.03, head_pitch: 0.15, {STANCE}",
        f"hand_R: [0.10, 0.22, 0.34], hand_L: [0.10, 0.22, 0.34], lean: 0.26, bob: -0.01, head_pitch: 0.12, {STANCE}",
    ],
    # a long tool held level, slid forward into an oven or a forge and drawn back (bake, fire a kiln, heat iron)
    "shove": [
        f"hand_R: [0.16, 0.30, 0.04], hand_L: [0.10, 0.33, 0.26], tool_pitch: 1.5, lean: 0.06, {STANCE}",
        f"hand_R: [0.15, 0.31, 0.16], hand_L: [0.09, 0.34, 0.38], tool_pitch: 1.52, lean: 0.14, {STANCE}",
        f"hand_R: [0.14, 0.32, 0.28], hand_L: [0.08, 0.35, 0.48], tool_pitch: 1.55, lean: 0.22, bob: -0.01, {STANCE}",
        f"hand_R: [0.14, 0.32, 0.30], hand_L: [0.08, 0.35, 0.50], tool_pitch: 1.57, lean: 0.24, bob: -0.02, {STANCE}",
        f"hand_R: [0.15, 0.31, 0.18], hand_L: [0.09, 0.34, 0.40], tool_pitch: 1.52, lean: 0.14, {STANCE}",
        f"hand_R: [0.16, 0.30, 0.06], hand_L: [0.10, 0.33, 0.28], tool_pitch: 1.5, lean: 0.08, {STANCE}",
    ],
    # both hands on a pole dipped into a vat in front, stirring round (mash, brew, mix)
    "stir": _cycle(6, lambda k, a:
        f"hand_R: [0.08, 0.50, {_f(0.20 + 0.07 * _m.cos(a))}], hand_L: [0.04, 0.31, {_f(0.27 + 0.07 * _m.cos(a))}], "
        f"tool_pitch: -0.35, twist: {_f(0.16 * _m.sin(a))}, lean: {_f(0.14 + 0.05 * _m.cos(a))}, head_pitch: 0.1, {STANCE}"),
    # a hand saw pushed and drawn through a board on a trestle, the left hand holding the board
    "saw": _cycle(6, lambda k, a:
        f"hand_R: [0.16, {_f(0.28 - 0.03 * _m.cos(a))}, {_f(0.18 + 0.14 * _m.cos(a))}], hand_L: [0.22, 0.20, 0.40], "
        f"tool_pitch: 1.95, lean: {_f(0.22 + 0.06 * _m.cos(a))}, head_pitch: 0.12, {STANCE}"),
    # the left hand high drawing out the fibre, the right twirling a spindle low (spinning)
    "spin": _cycle(4, lambda k, a:
        f"hand_L: [0.12, 0.60, 0.22], hand_R: [{_f(0.16 + 0.04 * _m.cos(a))}, {_f(0.22 + 0.03 * _m.sin(a))}, "
        f"{_f(0.26 + 0.04 * _m.sin(a))}], lean: 0.06, head_pitch: 0.08, {STANCE}"),
    # both hands at a loom at chest height: the shuttle thrown left and right, then the beater pulled in
    "weave": [
        f"hand_R: [0.10, 0.36, 0.38], hand_L: [0.10, 0.36, 0.38], twist: 0.2, lean: 0.10, {STANCE}",
        f"hand_R: [0.10, 0.36, 0.36], hand_L: [0.10, 0.36, 0.36], twist: 0.0, lean: 0.10, {STANCE}",
        f"hand_R: [0.10, 0.36, 0.38], hand_L: [0.10, 0.36, 0.38], twist: -0.2, lean: 0.10, {STANCE}",
        f"hand_R: [0.14, 0.38, 0.26], hand_L: [0.14, 0.38, 0.26], twist: 0.0, lean: 0.04, {STANCE}",
    ],
    # sewing: the cloth held up in the left hand, the right drawing the needle up and out in an arc
    "sew": [
        f"hand_L: [0.10, 0.34, 0.30], hand_R: [0.04, 0.34, 0.32], lean: 0.10, head_pitch: 0.18, {STANCE}",
        f"hand_L: [0.10, 0.34, 0.30], hand_R: [0.18, 0.46, 0.26], lean: 0.08, head_pitch: 0.14, {STANCE}",
        f"hand_L: [0.10, 0.34, 0.30], hand_R: [0.32, 0.56, 0.12], lean: 0.06, head_pitch: 0.1, {STANCE}",
        f"hand_L: [0.10, 0.34, 0.30], hand_R: [0.14, 0.40, 0.28], lean: 0.08, head_pitch: 0.16, {STANCE}",
    ],
    # cutting on a table at waist height: the left hand flat on the cloth, the right working forward along it
    "table": [
        f"hand_L: [0.06, 0.16, 0.40], hand_R: [0.18, 0.18, 0.26], tool_pitch: 1.65, lean: 0.30, head_pitch: 0.15, {STANCE}",
        f"hand_L: [0.06, 0.16, 0.40], hand_R: [0.17, 0.17, 0.32], tool_pitch: 1.7, lean: 0.32, head_pitch: 0.15, {STANCE}",
        f"hand_L: [0.06, 0.16, 0.40], hand_R: [0.16, 0.16, 0.38], tool_pitch: 1.7, lean: 0.34, head_pitch: 0.15, {STANCE}",
        f"hand_L: [0.06, 0.16, 0.40], hand_R: [0.17, 0.17, 0.32], tool_pitch: 1.65, lean: 0.32, head_pitch: 0.15, {STANCE}",
    ],
    # lift something up from the waist and hold it out to a customer, the left hand on the hip (serve, sell)
    "serve": [
        f"hand_R: [0.24, 0.16, 0.14], hand_L: [0.32, 0.14, -0.02], lean: 0.06, {STANCE}",
        f"hand_R: [0.20, 0.28, 0.28], hand_L: [0.32, 0.14, -0.02], lean: 0.08, {STANCE}",
        f"hand_R: [0.16, 0.38, 0.40], hand_L: [0.32, 0.14, -0.02], lean: 0.12, head_pitch: -0.04, {STANCE}",
        f"hand_R: [0.16, 0.38, 0.42], hand_L: [0.32, 0.14, -0.02], lean: 0.12, head_pitch: -0.04, {STANCE}",
        f"hand_R: [0.16, 0.37, 0.41], hand_L: [0.32, 0.14, -0.02], lean: 0.12, head_yaw: 0.15, {STANCE}",
        f"hand_R: [0.20, 0.26, 0.26], hand_L: [0.32, 0.14, -0.02], lean: 0.08, {STANCE}",
    ],
    # both hands pump a bellows lever up and down at the side of a furnace
    "pump": [
        f"hand_R: [0.16, 0.44, 0.28], hand_L: [0.08, 0.44, 0.30], lean: 0.08, {STANCE}",
        f"hand_R: [0.16, 0.30, 0.30], hand_L: [0.08, 0.30, 0.32], lean: 0.18, bob: -0.02, {STANCE}",
        f"hand_R: [0.16, 0.14, 0.32], hand_L: [0.08, 0.14, 0.34], lean: 0.30, bob: -0.05, {STANCE}",
        f"hand_R: [0.16, 0.30, 0.30], hand_L: [0.08, 0.30, 0.32], lean: 0.18, bob: -0.02, {STANCE}",
    ],
    # reach up for the beam of a press and haul it down with the whole body (wine press)
    "press": [
        f"hand_R: [0.14, 0.72, 0.22], hand_L: [0.08, 0.72, 0.22], lean: -0.04, head_pitch: -0.08, {STANCE}",
        f"hand_R: [0.14, 0.60, 0.26], hand_L: [0.08, 0.60, 0.26], lean: 0.08, {STANCE}",
        f"hand_R: [0.14, 0.42, 0.32], hand_L: [0.08, 0.42, 0.32], lean: 0.24, bob: -0.03, {STANCE}",
        f"hand_R: [0.14, 0.26, 0.36], hand_L: [0.08, 0.26, 0.36], lean: 0.38, bob: -0.06, {STANCE}",
        f"hand_R: [0.14, 0.24, 0.36], hand_L: [0.08, 0.24, 0.36], lean: 0.40, bob: -0.07, {STANCE}",
        f"hand_R: [0.14, 0.50, 0.28], hand_L: [0.08, 0.50, 0.28], lean: 0.14, {STANCE}",
    ],
    # a long pole thrust down into a fire or a kiln in front and drawn back (tend a fire)
    "poke": [
        f"hand_R: [0.14, 0.34, 0.14], hand_L: [0.06, 0.18, 0.36], tool_pitch: -0.9, lean: 0.14, {STANCE}",
        f"hand_R: [0.14, 0.30, 0.24], hand_L: [0.06, 0.13, 0.46], tool_pitch: -0.95, lean: 0.22, bob: -0.02, {STANCE}",
        f"hand_R: [0.14, 0.28, 0.30], hand_L: [0.06, 0.10, 0.52], tool_pitch: -1.0, lean: 0.28, bob: -0.03, {STANCE}",
        f"hand_R: [0.14, 0.32, 0.20], hand_L: [0.06, 0.15, 0.42], tool_pitch: -0.95, lean: 0.18, {STANCE}",
    ],
    # a staff raised forward to point at a board, tapping it (the teacher)
    "point": [
        f"hand_R: [0.22, 0.46, 0.24], hand_L: [0.31, 0.06, 0.04], tool_pitch: -2.05, lean: 0.02, head_pitch: -0.05, {STANCE}",
        f"hand_R: [0.22, 0.48, 0.28], hand_L: [0.31, 0.06, 0.04], tool_pitch: -2.15, lean: 0.04, head_pitch: -0.05, {STANCE}",
        f"hand_R: [0.22, 0.46, 0.24], hand_L: [0.31, 0.06, 0.04], tool_pitch: -2.05, lean: 0.02, head_yaw: 0.25, {STANCE}",
        f"hand_R: [0.22, 0.47, 0.26], hand_L: [0.31, 0.06, 0.04], tool_pitch: -2.1, lean: 0.02, head_yaw: 0.25, {STANCE}",
    ],
    # a hand bell held up at the side and rung back and forth
    "ring": [
        f"hand_R: [0.26, 0.48, 0.16], hand_L: [0.31, 0.06, 0.04], tool_pitch: 0.5, {STANCE}",
        f"hand_R: [0.26, 0.50, 0.22], hand_L: [0.31, 0.06, 0.04], tool_pitch: -0.1, {STANCE}",
        f"hand_R: [0.26, 0.48, 0.28], hand_L: [0.31, 0.06, 0.04], tool_pitch: -0.6, {STANCE}",
        f"hand_R: [0.26, 0.50, 0.22], hand_L: [0.31, 0.06, 0.04], tool_pitch: 0.0, {STANCE}",
    ],
    # an open book held in both hands at the chest, the head bowed over it
    "read": [
        f"hand_R: [0.14, 0.28, 0.34], hand_L: [0.14, 0.28, 0.34], tool_pitch: 0.2, lean: 0.06, head_pitch: 0.24, {STANCE}",
        f"hand_R: [0.14, 0.28, 0.34], hand_L: [0.14, 0.28, 0.34], tool_pitch: 0.2, lean: 0.06, head_pitch: 0.26, head_yaw: 0.08, bob: -0.01, {STANCE}",
        f"hand_R: [0.14, 0.28, 0.34], hand_L: [0.14, 0.28, 0.34], tool_pitch: 0.2, lean: 0.06, head_pitch: 0.26, head_yaw: -0.06, {STANCE}",
        f"hand_R: [0.14, 0.29, 0.34], hand_L: [0.14, 0.29, 0.34], tool_pitch: 0.15, lean: 0.06, head_pitch: 0.22, bob: -0.01, {STANCE}",
    ],
    # writing at a lectern: the left hand steadying the page, the right moving the quill in short strokes
    "write": [
        f"hand_L: [0.10, 0.30, 0.38], hand_R: [0.02, 0.32, 0.36], tool_pitch: 0.7, lean: 0.18, head_pitch: 0.22, {STANCE}",
        f"hand_L: [0.10, 0.30, 0.38], hand_R: [0.06, 0.31, 0.37], tool_pitch: 0.75, lean: 0.18, head_pitch: 0.22, {STANCE}",
        f"hand_L: [0.10, 0.30, 0.38], hand_R: [-0.02, 0.32, 0.35], tool_pitch: 0.65, lean: 0.18, head_pitch: 0.22, {STANCE}",
        f"hand_L: [0.10, 0.30, 0.38], hand_R: [0.03, 0.33, 0.36], tool_pitch: 0.7, lean: 0.18, head_pitch: 0.24, {STANCE}",
    ],
    # hands clasped behind the back, looking round, deep in thought (the scholar's rest)
    "muse": [
        f"hand_R: [0.16, 0.14, -0.16], hand_L: [0.16, 0.14, -0.16], lean: -0.02, head_yaw: 0.25, {STANCE}",
        f"hand_R: [0.16, 0.14, -0.16], hand_L: [0.16, 0.14, -0.16], lean: -0.02, head_yaw: 0.1, head_pitch: -0.05, bob: -0.01, {STANCE}",
        f"hand_R: [0.16, 0.14, -0.16], hand_L: [0.16, 0.14, -0.16], lean: -0.02, head_yaw: -0.1, head_pitch: -0.05, {STANCE}",
        f"hand_R: [0.16, 0.14, -0.16], hand_L: [0.16, 0.14, -0.16], lean: -0.02, head_yaw: -0.25, bob: -0.01, {STANCE}",
    ],
})

# Activity (the game's work_<activity>) -> (move, tool): tool None = the profession's own, "" = empty hands.
ACTIVITIES = {
    "build": ("hammer", None), "plow": ("till", "hoe"), "weed": ("scrape", "hoe"), "harvest": ("reap", "sickle"),
    "sow": ("sow", ""), "bind": ("stoop", ""), "load": ("lift", ""), "hand_over": ("lift", ""),
    "chop": ("chop", "axe"), "hew": ("chop", "pick"), "pick": ("chop", "pick"), "shape": ("knock", "hammer"),
    "hoist": ("crank", ""), "wind": ("crank", ""), "descend": ("stoop", ""),
    "dig": ("dig", "spade"), "muck": ("dig", "spade"), "plant": ("stoop", ""), "rest": ("lean", None),
    "cast": ("cast", "rod"), "wait_bite": ("hold", "rod"), "reel": ("reel", "rod"),
    "carve": ("whittle", "knife"), "skin": ("stoop", "knife"), "bend": ("stoop", ""), "aim": ("aim", "bow"),
    "herd": ("watch", "crook"), "shear": ("stoop", "shears"), "feed": ("sow", ""),
    "groom": ("brush", "brush"), "tend_hives": ("tend", "smoker"), "collect_honey": ("stoop", ""),
    # G3 part 2b
    "grind": ("crank", ""), "knead": ("knead", ""), "bake": ("shove", "peel"), "mash": ("stir", "paddle"),
    "brew": ("stir", "paddle"), "mix": ("stir", "paddle"), "ferment": ("lift", ""), "press": ("press", ""),
    "saw": ("saw", "saw"), "spin": ("spin", ""), "weave": ("weave", ""), "cut": ("table", "shears"), "sew": ("sew", ""),
    "mould": ("knead", ""), "fire": ("shove", "spade"), "serve": ("serve", "mug"), "sell": ("serve", ""),
    "hammer": ("hammer", "hammer"), "stack": ("lift", ""), "tend_fire": ("poke", "staff"), "tap": ("stoop", ""),
    "rake": ("scrape", "rake"), "slaughter": ("chop", "axe"), "bellows": ("pump", ""), "heat": ("shove", "tongs"),
    "forge": ("hammer", "hammer"), "quench": ("stoop", "tongs"), "rivet": ("knock", "hammer"), "polish": ("brush", ""),
    "string": ("weave", ""), "teach": ("point", "staff"), "ring": ("ring", "bell"), "read": ("read", "book"),
    "write": ("write", "quill"),
}
FARM = ["plow", "sow", "harvest", "bind", "weed"]

# Tools: a kit from art/specs/kits or a built-in one, with its params; the moves drive `pitch` through tool_pitch.
TOOLS = {
    "hammer": "{kit: hammer, as: tool, at: wrist_R, with: {length: 0.30, head: 0.06, width: 0.065, tilt: 0.3, pitch: tool_pitch, cheat: tool_cheat}}",
    "hoe": "{kit: hoe, as: tool, at: wrist_R, with: {pitch: tool_pitch}}",
    "sickle": "{kit: sickle, as: tool, at: wrist_R, with: {pitch: tool_pitch}}",
    "axe": "{kit: axe, as: tool, at: wrist_R, with: {length: 0.62, cheat: 0}}",
    "pick": "{kit: pick, as: tool, at: wrist_R}",
    "spade": "{kit: spade, as: tool, at: wrist_R}",
    "rod": "{kit: rod, as: tool, at: wrist_R}",
    "knife": "{kit: knife, as: tool, at: wrist_R}",
    "shears": "{kit: shears, as: tool, at: wrist_R}",
    "crook": "{kit: crook, as: tool, at: wrist_R}",
    "brush": "{kit: brush, as: tool, at: wrist_R}",
    "smoker": "{kit: smoker, as: tool, at: wrist_R}",
    "bow": "{kit: bow, as: tool, at: wrist_L, with: {length: 1.3, depth: 0.17, thick: 0.06, cheat: 0}}",
}
for _t in ("peel", "paddle", "saw", "mug", "tongs", "rake", "staff", "bell", "book", "quill"):
    TOOLS[_t] = "{kit: %s, as: tool, at: wrist_R}" % _t

# Headwear parts (head space; the head kit's crown is near y 0.33 head units).
HEADWEAR = {
    "kerchief": """  kerchief:          # a cloth tied over the whole hair, the knot at the nape (no hair kit under it)
    material: hat_m
    space: head
    blend: 0.02
    prims:
      - ellipsoid: {c: [0, 0.185, -0.025], r: [0.155, 0.135, 0.165]}
      - sphere: {c: [0, 0.10, -0.19], r: 0.04}
    cut:
      - plane: {n: [0, -0.55, 1], c: [0, 0.16, 0.09]}
""",
    "straw": """  hat_brim:           # a straw hat with a moderate brim
    material: hat_m
    space: head
    prims:
      - cylinder: {a: [0, 0.255, -0.02], b: [0, 0.278, -0.02], r: 0.24}
  hat_crown:
    material: hat_m
    space: head
    prims:
      - cone: {a: [0, 0.26, -0.02], b: [0, 0.36, -0.03], r: [0.155, 0.12]}
""",
    "cap": """  cap:                # a round felt cap over the crown
    material: hat_m
    space: head
    blend: 0.015
    prims:
      - ellipsoid: {c: [0, 0.19, -0.025], r: [0.16, 0.135, 0.17]}
    cut:
      - plane: {n: [0, -1, 0], c: [0, 0.19, 0]}
  cap_rim:
    material: hat_m
    space: head
    prims:
      - cylinder: {a: [0, 0.175, -0.03], b: [0, 0.205, -0.025], r: 0.17}
""",
}

HEADWEAR.update({
    "wide": """  hat_brim:           # a wide felt hat with a low round crown
    material: hat_m
    space: head
    prims:
      - cylinder: {a: [0, 0.25, -0.02], b: [0, 0.272, -0.02], r: 0.25}
  hat_crown:
    material: hat_m
    space: head
    blend: 0.02
    prims:
      - ellipsoid: {c: [0, 0.27, -0.025], r: [0.155, 0.1, 0.16]}
    cut:
      - plane: {n: [0, -1, 0], c: [0, 0.26, 0]}
""",
    "veil": """  hat_brim:           # a beekeeper's straw hat with a pale veil hanging round the head
    material: hat_m
    space: head
    prims:
      - cylinder: {a: [0, 0.26, -0.02], b: [0, 0.282, -0.02], r: 0.23}
  hat_crown:
    material: hat_m
    space: head
    prims:
      - cone: {a: [0, 0.27, -0.02], b: [0, 0.36, -0.03], r: [0.15, 0.12]}
  veil:
    material: veil_m
    space: head
    prims:
      - cone: {a: [0, 0.26, -0.02], b: [0, -0.04, -0.01], r: [0.215, 0.17], shell: 0.045}
""",
    "beret": """  cap:                # the miller's soft floury cap, broad and flat, slumped to one side
    material: hat_m
    space: head
    blend: 0.02
    prims:
      - ellipsoid: {c: [0.03, 0.235, -0.04], r: [0.2, 0.085, 0.2]}
  cap_rim:
    material: hat_m
    space: head
    prims:
      - cylinder: {a: [0, 0.17, -0.03], b: [0, 0.205, -0.025], r: 0.168}
""",
    "toque": """  cap:                # the baker's tall puffed white cap
    material: hat_m
    space: head
    blend: 0.03
    prims:
      - ellipsoid: {c: [0, 0.31, -0.03], r: [0.175, 0.15, 0.175]}
  cap_rim:
    material: hat_m
    space: head
    prims:
      - cylinder: {a: [0, 0.17, -0.03], b: [0, 0.22, -0.025], r: 0.168}
""",
    "hood": "",   # the hood kit (HOOD_USE)
    "none": "",
})

# The hair kit under each headwear (replaces the base's `hair` use).
HAIR = {
    "kerchief": None,
    "wide": "{kit: hair, at: head, with: {fringe: 0.4, part: 0.2, locks: 0.5, length: 0.2, volume: 0.8}}",
    "veil": "{kit: hair, at: head, with: {fringe: 0.3, part: 0.1, locks: 0.3, length: 0.1, volume: 0.7}}",
    "hood": "{kit: hair, at: head, with: {fringe: 0.4, part: 0.2, locks: 0.3, length: 0.1, volume: 0.7}}",
    "none": "{kit: hair, at: head, with: {fringe: 0.4, part: 0.2, locks: 0.5, length: 0.2, volume: 0.9}}",
    "cap": "{kit: hair, at: head, with: {fringe: 0.3, part: 0.1, locks: 0.4, length: 0.15, volume: 0.7}}",
    "straw": "{kit: hair, at: head, with: {fringe: 0.4, part: 0.2, locks: 0.5, length: 0.2, volume: 0.8}}",
    "beret": "{kit: hair, at: head, with: {fringe: 0.3, part: 0.1, locks: 0.4, length: 0.15, volume: 0.7}}",
    "toque": "{kit: hair, at: head, with: {fringe: 0.3, part: 0.1, locks: 0.4, length: 0.15, volume: 0.7}}",
}

HOOD_USE = "{kit: hood, as: hood, at: head, with: {size: 0.9, depth: 0.2, tip: 0.1, tilt: -0.25, mantle: false}, materials: {hood: hat_m}}"

BEARD = """  beard:              # a full short beard on the jaw and chin
    material: hair
    space: head
    blend: 0.02
    prims:
      - ellipsoid: {c: [0, 0.01, 0.075], r: [0.095, 0.065, 0.06]}
      - ellipsoid: {c: [0, -0.035, 0.085], r: [0.06, 0.05, 0.045]}
"""

CLOAK_USE = "{kit: cape, as: cloak, at: pelvis, with: {length: 0.62, width: 0.44, flare: 0.16, drape: 0.08, dip: 0.15}, materials: {cape: cloak_m}}"

QUIVER = """  quiver:             # on the back, arrows sticking up over the right shoulder (as the archer's)
    material: leather
    space: torso_rot
    prims:
      - cylinder: {a: [-0.08, 0.05, -0.2], b: [-0.17, 0.52, -0.23], r: 0.055}
  quiver_arrows:
    material: feather
    space: torso_rot
    min_cover: 2
    prims:
      - cone: {a: [-0.17, 0.5, -0.23], b: [-0.21, 0.66, -0.25], r: [0.045, 0.03]}
  nocked:             # the arrow while drawing: from the string hand past the bow
    material: wood
    when: "arrow > 0.5"
    priority: 3
    min_cover: 2
    prims:
      - cylinder: {a: "@wrist_R", b: {between: ["@wrist_R", "@wrist_L"], t: 1.25}, r: 0.018}
"""

APRON = """  apron:              # a leather or linen apron from the belt to the knees
    material: apron_m
    space: coatbase
    prims:
      - box: {c: [0, -0.10, 0.17], half: [0.15, 0.22, 0.012], rot: [0.08, 0, 0]}
"""

# Long clothes (G3 part 2b): a dress (the skirt in the hose colour, women) or a gown (the shirt colour, the
# teacher, the scholar, the merchant) to the ankles, wide enough at the hem to hide the stride.
SKIRT = """  coat:               # {what} to the ankles, flaring a little at the hem
    material: {mat}
    space: coatbase
    blend: 0.03
    prims:
      - cone: {{a: [0, 0.05, -0.01], b: [0, -0.70, -0.03], r: [0.2, 0.3]}}
    cut:
      - plane: {{n: [0, -1, 0], c: [0, -0.74, 0]}}
"""

# An apron on a long skirt is painted on its front (a separate plate would stand off the flaring hem).
SKIRT_APRON = """    paint:
      - material: apron_m
        prims:
          - box: {c: [0, -0.3, 0.3], half: [0.15, 0.37, 0.16]}
"""

SEEDBAG = """  seedbag:            # the seed bag on the left hip while sowing
    material: apron_m
    space: pelvis
    when: "seedbag > 0.5"
    blend: 0.02
    prims:
      - ellipsoid: {c: [0.22, 0.02, 0.06], r: [0.09, 0.11, 0.09]}
      - cylinder: {a: [0.22, 0.10, 0.06], b: [-0.12, 0.52, 0.0], r: 0.018}
"""

# Looks: a ramp name from RAMPS or an old code-drawn RGB colour (generate_characters.gd PEOPLE) for
# shirt, hose, hat, apron, hair and cloak; headwear from HEADWEAR; activities as the game names them.
PROFESSIONS = {
    "porter": {"summary": "porter: a brown wool jerkin, grey hose, a red kerchief over the hair",
               "shirt": "brown", "hose": "hose", "hat": "kerchief", "hat_ramp": "red",
               "activities": ["load"]},
    "farmer": {"summary": "farmer: an undyed linen smock, brown hose, a wide straw hat",
               "shirt": "flax", "hose": "hose_dark", "hat": "straw", "hat_ramp": "straw", "apron_ramp": "brown",
               "activities": FARM},
    "builder": {"summary": "builder: a grey shirt, a leather apron, a green felt cap, a carpenter's hammer",
                "shirt": "grey", "hose": "hose", "hat": "cap", "hat_ramp": "green", "apron": True,
                "apron_ramp": "leather", "tool": "hammer", "activities": ["build"]},
    # G3 part 2a: raw materials and farming
    "woodcutter": {"summary": "woodcutter: a red wool shirt, a full beard, an axe",
                   "shirt": (0.72, 0.2, 0.16), "hose": (0.32, 0.28, 0.22), "hair": (0.35, 0.22, 0.12),
                   "hat": "none", "beard": True, "activities": ["chop", "bind"]},
    "forester": {"summary": "forester: a green shirt and cap, a spade for planting saplings",
                 "shirt": (0.3, 0.5, 0.28), "hose": (0.36, 0.3, 0.22), "hair": (0.4, 0.26, 0.14),
                 "hat": "cap", "hat_ramp": (0.22, 0.38, 0.2), "tool": "spade", "activities": ["dig", "plant", "rest"]},
    "stonecutter": {"summary": "stonecutter: a grey shirt, a leather apron, a grey beard, a pick and a mallet",
                    "shirt": (0.58, 0.6, 0.62), "hose": (0.32, 0.3, 0.28), "hair": (0.3, 0.3, 0.3),
                    "hat": "none", "beard": True, "apron": True, "apron_ramp": (0.5, 0.36, 0.22),
                    "activities": ["hew", "shape", "hoist"]},
    "miner": {"summary": "miner: a brown shirt, a leather cap and apron, a beard, a pick",
              "shirt": (0.55, 0.42, 0.3), "hose": (0.3, 0.27, 0.24), "hair": (0.28, 0.2, 0.14),
              "hat": "cap", "hat_ramp": (0.38, 0.27, 0.17), "beard": True, "apron": True,
              "apron_ramp": (0.42, 0.3, 0.2), "activities": ["pick", "shape", "descend", "wind"]},
    "clay_digger": {"summary": "clay digger: a clay-coloured shirt and kerchief, a spade",
                    "shirt": (0.66, 0.5, 0.4), "hose": (0.45, 0.35, 0.28), "hair": (0.25, 0.18, 0.12),
                    "hat": "kerchief", "hat_ramp": (0.55, 0.4, 0.3), "activities": ["dig"]},
    "fisher": {"summary": "fisher: a blue shirt, a wide yellow hat, a beard; hauls in the catch",
               "shirt": (0.3, 0.42, 0.55), "hose": (0.36, 0.33, 0.3), "hair": (0.55, 0.42, 0.25),
               "hat": "wide", "hat_ramp": (0.75, 0.62, 0.3), "beard": True, "activities": [], "work": "lift"},
    "angler": {"summary": "angler: a light blue shirt, a wide hat, a fishing rod",
               "shirt": (0.36, 0.5, 0.7), "hose": (0.4, 0.36, 0.3), "hair": (0.5, 0.36, 0.2),
               "hat": "wide", "hat_ramp": (0.55, 0.45, 0.3), "activities": ["cast", "wait_bite", "reel"]},
    "hunter": {"summary": "hunter: a drab tunic, a green hood, a quiver on the back, a bow and a knife",
               "shirt": (0.4, 0.36, 0.24), "hose": (0.3, 0.26, 0.2), "hair": (0.3, 0.2, 0.12),
               "hat": "hood", "hat_ramp": (0.26, 0.34, 0.2), "quiver": True, "tool": "knife",
               "activities": ["carve", "skin", "bend", "aim"]},
    "shepherd": {"summary": "shepherd: an undyed wool shirt and cloak, a wide hat, a grey beard, a crook",
                 "shirt": (0.72, 0.66, 0.54), "hose": (0.42, 0.36, 0.28), "hair": (0.5, 0.45, 0.4),
                 "hat": "wide", "hat_ramp": (0.45, 0.35, 0.24), "beard": True, "cloak": (0.55, 0.5, 0.42),
                 "tool": "crook", "activities": ["herd", "shear"]},
    "swineherd": {"summary": "swineherd: a tan shirt, a straw hat, a spade for mucking out",
                  "shirt": (0.6, 0.52, 0.36), "hose": (0.38, 0.3, 0.22), "hair": (0.55, 0.38, 0.2),
                  "hat": "straw", "hat_ramp": "straw", "apron_ramp": "brown", "activities": ["feed", "muck"]},
    "groom": {"summary": "groom: a tan shirt, blue hose, a wide hat, a curry brush",
              "shirt": (0.6, 0.48, 0.32), "hose": (0.3, 0.3, 0.36), "hair": (0.45, 0.3, 0.16),
              "hat": "wide", "hat_ramp": (0.42, 0.3, 0.18), "apron_ramp": "brown", "activities": ["feed", "groom"]},
    "beekeeper": {"summary": "beekeeper: a pale smock, a straw hat with a veil, a smoker",
                  "shirt": (0.9, 0.86, 0.72), "hose": (0.6, 0.55, 0.45), "hair": (0.45, 0.3, 0.15),
                  "hat": "veil", "hat_ramp": (0.88, 0.78, 0.48), "activities": ["tend_hives", "collect_honey"]},
    "orchardist": {"summary": "orchardist: a green smock, a straw hat",
                   "shirt": (0.42, 0.56, 0.3), "hose": (0.4, 0.33, 0.24), "hair": (0.45, 0.3, 0.16),
                   "hat": "straw", "hat_ramp": "straw", "apron_ramp": "brown", "activities": FARM},
    "hop_grower": {"summary": "hop grower: a leaf-green smock, a straw hat",
                   "shirt": (0.42, 0.58, 0.32), "hose": (0.38, 0.32, 0.24), "hair": (0.3, 0.2, 0.12),
                   "hat": "straw", "hat_ramp": "straw", "apron_ramp": "brown", "activities": FARM},
    "winegrower": {"summary": "winegrower: a violet smock, a straw hat",
                   "shirt": (0.55, 0.42, 0.62), "hose": (0.38, 0.32, 0.24), "hair": (0.3, 0.2, 0.12),
                   "hat": "straw", "hat_ramp": "straw", "apron_ramp": "brown", "activities": FARM},
    "carter": {"summary": "carter: a green shirt, a wide hat, a beard",
               "shirt": (0.42, 0.5, 0.36), "hose": (0.34, 0.28, 0.22), "hair": (0.35, 0.24, 0.14),
               "hat": "wide", "hat_ramp": (0.4, 0.3, 0.2), "beard": True, "activities": ["load"]},
    "docker": {"summary": "docker: a pale shirt, blue hose, a red kerchief, a leather apron",
               "shirt": (0.62, 0.58, 0.5), "hose": (0.25, 0.28, 0.38), "hair": (0.25, 0.17, 0.1),
               "hat": "kerchief", "hat_ramp": (0.6, 0.2, 0.18), "apron": True, "apron_ramp": (0.42, 0.32, 0.22),
               "activities": ["hand_over"]},
    # G3 part 2b: crafts and the town
    "miller": {"summary": "miller: a floury pale shirt and apron, a soft white cap",
               "shirt": (0.86, 0.84, 0.78), "hose": (0.55, 0.5, 0.42), "hair": (0.55, 0.42, 0.25),
               "hat": "beret", "hat_ramp": (0.9, 0.89, 0.84), "apron": True, "apron_ramp": (0.93, 0.92, 0.88),
               "activities": ["grind"]},
    "baker": {"summary": "baker: a tan shirt, a white apron and a tall white cap, a peel",
              "shirt": (0.8, 0.62, 0.45), "hose": (0.4, 0.33, 0.26), "hair": (0.25, 0.17, 0.1),
              "hat": "toque", "hat_ramp": (0.92, 0.91, 0.88), "apron": True, "apron_ramp": (0.94, 0.93, 0.9),
              "activities": ["knead", "bake"]},
    "brewer": {"summary": "brewer: a straw shirt, a red cap, a brown apron, a mash paddle",
               "shirt": (0.82, 0.74, 0.55), "hose": (0.42, 0.32, 0.24), "hair": (0.6, 0.3, 0.15),
               "hat": "cap", "hat_ramp": (0.55, 0.25, 0.2), "apron": True, "apron_ramp": (0.48, 0.32, 0.2),
               "activities": ["mash", "brew"]},
    "mead_maker": {"summary": "mead maker: a honey-yellow shirt, an amber cap, a brown apron, a paddle",
                   "shirt": (0.85, 0.65, 0.3), "hose": (0.42, 0.32, 0.24), "hair": (0.35, 0.22, 0.12),
                   "hat": "cap", "hat_ramp": (0.6, 0.4, 0.15), "apron": True, "apron_ramp": (0.5, 0.34, 0.2),
                   "activities": ["mix", "ferment"]},
    "vintner": {"summary": "vintner: a pale shirt, a wine-red cap and a wine-stained apron",
                "shirt": (0.86, 0.8, 0.68), "hose": (0.4, 0.3, 0.24), "hair": (0.2, 0.14, 0.1),
                "hat": "cap", "hat_ramp": (0.5, 0.12, 0.18), "apron": True, "apron_ramp": (0.48, 0.14, 0.2),
                "activities": ["press", "ferment"]},
    "sawyer": {"summary": "sawyer: a green shirt and cap, a hand saw",
               "shirt": (0.38, 0.52, 0.36), "hose": (0.4, 0.33, 0.24), "hair": (0.55, 0.38, 0.2),
               "hat": "cap", "hat_ramp": (0.3, 0.4, 0.28), "activities": ["saw"]},
    "blacksmith": {"summary": "blacksmith: a dark grey shirt, a heavy leather apron, a black beard, a hammer and tongs",
                   "shirt": (0.4, 0.4, 0.42), "hose": (0.28, 0.25, 0.22), "hair": (0.15, 0.11, 0.09),
                   "hat": "none", "beard": True, "apron": True, "apron_ramp": (0.38, 0.26, 0.16), "tool": "hammer",
                   "activities": ["heat", "forge", "quench"]},
    "smelter": {"summary": "smelter: a rust shirt, a dark cap, a heavy leather apron",
                "shirt": (0.66, 0.4, 0.3), "hose": (0.32, 0.27, 0.23), "hair": (0.4, 0.24, 0.12),
                "hat": "cap", "hat_ramp": (0.3, 0.24, 0.2), "apron": True, "apron_ramp": (0.36, 0.25, 0.16),
                "activities": ["stack", "bellows", "tap"]},
    "armourer": {"summary": "armourer: a steel-blue shirt and cap, a leather apron, a hammer",
                 "shirt": (0.42, 0.48, 0.58), "hose": (0.3, 0.28, 0.26), "hair": (0.5, 0.36, 0.2),
                 "hat": "cap", "hat_ramp": (0.3, 0.32, 0.38), "apron": True, "apron_ramp": (0.45, 0.32, 0.2),
                 "activities": ["heat", "rivet", "polish"]},
    "bowyer": {"summary": "bowyer: a green shirt and cap, a knife for shaping staves",
               "shirt": (0.36, 0.5, 0.3), "hose": (0.42, 0.34, 0.24), "hair": (0.55, 0.36, 0.18),
               "hat": "cap", "hat_ramp": (0.28, 0.4, 0.22), "tool": "knife", "activities": ["carve", "bend", "string"]},
    "shipwright": {"summary": "shipwright: a blue shirt and cap, a beard, a leather apron, a hammer",
                   "shirt": (0.4, 0.46, 0.55), "hose": (0.34, 0.3, 0.26), "hair": (0.5, 0.34, 0.18),
                   "hat": "cap", "hat_ramp": (0.25, 0.3, 0.42), "beard": True, "apron": True,
                   "apron_ramp": (0.52, 0.36, 0.22), "activities": ["hammer"]},
    "charcoal_burner": {"summary": "charcoal burner: sooty grey clothes and kerchief, a beard, a pole and a rake",
                        "shirt": (0.34, 0.31, 0.28), "hose": (0.25, 0.22, 0.2), "hair": (0.18, 0.14, 0.11),
                        "hat": "kerchief", "hat_ramp": (0.3, 0.28, 0.25), "beard": True,
                        "activities": ["stack", "tend_fire", "rake"]},
    "tar_burner": {"summary": "tar burner: tar-black clothes and kerchief, a beard, a pole",
                   "shirt": (0.3, 0.27, 0.24), "hose": (0.24, 0.21, 0.19), "hair": (0.15, 0.12, 0.1),
                   "hat": "kerchief", "hat_ramp": (0.2, 0.18, 0.16), "beard": True,
                   "activities": ["stack", "tend_fire", "tap"]},
    "brickmaker": {"summary": "brickmaker: a brick-red shirt, a leather apron, a beard, a spade for the kiln",
                   "shirt": (0.72, 0.36, 0.26), "hose": (0.35, 0.3, 0.26), "hair": (0.3, 0.22, 0.15),
                   "hat": "none", "beard": True, "apron": True, "apron_ramp": (0.55, 0.38, 0.22),
                   "activities": ["mould", "fire"]},
    "weaver": {"summary": "weaver: a blue bodice, a mauve dress, a yellow kerchief",
               "shirt": (0.38, 0.42, 0.7), "hose": (0.5, 0.36, 0.45), "hair": (0.55, 0.32, 0.16),
               "hat": "kerchief", "hat_ramp": (0.85, 0.75, 0.45), "long": "dress", "activities": ["spin", "weave"]},
    "tailor": {"summary": "tailor: a purple shirt and cap, shears",
               "shirt": (0.55, 0.28, 0.5), "hose": (0.3, 0.28, 0.3), "hair": (0.2, 0.15, 0.12),
               "hat": "cap", "hat_ramp": (0.3, 0.2, 0.35), "activities": ["cut", "sew"]},
    "butcher": {"summary": "butcher: a pale shirt, a pinkish-white apron, a beard, an axe and a knife",
                "shirt": (0.78, 0.74, 0.68), "hose": (0.3, 0.26, 0.24), "hair": (0.22, 0.15, 0.1),
                "hat": "none", "beard": True, "apron": True, "apron_ramp": (0.88, 0.8, 0.78),
                "activities": ["slaughter", "skin"]},
    "innkeeper": {"summary": "innkeeper: a red shirt, a white apron, a beard, a tankard of ale",
                  "shirt": (0.6, 0.2, 0.2), "hose": (0.32, 0.26, 0.22), "hair": (0.45, 0.3, 0.18),
                  "hat": "none", "beard": True, "apron": True, "apron_ramp": (0.95, 0.93, 0.88),
                  "activities": ["serve"]},
    "stallholder": {"summary": "stallholder: an orange bodice, a mauve dress, a white apron, a blue kerchief",
                    "shirt": (0.75, 0.45, 0.25), "hose": (0.42, 0.3, 0.36), "hair": (0.5, 0.3, 0.15),
                    "hat": "kerchief", "hat_ramp": (0.3, 0.45, 0.65), "long": "dress", "apron": True,
                    "apron_ramp": (0.92, 0.88, 0.78), "activities": ["sell"]},
    "merchant": {"summary": "merchant: a long purple gown, a red cloak, a wide red hat, a beard, a staff",
                 "shirt": (0.35, 0.22, 0.45), "hose": (0.28, 0.24, 0.22), "hair": (0.3, 0.2, 0.12),
                 "hat": "wide", "hat_ramp": (0.4, 0.15, 0.15), "beard": True, "cloak": (0.55, 0.18, 0.16),
                 "long": "gown", "tool": "staff", "activities": [], "work": ("watch", "staff")},
    "teacher": {"summary": "teacher: a long dark blue scholar's gown, a black cap, a grey beard, a pointer and a bell",
                "shirt": (0.22, 0.24, 0.36), "hose": (0.2, 0.2, 0.26), "hair": (0.55, 0.52, 0.48),
                "hat": "cap", "hat_ramp": (0.14, 0.14, 0.2), "beard": True, "long": "gown", "tool": "staff",
                "activities": ["teach", "ring", "rest"], "moves": {"rest": ("watch", "staff")}},
    "scholar": {"summary": "scholar: a long red academic gown, a black cap, a book and a quill",
                "shirt": (0.55, 0.14, 0.12), "hose": (0.25, 0.12, 0.1), "hair": (0.4, 0.3, 0.2),
                "hat": "cap", "hat_ramp": (0.12, 0.12, 0.14), "long": "gown",
                "activities": ["read", "write", "rest"], "moves": {"rest": ("muse", "")}},
    "householder": {"summary": "householder: a red bodice, a mauve dress, a white apron and kerchief",
                    "shirt": (0.66, 0.3, 0.3), "hose": (0.45, 0.32, 0.4), "hair": (0.45, 0.28, 0.14),
                    "hat": "kerchief", "hat_ramp": (0.92, 0.9, 0.82), "long": "dress", "apron": True,
                    "apron_ramp": (0.92, 0.9, 0.84), "activities": [], "work": "knead"},
    "settler": {"summary": "settler: a drab travelling hood and cloak, a walking staff",
                "shirt": (0.45, 0.4, 0.32), "hose": (0.36, 0.3, 0.24), "hair": (0.3, 0.22, 0.14),
                "hat": "hood", "hat_ramp": (0.4, 0.36, 0.3), "cloak": (0.42, 0.38, 0.31), "tool": "staff",
                "activities": [], "work": ("watch", "staff")},
    "recruit": {"summary": "recruit: a plain undyed tunic, bareheaded (he changes at the armoury)",
                "shirt": (0.7, 0.62, 0.46), "hose": (0.42, 0.36, 0.28), "hair": (0.4, 0.26, 0.14),
                "hat": "none", "activities": [], "work": "lift"},
}

# The bow's own turns replace the kit's (as the archer's: the arm stretched out cannot raise it otherwise).
BOW_BONES = """  bow: {rot: "[bow_x, 0, bow_z]", scale: "max(show_bow, 0.001)"}
  bow_stave: {rot: "[0, bow_roll, 0]"}"""


def ramp(value):
    tones = RAMPS[value] if isinstance(value, str) else ramp_from(value)
    return "[" + ", ".join(f'"{c}"' for c in tones) + "]"


def move_keys(move, extra=""):
    return "\n".join(f"      - {{ms: 125, set: {{{extra}{k}}}}}" for k in MOVES[move])


def tool_of(p, activity):
    move, tool = p.get("moves", {}).get(activity) or ACTIVITIES[activity]
    return move, (p.get("tool", "") if tool is None else tool)


def work_of(p):
    """The fallback `work` clip of a profession without activities: a move name or (move, tool)."""
    w = p["work"]
    return (w, "") if isinstance(w, str) else w


def spec_text(pid, p):
    acts = p["activities"]
    tools = {tool_of(p, a)[1] for a in acts}
    if "work" in p:
        tools.add(work_of(p)[1])
    tools.discard("")
    lines = [
        "spritekiln: 1",
        "# Generated by tools/spritekiln/gen_civilians.py (G3): edit the generator, not this file.",
        f"name: {pid}",
        "extends: ../civilian/civilian.yaml",
        "",
        "brief:",
        f'  summary: "Your Kingdom {p["summary"]}"',
        "",
        "ramps:",
        f"  shirt: {ramp(p['shirt'])}",
        f"  hose: {ramp(p['hose'])}",
        f"  hat: {ramp(p.get('hat_ramp', 'flax'))}",
        f"  apron: {ramp(p.get('apron_ramp', 'flax'))}",
    ]
    if "hair" in p:
        lines.append(f"  hair: {ramp(p['hair'])}")
    if "cloak" in p:
        lines.append(f"  cloak: {ramp(p['cloak'])}")
    if p["hat"] == "veil":
        lines.append(f"  veil: {ramp((0.62, 0.62, 0.55))}")
    lines += ["", "materials:", "  hair: {ramp: hair}"]
    if "cloak" in p:
        lines.append("  cloak_m: {ramp: cloak, bands: [1, 5]}")
    if p["hat"] == "veil":
        lines.append("  veil_m: {ramp: veil, bands: [2, 5]}")
    if p.get("quiver"):
        lines += ["  feather: {ramp: apron, bands: [3, 5], outline: false}", "  wood: {ramp: wood}"]
    lines += ["", "channels:", "  seedbag: 0"]
    for t in sorted(tools):
        lines.append(f"  show_{t}: 0")
    if "bow" in tools:
        lines += ["  bow_x: -0.75", "  bow_z: 0", "  bow_roll: 0", "  arrow: 0"]
    if HAIR[p["hat"]]:
        lines += ["", "use:", f"  - {HAIR[p['hat']]}"]
    else:
        lines[lines.index("extends: ../civilian/civilian.yaml") + 1:1] = ["remove: [use.hair]"]
        lines += ["", "use:"]
    if p["hat"] == "hood":
        lines.append(f"  - {HOOD_USE}")
    if "cloak" in p:
        lines.append(f"  - {CLOAK_USE}")
    for t in sorted(tools):
        lines.append(f"  - {TOOLS[t]}".replace("as: tool", f"as: {t}"))
    pieces = []
    long = p.get("long")
    skirt = SKIRT.format(what="a dress" if long == "dress" else "a gown", mat="trousers" if long == "dress" else "cloth")
    if p.get("apron") and long:
        skirt += SKIRT_APRON
    for piece, on in ((HEADWEAR[p["hat"]], True), (BEARD, p.get("beard")), (skirt, long),
                      (APRON, p.get("apron") and not long),
                      (QUIVER, p.get("quiver")),
                      (SEEDBAG, any(ACTIVITIES[a][0] == "sow" for a in acts))):
        if on and piece:
            pieces.append(piece.rstrip("\n"))
    if pieces:   # an empty `parts:` would replace the inherited body with nothing
        lines += ["", "parts:"] + pieces
    # Tools turn in the torso's frame at the fist and hide outside their clips (bone scaled to nothing).
    if tools:
        lines += ["", "bones:"]
        for t in sorted(tools):
            if t == "bow":
                lines.append(BOW_BONES)
                continue
            lines.append(f'  {t}: {{parent: torso_rot, at: wrist_R, pos: [0, 0, 0], rot: "[tool_pitch, tool_yaw, 0]", '
                         f'scale: "max(show_{t}, 0.001)"}}')
    lines += ["", "animations:"]
    clips = [(f"work_{a}",) + tool_of(p, a) for a in acts]
    if "work" in p:
        clips.append(("work",) + work_of(p))
    for clip, move, tool in clips:
        lines += [f"  {clip}:", "    loop: true", "    keys:"]
        lines.append(move_keys(move, f"show_{tool}: 1, " if tool else ""))
    return "\n".join(lines) + "\n"


def main():
    ids = sys.argv[1:] or list(PROFESSIONS)
    for pid in ids:
        d = os.path.join(SPECS, pid)
        os.makedirs(d, exist_ok=True)
        path = os.path.join(d, pid + ".yaml")
        with open(path, "w") as fh:
            fh.write(spec_text(pid, PROFESSIONS[pid]))
        print(path)


if __name__ == "__main__":
    main()
