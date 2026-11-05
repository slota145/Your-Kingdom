extends SceneTree
## Generates placeholder art into res://assets/_placeholder in the same layout as the final
## art (ART_SPEC §2, §9.1). Run:
##   "$GODOT" --headless --path . -s res://tools/generate_placeholders.gd
##
## Characters: sheets with rows = screen directions (S, SE, E, NE, N, NW, W, SW), columns =
## frames, 64x64 per frame, feet at (32, 58). Carry animations get an .anchors.png with one
## red pixel per frame (where the carried good goes) and a blue pixel when the good is
## drawn behind the body. "peasant" has all 8 directions drawn; "peasant_mirror" has only
## the first 5 rows and relies on mirroring, so the two can be compared side by side.

const OUT := "res://assets/_placeholder"
const TILE := Vector2i(64, 32)
const FRAME := Vector2i(64, 64)
const FOOT := Vector2i(32, 58)
const CHARACTER_HEIGHT := 42

const OUTLINE := Color(0.13, 0.09, 0.07)
const SKIN := Color(0.93, 0.76, 0.6)
const SHIRT := Color(0.62, 0.42, 0.22)
const TROUSERS := Color(0.32, 0.27, 0.22)
const HAT := Color(0.85, 0.72, 0.35)
const TOOL := Color(0.45, 0.3, 0.15)
const TOOL_HEAD := Color(0.75, 0.78, 0.8)
const ANCHOR := Color(1, 0, 0)
const BEHIND := Color(0, 0, 1)

## Carry category -> where the good sits: base height above the feet, forward and
## right-hand offsets (unsquashed px), and whether it hides behind the body when the
## person faces the camera (true) or away (false).
const CARRY := {
	"sack": {"height": 26.0, "forward": -1.0, "right": 8.0, "behind_when_facing_camera": false},
	"basket": {"height": 20.0, "forward": 5.0, "right": 5.0, "behind_when_facing_camera": false},
	"bundle": {"height": 30.0, "forward": -6.0, "right": 0.0, "behind_when_facing_camera": true},
	"log": {"height": 30.0, "forward": 0.0, "right": 6.0, "behind_when_facing_camera": false},
	"barrel": {"height": 20.0, "forward": 6.0, "right": 2.0, "behind_when_facing_camera": false},
	"stone": {"height": 28.0, "forward": -1.0, "right": 7.0, "behind_when_facing_camera": false},
}

## Good id -> (carry category, main colour, accent colour).
const CARRIED_GOODS := {
	"flour": ["sack", Color(0.95, 0.94, 0.9), Color(0.7, 0.68, 0.62)],
	"bread": ["basket", Color(0.62, 0.42, 0.2), Color(0.86, 0.6, 0.3)],
	"grain": ["bundle", Color(0.9, 0.75, 0.3), Color(0.7, 0.55, 0.2)],
	"wood": ["log", Color(0.55, 0.36, 0.2), Color(0.85, 0.7, 0.45)],
	"planks": ["log", Color(0.85, 0.68, 0.42), Color(0.95, 0.82, 0.58)],
	"stone": ["stone", Color(0.6, 0.6, 0.62), Color(0.78, 0.78, 0.8)],
	"fish": ["basket", Color(0.55, 0.4, 0.22), Color(0.65, 0.75, 0.82)],
	"hops": ["bundle", Color(0.45, 0.68, 0.28), Color(0.3, 0.5, 0.2)],
	"beer": ["barrel", Color(0.5, 0.32, 0.16), Color(0.3, 0.3, 0.32)],
}

## Stacks and nature sprites keep the tile diamond in their bottom 32 px (ART_SPEC §2).
const STACK_FRAME := Vector2i(64, 64)
const TREE_FRAME := Vector2i(64, 96)


func _init() -> void:
	_terrain()
	_characters()
	_goods()
	_stacks()
	_nature()
	_buildings()
	_walls()
	print("Placeholders written to ", OUT)
	quit()


# --- Terrain ---------------------------------------------------------------------------

func _terrain() -> void:
	# Ground textures are sampled seamlessly by the organic ground shader: no border.
	var ground := {
		"grass/a": Color(0.36, 0.55, 0.25), "grass/light": Color(0.4, 0.59, 0.28),
		"grass/dark": Color(0.31, 0.49, 0.22), "meadow/a": Color(0.55, 0.68, 0.32),
		"forest/a": Color(0.22, 0.38, 0.18), "water/a": Color(0.2, 0.4, 0.66),
		"ford/a": Color(0.47, 0.64, 0.78), "sea/a": Color(0.12, 0.27, 0.5),
		"sea/shallow": Color(0.3, 0.55, 0.7), "sand/a": Color(0.86, 0.78, 0.55),
		"bank/a": Color(0.45, 0.35, 0.22), "road/a": Color(0.6, 0.5, 0.36),
		"water/b": Color(0.21, 0.42, 0.68), "sea/b": Color(0.13, 0.29, 0.52),
		"road/b": Color(0.58, 0.48, 0.34),
	}
	for name: String in ground:
		_save(_diamond(ground[name], ground[name]), "terrain/%s.png" % name)
	_save(_diamond(Color(0, 0, 0, 0), Color(1, 1, 1, 0.3)), "terrain/grid/a.png")
	var decor := {
		"flowers_white": Color(0.95, 0.95, 0.9), "flowers_yellow": Color(0.95, 0.8, 0.3),
		"flowers_purple": Color(0.7, 0.55, 0.85), "clover": Color(0.6, 0.78, 0.45),
	}
	for name: String in decor:
		_save(_specks(decor[name]), "terrain/grass_decor/%s.png" % name)
	_save(_diamond(Color(0.5, 0.42, 0.28), Color(0.44, 0.36, 0.24)), "terrain/field/fallow.png")
	_save(_furrows(Color(0.42, 0.3, 0.18), Color(0.32, 0.22, 0.13), Color(0, 0, 0, 0)), "terrain/field/plowed.png")
	_save(_furrows(Color(0.42, 0.3, 0.18), Color(0.32, 0.22, 0.13), Color(0.45, 0.62, 0.25)), "terrain/field/sown_1.png")
	_save(_furrows(Color(0.36, 0.5, 0.2), Color(0.3, 0.42, 0.16), Color(0.5, 0.7, 0.28)), "terrain/field/sown_2.png")
	_save(_furrows(Color(0.52, 0.6, 0.24), Color(0.44, 0.52, 0.2), Color(0.72, 0.7, 0.3)), "terrain/field/sown_3.png")
	_save(_furrows(Color(0.86, 0.72, 0.3), Color(0.74, 0.6, 0.24), Color(0.95, 0.82, 0.4)), "terrain/field/ripe.png")
	# Hop garden: same soil, climbing green bines on poles that thicken with growth.
	var soil := Color(0.42, 0.3, 0.18)
	var furrow := Color(0.32, 0.22, 0.13)
	_save(_diamond(Color(0.5, 0.42, 0.28), Color(0.44, 0.36, 0.24)), "terrain/field_hops/fallow.png")
	_save(_furrows(soil, furrow, Color(0, 0, 0, 0)), "terrain/field_hops/plowed.png")
	for stage: int in 4:
		var name := "ripe" if stage == 3 else "sown_%d" % (stage + 1)
		_save(_hop_poles(soil, furrow, stage), "terrain/field_hops/%s.png" % name)
	# Coverage overlay of a service (well): a soft tinted diamond.
	_save(_diamond(Color(0.35, 0.6, 1.0, 0.28), Color(0.35, 0.6, 1.0, 0.45)), "terrain/range/a.png")
	_save(_diamond(Color(0.3, 1.0, 0.3, 0.35), Color(0.3, 1.0, 0.3, 0.9)), "terrain/cursor/ok.png")
	_save(_diamond(Color(1.0, 0.25, 0.2, 0.35), Color(1.0, 0.25, 0.2, 0.9)), "terrain/cursor/bad.png")
	_save(_diamond(Color(1, 1, 0.6, 0.35), Color(1, 1, 0.6, 0.9)), "terrain/cursor/a.png")


## A field tile: soil diamond with furrows along grid x; [param crop] dots on the ridges.
func _furrows(soil: Color, furrow: Color, crop: Color) -> Image:
	var img := _diamond(soil, furrow)
	for i: int in range(1, 6):
		var t := i / 6.0
		var a := IsoMath.grid_to_screen(Vector2(0.08, t)) + Vector2(32, 0)
		var b := IsoMath.grid_to_screen(Vector2(0.92, t)) + Vector2(32, 0)
		_line(img, a, b, furrow, 1)
		if crop.a > 0.0:
			for j: int in range(1, 7):
				var c := IsoMath.grid_to_screen(Vector2(j / 7.0, t)) + Vector2(32, -1)
				_line(img, c, c - Vector2(0, 2 + (i % 2)), crop, 2)
	return img


## Hop poles on a field tile: [param stage] 0..3 = bines climbing, 3 = ripe cones.
func _hop_poles(soil: Color, furrow: Color, stage: int) -> Image:
	var img := _furrows(soil, furrow, Color(0, 0, 0, 0))
	var green := Color(0.3, 0.55, 0.22).lightened(stage * 0.08)
	for p: Vector2 in [Vector2(0.3, 0.3), Vector2(0.7, 0.3), Vector2(0.3, 0.7), Vector2(0.7, 0.7)]:
		var foot := IsoMath.grid_to_screen(p) + Vector2(32, 0)
		_line(img, foot, foot - Vector2(0, 10), Color(0.45, 0.32, 0.18), 1)
		var top := foot - Vector2(0, 3 + stage * 2.5)
		_line(img, foot, top, green, 2)
		if stage == 3:
			_ellipse(img, top, Vector2(2, 2), Color(0.75, 0.85, 0.4))
	return img


## A loose cluster of single-pixel specks (flower decal placeholder).
func _specks(colour: Color) -> Image:
	var img := _blank(Vector2i(24, 12))
	for p: Vector2i in [Vector2i(3, 5), Vector2i(8, 2), Vector2i(11, 7), Vector2i(16, 4), Vector2i(20, 8), Vector2i(13, 10)]:
		img.set_pixelv(p, colour)
	return img


## Isometric 2:1 diamond filling the 64x32 tile, with a 1 px border.
func _diamond(fill: Color, border: Color) -> Image:
	var img := _blank(TILE)
	for y: int in TILE.y:
		var row := y if y < TILE.y / 2 else TILE.y - 1 - y
		var half_width := (row + 1) * 2
		for x: int in range(TILE.x / 2 - half_width, TILE.x / 2 + half_width):
			var edge := x <= TILE.x / 2 - half_width + 1 or x >= TILE.x / 2 + half_width - 2
			img.set_pixel(x, y, border if edge else fill)
	return img


# --- Characters ------------------------------------------------------------------------

func _characters() -> void:
	var anims := {
		"idle": [4, 0.0, ""],
		"walk": [8, 2.0, ""],
		"walk_carry_sack": [8, 1.0, "sack"],
		"walk_carry_basket": [8, 2.0, "basket"],
		"walk_carry_bundle": [8, 1.0, "bundle"],
		"walk_carry_log": [8, 1.0, "log"],
		"walk_carry_barrel": [8, 1.0, "barrel"],
		"walk_carry_stone": [8, 1.0, "stone"],
	}
	_save(_work_sheet(4), "characters/peasant/work.png")
	for anim: String in anims:
		var spec: Array = anims[anim]
		var sheets := _character_sheet(spec[0], spec[1], spec[2])
		_save(sheets[0], "characters/peasant/%s.png" % anim)
		_save(sheets[0].get_region(Rect2i(0, 0, sheets[0].get_width(), FRAME.y * 5)),
				"characters/peasant_mirror/%s.png" % anim)
		if spec[2] != "":
			_save(sheets[1], "characters/peasant/%s.anchors.png" % anim)
			_save(sheets[1].get_region(Rect2i(0, 0, sheets[1].get_width(), FRAME.y * 5)),
					"characters/peasant_mirror/%s.anchors.png" % anim)


## Returns [sheet, anchors]. Directions follow IsoMath.Dir; a red "nose" on the hat brim
## shows the facing, a tool in the right hand makes mirroring visible.
func _character_sheet(frames: int, bob: float, carry: String) -> Array[Image]:
	var sheet := _blank(Vector2i(FRAME.x * frames, FRAME.y * IsoMath.DIR_COUNT))
	var anchors := _blank(sheet.get_size())
	for dir: int in IsoMath.DIR_COUNT:
		var angle := PI / 2.0 - dir * TAU / IsoMath.DIR_COUNT
		var forward := Vector2(cos(angle), sin(angle))   # unsquashed screen space, y down
		var right := Vector2(-forward.y, forward.x)       # the person's right hand side
		for frame: int in frames:
			var phase := frame * TAU / frames
			var origin := Vector2i(frame * FRAME.x, dir * FRAME.y)
			var lift := int(round(absf(sin(phase)) * bob))
			var foot := Vector2(origin + FOOT) - Vector2(0, lift)
			_draw_person(sheet, foot, forward, right, sin(phase) if frames > 4 else 0.0, carry != "")
			if carry != "":
				var c: Dictionary = CARRY[carry]
				var spot := foot + Vector2(0, -c.height) \
						+ _squash(forward * c.forward + right * c.right)
				anchors.set_pixelv(Vector2i(spot.round()), ANCHOR)
				var faces_camera := forward.y > 0.1
				var faces_away := forward.y < -0.1
				var behind: bool = faces_camera if c.behind_when_facing_camera else faces_away
				if behind:
					anchors.set_pixelv(origin, BEHIND)
	return [sheet, anchors]


func _draw_person(img: Image, foot: Vector2, forward: Vector2, right: Vector2,
		swing: float, carrying: bool) -> void:
	var hand := foot + Vector2(0, -20) + _squash(right * 8.0 + forward * 2.0)
	var tool_in_front := right.y >= 0.0
	if not tool_in_front and not carrying:
		_draw_tool(img, hand)
	# Legs swing along the walking direction.
	for side: float in [-1.0, 1.0]:
		var hip := foot + Vector2(0, -12) + _squash(right * 3.0 * side)
		var step := _squash(forward * 4.0 * swing * side)
		_line(img, hip, foot + _squash(right * 3.0 * side) + step, TROUSERS, 3)
	# Torso and head.
	_ellipse(img, foot + Vector2(0, -21), Vector2(7, 10), SHIRT)
	var head := foot + Vector2(0, -CHARACTER_HEIGHT + 6)
	_ellipse(img, head, Vector2(5, 5), SKIN)
	_ellipse(img, head + Vector2(0, -4), Vector2(7, 2), HAT)
	var nose := head + _squash(forward * 6.0) + Vector2(0, -3)
	img.fill_rect(Rect2i(Vector2i(nose.round()) - Vector2i.ONE, Vector2i(3, 3)), Color(1, 0.15, 0.15))
	if tool_in_front and not carrying:
		_draw_tool(img, hand)


## Generic work animation: standing person swinging the tool up and down (all 8 directions).
func _work_sheet(frames: int) -> Image:
	var sheet := _blank(Vector2i(FRAME.x * frames, FRAME.y * IsoMath.DIR_COUNT))
	for dir: int in IsoMath.DIR_COUNT:
		var angle := PI / 2.0 - dir * TAU / IsoMath.DIR_COUNT
		var forward := Vector2(cos(angle), sin(angle))
		var right := Vector2(-forward.y, forward.x)
		for frame: int in frames:
			var foot := Vector2(Vector2i(frame * FRAME.x, dir * FRAME.y) + FOOT)
			_draw_person(sheet, foot, forward, right, 0.0, true)
			var swing := sin(frame * TAU / frames)
			var hand := foot + Vector2(0, -22) + _squash(forward * 6.0)
			var tip := hand + Vector2(0, -10 - 6 * swing) + _squash(forward * (6.0 + 6.0 * swing))
			_line(sheet, hand, tip, TOOL, 2)
			sheet.fill_rect(Rect2i(Vector2i(tip.round()) - Vector2i(3, 2), Vector2i(6, 4)), TOOL_HEAD)
	return sheet


func _draw_tool(img: Image, hand: Vector2) -> void:
	_line(img, hand + Vector2(0, 6), hand + Vector2(0, -14), TOOL, 2)
	img.fill_rect(Rect2i(Vector2i(hand.round()) + Vector2i(-3, -17), Vector2i(7, 4)), TOOL_HEAD)


## Ground-plane vector to screen (vertical squash 2:1).
static func _squash(v: Vector2) -> Vector2:
	return Vector2(v.x, v.y * 0.5)


# --- Goods -----------------------------------------------------------------------------

func _goods() -> void:
	for good: String in CARRIED_GOODS:
		var spec: Array = CARRIED_GOODS[good]
		var icon := _good_shape(spec[0], spec[1], spec[2], 1.0)
		_save(icon, "goods/icons/%s.png" % good)
		# Carried overlay: 5 rows (S, SE, E, NE, N), mirrored for the rest. 24x24 per row.
		var carried := _blank(Vector2i(24, 24 * 5))
		var small := _good_shape(spec[0], spec[1], spec[2], 0.75)
		for row: int in 5:
			carried.blit_rect(small.get_region(Rect2i(4, 4, 24, 24)), Rect2i(0, 0, 24, 24),
					Vector2i(0, row * 24))
		_save(carried, "goods/carried/%s/%s.png" % [spec[0], good])


func _good_shape(category: String, main: Color, accent: Color, scale: float) -> Image:
	var img := _blank(Vector2i(32, 32))
	var c := Vector2(16, 16)
	match category:
		"sack":
			_ellipse(img, c + Vector2(0, 2), Vector2(7, 8) * scale, main)
			_line(img, c + Vector2(-3, -8) * scale, c + Vector2(3, -8) * scale, accent, 2)
		"basket":
			_ellipse(img, c + Vector2(0, -2) * scale, Vector2(8, 4) * scale, accent)
			img.fill_rect(Rect2i(Vector2i(c + Vector2(-10, 0) * scale), Vector2i(Vector2(20, 9) * scale)), main)
		"log":
			_line(img, c + Vector2(-11, 4) * scale, c + Vector2(11, -4) * scale, main, roundi(6 * scale))
			_ellipse(img, c + Vector2(11, -4) * scale, Vector2(3, 3) * scale, accent)
		"barrel":
			_ellipse(img, c, Vector2(7, 9) * scale, main)
			_line(img, c + Vector2(-7, -4) * scale, c + Vector2(7, -4) * scale, accent, 2)
			_line(img, c + Vector2(-7, 4) * scale, c + Vector2(7, 4) * scale, accent, 2)
		"stone":
			_ellipse(img, c + Vector2(0, 2) * scale, Vector2(9, 6) * scale, main)
			_ellipse(img, c + Vector2(-2, 0) * scale, Vector2(4, 2) * scale, accent)
		"bundle":
			for i: int in 5:
				var x := (i - 2) * 3.0 * scale
				_line(img, c + Vector2(x, 10 * scale), c + Vector2(x * 1.6, -11 * scale), main, 2)
			_line(img, c + Vector2(-6, 1) * scale, c + Vector2(6, 1) * scale, accent, 2)
	return img


## Stockpile stacks: 4 fill stages side by side, each a growing heap on one tile.
func _stacks() -> void:
	for good: String in CARRIED_GOODS:
		var spec: Array = CARRIED_GOODS[good]
		var sheet := _blank(Vector2i(STACK_FRAME.x * 4, STACK_FRAME.y))
		for stage: int in 4:
			var frame := _blank(STACK_FRAME)
			var foot := Vector2(STACK_FRAME.x / 2.0, STACK_FRAME.y - 16.0)
			var base := PackedVector2Array([Vector2(-0.32, -0.32), Vector2(0.32, -0.32),
					Vector2(0.32, 0.32), Vector2(-0.32, 0.32)])
			_prism(frame, Vector2i(foot), base, 0.0, 6.0 + stage * 7.0, spec[1])
			_ellipse(frame, foot - Vector2(0, 8.0 + stage * 7.0), Vector2(6, 3), spec[2])
			sheet.blit_rect(frame, Rect2i(Vector2i.ZERO, STACK_FRAME), Vector2i(stage * STACK_FRAME.x, 0))
		_save(sheet, "goods/stacks/%s.png" % good)


## Tree states: grown, felled (trunk on the ground), stump.
func _nature() -> void:
	var foot := Vector2(TREE_FRAME.x / 2.0, TREE_FRAME.y - 16.0)
	var trunk := Color(0.42, 0.28, 0.16)
	var leaves := Color(0.2, 0.42, 0.18)
	var grown := _blank(TREE_FRAME)
	_line(grown, foot, foot - Vector2(0, 34), trunk, 6)
	_ellipse(grown, foot - Vector2(0, 52), Vector2(20, 24), leaves)
	_ellipse(grown, foot - Vector2(-6, 60), Vector2(8, 8), leaves.lightened(0.15))
	_save(grown, "nature/tree/grown.png")
	var felled := _blank(TREE_FRAME)
	_line(felled, foot + Vector2(-4, 2), foot + Vector2(22, -10), trunk, 6)
	_ellipse(felled, foot + Vector2(26, -14), Vector2(10, 7), leaves)
	_ellipse(felled, foot - Vector2(4, 2), Vector2(5, 3), Color(0.8, 0.66, 0.42))
	_save(felled, "nature/tree/felled.png")
	var stump := _blank(TREE_FRAME)
	_line(stump, foot, foot - Vector2(0, 5), trunk, 7)
	_ellipse(stump, foot - Vector2(0, 6), Vector2(4, 2), Color(0.8, 0.66, 0.42))
	_save(stump, "nature/tree/stump.png")
	# Rock outcrop: whole, half quarried, rubble.
	var rock := Color(0.58, 0.57, 0.55)
	for state: String in ["grown", "felled", "stump"]:
		var img := _blank(TREE_FRAME)
		var s: float = {"grown": 1.0, "felled": 0.65, "stump": 0.3}[state]
		var base := PackedVector2Array([Vector2(-0.38, -0.38), Vector2(0.38, -0.38),
				Vector2(0.38, 0.38), Vector2(-0.38, 0.38)])
		_prism(img, Vector2i(foot), base, 0.0, 28.0 * s, rock)
		_pyramid(img, Vector2i(foot), base, 28.0 * s, 10.0 * s, rock.lightened(0.15))
		_ellipse(img, foot + Vector2(10, -3), Vector2(4, 2) * s + Vector2(1, 1), rock.darkened(0.2))
		_save(img, "nature/rock/%s.png" % state)


# --- Buildings -------------------------------------------------------------------------

func _buildings() -> void:
	_building("hut_box", Vector2i(2, 2), Vector2i(1, 1), 30.0, 26.0, Color(0.78, 0.7, 0.55), Color(0.62, 0.3, 0.22))
	_building("hall_box", Vector2i(4, 4), Vector2i(3, 3), 48.0, 40.0, Color(0.7, 0.68, 0.64), Color(0.35, 0.38, 0.5))
	_building("workshop_box", Vector2i(3, 2), Vector2i(2, 1), 36.0, 28.0, Color(0.74, 0.62, 0.48), Color(0.5, 0.35, 0.22))
	# M3 slice buildings: own colours and one telling detail each (data/visuals points here).
	for id: String in SLICE_BUILDINGS:
		var b: Dictionary = SLICE_BUILDINGS[id]
		var fp: Vector2i = b["footprint"]
		var entrance: Vector2i = b["entrance"]
		if b["walls"] > 0.0:
			_building(id, fp, entrance, b["walls"], b["roof"], b["wall"], b["roof_color"],
					"base", "hip_both", b.get("extra", ""))
		_site(id, fp, 1)
		_site(id, fp, 2)
	# House level 2 (burgher house) and its row variants (ARCHITECTURE §6.6, ART_SPEC §7).
	var house_wall := Color(0.86, 0.8, 0.66)
	var house_roof := Color(0.55, 0.22, 0.18)
	for variant: String in ["single", "end_a", "middle", "end_b"]:
		for axis: String in ["x", "y"]:
			var roof: String = {"single": "hip_both", "end_a": "hip_start", "middle": "hip_none",
					"end_b": "hip_end"}[variant]
			_building("hut", Vector2i(2, 2), Vector2i(1, 1), 44.0, 24.0, house_wall, house_roof,
					"level_2_%s_%s" % [variant, axis], roof + "_" + axis, "",
					0 if variant != "single" else 8)
	_scaffold("hut", Vector2i(2, 2), 54.0)


## id -> footprint, entrance, wall height, roof height, colours, detail. Walls 0 = no box
## (the stockpile is a yard drawn by the view).
const SLICE_BUILDINGS := {
	"town_hall": {"footprint": Vector2i(4, 4), "entrance": Vector2i(1, 3), "walls": 50.0, "roof": 42.0,
			"wall": Color(0.72, 0.7, 0.66), "roof_color": Color(0.3, 0.36, 0.55), "extra": "tower"},
	"stockpile": {"footprint": Vector2i(4, 4), "entrance": Vector2i(1, 3), "walls": 0.0, "roof": 0.0,
			"wall": Color.WHITE, "roof_color": Color.WHITE},
	"hut": {"footprint": Vector2i(2, 2), "entrance": Vector2i(1, 1), "walls": 26.0, "roof": 26.0,
			"wall": Color(0.76, 0.66, 0.48), "roof_color": Color(0.78, 0.66, 0.32)},
	"well": {"footprint": Vector2i(1, 1), "entrance": Vector2i(0, 0), "walls": 10.0, "roof": 20.0,
			"wall": Color(0.62, 0.62, 0.64), "roof_color": Color(0.5, 0.32, 0.2), "extra": "well"},
	"woodcutter": {"footprint": Vector2i(2, 2), "entrance": Vector2i(1, 1), "walls": 26.0, "roof": 22.0,
			"wall": Color(0.55, 0.4, 0.26), "roof_color": Color(0.32, 0.45, 0.25), "extra": "logs"},
	"farm": {"footprint": Vector2i(2, 2), "entrance": Vector2i(1, 1), "walls": 28.0, "roof": 24.0,
			"wall": Color(0.82, 0.76, 0.6), "roof_color": Color(0.85, 0.7, 0.3), "extra": "sheaf"},
	"mill": {"footprint": Vector2i(2, 2), "entrance": Vector2i(1, 1), "walls": 44.0, "roof": 24.0,
			"wall": Color(0.9, 0.88, 0.82), "roof_color": Color(0.45, 0.32, 0.22), "extra": "sails"},
	"bakery": {"footprint": Vector2i(2, 2), "entrance": Vector2i(1, 1), "walls": 30.0, "roof": 22.0,
			"wall": Color(0.8, 0.58, 0.42), "roof_color": Color(0.6, 0.25, 0.2), "extra": "chimney"},
	# M4a
	"sawmill": {"footprint": Vector2i(2, 2), "entrance": Vector2i(1, 1), "walls": 24.0, "roof": 18.0,
			"wall": Color(0.7, 0.55, 0.36), "roof_color": Color(0.45, 0.35, 0.25), "extra": "planks"},
	"quarry": {"footprint": Vector2i(2, 2), "entrance": Vector2i(1, 1), "walls": 22.0, "roof": 18.0,
			"wall": Color(0.62, 0.6, 0.56), "roof_color": Color(0.4, 0.38, 0.36), "extra": "blocks"},
	"fishing_hut": {"footprint": Vector2i(2, 2), "entrance": Vector2i(1, 1), "walls": 22.0, "roof": 20.0,
			"wall": Color(0.6, 0.5, 0.38), "roof_color": Color(0.35, 0.45, 0.55), "extra": "nets"},
	"hop_farm": {"footprint": Vector2i(2, 2), "entrance": Vector2i(1, 1), "walls": 28.0, "roof": 24.0,
			"wall": Color(0.8, 0.74, 0.58), "roof_color": Color(0.35, 0.55, 0.28), "extra": "poles"},
	"brewery": {"footprint": Vector2i(2, 2), "entrance": Vector2i(1, 1), "walls": 32.0, "roof": 22.0,
			"wall": Color(0.74, 0.6, 0.46), "roof_color": Color(0.5, 0.28, 0.16), "extra": "barrels"},
	"chapel": {"footprint": Vector2i(2, 2), "entrance": Vector2i(1, 1), "walls": 30.0, "roof": 26.0,
			"wall": Color(0.88, 0.86, 0.8), "roof_color": Color(0.42, 0.3, 0.24), "extra": "cross"},
	"church": {"footprint": Vector2i(3, 3), "entrance": Vector2i(1, 2), "walls": 46.0, "roof": 34.0,
			"wall": Color(0.82, 0.8, 0.74), "roof_color": Color(0.3, 0.32, 0.42), "extra": "steeple"},
	"market": {"footprint": Vector2i(3, 3), "entrance": Vector2i(1, 2), "walls": 14.0, "roof": 12.0,
			"wall": Color(0.7, 0.55, 0.38), "roof_color": Color(0.8, 0.3, 0.25), "extra": "stalls"},
}


func _canvas(footprint: Vector2i, height: float, eaves: int) -> Dictionary:
	var size := Vector2i(32 * (footprint.x + footprint.y) + eaves * 2,
			16 * (footprint.x + footprint.y) + int(height) + 4)
	return {"size": size, "pivot": Vector2i(32 * footprint.x + eaves, size.y - 2)}


func _write_art(id: String, name: String, img: Image, footprint: Vector2i, entrance: Vector2i,
		pivot: Vector2i) -> void:
	_save(img, "buildings/%s/%s.png" % [id, name])
	var meta := {"footprint": [footprint.x, footprint.y], "entrance": [entrance.x, entrance.y],
			"pivot": [pivot.x, pivot.y]}
	var file := FileAccess.open(OUT.path_join("buildings/%s/%s.json" % [id, name]), FileAccess.WRITE)
	file.store_string(JSON.stringify(meta, "\t"))


## Box building with a roof. Writes <name>.png and <name>.json (footprint, entrance, pivot).
## [param roof_kind]: "hip_both" (pyramid-like) or "<hip_start|hip_end|hip_none>_<x|y>"
## for houses joined into a row along a grid axis.
func _building(id: String, footprint: Vector2i, entrance: Vector2i, wall_h: float, roof_h: float,
		wall: Color, roof: Color, name: String = "base", roof_kind: String = "hip_both",
		extra: String = "", eaves: int = 8) -> void:
	var canvas := _canvas(footprint, wall_h + roof_h + float({"tower": 30.0, "steeple": 46.0, "cross": 16.0}.get(extra, 0.0)), maxi(eaves, 8))
	var pivot: Vector2i = canvas["pivot"]
	var img := _blank(canvas["size"])
	var base := _footprint_base(footprint)
	_prism(img, pivot, base, 0.0, wall_h, wall)
	_door(img, pivot, footprint, entrance)
	if roof_kind == "hip_both":
		var grown := PackedVector2Array()
		var center := -Vector2(footprint) * 0.5
		var overhang := 0.25 / maxf(footprint.x, footprint.y) if eaves > 0 else 0.0
		for p: Vector2 in base:
			grown.append(center + (p - center) * (1.0 + overhang))
		_pyramid(img, pivot, grown, wall_h, roof_h, roof)
	else:
		_ridge_roof(img, pivot, footprint, wall_h, roof_h, roof, roof_kind)
	_extra(img, pivot, footprint, wall_h, roof_h, extra)
	_write_art(id, name, img, footprint, entrance, pivot)


func _footprint_base(footprint: Vector2i) -> PackedVector2Array:
	var base := PackedVector2Array()
	for p: Vector2 in [Vector2(0, 0), Vector2(footprint.x, 0), Vector2(footprint), Vector2(0, footprint.y)]:
		base.append(p - Vector2(footprint))
	return base


func _door(img: Image, pivot: Vector2i, footprint: Vector2i, entrance: Vector2i) -> void:
	var door_tile := Vector2(entrance) - Vector2(footprint)
	var on_right_face := entrance.x == footprint.x - 1
	var door_mid := door_tile + (Vector2(1.0, 0.5) if on_right_face else Vector2(0.5, 1.0))
	var door_dir := Vector2(0, 0.2) if on_right_face else Vector2(0.2, 0)
	var d0 := Vector2(pivot) + IsoMath.grid_to_screen(door_mid - door_dir)
	var d1 := Vector2(pivot) + IsoMath.grid_to_screen(door_mid + door_dir)
	_fill_polygon(img, PackedVector2Array([d0, d1, d1 - Vector2(0, 20), d0 - Vector2(0, 20)]),
			Color(0.25, 0.16, 0.1))


## Ridge roof along a grid axis: hipped ends where the row ends, open (flush) ends where a
## neighbour continues the row, so adjacent houses read as one long roof.
func _ridge_roof(img: Image, pivot: Vector2i, footprint: Vector2i, wall_h: float, roof_h: float,
		color: Color, kind: String) -> void:
	var parts := kind.rsplit("_", true, 1)
	var hips: String = parts[0]
	var along_x: bool = parts[1] == "x"
	var f := Vector2(footprint)
	var o := -f
	var length := f.x if along_x else f.y
	var width := f.y if along_x else f.x
	var start_in := width * 0.5 if hips in ["hip_both", "hip_start"] else 0.0
	var end_in := width * 0.5 if hips in ["hip_both", "hip_end"] else 0.0
	# Points in (along, across) space, then mapped to grid.
	var to_grid := func(a: float, c: float) -> Vector2:
		return o + (Vector2(a, c) if along_x else Vector2(c, a))
	var e0: Vector2 = to_grid.call(0.0, 0.0)
	var e1: Vector2 = to_grid.call(length, 0.0)
	var e2: Vector2 = to_grid.call(length, width)
	var e3: Vector2 = to_grid.call(0.0, width)
	var r0: Vector2 = to_grid.call(start_in, width * 0.5)
	var r1: Vector2 = to_grid.call(length - end_in, width * 0.5)
	var faces := [
		[[e0, wall_h], [e1, wall_h], [r1, wall_h + roof_h], [r0, wall_h + roof_h]],
		[[e3, wall_h], [e2, wall_h], [r1, wall_h + roof_h], [r0, wall_h + roof_h]],
		[[e0, wall_h], [e3, wall_h], [r0, wall_h + roof_h]],
		[[e1, wall_h], [e2, wall_h], [r1, wall_h + roof_h]],
	]
	faces.sort_custom(func(a: Array, b: Array) -> bool:
		return _face_depth(a) < _face_depth(b))
	for i: int in faces.size():
		var poly := PackedVector2Array()
		for corner: Array in faces[i]:
			poly.append(Vector2(pivot) + IsoMath.grid_to_screen(corner[0]) - Vector2(0, corner[1]))
		var shade := color.darkened(0.1 * (3 - i)) if i < 3 else color.lightened(0.08)
		_fill_polygon(img, poly, shade)
		_outline(img, poly, color.darkened(0.6))


func _face_depth(face: Array) -> float:
	var sum := 0.0
	for corner: Array in face:
		var g: Vector2 = corner[0]
		sum += g.x + g.y
	return sum / face.size()


## One telling detail per building so they are easy to tell apart.
func _extra(img: Image, pivot: Vector2i, footprint: Vector2i, wall_h: float, roof_h: float, extra: String) -> void:
	var front := Vector2(pivot)
	var center := front + IsoMath.grid_to_screen(-Vector2(footprint) * 0.5)
	match extra:
		"tower":
			var t := PackedVector2Array([Vector2(-2.6, -2.6), Vector2(-1.4, -2.6), Vector2(-1.4, -1.4), Vector2(-2.6, -1.4)])
			_prism(img, pivot, t, wall_h, wall_h + roof_h + 10.0, Color(0.68, 0.66, 0.62))
			_pyramid(img, pivot, t, wall_h + roof_h + 10.0, 18.0, Color(0.3, 0.36, 0.55))
		"well":
			_ellipse(img, center - Vector2(0, wall_h + 2), Vector2(9, 4), Color(0.15, 0.25, 0.45))
		"logs":
			var p := front + IsoMath.grid_to_screen(Vector2(-0.4, -1.9))
			for i: int in 3:
				_line(img, p + Vector2(-8, -4 - i * 4), p + Vector2(8, -i * 4), Color(0.5, 0.33, 0.18), 4)
		"sheaf":
			var q := front + IsoMath.grid_to_screen(Vector2(-1.9, -0.4)) - Vector2(0, 4)
			for i: int in 5:
				_line(img, q + Vector2(i * 2 - 4, 0), q + Vector2(i * 3 - 6, -14), Color(0.92, 0.78, 0.32), 2)
		"sails":
			var hub := front + IsoMath.grid_to_screen(Vector2(-0.5, -1.0)) - Vector2(0, wall_h * 0.75)
			for k: int in 4:
				var a := k * PI / 2.0 + PI / 4.0
				var tip := hub + Vector2(cos(a), sin(a)) * 26.0
				_line(img, hub, tip, Color(0.4, 0.28, 0.16), 2)
				_line(img, tip, tip.lerp(hub, 0.6) + Vector2(cos(a + 0.5), sin(a + 0.5)) * 6.0, Color(0.92, 0.9, 0.84), 4)
			_ellipse(img, hub, Vector2(3, 3), Color(0.3, 0.2, 0.12))
		"chimney":
			var c := PackedVector2Array([Vector2(-1.5, -0.8), Vector2(-1.1, -0.8), Vector2(-1.1, -0.4), Vector2(-1.5, -0.4)])
			_prism(img, pivot, c, wall_h, wall_h + roof_h + 8.0, Color(0.55, 0.3, 0.25))
		"planks":
			var p := front + IsoMath.grid_to_screen(Vector2(-0.4, -1.9))
			for i: int in 4:
				_line(img, p + Vector2(-9, -2 - i * 3), p + Vector2(9, 2 - i * 3), Color(0.88, 0.72, 0.46), 3)
		"blocks":
			var base := PackedVector2Array([Vector2(-0.3, -2.0), Vector2(0.3, -2.0), Vector2(0.3, -1.4), Vector2(-0.3, -1.4)])
			_prism(img, pivot, base, 0.0, 10.0, Color(0.7, 0.7, 0.72))
		"nets":
			var n := front + IsoMath.grid_to_screen(Vector2(-1.9, -0.5)) - Vector2(0, 6)
			for i: int in 4:
				_line(img, n + Vector2(i * 4 - 6, 0), n + Vector2(i * 4 - 6, -14), Color(0.85, 0.82, 0.7), 1)
			_line(img, n + Vector2(-7, -14), n + Vector2(8, -14), Color(0.45, 0.3, 0.18), 2)
		"poles":
			var h := front + IsoMath.grid_to_screen(Vector2(-1.9, -0.4))
			for i: int in 3:
				_line(img, h + Vector2(i * 6 - 6, 0), h + Vector2(i * 6 - 6, -20), Color(0.45, 0.32, 0.18), 2)
				_line(img, h + Vector2(i * 6 - 6, 0), h + Vector2(i * 6 - 5, -16), Color(0.35, 0.6, 0.25), 2)
		"barrels":
			var b := front + IsoMath.grid_to_screen(Vector2(-0.4, -1.9))
			for i: int in 2:
				_ellipse(img, b + Vector2(i * 9 - 4, -6), Vector2(4, 6), Color(0.5, 0.32, 0.16))
				_line(img, b + Vector2(i * 9 - 8, -6), b + Vector2(i * 9, -6), Color(0.3, 0.3, 0.32), 1)
		"cross":
			var top := center - Vector2(0, wall_h + roof_h + 2)
			_line(img, top, top - Vector2(0, 12), Color(0.95, 0.85, 0.4), 2)
			_line(img, top - Vector2(4, 8), top - Vector2(-4, 8), Color(0.95, 0.85, 0.4), 2)
		"steeple":
			var t := PackedVector2Array([Vector2(-2.8, -2.8), Vector2(-1.8, -2.8), Vector2(-1.8, -1.8), Vector2(-2.8, -1.8)])
			_prism(img, pivot, t, wall_h, wall_h + roof_h + 16.0, Color(0.8, 0.78, 0.72))
			_pyramid(img, pivot, t, wall_h + roof_h + 16.0, 26.0, Color(0.3, 0.32, 0.42))
		"stalls":
			for k: int in 3:
				var s := front + IsoMath.grid_to_screen(Vector2(-0.6 - k * 0.9, -2.4 + k * 0.6)) - Vector2(0, wall_h + roof_h - 4)
				_line(img, s + Vector2(-8, 0), s + Vector2(8, 0), [Color(0.9, 0.85, 0.75), Color(0.35, 0.5, 0.75), Color(0.85, 0.7, 0.3)][k], 4)


## Construction site art: phase 1 = foundation with poles, phase 2 = half-built walls with
## scaffolding planks. Same footprint and pivot rules as the finished building.
func _site(id: String, footprint: Vector2i, phase: int) -> void:
	var height := 48.0
	var canvas := _canvas(footprint, height, 8)
	var pivot: Vector2i = canvas["pivot"]
	var img := _blank(canvas["size"])
	var base := _footprint_base(footprint)
	_prism(img, pivot, base, 0.0, 4.0, Color(0.6, 0.58, 0.54))
	if phase == 2:
		var inner := PackedVector2Array()
		var center := -Vector2(footprint) * 0.5
		for p: Vector2 in base:
			inner.append(center + (p - center) * 0.9)
		_prism(img, pivot, inner, 4.0, 22.0, Color(0.78, 0.68, 0.5))
	_scaffold_on(img, pivot, footprint, 30.0 if phase == 1 else 40.0)
	_write_art(id, "construction_%d" % phase, img, footprint, Vector2i(footprint.x / 2, footprint.y - 1), pivot)


## Scaffolding overlay drawn over a house being upgraded.
func _scaffold(id: String, footprint: Vector2i, height: float) -> void:
	var canvas := _canvas(footprint, height + 30.0, 8)
	var pivot: Vector2i = canvas["pivot"]
	var img := _blank(canvas["size"])
	_scaffold_on(img, pivot, footprint, height)
	_write_art(id, "upgrade_scaffold", img, footprint, Vector2i(1, 1), pivot)


func _scaffold_on(img: Image, pivot: Vector2i, footprint: Vector2i, height: float) -> void:
	var wood := Color(0.62, 0.45, 0.25)
	var corners := [Vector2(0, 0), Vector2(footprint.x, 0), Vector2(footprint), Vector2(0, footprint.y)]
	var front := []
	for c: Vector2 in corners:
		front.append(Vector2(pivot) + IsoMath.grid_to_screen(c - Vector2(footprint)))
	for p: Vector2 in front:
		_line(img, p, p - Vector2(0, height), wood, 2)
	for level: float in [height * 0.45, height * 0.9]:
		for i: int in 4:
			var a: Vector2 = front[i]
			var b: Vector2 = front[(i + 1) % 4]
			_line(img, a - Vector2(0, level), b - Vector2(0, level), wood.lightened(0.15), 2)


# --- Walls -----------------------------------------------------------------------------

func _walls() -> void:
	var stone := Color(0.66, 0.64, 0.6)
	for piece: WallGeometry.Piece in WallGeometry.all_pieces():
		var img := _blank(WallGeometry.CANVAS)
		var color := stone.darkened(0.15) if piece.name.begins_with("gate_lintel") else stone
		_prism(img, WallGeometry.PIVOT, piece.base, piece.z_bottom, piece.z_top, color)
		_save(img, "walls/stone_wall/%s.png" % piece.name)


# --- Drawing primitives ----------------------------------------------------------------

## Extruded convex ground polygon (grid units relative to [param pivot]): visible side
## faces with light from the top-left-front, then the lighter top face, then outlines.
func _prism(img: Image, pivot: Vector2i, base: PackedVector2Array, z0: float, z1: float, color: Color) -> void:
	var centroid := Vector2.ZERO
	for p: Vector2 in base:
		centroid += p
	centroid /= base.size()
	var n := base.size()
	var top := PackedVector2Array()
	for p: Vector2 in base:
		top.append(Vector2(pivot) + IsoMath.grid_to_screen(p) - Vector2(0, z1))
	for i: int in n:
		var a := base[i]
		var b := base[(i + 1) % n]
		var mid := (a + b) * 0.5
		var normal := (b - a).orthogonal().normalized()
		if normal.dot(mid - centroid) < 0:
			normal = -normal
		if normal.dot(Vector2(1, 1)) <= 0.001:
			continue
		# Faces turned towards grid +y (screen left) are lit, towards +x darker.
		var shade := color.darkened(0.35 - 0.25 * clampf(normal.y - normal.x + 0.5, 0.0, 1.0))
		var sa := Vector2(pivot) + IsoMath.grid_to_screen(a)
		var sb := Vector2(pivot) + IsoMath.grid_to_screen(b)
		var face := PackedVector2Array([sa - Vector2(0, z0), sb - Vector2(0, z0),
				sb - Vector2(0, z1), sa - Vector2(0, z1)])
		_fill_polygon(img, face, shade)
		_outline(img, face, color.darkened(0.6))
	_fill_polygon(img, top, color.lightened(0.15))
	_outline(img, top, color.darkened(0.6))


func _pyramid(img: Image, pivot: Vector2i, base: PackedVector2Array, z0: float, height: float, color: Color) -> void:
	var centroid := Vector2.ZERO
	for p: Vector2 in base:
		centroid += p
	centroid /= base.size()
	var apex := Vector2(pivot) + IsoMath.grid_to_screen(centroid) - Vector2(0, z0 + height)
	var n := base.size()
	# Back faces first so the front ones cover them.
	var order: Array[int] = []
	for i: int in n:
		order.append(i)
	order.sort_custom(func(i: int, j: int) -> bool:
		var mi := (base[i] + base[(i + 1) % n]) * 0.5
		var mj := (base[j] + base[(j + 1) % n]) * 0.5
		return mi.x + mi.y < mj.x + mj.y)
	for i: int in order:
		var a := base[i]
		var b := base[(i + 1) % n]
		var normal := (b - a).orthogonal().normalized()
		if normal.dot((a + b) * 0.5 - centroid) < 0:
			normal = -normal
		var shade := color.darkened(0.3 - 0.3 * clampf(normal.y - normal.x + 0.5, 0.0, 1.0))
		if normal.dot(Vector2(1, 1)) < 0:
			shade = color.lightened(0.1)
		var tri := PackedVector2Array([
			Vector2(pivot) + IsoMath.grid_to_screen(a) - Vector2(0, z0),
			Vector2(pivot) + IsoMath.grid_to_screen(b) - Vector2(0, z0), apex])
		_fill_polygon(img, tri, shade)
		_outline(img, tri, color.darkened(0.6))


func _fill_polygon(img: Image, poly: PackedVector2Array, color: Color) -> void:
	var bounds := Rect2(poly[0], Vector2.ZERO)
	for p: Vector2 in poly:
		bounds = bounds.expand(p)
	var area := Rect2i(bounds).grow(1).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), poly):
				img.set_pixel(x, y, color)


func _outline(img: Image, poly: PackedVector2Array, color: Color) -> void:
	for i: int in poly.size():
		_line(img, poly[i], poly[(i + 1) % poly.size()], color, 1)


func _line(img: Image, a: Vector2, b: Vector2, color: Color, width: int) -> void:
	var steps := maxi(1, int(ceil(a.distance_to(b))))
	for s: int in steps + 1:
		var p := a.lerp(b, float(s) / steps)
		for dx: int in width:
			for dy: int in width:
				var q := Vector2i(int(p.x) + dx - width / 2, int(p.y) + dy - width / 2)
				if Rect2i(Vector2i.ZERO, img.get_size()).has_point(q):
					img.set_pixelv(q, color)


func _ellipse(img: Image, center: Vector2, radius: Vector2, color: Color) -> void:
	for y: int in range(int(center.y - radius.y) - 2, int(center.y + radius.y) + 3):
		for x: int in range(int(center.x - radius.x) - 2, int(center.x + radius.x) + 3):
			if not Rect2i(Vector2i.ZERO, img.get_size()).has_point(Vector2i(x, y)):
				continue
			var d := Vector2((x + 0.5 - center.x) / radius.x, (y + 0.5 - center.y) / radius.y).length()
			if d <= 1.0:
				img.set_pixel(x, y, color)
			elif d <= 1.0 + 1.2 / minf(radius.x, radius.y) and img.get_pixel(x, y).a == 0.0:
				img.set_pixel(x, y, OUTLINE)


func _blank(size: Vector2i) -> Image:
	return Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)


func _save(img: Image, relative: String) -> void:
	var path := OUT.path_join(relative)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var err := img.save_png(path)
	if err != OK:
		push_error("Cannot save %s (%s)" % [path, error_string(err)])
