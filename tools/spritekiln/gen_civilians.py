"""Write the SpriteKiln specs of the townsfolk (G3, ART_SPEC 10.27): art/specs/characters/<id>/<id>.yaml.

Every profession extends the common model art/specs/characters/civilian/civilian.yaml (clothes, idle, walk
and the 7 carry walks with the `load` socket) and adds its own colours, headwear, apron, tool and work moves.
Work moves are shared patterns (MOVES: a hammer blow, a hoe stroke, a reap...) played with the profession's
tool; the game's activity names (work_plow, work_build...) map onto them in ACTIVITIES.

Run: python3 tools/spritekiln/gen_civilians.py [<id> ...]
Then render each: cd tools/spritekiln/art/specs/characters/<id> && spritekiln render <id>.yaml
and copy into the game: python3 tools/spritekiln/export_civilian.py <id> ...
"""
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

# Activity (the game's work_<activity>) -> move.
ACTIVITIES = {
    "build": "hammer", "plow": "till", "weed": "scrape", "harvest": "reap", "sow": "sow", "bind": "stoop",
    "load": "lift",
}

# Tools: a kit from art/specs/kits or a built-in one, with its params; the moves drive `pitch` through tool_pitch.
TOOLS = {
    "hammer": "{kit: hammer, as: tool, at: wrist_R, with: {length: 0.30, head: 0.06, width: 0.065, tilt: 0.3, pitch: tool_pitch, cheat: tool_cheat}}",
    "hoe": "{kit: hoe, as: tool, at: wrist_R, with: {pitch: tool_pitch}}",
    "sickle": "{kit: sickle, as: tool, at: wrist_R, with: {pitch: tool_pitch}}",
}

# Moves that need a different tool than the profession's own (a farmer ploughs with a hoe, reaps with a sickle).
MOVE_TOOL = {"till": "hoe", "scrape": "hoe", "reap": "sickle", "sow": "", "stoop": "", "lift": ""}

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

# The hair kit under each headwear (replaces the base's `hair` use).
HAIR = {
    "kerchief": None,
    "cap": "{kit: hair, at: head, with: {fringe: 0.3, part: 0.1, locks: 0.4, length: 0.15, volume: 0.7}}",
    "straw": "{kit: hair, at: head, with: {fringe: 0.4, part: 0.2, locks: 0.5, length: 0.2, volume: 0.8}}",
}

APRON = """  apron:              # a leather or linen apron from the belt to the knees
    material: apron_m
    space: coatbase
    prims:
      - box: {c: [0, -0.10, 0.17], half: [0.15, 0.22, 0.012], rot: [0.08, 0, 0]}
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

PROFESSIONS = {
    "porter": {"summary": "porter: a brown wool jerkin, grey hose, a red kerchief over the hair",
               "shirt": "brown", "hose": "hose", "hat": "kerchief", "hat_ramp": "red",
               "activities": ["load"]},
    "farmer": {"summary": "farmer: an undyed linen smock, brown hose, a wide straw hat",
               "shirt": "flax", "hose": "hose_dark", "hat": "straw", "hat_ramp": "straw", "apron_ramp": "brown",
               "activities": ["plow", "sow", "harvest", "bind", "weed"]},
    "builder": {"summary": "builder: a grey shirt, a leather apron, a green felt cap, a carpenter's hammer",
                "shirt": "grey", "hose": "hose", "hat": "cap", "hat_ramp": "green", "apron": True,
                "apron_ramp": "leather", "tool": "hammer", "activities": ["build"]},
}


def ramp(name):
    return "[" + ", ".join(f'"{c}"' for c in RAMPS[name]) + "]"


def move_keys(move):
    return "\n".join(f"      - {{ms: 125, set: {{{k}}}}}" for k in MOVES[move])


def spec_text(pid, p):
    acts = p["activities"]
    tools = {p.get("tool", "")} | {MOVE_TOOL[ACTIVITIES[a]] for a in acts if ACTIVITIES[a] in MOVE_TOOL}
    tools.discard("")
    # One tool per spec part set: several tools are separate uses shown only in their clips.
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
        f"  hat: {ramp(p['hat_ramp'])}",
        f"  apron: {ramp(p.get('apron_ramp', 'flax'))}",
        "",
        "channels:",
        "  seedbag: 0",
    ]
    for t in sorted(tools):
        lines.append(f"  show_{t}: 0")
    if HAIR[p["hat"]]:
        lines += ["", "use:", f"  - {HAIR[p['hat']]}"]
    else:
        lines[lines.index("extends: ../civilian/civilian.yaml") + 1:1] = ["remove: [use.hair]"]
        lines += ["", "use:"]
    if tools:
        for t in sorted(tools):
            lines.append(f"  - {TOOLS[t]}".replace("as: tool", f"as: {t}"))
    lines += ["", "parts:"]
    lines.append(HEADWEAR[p["hat"]].rstrip("\n"))
    if p.get("apron"):
        lines.append(APRON.rstrip("\n"))
    if any(ACTIVITIES[a] == "sow" for a in acts):
        lines.append(SEEDBAG.rstrip("\n"))
    # Hide every tool outside its clips: scale its bone to nothing.
    if tools:
        lines += ["", "bones:"]
        for t in sorted(tools):
            lines.append(f'  {t}: {{parent: torso_rot, at: wrist_R, pos: [0, 0, 0], rot: "[tool_pitch, tool_yaw, 0]", '
                         f'scale: "max(show_{t}, 0.001)"}}')
    lines += ["", "animations:"]
    for a in acts:
        move = ACTIVITIES[a]
        tool = MOVE_TOOL.get(move, p.get("tool", "")) if move in MOVE_TOOL else p.get("tool", "")
        lines.append(f"  work_{a}:")
        lines.append("    loop: true")
        lines.append("    keys:")
        body = move_keys(move)
        if tool:
            body = body.replace("set: {", f"set: {{show_{tool}: 1, ")
        lines.append(body)
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
