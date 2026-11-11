extends SceneTree
## Final character art drawn in code (owner decision 2026-11-05: better than the placeholders,
## without PixelLab). Writes res://assets/characters/<kind>/<anim>.png (+ .anchors.png for
## carrying) in the layout of ART_SPEC §4: 64x64 frames, feet at (32, 58), rows S, SE, E, NE,
## N (the W side is mirrored by the game), 42 px tall people.
##
## Run: godot --headless --path . -s res://tools/generate_characters.gd   (then --import)
##
## A person is a set of body parts placed in body space (side s to the right hand, front f,
## height z), turned to the row's direction and squashed 2:1 like the ground. Parts are drawn
## from the back to the front, then a 1 px outline in a darker shade (ART_SPEC §1).
## Each profession has its own clothes, hat and tool (ART_SPEC §4.4).

const OUT := "res://assets/characters"
const FRAME := Vector2i(64, 64)
const FOOT := Vector2(32, 58)
const ROWS := 5
## People are drawn for 42 px and shrunk to about 34 px around the feet (owner decision
## 2026-11-05: closer to the size of doors and windows).
const SCALE := 0.81
const ANCHOR := Color(1, 0, 0)
const BEHIND := Color(0, 0, 1)

const SKIN := Color(0.93, 0.74, 0.58)
## How much higher a rider sits than a man on foot (body space units).
const MOUNT_LIFT := 7.0
const C_IRON := Color(0.62, 0.64, 0.68)
const C_WOOD := Color(0.5, 0.33, 0.18)
const C_SHOE := Color(0.27, 0.18, 0.12)

## Kind -> look. shirt/legs/hair colours, hat, apron (colour or null), tool, dress.
const PEOPLE := {
	"farmer": {"shirt": Color(0.78, 0.66, 0.42), "legs": Color(0.42, 0.34, 0.24), "hair": Color(0.45, 0.3, 0.16),
			"hat": "straw", "tool": "sickle"},
	"hop_grower": {"shirt": Color(0.42, 0.58, 0.32), "legs": Color(0.38, 0.32, 0.24), "hair": Color(0.3, 0.2, 0.12),
			"hat": "straw", "tool": "hook"},
	"miller": {"shirt": Color(0.86, 0.84, 0.78), "legs": Color(0.55, 0.5, 0.42), "hair": Color(0.55, 0.42, 0.25),
			"hat": "flour_cap", "apron": Color(0.95, 0.94, 0.9), "tool": ""},
	"baker": {"shirt": Color(0.8, 0.62, 0.45), "legs": Color(0.4, 0.33, 0.26), "hair": Color(0.25, 0.17, 0.1),
			"hat": "baker_cap", "apron": Color(0.96, 0.95, 0.92), "tool": "peel"},
	"woodcutter": {"shirt": Color(0.72, 0.2, 0.16), "legs": Color(0.32, 0.28, 0.22), "hair": Color(0.35, 0.22, 0.12),
			"hat": "", "beard": true, "tool": "axe"},
	"porter": {"shirt": Color(0.5, 0.34, 0.2), "legs": Color(0.36, 0.3, 0.24), "hair": Color(0.2, 0.14, 0.1),
			"hat": "kerchief", "hat_colour": Color(0.75, 0.25, 0.2), "tool": ""},
	"builder": {"shirt": Color(0.6, 0.58, 0.55), "legs": Color(0.35, 0.3, 0.25), "hair": Color(0.4, 0.28, 0.15),
			"hat": "cap", "hat_colour": Color(0.45, 0.32, 0.2), "apron": Color(0.55, 0.38, 0.22), "tool": "hammer"},
	"sawyer": {"shirt": Color(0.38, 0.52, 0.36), "legs": Color(0.4, 0.33, 0.24), "hair": Color(0.55, 0.38, 0.2),
			"hat": "cap", "hat_colour": Color(0.3, 0.4, 0.28), "tool": "saw"},
	"stonecutter": {"shirt": Color(0.58, 0.6, 0.62), "legs": Color(0.32, 0.3, 0.28), "hair": Color(0.3, 0.3, 0.3),
			"hat": "", "beard": true, "apron": Color(0.5, 0.36, 0.22), "tool": "pick"},
	"angler": {"shirt": Color(0.36, 0.5, 0.7), "legs": Color(0.4, 0.36, 0.3), "hair": Color(0.5, 0.36, 0.2),
			"hat": "wide", "hat_colour": Color(0.55, 0.45, 0.3), "tool": "rod"},
	"brewer": {"shirt": Color(0.82, 0.74, 0.55), "legs": Color(0.42, 0.32, 0.24), "hair": Color(0.6, 0.3, 0.15),
			"hat": "cap", "hat_colour": Color(0.55, 0.25, 0.2), "apron": Color(0.48, 0.32, 0.2), "tool": "paddle"},
	"householder": {"shirt": Color(0.66, 0.3, 0.3), "legs": Color(0.45, 0.32, 0.4), "hair": Color(0.45, 0.28, 0.14),
			"hat": "kerchief", "hat_colour": Color(0.92, 0.9, 0.82), "dress": true, "apron": Color(0.92, 0.9, 0.84), "tool": ""},
	"settler": {"shirt": Color(0.45, 0.4, 0.32), "legs": Color(0.36, 0.3, 0.24), "hair": Color(0.3, 0.22, 0.14),
			"hat": "hood", "hat_colour": Color(0.4, 0.36, 0.3), "cloak": Color(0.4, 0.36, 0.3), "tool": "staff"},
	# M4b (patricians)
	"forester": {"shirt": Color(0.3, 0.5, 0.28), "legs": Color(0.36, 0.3, 0.22), "hair": Color(0.4, 0.26, 0.14),
			"hat": "cap", "hat_colour": Color(0.22, 0.38, 0.2), "tool": "spade"},
	"shepherd": {"shirt": Color(0.72, 0.66, 0.54), "legs": Color(0.42, 0.36, 0.28), "hair": Color(0.5, 0.45, 0.4),
			"hat": "wide", "hat_colour": Color(0.45, 0.35, 0.24), "beard": true,
			"cloak": Color(0.55, 0.5, 0.42), "tool": "crook"},
	"weaver": {"shirt": Color(0.38, 0.42, 0.7), "legs": Color(0.5, 0.36, 0.45), "hair": Color(0.55, 0.32, 0.16),
			"hat": "kerchief", "hat_colour": Color(0.85, 0.75, 0.45), "dress": true, "tool": ""},
	"tailor": {"shirt": Color(0.55, 0.28, 0.5), "legs": Color(0.3, 0.28, 0.3), "hair": Color(0.2, 0.15, 0.12),
			"hat": "cap", "hat_colour": Color(0.3, 0.2, 0.35), "tool": "shears"},
	"beekeeper": {"shirt": Color(0.9, 0.86, 0.72), "legs": Color(0.6, 0.55, 0.45), "hair": Color(0.45, 0.3, 0.15),
			"hat": "veil", "hat_colour": Color(0.88, 0.78, 0.48), "tool": "smoker"},
	"mead_maker": {"shirt": Color(0.85, 0.65, 0.3), "legs": Color(0.42, 0.32, 0.24), "hair": Color(0.35, 0.22, 0.12),
			"hat": "cap", "hat_colour": Color(0.6, 0.4, 0.15), "apron": Color(0.5, 0.34, 0.2), "tool": "paddle"},
	# M6 part 3 (wine): a winegrower with a pruning knife, a vintner in a wine-stained apron.
	"winegrower": {"shirt": Color(0.55, 0.42, 0.62), "legs": Color(0.38, 0.32, 0.24), "hair": Color(0.3, 0.2, 0.12),
			"hat": "straw", "tool": "hook"},
	# E2 part 2: a hunter in a green hood with a bow and a quiver, a knife to dress the game.
	"hunter": {"shirt": Color(0.4, 0.36, 0.24), "legs": Color(0.3, 0.26, 0.2), "hair": Color(0.3, 0.2, 0.12),
			"hat": "archer_hood", "hat_colour": Color(0.26, 0.34, 0.2), "weapon": "bow", "quiver": true,
			"aim": "draw", "tool": "knife"},
	# E2 part 1: an orchardist in a green smock with a pruning hook.
	"orchardist": {"shirt": Color(0.42, 0.56, 0.3), "legs": Color(0.4, 0.33, 0.24), "hair": Color(0.45, 0.3, 0.16),
			"hat": "straw", "tool": "hook"},
	"vintner": {"shirt": Color(0.86, 0.8, 0.68), "legs": Color(0.4, 0.3, 0.24), "hair": Color(0.2, 0.14, 0.1),
			"hat": "cap", "hat_colour": Color(0.5, 0.12, 0.18), "apron": Color(0.48, 0.14, 0.2), "tool": "paddle"},
	"clay_digger": {"shirt": Color(0.66, 0.5, 0.4), "legs": Color(0.45, 0.35, 0.28), "hair": Color(0.25, 0.18, 0.12),
			"hat": "kerchief", "hat_colour": Color(0.55, 0.4, 0.3), "tool": "spade"},
	"brickmaker": {"shirt": Color(0.72, 0.36, 0.26), "legs": Color(0.35, 0.3, 0.26), "hair": Color(0.3, 0.22, 0.15),
			"hat": "", "beard": true, "apron": Color(0.55, 0.38, 0.22), "tool": "spade"},
	"innkeeper": {"shirt": Color(0.6, 0.2, 0.2), "legs": Color(0.32, 0.26, 0.22), "hair": Color(0.45, 0.3, 0.18),
			"hat": "", "beard": true, "apron": Color(0.95, 0.93, 0.88), "tool": "mug"},
	# E4 part 2: a teacher in a long dark scholar's gown and cap, with a pointer.
	"teacher": {"shirt": Color(0.22, 0.24, 0.36), "legs": Color(0.2, 0.2, 0.26), "hair": Color(0.55, 0.52, 0.48),
			"hat": "cap", "hat_colour": Color(0.14, 0.14, 0.2), "beard": true, "dress": true,
			"cloak": Color(0.2, 0.22, 0.32), "tool": "staff"},
	# E4 part 3: a scholar in a red academic gown with a black cap, a book in hand.
	"scholar": {"shirt": Color(0.55, 0.14, 0.12), "legs": Color(0.25, 0.12, 0.1), "hair": Color(0.4, 0.3, 0.2),
			"hat": "cap", "hat_colour": Color(0.1, 0.1, 0.12), "dress": true,
			"cloak": Color(0.5, 0.12, 0.1), "tool": ""},
	# M4b-2 (meat)
	"swineherd": {"shirt": Color(0.6, 0.52, 0.36), "legs": Color(0.38, 0.3, 0.22), "hair": Color(0.55, 0.38, 0.2),
			"hat": "straw", "tool": "spade"},
	"butcher": {"shirt": Color(0.78, 0.74, 0.68), "legs": Color(0.3, 0.26, 0.24), "hair": Color(0.22, 0.15, 0.1),
			"hat": "", "beard": true, "apron": Color(0.88, 0.8, 0.78), "tool": "axe"},
	# M4b-2 (market and merchant)
	"stallholder": {"shirt": Color(0.75, 0.45, 0.25), "legs": Color(0.42, 0.3, 0.36), "hair": Color(0.5, 0.3, 0.15),
			"hat": "kerchief", "hat_colour": Color(0.3, 0.45, 0.65), "dress": true,
			"apron": Color(0.92, 0.88, 0.78), "tool": ""},
	# M4b-3 (wagons)
	"carter": {"shirt": Color(0.42, 0.5, 0.36), "legs": Color(0.34, 0.28, 0.22), "hair": Color(0.35, 0.24, 0.14),
			"hat": "wide", "hat_colour": Color(0.4, 0.3, 0.2), "beard": true, "tool": ""},
	"merchant": {"shirt": Color(0.35, 0.22, 0.45), "legs": Color(0.28, 0.24, 0.22), "hair": Color(0.3, 0.2, 0.12),
			"hat": "wide", "hat_colour": Color(0.4, 0.15, 0.15), "beard": true,
			"cloak": Color(0.55, 0.18, 0.16), "tool": "staff"},
	# M5 (the sea)
	"shipwright": {"shirt": Color(0.4, 0.46, 0.55), "legs": Color(0.34, 0.3, 0.26), "hair": Color(0.5, 0.34, 0.18),
			"hat": "cap", "hat_colour": Color(0.25, 0.3, 0.42), "beard": true,
			"apron": Color(0.52, 0.36, 0.22), "tool": "hammer"},
	"tar_burner": {"shirt": Color(0.3, 0.27, 0.24), "legs": Color(0.24, 0.21, 0.19), "hair": Color(0.15, 0.12, 0.1),
			"hat": "kerchief", "hat_colour": Color(0.2, 0.18, 0.16), "beard": true, "tool": "staff"},
	"fisher": {"shirt": Color(0.3, 0.42, 0.55), "legs": Color(0.36, 0.33, 0.3), "hair": Color(0.55, 0.42, 0.25),
			"hat": "wide", "hat_colour": Color(0.75, 0.62, 0.3), "beard": true, "tool": ""},
	# M5 part 2 (the port)
	"docker": {"shirt": Color(0.62, 0.58, 0.5), "legs": Color(0.25, 0.28, 0.38), "hair": Color(0.25, 0.17, 0.1),
			"hat": "kerchief", "hat_colour": Color(0.6, 0.2, 0.18), "beard": false,
			"apron": Color(0.42, 0.32, 0.22), "tool": ""},
	# M7 part 1 (metals and weapons): sooty charcoal burner, miner in a leather cap, smelter and
	# blacksmith in heavy leather aprons, armourer, bowyer in green, groom, and the recruit in a
	# plain tunic (he changes into his unit's clothes at the armoury).
	"charcoal_burner": {"shirt": Color(0.34, 0.31, 0.28), "legs": Color(0.25, 0.22, 0.2), "hair": Color(0.18, 0.14, 0.11),
			"hat": "kerchief", "hat_colour": Color(0.24, 0.22, 0.2), "beard": true, "tool": "rake"},
	"miner": {"shirt": Color(0.55, 0.42, 0.3), "legs": Color(0.3, 0.27, 0.24), "hair": Color(0.28, 0.2, 0.14),
			"hat": "cap", "hat_colour": Color(0.38, 0.27, 0.17), "beard": true,
			"apron": Color(0.42, 0.3, 0.2), "tool": "pick"},
	"smelter": {"shirt": Color(0.66, 0.4, 0.3), "legs": Color(0.32, 0.27, 0.23), "hair": Color(0.4, 0.24, 0.12),
			"hat": "cap", "hat_colour": Color(0.3, 0.24, 0.2), "apron": Color(0.36, 0.25, 0.16), "tool": "tongs"},
	"blacksmith": {"shirt": Color(0.4, 0.4, 0.42), "legs": Color(0.28, 0.25, 0.22), "hair": Color(0.15, 0.11, 0.09),
			"hat": "", "beard": true, "apron": Color(0.38, 0.26, 0.16), "tool": "hammer"},
	"armourer": {"shirt": Color(0.42, 0.48, 0.58), "legs": Color(0.3, 0.28, 0.26), "hair": Color(0.5, 0.36, 0.2),
			"hat": "cap", "hat_colour": Color(0.3, 0.32, 0.38), "apron": Color(0.45, 0.32, 0.2), "tool": "hammer"},
	"bowyer": {"shirt": Color(0.36, 0.5, 0.3), "legs": Color(0.42, 0.34, 0.24), "hair": Color(0.55, 0.36, 0.18),
			"hat": "cap", "hat_colour": Color(0.28, 0.4, 0.22), "tool": "knife"},
	"groom": {"shirt": Color(0.6, 0.48, 0.32), "legs": Color(0.3, 0.3, 0.36), "hair": Color(0.45, 0.3, 0.16),
			"hat": "wide", "hat_colour": Color(0.42, 0.3, 0.18), "tool": "brush"},
	"recruit": {"shirt": Color(0.7, 0.62, 0.46), "legs": Color(0.42, 0.36, 0.28), "hair": Color(0.4, 0.26, 0.14),
			"hat": "", "tool": ""},
}

## The kingdom's colours (the player's arms on the world map, M6): tabards, shields, pennons.
const ROYAL := Color(0.70, 0.12, 0.10)
const GOLD := Color(0.92, 0.74, 0.26)
const C_STEEL := Color(0.7, 0.72, 0.76)
const C_MAIL := Color(0.56, 0.58, 0.62)
const C_LEATHER := Color(0.46, 0.3, 0.18)

## M7 part 1: soldiers, drawn with the same body and much more gear (owner's wish 2026-11-07:
## as fine and detailed as possible). armour: "gambeson" (quilted), "leather" (jerkin with
## studs) or "mail" (ring mail with a tabard in the kingdom's colours); helmet; weapon in the
## right hand; shield on the left arm; drill: the motion of his drill (work_drill).
const SOLDIERS := {
	"spearman": {"shirt": Color(0.78, 0.68, 0.5), "legs": Color(0.4, 0.3, 0.24), "hair": Color(0.35, 0.22, 0.12),
			"hat": "kettle", "armour": "gambeson", "weapon": "spear", "shield": "round",
			"drill": "thrust", "tool": ""},
	"archer": {"shirt": Color(0.42, 0.5, 0.3), "legs": Color(0.36, 0.3, 0.22), "hair": Color(0.5, 0.32, 0.16),
			"hat": "archer_hood", "hat_colour": Color(0.34, 0.44, 0.24), "armour": "leather",
			"weapon": "bow", "quiver": true, "drill": "draw", "tool": ""},
	"swordsman": {"shirt": C_MAIL, "legs": Color(0.32, 0.28, 0.26), "hair": Color(0.25, 0.16, 0.1),
			"hat": "nasal", "armour": "mail", "tabard": true, "weapon": "sword", "shield": "kite",
			"beard": true, "drill": "slash", "tool": ""},
	"knight": {"shirt": C_MAIL, "legs": C_MAIL, "hair": Color(0.3, 0.2, 0.1),
			"hat": "great_helm", "armour": "mail", "tabard": true, "weapon": "sword", "shield": "kite",
			"mounted": true, "drill": "slash", "tool": ""},
	# J1 part 1 (owner's survey 2026-11-08: drawn by code like the M7 soldiers): plate armour
	# over mail for the halberdier and the man-at-arms (the same armour good as the swordsman's).
	"halberdier": {"shirt": C_MAIL, "legs": Color(0.476, 0.493, 0.527), "hair": Color(0.36, 0.24, 0.12),
			"hat": "kettle", "armour": "plate", "tabard": true, "weapon": "halberd", "drill": "thrust",
			"tool": ""},
	"crossbowman": {"shirt": Color(0.66, 0.58, 0.44), "legs": Color(0.34, 0.3, 0.26), "hair": Color(0.28, 0.18, 0.1),
			"hat": "kettle", "armour": "gambeson", "weapon": "crossbow", "quiver": true, "drill": "aim",
			"beard": true, "tool": ""},
	"man_at_arms": {"shirt": C_MAIL, "legs": Color(0.504, 0.522, 0.558), "hair": Color(0.22, 0.14, 0.08),
			"hat": "great_helm", "armour": "plate", "tabard": true, "weapon": "morning_star", "shield": "kite",
			"drill": "slash", "tool": ""},
	"light_cavalry": {"shirt": Color(0.72, 0.62, 0.46), "legs": Color(0.38, 0.3, 0.22), "hair": Color(0.4, 0.26, 0.12),
			"hat": "nasal", "armour": "gambeson", "weapon": "spear", "shield": "round", "mounted": true,
			"drill": "thrust", "tool": ""},
}

## M7 part 2: bandits (drab hoods, no colours of the kingdom) and the ladderman.
const BANDITS := {
	"bandit": {"shirt": Color(0.36, 0.3, 0.24), "legs": Color(0.22, 0.2, 0.18), "hair": Color(0.12, 0.1, 0.08),
			"hat": "archer_hood", "hat_colour": Color(0.24, 0.21, 0.19), "armour": "gambeson", "weapon": "spear",
			"shield": "round", "beard": true, "drill": "thrust", "tool": "",
			"royal": Color(0.3, 0.24, 0.18), "gold": Color(0.55, 0.46, 0.32)},
	"bandit_archer": {"shirt": Color(0.3, 0.28, 0.22), "legs": Color(0.24, 0.2, 0.17), "hair": Color(0.2, 0.14, 0.1),
			"hat": "archer_hood", "hat_colour": Color(0.2, 0.24, 0.18), "armour": "leather", "weapon": "bow",
			"quiver": true, "drill": "draw", "tool": "", "royal": Color(0.3, 0.26, 0.2), "gold": Color(0.6, 0.52, 0.36)},
	"ladderman": {"shirt": Color(0.62, 0.54, 0.4), "legs": Color(0.38, 0.32, 0.26), "hair": Color(0.42, 0.28, 0.14),
			"hat": "cap", "hat_colour": Color(0.55, 0.16, 0.12), "armour": "", "weapon": "ladder", "drill": "",
			"tool": ""},
}

## Horse colours (the knight's mount and the stud farm's herd).
const HORSE := {"coat": Color(0.48, 0.3, 0.17), "mane": Color(0.18, 0.12, 0.09), "hoof": Color(0.22, 0.18, 0.15),
		"blaze": Color(0.92, 0.9, 0.84)}

## Activity -> motion and the tool it uses (empty = the profession's own).
const WORK := {
	"chop": ["overhead", "axe"], "hew": ["overhead", "pick"], "build": ["overhead", "hammer"],
	"plow": ["overhead", "hoe"], "weed": ["low", "hoe"], "harvest": ["low", "sickle"], "shape": ["low", "hammer"],
	"saw": ["push", "saw"], "knead": ["push", ""], "bake": ["push", "peel"], "grind": ["stir", ""],
	"mash": ["stir", "paddle"], "brew": ["stir", "paddle"], "sow": ["throw", ""], "bind": ["bend", ""],
	"cast": ["cast", "rod"], "wait_bite": ["hold", "rod"], "reel": ["reel", "rod"],
	"dig": ["low", "spade"], "plant": ["bend", ""], "rest": ["rest", ""], "herd": ["rest", "crook"],
	"shear": ["low", "shears"], "spin": ["stir", ""], "weave": ["push", ""], "cut": ["push", "shears"],
	"sew": ["stir", ""], "tend_hives": ["low", "smoker"], "collect_honey": ["bend", ""],
	"mix": ["stir", "paddle"], "ferment": ["push", ""], "press": ["push", ""], "mould": ["push", ""], "fire": ["push", "spade"],
	"serve": ["push", "mug"],
	"hammer": ["overhead", "hammer"], "stack": ["bend", ""], "tend_fire": ["low", "staff"], "tap": ["bend", ""],
	"load": ["bend", ""], "hand_over": ["bend", ""],
	"sell": ["throw", ""], "feed": ["throw", ""], "muck": ["low", "spade"], "slaughter": ["overhead", "axe"], "skin": ["push", ""],
	# M7 part 1
	"rake": ["low", "rake"], "pick": ["overhead", "pick"], "bellows": ["push", ""], "heat": ["push", "tongs"],
	"forge": ["overhead", "hammer"], "quench": ["bend", "tongs"], "rivet": ["low", "hammer"], "polish": ["stir", ""],
	"carve": ["push", "knife"], "bend": ["bend", ""], "string": ["stir", ""], "groom": ["push", "brush"],
	# E3 part 1: the stone pit's crane winch
	"hoist": ["stir", ""],
	# E3 part 2: the deep mine's shaft and winch
	"descend": ["bend", ""], "wind": ["stir", ""],
	# E4 part 2: the teacher points at the blackboard, rings the bell
	"teach": ["throw", "staff"], "ring": ["stir", ""],
	# E4 part 3: the scholar reads and writes at a lectern
	"read": ["hold", ""], "write": ["stir", ""],
}

## Activities each profession performs (recipes, fields, building).
const ACTIVITIES := {
	"farmer": ["plow", "sow", "harvest", "bind", "weed"], "hop_grower": ["plow", "sow", "harvest", "bind", "weed"],
	"miller": ["grind"], "baker": ["knead", "bake"], "woodcutter": ["chop", "bind"],
	"builder": ["build"], "sawyer": ["saw"], "stonecutter": ["hew", "shape", "hoist"],
	"angler": ["cast", "wait_bite", "reel"], "brewer": ["mash", "brew"],
	"forester": ["dig", "plant", "rest"], "shepherd": ["herd", "shear"], "weaver": ["spin", "weave"],
	"tailor": ["cut", "sew"], "beekeeper": ["tend_hives", "collect_honey"], "mead_maker": ["mix", "ferment"],
	"winegrower": ["plow", "sow", "harvest", "bind", "weed"], "vintner": ["press", "ferment"],
	"orchardist": ["plow", "sow", "harvest", "bind", "weed"],
	"hunter": ["carve", "skin", "bend"],
	"clay_digger": ["dig"], "brickmaker": ["mould", "fire"], "innkeeper": ["serve"],
	"swineherd": ["feed", "muck"], "butcher": ["slaughter", "skin"], "stallholder": ["sell"],
	"merchant": [], "porter": ["load"], "carter": ["load"],
	"shipwright": ["hammer"], "tar_burner": ["stack", "tend_fire", "tap"], "fisher": [],
	"docker": ["hand_over"],
	"charcoal_burner": ["stack", "tend_fire", "rake"], "miner": ["pick", "shape", "descend", "wind"],
	"smelter": ["stack", "bellows", "tap"], "blacksmith": ["heat", "forge", "quench"],
	"armourer": ["heat", "rivet", "polish"], "bowyer": ["carve", "bend", "string"], "groom": ["feed", "groom"],
	"recruit": [], "teacher": ["teach", "ring", "rest"],
	"scholar": ["read", "write", "rest"],
}

## Carry category -> hands (side, front, height) for both hands, the good's anchor and
## whether the good hides behind the body when facing the camera (true) or away (false).
const CARRY := {
	"sack": {"hands": [Vector3(3.5, 0.5, 31.0), Vector3(-5.0, 1.0, 17.0)], "anchor": Vector3(4.5, -0.5, 32.0), "behind_camera": false},
	"basket": {"hands": [Vector3(6.5, 2.5, 17.0), Vector3(-5.0, 0.0, 16.0)], "anchor": Vector3(7.5, 3.0, 15.0), "behind_camera": false},
	"bundle": {"hands": [Vector3(3.5, 2.0, 25.0), Vector3(-3.5, 2.0, 25.0)], "anchor": Vector3(0.0, -5.5, 27.0), "behind_camera": true},
	"log": {"hands": [Vector3(4.0, 1.5, 31.0), Vector3(-2.0, 2.5, 26.0)], "anchor": Vector3(4.0, 0.0, 33.0), "behind_camera": false},
	"barrel": {"hands": [Vector3(4.0, 0.5, 34.0), Vector3(-1.0, 1.5, 32.0)], "anchor": Vector3(4.5, -0.5, 35.0), "behind_camera": false},
	"stone": {"hands": [Vector3(3.5, 5.0, 20.0), Vector3(-3.5, 5.0, 20.0)], "anchor": Vector3(0.0, 6.5, 21.0), "behind_camera": false},
	"crate": {"hands": [Vector3(4.0, 5.0, 20.0), Vector3(-4.0, 5.0, 20.0)], "anchor": Vector3(0.0, 6.5, 21.0), "behind_camera": false},
}

var _look: Dictionary
## Livery of the soldier being drawn: the kingdom's red and gold, a bandit's drab ones.
var _royal: Color = ROYAL
var _gold: Color = GOLD
## Parts of the frame being drawn: [depth, callable].
var _parts: Array = []
var _forward: Vector2
var _right: Vector2


func _init() -> void:
	var only := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	for kind: String in PEOPLE:
		if not only.is_empty() and kind != only:
			continue
		_look = PEOPLE[kind]
		_save(_sheet(4, func(_f: int, t: float) -> Dictionary: return {"breath": sin(t * TAU)}), kind, "idle")
		_save(_sheet(8, func(_f: int, t: float) -> Dictionary: return {"swing": sin(t * TAU)}), kind, "walk")
		for category: String in CARRY:
			var spec: Dictionary = CARRY[category]
			var pair := _sheet(8, func(_f: int, t: float) -> Dictionary:
				return {"swing": sin(t * TAU) * (0.6 if category == "stone" else 0.85), "carry": category}, spec)
			_save(pair, kind, "walk_carry_" + category)
		_save(_sheet(8, func(_f: int, t: float) -> Dictionary: return {"work": "overhead", "t": t,
				"tool": String(_look["tool"])}), kind, "work")
		for activity: String in ACTIVITIES.get(kind, []):
			var w: Array = WORK[activity]
			var tool: String = w[1] if w[1] != "" else String(_look["tool"])
			if w[1] == "" and w[0] in ["push", "stir", "throw", "bend"]:
				tool = ""
			_save(_sheet(8, func(_f: int, t: float) -> Dictionary: return {"work": w[0], "t": t, "tool": tool}),
					kind, "work_" + activity)
		if _look.has("aim"):
			# E2 part 2: the hunter draws his bow like an archer's drill.
			var aim := String(_look["aim"])
			_save(_sheet(8, func(_f: int, t: float) -> Dictionary: return {"drill": aim, "t": t}), kind, "work_aim")
	var fighters := SOLDIERS.duplicate()
	fighters.merge(BANDITS)
	for kind: String in fighters:
		if not only.is_empty() and kind != only:
			continue
		_look = fighters[kind]
		_royal = _look.get("royal", ROYAL)
		_gold = _look.get("gold", GOLD)
		_save(_sheet(4, func(_f: int, t: float) -> Dictionary: return {"breath": sin(t * TAU)}), kind, "idle")
		_save(_sheet(8, func(_f: int, t: float) -> Dictionary: return {"swing": sin(t * TAU)}), kind, "walk")
		var drill := String(_look["drill"])
		var drill_pose := func(_f: int, t: float) -> Dictionary: return {"drill": drill, "t": t}
		_save(_sheet(8, drill_pose), kind, "work_drill")
		_save(_sheet(8, drill_pose), kind, "work")
	if only.is_empty() or only == "horse":
		_horse_goods()
	_write_visuals()
	print("Characters written to ", OUT)
	quit()


## Renders [param frames] x 5 rows. [param pose_of] (frame, phase 0..1) -> pose dictionary.
## Returns [sheet, anchors or null].
func _sheet(frames: int, pose_of: Callable, carry: Dictionary = {}) -> Array:
	var sheet := Image.create_empty(FRAME.x * frames, FRAME.y * ROWS, false, Image.FORMAT_RGBA8)
	var anchors: Image = null
	if not carry.is_empty():
		anchors = Image.create_empty(sheet.get_width(), sheet.get_height(), false, Image.FORMAT_RGBA8)
	for row: int in ROWS:
		var angle := PI / 2.0 - row * TAU / 8.0
		_forward = Vector2(cos(angle), sin(angle))
		_right = Vector2(-_forward.y, _forward.x)
		for frame: int in frames:
			var t := float(frame) / frames
			var pose: Dictionary = pose_of.call(frame, t)
			var origin := Vector2i(frame * FRAME.x, row * FRAME.y)
			var img := Image.create_empty(FRAME.x, FRAME.y, false, Image.FORMAT_RGBA8)
			var bob := absf(pose.get("swing", 0.0)) * 1.0 if pose.has("swing") else 0.0
			_person(img, FOOT - Vector2(0, round(bob)), pose)
			_outline(img)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, FRAME), origin)
			if anchors != null:
				var a: Vector3 = carry["anchor"]
				var spot := _shrink(FOOT - Vector2(0, round(bob)) + _ground(a.x, a.y) - Vector2(0, a.z))
				anchors.set_pixelv(origin + Vector2i(spot.round()), ANCHOR)
				var faces_camera := _forward.y > 0.1
				var faces_away := _forward.y < -0.1
				if (faces_camera if carry["behind_camera"] else faces_away):
					anchors.set_pixelv(origin, BEHIND)
	return [sheet, anchors]


# --- The person ----------------------------------------------------------------------------

func _person(img: Image, foot: Vector2, pose: Dictionary) -> void:
	_parts = []
	var swing: float = pose.get("swing", 0.0)
	var work := String(pose.get("work", ""))
	var t: float = pose.get("t", 0.0)
	var lean := 0.0
	var crouch := 0.0
	if work == "bend":
		lean = 3.0 + sin(t * TAU) * 0.5
		crouch = 4.0
	elif work in ["low", "throw"]:
		lean = 1.5
		crouch = 1.0 + maxf(sin(t * TAU), 0.0) * 1.5 if work == "low" else 0.0
	var breath: float = pose.get("breath", 0.0)
	var top := 0.4 * breath - crouch
	var dress: bool = _look.get("dress", false)
	var mounted: bool = _look.get("mounted", false)
	if mounted:
		# A rider (M7): the horse under him, he sits MOUNT_LIFT higher with his legs astride.
		_horse(foot, swing, t if pose.has("drill") else 0.0, breath, true)
		top += MOUNT_LIFT
		for side: float in [-1.0, 1.0]:
			var hip := Vector3(side * 2.4, 0.5, 13.0 + MOUNT_LIFT)
			var knee := Vector3(side * 4.8, 3.2, 9.0 + MOUNT_LIFT)
			var ankle := Vector3(side * 4.6, 1.6, 2.5 + MOUNT_LIFT)
			_limb(foot, hip, knee, 3.4, _look["legs"])
			_limb(foot, knee, ankle, 3.0, _look["legs"].darkened(0.06))
			_blob(foot, ankle + Vector3(0, 1.0, -0.8), Vector2(2.0, 1.3), C_SHOE)
			# Stirrup.
			_blob(foot, ankle + Vector3(side * 0.2, 1.0, -1.8), Vector2(1.6, 0.7), C_STEEL.darkened(0.3))
	for side: float in [-1.0, 1.0] if not mounted else []:
		var step := swing * side * 3.5
		var hip := Vector3(side * 2.2, lean * 0.2, 13.0 - crouch)
		var knee := Vector3(side * 2.3, step * 0.5 + 0.8, 7.0 - crouch * 0.5)
		var ankle := Vector3(side * 2.3, step, 1.5)
		if not dress:
			_limb(foot, hip, knee, 3.4, _look["legs"])
			_limb(foot, knee, ankle, 3.0, _look["legs"].darkened(0.06))
		_blob(foot, ankle + Vector3(0, 1.0, -0.8), Vector2(2.2, 1.4), C_SHOE)
		if _look.has("armour"):
			# Soldiers' boots: taller, with a turned-down cuff.
			_blob(foot, ankle + Vector3(0, 0.3, 1.6), Vector2(1.9, 1.6), C_SHOE.lightened(0.08))
	# Body.
	var body := Vector3(0, lean, 21.0 + top)
	var shirt: Color = _look["shirt"]
	if dress:
		_skirt(foot, lean, top)
	_torso(foot, body, shirt)
	if _look.has("armour"):
		_armour(foot, body, lean, top)
	if _look.has("cloak"):
		var cloak: Color = _look["cloak"]
		_part(_depth(0, lean - 2.0) - 0.3, func() -> void: _ellipse_at(foot, Vector3(0, lean - 1.6, 19.0 + top), Vector2(_width(7.0), 10.0), cloak))
	if _look.has("apron"):
		var apron: Color = _look["apron"]
		_part(_depth(0, lean + 3.2) + 0.05, func() -> void:
			if _forward.y > -0.25:
				var w := _width(4.2)
				var waist := foot + _ground(0, lean + 3.0) - Vector2(0, 18.0 + top)
				var hem := foot + _ground(0, lean * 0.3 + 2.0) - Vector2(0, 6.0)
				_polygon(PackedVector2Array([waist - Vector2(w, 0), waist + Vector2(w, 0),
						hem + Vector2(w * 1.1, 0), hem - Vector2(w * 1.1, 0)]), apron)
				_line(waist - Vector2(w, 0), waist + Vector2(w, 0), apron.darkened(0.3), 1))
	# Belt.
	_part(_depth(0, lean + 2.8), func() -> void:
		if _forward.y > -0.6:
			var b := foot + _ground(0, lean + 2.6) - Vector2(0, 18.0 + top)
			var w := _width(5.6)
			_line(b - Vector2(w, 0), b + Vector2(w, 0), Color(0.3, 0.2, 0.12), 1))
	# Arms and the tool.
	var hands := _hands(pose, lean, top)
	var shoulder_z := 27.5 + top
	for i: int in 2:
		var side := 1.0 if i == 0 else -1.0
		var shoulder := Vector3(side * 5.0, lean * 0.9, shoulder_z)
		var hand: Vector3 = hands[i]
		var elbow := (shoulder + hand) * 0.5 + Vector3(side * 1.2, -0.8, -1.5)
		_limb(foot, shoulder, elbow, 2.8, shirt.darkened(0.22))
		_limb(foot, elbow, hand, 2.4, shirt.darkened(0.18))
		_blob(foot, hand, Vector2(1.5, 1.5), SKIN)
	var tool := String(pose.get("tool", ""))
	if tool == "" and work == "" and not pose.has("carry"):
		tool = String(_look["tool"]) if _look["tool"] in ["staff", "crook"] else ""
	if tool != "":
		_tool(foot, tool, hands[0], hands[1], work, t)
	if _look.has("weapon"):
		_gear(foot, pose, hands, lean, top)
	# Head, hair, face, hat.
	var head := Vector3(0, lean * 1.4, 35.0 + top)
	_head(foot, head)
	_parts.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for part: Array in _parts:
		(part[1] as Callable).call()
	_target_img = null
	_flush(img)


func _hands(pose: Dictionary, lean: float, top: float) -> Array:
	var swing: float = pose.get("swing", 0.0)
	var t: float = pose.get("t", 0.0)
	var c := TAU * t
	if _look.has("weapon"):
		return _soldier_hands(pose, top)
	if pose.has("carry"):
		var hands: Array = (CARRY[String(pose["carry"])] as Dictionary)["hands"].duplicate()
		var free: Vector3 = hands[1]
		if pose["carry"] in ["sack", "basket", "log"]:
			hands[1] = free + Vector3(0, -swing * 2.5, 0)
		return hands
	match String(pose.get("work", "")):
		"overhead":
			# Raise over the head, strike down in front.
			var k := 0.5 - 0.5 * cos(c)
			var up := Vector3(2.0, -1.0, 38.0 + top)
			var down := Vector3(1.0, 7.0 + lean, 15.0 + top)
			var h := up.lerp(down, k * k)
			return [h, h + Vector3(-2.5, -0.5, -1.5)]
		"low":
			var h := Vector3(4.0 + sin(c) * 3.0, 6.0 + lean, 10.0 + top)
			return [h, Vector3(-4.0, 4.0 + lean, 13.0 + top)]
		"push":
			var f := 5.0 + lean + sin(c) * 2.5
			return [Vector3(3.0, f, 19.0 + top), Vector3(-3.0, f, 19.0 + top)]
		"stir":
			var h := Vector3(cos(c) * 2.5, 6.0 + sin(c) * 1.5, 21.0 + top)
			return [h, h + Vector3(-1.5, -0.5, 4.0)]
		"throw":
			var k := maxf(sin(c), 0.0)
			return [Vector3(5.5, 2.0 + 5.0 * k, 15.0 + 6.0 * k + top), Vector3(-5.0, 2.0, 17.0 + top)]
		"bend":
			var h := Vector3(1.5, 5.5 + lean, 9.0 + top + sin(c) * 1.0)
			return [h, h + Vector3(-3.0, 0, 0.5)]
		"cast":
			var k := 0.5 - 0.5 * cos(c)
			var h := Vector3(3.0, -2.0 + 9.0 * k, 34.0 - 10.0 * k + top)
			return [h, h + Vector3(-2.0, -1.0, -3.0)]
		"hold":
			var h := Vector3(3.0, 5.0, 21.0 + top + sin(c) * 0.5)
			return [h, h + Vector3(-2.5, -1.0, -2.0)]
		"reel":
			var k := 0.5 - 0.5 * cos(c)
			var h := Vector3(3.0, 5.0 - 3.0 * k, 21.0 + 9.0 * k + top)
			return [h, Vector3(-2.0, 4.0, 19.0 + top + sin(c * 2.0) * 1.5)]
	return [Vector3(5.5, -swing * 3.0, 16.0 + top), Vector3(-5.5, swing * 3.0, 16.0 + top)]


func _torso(foot: Vector2, body: Vector3, shirt: Color) -> void:
	_part(_depth(0, body.y), func() -> void:
		var c := foot + _ground(0, body.y) - Vector2(0, body.z)
		var w := _width(6.2)
		# Shoulders wider than the waist: two stacked ellipses.
		_ellipse(c + Vector2(0, 2.5), Vector2(w * 0.85, 6.5), shirt)
		_ellipse(c - Vector2(0, 3.0), Vector2(w, 4.5), shirt.lightened(0.04))
		# Collar / neckline.
		if _forward.y > -0.3:
			_ellipse(c - Vector2(0, 7.0) + _ground(0, 1.5), Vector2(2.0, 1.0), SKIN.darkened(0.08)))


func _skirt(foot: Vector2, lean: float, top: float) -> void:
	var colour: Color = _look["legs"]
	_part(_depth(0, lean) - 0.1, func() -> void:
		var waist := foot + _ground(0, lean * 0.6) - Vector2(0, 17.0 + top)
		var hem := foot - Vector2(0, 2.0)
		var w := _width(5.0)
		var poly := PackedVector2Array([waist - Vector2(w * 0.8, 0), waist + Vector2(w * 0.8, 0),
				hem + Vector2(w * 1.3, 0), hem - Vector2(w * 1.3, 0)])
		_polygon(poly, colour)
		_line(hem - Vector2(w * 1.25, 1), hem + Vector2(w * 1.25, 1), colour.darkened(0.25), 1))


func _head(foot: Vector2, head: Vector3) -> void:
	var hair: Color = _look["hair"]
	var hat := String(_look.get("hat", ""))
	var hat_colour: Color = _look.get("hat_colour", Color(0.85, 0.72, 0.4))
	_part(_depth(0, head.y) + 0.2, func() -> void: _draw_head(foot, head, hair, hat, hat_colour))


func _draw_head(foot: Vector2, head: Vector3, hair: Color, hat: String, hat_colour: Color) -> void:
	var c := foot + _ground(0, head.y) - Vector2(0, head.z)
	# Neck, then head.
	_ellipse(c + Vector2(0, 4.5), Vector2(1.8, 1.8), SKIN.darkened(0.1))
	_ellipse(c, Vector2(4.4, 4.8), SKIN)
	# Hair: back of the head, a fringe at the front.
	var back := c + _ground(0, -1.6) - Vector2(0, 1.2)
	_ellipse(back, Vector2(4.6, 4.0 if _forward.y < 0.0 else 3.2), hair)
	if _forward.y > -0.3:
		var face := c + _ground(0, 3.6)
		for side: float in [-1.0, 1.0]:
			var eye := face + _ground(side * 1.7, 0) - Vector2(0, 0.5)
			if absf(_right.x) > 0.4 or side * _right.x * -1.0 > -0.5:
				_pixel(eye, Color(0.15, 0.1, 0.08))
		_pixel(face + Vector2(0, 2.0), SKIN.darkened(0.2))
		if _look.get("beard", false):
			_ellipse(face + Vector2(0, 2.8), Vector2(2.6, 1.6), hair)
	match hat:
		"straw":
			var brim := c - Vector2(0, 3.5)
			_ellipse(brim, Vector2(8.5, 3.0), Color(0.88, 0.76, 0.42))
			_ellipse(brim - Vector2(0, 2.0), Vector2(4.2, 2.6), Color(0.92, 0.8, 0.46))
			_line(brim - Vector2(4, 0.5), brim + Vector2(4, -0.5), Color(0.6, 0.35, 0.2), 1)
		"veil":
			# Beekeeper: pale wide hat with a mesh veil over the face (dithered, not translucent).
			var vb := c - Vector2(0, 3.5)
			for y: int in range(int(vb.y), int(c.y + 5.0)):
				for x: int in range(int(c.x - 5.0), int(c.x + 6.0)):
					if (x + y) % 2 == 0:
						_pixel(Vector2(x, y), Color(0.82, 0.8, 0.74))
			_ellipse(vb, Vector2(8.0, 2.8), hat_colour)
			_ellipse(vb - Vector2(0, 2.0), Vector2(4.0, 2.4), hat_colour.lightened(0.08))
		"wide":
			var brim := c - Vector2(0, 3.5)
			_ellipse(brim, Vector2(7.5, 2.6), hat_colour)
			_ellipse(brim - Vector2(0, 2.0), Vector2(4.0, 2.4), hat_colour.lightened(0.08))
		"cap":
			_ellipse(c - Vector2(0, 3.5), Vector2(4.8, 2.6), hat_colour)
			_ellipse(c - Vector2(0, 3.0) + _ground(0, 3.5), Vector2(2.8, 1.0), hat_colour.darkened(0.15))
		"flour_cap":
			_ellipse(c - Vector2(0, 4.0), Vector2(5.0, 3.0), Color(0.95, 0.94, 0.9))
		"baker_cap":
			_ellipse(c - Vector2(0, 4.5), Vector2(4.6, 3.0), Color(0.97, 0.96, 0.93))
			_ellipse(c - Vector2(0, 7.0), Vector2(4.0, 2.6), Color(1, 1, 0.98))
		"kerchief":
			_ellipse(c - Vector2(0, 2.5), Vector2(5.0, 3.6), hat_colour)
			var knot := c + _ground(0, -4.0) + Vector2(0, -1.0)
			if _forward.y < 0.3:
				_ellipse(knot, Vector2(1.6, 1.4), hat_colour.darkened(0.15))
		"kettle":
			# Kettle hat: a steel dome with a wide brim, a rivet line and a bright rim.
			var brim := c - Vector2(0, 3.0)
			_ellipse(brim, Vector2(7.0, 2.6), C_STEEL.darkened(0.12))
			_line(brim - Vector2(6.5, -0.5), brim + Vector2(6.5, 0.5), C_STEEL.lightened(0.2), 1)
			_ellipse(brim - Vector2(0, 2.4), Vector2(4.4, 3.2), C_STEEL)
			_pixel(brim - Vector2(1.5, 4.2), Color(1, 1, 1))
			_line(brim - Vector2(0, 5.3), brim - Vector2(0, 1.0), C_STEEL.darkened(0.25), 1)
		"nasal":
			# Conical helmet with a nose guard over a mail coif.
			_ellipse(c + Vector2(0, 2.5), Vector2(4.8, 3.6), C_MAIL)
			for k: int in 7:
				_pixel(c + Vector2(-3 + k, 3.0 + (k % 2)), C_MAIL.darkened(0.3))
			var dome := c - Vector2(0, 2.8)
			_ellipse(dome, Vector2(4.7, 3.4), C_STEEL)
			_polygon(PackedVector2Array([dome - Vector2(3.0, 1.0), dome + Vector2(3.0, -1.0),
					dome - Vector2(0, 6.0)]), C_STEEL.lightened(0.06))
			_line(dome + Vector2(-4.6, 1.2), dome + Vector2(4.6, 1.2), C_STEEL.darkened(0.3), 1)
			_pixel(dome - Vector2(1.5, 3.5), Color(1, 1, 1))
			if _forward.y > -0.3:
				var nose := c + _ground(0, 4.2)
				_line(nose - Vector2(0, 3.5), nose + Vector2(0, 1.0), C_STEEL.lightened(0.1), 1)
		"great_helm":
			# Flat-topped great helm with an eye slit, a breathing cross and a red crest.
			_ellipse(c - Vector2(0, 0.5), Vector2(4.8, 5.6), C_STEEL)
			_ellipse(c - Vector2(0, 5.4), Vector2(4.6, 1.6), C_STEEL.lightened(0.15))
			_line(c + Vector2(-4.6, 1.5), c + Vector2(4.6, 1.5), C_STEEL.darkened(0.2), 1)
			if _forward.y > -0.3:
				var face := c + _ground(0, 3.4)
				_line(face + Vector2(-2.6, -1.4), face + Vector2(2.6, -1.4), Color(0.08, 0.07, 0.08), 1)
				_line(face + Vector2(0, -0.4), face + Vector2(0, 3.2), _gold, 1)
				_line(face + Vector2(-1.2, 1.2), face + Vector2(1.2, 1.2), _gold, 1)
			_pixel(c - Vector2(2.0, 4.0), Color(1, 1, 1))
			for k: int in 5:
				var plume := c - Vector2(0, 7.0 + k * 0.9) + _ground(0, -k * 0.9)
				_ellipse(plume, Vector2(1.4, 1.2), _royal.lightened(0.05 * k))
		"archer_hood":
			# A hood with its point hanging down the back; the face shows.
			_ellipse(c - Vector2(0, 1.0) + _ground(0, -0.8), Vector2(5.4, 5.6), hat_colour)
			var tip := c + _ground(0, -4.5) + Vector2(0, 3.0)
			_line(c + _ground(0, -3.0) - Vector2(0, 2.0), tip, hat_colour.darkened(0.2), 2)
			if _forward.y > -0.3:
				var face := c + _ground(0, 3.0)
				_ellipse(face, Vector2(3.0, 3.4), SKIN)
				_pixel(face + _ground(-1.4, 0) - Vector2(0, 0.5), Color(0.15, 0.1, 0.08))
				_pixel(face + _ground(1.4, 0) - Vector2(0, 0.5), Color(0.15, 0.1, 0.08))
				_pixel(face + Vector2(0, 1.6), SKIN.darkened(0.2))
		"hood":
			_ellipse(c - Vector2(0, 1.5) + _ground(0, -0.8), Vector2(5.6, 5.4), hat_colour)
			if _forward.y > -0.3:
				_ellipse(c + _ground(0, 3.0), Vector2(3.0, 3.4), SKIN)
				_pixel(c + _ground(0, 3.6) + _ground(-1.4, 0) - Vector2(0, 0.5), Color(0.15, 0.1, 0.08))
				_pixel(c + _ground(0, 3.6) + _ground(1.4, 0) - Vector2(0, 0.5), Color(0.15, 0.1, 0.08))


func _tool(foot: Vector2, tool: String, hand: Vector3, other: Vector3, work: String, t: float) -> void:
	var h := foot + _ground(hand.x, hand.y) - Vector2(0, hand.z)
	var o := foot + _ground(other.x, other.y) - Vector2(0, other.z)
	# Direction the tool points, in screen space.
	var dir := Vector2(0, -1)
	match work:
		"overhead":
			var k := 0.5 - 0.5 * cos(TAU * t)
			dir = (_ground(0, -1.0) * 0.6 + Vector2(0, -1)).lerp(_ground(0, 1.0) * 1.2 + Vector2(0, 0.6), k).normalized()
		"low":
			dir = (_ground(0.5, 1.0) + Vector2(0, 0.4)).normalized()
		"push", "stir":
			dir = (_ground(0, 1.0) + Vector2(0, 0.9)).normalized()
		"cast", "hold", "reel":
			var lift: float = {"cast": 0.6 + 0.6 * cos(TAU * t), "hold": 0.35, "reel": 0.35 + 0.5 * (0.5 - 0.5 * cos(TAU * t))}[work]
			dir = (_ground(0, 1.0) * 1.3 + Vector2(0, -lift)).normalized()
		_:
			dir = (Vector2(0, -1) + _ground(0, 0.3)).normalized()
	var depth := _depth(hand.x, hand.y) + 0.3
	_part(depth, func() -> void: _draw_tool(tool, h, dir, work, t))
	var _o := o


func _draw_tool(tool: String, h: Vector2, dir: Vector2, work: String, t: float) -> void:
	match tool:
		"axe":
			var tip := h + dir * 11.0
			_line(h - dir * 2.0, tip, C_WOOD, 1)
			_polygon(PackedVector2Array([tip, tip + dir.orthogonal() * 4.0 - dir * 2.0, tip + dir.orthogonal() * 3.0 - dir * 4.0]), C_IRON)
		"pick":
			var tip := h + dir * 11.0
			_line(h - dir * 2.0, tip, C_WOOD, 1)
			_line(tip - dir.orthogonal() * 4.0 - dir, tip + dir.orthogonal() * 4.0 - dir, C_IRON, 1)
		"hammer":
			var tip := h + dir * 7.0
			_line(h - dir, tip, C_WOOD, 1)
			_line(tip - dir.orthogonal() * 2.0, tip + dir.orthogonal() * 2.0, C_IRON.darkened(0.2), 2)
		"hoe":
			var tip := h + dir * 15.0
			_line(h - dir * 3.0, tip, C_WOOD, 1)
			_line(tip, tip + dir.orthogonal() * 3.0 + dir * 1.5, C_IRON, 2)
		"sickle", "hook":
			_line(h, h + dir * 3.0, C_WOOD, 1)
			var c := h + dir * 6.0
			for k: int in 6:
				var a := dir.angle() - 1.2 + k * 0.45
				_pixel(c + Vector2(cos(a), sin(a)) * 3.5, C_IRON)
		"saw":
			var along := _ground(0, 1.0).normalized() if _ground(0, 1.0).length() > 0.1 else Vector2(1, 0)
			var a := h - along * 3.0
			var b := h + along * 9.0
			_line(a, b, C_IRON, 2)
			_line(a + Vector2(0, 2), b + Vector2(0, 2), C_IRON.darkened(0.35), 1)
			_line(a - along * 2.0, a, C_WOOD, 2)
		"peel":
			var tip := h + dir * 13.0
			_line(h - dir * 4.0, tip, C_WOOD.lightened(0.15), 1)
			_ellipse(tip, Vector2(2.5, 1.5), C_WOOD.lightened(0.25))
		"paddle":
			var tip := h + Vector2(0, 9.0) + _ground(0, 1.5)
			_line(h - Vector2(0, 5), tip, C_WOOD.lightened(0.1), 1)
			_ellipse(tip, Vector2(1.5, 2.5), C_WOOD.lightened(0.2))
		"rod":
			var tip := h + dir * 20.0
			_line(h - dir * 2.0, tip, C_WOOD.lightened(0.2), 1)
			if work in ["hold", "reel"]:
				var bob := tip + Vector2(0, 10.0 + sin(TAU * t) * 1.0)
				_line(tip, bob, Color(0.85, 0.85, 0.8, 0.8), 1)
				_pixel(bob, Color(0.9, 0.25, 0.2))
		"staff":
			_line(h + Vector2(0, 14), h - Vector2(0, 10), C_WOOD.lightened(0.1), 1)
		"crook":
			_line(h + Vector2(0, 14), h - Vector2(0, 14), C_WOOD.lightened(0.1), 1)
			var top := h - Vector2(0, 14)
			for k: int in 5:
				var a := PI + k * PI / 4.0
				_pixel(top + Vector2(2.0 + cos(a) * 2.0, sin(a) * 2.5), C_WOOD.lightened(0.1))
		"spade":
			var tip := h + dir * 13.0
			var side := dir.orthogonal()
			_line(h - dir * 4.0, tip, C_WOOD.lightened(0.1), 1)
			_line(h - dir * 4.0 - side * 1.5, h - dir * 4.0 + side * 1.5, C_WOOD, 1)
			_polygon(PackedVector2Array([tip - side * 2.0, tip + side * 2.0, tip + dir * 4.0 + side * 1.5,
					tip + dir * 4.0 - side * 1.5]), C_IRON)
		"shears":
			var tip := h + dir * 5.0
			_line(h, tip + dir.orthogonal(), C_IRON, 1)
			_line(h, tip - dir.orthogonal(), C_IRON.darkened(0.2), 1)
		"smoker":
			_ellipse(h + Vector2(0, 2.5), Vector2(2.0, 3.0), Color(0.6, 0.45, 0.28))
			_line(h - Vector2(0, 0.5), h - Vector2(-1, 3), C_IRON, 1)
			_pixel(h - Vector2(-2, 5.0 + sin(TAU * t)), Color(0.82, 0.82, 0.8))
		"tongs":
			var tip := h + dir * 9.0
			_line(h - dir, tip + dir.orthogonal() * 0.8, C_IRON.darkened(0.3), 1)
			_line(h - dir, tip - dir.orthogonal() * 0.8, C_IRON.darkened(0.15), 1)
			if work in ["push", "bend"]:
				_line(tip - dir.orthogonal() * 1.5, tip + dir.orthogonal() * 1.5 + dir * 2.0, Color(1.0, 0.55, 0.15), 2)
		"knife":
			_line(h, h + dir * 2.0, C_WOOD, 1)
			_line(h + dir * 2.0, h + dir * 5.0, C_IRON.lightened(0.2), 1)
		"brush":
			_ellipse(h + dir * 1.5, Vector2(2.2, 1.4), C_WOOD.lightened(0.15))
			_line(h + dir * 1.5 + Vector2(-2, 1), h + dir * 1.5 + Vector2(2, 1), Color(0.3, 0.22, 0.14), 1)
		"rake":
			var tip := h + dir * 14.0
			var side := dir.orthogonal()
			_line(h - dir * 3.0, tip, C_WOOD.lightened(0.1), 1)
			_line(tip - side * 3.0, tip + side * 3.0, C_IRON.darkened(0.2), 1)
			for k: int in 4:
				_pixel(tip - side * 3.0 + side * 2.0 * k + dir, C_IRON.darkened(0.3))
		"mug":
			_ellipse(h - Vector2(0, 1.5), Vector2(1.6, 2.2), Color(0.8, 0.62, 0.3))
			_pixel(h - Vector2(0, 4), Color(0.97, 0.95, 0.88))
			_pixel(h - Vector2(-2, 1.5), Color(0.6, 0.45, 0.2))



# --- Soldiers (M7 part 1) ------------------------------------------------------------------

## Hands of a soldier: [right (weapon), left (shield or bow)], in body space.
func _soldier_hands(pose: Dictionary, top: float) -> Array:
	var swing: float = pose.get("swing", 0.0)
	var t: float = pose.get("t", 0.0)
	var c := TAU * t
	var weapon := String(_look["weapon"])
	var drill := String(pose.get("drill", ""))
	var right := Vector3(5.5, -swing * 3.0, 16.0 + top)
	var left := Vector3(-5.5, swing * 3.0, 16.0 + top)
	match weapon:
		"spear", "halberd":
			right = Vector3(6.2, 1.5 - swing * 1.0, 18.0 + top)
		"crossbow":
			# Carried at the hip, the bow forward.
			right = Vector3(4.5, 0.5 - swing * 1.0, 17.0 + top)
			left = Vector3(-1.0, 6.0, 18.0 + top)
		"bow":
			left = Vector3(-5.0, 1.5 + swing * 2.0, 17.0 + top)
	if _look.has("shield"):
		left = Vector3(-5.6, 2.5, 19.0 + top)
	if _look.get("mounted", false) and drill == "":
		# Reins in the left hand, the sword arm resting.
		left = Vector3(-2.5, 5.5, 19.0 + top)
		right = Vector3(4.5, 3.0, 19.0 + top)
	match drill:
		"thrust":
			# Spear levelled at the hip, thrust forward and drawn back.
			var k := maxf(sin(c), 0.0)
			right = Vector3(3.8, 2.0 + 7.0 * k, 19.0 + top)
			left = Vector3(-1.5, 6.0 + 7.0 * k, 21.0 + top)
		"draw":
			# Bow arm out in front at shoulder height, string drawn to the cheek, loosed at the end.
			var k := 0.5 - 0.5 * cos(c) if t < 0.8 else 0.0
			left = Vector3(-1.5, 11.0, 28.0 + top)
			right = Vector3(-0.5, 9.5 - 8.5 * k, 28.5 + top)
		"aim":
			# Crossbow at the shoulder, aimed, loosed at 0.5; then lowered and spanned again.
			if t < 0.55:
				right = Vector3(1.2, 5.0, 28.0 + top)
				left = Vector3(-0.8, 12.0, 27.5 + top)
			else:
				var k := sin((t - 0.55) / 0.45 * PI)
				right = Vector3(3.0, 3.0 - 2.0 * k, 22.0 + top - 4.0 * k)
				left = Vector3(-0.5, 9.0, 20.0 + top - 2.0 * k)
		"slash":
			# Up behind the head, a cut down across the front; the shield held forward.
			var k := 0.5 - 0.5 * cos(c)
			var up := Vector3(4.0, -2.0, 38.0 + top)
			var down := Vector3(-1.0, 8.0, 17.0 + top)
			right = up.lerp(down, k * k)
			left = Vector3(-4.5, 6.0, 21.0 + top)
	return [right, left]


## Armour over the shirt: quilting, a studded jerkin, or ring mail with a tabard.
func _armour(foot: Vector2, body: Vector3, lean: float, top: float) -> void:
	var armour := String(_look["armour"])
	_part(_depth(0, body.y) + 0.02, func() -> void:
		var c := foot + _ground(0, body.y) - Vector2(0, body.z)
		var w := _width(6.2)
		if armour == "gambeson":
			# Quilted lines down the coat and a collar.
			var shirt: Color = _look["shirt"]
			for k: int in 4:
				var x := -w * 0.75 + k * w * 0.5
				_line(c + Vector2(x, -6.0), c + Vector2(x * 0.85, 8.0), shirt.darkened(0.18), 1)
			_line(c + Vector2(-w, -1.0), c + Vector2(w, -1.0), shirt.darkened(0.12), 1)
			_line(c + Vector2(-w * 0.85, 4.0), c + Vector2(w * 0.85, 4.0), shirt.darkened(0.12), 1)
		elif armour == "leather":
			# A brown jerkin with bright studs over the green shirt.
			_ellipse(c + Vector2(0, 1.5), Vector2(w * 0.8, 6.0), C_LEATHER)
			for k: int in 6:
				_pixel(c + Vector2(-w * 0.55 + (k % 3) * w * 0.55, -1.0 + (k / 3) * 4.0), _gold.lightened(0.2))
		elif armour == "plate":
			# Mail under a steel breastplate with a ridge and a bright edge, and pauldrons.
			for y: int in range(int(c.y - 7.5), int(c.y + 9.0)):
				for x: int in range(int(c.x - w), int(c.x + w) + 1):
					var d := Vector2((x + 0.5 - c.x) / w, (y + 0.5 - c.y - 1.0) / 8.0)
					if d.length() <= 1.0 and (x + y) % 2 == 0:
						_pixel(Vector2(x, y), C_MAIL.darkened(0.22))
			_ellipse(c + Vector2(0, -0.5), Vector2(w * 0.78, 5.6), C_STEEL.darkened(0.08))
			_ellipse(c + Vector2(-w * 0.18, -2.0), Vector2(w * 0.35, 2.6), C_STEEL.lightened(0.22))
			_line(c + Vector2(0, -5.5), c + Vector2(0, 4.5), C_STEEL.darkened(0.25), 1)
			_line(c + Vector2(-w * 0.8, 4.8), c + Vector2(w * 0.8, 4.8), C_IRON.darkened(0.2), 1)
			for side: float in [-1.0, 1.0]:
				_ellipse(c + Vector2(side * w * 0.95, -6.0), Vector2(2.2, 1.6), C_STEEL)
				_pixel(c + Vector2(side * w * 0.95 - 0.5, -6.8), Color(1, 1, 1))
		elif armour == "mail":
			# Rings: a dither of darker and brighter pixels over the grey.
			for y: int in range(int(c.y - 7.5), int(c.y + 9.0)):
				for x: int in range(int(c.x - w), int(c.x + w) + 1):
					var d := Vector2((x + 0.5 - c.x) / w, (y + 0.5 - c.y - 1.0) / 8.0)
					if d.length() > 1.0:
						continue
					if (x + y) % 2 == 0:
						_pixel(Vector2(x, y), C_MAIL.darkened(0.22))
					elif (x * 3 + y) % 7 == 0:
						_pixel(Vector2(x, y), C_MAIL.lightened(0.25)))
	if _look.get("tabard", false):
		# The kingdom's tabard over the mail, front and back, with a gold cross.
		_part(_depth(0, lean + 3.0) + 0.06, func() -> void:
			var w := _width(4.4)
			var neck := foot + _ground(0, lean + 2.6) - Vector2(0, 26.0 + top)
			var hem := foot + _ground(0, lean * 0.4 + 2.2) - Vector2(0, (8.0 if not _look.get("mounted", false) else 10.0) + top)
			_polygon(PackedVector2Array([neck - Vector2(w, 0), neck + Vector2(w, 0),
					hem + Vector2(w * 1.15, 0), hem - Vector2(w * 1.15, 0)]), _royal)
			_line(hem - Vector2(w * 1.1, 0), hem + Vector2(w * 1.1, 0), _gold, 1)
			var mid := neck.lerp(hem, 0.42)
			_line(mid - Vector2(0, 5.0), mid + Vector2(0, 5.0), _gold, 1)
			_line(mid - Vector2(w * 0.7, 1.0), mid + Vector2(w * 0.7, -1.0), _gold, 1))


## The soldier's weapon, shield, quiver and scabbard.
func _gear(foot: Vector2, pose: Dictionary, hands: Array, lean: float, top: float) -> void:
	var weapon := String(_look["weapon"])
	var drill := String(pose.get("drill", ""))
	var t: float = pose.get("t", 0.0)
	var right: Vector3 = hands[0]
	var left: Vector3 = hands[1]
	var rh := foot + _ground(right.x, right.y) - Vector2(0, right.z)
	var lh := foot + _ground(left.x, left.y) - Vector2(0, left.z)
	match weapon:
		"spear":
			var along := Vector3(0, 0, 1)   # upright
			if drill == "thrust":
				along = Vector3(0, 1, 0.12)   # levelled forward
			var butt := right - along * (12.0 if drill == "thrust" else 16.5)
			var tip := right + along * (18.0 if drill == "thrust" else 30.0)
			_part(_depth(right.x, right.y) + 0.35, func() -> void:
				var a := foot + _ground(butt.x, butt.y) - Vector2(0, butt.z)
				var b := foot + _ground(tip.x, tip.y) - Vector2(0, tip.z)
				_line(a, b, C_WOOD.darkened(0.1), 2)
				_line(a, b, C_WOOD.lightened(0.15), 1)
				var dir := (b - a).normalized()
				var side := dir.orthogonal()
				_polygon(PackedVector2Array([b + dir * 4.0, b + side * 1.6, b - side * 1.6]), C_STEEL)
				_pixel(b + dir * 2.0, Color(1, 1, 1))
				# A small pennon in the kingdom's colour below the head.
				if drill != "thrust":
					var flap := sin(TAU * t) * 0.8
					_polygon(PackedVector2Array([b - dir * 1.0, b - dir * 4.0, b - dir * 2.0 + Vector2(5.0, 1.0 + flap)]), _royal)
				_pixel(a, C_IRON.darkened(0.3)))
		"bow":
			_part(_depth(left.x, left.y) + 0.35, func() -> void:
				# A longbow upright in the left hand, its belly towards the target.
				var fwd := _ground(0, 1.0)
				var top_tip := lh - Vector2(0, 15.0) - fwd * 1.5
				var low_tip := lh + Vector2(0, 13.0) - fwd * 1.5
				var prev := top_tip
				for k: int in 9:
					var u := float(k + 1) / 9.0
					var p := top_tip.lerp(low_tip, u) + fwd * (sin(u * PI) * 3.5)
					_line(prev, p, C_WOOD.lightened(0.18), 1)
					prev = p
				_line(lh - Vector2(0, 1.5), lh + Vector2(0, 1.5), C_LEATHER.darkened(0.2), 1)
				var nock := rh if drill == "draw" else lh - fwd * 1.5
				_line(top_tip, nock, Color(0.92, 0.9, 0.82), 1)
				_line(nock, low_tip, Color(0.92, 0.9, 0.82), 1)
				if drill == "draw" and t < 0.8:
					# The arrow on the string, pointing ahead.
					var head := lh + fwd * 3.5
					_line(nock, head, C_WOOD.lightened(0.3), 1)
					_pixel(head + fwd * 0.8, C_STEEL)
					_pixel(nock - fwd * 0.6 + Vector2(0, -1), Color(0.95, 0.95, 0.95)))
		"halberd":
			# Like the spear, but with an axe blade, a back hook and a spike at the head.
			var along := Vector3(0, 0, 1)
			if drill == "thrust":
				along = Vector3(0, 1, 0.12)
			var butt := right - along * (12.0 if drill == "thrust" else 16.5)
			var tip := right + along * (20.0 if drill == "thrust" else 31.0)
			_part(_depth(right.x, right.y) + 0.35, func() -> void:
				var a := foot + _ground(butt.x, butt.y) - Vector2(0, butt.z)
				var b := foot + _ground(tip.x, tip.y) - Vector2(0, tip.z)
				_line(a, b, C_WOOD.darkened(0.15), 2)
				_line(a, b, C_WOOD.lightened(0.1), 1)
				var dir := (b - a).normalized()
				var side := dir.orthogonal()
				if side.x < 0:
					side = -side
				var neck := b - dir * 5.0
				# The spike.
				_line(b - dir * 1.0, b + dir * 3.5, C_STEEL, 1)
				_pixel(b + dir * 3.0, Color(1, 1, 1))
				# The axe blade: a curved edge on one side of the neck.
				_polygon(PackedVector2Array([neck + dir * 3.0, neck + side * 1.0 + dir * 3.5,
						neck + side * 4.8 + dir * 2.5, neck + side * 5.2 - dir * 0.5,
						neck + side * 4.4 - dir * 3.0, neck + side * 1.0 - dir * 2.5, neck - dir * 2.0]), C_STEEL)
				_line(neck + side * 4.8 + dir * 2.5, neck + side * 4.4 - dir * 3.0, C_STEEL.lightened(0.35), 1)
				# The hook behind.
				_line(neck - side * 0.5 + dir * 1.0, neck - side * 3.0 + dir * 0.0, C_STEEL.darkened(0.2), 1)
				_pixel(a, C_IRON.darkened(0.3)))
		"crossbow":
			# A crossbow: the stock along the aim, the steel bow across its nose, the string.
			_part(_depth(left.x, left.y) + 0.36, func() -> void:
				var fwd := _ground(0, 1.0).normalized()
				var across := _ground(1.0, 0).normalized()
				var butt := rh - fwd * 3.0
				var nose := lh + fwd * 3.0
				if drill != "aim":
					nose = lh + fwd * 2.0 + Vector2(0, -2.0)
				_line(butt, nose, C_WOOD.darkened(0.1), 2)
				_line(butt, nose, C_WOOD.lightened(0.15), 1)
				# The steel bow curved forward across the nose, the string straight between its
				# tips (owner's request 2026-11-08); the bolt lies on the stock while loaded.
				var prod_a := nose + across * 5.0 - fwd * 1.5
				var prod_b := nose - across * 5.0 - fwd * 1.5
				var prev := prod_a
				for k: int in 6:
					var u := float(k + 1) / 6.0
					var p := prod_a.lerp(prod_b, u) + fwd * (sin(u * PI) * 2.2)
					_line(prev, p, C_STEEL, 1)
					prev = p
				_line(prod_a, prod_b, Color(0.92, 0.9, 0.82), 1)
				if drill != "aim" or t < 0.5:
					_line(nose.lerp(butt, 0.45), nose + fwd * 1.5, C_WOOD.lightened(0.3), 1)
					_pixel(nose + fwd * 2.0, C_STEEL))
		"morning_star":
			if drill != "" or _look.get("mounted", false):
				_part(_depth(right.x, right.y) + 0.35, func() -> void:
					var dir := Vector2(0, -1)
					if drill == "slash":
						var k := 0.5 - 0.5 * cos(TAU * t)
						dir = (_ground(0, -1.0) * 0.5 + Vector2(0, -1)).lerp(_ground(0, 1.0) * 1.2 + Vector2(0, 0.7), k).normalized()
					_morning_star(rh, dir))
		"ladder":
			# A ladder on the right shoulder, sloping forward (M7 part 2, a ladderman).
			_part(_depth(right.x, right.y) + 0.4, func() -> void:
				var shoulder := foot + _ground(3.0, lean) - Vector2(0, 30.0 + top)
				var fwd := _ground(0, 1.0)
				var a := shoulder - fwd * 11.0 + Vector2(0, -3.0)
				var b := shoulder + fwd * 13.0 + Vector2(0, 4.0)
				var side := Vector2(0, -2.5)
				_line(a, b, C_WOOD.darkened(0.15), 1)
				_line(a + side, b + side, C_WOOD.lightened(0.1), 1)
				for k: int in 6:
					var p := a.lerp(b, (k + 0.5) / 6.0)
					_line(p, p + side, C_WOOD.lightened(0.2), 1))
		"sword":
			if drill != "" or _look.get("mounted", false):
				_part(_depth(right.x, right.y) + 0.35, func() -> void:
					var dir := Vector2(0, -1)
					if drill == "slash":
						var k := 0.5 - 0.5 * cos(TAU * t)
						dir = (_ground(0, -1.0) * 0.5 + Vector2(0, -1)).lerp(_ground(0, 1.0) * 1.2 + Vector2(0, 0.7), k).normalized()
					elif _look.get("mounted", false):
						dir = (Vector2(0, -1) + _ground(0, 0.6)).normalized()
					_sword(rh, dir))
	# Not drilling, the morning star hangs from the belt at the right hip.
	if weapon == "morning_star" and drill == "" and not _look.get("mounted", false):
		_part(_depth(3.8, lean + 0.6) + 0.03, func() -> void:
			var hip := foot + _ground(3.8, lean + 0.6) - Vector2(0, 17.0 + top)
			_morning_star(hip, Vector2(0.15, 1.0).normalized()))
	# The scabbard at the left hip (empty while the sword is out).
	if weapon == "sword":
		_part(_depth(-3.5, lean + 0.5) + 0.03, func() -> void:
			var hip := foot + _ground(-3.6, lean + 0.6) - Vector2(0, 17.0 + top)
			var end := hip + _ground(-0.6, -3.0) + Vector2(0, 8.0)
			_line(hip, end, C_LEATHER.darkened(0.25), 2)
			_pixel(end, _gold)
			if drill == "" and not _look.get("mounted", false):
				_line(hip - Vector2(0, 3.0), hip, C_LEATHER.lightened(0.1), 1)
				_line(hip - Vector2(1.5, 1.5), hip + Vector2(1.5, -1.5), _gold, 1))
	if _look.get("quiver", false):
		# A quiver on the back, its arrows fletched white and red.
		_part(_depth(2.0, lean - 3.0) - 0.05, func() -> void:
			var low := foot + _ground(2.0, lean - 3.2) - Vector2(0, 17.0 + top)
			var high := foot + _ground(3.0, lean - 3.6) - Vector2(0, 30.0 + top)
			_thick(low, high, 2.6, C_LEATHER)
			for k: int in 3:
				var f := high + Vector2(k - 1.0, -1.5 - (k % 2))
				_pixel(f, Color(0.95, 0.94, 0.9) if k != 1 else _royal)
				_pixel(f - Vector2(0, 1), Color(0.95, 0.94, 0.9)))
	if _look.has("shield"):
		_shield(foot, left, String(_look["shield"]), drill)


func _sword(h: Vector2, dir: Vector2) -> void:
	var side := dir.orthogonal()
	var tip := h + dir * 12.0
	_line(h + dir * 1.5, tip, C_STEEL, 2)
	_line(h + dir * 2.0 + side * 0.5, tip - dir, C_STEEL.lightened(0.3), 1)
	_line(h + dir * 1.5 - side * 2.5, h + dir * 1.5 + side * 2.5, _gold.darkened(0.15), 1)
	_line(h - dir * 1.0, h + dir * 1.0, C_LEATHER, 1)
	_pixel(h - dir * 2.0, _gold)


## A morning star held at [param h]: an oak haft along [param dir] with a spiked steel ball.
func _morning_star(h: Vector2, dir: Vector2) -> void:
	var head := h + dir * 9.0
	_line(h - dir * 1.5, head, C_WOOD.darkened(0.1), 2)
	_line(h - dir * 1.0, h + dir * 1.0, C_LEATHER, 1)
	_ellipse(head + dir * 1.5, Vector2(2.6, 2.6), C_STEEL.darkened(0.1))
	_pixel(head + dir * 1.5 - Vector2(1.0, 1.0), C_STEEL.lightened(0.4))
	for a: int in 6:
		var spike := Vector2.RIGHT.rotated(a * TAU / 6.0 + 0.3)
		_pixel(head + dir * 1.5 + spike * 3.6, C_STEEL.lightened(0.15))


## A shield on the left arm: round (wood with a boss, the kingdom's colours) or kite (with the
## gold cross). Facing outwards, or forwards while drilling; its back is plain wood.
func _shield(foot: Vector2, hand: Vector3, kind: String, drill: String) -> void:
	var normal := Vector3(-1, 0.35, 0) if drill == "" else Vector3(-0.35, 1, 0)
	normal = normal.normalized()
	var centre := hand + normal * 1.6 + Vector3(0, 0, 1.0)
	var u := Vector3(-normal.y, normal.x, 0).normalized()   # across, level
	var v := Vector3(0, 0, 1)
	var facing := (_right * normal.x + _forward * normal.y).y
	_part(_depth(centre.x, centre.y) + 0.4, func() -> void:
		var poly := PackedVector2Array()
		var r := 5.2
		if kind == "round":
			for k: int in 16:
				var a := k * TAU / 16.0
				var p := centre + u * cos(a) * r + v * sin(a) * r
				poly.append(foot + _ground(p.x, p.y) - Vector2(0, p.z))
		else:
			for q: Vector2 in [Vector2(-4.6, 6.0), Vector2(4.6, 6.0), Vector2(4.4, 1.0), Vector2(2.2, -5.0),
					Vector2(0, -8.0), Vector2(-2.2, -5.0), Vector2(-4.4, 1.0)]:
				var p := centre + u * q.x + v * q.y
				poly.append(foot + _ground(p.x, p.y) - Vector2(0, p.z))
		var front := facing > -0.15
		var fill := _royal if front else C_WOOD
		_polygon(poly, fill)
		for k: int in poly.size():
			_line(poly[k], poly[(k + 1) % poly.size()], C_IRON.darkened(0.15) if front else C_WOOD.darkened(0.3), 1)
		if not front:
			return
		var mid := foot + _ground(centre.x, centre.y) - Vector2(0, centre.z)
		var up := (foot + _ground(centre.x + v.x * 4.0, centre.y + v.y * 4.0) - Vector2(0, centre.z + 4.0)) - mid
		var across := (foot + _ground(centre.x + u.x * 4.0, centre.y + u.y * 4.0) - Vector2(0, centre.z)) - mid
		if kind == "round":
			# Gold quarters and a steel boss.
			_line(mid - up, mid + up, _gold, 1)
			_line(mid - across, mid + across, _gold, 1)
			_ellipse(mid, Vector2(1.4, 1.4), C_STEEL)
			_pixel(mid - Vector2(0.5, 0.5), Color(1, 1, 1))
		else:
			_line(mid - up * 1.2, mid + up * 1.0, _gold, 1)
			_line(mid - across * 0.8 + up * 0.35, mid + across * 0.8 + up * 0.35, _gold, 1))


# --- Horses --------------------------------------------------------------------------------

## A horse in body space under the rider (or alone for the herd): body, neck and head along
## [member _forward], legs in a walking gait ([param swing] -1..1 over a stride), the tail
## swishing. [param barded]: the kingdom's cloth and a saddle (a knight's mount).
func _horse(foot: Vector2, swing: float, t: float, breath: float, barded: bool) -> void:
	var coat: Color = HORSE["coat"]
	var mane: Color = HORSE["mane"]
	var gait := swing
	# Legs: front at f +5, hind at f -6; diagonal pairs move together.
	for leg: Array in [[2.0, 5.0, 1.0], [-2.0, 5.0, -1.0], [2.0, -6.0, -1.0], [-2.0, -6.0, 1.0]]:
		var s: float = leg[0]
		var f: float = leg[1]
		var phase: float = leg[2] * gait
		var top := Vector3(s, f, 12.0)
		var knee := Vector3(s, f + phase * 1.6 + (0.6 if f > 0 else -0.6), 6.5 + absf(phase) * 0.8)
		var hoof := Vector3(s, f + phase * 3.0, 0.8 + maxf(phase, 0.0) * 1.2)
		var shade := coat.darkened(0.12 if s < 0 else 0.0)
		_limb(foot, top, knee, 2.4, shade)
		_limb(foot, knee, hoof, 1.8, shade.darkened(0.05))
		_blob(foot, hoof + Vector3(0, 0.4, -0.4), Vector2(1.4, 0.9), HORSE["hoof"])
	# Body, neck, head.
	var lift := breath * 0.2
	_limb(foot, Vector3(0, -7.0, 14.0 + lift), Vector3(0, 5.5, 14.8 + lift), 9.0, coat)
	_limb(foot, Vector3(0, 6.0, 17.0 + lift), Vector3(0, 9.5, 23.5 + lift), 4.6, coat.lightened(0.04))
	_limb(foot, Vector3(0, 5.3, 19.0 + lift), Vector3(0, 8.8, 26.0 + lift), 1.8, mane)
	_limb(foot, Vector3(0, 10.2, 24.5 + lift), Vector3(0, 13.4, 20.2 + lift), 3.6, coat.lightened(0.06))
	_part(_depth(0, 11.5) + 0.05, func() -> void:
		var forehead := foot + _ground(0, 10.6) - Vector2(0, 26.4 + lift)
		_pixel(forehead + _ground(1.0, 0) - Vector2(0, 1.0), coat.darkened(0.2))
		_pixel(forehead + _ground(-1.0, 0) - Vector2(0, 1.0), coat.darkened(0.2))
		if _forward.y > -0.4:
			var face := foot + _ground(0, 12.2) - Vector2(0, 23.0 + lift)
			_line(face - Vector2(0, 2.0), face + Vector2(0, 2.0), HORSE["blaze"], 1)
		for side: float in [-1.0, 1.0]:
			var eye := foot + _ground(side * 1.6, 11.0) - Vector2(0, 24.3 + lift)
			if (_right * side).y > -0.2:
				_pixel(eye, Color(0.08, 0.06, 0.05)))
	# Tail.
	var swish := sin(TAU * t + gait) * 1.2
	_limb(foot, Vector3(swish * 0.3, -8.5, 16.0 + lift), Vector3(swish, -10.5, 8.0 + lift), 2.2, mane)
	if barded:
		# The kingdom's cloth over the body with a gold hem, and a saddle on it.
		_limb(foot, Vector3(0, -6.5, 12.6 + lift), Vector3(0, 5.0, 13.2 + lift), 9.6, _royal)
		_part(_depth(0, 5.0) + 0.02, func() -> void:
			var a := foot + _ground(0, -6.5) - Vector2(0, 8.0 + lift)
			var b := foot + _ground(0, 5.0) - Vector2(0, 8.6 + lift)
			_line(a, b, _gold, 1))
		_limb(foot, Vector3(0, -2.5, 18.6 + lift), Vector3(0, 1.5, 18.8 + lift), 4.0, C_LEATHER)
		# Reins from the bit to the rider's hands.
		_part(_depth(0, 10.0), func() -> void:
			var bit := foot + _ground(0, 13.2) - Vector2(0, 21.5 + lift)
			var hands := foot + _ground(-1.0, 5.0) - Vector2(0, 26.0 + lift)
			_line(bit, hands, C_LEATHER.darkened(0.3), 1))


## The stud farm's horses as goods (ART_SPEC §5, §8, like the pigs): a herd sheet of 4
## frames 64x64 (1, 2, 3, 4+ horses), a led horse 24x24 in 5 rows, an icon 32x32.
func _horse_goods() -> void:
	_look = {"shirt": Color(), "legs": Color(), "hair": Color(), "tool": ""}
	var herd := Image.create_empty(64 * 4, 64, false, Image.FORMAT_RGBA8)
	var spots: Array = [[Vector2(32, 44), 2], [Vector2(20, 38), 1], [Vector2(46, 34), 3], [Vector2(28, 30), 6]]
	for frame: int in 4:
		var img := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
		var placed: Array = spots.slice(0, frame + 1)
		placed.sort_custom(func(a: Array, b: Array) -> bool: return (a[0] as Vector2).y < (b[0] as Vector2).y)
		for spot: Array in placed:
			var one := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
			_one_horse(one, spot[0], int(spot[1]), 0.62, 0.0)
			_outline(one)
			img.blend_rect(one, Rect2i(0, 0, 64, 64), Vector2i.ZERO)
		herd.blit_rect(img, Rect2i(0, 0, 64, 64), Vector2i(frame * 64, 0))
	herd.save_png("res://assets/goods/stacks/horse.png")
	var led := Image.create_empty(24, 24 * ROWS, false, Image.FORMAT_RGBA8)
	for row: int in ROWS:
		var one := Image.create_empty(24, 24, false, Image.FORMAT_RGBA8)
		_one_horse(one, Vector2(12, 21), row, 0.42, 0.0)
		_outline(one)
		led.blit_rect(one, Rect2i(0, 0, 24, 24), Vector2i(0, row * 24))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/goods/carried/animal"))
	led.save_png("res://assets/goods/carried/animal/horse.png")
	var icon := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	_one_horse(icon, Vector2(16, 29), 2, 0.6, 0.0)
	_outline(icon)
	icon.save_png("res://assets/goods/icons/horse.png")
	_shrink_foot = FOOT
	_scale = SCALE


## One standing horse drawn into [param img] with its hooves at [param at], facing [param dir]
## (0 = S ... 7 = SW, as the rows), shrunk by [param scale].
func _one_horse(img: Image, at: Vector2, dir: int, scale: float, swing: float) -> void:
	var angle := PI / 2.0 - dir * TAU / 8.0
	_forward = Vector2(cos(angle), sin(angle))
	_right = Vector2(-_forward.y, _forward.x)
	_shrink_foot = at
	_scale = scale
	_parts = []
	_horse(at, swing, 0.0, 0.0, false)
	_parts.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for part: Array in _parts:
		(part[1] as Callable).call()
	_flush(img)


# --- Drawing in body space -----------------------------------------------------------------

var _target_img: Image
var _queue: Array = []
## Shrinking around the feet (people: FOOT and SCALE; the horses of the herd: smaller).
var _shrink_foot: Vector2 = FOOT
var _scale: float = SCALE


func _ground(s: float, f: float) -> Vector2:
	var v := _right * s + _forward * f
	return Vector2(v.x, v.y * 0.5)


## Larger = nearer to the camera.
func _depth(s: float, f: float) -> float:
	var v := _right * s + _forward * f
	return v.y


## Apparent half-width of the body for the facing (narrower seen from the side).
func _width(full: float) -> float:
	return full * (0.62 + 0.38 * absf(_right.x))


func _part(depth: float, draw: Callable) -> void:
	_parts.append([depth, draw])


func _limb(foot: Vector2, a: Vector3, b: Vector3, width: float, colour: Color) -> void:
	_part(_depth((a.x + b.x) * 0.5, (a.y + b.y) * 0.5), func() -> void:
		var pa := foot + _ground(a.x, a.y) - Vector2(0, a.z)
		var pb := foot + _ground(b.x, b.y) - Vector2(0, b.z)
		_thick(pa, pb, width, colour))


func _blob(foot: Vector2, at: Vector3, radius: Vector2, colour: Color) -> void:
	_part(_depth(at.x, at.y) + 0.01, func() -> void:
		_ellipse(foot + _ground(at.x, at.y) - Vector2(0, at.z), radius, colour))


func _ellipse_at(foot: Vector2, at: Vector3, radius: Vector2, colour: Color) -> void:
	_ellipse(foot + _ground(at.x, at.y) - Vector2(0, at.z), radius, colour)


func _flush(img: Image) -> void:
	for op: Array in _queue:
		match String(op[0]):
			"px":
				var p: Vector2i = op[1]
				if Rect2i(Vector2i.ZERO, img.get_size()).has_point(p):
					img.set_pixelv(p, op[2])
	_queue = []


func _pixel(p: Vector2, colour: Color) -> void:
	_queue.append(["px", Vector2i(_shrink(p).floor()), colour])


func _shrink(p: Vector2) -> Vector2:
	return _shrink_foot + (p - _shrink_foot) * _scale


func _ellipse(centre: Vector2, radius: Vector2, colour: Color) -> void:
	for y: int in range(int(floor(centre.y - radius.y)) - 1, int(ceil(centre.y + radius.y)) + 1):
		for x: int in range(int(floor(centre.x - radius.x)) - 1, int(ceil(centre.x + radius.x)) + 1):
			var d := Vector2((x + 0.5 - centre.x) / maxf(radius.x, 0.5), (y + 0.5 - centre.y) / maxf(radius.y, 0.5))
			if d.length() <= 1.0:
				# Light from above and the front: lighter top, darker bottom edge.
				var shade := clampf(d.y * 0.14 + d.x * 0.04, -0.12, 0.16)
				_pixel(Vector2(x, y), colour.darkened(shade) if shade > 0.0 else colour.lightened(-shade))


func _thick(a: Vector2, b: Vector2, width: float, colour: Color) -> void:
	var steps := maxi(1, int(ceil(a.distance_to(b) * 2.0)))
	for s: int in steps + 1:
		var p := a.lerp(b, float(s) / steps)
		_ellipse(p, Vector2(width * 0.5, width * 0.5), colour)


func _line(a: Vector2, b: Vector2, colour: Color, width: int) -> void:
	var steps := maxi(1, int(ceil(a.distance_to(b))))
	for s: int in steps + 1:
		var p := a.lerp(b, float(s) / steps)
		for dx: int in width:
			for dy: int in width:
				_pixel(p + Vector2(dx - width / 2, dy - width / 2), colour)


func _polygon(poly: PackedVector2Array, colour: Color) -> void:
	var bounds := Rect2(poly[0], Vector2.ZERO)
	for p: Vector2 in poly:
		bounds = bounds.expand(p)
	for y: int in range(int(bounds.position.y) - 1, int(bounds.end.y) + 2):
		for x: int in range(int(bounds.position.x) - 1, int(bounds.end.x) + 2):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), poly):
				_pixel(Vector2(x, y), colour.darkened(0.08 * float((y - int(bounds.position.y)) > bounds.size.y * 0.6)))


## Selective outline: transparent pixels next to the figure get a dark version of it.
func _outline(img: Image) -> void:
	var size := img.get_size()
	var edge: Dictionary = {}
	for y: int in size.y:
		for x: int in size.x:
			var c := img.get_pixel(x, y)
			if c.a == 0.0:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q := Vector2i(x, y) + d
				if Rect2i(Vector2i.ZERO, size).has_point(q) and img.get_pixelv(q).a == 0.0 and not edge.has(q):
					edge[q] = Color(c.r * 0.32, c.g * 0.27, c.b * 0.25, 1.0)
	for q: Vector2i in edge:
		img.set_pixelv(q, edge[q])


func _save(pair: Array, kind: String, anim: String) -> void:
	var dir := OUT.path_join(kind)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	(pair[0] as Image).save_png(dir.path_join(anim + ".png"))
	if pair[1] != null:
		(pair[1] as Image).save_png(dir.path_join(anim + ".anchors.png"))


## Points every profession's visual definition at its own character, untinted.
func _write_visuals() -> void:
	for kind: String in PEOPLE.keys() + SOLDIERS.keys() + BANDITS.keys():
		var path := "res://data/visuals/agents/%s.tres" % kind
		var text := "[gd_resource type=\"Resource\" script_class=\"AgentVisualDef\" format=3]\n\n" \
				+ "[ext_resource type=\"Script\" path=\"res://src/defs/visuals/agent_visual_def.gd\" id=\"1_vis\"]\n\n" \
				+ "[resource]\nscript = ExtResource(\"1_vis\")\ncharacter = &\"%s\"\n" % kind
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(text)
