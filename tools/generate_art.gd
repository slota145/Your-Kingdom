extends SceneTree
## Final building art drawn in code (owner decision 2026-11-05: better than the placeholders,
## without PixelLab). Writes res://assets/buildings/<id>/<name>.png + .json in the layout of
## ART_SPEC §2 and §3.2, so it replaces placeholders file by file (ArtPaths: final art wins).
##
## Run: godot --headless --path . -s res://tools/generate_art.gd   (then --import)
##
## A building is a few volumes inside its footprint, a little smaller than its tiles so some
## ground shows around it: houses with ridge roofs, lean-tos (open sheds show the work inside),
## round towers (windmill, hop kiln) and towers with spires. Volumes are drawn back to front.
## Every face is a plane: each pixel is mapped back to face coordinates (u along, v up, in
## pixels) and coloured by a material: timber framing, stone, logs, planks, plaster, thatch,
## shingles, tiles, slate. Light comes from above and the front: the SW (left) faces are the
## brightest (ART_SPEC §1).

const OUT := "res://assets"
const TownHouseArt := preload("res://tools/town_house_art.gd")

const LIGHT_SW := 1.0
const LIGHT_SE := 0.8
const LIGHT_ROOF_SW := 1.06
const LIGHT_ROOF_SE := 0.86
const LIGHT_ROOF_BACK := 0.72

## Roof overhang beyond the walls, in tiles.
const OVERHANG := 0.12
## Gap between the footprint edge and the walls, in tiles (some ground shows around).
const INSET := 0.14
## A wall this far behind the entrance tile still gets the door (in tiles).
const DOOR_REACH := 0.15

const C_BEAM := Color(0.33, 0.21, 0.13)
const C_PLASTER := Color(0.9, 0.85, 0.73)
const C_STONE := Color(0.62, 0.6, 0.56)
const C_MORTAR := Color(0.45, 0.43, 0.4)
const C_GLASS := Color(0.16, 0.2, 0.26)
const C_DOOR := Color(0.42, 0.27, 0.15)
const C_THATCH := Color(0.79, 0.65, 0.38)
const C_SHINGLE := Color(0.5, 0.42, 0.34)
const C_TILE := Color(0.68, 0.3, 0.2)
const C_SLATE := Color(0.36, 0.4, 0.48)
const C_LOG := Color(0.52, 0.35, 0.2)
const C_PLANK := Color(0.58, 0.42, 0.26)
const C_IRON := Color(0.24, 0.24, 0.26)

## Building id -> list of looks (several = variants "base", "base_2"...). Each look has
## "volumes" (drawn back to front) and "props" ([name, grid x, grid y]).
## Volume kinds and keys (rect = [x0, y0, x1, y1] in footprint tiles):
## - house: rect, h, rh, ridge "x"/"y", ends [start, end] ("gable"/"hip"/"open"), walls, roof,
##   optional tint, shutters, floors, chimney ([grid x, grid y]),
## - lean: rect, low (side the roof slopes down to: "x" or "y"), h (low eave), hh (high side),
##   roof, walls, open (no front wall: the work inside shows),
## - round: centre [x, y], r (tiles), h, rh, walls, roof, sails,
## - tower: rect, h, spire, walls, roof, cross.
const BUILDINGS := {
	"hut": [
		{"volumes": [
			{"kind": "house", "rect": [0.14, 0.14, 1.42, 1.86], "h": 39.0, "rh": 26.0, "ridge": "y",
				"ends": ["gable", "gable"], "walls": "timber", "roof": "thatch",
				"shutters": Color(0.35, 0.45, 0.3), "chimney": [0.7, 0.9]},
			{"kind": "lean", "rect": [1.42, 0.3, 1.86, 1.08], "low": "x", "h": 25.0, "hh": 36.0,
				"roof": "thatch", "walls": "planks", "open": true, "inside": [["log_stack", 1.62, 0.95]]}],
		 "props": [["flowers", 0.75, 1.9]]},
		{"volumes": [
			{"kind": "house", "rect": [0.14, 0.14, 1.86, 1.42], "h": 36.0, "rh": 24.0, "ridge": "x",
				"ends": ["gable", "gable"], "walls": "logs", "roof": "shingle",
				"shutters": Color(0.55, 0.25, 0.2), "chimney": [0.5, 0.6]},
			{"kind": "lean", "rect": [0.3, 1.42, 1.1, 1.86], "low": "y", "h": 24.0, "hh": 32.0,
				"roof": "shingle", "walls": "planks", "open": false}],
		 "props": [["bench", 1.55, 1.75], ["barrel", 1.85, 1.6]]},
		{"volumes": [
			{"kind": "house", "rect": [0.14, 0.14, 1.86, 1.05], "h": 36.0, "rh": 22.0, "ridge": "x",
				"ends": ["hip", "gable"], "walls": "plaster", "roof": "thatch",
				"shutters": Color(0.3, 0.4, 0.6), "chimney": [0.6, 0.55]},
			{"kind": "house", "rect": [0.95, 1.05, 1.86, 1.86], "h": 36.0, "rh": 20.0, "ridge": "y",
				"ends": ["open", "gable"], "walls": "plaster", "roof": "thatch",
				"shutters": Color(0.3, 0.4, 0.6)}],
		 "props": [["flowers", 0.5, 1.4], ["fence", 0.2, 1.85]]},
	],
	"woodcutter": [{"volumes": [
		{"kind": "house", "rect": [0.14, 0.14, 1.0, 1.86], "h": 36.0, "rh": 22.0, "ridge": "y", "ends": ["gable", "gable"], "walls": "logs", "roof": "shingle", "shutters": Color(0.45, 0.3, 0.18)}],
		"props": [["chopping_block", 1.3, 1.75], ["log_pile", 0.5, 2.0]]}],
	"sawmill": [{"volumes": [
		{"kind": "house", "rect": [0.14, 0.14, 1.0, 1.45], "h": 38.0, "rh": 20.0, "ridge": "y", "ends": ["gable", "gable"], "walls": "planks", "roof": "shingle", "shutters": Color(0.45, 0.3, 0.18)},
		{"kind": "lean", "rect": [0.14, 1.45, 1.0, 1.86], "low": "y", "h": 24.0, "hh": 32.0, "roof": "shingle", "walls": "planks", "open": true, "inside": [["saw_horse", 0.62, 1.68]]}],
		"props": [["plank_stack", 1.3, 1.82], ["log_pile", 0.2, 1.98]]}],
	"quarry": [{"volumes": [
		{"kind": "house", "rect": [0.14, 0.14, 1.0, 1.86], "h": 34.0, "rh": 18.0, "ridge": "y", "ends": ["gable", "gable"], "walls": "stone", "roof": "slate", "shutters": Color(0.4, 0.38, 0.36)}],
		"props": [["stone_blocks", 1.3, 1.78], ["crane", 0.3, 1.95]]}],
	# E3 part 1: the stone pit's base art is from SpriteKiln (tools/spritekiln/gen_stone_pit.py);
	# this look gives its construction sites (restore base.* after running this script).
	"stone_pit": [{"volumes": [
		{"kind": "lean", "rect": [0.2, 0.2, 1.2, 1.2], "low": "y", "h": 22.0, "hh": 30.0, "roof": "shingle", "walls": "planks", "open": true, "inside": []}],
		"props": [["stone_blocks", 1.6, 2.6], ["crane", 2.4, 2.2]]}],
	# E3 part 2: the deep mine's base art is from SpriteKiln (tools/spritekiln/gen_deep_mine.py);
	# this look gives its construction sites (restore base.* after running this script).
	"deep_mine": [{"volumes": [
		{"kind": "lean", "rect": [0.5, 0.5, 1.5, 1.5], "low": "y", "h": 40.0, "hh": 52.0, "roof": "shingle", "walls": "planks", "open": true, "inside": []}],
		"props": [["log_pile", 2.4, 0.8], ["crane", 2.4, 2.2]]}],
	# E4 part 2: the school's base art is from SpriteKiln (tools/spritekiln/gen_school.py);
	# this look gives its construction sites (restore base.* after running this script).
	"school": [{"volumes": [
		{"kind": "house", "rect": [0.1, 0.15, 2.15, 1.4], "h": 44.0, "rh": 30.0, "ridge": "x", "ends": ["gable", "gable"], "walls": "timber", "roof": "tile", "shutters": Color(0.3, 0.4, 0.6)}],
		"props": []}],
	# E4 part 3: the university's base art is from SpriteKiln (tools/spritekiln/gen_university.py);
	# this look gives its construction sites (restore base.* after running this script).
	"university": [{"volumes": [
		{"kind": "house", "rect": [0.2, 0.2, 3.0, 1.4], "h": 46.0, "rh": 32.0, "ridge": "x", "ends": ["gable", "gable"], "walls": "stone", "roof": "tile", "shutters": Color(0.3, 0.4, 0.6)}],
		"props": []}],
	# E4 part 4: the barracks' base art is from SpriteKiln (tools/spritekiln/gen_barracks.py);
	# these looks give their construction sites (restore base.* after running this script).
	"barracks_small": [{"volumes": [
		{"kind": "house", "rect": [0.14, 0.14, 1.4, 1.86], "h": 36.0, "rh": 22.0, "ridge": "y", "ends": ["gable", "gable"], "walls": "logs", "roof": "shingle", "shutters": Color(0.45, 0.3, 0.18)}],
		"props": []}],
	"barracks_large": [{"volumes": [
		{"kind": "house", "rect": [0.1, 0.1, 4.9, 1.7], "h": 46.0, "rh": 30.0, "ridge": "x", "ends": ["gable", "gable"], "walls": "stone", "roof": "slate", "shutters": Color(0.4, 0.38, 0.36)},
		{"kind": "house", "rect": [0.1, 1.7, 1.7, 4.9], "h": 46.0, "rh": 30.0, "ridge": "y", "ends": ["open", "gable"], "walls": "stone", "roof": "slate", "shutters": Color(0.4, 0.38, 0.36)}],
		"props": []}],
	"farm": [{"volumes": [
		{"kind": "house", "rect": [0.14, 0.14, 1.0, 1.86], "h": 42.0, "rh": 26.0, "ridge": "y", "ends": ["gable", "gable"], "walls": "timber", "roof": "thatch", "shutters": Color(0.6, 0.25, 0.2), "chimney": [0.55, 0.6]}],
		"props": [["sheaves", 1.3, 1.78], ["cart_wheel", 0.55, 1.98]]}],
	"hop_farm": [{"volumes": [
		{"kind": "house", "rect": [0.14, 0.14, 1.0, 1.4], "h": 39.0, "rh": 24.0, "ridge": "y", "ends": ["gable", "gable"], "walls": "timber", "roof": "thatch", "shutters": Color(0.3, 0.5, 0.3)},
		{"kind": "round", "centre": [0.52, 1.66], "r": 0.27, "h": 34.0, "rh": 24.0, "walls": "stone_plaster", "roof": "tile", "sails": false, "cowl": true}],
		"props": [["hop_poles", 1.25, 1.85], ["baskets", 1.45, 1.92]]}],
	# M6 part 3 (wine): a vintner's farmstead with a stone press-house; a stone press-house with
	# a big screw press under a lean-to and casks.
	"vineyard": [{"volumes": [
		{"kind": "house", "rect": [0.14, 0.14, 1.9, 1.5], "h": 42.0, "rh": 26.0, "ridge": "x", "ends": ["gable", "hip"], "walls": "stone_plaster", "roof": "tile", "shutters": Color(0.5, 0.2, 0.32), "chimney": [0.5, 0.6]},
		{"kind": "house", "rect": [0.14, 1.5, 1.1, 2.55], "h": 32.0, "rh": 20.0, "ridge": "y", "ends": ["open", "gable"], "walls": "timber", "roof": "tile", "shutters": Color(0.45, 0.3, 0.2)}],
		"props": [["hop_poles", 0.4, 2.8], ["baskets", 1.5, 2.6], ["barrel", 2.25, 2.6]]}],
	"wine_press": [{"volumes": [
		{"kind": "house", "rect": [0.14, 0.14, 1.0, 1.45], "h": 44.0, "rh": 24.0, "ridge": "y", "ends": ["gable", "gable"], "walls": "stone_plaster", "roof": "tile", "shutters": Color(0.5, 0.15, 0.22), "chimney": [0.55, 0.5]},
		{"kind": "lean", "rect": [0.14, 1.45, 1.0, 1.86], "low": "y", "h": 28.0, "hh": 36.0, "roof": "tile", "walls": "stone_plaster", "open": true, "inside": [["mead_vat", 0.4, 1.7], ["cask_rack", 0.8, 1.72]]}],
		"props": [["barrel", 1.25, 1.85], ["baskets", 0.15, 1.98]]}],
	"mill": [{"volumes": [
		{"kind": "round", "centre": [0.58, 1.0], "r": 0.44, "h": 92.0, "rh": 30.0, "walls": "stone_plaster", "roof": "shingle", "sails": true}],
		"props": [["sacks", 1.28, 1.78], ["sacks", 0.4, 1.85]]}],
	"bakery": [{"volumes": [
		{"kind": "house", "rect": [0.14, 0.14, 1.0, 1.45], "h": 42.0, "rh": 22.0, "ridge": "y", "ends": ["gable", "gable"], "walls": "timber", "roof": "tile", "shutters": Color(0.6, 0.25, 0.2), "chimney": [0.5, 0.55]},
		{"kind": "lean", "rect": [0.14, 1.45, 1.0, 1.86], "low": "y", "h": 28.0, "hh": 36.0, "roof": "tile", "walls": "timber", "open": true, "inside": [["table", 0.35, 1.7], ["oven", 0.75, 1.7]]}],
		"props": [["sacks", 1.28, 1.85], ["sign_bread", 1.05, 1.98]]}],
	"brewery": [{"volumes": [
		{"kind": "house", "rect": [0.14, 0.14, 1.0, 1.45], "h": 48.0, "rh": 22.0, "ridge": "y", "ends": ["gable", "gable"], "walls": "stone_plaster", "roof": "tile", "shutters": Color(0.3, 0.35, 0.5), "chimney": [0.5, 0.5]},
		{"kind": "lean", "rect": [0.14, 1.45, 1.0, 1.86], "low": "y", "h": 28.0, "hh": 38.0, "roof": "tile", "walls": "stone_plaster", "open": true, "inside": [["barrels", 0.35, 1.7], ["kettle", 0.75, 1.68]]}],
		"props": [["barrel", 1.28, 1.85]]}],
	"fishing_hut": [{"volumes": [
		{"kind": "house", "rect": [0.14, 0.14, 1.0, 1.6], "h": 34.0, "rh": 22.0, "ridge": "y", "ends": ["gable", "gable"], "walls": "planks", "roof": "thatch", "shutters": Color(0.3, 0.45, 0.6)}],
		"props": [["fish_rack", 1.3, 1.8], ["boat", 0.55, 1.98]]}],
	"chapel": [{"volumes": [
		{"kind": "house", "rect": [0.14, 0.4, 1.86, 1.6], "h": 42.0, "rh": 24.0, "ridge": "x",
			"ends": ["gable", "gable"], "walls": "plaster", "roof": "shingle", "shutters": Color(0.45, 0.3, 0.18)},
		{"kind": "tower", "rect": [1.45, 0.75, 1.86, 1.25], "h": 56.0, "spire": 22.0, "walls": "planks",
			"roof": "shingle", "cross": true}],
		"props": [["fence", 0.2, 1.85]]}],
	"church": [{"volumes": [
		{"kind": "house", "rect": [0.14, 0.4, 2.15, 2.5], "h": 56.0, "rh": 34.0, "ridge": "x",
			"ends": ["hip", "gable"], "walls": "stone", "roof": "slate", "shutters": Color(0.4, 0.3, 0.25),
			"tall_windows": true},
		{"kind": "tower", "rect": [2.15, 1.05, 2.86, 1.85], "h": 98.0, "spire": 44.0, "walls": "stone",
			"roof": "slate", "cross": true}],
		"props": [["graves", 0.5, 2.8]]}],
	"town_hall": [{"volumes": [
		{"kind": "house", "rect": [0.14, 0.14, 3.86, 1.9], "h": 62.0, "rh": 34.0, "ridge": "x",
			"ends": ["hip", "hip"], "walls": "timber_stone", "roof": "tile",
			"shutters": Color(0.25, 0.35, 0.55), "floors": 2, "chimney": [0.9, 0.7]},
		{"kind": "house", "rect": [0.14, 1.9, 2.2, 3.86], "h": 62.0, "rh": 30.0, "ridge": "y",
			"ends": ["open", "gable"], "walls": "timber_stone", "roof": "tile",
			"shutters": Color(0.25, 0.35, 0.55), "floors": 2},
		{"kind": "tower", "rect": [2.45, 2.3, 3.35, 3.2], "h": 106.0, "spire": 34.0, "walls": "timber_stone",
			"roof": "tile", "cross": false, "clock": true}],
		"props": [["banner", 0.35, 3.86], ["bench", 3.4, 3.7]]}],
	# M4b (patricians): textiles, honey and mead, clay and bricks, forester, tavern.
	"forester": [{"volumes": [
		{"kind": "house", "rect": [0.14, 0.14, 1.2, 1.6], "h": 36.0, "rh": 22.0, "ridge": "y",
			"ends": ["gable", "gable"], "walls": "logs", "roof": "shingle", "shutters": Color(0.3, 0.45, 0.25),
			"chimney": [0.6, 0.5]}],
		"pens": [[1.3, 0.15, 1.92, 1.05, "saplings"]],
		"props": [["sapling_pots", 0.55, 1.95], ["spade", 1.4, 1.75]]}],
	"sheep_farm": [{"volumes": [
		{"kind": "house", "rect": [0.14, 0.14, 1.0, 1.5], "h": 34.0, "rh": 24.0, "ridge": "y", "ends": ["gable", "gable"], "walls": "planks", "roof": "thatch", "shutters": Color(0.6, 0.25, 0.2)}],
		"pens": [[0.12, 1.58, 1.0, 1.94, "sheep"]],
		"props": [["hay", 1.3, 1.82]]}],
	# M4b-2 (meat), smaller in Z1 (animal pens): the sty without a built-in pen (the pigs live
	# in the pen tiles the player places): a plank hut, an open feed shed with a feed basket.
	"pigsty": [{"volumes": [
		{"kind": "house", "rect": [0.14, 0.14, 1.0, 1.5], "h": 30.0, "rh": 22.0, "ridge": "y",
			"ends": ["gable", "gable"], "walls": "planks", "roof": "thatch", "shutters": Color(0.55, 0.35, 0.2)},
		{"kind": "lean", "rect": [1.0, 0.2, 1.86, 1.0], "low": "x", "h": 20.0, "hh": 28.0,
			"roof": "thatch", "walls": "planks", "open": true, "inside": [["hay", 1.45, 0.65]]}],
		"props": [["trough", 1.35, 1.45], ["baskets", 1.55, 1.85], ["bucket", 0.25, 1.95]]}],
	# M4b-3: a stable with a hay loft, an open wagon shed and a paddock.
	# M6 part 3 (owner's decision 2026-11-07): the trading post keeps the big covered merchant
	# wagon that runs trade routes between provinces: a stone warehouse with a loading bay.
	"trading_post": [{"volumes": [
		{"kind": "house", "rect": [0.14, 0.14, 1.9, 1.7], "h": 52.0, "rh": 26.0, "ridge": "x",
			"ends": ["gable", "hip"], "walls": "timber_stone", "roof": "tile",
			"shutters": Color(0.25, 0.35, 0.55), "floors": 2},
		{"kind": "lean", "rect": [1.9, 0.2, 2.86, 1.7], "low": "x", "h": 28.0, "hh": 40.0,
			"roof": "tile", "walls": "planks", "open": true, "inside": [["barrels", 2.35, 1.0]]}],
		"props": [["sacks", 0.4, 2.4], ["barrel", 1.2, 2.6], ["wagon", 2.2, 2.35]]}],
	"stable": [{"volumes": [
		{"kind": "house", "rect": [0.14, 0.14, 1.75, 1.6], "h": 40.0, "rh": 26.0, "ridge": "x",
			"ends": ["gable", "gable"], "walls": "timber", "roof": "thatch", "shutters": Color(0.45, 0.3, 0.2)},
		{"kind": "lean", "rect": [1.75, 0.2, 2.86, 1.6], "low": "x", "h": 26.0, "hh": 36.0,
			"roof": "shingle", "walls": "planks", "open": true, "inside": [["wagon", 2.35, 1.15]]}],
		"pens": [[1.7, 1.7, 2.9, 2.9, "horses"]],
		"props": [["hay", 0.55, 2.35], ["trough", 1.3, 2.75], ["wagon", 0.75, 1.95]]}],
	"slaughterhouse": [{"volumes": [
		{"kind": "house", "rect": [0.14, 0.14, 1.0, 1.45], "h": 40.0, "rh": 22.0, "ridge": "y", "ends": ["gable", "gable"], "walls": "timber_stone", "roof": "tile", "shutters": Color(0.55, 0.22, 0.2), "chimney": [0.5, 0.5]},
		{"kind": "lean", "rect": [0.14, 1.45, 1.0, 1.86], "low": "y", "h": 28.0, "hh": 36.0, "roof": "tile", "walls": "timber", "open": true, "inside": [["butcher_block", 0.38, 1.68], ["meat_hooks", 0.78, 1.66]]}],
		"props": [["hide_rack", 1.25, 1.85], ["barrel", 0.15, 1.98]]}],
	"weaver": [{"volumes": [
		{"kind": "house", "rect": [0.14, 0.14, 1.0, 1.45], "h": 42.0, "rh": 22.0, "ridge": "y", "ends": ["gable", "gable"], "walls": "timber", "roof": "shingle", "shutters": Color(0.3, 0.38, 0.6), "chimney": [0.5, 0.6]},
		{"kind": "lean", "rect": [0.14, 1.45, 1.0, 1.86], "low": "y", "h": 28.0, "hh": 36.0, "roof": "shingle", "walls": "timber", "open": true, "inside": [["spinning_wheel", 0.38, 1.68], ["loom", 0.78, 1.68]]}],
		"props": [["cloth_bolts", 1.28, 1.85], ["sign_cloth", 0.15, 1.98]]}],
	"tailor": [{"volumes": [
		{"kind": "house", "rect": [0.14, 0.14, 1.0, 1.45], "h": 44.0, "rh": 22.0, "ridge": "y", "ends": ["gable", "gable"], "walls": "plaster", "roof": "tile", "shutters": Color(0.55, 0.3, 0.55), "chimney": [0.5, 0.55]},
		{"kind": "lean", "rect": [0.14, 1.45, 1.0, 1.86], "low": "y", "h": 28.0, "hh": 38.0, "roof": "tile", "walls": "timber", "open": true, "inside": [["cutting_table", 0.62, 1.7], ["cloth_bolts", 0.3, 1.72]]}],
		"props": [["clothes_line", 1.25, 1.88], ["sign_shirt", 0.15, 1.98]]}],
	"apiary": [{"volumes": [
		{"kind": "house", "rect": [0.14, 0.14, 1.0, 1.5], "h": 30.0, "rh": 22.0, "ridge": "y", "ends": ["gable", "gable"], "walls": "planks", "roof": "thatch", "shutters": Color(0.75, 0.6, 0.2)}],
		"props": [["skeps", 1.28, 1.82], ["skeps", 0.6, 1.88], ["skeps", 0.22, 1.75], ["flowers", 1.05, 1.98], ["honey_pots", 1.5, 1.92]]}],
	"meadery": [{"volumes": [
		{"kind": "house", "rect": [0.14, 0.14, 1.0, 1.45], "h": 42.0, "rh": 24.0, "ridge": "y", "ends": ["hip", "gable"], "walls": "timber_stone", "roof": "thatch", "shutters": Color(0.7, 0.5, 0.15), "chimney": [0.5, 0.6]},
		{"kind": "lean", "rect": [0.14, 1.45, 1.0, 1.86], "low": "y", "h": 28.0, "hh": 36.0, "roof": "thatch", "walls": "timber", "open": true, "inside": [["mead_vat", 0.4, 1.7], ["cask_rack", 0.8, 1.72]]}],
		"props": [["honey_pots", 1.28, 1.85], ["barrel", 0.15, 1.98]]}],
	"clay_pit": [{"volumes": [
		{"kind": "house", "rect": [0.14, 0.14, 1.0, 1.45], "h": 30.0, "rh": 20.0, "ridge": "y", "ends": ["gable", "gable"], "walls": "planks", "roof": "thatch", "shutters": Color(0.45, 0.3, 0.18)}],
		"props": [["clay_pit", 0.55, 1.72], ["clay_mound", 1.3, 1.82], ["spade", 1.1, 1.55]]}],
	"brickworks": [{"volumes": [
		{"kind": "house", "rect": [0.14, 0.14, 1.0, 1.4], "h": 36.0, "rh": 20.0, "ridge": "y", "ends": ["gable", "gable"], "walls": "planks", "roof": "shingle", "shutters": Color(0.45, 0.3, 0.18)}],
		"props": [["kiln", 0.55, 1.7], ["mould_table", 1.3, 1.82], ["brick_stack", 0.12, 1.98]]}],
	"tavern": [{"volumes": [
		{"kind": "house", "rect": [0.14, 0.14, 1.5, 1.86], "h": 58.0, "rh": 28.0, "ridge": "y",
			"ends": ["hip", "gable"], "walls": "timber_stone", "roof": "tile",
			"shutters": Color(0.25, 0.45, 0.3), "floors": 2, "chimney": [0.55, 0.5]}],
		"props": [["bar_counter", 1.72, 0.55], ["tavern_table", 1.75, 1.62], ["tavern_table", 0.75, 2.02],
			["sign_mug", 1.55, 1.0]]}],
	# M5: the sea. Decks (piers, slipways) are drawn first, low over the water rows.
	"tar_kiln": [{"volumes": [
		{"kind": "house", "rect": [0.14, 0.14, 1.0, 1.3], "h": 30.0, "rh": 18.0, "ridge": "y", "ends": ["gable", "gable"], "walls": "logs", "roof": "planks_roof", "shutters": Color(0.3, 0.25, 0.2)}],
		"props": [["tar_pit", 0.55, 1.68], ["tar_barrels", 1.3, 1.85], ["log_pile", 0.15, 1.95]]}],
	"shipyard": [{"volumes": [
		{"kind": "deck", "rect": [0.7, 1.55, 2.3, 4.0], "h": 7.0, "h_end": -3.0, "slip": true},
		{"kind": "house", "rect": [0.14, 0.14, 2.0, 1.4], "h": 38.0, "rh": 22.0, "ridge": "x",
			"ends": ["gable", "gable"], "walls": "planks", "roof": "shingle", "shutters": Color(0.35, 0.3, 0.25),
			"chimney": [0.6, 0.5]},
		{"kind": "lean", "rect": [2.1, 0.14, 3.86, 1.45], "low": "x", "h": 28.0, "hh": 36.0,
			"roof": "shingle", "walls": "planks", "open": true,
			"inside": [["plank_stack", 2.9, 1.2], ["saw_horse", 3.4, 0.8]]}],
		"props": [["crane", 2.6, 1.9], ["tar_barrels", 0.4, 1.85], ["log_pile", 3.55, 1.9],
			["bollard", 2.95, 3.6]]}],
	# J1 part 3: the large shipyard (6x6): a wide slipway three rows into the water between two
	# quay strips, a big boat shed with a stone base and a sail loft, a lean-to of timber, two
	# cranes and the stores of a great yard.
	"large_shipyard": [{"volumes": [
		{"kind": "deck", "rect": [0.9, 2.45, 5.1, 6.0], "h": 8.0, "h_end": -3.0, "slip": true},
		{"kind": "house", "rect": [0.14, 0.14, 3.2, 2.2], "h": 50.0, "rh": 30.0, "ridge": "x",
			"ends": ["gable", "gable"], "walls": "timber_stone", "roof": "shingle", "shutters": Color(0.35, 0.3, 0.25),
			"floors": 2, "chimney": [0.6, 0.5]},
		{"kind": "lean", "rect": [3.3, 0.14, 5.86, 2.1], "low": "x", "h": 32.0, "hh": 42.0,
			"roof": "shingle", "walls": "planks", "open": true,
			"inside": [["plank_stack", 4.2, 1.6], ["saw_horse", 5.0, 1.0], ["plank_stack", 3.8, 0.8]]}],
		"props": [["crane", 1.0, 2.6], ["crane", 4.9, 2.6], ["tar_barrels", 0.5, 2.3], ["log_pile", 5.5, 2.4],
			["log_pile", 3.2, 2.35], ["bollard", 0.5, 5.6], ["bollard", 5.5, 5.6]]}],
	# N1: the pier over the water is the shared quay strip (QuayLayer), not part of the art.
	"fishing_wharf": [{"volumes": [
		{"kind": "house", "rect": [0.14, 0.14, 1.9, 1.55], "h": 34.0, "rh": 22.0, "ridge": "x", "ends": ["gable", "gable"], "walls": "planks", "roof": "thatch", "shutters": Color(0.3, 0.45, 0.6)}],
		"props": [["nets", 2.3, 1.85], ["fish_rack", 0.45, 1.8], ["bollard", 0.5, 2.8], ["bollard", 2.5, 2.8], ["barrel", 1.3, 1.85]]}],
	# M5 part 2: the port. Its land tiles are left see-through: the quay yard (planks and the
	# stacks of goods) is drawn by the view (QuayYard), so stacks are never hidden by the art.
	# N1: a mooring on the quay: bollards with a coiled rope, a lantern, a few barrels. The
	# quay under it is the QuayLayer's.
	"mooring": [{"min_height": 40.0, "volumes": [],
		"props": [["bollard", 0.35, 1.8], ["bollard", 1.65, 1.8], ["barrels", 0.55, 0.55], ["lantern", 1.75, 0.3],
			["nets", 0.25, 1.15]]}],
	# N1: its quay over the water is the shared quay strip (QuayLayer).
	"port": [{"min_height": 64.0, "volumes": [],
		"props": [["gate_posts", 3.55, 1.0], ["port_crane", 0.75, 2.55], ["barrels", 1.4, 2.35],
			["bollard", 0.5, 3.75], ["bollard", 1.7, 3.75], ["bollard", 3.55, 3.75], ["lantern", 3.7, 2.2]]}],
	# N1 part 2: the cargo crane on the quay: a treadwheel by the door (the operator walks in
	# it) and a tall mast. The jib, the rope and the load are drawn by the view (CraneLayer),
	# which swings them between the quay yard and the ship.
	"crane": [{"min_height": 136.0, "volumes": [],
		"props": [["crane_mast", 1.15, 0.85], ["treadwheel", 0.5, 1.5], ["barrels", 1.7, 1.8],
			["bollard", 1.85, 0.25]]}],
	"port_warehouse": [{"special": "yard"}],
	# E2 part 2: the hunter's lodge (2x2); final art from SpriteKiln (gen_farmsteads.py).
	"hunter_lodge": [{"volumes": [
		{"kind": "house", "rect": [0.14, 0.14, 1.0, 1.86], "h": 30.0, "rh": 18.0, "ridge": "x",
			"ends": ["gable", "gable"], "walls": "logs", "roof": "thatch", "shutters": Color(0.3, 0.25, 0.2)}],
		"props": [["log_stack", 0.4, 1.7]]}],
	# E2 part 1: the orchard (2x2); final art from SpriteKiln (tools/spritekiln/gen_farmsteads.py),
	# this drawing gives the construction stages.
	"orchard": [{"volumes": [
		{"kind": "house", "rect": [0.14, 0.14, 1.0, 1.86], "h": 32.0, "rh": 20.0, "ridge": "x",
			"ends": ["gable", "gable"], "walls": "plaster", "roof": "tile", "shutters": Color(0.35, 0.3, 0.25)}],
		"props": [["crate_stack", 0.6, 1.6]]}],
	# E1 part 1: the porters' hut (2x2) and house (3x3); final art from SpriteKiln
	# (tools/spritekiln/gen_farmsteads.py and porters_house.yaml), these drawings give the construction stages.
	"porters_hut": [{"volumes": [
		{"kind": "house", "rect": [0.14, 0.14, 1.25, 1.86], "h": 34.0, "rh": 22.0, "ridge": "y",
			"ends": ["gable", "gable"], "walls": "planks", "roof": "thatch", "shutters": Color(0.35, 0.3, 0.25)}],
		"props": [["crate_stack", 1.62, 1.72], ["sacks", 1.6, 0.6]]}],
	"porters_house": [{"volumes": [
		{"kind": "house", "rect": [0.14, 0.14, 2.05, 2.86], "h": 50.0, "rh": 28.0, "ridge": "x",
			"ends": ["gable", "gable"], "walls": "timber_stone", "roof": "tile", "shutters": Color(0.25, 0.4, 0.55),
			"floors": 2, "chimney": [1.45, 1.75]}],
		"props": [["crate_stack", 2.5, 0.6], ["sacks", 2.5, 1.5], ["barrels", 2.5, 2.4]]}],
	# P2 part 3: the builders' hut (2x2): a timber-framed cottage on a stone plinth with a
	# shingle roof and a chimney, an open shed full of tools and timber, a ladder against the
	# wall, a saw horse, dressed stone and planks waiting for the next site.
	"builders_hut": [{"volumes": [
		{"kind": "house", "rect": [0.14, 0.14, 1.25, 1.86], "h": 36.0, "rh": 22.0, "ridge": "y",
			"ends": ["gable", "gable"], "walls": "timber_stone", "roof": "shingle", "shutters": Color(0.5, 0.32, 0.18),
			"chimney": [0.7, 0.6]},
		{"kind": "lean", "rect": [1.3, 0.2, 1.88, 1.2], "low": "x", "h": 22.0, "hh": 30.0,
			"roof": "shingle", "walls": "planks", "open": true,
			"inside": [["plank_stack", 1.6, 0.85], ["saw_horse", 1.62, 0.45]]}],
		"props": [["stone_blocks", 1.62, 1.75], ["log_stack", 0.3, 1.95], ["spade", 1.35, 1.55]]}],
	"port_store": [{"special": "yard"}],
	"port_warehouse_small": [{"special": "yard"}],
	# P2 part 1: a stone bollard on the edge of a stone quay: a squat post with an iron cap, a
	# hawser coiled round it, a lantern on a pole and a few crates waiting for the ship.
	"bollard": [{"min_height": 46.0, "volumes": [],
		"props": [["lantern_pole", 0.8, 0.25], ["stone_bollard", 0.55, 0.75], ["rope_coil", 0.15, 0.7]]}],
	# P2 part 1: the dockers' hut (2x2): a weatherboarded cottage with a shingle roof and a
	# chimney, an open lean-to with coiled ropes and sacks, nets drying, a handcart and crates.
	# Two doors (land and water): the front one is drawn, the back one is behind the house.
	"docker_hut": [{"volumes": [
		{"kind": "house", "rect": [0.14, 0.14, 1.3, 1.86], "h": 34.0, "rh": 22.0, "ridge": "y",
			"ends": ["gable", "hip"], "walls": "planks", "roof": "shingle", "shutters": Color(0.25, 0.4, 0.55),
			"chimney": [0.7, 0.55]},
		{"kind": "lean", "rect": [1.36, 0.2, 1.88, 1.25], "low": "x", "h": 20.0, "hh": 28.0,
			"roof": "shingle", "walls": "planks", "open": true,
			"inside": [["rope_coil", 1.62, 0.6], ["sacks", 1.6, 1.0]]}],
		"props": [["crate_stack", 1.62, 1.72], ["nets", 0.25, 1.95], ["rope_coil", 0.95, 1.98]]}],
	# P2 part 1: the dockers' house (3x3): a two-storey timber-framed house on a stone plinth
	# with a tiled hip roof and two chimneys, a lookout turret at the back corner where the
	# foreman watches for sails, a weatherboarded back wing, an open loading shed with sacks
	# and barrels, crates, a handcart, a hand crane and a lantern by the door.
	"docker_house": [{"volumes": [
		{"kind": "tower", "rect": [0.16, 0.16, 0.86, 0.86], "h": 84.0, "spire": 26.0, "walls": "timber_stone",
			"roof": "slate"},
		{"kind": "house", "rect": [0.92, 0.14, 2.86, 0.98], "h": 36.0, "rh": 20.0, "ridge": "x",
			"ends": ["gable", "hip"], "walls": "planks", "roof": "shingle", "shutters": Color(0.25, 0.4, 0.55),
			"chimney": [2.3, 0.55]},
		{"kind": "house", "rect": [0.14, 1.05, 2.05, 2.86], "h": 52.0, "rh": 28.0, "ridge": "x",
			"ends": ["hip", "gable"], "walls": "timber_stone", "roof": "tile", "shutters": Color(0.25, 0.4, 0.55),
			"floors": 2, "chimney": [1.45, 1.75]},
		{"kind": "lean", "rect": [2.12, 1.05, 2.88, 2.86], "low": "x", "h": 24.0, "hh": 36.0,
			"roof": "shingle", "walls": "planks", "open": true,
			"inside": [["sacks", 2.5, 1.5], ["barrels", 2.5, 2.35], ["rope_coil", 2.35, 1.2]]}],
		"props": [["crate_stack", 0.3, 2.95], ["hand_crane", 2.95, 2.95], ["rope_coil", 1.7, 2.98]]}],
	# M5 part 3: the pioneer camp, the first building after a start from a ship: a log hut,
	# canvas tents, a camp fire and the settlers' tools.
	"pioneer_camp": [{"volumes": [
		{"kind": "house", "rect": [0.14, 0.14, 1.55, 1.25], "h": 28.0, "rh": 18.0, "ridge": "y",
			"ends": ["gable", "gable"], "walls": "logs", "roof": "thatch", "shutters": Color(0.35, 0.3, 0.25)}],
		"props": [["tent", 2.35, 0.75], ["tent", 2.45, 2.0], ["log_stack", 0.55, 2.35], ["campfire", 1.35, 1.75],
			["barrel", 0.35, 1.55], ["spade", 1.9, 0.4], ["banner", 0.2, 2.86]]}],
	"well": [{"special": "well"}],
	"market": [{"special": "market"}],
	"stockpile": [{"special": "yard"}],
}

## Row pieces of town houses (ART_SPEC §7, HouseRowResolver).
const ROW_PIECES: Array[String] = ["single", "end_a", "middle", "end_b", "corner_a", "corner_b"]

## Huts seen from the back (door away from the camera, M4b-1.5): the same houses turned
## round, so the camera sees the back wall with a back door, the woodpile and the garden
## instead of the front with its lean-to and flowers. One per look of "hut".
const HUT_BACKS := [
	{"volumes": [
		{"kind": "house", "rect": [0.58, 0.14, 1.86, 1.86], "h": 39.0, "rh": 26.0, "ridge": "y",
			"ends": ["gable", "gable"], "walls": "timber", "roof": "thatch",
			"shutters": Color(0.35, 0.45, 0.3), "chimney": [1.3, 1.1]}],
	 "props": [["garden_bed", 0.25, 1.2], ["log_stack", 0.35, 0.6], ["barrel", 1.9, 0.35]]},
	{"volumes": [
		{"kind": "house", "rect": [0.14, 0.58, 1.86, 1.86], "h": 36.0, "rh": 24.0, "ridge": "x",
			"ends": ["gable", "gable"], "walls": "logs", "roof": "shingle",
			"shutters": Color(0.55, 0.25, 0.2), "chimney": [1.5, 1.4]}],
	 "props": [["garden_bed", 1.1, 0.3], ["barrel", 0.3, 0.4]]},
	{"volumes": [
		{"kind": "house", "rect": [0.14, 0.95, 1.86, 1.86], "h": 36.0, "rh": 22.0, "ridge": "x",
			"ends": ["gable", "hip"], "walls": "plaster", "roof": "thatch",
			"shutters": Color(0.3, 0.4, 0.6), "chimney": [1.4, 1.45]},
		{"kind": "house", "rect": [0.14, 0.14, 1.05, 0.95], "h": 36.0, "rh": 20.0, "ridge": "y",
			"ends": ["gable", "open"], "walls": "plaster", "roof": "thatch",
			"shutters": Color(0.3, 0.4, 0.6)}],
	 "props": [["garden_bed", 1.5, 0.45], ["log_stack", 1.8, 0.25]]},
]

var _entrance: Vector2i
var _footprint: Vector2i
## Tile (as drawn) of the production yard, drawn as trodden earth; (-1, -1) = none.
var _yard: Vector2i = Vector2i(-1, -1)


## G3 part 3: buildings whose base art and both construction stages come from SpriteKiln
## (tools/spritekiln/gen_workshops.py); this script no longer draws them, so nothing old comes back.
## Their drawings stay in BUILDINGS until the G3 clean-up.
const SPRITEKILN_BUILDINGS: Array[String] = ["woodcutter", "forester", "quarry", "fishing_hut",
		"mine", "clay_pit", "farm", "hop_farm", "vineyard", "stable", "charcoal_burner", "tar_kiln",
		"mill", "bakery", "brewery", "meadery", "wine_press", "sawmill", "blacksmith", "smelter", "brickworks",
		"weaver", "tailor", "slaughterhouse"]


func _init() -> void:
	var registry := DataRegistry.new()
	registry.load_from("res://data")
	var only := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	for id: String in BUILDINGS:
		if not only.is_empty() and id != only:
			continue
		if SPRITEKILN_BUILDINGS.has(id):
			continue
		var def := registry.get_building(StringName(id))
		if def == null:
			push_error("generate_art: unknown building %s" % id)
			continue
		_make(id, def, registry)
	print("Building art written to ", OUT)
	quit()


func _make(id: String, def: BuildingDef, registry: DataRegistry) -> void:
	_footprint = def.footprint
	_entrance = def.entrance
	_yard = Vector2i(-1, -1)
	if def.herd_good == &"" and not BuildingState.yard_goods(def, registry).is_empty():
		_yard = def.yard_at(0)
	var looks: Array = BUILDINGS[id]
	for i: int in looks.size():
		var look: Dictionary = looks[i]
		var name := "base" if i == 0 else "base_%d" % (i + 1)
		match String(look.get("special", "")):
			"well":
				_well(id)
			"market":
				_market(id)
			"yard":
				pass
			_:
				var art := _compose(look)
				_write(id, name, art)
				if art.has("ground"):
					_write(id, name + "_ground", {"img": art["ground"], "pivot": art["pivot"]})
	for phase: int in [1, 2]:
		_write(id, "construction_%d" % phase, _site_image(phase, id))
	if def.is_house():
		# Houses turn four ways: the back of each look, site and scaffold (M4b-1.5).
		for i: int in HUT_BACKS.size():
			_write(id, ("base" if i == 0 else "base_%d" % (i + 1)) + "_back", _compose(HUT_BACKS[i]))
		for phase: int in [1, 2]:
			_write(id, "construction_%d_back" % phase, _site_image(phase, id, true))
	if def.house_levels.size() > 1:
		_town_rows(id, 2)
		if def.house_levels.size() > 2:
			_town_rows(id, 3)
		_write(id, "upgrade_scaffold", _scaffold_image())
		_write(id, "upgrade_scaffold_back", _scaffold_image(true))


# --- Composition ---------------------------------------------------------------------------

func _compose(look: Dictionary) -> Dictionary:
	var volumes: Array = look["volumes"]
	var top: float = look.get("min_height", 0.0)
	for vol: Dictionary in volumes:
		top = maxf(top, float(vol.get("h", 0.0)) + float(vol.get("rh", 0.0)) + float(vol.get("spire", 0.0))
				+ (12.0 if vol.has("chimney") else 0.0) + (40.0 if vol.get("sails", false) else 0.0))
	var c := _canvas(top + 4.0, 12)
	var img: Image = c["img"]
	var pivot: Vector2i = c["pivot"]
	# A port's quay is ground people walk on (M5 part 2): drawn into its own image, which
	# the view lays under everything (QuayYard), not into the sorted strips.
	var ground: Image = null
	if look.get("ground_decks", false):
		ground = Image.create_empty(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	if _yard != Vector2i(-1, -1) and not look.has("special"):
		_yard_ground(img, pivot, _yard)
	for vol: Dictionary in volumes:
		if vol["kind"] == "deck":
			_deck(ground if ground != null else img, pivot, vol)
	var ordered := _back_to_front(volumes.filter(func(v: Dictionary) -> bool: return v["kind"] != "deck"))
	var door_done := false
	for vol: Dictionary in ordered:
		match String(vol["kind"]):
			"house":
				door_done = _house(img, pivot, vol, door_done) or door_done
			"lean":
				_lean(img, pivot, vol)
			"round":
				_round(img, pivot, vol)
			"tower":
				_tower(img, pivot, vol)
	for pen: Array in look.get("pens", []):
		_pen(img, pivot, Rect2(Vector2(pen[0], pen[1]), Vector2(float(pen[2]) - float(pen[0]), float(pen[3]) - float(pen[1]))),
				String(pen[4]))
	for prop: Array in look.get("props", []):
		_prop(img, Vector2(pivot) + IsoMath.grid_to_screen(Vector2(prop[1], prop[2]) - Vector2(_footprint)), String(prop[0]))
	_finish(img)
	if ground != null:
		_finish(ground)
		return {"img": img, "pivot": pivot, "ground": ground}
	return {"img": img, "pivot": pivot}


## A timber deck over the water (M5): a pier on posts, or a slipway (slip = true) sloping from
## height h at its back edge down to h_end at its front edge, with two rails and keel blocks.
func _deck(img: Image, pivot: Vector2i, vol: Dictionary) -> void:
	var r := _rect(vol)
	var z0: float = vol.get("h", 4.0)
	var z1: float = vol.get("h_end", z0)
	var slip: bool = vol.get("slip", false)
	var z := func(y: float) -> float: return lerpf(z0, z1, (y - r.position.y) / maxf(r.size.y, 0.01))
	# Posts along the front edges, standing in the water.
	var posts: Array[Vector2] = []
	var steps := maxi(ceili(r.size.x / 0.5), 1)
	for i: int in steps + 1:
		posts.append(Vector2(r.position.x + r.size.x * i / steps, r.end.y))
	steps = maxi(ceili(r.size.y / 0.5), 1)
	for i: int in steps:
		posts.append(Vector2(r.end.x, r.position.y + r.size.y * i / steps))
	for post: Vector2 in posts:
		var top: float = z.call(post.y)
		if top > -1.0:
			_line(img, _scr(pivot, Vector3(post.x, post.y, top)), _scr(pivot, Vector3(post.x, post.y, -5.0)),
					C_BEAM.darkened(0.2), 2)
	var wood := Color(0.5, 0.36, 0.22) if slip else C_PLANK
	var surface := PackedVector2Array([
		_scr(pivot, Vector3(r.position.x, r.position.y, z0)), _scr(pivot, Vector3(r.end.x, r.position.y, z0)),
		_scr(pivot, Vector3(r.end.x, r.end.y, z1)), _scr(pivot, Vector3(r.position.x, r.end.y, z1))])
	_fill_shader(img, surface, func(x: int, y: int) -> Color:
		# Planks across the deck (lines along the grid x axis: screen x - 2y constant).
		var stripe := posmod(x + 2 * y, 6) == 0 if slip else posmod(x - 2 * y, 5) == 0
		return _lit(wood.darkened(0.28) if stripe else wood.darkened(0.06 * _hash(x / 3, y, 17)), 1.05))
	for edge: Array in [[Vector2(r.position.x, r.end.y), r.end, LIGHT_SW], [Vector2(r.end.x, r.position.y), r.end, LIGHT_SE]]:
		var a: Vector2 = edge[0]
		var b: Vector2 = edge[1]
		var face := PackedVector2Array([_scr(pivot, Vector3(a.x, a.y, z.call(a.y))), _scr(pivot, Vector3(b.x, b.y, z.call(b.y))),
				_scr(pivot, Vector3(b.x, b.y, z.call(b.y) - 3.0)), _scr(pivot, Vector3(a.x, a.y, z.call(a.y) - 3.0))])
		_fill(img, face, _lit(wood.darkened(0.3), edge[2]))
	_outline(img, surface, wood.darkened(0.55))
	if slip:
		for rail: float in [0.3, 0.7]:
			var x := r.position.x + r.size.x * rail
			_line(img, _scr(pivot, Vector3(x, r.position.y, z0 + 1.0)), _scr(pivot, Vector3(x, r.end.y, z1 + 1.0)),
					C_BEAM.darkened(0.15), 2)
		for k: int in 4:
			var y := r.position.y + r.size.y * (0.15 + k * 0.2)
			_box(img, _scr(pivot, Vector3(r.get_center().x, y, z.call(y))), Vector2(8, 4), 3.0, C_LOG)


## A fenced enclosure on the ground (grid rect): back fences, the contents (sheep grazing on
## trodden grass, saplings in rows), then the front fences over them.
## The production yard beside the door (review fix 2026-11-07): a patch of trodden earth
## with a few chips and straws, where the stack of goods grows (PileLayer).
func _yard_ground(img: Image, pivot: Vector2i, tile: Vector2i) -> void:
	var f := Vector2(_footprint)
	var s := func(p: Vector2) -> Vector2: return Vector2(pivot) + IsoMath.grid_to_screen(p - f)
	var t := Vector2(tile)
	var inset := 0.06
	var ground := PackedVector2Array([s.call(t + Vector2(inset, inset)), s.call(t + Vector2(1.0 - inset, inset)),
			s.call(t + Vector2(1.0 - inset, 1.0 - inset)), s.call(t + Vector2(inset, 1.0 - inset))])
	var earth := Color(0.5, 0.4, 0.28)
	_fill_shader(img, ground, func(x: int, y: int) -> Color:
		var n := _hash(x / 2, y / 2, 91)
		if n > 0.93:
			return Color(0.72, 0.6, 0.4)   # a chip or a straw
		if n < 0.08:
			return earth.darkened(0.22)    # a pebble or a hoof print
		return earth.darkened(0.12 * _hash(x / 3, y / 3, 17)).lightened(0.05 * _hash(x, y, 5)))


func _pen(img: Image, pivot: Vector2i, r: Rect2, contents: String) -> void:
	var f := Vector2(_footprint)
	var s := func(p: Vector2) -> Vector2: return Vector2(pivot) + IsoMath.grid_to_screen(p - f)
	var c0: Vector2 = r.position
	var c1 := Vector2(r.end.x, r.position.y)
	var c2: Vector2 = r.end
	var c3 := Vector2(r.position.x, r.end.y)
	var ground := PackedVector2Array([s.call(c0), s.call(c1), s.call(c2), s.call(c3)])
	var floor_col := Color(0.5, 0.56, 0.3) if contents == "sheep" else Color(0.45, 0.34, 0.22)
	if contents == "pigs":
		floor_col = Color(0.4, 0.31, 0.22)   # trodden mud
	_fill_shader(img, ground, func(x: int, y: int) -> Color:
		if contents != "sheep" and y % 3 == 0:
			return floor_col.darkened(0.15)
		return floor_col.darkened(0.1 * _hash(x / 2, y / 2, 73)))
	_fence(img, s.call(c0), s.call(c1))
	_fence(img, s.call(c0), s.call(c3))
	match contents:
		"sheep":
			var spots := [Vector2(0.3, 0.3), Vector2(0.7, 0.45), Vector2(0.35, 0.72), Vector2(0.75, 0.8)]
			var n := 4 if r.size.x * r.size.y > 0.45 else 3
			for k: int in n:
				var g: Vector2 = r.position + r.size * (spots[k] as Vector2)
				_sheep(img, s.call(g), k % 2 == 0)
		"pigs":
			# Mud puddles only: the live herd (1 to 4 pigs by its size) stands on the front tiles,
			# so an empty sty looks empty.
			for k: int in 2:
				var g: Vector2 = r.position + r.size * Vector2(0.3 + 0.4 * k, 0.35 + 0.3 * k)
				_ellipse(img, s.call(g) + Vector2(3, -1), Vector2(6, 2.5), Color(0.33, 0.26, 0.2))
		"horses":
			_horse(img, s.call(r.position + r.size * Vector2(0.45, 0.5)))
		"saplings":
			var rows := maxi(1, int(r.size.y / 0.3))
			var cols := maxi(1, int(r.size.x / 0.3))
			for j: int in rows:
				for i: int in cols:
					var g := r.position + Vector2((i + 0.5) * r.size.x / cols, (j + 0.5) * r.size.y / rows)
					_sapling(img, s.call(g), 7.0 + 3.0 * _hash(i, j, 5))
	_fence(img, s.call(c1), s.call(c2))
	_fence(img, s.call(c3), s.call(c2))


## Post-and-rail fence between two ground points.
func _fence(img: Image, a: Vector2, b: Vector2) -> void:
	var n := maxi(1, int(a.distance_to(b) / 7.0))
	for k: int in n + 1:
		var p := a.lerp(b, float(k) / n)
		_line(img, p, p - Vector2(0, 8), C_BEAM.lightened(0.15), 1)
	_line(img, a - Vector2(0, 7), b - Vector2(0, 7), C_PLANK.lightened(0.15), 1)
	_line(img, a - Vector2(0, 4), b - Vector2(0, 4), C_PLANK, 1)


## A sheep: woolly body, dark head and legs.
func _sheep(img: Image, foot: Vector2, facing_left: bool) -> void:
	var dir := -1.0 if facing_left else 1.0
	for lx: float in [-3.0, -1.0, 2.0, 4.0]:
		_line(img, foot + Vector2(lx * dir, -3), foot + Vector2(lx * dir, 0), Color(0.2, 0.17, 0.15), 1)
	_ellipse(img, foot - Vector2(0, 6), Vector2(6, 4), Color(0.93, 0.91, 0.84))
	_ellipse(img, foot + Vector2(-2, -8), Vector2(3, 2), Color(0.98, 0.97, 0.92))
	_ellipse(img, foot + Vector2(6 * dir, -7), Vector2(2.2, 2.2), Color(0.22, 0.19, 0.17))
	_px(img, Vector2i(foot + Vector2(7 * dir, -8)), Color(0.1, 0.08, 0.06))


## A young tree tied to a stake.
func _sapling(img: Image, foot: Vector2, height: float) -> void:
	_line(img, foot, foot - Vector2(-2, height + 2), C_PLANK.lightened(0.2), 1)
	_line(img, foot, foot - Vector2(0, height), Color(0.42, 0.3, 0.18), 1)
	_ellipse(img, foot - Vector2(0, height + 1), Vector2(3, 3), Color(0.32, 0.55, 0.25))
	_px(img, Vector2i(foot - Vector2(1, height + 2)), Color(0.5, 0.72, 0.35))


## Volumes in drawing order. A volume lying wholly behind another one's wall (at smaller
## grid x or y, with overlapping extent on the other axis) is drawn first; otherwise the
## one whose front corner is further back goes first.
func _back_to_front(volumes: Array) -> Array:
	var left := volumes.duplicate()
	left.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _depth(a) < _depth(b))
	var result: Array = []
	while not left.is_empty():
		for i: int in left.size():
			var free := true
			for j: int in left.size():
				if i != j and _behind(left[j], left[i]):
					free = false
					break
			if free:
				result.append(left[i])
				left.remove_at(i)
				break
	return result


func _behind(a: Dictionary, b: Dictionary) -> bool:
	var ra := _bounds(a)
	var rb := _bounds(b)
	var eps := 0.02
	var y_overlap := ra.position.y < rb.end.y - eps and rb.position.y < ra.end.y - eps
	var x_overlap := ra.position.x < rb.end.x - eps and rb.position.x < ra.end.x - eps
	return (ra.end.x <= rb.position.x + eps and y_overlap) or (ra.end.y <= rb.position.y + eps and x_overlap)


func _bounds(vol: Dictionary) -> Rect2:
	if vol.has("rect"):
		return _rect(vol)
	var c: Array = vol["centre"]
	var r: float = vol["r"]
	return Rect2(Vector2(float(c[0]) - r, float(c[1]) - r), Vector2(r, r) * 2.0)


func _depth(vol: Dictionary) -> float:
	if vol.has("rect"):
		var r: Array = vol["rect"]
		return float(r[2]) + float(r[3]) - 0.01 * (float(r[2]) - float(r[0])) * (float(r[3]) - float(r[1]))
	var c: Array = vol["centre"]
	return float(c[0]) + float(c[1]) + float(vol["r"])


func _rect(vol: Dictionary) -> Rect2:
	var r: Array = vol["rect"]
	return Rect2(Vector2(r[0], r[1]), Vector2(float(r[2]) - float(r[0]), float(r[3]) - float(r[1])))


## Row pieces of a town house level (ART_SPEC §7): level 2 = burgher houses, level 3 =
## patrician townhouses, gable to the street, 1-3 houses per lot, each piece in three looks
## ("", "_2", "_3") from the front and from the back (tools/town_house_art.gd).
func _town_rows(id: String, level: int) -> void:
	var painter := TownHouseArt.new(self)
	for piece: String in ROW_PIECES:
		for look: int in 3:
			for back: bool in [false, true]:
				var name := "level_%d_%s%s%s" % [level, piece, "" if look == 0 else "_%d" % (look + 1),
						"_back" if back else ""]
				_write(id, name, painter.render(level, piece, back, look))


# --- Houses --------------------------------------------------------------------------------

## Walls facing the camera and a ridge roof. Returns whether it drew the door.
func _house(img: Image, pivot: Vector2i, vol: Dictionary, door_done: bool) -> bool:
	var r := _rect(vol)
	var h: float = vol["h"]
	var tint: Color = vol.get("tint", Color.WHITE)
	var shutters: Color = vol.get("shutters", C_BEAM)
	var floors: int = vol.get("floors", 1)
	var tall: bool = vol.get("tall_windows", false)
	var drew_door := false
	# SE face (x = end), then SW face (y = end) which overlaps it at the front corner.
	var se_door := -1.0
	var sw_door := -1.0
	if not door_done:
		var tile := Rect2(Vector2(_entrance), Vector2.ONE)
		var on_se := _entrance.x == _footprint.x - 1
		# A wall just behind the entrance tile also takes the door (the entrance tile is then
		# open ground in front of it, beside the yard tile: review fix 2026-11-07).
		if on_se and r.end.x > tile.position.x - DOOR_REACH and r.end.x <= tile.end.x + 0.01:
			var lo := maxf(r.position.y, tile.position.y)
			var hi := minf(r.end.y, tile.end.y)
			if hi - lo >= 0.35:
				se_door = (lo + hi) * 0.5 - r.position.y
		elif not on_se and r.end.y > tile.position.y - DOOR_REACH and r.end.y <= tile.end.y + 0.01:
			var lo := maxf(r.position.x, tile.position.x)
			var hi := minf(r.end.x, tile.end.x)
			if hi - lo >= 0.35:
				sw_door = (lo + hi) * 0.5 - r.position.x
		drew_door = se_door >= 0.0 or sw_door >= 0.0
	_wall_face(img, pivot, Vector2(r.end.x, r.position.y), r.end, 0.0, h, vol["walls"], tint, LIGHT_SE,
			shutters, floors, se_door, tall)
	_wall_face(img, pivot, Vector2(r.position.x, r.end.y), r.end, 0.0, h, vol["walls"], tint, LIGHT_SW,
			shutters, floors, sw_door, tall)
	var ends: Array[String] = []
	ends.assign(vol["ends"])
	_roof(img, pivot, r, String(vol["roof"]), h, vol["rh"], vol["ridge"] == "x", ends, String(vol["walls"]), tint)
	if vol.has("chimney"):
		var ch: Array = vol["chimney"]
		var along_x: bool = vol["ridge"] == "x"
		var width := r.size.y if along_x else r.size.x
		var mid := r.get_center()
		var at := Vector2(ch[0], ch[1])
		# Height of the roof surface at the chimney.
		var across := absf((at.y - mid.y) if along_x else (at.x - mid.x))
		var z := h + float(vol["rh"]) * (1.0 - across / (width * 0.5 + OVERHANG))
		var foot := Vector2(pivot) + IsoMath.grid_to_screen(at - Vector2(_footprint)) - Vector2(0, z - 4.0)
		_box(img, foot, Vector2(10, 5), 14.0, Color(0.62, 0.36, 0.28), "brick")
	return drew_door


## [param door_at]: distance of the door centre from [param a] along the face, in tiles (-1 = none).
func _wall_face(img: Image, pivot: Vector2i, a: Vector2, b: Vector2, z0: float, h: float, material: String,
		tint: Color, light: float, shutters: Color, floors: int, door_at: float, tall: bool) -> void:
	var f := Vector2(_footprint)
	var o := Vector2(pivot) + IsoMath.grid_to_screen(a - f) - Vector2(0, z0)
	var eu := IsoMath.grid_to_screen(b - a)
	var length := eu.length()
	var tiles := (b - a).length()
	if length < 1.0:
		return
	var px_per_tile := length / tiles
	var holes: Array = []
	var door_u := door_at * px_per_tile
	if door_at >= 0.0:
		holes.append([door_u - 6.0, 3.0, door_u + 6.0, 28.0, "door"])
	var count := maxi(1, int(round(tiles / 0.85)))
	for k: int in count:
		var mid := (k + 0.5) * length / count
		for floor_i: int in floors:
			var v0: float = h * 0.36 if floors == 1 else (h * 0.14 if floor_i == 0 else h * 0.6)
			if floors >= 3:
				v0 = [h * 0.09, h * 0.42, h * 0.7][mini(floor_i, 2)]
			var wh := 12.0 if not tall else h * 0.45
			if floors >= 3 and floor_i == 1:
				wh = 14.0   # piano nobile: taller windows on the main floor
			if tall:
				v0 = h * 0.3
			if door_at >= 0.0 and absf(mid - door_u) < 14.0 and v0 < 30.0:
				continue
			if h >= 20.0 and length >= 16.0:
				holes.append([mid - 4.5, v0, mid + 4.5, v0 + wh, "arch" if tall else "window"])
	var poly := PackedVector2Array([o, o + eu, o + eu - Vector2(0, h), o - Vector2(0, h)])
	_fill_shader(img, poly, func(x: int, y: int) -> Color:
		var p := Vector2(x + 0.5, y + 0.5) - o
		var u := _project_u(p, eu) * length
		var v := -(p.y - eu.y * (u / length))
		for hole: Array in holes:
			if u >= hole[0] and u < hole[2] and v >= hole[1] and v < hole[3]:
				var hc := _opening(u - hole[0], v - hole[1], hole[2] - hole[0], hole[3] - hole[1], hole[4], shutters)
				if hc.a > 0.0:
					return _lit(hc, light)
		var col := _wall_material(material, u, v, h, length, tint)
		for hole: Array in holes:
			if hole[4] == "window" and v >= hole[1] and v < hole[3] \
					and (u >= hole[0] - 3.0 and u < hole[0] or u >= hole[2] and u < hole[2] + 3.0):
				col = shutters.darkened(0.15 * float(int(v) % 3 == 0))
			if hole[4] == "window" and v >= hole[1] - 2.0 and v < hole[1] and u >= hole[0] - 1.0 and u < hole[2] + 1.0 \
					and floors > 1:
				col = Color(0.75, 0.3, 0.3) if int(u) % 3 != 0 else Color(0.35, 0.55, 0.25)
		return _lit(col, light))
	_outline(img, poly, _lit(_wall_material(material, 1.0, 1.0, h, length, tint), light).darkened(0.55))


## A ridge roof over [param r] along grid x or y. [param ends]: start and end of the ridge,
## each "gable" (vertical wall triangle), "hip" (sloped triangle) or "open" (flush, a row or
## a wing continues there).
func _roof(img: Image, pivot: Vector2i, r: Rect2, material: String, h: float, rh: float, along_x: bool,
		ends: Array[String], wall_material: String, tint: Color) -> void:
	var length := r.size.x if along_x else r.size.y
	var width := r.size.y if along_x else r.size.x
	var drop := rh * OVERHANG / (width * 0.5)
	var g := func(a: float, c: float, z: float) -> Vector3:
		return Vector3(r.position.x + a, r.position.y + c, z) if along_x else Vector3(r.position.x + c, r.position.y + a, z)
	var o_start := 0.0 if ends[0] == "open" else OVERHANG
	var o_end := 0.0 if ends[1] == "open" else OVERHANG
	var r_start := -o_start if ends[0] != "hip" else width * 0.5
	var r_end := length + o_end if ends[1] != "hip" else length - width * 0.5
	var eave_lo := h - drop
	var top := h + rh
	var a0 := -o_start
	var a1 := length + o_end
	var faces: Array = []
	faces.append({"eave": [g.call(a0, width + OVERHANG, eave_lo), g.call(a1, width + OVERHANG, eave_lo)],
			"ridge": [g.call(r_start, width * 0.5, top), g.call(r_end, width * 0.5, top)],
			"light": LIGHT_ROOF_SW if along_x else LIGHT_ROOF_SE, "depth": 2.0})
	faces.append({"eave": [g.call(a0, -OVERHANG, eave_lo), g.call(a1, -OVERHANG, eave_lo)],
			"ridge": [g.call(r_start, width * 0.5, top), g.call(r_end, width * 0.5, top)],
			"light": LIGHT_ROOF_BACK, "depth": 0.0})
	for e: int in 2:
		var at := a0 if e == 0 else a1
		var ridge_at := r_start if e == 0 else r_end
		var light := LIGHT_ROOF_BACK if e == 0 else (LIGHT_ROOF_SE if along_x else LIGHT_ROOF_SW)
		if ends[e] == "hip":
			faces.append({"eave": [g.call(at, -OVERHANG, eave_lo), g.call(at, width + OVERHANG, eave_lo)],
					"ridge": [g.call(ridge_at, width * 0.5, top), g.call(ridge_at, width * 0.5, top)],
					"light": light, "depth": 1.0 if e == 0 else 3.0})
		elif ends[e] == "gable" and e == 1:
			var gl := LIGHT_SE if along_x else LIGHT_SW
			_gable(img, pivot, g.call(length, 0.0, h), g.call(length, width, h), g.call(length, width * 0.5, top - 2.0),
					wall_material, tint, gl)
	faces.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return p["depth"] < q["depth"])
	for face: Dictionary in faces:
		var ea: Vector2 = _scr(pivot, face["eave"][0])
		var eb: Vector2 = _scr(pivot, face["eave"][1])
		var ra: Vector2 = _scr(pivot, face["ridge"][0])
		var rb: Vector2 = _scr(pivot, face["ridge"][1])
		var poly := PackedVector2Array([ea, eb, rb, ra]) if ra.distance_to(rb) > 0.5 else PackedVector2Array([ea, eb, ra])
		_face_2d(img, poly, ea, eb - ea, (ra + rb) * 0.5 - (ea + eb) * 0.5, material, face["light"])


# --- Lean-tos, round towers, towers --------------------------------------------------------

## A shed against a wall: the roof falls from [code]hh[/code] at the back to [code]h[/code] at the
## front side named by [code]low[/code]. Open sheds show a dark back wall and posts.
func _lean(img: Image, pivot: Vector2i, vol: Dictionary) -> void:
	var r := _rect(vol)
	var h: float = vol["h"]
	var hh: float = vol["hh"]
	var low_x: bool = vol["low"] == "x"
	var open: bool = vol["open"]
	var walls: String = vol["walls"]
	var f := Vector2(_footprint)
	# Side wall (the face parallel to the slope): a trapezoid, then the front wall or posts.
	var side_a := Vector2(r.position.x, r.end.y) if low_x else Vector2(r.end.x, r.position.y)
	var side_b := r.end
	var back_side := Vector2(r.position.x, r.position.y)
	var front_a := Vector2(r.end.x, r.position.y) if low_x else Vector2(r.position.x, r.end.y)
	if open:
		# Inside: back wall in shadow and earth floor.
		var floor_poly := PackedVector2Array()
		for p: Vector2 in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
			floor_poly.append(Vector2(pivot) + IsoMath.grid_to_screen(p - f))
		_fill(img, floor_poly, Color(0.4, 0.31, 0.21))
		var bw_a := back_side
		var bw_b := Vector2(r.position.x, r.end.y) if low_x else Vector2(r.end.x, r.position.y)
		var sa := Vector2(pivot) + IsoMath.grid_to_screen(bw_a - f)
		var sb := Vector2(pivot) + IsoMath.grid_to_screen(bw_b - f)
		_fill(img, PackedVector2Array([sa, sb, sb - Vector2(0, hh), sa - Vector2(0, hh)]), C_PLANK.darkened(0.55))
		for prop: Array in vol.get("inside", []):
			_prop(img, Vector2(pivot) + IsoMath.grid_to_screen(Vector2(prop[1], prop[2]) - f), String(prop[0]))
	# Side trapezoid wall (lit if it faces SW).
	var s0 := Vector2(pivot) + IsoMath.grid_to_screen(side_a - f)
	var s1 := Vector2(pivot) + IsoMath.grid_to_screen(side_b - f)
	var back_corner := Vector2(r.position.x, r.end.y) if low_x else Vector2(r.end.x, r.position.y)
	var hb := Vector2(pivot) + IsoMath.grid_to_screen(back_corner - f)
	var side_light := LIGHT_SW if low_x else LIGHT_SE
	if not open:
		var side := PackedVector2Array([hb, s1, s1 - Vector2(0, h), hb - Vector2(0, hh)])
		_fill_shader(img, side, func(x: int, y: int) -> Color:
			return _lit(_wall_material(walls, float(x), float(int(s1.y) - y), hh, 200.0, Color.WHITE), side_light))
		_outline(img, side, C_BEAM.darkened(0.3))
		var fa := Vector2(pivot) + IsoMath.grid_to_screen(front_a - f)
		var front := PackedVector2Array([fa, s1, s1 - Vector2(0, h), fa - Vector2(0, h)])
		_fill_shader(img, front, func(x: int, y: int) -> Color:
			return _lit(_wall_material(walls, float(x), float(int(s1.y) - y), h, 200.0, Color.WHITE), LIGHT_SE if low_x else LIGHT_SW))
		_outline(img, front, C_BEAM.darkened(0.3))
	else:
		for p: Vector2 in [s1, Vector2(pivot) + IsoMath.grid_to_screen(front_a - f), hb]:
			var top := h if p != hb else hh
			_line(img, p, p - Vector2(0, top), C_BEAM, 2)
	# Roof plane: eave on the low side, ridge against the back.
	var eave_a := Vector3(r.end.x + OVERHANG, r.position.y - 0.05, h - 2.0) if low_x else Vector3(r.position.x - 0.05, r.end.y + OVERHANG, h - 2.0)
	var eave_b := Vector3(r.end.x + OVERHANG, r.end.y + 0.05, h - 2.0) if low_x else Vector3(r.end.x + 0.05, r.end.y + OVERHANG, h - 2.0)
	var top_a := Vector3(r.position.x, r.position.y - 0.05, hh) if low_x else Vector3(r.position.x - 0.05, r.position.y, hh)
	var top_b := Vector3(r.position.x, r.end.y + 0.05, hh) if low_x else Vector3(r.end.x + 0.05, r.position.y, hh)
	var ea := _scr(pivot, eave_a)
	var eb := _scr(pivot, eave_b)
	var ta := _scr(pivot, top_a)
	var tb := _scr(pivot, top_b)
	var roof_material: String = vol["roof"]
	_face_2d(img, PackedVector2Array([ea, eb, tb, ta]), ea, eb - ea, (ta + tb) * 0.5 - (ea + eb) * 0.5,
			"shingle" if roof_material == "planks_roof" else roof_material, LIGHT_ROOF_SE if low_x else LIGHT_ROOF_SW)


## A round tower with a conical roof (windmill, hop kiln).
func _round(img: Image, pivot: Vector2i, vol: Dictionary) -> void:
	var c: Array = vol["centre"]
	var centre := Vector2(pivot) + IsoMath.grid_to_screen(Vector2(c[0], c[1]) - Vector2(_footprint))
	var r: float = vol["r"]
	var h: float = vol["h"]
	var rh: float = vol["rh"]
	var rx := r * 45.25
	var ry := r * 22.6
	var walls: String = vol["walls"]
	# Walls: column by column, front half of the cylinder.
	for x: int in range(int(centre.x - rx), int(centre.x + rx) + 1):
		var sx := clampf((x + 0.5 - centre.x) / rx, -1.0, 1.0)
		var theta := asin(sx)
		var bottom := centre.y + ry * cos(theta)
		var light := 0.95 - 0.22 * sx
		for y: int in range(int(bottom - h), int(bottom)):
			var u := (theta + PI * 0.5) * rx
			var v := bottom - y
			var col := _wall_material(walls, u, v, h, PI * rx, Color.WHITE)
			# Door at the front, a few small windows up the tower.
			if absf(sx - 0.15) < 0.14 and v > 2.0 and v < 28.0:
				col = C_DOOR if absf(sx - 0.15) < 0.11 and v < 27.0 else C_BEAM
			elif (absf(sx + 0.3) < 0.08 and absf(v - h * 0.55) < 4.0) or (absf(sx - 0.35) < 0.08 and absf(v - h * 0.8) < 4.0):
				col = C_GLASS if absf(sx) > 0.0 else C_BEAM
			_px(img, Vector2i(x, y), _lit(col, light))
	# Conical roof with a small overhang.
	var base_y := centre.y - h
	var crx := rx * 1.12
	var cry := ry * 1.12
	var apex := Vector2(centre.x, base_y - rh)
	var cone := PackedVector2Array([apex])
	for k: int in 25:
		var a := PI - k * PI / 24.0
		cone.append(Vector2(centre.x + cos(a) * crx, base_y + sin(a) * cry))
	_fill_shader(img, cone, func(x: int, y: int) -> Color:
		var t := clampf((y + 0.5 - apex.y) / (base_y + cry * 0.5 - apex.y), 0.02, 1.0)
		var sx := clampf((x + 0.5 - centre.x) / (crx * t), -1.0, 1.0)
		var theta := asin(sx)
		var u := (theta + PI * 0.5) * 18.0
		var v := (1.0 - t) * rh * 1.2
		return _lit(_roof_material(String(vol["roof"]), u, v, rh * 1.2), 1.0 - 0.25 * sx))
	_outline(img, cone, C_BEAM.darkened(0.3))
	if vol.get("cowl", false):
		_box(img, apex + Vector2(0, 6), Vector2(8, 4), 8.0, Color(0.85, 0.82, 0.75), "planks")
		_fill(img, PackedVector2Array([apex + Vector2(-5, -2), apex + Vector2(5, -8), apex + Vector2(5, -2)]), Color(0.9, 0.88, 0.82))
	if vol.get("sails", false):
		_sails(img, Vector2(centre.x + rx * 0.35, base_y - rh * 0.25))


func _sails(img: Image, hub: Vector2) -> void:
	for k: int in 4:
		var a := k * PI / 2.0 + PI / 5.0
		var dir := Vector2(cos(a), sin(a) * 0.85)
		var side := dir.orthogonal() * 8.0
		var tip := hub + dir * 54.0
		var sail := PackedVector2Array([hub + dir * 10.0, tip, tip + side, hub + dir * 10.0 + side])
		_fill_shader(img, sail, func(x: int, y: int) -> Color:
			return Color(0.55, 0.42, 0.28) if (x % 4 == 0 or y % 4 == 0) else Color(0.93, 0.9, 0.82))
		_outline(img, sail, Color(0.4, 0.3, 0.2))
		_line(img, hub, tip, C_BEAM.lightened(0.1), 2)
	_ellipse(img, hub, Vector2(4, 4), C_BEAM)


## A square tower from the ground with a spire.
func _tower(img: Image, pivot: Vector2i, vol: Dictionary) -> void:
	var r := _rect(vol)
	var f := Vector2(_footprint)
	var height: float = vol["h"]
	var walls: String = vol["walls"]
	for side: int in 2:
		var a := Vector2(r.end.x, r.position.y) if side == 0 else Vector2(r.position.x, r.end.y)
		var o := Vector2(pivot) + IsoMath.grid_to_screen(a - f)
		var eu := IsoMath.grid_to_screen(r.end - a)
		var length := eu.length()
		var light := LIGHT_SE if side == 0 else LIGHT_SW
		var clock: bool = vol.get("clock", false) and side == 1
		var poly := PackedVector2Array([o, o + eu, o + eu - Vector2(0, height), o - Vector2(0, height)])
		_fill_shader(img, poly, func(x: int, y: int) -> Color:
			var p := Vector2(x + 0.5, y + 0.5) - o
			var u := _project_u(p, eu) * length
			var v := -(p.y - eu.y * (u / length))
			var mu := absf(u - length * 0.5)
			if clock and Vector2(u - length * 0.5, v - (height - 22.0)).length() < 6.0:
				var d := Vector2(u - length * 0.5, v - (height - 22.0))
				if d.length() > 5.0:
					return _lit(C_BEAM, light)
				if (absf(d.x) < 0.7 and d.y > 0.0 and d.y < 4.5) or (absf(d.y) < 0.7 and d.x > 0.0 and d.x < 3.0):
					return _lit(C_IRON, light)
				return _lit(Color(0.92, 0.88, 0.75), light)
			if mu < 3.0 and v > height - 13.0 and v < height - 4.0:
				return _lit(C_BEAM.darkened(0.3) if int(v) % 2 == 0 else C_BEAM, light)
			if mu < 1.2 and v > height * 0.35 and v < height * 0.35 + 7.0:
				return _lit(C_GLASS, light)
			return _lit(_wall_material(walls, u, v, height, length, Color.WHITE), light))
		_outline(img, poly, _lit(C_STONE, light).darkened(0.55))
	var centre := r.get_center()
	var apex := Vector2(pivot) + IsoMath.grid_to_screen(centre - f) - Vector2(0, height + float(vol["spire"]))
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for k: int in [0, 3, 1, 2]:
		var a: Vector2 = corners[k]
		var b: Vector2 = corners[(k + 1) % 4]
		var sa := Vector2(pivot) + IsoMath.grid_to_screen(a - f + (a - centre) * 0.2) - Vector2(0, height - 2.0)
		var sb := Vector2(pivot) + IsoMath.grid_to_screen(b - f + (b - centre) * 0.2) - Vector2(0, height - 2.0)
		var light: float = [LIGHT_ROOF_BACK, LIGHT_ROOF_SE, LIGHT_ROOF_SW, LIGHT_ROOF_BACK][k]
		_face_2d(img, PackedVector2Array([sa, sb, apex]), sa, sb - sa, apex - (sa + sb) * 0.5, String(vol["roof"]), light)
	if vol.get("cross", false):
		_line(img, apex, apex - Vector2(0, 10), Color(0.9, 0.8, 0.35), 1)
		_line(img, apex - Vector2(3, 7), apex - Vector2(-3, 7), Color(0.9, 0.8, 0.35), 1)
	else:
		_line(img, apex, apex - Vector2(0, 12), C_IRON, 1)
		_fill(img, PackedVector2Array([apex - Vector2(-1, 12), apex - Vector2(-9, 10), apex - Vector2(-1, 7)]), Color(0.8, 0.2, 0.2))


# --- Special buildings and sites -----------------------------------------------------------

func _market(id: String) -> void:
	var c := _canvas(48.0, 8)
	var img: Image = c["img"]
	var pivot: Vector2i = c["pivot"]
	var f := Vector2(_footprint)
	var base := PackedVector2Array()
	for p: Vector2 in [Vector2(INSET, INSET), Vector2(f.x - INSET, INSET), f - Vector2(INSET, INSET), Vector2(INSET, f.y - INSET)]:
		base.append(Vector2(pivot) + IsoMath.grid_to_screen(p - f))
	_fill_shader(img, base, func(x: int, y: int) -> Color:
		var row := y / 4
		var col := (x + (row % 2) * 4) / 8
		var stone := C_STONE.lightened(0.1).darkened(0.12 * _hash(col, row, 7))
		return C_MORTAR if (y % 4 == 0 or (x + (row % 2) * 4) % 8 == 0) else stone)
	_outline(img, base, C_MORTAR.darkened(0.3))
	var stripes := [[Color(0.85, 0.25, 0.2), Color(0.95, 0.9, 0.8)], [Color(0.25, 0.4, 0.7), Color(0.95, 0.9, 0.8)],
			[Color(0.35, 0.55, 0.25), Color(0.92, 0.85, 0.55)]]
	var spots := [Vector2(0.9, 0.9), Vector2(2.1, 0.9), Vector2(0.9, 2.1)]
	for k: int in 3:
		_stall(img, pivot, spots[k] - f, stripes[k])
	_crate(img, Vector2(pivot) + IsoMath.grid_to_screen(Vector2(2.3, 2.2) - f), C_PLANK)
	_crate(img, Vector2(pivot) + IsoMath.grid_to_screen(Vector2(2.6, 1.9) - f) - Vector2(0, 2), C_PLANK.darkened(0.1))
	_barrel(img, Vector2(pivot) + IsoMath.grid_to_screen(Vector2(1.6, 1.6) - f))
	_finish(img)
	_write(id, "base", {"img": img, "pivot": pivot})


## Construction site: phase 1 = foundation stones, stakes and string, piles of material;
## phase 2 = foundation plus a timber skeleton with rafters, half the infill and scaffolding.
## [param back]: a house turned with its door away from the camera; materials and the
## ladder are on the far side, by the door.
func _site_image(phase: int, id: String, back: bool = false) -> Dictionary:
	var c := _canvas(78.0, 12)
	var img: Image = c["img"]
	var pivot: Vector2i = c["pivot"]
	var f := Vector2(_footprint)
	var r := Rect2(Vector2(INSET, INSET), f - Vector2(INSET, INSET) * 2.0)
	var ground := PackedVector2Array()
	for p: Vector2 in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		ground.append(Vector2(pivot) + IsoMath.grid_to_screen(p - f))
	_fill_shader(img, ground, func(x: int, y: int) -> Color:
		return Color(0.47, 0.37, 0.25).darkened(0.12 * _hash(x / 3, y / 2, 61)))
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	# Foundation course: back walls first.
	for e: Array in [[corners[0], corners[1]], [corners[0], corners[3]], [corners[1], corners[2]], [corners[3], corners[2]]]:
		var light := LIGHT_SE if (e[1] as Vector2).x == r.end.x and (e[0] as Vector2).x == r.end.x else LIGHT_SW
		_wall_face(img, pivot, e[0], e[1], 0.0, 6.0, "stone", Color.WHITE, light, C_BEAM, 1, -1.0, false)
	var h := 40.0
	if phase == 1:
		# Stakes and string at the corners, materials waiting.
		for p: Vector2 in corners:
			var s := Vector2(pivot) + IsoMath.grid_to_screen(p - f)
			_line(img, s - Vector2(0, 6), s - Vector2(0, 16), C_PLANK.lightened(0.3), 2)
		for e: Array in [[corners[3], corners[2]], [corners[1], corners[2]]]:
			_line(img, Vector2(pivot) + IsoMath.grid_to_screen(e[0] - f) - Vector2(0, 14),
					Vector2(pivot) + IsoMath.grid_to_screen(e[1] - f) - Vector2(0, 14), Color(0.9, 0.88, 0.8), 1)
		_prop(img, Vector2(pivot) + IsoMath.grid_to_screen(r.get_center() - f), "barrel")
		_line(img, Vector2(pivot) + IsoMath.grid_to_screen(r.get_center() + Vector2(0.3, -0.2) - f),
				Vector2(pivot) + IsoMath.grid_to_screen(r.get_center() + Vector2(0.5, -0.4) - f) - Vector2(0, 12), C_BEAM, 1)
		if back:
			_stone_pile(img, Vector2(pivot) + IsoMath.grid_to_screen(r.position + Vector2(0.45, 0.35) - f))
		else:
			_stone_pile(img, Vector2(pivot) + IsoMath.grid_to_screen(Vector2(r.end.x - 0.4, r.end.y + 0.02) - f))
			_plank_pile(img, Vector2(pivot) + IsoMath.grid_to_screen(Vector2(r.position.x + 0.45, r.end.y + 0.02) - f))
	else:
		var along_x := f.x >= f.y
		# Skeleton: posts every half tile on the visible walls, plates, braces.
		var faces := [[corners[1], corners[2], LIGHT_SE], [corners[3], corners[2], LIGHT_SW]]
		for face: Array in faces:
			var a: Vector2 = face[0]
			var b: Vector2 = face[1]
			# Lower half of the infill is done on the lit wall.
			if face[2] == LIGHT_SW:
				_wall_face(img, pivot, a, a.lerp(b, 0.6), 6.0, 10.0, "planks", Color.WHITE, LIGHT_SW, C_BEAM, 1, -1.0, false)
			var n := maxi(2, int(round((b - a).length() * 2.0)))
			for k: int in n + 1:
				var p := Vector2(pivot) + IsoMath.grid_to_screen(a.lerp(b, float(k) / n) - f)
				_line(img, p - Vector2(0, 6), p - Vector2(0, h), C_BEAM.lightened(0.15), 2)
			var pa := Vector2(pivot) + IsoMath.grid_to_screen(a - f)
			var pb := Vector2(pivot) + IsoMath.grid_to_screen(b - f)
			_line(img, pa - Vector2(0, h), pb - Vector2(0, h), C_BEAM.lightened(0.15), 2)
			_line(img, pa - Vector2(0, 7), pa.lerp(pb, 0.5) - Vector2(0, h - 2), C_BEAM, 1)
		# Back posts and rafters (A-frames along the ridge).
		for p: Vector2 in [corners[0], corners[1], corners[3]]:
			var s := Vector2(pivot) + IsoMath.grid_to_screen(p - f)
			_line(img, s - Vector2(0, 6), s - Vector2(0, h), C_BEAM, 2)
		var length := r.size.x if along_x else r.size.y
		var n_r := maxi(2, int(round(length * 2.0)))
		for k: int in n_r + 1:
			var t := float(k) / n_r
			var a3 := Vector3(r.position.x + r.size.x * t, r.position.y, h) if along_x else Vector3(r.position.x, r.position.y + r.size.y * t, h)
			var b3 := Vector3(r.position.x + r.size.x * t, r.end.y, h) if along_x else Vector3(r.end.x, r.position.y + r.size.y * t, h)
			var m3 := (a3 + b3) * 0.5 + Vector3(0, 0, 20.0)
			if k == 0 or k == n_r or k == n_r / 2:
				_line(img, _scr(pivot, a3), _scr(pivot, m3), C_PLANK.lightened(0.1), 2)
				_line(img, _scr(pivot, b3), _scr(pivot, m3), C_PLANK.lightened(0.1), 2)
		var ridge_a := Vector3(r.position.x, r.get_center().y, h + 20.0) if along_x else Vector3(r.get_center().x, r.position.y, h + 20.0)
		var ridge_b := Vector3(r.end.x, r.get_center().y, h + 20.0) if along_x else Vector3(r.get_center().x, r.end.y, h + 20.0)
		_line(img, _scr(pivot, ridge_a), _scr(pivot, ridge_b), C_PLANK, 2)
		if back:
			_finish(img)
			return {"img": img, "pivot": pivot}
		# Scaffold plank and a ladder on the lit side.
		var s0 := Vector2(pivot) + IsoMath.grid_to_screen(corners[3] + Vector2(0, 0.12) - f)
		var s1 := Vector2(pivot) + IsoMath.grid_to_screen(corners[2] + Vector2(0, 0.12) - f)
		_line(img, s0 - Vector2(0, 20), s1 - Vector2(0, 20), C_PLANK.lightened(0.25), 3)
		var l := s0.lerp(s1, 0.3)
		_line(img, l, l - Vector2(0, 28), C_PLANK.lightened(0.2), 1)
		_line(img, l + Vector2(4, 0), l + Vector2(4, -28), C_PLANK.lightened(0.2), 1)
		for k: int in 5:
			_line(img, l - Vector2(0, 4 + k * 5), l + Vector2(4, -4 - k * 5), C_PLANK.lightened(0.2), 1)
		_plank_pile(img, Vector2(pivot) + IsoMath.grid_to_screen(Vector2(r.end.x + 0.02, r.end.y - 0.4) - f))
	var _unused := id
	_finish(img)
	return {"img": img, "pivot": pivot}


func _stone_pile(img: Image, foot: Vector2) -> void:
	_box(img, foot + Vector2(-5, 0), Vector2(9, 4), 5.0, C_STONE, "stone")
	_box(img, foot + Vector2(4, 1), Vector2(8, 4), 4.0, C_STONE.darkened(0.08), "stone")
	_box(img, foot + Vector2(0, -4), Vector2(8, 4), 4.0, C_STONE.lightened(0.06), "stone")


func _plank_pile(img: Image, foot: Vector2) -> void:
	for i: int in 4:
		_line(img, foot + Vector2(-11, -1 - i * 2), foot + Vector2(8, 8 - i * 2), C_PLANK.lightened(0.25 - 0.05 * i), 2)


## [param back]: the ladder leans on the right-hand wall (the door is away from the camera).
func _scaffold_image(back: bool = false) -> Dictionary:
	var c := _canvas(84.0, 12)
	var img: Image = c["img"]
	var pivot: Vector2i = c["pivot"]
	var f := Vector2(_footprint)
	var wood := C_PLANK.lightened(0.2)
	for p: Vector2 in [Vector2(0.05, f.y + 0.05), f + Vector2(0.05, 0.05), Vector2(f.x + 0.05, 0.05)]:
		var s := Vector2(pivot) + IsoMath.grid_to_screen(p - f)
		_line(img, s, s - Vector2(0, 62), wood, 2)
	for level: float in [22.0, 44.0]:
		for e: Array in [[Vector2(0, f.y), f], [Vector2(f.x, 0), f]]:
			var a := Vector2(pivot) + IsoMath.grid_to_screen(e[0] + Vector2(0.05, 0.05) - f) - Vector2(0, level)
			var b := Vector2(pivot) + IsoMath.grid_to_screen(e[1] + Vector2(0.05, 0.05) - f) - Vector2(0, level)
			_line(img, a, b, wood, 3)
			_line(img, a + Vector2(0, 2), b + Vector2(0, 2), wood.darkened(0.3), 1)
	var l := Vector2(pivot) + IsoMath.grid_to_screen(Vector2(0.05, -0.5) if back else Vector2(-0.5, 0.05))
	_line(img, l, l - Vector2(0, 46), wood, 1)
	_line(img, l + Vector2(5, 0), l + Vector2(5, -46), wood, 1)
	for k: int in 8:
		_line(img, l - Vector2(0, 4 + k * 5.5), l + Vector2(5, -4 - k * 5.5), wood, 1)
	_finish(img)
	return {"img": img, "pivot": pivot}


# --- Props ---------------------------------------------------------------------------------

func _prop(img: Image, p: Vector2, prop: String) -> void:
	match prop:
		"tent":
			# A ridge tent of canvas: the lit front triangle with a dark door flap and the
			# side slope in shade (M5 part 3, pioneer camp).
			var canvas := Color(0.86, 0.8, 0.64)
			var apex := p + Vector2(-3, -24)
			var back := p + Vector2(13, -31)
			var side := PackedVector2Array([p + Vector2(7, 6), p + Vector2(23, -2), back, apex])
			_fill(img, side, _lit(canvas, LIGHT_SE))
			_outline(img, side, canvas.darkened(0.55))
			var front := PackedVector2Array([p + Vector2(-13, 0), p + Vector2(7, 6), apex])
			_fill(img, front, _lit(canvas, LIGHT_SW))
			_outline(img, front, canvas.darkened(0.55))
			_fill(img, PackedVector2Array([p + Vector2(-5, 3), p + Vector2(1, 5), apex + Vector2(0, 7)]),
					canvas.darkened(0.45))
			_line(img, apex, apex + Vector2(0, -4), C_BEAM, 1)
			_line(img, p + Vector2(23, -2), p + Vector2(28, 1), C_BEAM.lightened(0.3), 1)
		"campfire":
			for i: int in 8:
				var a := TAU * i / 8.0
				_ellipse(img, p + Vector2(cos(a) * 7, sin(a) * 3.5), Vector2(2, 1.5), Color(0.5, 0.48, 0.45))
			_line(img, p + Vector2(-5, -1), p + Vector2(5, 1), C_LOG, 2)
			_line(img, p + Vector2(-4, 2), p + Vector2(4, -2), C_LOG.darkened(0.2), 2)
			_ellipse(img, p + Vector2(0, -3), Vector2(3, 4), Color(0.95, 0.45, 0.12))
			_ellipse(img, p + Vector2(0, -4), Vector2(1.5, 2.5), Color(1.0, 0.85, 0.35))
			# A kettle on a tripod over the fire.
			_line(img, p + Vector2(-7, 1), p + Vector2(0, -16), C_BEAM, 1)
			_line(img, p + Vector2(7, 1), p + Vector2(0, -16), C_BEAM, 1)
			_line(img, p + Vector2(0, -16), p + Vector2(0, -10), C_IRON, 1)
			_ellipse(img, p + Vector2(0, -8), Vector2(3, 2.5), C_IRON.lightened(0.15))
		"log_stack":
			for row: int in 3:
				for k: int in 4 - row:
					var c := p + Vector2(-9 + k * 6 + row * 3, -3 - row * 5)
					_ellipse(img, c, Vector2(3, 3), Color(0.74, 0.58, 0.36))
					_px(img, Vector2i(c), Color(0.55, 0.38, 0.2))
		"log_pile":
			for i: int in 3:
				_line(img, p + Vector2(-10, -2 - i * 3), p + Vector2(8, 6 - i * 3), C_LOG.lightened(0.05 * i), 4)
				_ellipse(img, p + Vector2(8, 6 - i * 3), Vector2(2, 2), Color(0.74, 0.58, 0.36))
		"chopping_block":
			_box(img, p, Vector2(8, 4), 5.0, C_LOG)
			_line(img, p - Vector2(1, 6), p + Vector2(4, -13), C_BEAM.lightened(0.2), 1)
			_line(img, p + Vector2(2, -12), p + Vector2(6, -11), C_IRON.lightened(0.3), 2)
		"saw_horse":
			for s: float in [-6.0, 6.0]:
				_line(img, p + Vector2(s - 3, 0), p + Vector2(s, -8), C_BEAM, 1)
				_line(img, p + Vector2(s + 3, 0), p + Vector2(s, -8), C_BEAM, 1)
			_line(img, p + Vector2(-11, -9), p + Vector2(11, -8), C_LOG, 4)
			_ellipse(img, p + Vector2(11, -8), Vector2(2, 2), Color(0.74, 0.58, 0.36))
		"plank_stack":
			_plank_pile(img, p)
		"stone_blocks":
			_stone_pile(img, p)
		"port_crane":
			# A tall timber crane on the quay: post, strut, jib out over the water, a crate
			# hanging from the rope.
			_box(img, p, Vector2(12, 6), 4.0, C_BEAM.lightened(0.1))
			_line(img, p - Vector2(0, 4), p - Vector2(0, 56), C_BEAM, 3)
			_line(img, p - Vector2(0, 18), p + Vector2(-14, -40), C_BEAM.lightened(0.05), 2)
			_line(img, p - Vector2(0, 54), p + Vector2(-30, -42), C_BEAM, 2)
			_line(img, p + Vector2(-29, -42), p + Vector2(-29, -20), Color(0.75, 0.65, 0.45), 1)
			_crate(img, p + Vector2(-29, -12), Color(0.62, 0.46, 0.28))
		"crane_mast":
			# N1 part 2: a heavy squared timber mast on a stone plinth, four raking struts with
			# cross braces, iron bands, a slewing collar (the jib's heel, CraneLayer.HEEL_HEIGHT)
			# and a little gabled hood over the sheave at the top.
			_box(img, p + Vector2(0, 2), Vector2(30, 15), 8.0, C_STONE, "stone")
			_box(img, p - Vector2(0, 8), Vector2(22, 11), 3.0, C_PLANK, "planks")
			var foot := p - Vector2(0, 11)
			var knee := foot - Vector2(0, 46)
			for corner: Vector2 in [Vector2(-10, -5), Vector2(10, -5), Vector2(-10, 5), Vector2(10, 5)]:
				if corner.y < 0:
					_line(img, foot + corner, knee, C_BEAM.darkened(0.2), 3)
			_box(img, foot, Vector2(9, 5), 104.0, C_BEAM.lightened(0.12))
			for corner: Vector2 in [Vector2(-10, 5), Vector2(10, 5)]:
				_line(img, foot + corner, knee + Vector2(corner.x * 0.15, 2), C_BEAM, 3)
				_line(img, foot + corner + Vector2(-1, -1), knee + Vector2(corner.x * 0.15 - 1, 1), C_BEAM.lightened(0.25), 1)
			# Cross braces between the front struts and the mast.
			for side: float in [-1.0, 1.0]:
				_line(img, foot + Vector2(side * 7, 2), foot + Vector2(0, -30), C_BEAM.darkened(0.1), 2)
			for k: int in 7:
				var y := 18.0 + k * 13.0
				_line(img, foot - Vector2(5, y), foot - Vector2(-5, y + 2.5), C_IRON, 1)
				_px(img, Vector2i(foot - Vector2(2, y + 1)), C_IRON.lightened(0.5))
			# The slewing collar: a thick timber ring with iron straps.
			_box(img, foot - Vector2(0, 80), Vector2(16, 8), 8.0, C_BEAM.lightened(0.2))
			_line(img, foot - Vector2(8, 84), foot - Vector2(-8, 84), C_IRON, 1)
			# The hood: a small gabled roof of planks over the sheave, a finial.
			var top := foot - Vector2(0, 104)
			_box(img, top + Vector2(0, 2), Vector2(12, 6), 5.0, C_BEAM)
			var ridge_l := top + Vector2(-9, -6)
			var ridge_r := top + Vector2(9, -6)
			var apex := top + Vector2(0, -15)
			_fill(img, PackedVector2Array([top + Vector2(-11, 0), top + Vector2(0, 4), apex + Vector2(0, 3), ridge_l]), _lit(C_SHINGLE, LIGHT_ROOF_SW))
			_fill(img, PackedVector2Array([top + Vector2(0, 4), top + Vector2(11, 0), ridge_r, apex + Vector2(0, 3)]), _lit(C_SHINGLE, LIGHT_ROOF_SE))
			_outline(img, PackedVector2Array([top + Vector2(-11, 0), top + Vector2(0, 4), top + Vector2(11, 0), ridge_r, apex, ridge_l]), C_SHINGLE.darkened(0.6))
			_line(img, apex, apex - Vector2(0, 5), C_IRON, 1)
		"treadwheel":
			# N1 part 2: a big treadwheel: two thick rims joined by tread boards, double spokes,
			# a drum on the axle with the hoist rope wound on it, heavy A-frames on sill beams.
			var c := p - Vector2(0, 25)
			var depth := Vector2(10, -5)
			var rim := Color(0.56, 0.38, 0.22)
			var r := 22.0
			_line(img, p + Vector2(-18, 2), p + Vector2(18, 2) , C_BEAM.darkened(0.2), 3)
			_line(img, p + Vector2(-18, 2) + depth, p + Vector2(18, 2) + depth, C_BEAM.darkened(0.3), 3)
			for side: float in [-1.0, 1.0]:
				_line(img, p + Vector2(side * 17, 1) + depth, c + depth, C_BEAM.darkened(0.25), 3)
			_circle(img, c + depth, r, rim.darkened(0.4), 3)
			for k: int in 8:
				var a := TAU * k / 8.0 + 0.2
				_line(img, c + depth, c + depth + Vector2(cos(a), sin(a)) * (r - 2.0), rim.darkened(0.45), 1)
			# Tread boards across, lit on the lower half where the operator walks.
			for k: int in 28:
				var a := TAU * k / 28.0
				var q := c + Vector2(cos(a), sin(a)) * (r - 1.0)
				var lit := rim.lightened(0.18) if sin(a) > 0.3 else rim.darkened(0.05)
				_line(img, q, q + depth, lit, 2)
				_line(img, q + Vector2(0, 1), q + depth + Vector2(0, 1), rim.darkened(0.35), 1)
			_circle(img, c, r, rim, 3)
			_circle(img, c, r - 3.5, rim.darkened(0.25), 1)
			for k: int in 8:
				var a := TAU * k / 8.0 + 0.2
				_line(img, c, c + Vector2(cos(a), sin(a)) * (r - 2.0), rim.darkened(0.15), 2)
			# The drum with rope wound on it, the axle bearings.
			_box(img, c + Vector2(5, 5) , Vector2(12, 6), 7.0, Color(0.48, 0.33, 0.2))
			for k: int in 4:
				_line(img, c + Vector2(-1 + k * 3, -1 - k * 1.5), c + Vector2(-1 + k * 3, 4 - k * 1.5), Color(0.82, 0.72, 0.5), 1)
			_ellipse(img, c, Vector2(3, 3), C_IRON.lightened(0.2))
			_ellipse(img, c + depth, Vector2(2, 2), C_IRON)
			for side: float in [-1.0, 1.0]:
				_line(img, p + Vector2(side * 17, 1), c, C_BEAM, 4)
				_line(img, p + Vector2(side * 17 - 1, 0), c + Vector2(-1, 0), C_BEAM.lightened(0.25), 1)
			_line(img, p + Vector2(-10, -10), p + Vector2(10, -10), C_BEAM, 2)
		"gate_posts":
			for k: int in 2:
				var q := p + Vector2(-12 + k * 22, -6 + k * 11)
				_box(img, q, Vector2(5, 3), 22.0, C_BEAM)
		"lantern":
			_line(img, p, p - Vector2(0, 26), C_IRON, 1)
			_box(img, p - Vector2(0, 26), Vector2(4, 2), 5.0, Color(0.95, 0.8, 0.4))
		"crane":
			_line(img, p, p - Vector2(0, 30), C_BEAM, 2)
			_line(img, p - Vector2(0, 28), p + Vector2(-16, -24), C_BEAM, 2)
			_line(img, p + Vector2(-15, -24), p + Vector2(-15, -10), Color(0.75, 0.65, 0.45), 1)
			_box(img, p + Vector2(-15, -4), Vector2(7, 3), 5.0, C_STONE, "stone")
		"sheaves":
			for k: int in 3:
				var q := p + Vector2(k * 9 - 9, k * 2)
				for i: int in 5:
					_line(img, q + Vector2(i * 1.5 - 3, 0), q + Vector2(i * 2.0 - 4, -12), Color(0.9, 0.76, 0.35), 1)
				_line(img, q + Vector2(-3, -5), q + Vector2(3, -5), Color(0.6, 0.45, 0.2), 1)
		"cart_wheel":
			_ring(img, p - Vector2(0, 7), 6.0, C_BEAM)
			for k: int in 4:
				var a := k * PI / 4.0
				_line(img, p - Vector2(0, 7) - Vector2(cos(a), sin(a)) * 5.0, p - Vector2(0, 7) + Vector2(cos(a), sin(a)) * 5.0, C_BEAM, 1)
		"hop_poles":
			for k: int in 3:
				var q := p + Vector2(k * 7 - 7, k * 3 - 3)
				_line(img, q, q - Vector2(0, 28), C_BEAM, 1)
				for j: int in 7:
					_px(img, Vector2i(q + Vector2((j % 2) * 2 - 1, -4 - j * 3.5)), Color(0.35, 0.6, 0.25))
					_px(img, Vector2i(q + Vector2((j % 2) * 2, -5 - j * 3.5)), Color(0.55, 0.75, 0.35))
		"baskets":
			for k: int in 2:
				var q := p + Vector2(k * 10 - 5, k * 2)
				_box(img, q, Vector2(8, 4), 6.0, Color(0.68, 0.52, 0.3), "wicker")
				_ellipse(img, q - Vector2(0, 7), Vector2(4, 2), Color(0.55, 0.75, 0.35))
		"barrels":
			_barrel(img, p + Vector2(-5, 0))
			_barrel(img, p + Vector2(5, 2))
			_barrel(img, p + Vector2(0, -9))
		"barrel":
			_barrel(img, p)
		"kettle":
			_box(img, p, Vector2(14, 7), 6.0, Color(0.55, 0.32, 0.25), "brick")
			_ellipse(img, p - Vector2(0, 12), Vector2(7, 5), Color(0.75, 0.45, 0.25))
			_ellipse(img, p - Vector2(0, 15), Vector2(5, 2), Color(0.55, 0.3, 0.15))
		"oven":
			_ellipse(img, p - Vector2(0, 7), Vector2(10, 9), Color(0.68, 0.4, 0.3))
			_ellipse(img, p - Vector2(-1, 4), Vector2(4, 3), Color(0.15, 0.08, 0.05))
			_ellipse(img, p - Vector2(-1, 4), Vector2(2.5, 1.5), Color(0.95, 0.55, 0.2))
		"table":
			_box(img, p, Vector2(14, 6), 7.0, C_PLANK, "planks")
			_ellipse(img, p - Vector2(2, 10), Vector2(3, 1.5), Color(0.93, 0.88, 0.75))
		"sign_bread":
			_line(img, p, p + Vector2(0, -24), C_IRON, 1)
			_line(img, p + Vector2(0, -24), p + Vector2(8, -24), C_IRON, 1)
			_ellipse(img, p + Vector2(8, -19), Vector2(5, 4), Color(0.8, 0.55, 0.25))
		"sacks":
			for k: int in 2:
				var q := p + Vector2(k * 8 - 4, k * 2)
				_ellipse(img, q - Vector2(0, 5), Vector2(4, 5), Color(0.92, 0.9, 0.82))
				_line(img, q - Vector2(2, 10), q - Vector2(-2, 10), Color(0.7, 0.66, 0.55), 1)
		"nets":
			_line(img, p, p - Vector2(0, 22), C_BEAM, 1)
			_line(img, p + Vector2(14, 7), p + Vector2(14, -15), C_BEAM, 1)
			for i: int in 6:
				_line(img, p - Vector2(0, 20 - i * 3), p + Vector2(14, -13 + i * 3), Color(0.75, 0.72, 0.6), 1)
			for i: int in 4:
				_line(img, p + Vector2(i * 4 + 1, -20 + i * 2), p + Vector2(i * 4 + 1, -2 + i * 2), Color(0.75, 0.72, 0.6), 1)
		"tar_pit":
			# An earthen mound over the slow fire, smoke seeping out at the top, the tap at its foot.
			var mound := PackedVector2Array()
			for k: int in 20:
				var a := PI + k * PI / 19.0
				mound.append(p + Vector2(cos(a) * 20.0, sin(a) * 13.0 - 2.0))
			mound.append(p + Vector2(20, 2))
			mound.append(p + Vector2(-20, 2))
			_fill_shader(img, mound, func(x: int, y: int) -> Color:
				var c := Color(0.38, 0.3, 0.22).darkened(0.12 * _hash(x / 2, y / 2, 23))
				return _lit(c, LIGHT_SW if x < p.x else LIGHT_SE))
			_outline(img, mound, Color(0.2, 0.15, 0.1))
			for k: int in 5:
				_px(img, Vector2i(p + Vector2(-2 + k, -16 - k * 2)), Color(0.75, 0.75, 0.72, 0.8))
				_px(img, Vector2i(p + Vector2(-1 + k, -17 - k * 2)), Color(0.6, 0.6, 0.6, 0.7))
			_line(img, p + Vector2(8, -1), p + Vector2(14, 3), C_BEAM, 2)
			_ellipse(img, p + Vector2(16, 3), Vector2(3, 2), Color(0.08, 0.06, 0.05))
		"tar_barrels":
			for k: int in 2:
				var q := p + Vector2(k * 9 - 4, k * 2)
				_ellipse(img, q - Vector2(0, 5), Vector2(4, 5), Color(0.24, 0.17, 0.12))
				_line(img, q - Vector2(4, 7), q - Vector2(-4, 7), C_IRON, 1)
				_ellipse(img, q - Vector2(0, 9), Vector2(3, 1.5), Color(0.08, 0.06, 0.05))
		"stone_bollard":
			# A squat round stone post with an iron cap and a hawser looped over it.
			_ellipse(img, p - Vector2(0, 1), Vector2(10, 5), Color(0.34, 0.32, 0.3))
			for k: int in 16:
				var y := float(k)
				var c := _stone(int(p.x) + k % 3, int(p.y) + k, 7)
				_ellipse(img, p - Vector2(0, 2 + y), Vector2(7.5 - 0.08 * y, 3.6), _lit(c, 1.02 - 0.015 * y))
				_px(img, Vector2i(p + Vector2(-7.0 + 0.08 * y, -2 - y)), c.darkened(0.45))
				_px(img, Vector2i(p + Vector2(7.0 - 0.08 * y, -2 - y)), c.darkened(0.35))
			_ellipse(img, p - Vector2(0, 18), Vector2(8, 3.8), C_IRON)
			_ellipse(img, p - Vector2(0, 19.5), Vector2(6.5, 3), C_IRON.lightened(0.2))
			_ellipse(img, p - Vector2(1.5, 20.5), Vector2(2.5, 1.2), C_IRON.lightened(0.5))
			_line(img, p + Vector2(-7, -13), p + Vector2(7, -11), Color(0.72, 0.62, 0.42), 2)
			_line(img, p + Vector2(-7, -10), p + Vector2(7, -8), Color(0.62, 0.52, 0.34), 1)
			_line(img, p + Vector2(6, -10), p + Vector2(16, 5), Color(0.66, 0.56, 0.38), 2)
		"rope_coil":
			for k: int in 3:
				_ellipse(img, p - Vector2(0, 1 + k * 1.5), Vector2(5 - k, 2.4 - k * 0.4), Color(0.6, 0.5, 0.32).darkened(0.12 * k))
				_ellipse(img, p - Vector2(0, 1 + k * 1.5), Vector2(3.5 - k, 1.4 - k * 0.3), Color(0.74, 0.64, 0.44))
			_ellipse(img, p - Vector2(0, 5), Vector2(1.5, 0.6), Color(0.3, 0.24, 0.16))
		"lantern_pole":
			_line(img, p, p + Vector2(0, -34), C_BEAM, 2)
			_line(img, p + Vector2(0, -33), p + Vector2(6, -33), C_BEAM, 1)
			_line(img, p + Vector2(6, -33), p + Vector2(6, -30), C_IRON, 1)
			_box(img, p + Vector2(6, -23), Vector2(5, 2.5), 6.0, C_IRON)
			_ellipse(img, p + Vector2(6, -26), Vector2(1.5, 2), Color(1.0, 0.82, 0.4))
		"crate_stack":
			_crate(img, p + Vector2(-5, 0), Color(0.62, 0.46, 0.28))
			_crate(img, p + Vector2(5, 2), Color(0.58, 0.42, 0.26))
			_crate(img, p + Vector2(0, -7), Color(0.66, 0.5, 0.3))
			_line(img, p + Vector2(-3, -13), p + Vector2(3, -12), Color(0.72, 0.62, 0.42), 1)
		"hand_crane":
			# A small swing crane on a post: a hook, a block and a sack hanging.
			_box(img, p, Vector2(8, 4), 4.0, C_STONE, "stone")
			_line(img, p + Vector2(0, -4), p + Vector2(0, -40), C_BEAM, 2)
			_line(img, p + Vector2(0, -38), p + Vector2(-16, -34), C_BEAM, 2)
			_line(img, p + Vector2(0, -24), p + Vector2(-10, -35), C_BEAM, 1)
			_line(img, p + Vector2(-15, -34), p + Vector2(-15, -20), Color(0.72, 0.62, 0.42), 1)
			_ellipse(img, p + Vector2(-15, -16), Vector2(4, 4), Color(0.78, 0.68, 0.5))
			_line(img, p + Vector2(-17, -19), p + Vector2(-13, -19), Color(0.6, 0.5, 0.35), 1)
		"bollard":
			_box(img, p, Vector2(4, 2), 7.0, C_BEAM)
			_line(img, p + Vector2(-3, -5), p + Vector2(3, -5), Color(0.75, 0.68, 0.5), 1)
		"fish_rack":
			_line(img, p + Vector2(-8, 0), p + Vector2(-8, -12), C_BEAM, 1)
			_line(img, p + Vector2(8, 4), p + Vector2(8, -8), C_BEAM, 1)
			_line(img, p + Vector2(-8, -12), p + Vector2(8, -8), C_BEAM, 1)
			for i: int in 4:
				var q := p + Vector2(-6 + i * 4, -10 + i)
				_line(img, q, q + Vector2(0, 5), Color(0.7, 0.78, 0.82), 2)
		"boat":
			var hull := PackedVector2Array([p + Vector2(-14, -6), p + Vector2(10, 4), p + Vector2(14, 2), p + Vector2(8, 6), p + Vector2(-12, -2)])
			_fill(img, hull, C_PLANK)
			_outline(img, hull, C_BEAM)
			_line(img, p + Vector2(-12, -5), p + Vector2(11, 3), C_PLANK.lightened(0.2), 1)
		"bench":
			_line(img, p + Vector2(-8, -4), p + Vector2(6, 3), C_PLANK.lightened(0.1), 2)
			_line(img, p + Vector2(-7, -3), p + Vector2(-7, 1), C_BEAM, 1)
			_line(img, p + Vector2(5, 3), p + Vector2(5, 7), C_BEAM, 1)
		"garden_bed":
			# A vegetable patch behind a house: dark soil in rows, green tufts.
			var bed := PackedVector2Array([p + Vector2(-12, 0), p + Vector2(0, -6), p + Vector2(12, 0), p + Vector2(0, 6)])
			_fill_shader(img, bed, func(x: int, y: int) -> Color:
				return Color(0.36, 0.26, 0.17).darkened(0.18 * float((x + 2 * y) % 5 == 0)))
			for k: int in 7:
				var q := p + Vector2(-8 + k * 3, -1 + (k % 2) * 2)
				_px(img, Vector2i(q), Color(0.32, 0.58, 0.26))
				_px(img, Vector2i(q) + Vector2i(1, -1), Color(0.45, 0.68, 0.3))
		"flowers":
			for k: int in 6:
				var q := p + Vector2(k * 3 - 8, (k % 3) - 1)
				_px(img, Vector2i(q), Color(0.3, 0.55, 0.25))
				_px(img, Vector2i(q) + Vector2i(0, -1), [Color(0.9, 0.3, 0.3), Color(0.95, 0.85, 0.3), Color(0.75, 0.5, 0.85)][k % 3])
		"fence":
			for k: int in 5:
				var q := p + Vector2(k * 6, k * 3)
				_line(img, q, q - Vector2(0, 7), C_BEAM.lightened(0.15), 1)
			_line(img, p - Vector2(0, 5), p + Vector2(24, 7), C_PLANK.lightened(0.1), 1)
		"sapling_pots":
			for k: int in 3:
				var q := p + Vector2(k * 7 - 7, k * 2 - 2)
				_sapling(img, q - Vector2(0, 4), 8.0 + k)
				_box(img, q, Vector2(6, 3), 4.0, Color(0.68, 0.38, 0.26))
		"spade":
			_line(img, p + Vector2(0, -2), p + Vector2(2, -18), C_PLANK.lightened(0.1), 1)
			_line(img, p + Vector2(1, -18), p + Vector2(4, -18), C_PLANK.lightened(0.1), 1)
			_fill(img, PackedVector2Array([p + Vector2(-2, -4), p + Vector2(2, -4), p + Vector2(1, 2), p + Vector2(-1, 2)]), C_IRON.lightened(0.35))
		"trough":
			_box(img, p, Vector2(16, 6), 4.0, C_PLANK.darkened(0.1))
			_line(img, p + Vector2(-6, -4), p + Vector2(6, -2), Color(0.62, 0.55, 0.3), 1)
		"bucket":
			_ellipse(img, p - Vector2(0, 3), Vector2(3, 3.5), C_PLANK)
			_line(img, p - Vector2(3, 5), p - Vector2(-3, 5), C_IRON, 1)
			_line(img, p - Vector2(3, 6), p - Vector2(0, 9), C_IRON, 1)
		"butcher_block":
			_box(img, p, Vector2(10, 5), 7.0, C_LOG.darkened(0.05))
			_ellipse(img, p - Vector2(0, 8), Vector2(4, 1.6), Color(0.62, 0.28, 0.24))
			_line(img, p + Vector2(2, -9), p + Vector2(6, -14), C_BEAM.lightened(0.2), 1)
			_line(img, p + Vector2(5, -15), p + Vector2(8, -12), C_IRON.lightened(0.35), 2)
		"meat_hooks":
			_line(img, p + Vector2(-8, -26), p + Vector2(8, -22), C_BEAM, 1)
			for k: int in 3:
				var hook := p + Vector2(-5 + k * 5, -24 + k * 1.2)
				_line(img, hook, hook + Vector2(0, 3), C_IRON, 1)
				_ellipse(img, hook + Vector2(0, 7), Vector2(2.2, 3.5), Color(0.72, 0.3, 0.26).darkened(0.08 * k))
				_px(img, Vector2i(hook + Vector2(-1, 6)), Color(0.95, 0.86, 0.78))
		"hide_rack":
			for side: float in [-7.0, 7.0]:
				_line(img, p + Vector2(side, 0), p + Vector2(side, -18), C_BEAM, 1)
			_line(img, p + Vector2(-8, -17), p + Vector2(8, -17), C_BEAM, 1)
			var hide := PackedVector2Array([p + Vector2(-6, -16), p + Vector2(6, -16), p + Vector2(5, -5),
					p + Vector2(0, -3), p + Vector2(-5, -5)])
			_fill(img, hide, Color(0.55, 0.38, 0.24))
			_outline(img, hide, Color(0.35, 0.24, 0.15))
		"wagon":
			# A four-wheeled wagon box with its shafts down, wheels on the near side.
			_box(img, p - Vector2(0, 5), Vector2(22, 12), 7.0, C_PLANK, "planks")
			_line(img, p + Vector2(-11, -7), p + Vector2(-22, -1), C_BEAM, 1)
			_line(img, p + Vector2(-8, -5), p + Vector2(-19, 1), C_BEAM, 1)
			for k: int in 2:
				var c := p + Vector2(-5 + k * 11, -2 - k * 5)
				_ring(img, c, 4.0, C_BEAM.darkened(0.2))
				_line(img, c - Vector2(3, 0), c + Vector2(3, 0), C_BEAM, 1)
				_line(img, c - Vector2(0, 3), c + Vector2(0, 3), C_BEAM, 1)
		"hay":
			_ellipse(img, p - Vector2(0, 6), Vector2(9, 6), Color(0.86, 0.74, 0.38))
			_ellipse(img, p - Vector2(2, 10), Vector2(5, 3), Color(0.93, 0.82, 0.45))
			_line(img, p + Vector2(-6, -6), p + Vector2(6, -5), Color(0.7, 0.58, 0.28), 1)
		"spinning_wheel":
			_line(img, p + Vector2(-5, 0), p + Vector2(-2, -8), C_BEAM, 1)
			_line(img, p + Vector2(5, 0), p + Vector2(2, -8), C_BEAM, 1)
			_ring(img, p - Vector2(0, 12), 5.0, C_PLANK.lightened(0.15))
			for k: int in 3:
				var a := k * PI / 3.0
				_line(img, p - Vector2(0, 12) - Vector2(cos(a), sin(a)) * 4.0, p - Vector2(0, 12) + Vector2(cos(a), sin(a)) * 4.0, C_BEAM, 1)
			_ellipse(img, p + Vector2(7, -9), Vector2(2, 1.5), Color(0.95, 0.93, 0.86))
		"loom":
			for s: float in [-8.0, 8.0]:
				_line(img, p + Vector2(s, 2 if s > 0 else -2), p + Vector2(s, -20 + (2 if s > 0 else -2)), C_BEAM, 2)
			_line(img, p + Vector2(-8, -20), p + Vector2(8, -16), C_BEAM, 2)
			_line(img, p + Vector2(-8, -6), p + Vector2(8, -2), C_BEAM, 2)
			for k: int in 7:
				var x := -6.0 + k * 2.0
				_line(img, p + Vector2(x, -19 + k * 0.5), p + Vector2(x, -6 + k * 0.5), Color(0.92, 0.88, 0.78), 1)
			_fill(img, PackedVector2Array([p + Vector2(-7, -12), p + Vector2(7, -9), p + Vector2(7, -5), p + Vector2(-7, -8)]), Color(0.7, 0.3, 0.25))
		"cloth_bolts":
			var colours := [Color(0.75, 0.25, 0.22), Color(0.3, 0.42, 0.7), Color(0.9, 0.86, 0.72), Color(0.4, 0.6, 0.35)]
			for k: int in 4:
				# Two bolts at the bottom, two on top of them.
				var q := p + Vector2((k % 2) * 7 - 4, -2 - (k / 2) * 5 + (k % 2) * 2)
				_line(img, q + Vector2(-5, 2), q + Vector2(5, -2), colours[k], 3)
				_ellipse(img, q + Vector2(5, -2), Vector2(1.5, 1.5), Color(colours[k]).lightened(0.25))
		"sign_cloth", "sign_shirt", "sign_mug":
			_line(img, p, p + Vector2(0, -32), C_BEAM, 2)
			_line(img, p + Vector2(0, -32), p + Vector2(11, -32), C_IRON, 1)
			_line(img, p + Vector2(3, -32), p + Vector2(3, -28), C_IRON, 1)
			_line(img, p + Vector2(10, -32), p + Vector2(10, -28), C_IRON, 1)
			var board := PackedVector2Array([p + Vector2(1, -28), p + Vector2(12, -28), p + Vector2(12, -19), p + Vector2(1, -19)])
			_fill(img, board, C_PLANK.lightened(0.15))
			_outline(img, board, C_BEAM)
			var m := p + Vector2(6.5, -23.5)
			match prop:
				"sign_cloth":
					_line(img, m + Vector2(-3, 1), m + Vector2(3, -1), Color(0.75, 0.25, 0.22), 3)
				"sign_shirt":
					_fill(img, PackedVector2Array([m + Vector2(-4, -3), m + Vector2(4, -3), m + Vector2(2, 3), m + Vector2(-2, 3)]), Color(0.3, 0.42, 0.7))
					_line(img, m + Vector2(-4, -3), m + Vector2(-4, 0), Color(0.3, 0.42, 0.7), 1)
					_line(img, m + Vector2(4, -3), m + Vector2(4, 0), Color(0.3, 0.42, 0.7), 1)
				"sign_mug":
					_fill(img, PackedVector2Array([m + Vector2(-3, -3), m + Vector2(2, -3), m + Vector2(2, 3), m + Vector2(-3, 3)]), Color(0.85, 0.7, 0.3))
					_line(img, m + Vector2(-3, -3), m + Vector2(2, -3), Color(0.97, 0.95, 0.88), 1)
					_ring(img, m + Vector2(3.5, 0), 1.8, Color(0.85, 0.7, 0.3))
		"cutting_table":
			_box(img, p, Vector2(16, 7), 7.0, C_PLANK, "planks")
			_fill(img, PackedVector2Array([p + Vector2(-6, -9), p + Vector2(0, -12), p + Vector2(6, -9), p + Vector2(0, -7)]), Color(0.3, 0.42, 0.7))
			_line(img, p + Vector2(2, -10), p + Vector2(5, -12), C_IRON.lightened(0.4), 1)
		"clothes_line":
			_line(img, p + Vector2(-8, 4), p + Vector2(-8, -20), C_BEAM, 1)
			_line(img, p + Vector2(8, -4), p + Vector2(8, -28), C_BEAM, 1)
			_line(img, p + Vector2(-8, -19), p + Vector2(8, -27), Color(0.85, 0.82, 0.72), 1)
			var cols := [Color(0.75, 0.25, 0.22), Color(0.92, 0.9, 0.82), Color(0.4, 0.55, 0.3)]
			for k: int in 3:
				var q := p + Vector2(-5 + k * 5, -19 - k * 2.5)
				_fill(img, PackedVector2Array([q + Vector2(-2, -1), q + Vector2(2, -2), q + Vector2(2, 5), q + Vector2(-2, 6)]), cols[k])
		"skeps":
			_line(img, p + Vector2(-11, -2), p + Vector2(9, 4), C_PLANK, 2)
			_line(img, p + Vector2(-10, -1), p + Vector2(-10, 3), C_BEAM, 1)
			_line(img, p + Vector2(8, 5), p + Vector2(8, 9), C_BEAM, 1)
			for k: int in 3:
				var q := p + Vector2(-7 + k * 7, -3 + k * 2)
				_ellipse(img, q - Vector2(0, 5), Vector2(4, 5), Color(0.85, 0.68, 0.32))
				for b: int in 3:
					_line(img, q + Vector2(-4, -2 - b * 3), q + Vector2(4, -2 - b * 3), Color(0.65, 0.48, 0.2), 1)
				_px(img, Vector2i(q + Vector2(0, -1)), Color(0.15, 0.1, 0.05))
				_px(img, Vector2i(q + Vector2(3, -11)), Color(0.95, 0.8, 0.2))
		"honey_pots":
			for k: int in 3:
				var q := p + Vector2(k * 5 - 5, k * 1.5)
				_ellipse(img, q - Vector2(0, 3), Vector2(2.5, 3), Color(0.7, 0.42, 0.28))
				_ellipse(img, q - Vector2(0, 6), Vector2(1.8, 0.8), Color(0.95, 0.72, 0.2))
		"mead_vat":
			_ellipse(img, p - Vector2(0, 6), Vector2(9, 7), Color(0.55, 0.36, 0.2))
			_line(img, p + Vector2(-9, -9), p + Vector2(9, -9), C_IRON, 1)
			_line(img, p + Vector2(-9, -3), p + Vector2(9, -3), C_IRON, 1)
			_ellipse(img, p - Vector2(0, 12), Vector2(8, 3), Color(0.66, 0.46, 0.28))
			_ellipse(img, p - Vector2(0, 12), Vector2(6, 2), Color(0.88, 0.66, 0.22))
		"cask_rack":
			_line(img, p + Vector2(-10, -1), p + Vector2(10, 3), C_BEAM, 2)
			for k: int in 2:
				var q := p + Vector2(k * 9 - 5, k * 2)
				_ellipse(img, q - Vector2(0, 7), Vector2(5, 5), Color(0.55, 0.36, 0.2))
				_ellipse(img, q - Vector2(-1, 7), Vector2(2.5, 3), Color(0.66, 0.46, 0.28))
				_px(img, Vector2i(q - Vector2(-1, 7)), Color(0.9, 0.7, 0.25))
			_barrel(img, p + Vector2(0, -8))
		"clay_pit":
			var pit := PackedVector2Array()
			for k: int in 16:
				var a := k * TAU / 16.0
				pit.append(p + Vector2(cos(a) * 17.0, sin(a) * 8.5) * (0.9 + 0.12 * _hash(k, 3, 7)))
			_fill_shader(img, pit, func(x: int, y: int) -> Color:
				var d := Vector2((x - p.x) / 17.0, (y - p.y) / 8.5)
				if d.length() < 0.35:
					return Color(0.3, 0.42, 0.5).lightened(0.12 * float(_hash(x, y, 9) > 0.8))
				if d.y < -0.2:
					return Color(0.42, 0.3, 0.22).darkened(0.1 * _hash(x / 2, y, 8))
				return Color(0.62, 0.48, 0.4).darkened(0.12 * _hash(x / 2, y / 2, 8)))
			_outline(img, pit, Color(0.35, 0.26, 0.18))
			for k: int in 4:
				_line(img, p + Vector2(-12 + k * 6, -6 + absf(k - 1.5)), p + Vector2(-10 + k * 6, -4 + absf(k - 1.5)), Color(0.5, 0.36, 0.28), 1)
		"clay_mound":
			_ellipse(img, p - Vector2(0, 4), Vector2(8, 5), Color(0.66, 0.5, 0.42))
			_ellipse(img, p - Vector2(1, 7), Vector2(5, 3), Color(0.72, 0.56, 0.46))
			_px(img, Vector2i(p + Vector2(-3, -6)), Color(0.8, 0.66, 0.55))
		"kiln":
			_box(img, p, Vector2(22, 11), 14.0, Color(0.68, 0.34, 0.24), "brick")
			_ellipse(img, p - Vector2(0, 19), Vector2(10, 6), Color(0.66, 0.33, 0.24))
			_ellipse(img, p + Vector2(-5, -5), Vector2(3, 3.5), Color(0.15, 0.08, 0.05))
			_ellipse(img, p + Vector2(-5, -4), Vector2(2, 2), Color(0.98, 0.6, 0.2))
			_box(img, p - Vector2(-2, 22), Vector2(6, 3), 16.0, Color(0.6, 0.3, 0.22), "brick")
		"mould_table":
			_box(img, p, Vector2(14, 6), 7.0, C_PLANK, "planks")
			for k: int in 3:
				_box(img, p + Vector2(-4 + k * 4, -8 + k), Vector2(3, 1.5), 1.5, Color(0.72, 0.56, 0.46))
		"brick_stack":
			_box(img, p + Vector2(-6, 0), Vector2(12, 6), 9.0, Color(0.74, 0.36, 0.25), "brick")
			_box(img, p + Vector2(6, 1), Vector2(12, 6), 6.0, Color(0.7, 0.34, 0.24), "brick")
		"bar_counter":
			_box(img, p, Vector2(16, 8), 9.0, C_PLANK.darkened(0.1), "planks")
			_barrel(img, p + Vector2(-2, -9))
			_ellipse(img, p + Vector2(5, -11), Vector2(1.5, 2), Color(0.85, 0.7, 0.3))
		"tavern_table":
			# Bench behind, table, bench in front; two mugs on the table.
			_box(img, p + Vector2(4, -5), Vector2(14, 4), 4.0, C_PLANK.darkened(0.1))
			_box(img, p, Vector2(16, 7), 8.0, C_PLANK.lightened(0.05), "planks")
			_ellipse(img, p + Vector2(-2, -11), Vector2(1.5, 2), Color(0.85, 0.7, 0.3))
			_px(img, Vector2i(p + Vector2(-2, -13)), Color(0.97, 0.95, 0.88))
			_ellipse(img, p + Vector2(3, -12), Vector2(1.5, 2), Color(0.85, 0.7, 0.3))
			_px(img, Vector2i(p + Vector2(3, -14)), Color(0.97, 0.95, 0.88))
			_box(img, p + Vector2(-5, 5), Vector2(14, 4), 4.0, C_PLANK.darkened(0.1))
		"lantern":
			_line(img, p, p + Vector2(0, -26), C_IRON, 1)
			_line(img, p + Vector2(0, -26), p + Vector2(4, -26), C_IRON, 1)
			_fill(img, PackedVector2Array([p + Vector2(2, -25), p + Vector2(6, -25), p + Vector2(6, -20), p + Vector2(2, -20)]), Color(0.98, 0.82, 0.4))
			_outline(img, PackedVector2Array([p + Vector2(2, -25), p + Vector2(6, -25), p + Vector2(6, -20), p + Vector2(2, -20)]), C_IRON)
		"banner":
			_line(img, p, p + Vector2(0, -30), C_IRON, 1)
			_fill(img, PackedVector2Array([p + Vector2(1, -30), p + Vector2(10, -28), p + Vector2(1, -22)]), Color(0.75, 0.15, 0.2))
		"graves":
			for k: int in 3:
				var q := p + Vector2(k * 9, k * 4)
				_line(img, q, q - Vector2(0, 7), C_STONE.darkened(0.2), 2)
				_line(img, q - Vector2(2, 5), q - Vector2(-2, 5), C_STONE.darkened(0.2), 1)


# --- Helpers ------------------------------------------------------------------------------

func _project_u(p: Vector2, eu: Vector2) -> float:
	# Walls are vertical, so screen x alone tells how far along the wall a pixel is.
	return clampf(p.x / eu.x, 0.0, 1.0) if absf(eu.x) > 0.01 else 0.0


func _wall_material(material: String, u: float, v: float, h: float, length: float, tint: Color) -> Color:
	var iu := int(u)
	var iv := int(v)
	match material:
		"timber", "timber_stone":
			var plinth := 18.0 if material == "timber_stone" and h > 30.0 else 4.0
			if v < plinth:
				return _stone(iu, iv, 3)
			if v < plinth + 2.0 or v > h - 2.0 or (absf(v - (plinth + h) * 0.5) < 1.0):
				return C_BEAM
			var panel := 14.0
			var pu := fposmod(u, panel)
			if pu < 2.0 or u > length - 2.0:
				return C_BEAM
			# Diagonal braces in alternate panels.
			var lower := v < (plinth + h) * 0.5
			var t := (v - plinth) / maxf((h - plinth) * 0.5, 1.0)
			if lower and int(u / panel) % 2 == 0 and absf(pu - t * panel) < 1.2:
				return C_BEAM
			return _plaster(iu, iv, C_PLASTER * tint)
		"stone":
			return _stone(iu, iv, 5)
		"stone_plaster":
			if v < 6.0:
				return _stone(iu, iv, 5)
			if fposmod(u, length) < 2.0 or u > length - 2.0:
				return _stone(iu, iv, 9).lightened(0.05)
			return _plaster(iu, iv, Color(0.9, 0.87, 0.8) * tint)
		"patrician":
			# Ashlar ground floor with a cornice, tinted plaster above with string courses,
			# stone quoins at the corners and a moulded eave.
			var ground := h * 0.34
			if v < ground:
				var row := iv / 5
				var shift := (row % 2) * 6
				if iv % 5 == 0 or (iu + shift) % 12 == 0:
					return C_MORTAR.lightened(0.15)
				return Color(0.78, 0.74, 0.66).darkened(0.1 * _hash((iu + shift) / 12, row, 91))
			if v < ground + 2.5:
				return Color(0.86, 0.83, 0.76) if v > ground + 1.0 else Color(0.6, 0.57, 0.52)
			if v > h - 3.0:
				return Color(0.86, 0.83, 0.76) if v < h - 1.0 else Color(0.6, 0.57, 0.52)
			if absf(v - h * 0.66) < 1.0:
				return (C_PLASTER * tint).darkened(0.3)
			if u < 4.0 or u > length - 4.0:
				return Color(0.84, 0.8, 0.72) if int(v / 4.0) % 2 == 0 else Color(0.74, 0.7, 0.63)
			return _plaster(iu, iv, Color(0.94, 0.92, 0.86) * tint)
		"plaster", "plaster_stone":
			if v < 5.0:
				return _stone(iu, iv, 5)
			if material == "plaster_stone" and (absf(v - h * 0.55) < 1.0 or v > h - 2.0):
				return (C_PLASTER * tint).darkened(0.25)
			if u < 2.0 or u > length - 2.0:
				return _stone(iu, iv, 9).lightened(0.08)
			return _plaster(iu, iv, Color(0.94, 0.92, 0.86) * tint)
		"logs":
			if v < 4.0:
				return _stone(iu, iv, 3)
			var lv := fposmod(v - 4.0, 5.0)
			var log_col := C_LOG.darkened(0.12 * _hash(int((v - 4.0) / 5.0), iu / 9, 11))
			if lv < 1.0:
				return C_LOG.darkened(0.45)
			if lv > 3.6:
				return log_col.lightened(0.12)
			if u < 3.0 or u > length - 3.0:
				return Color(0.72, 0.56, 0.36) if lv > 1.5 and lv < 3.5 else log_col
			return log_col
		"planks":
			if v < 4.0:
				return _stone(iu, iv, 3)
			var pu := fposmod(u, 5.0)
			var board := C_PLANK.darkened(0.14 * _hash(int(u / 5.0), 0, 13))
			if pu < 1.0:
				return C_PLANK.darkened(0.45)
			if v > h - 2.0:
				return C_BEAM
			return board.darkened(0.05 * _hash(iu, iv / 3, 17))
	return _plaster(iu, iv, C_PLASTER)


func _opening(u: float, v: float, w: float, hgt: float, kind: String, _shutters: Color) -> Color:
	if kind == "door":
		if u < 1.0 or u >= w - 1.0 or v >= hgt - 1.0:
			return C_BEAM
		if v < 1.0:
			return C_STONE.lightened(0.1)
		var board := C_DOOR.darkened(0.15 * float(int(u) % 3 == 0))
		if absf(v - hgt * 0.35) < 0.6 or absf(v - hgt * 0.75) < 0.6:
			return C_IRON
		if int(u) == int(w) - 3 and absf(v - hgt * 0.5) < 1.0:
			return Color(0.8, 0.7, 0.35)
		return board
	# Window: frame, cross bars, glass with a highlight, light sill.
	if v < 1.0:
		return C_PLASTER.lightened(0.05)
	if u < 1.0 or u >= w - 1.0 or v >= hgt - 1.0:
		return C_BEAM
	if absf(u - w * 0.5) < 0.6 or absf(v - hgt * 0.5) < 0.6:
		return C_BEAM.lightened(0.1)
	if u < 3.0 and v > hgt * 0.6:
		return C_GLASS.lightened(0.35)
	return C_GLASS


## Fills [param poly] with a roof material in face coordinates: u along [param eu] (eave),
## v up [param ev] (towards the ridge), both in pixels.
func _face_2d(img: Image, poly: PackedVector2Array, origin: Vector2, eu: Vector2, ev: Vector2,
		material: String, light: float) -> void:
	var det := eu.x * ev.y - eu.y * ev.x
	if absf(det) < 0.001:
		return
	var lu := eu.length()
	var lv := ev.length()
	_fill_shader(img, poly, func(x: int, y: int) -> Color:
		var p := Vector2(x + 0.5, y + 0.5) - origin
		var s := (p.x * ev.y - p.y * ev.x) / det
		var t := (eu.x * p.y - eu.y * p.x) / det
		return _lit(_roof_material(material, s * lu, t * lv, lv), light))
	var edge := _lit(_roof_material(material, 3.0, 3.0, lv), light).darkened(0.5)
	_outline(img, poly, edge)


func _roof_material(material: String, u: float, v: float, length: float) -> Color:
	var iu := int(u)
	var iv := int(v)
	var near_eave := v < 2.0
	var near_ridge := v > length - 2.5
	match material:
		"thatch":
			if near_ridge:
				return C_THATCH.darkened(0.25)
			var layer := fposmod(v, 6.0)
			var streak := _hash(iu, int(v / 6.0), 3)
			var col := C_THATCH.darkened(0.18 * streak).lightened(0.1 * _hash(iu / 2, iv, 4))
			if layer < 1.0:
				col = col.darkened(0.22)
			if near_eave:
				col = col.darkened(0.3)
			return col
		"shingle", "tile", "slate":
			var base: Color = {"shingle": C_SHINGLE, "tile": C_TILE, "slate": C_SLATE}[material]
			var rows := 4.0 if material != "slate" else 3.0
			var cols := 6.0 if material != "tile" else 4.0
			var row := int(v / rows)
			var cu := u + (cols * 0.5 if row % 2 == 1 else 0.0)
			var pu := fposmod(cu, cols)
			var pv := fposmod(v, rows)
			var col := base.darkened(0.14 * _hash(int(cu / cols), row, 5))
			if material == "tile" and pu > cols - 1.5:
				col = col.lightened(0.18)
			if pv < 1.0:
				col = col.darkened(0.3)
			elif pu < 0.8 and material != "tile":
				col = col.darkened(0.2)
			if near_ridge:
				col = base.darkened(0.35)
			if near_eave:
				col = col.darkened(0.25)
			return col
	return C_THATCH


func _gable(img: Image, pivot: Vector2i, a: Vector3, b: Vector3, apex: Vector3, material: String,
		tint: Color, light: float) -> void:
	var sa := _scr(pivot, a)
	var sb := _scr(pivot, b)
	var sp := _scr(pivot, apex)
	var poly := PackedVector2Array([sa, sb, sp])
	var eu := sb - sa
	var length := eu.length()
	var gable_material := material if material in ["logs", "planks", "stone"] else "gable_" + material
	_fill_shader(img, poly, func(x: int, y: int) -> Color:
		var p := Vector2(x + 0.5, y + 0.5) - sa
		var u := clampf(p.x / eu.x, 0.0, 1.0) * length if absf(eu.x) > 0.01 else 0.0
		var v := -(p.y - eu.y * (u / maxf(length, 0.01)))
		if material == "patrician":
			# Plastered gable with a small round window.
			var mid_p := length * 0.5
			if Vector2(u - mid_p, v - 9.0).length() < 2.6:
				return _lit(C_GLASS, light)
			if Vector2(u - mid_p, v - 9.0).length() < 3.8:
				return _lit(Color(0.84, 0.8, 0.72), light)
			return _lit(_plaster(int(u), int(v), Color(0.94, 0.92, 0.86) * tint), light)
		if gable_material.begins_with("gable_"):
			# Timber gable: vertical boards, a small round window in the middle.
			var mid := length * 0.5
			if Vector2(u - mid, v - 10.0).length() < 3.0:
				return _lit(C_GLASS, light)
			if Vector2(u - mid, v - 10.0).length() < 4.2:
				return _lit(C_BEAM, light)
			if fposmod(u, 5.0) < 1.0:
				return _lit(C_PLANK.darkened(0.45), light)
			return _lit(C_PLANK.lightened(0.05).darkened(0.12 * _hash(int(u / 5.0), 1, 21)), light)
		return _lit(_wall_material(gable_material, u, v + 20.0, 200.0, length, tint), light))
	_outline(img, poly, C_BEAM.darkened(0.3))


## A small box seen from the front corner at [param foot]: [param size] = screen width and
## half-depth, [param height] in px.
func _box(img: Image, foot: Vector2, size: Vector2, height: float, colour: Color, material: String = "") -> void:
	var w := size.x * 0.5
	var d := size.y * 0.5
	var left := PackedVector2Array([foot + Vector2(-w, -d), foot, foot - Vector2(0, height), foot + Vector2(-w, -d - height)])
	var right := PackedVector2Array([foot, foot + Vector2(w, -d), foot + Vector2(w, -d - height), foot - Vector2(0, height)])
	var top := PackedVector2Array([foot + Vector2(-w, -d - height), foot - Vector2(0, height), foot + Vector2(w, -d - height), foot + Vector2(0, -2 * d - height)])
	for part: Array in [[left, LIGHT_SW], [right, LIGHT_SE], [top, 1.15]]:
		var poly: PackedVector2Array = part[0]
		var light: float = part[1]
		_fill_shader(img, poly, func(x: int, y: int) -> Color:
			var col := colour
			match material:
				"brick":
					var row := y / 2
					col = colour.darkened(0.25) if y % 2 == 0 or (x + row * 2) % 5 == 0 else colour.darkened(0.08 * _hash(x / 5, row, 31))
				"stone":
					col = _stone(x, y, 41)
				"planks":
					col = C_PLANK.darkened(0.3) if x % 4 == 0 else C_PLANK
				"wicker":
					col = colour.darkened(0.2) if (x + y) % 3 == 0 else colour
			return _lit(col, light))
		_outline(img, poly, colour.darkened(0.55))


func _barrel(img: Image, foot: Vector2) -> void:
	_ellipse(img, foot - Vector2(0, 5), Vector2(5, 6), Color(0.55, 0.36, 0.2))
	_line(img, foot - Vector2(5, 8), foot - Vector2(-5, 8), C_IRON, 1)
	_line(img, foot - Vector2(5, 2), foot - Vector2(-5, 2), C_IRON, 1)
	_ellipse(img, foot - Vector2(0, 10), Vector2(4, 1.5), Color(0.66, 0.46, 0.28))


func _crate(img: Image, foot: Vector2, colour: Color) -> void:
	_box(img, foot, Vector2(10, 5), 7.0, colour, "planks")


## A brown horse standing sideways (stable paddock, M4b-3).
func _horse(img: Image, p: Vector2) -> void:
	var coat := Color(0.48, 0.3, 0.18)
	for x: float in [-6.0, -3.0, 4.0, 7.0]:
		_line(img, p + Vector2(x, -7), p + Vector2(x, 0), coat.darkened(0.25), 2)
	_ellipse(img, p + Vector2(0, -11), Vector2(10, 5), coat)
	_line(img, p + Vector2(8, -13), p + Vector2(12, -20), coat, 3)
	_ellipse(img, p + Vector2(13, -20), Vector2(3.5, 2.5), coat.lightened(0.05))
	_line(img, p + Vector2(7, -15), p + Vector2(10, -21), Color(0.2, 0.14, 0.1), 1)
	_line(img, p + Vector2(-10, -12), p + Vector2(-13, -5), Color(0.2, 0.14, 0.1), 2)


## A circle outline of [param width] px drawn as short lines (a wheel rim).
func _circle(img: Image, centre: Vector2, radius: float, colour: Color, width: int) -> void:
	var steps := maxi(ceili(radius * 1.5), 12)
	for k: int in steps:
		var a := TAU * k / steps
		var b := TAU * (k + 1) / steps
		_line(img, centre + Vector2(cos(a), sin(a)) * radius, centre + Vector2(cos(b), sin(b)) * radius, colour, width)


func _ring(img: Image, centre: Vector2, radius: float, colour: Color) -> void:
	for k: int in 32:
		var a := k * TAU / 32.0
		_px(img, Vector2i(centre + Vector2(cos(a), sin(a)) * radius), colour)


func _stone(x: int, y: int, salt: int) -> Color:
	var row := y / 4
	var shift := (row % 2) * 5
	var block := (x + shift) / 9
	if y % 4 == 0 or (x + shift) % 9 == 0:
		return C_MORTAR
	return C_STONE.darkened(0.16 * _hash(block, row, salt)).lightened(0.05 * _hash(x, y, salt + 1))


func _plaster(x: int, y: int, colour: Color) -> Color:
	var n := _hash(x / 2, y / 2, 51)
	return colour.darkened(0.05 * n) if n > 0.25 else colour.darkened(0.09)


func _lit(colour: Color, light: float) -> Color:
	return Color(minf(colour.r * light, 1.0), minf(colour.g * light, 1.0), minf(colour.b * light, 1.0), colour.a)


func _hash(x: int, y: int, salt: int) -> float:
	var n := (x * 374761393 + y * 668265263 + salt * 1442695041) & 0xffffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0xffffffff
	return float((n ^ (n >> 16)) & 0xffff) / 65535.0


func _canvas(height: float, eaves: int) -> Dictionary:
	var fp := _footprint
	var size := Vector2i(32 * (fp.x + fp.y) + eaves * 2, 16 * (fp.x + fp.y) + int(height) + 6)
	var img := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	return {"img": img, "pivot": Vector2i(32 * fp.x + eaves, size.y - 2)}


func _scr(pivot: Vector2i, p: Vector3) -> Vector2:
	return Vector2(pivot) + IsoMath.grid_to_screen(Vector2(p.x, p.y) - Vector2(_footprint)) - Vector2(0, p.z)


func _fill(img: Image, poly: PackedVector2Array, colour: Color) -> void:
	_fill_shader(img, poly, func(_x: int, _y: int) -> Color: return colour)


func _fill_shader(img: Image, poly: PackedVector2Array, shader: Callable) -> void:
	var bounds := Rect2(poly[0], Vector2.ZERO)
	for p: Vector2 in poly:
		bounds = bounds.expand(p)
	var area := Rect2i(bounds).grow(1).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), poly):
				var c: Color = shader.call(x, y)
				if c.a > 0.0:
					img.set_pixel(x, y, c)


func _outline(img: Image, poly: PackedVector2Array, colour: Color) -> void:
	for i: int in poly.size():
		_line(img, poly[i], poly[(i + 1) % poly.size()], colour, 1)


func _line(img: Image, a: Vector2, b: Vector2, colour: Color, width: int) -> void:
	var steps := maxi(1, int(ceil(a.distance_to(b))))
	for s: int in steps + 1:
		var p := a.lerp(b, float(s) / steps)
		for dx: int in width:
			for dy: int in width:
				_px(img, Vector2i(int(p.x) + dx - width / 2, int(p.y) + dy - width / 2), colour)


func _ellipse(img: Image, centre: Vector2, radius: Vector2, colour: Color) -> void:
	for y: int in range(int(centre.y - radius.y) - 1, int(centre.y + radius.y) + 2):
		for x: int in range(int(centre.x - radius.x) - 1, int(centre.x + radius.x) + 2):
			var d := Vector2((x + 0.5 - centre.x) / radius.x, (y + 0.5 - centre.y) / radius.y).length()
			if d <= 1.0:
				# Rounded shading: lighter towards the top left.
				var shade := clampf(((x + 0.5 - centre.x) / radius.x + (y + 0.5 - centre.y) / radius.y) * 0.12, -0.12, 0.12)
				_px(img, Vector2i(x, y), colour.darkened(shade) if shade > 0.0 else colour.lightened(-shade))


func _px(img: Image, p: Vector2i, colour: Color) -> void:
	if Rect2i(Vector2i.ZERO, img.get_size()).has_point(p):
		img.set_pixelv(p, colour)


## Selective outline (ART_SPEC §1): opaque pixels touching transparency get a dark version
## of their own colour, so the silhouette reads on any ground.
func _finish(img: Image) -> void:
	var size := img.get_size()
	var edge: Array[Vector2i] = []
	for y: int in size.y:
		for x: int in size.x:
			if img.get_pixel(x, y).a == 0.0:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q := Vector2i(x, y) + d
				if not Rect2i(Vector2i.ZERO, size).has_point(q) or img.get_pixelv(q).a == 0.0:
					edge.append(Vector2i(x, y))
					break
	for p: Vector2i in edge:
		var c := img.get_pixelv(p)
		img.set_pixelv(p, Color(c.r * 0.35, c.g * 0.3, c.b * 0.28, 1.0))


func _write(id: String, name: String, art: Dictionary) -> void:
	var img: Image = art["img"]
	var pivot: Vector2i = art["pivot"]
	var dir := OUT.path_join("buildings/%s" % id)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var err := img.save_png(dir.path_join(name + ".png"))
	if err != OK:
		push_error("Cannot save %s/%s (%s)" % [dir, name, error_string(err)])
	var entrance := _entrance if not name.begins_with("construction") else Vector2i(_footprint.x / 2, _footprint.y - 1)
	var meta := {"footprint": [_footprint.x, _footprint.y], "entrance": [entrance.x, entrance.y],
			"pivot": [pivot.x, pivot.y]}
	var file := FileAccess.open(dir.path_join(name + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(meta, "\t"))


func _stall(img: Image, pivot: Vector2i, at: Vector2, colours: Array) -> void:
	var s := Vector2(pivot) + IsoMath.grid_to_screen(at)
	# Counter.
	_box(img, s + Vector2(0, -1), Vector2(26, 13), 8.0, C_PLANK)
	for g: int in 4:
		_ellipse(img, s + Vector2(-8 + g * 5, -10 - (g % 2)), Vector2(2.5, 2), [Color(0.85, 0.6, 0.25),
				Color(0.75, 0.2, 0.15), Color(0.55, 0.7, 0.3), Color(0.9, 0.8, 0.4)][g])
	# Posts and awning.
	for side: float in [-13.0, 13.0]:
		_line(img, s + Vector2(side, -4), s + Vector2(side, -34), C_BEAM, 2)
	var awning := PackedVector2Array([s + Vector2(-16, -32), s + Vector2(0, -40), s + Vector2(16, -32), s + Vector2(0, -24)])
	_fill_shader(img, awning, func(x: int, y: int) -> Color:
		return colours[((x - y * 2) / 4) % 2 if (x - y * 2) >= 0 else 1])
	_outline(img, awning, Color(colours[0]).darkened(0.5))


func _well(id: String) -> void:
	var c := _canvas(64.0, 8)
	var img: Image = c["img"]
	var pivot: Vector2i = c["pivot"]
	var centre := Vector2(pivot) + IsoMath.grid_to_screen(Vector2(-0.5, -0.5))
	# Round stone curb: stacked rings, darker at the back.
	for ring: int in 6:
		var y := centre.y - ring * 3.0
		_ellipse(img, Vector2(centre.x, y), Vector2(15, 7.5), C_STONE.darkened(0.12 * float(ring % 2)))
	for k: int in 14:
		var a := k * TAU / 14.0
		var p := Vector2(centre.x + cos(a) * 15.0, centre.y - 15.0 + sin(a) * 7.5)
		if sin(a) > -0.2:
			_px(img, Vector2i(p), C_MORTAR)
	_ellipse(img, Vector2(centre.x, centre.y - 18), Vector2(15, 7.5), C_STONE.lightened(0.1))
	_ellipse(img, Vector2(centre.x, centre.y - 18), Vector2(11, 5), Color(0.12, 0.2, 0.3))
	_ellipse(img, Vector2(centre.x - 3, centre.y - 19), Vector2(3, 1), Color(0.35, 0.5, 0.65))
	# Posts, crossbar with rope and bucket, small shingle roof.
	for side: float in [-13.0, 13.0]:
		_line(img, Vector2(centre.x + side, centre.y - 14), Vector2(centre.x + side, centre.y - 46), C_BEAM, 3)
	_line(img, Vector2(centre.x - 13, centre.y - 40), Vector2(centre.x + 13, centre.y - 40), C_BEAM.lightened(0.15), 2)
	_line(img, Vector2(centre.x + 2, centre.y - 40), Vector2(centre.x + 2, centre.y - 28), Color(0.75, 0.65, 0.45), 1)
	_fill(img, PackedVector2Array([Vector2(centre.x - 1, centre.y - 28), Vector2(centre.x + 5, centre.y - 28),
			Vector2(centre.x + 4, centre.y - 22), Vector2(centre.x, centre.y - 22)]), C_PLANK)
	var roof := PackedVector2Array([Vector2(centre.x - 20, centre.y - 42), Vector2(centre.x, centre.y - 58),
			Vector2(centre.x + 20, centre.y - 42), Vector2(centre.x, centre.y - 36)])
	_face_2d(img, roof, Vector2(centre.x - 20, centre.y - 42), Vector2(40, 0), Vector2(0, -16), "shingle", 1.0)
	_finish(img)
	_write(id, "base", {"img": img, "pivot": pivot})
