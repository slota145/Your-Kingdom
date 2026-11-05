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
}

## Good id -> (carry category, main colour, accent colour).
const CARRIED_GOODS := {
	"flour": ["sack", Color(0.95, 0.94, 0.9), Color(0.7, 0.68, 0.62)],
	"bread": ["basket", Color(0.62, 0.42, 0.2), Color(0.86, 0.6, 0.3)],
	"grain": ["bundle", Color(0.9, 0.75, 0.3), Color(0.7, 0.55, 0.2)],
	"wood": ["log", Color(0.55, 0.36, 0.2), Color(0.85, 0.7, 0.45)],
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
	_save(_diamond(Color(0.36, 0.55, 0.25), Color(0.32, 0.5, 0.22)), "terrain/grass/a.png")
	_save(_diamond(Color(0.38, 0.57, 0.26), Color(0.34, 0.52, 0.23)), "terrain/grass/b.png")
	_save(_diamond(Color(0, 0, 0, 0), Color(1, 1, 1, 0.3)), "terrain/grid/a.png")
	_save(_diamond(Color(1, 1, 0.6, 0.35), Color(1, 1, 0.6, 0.9)), "terrain/cursor/a.png")


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
	}
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


# --- Buildings -------------------------------------------------------------------------

func _buildings() -> void:
	_building("hut_box", Vector2i(2, 2), Vector2i(1, 1), 30.0, 26.0, Color(0.78, 0.7, 0.55), Color(0.62, 0.3, 0.22))
	_building("hall_box", Vector2i(4, 4), Vector2i(3, 3), 48.0, 40.0, Color(0.7, 0.68, 0.64), Color(0.35, 0.38, 0.5))
	_building("workshop_box", Vector2i(3, 2), Vector2i(2, 1), 36.0, 28.0, Color(0.74, 0.62, 0.48), Color(0.5, 0.35, 0.22))


## Box building with a pyramid roof. Writes base.png and base.json (footprint, pivot).
func _building(id: String, footprint: Vector2i, entrance: Vector2i, wall_h: float, roof_h: float,
		wall: Color, roof: Color) -> void:
	var eaves := 8
	var size := Vector2i(32 * (footprint.x + footprint.y) + eaves * 2,
			16 * (footprint.x + footprint.y) + int(wall_h + roof_h) + 4)
	var pivot := Vector2i(32 * footprint.x + eaves, size.y - 2)
	var img := _blank(size)
	var rect := PackedVector2Array([Vector2(0, 0), Vector2(footprint.x, 0),
			Vector2(footprint), Vector2(0, footprint.y)])
	# Footprint corners relative to B (front vertex).
	var base := PackedVector2Array()
	for p: Vector2 in rect:
		base.append(p - Vector2(footprint))
	_prism(img, pivot, base, 0.0, wall_h, wall)
	# Door on the entrance tile's visible face.
	var door_tile := Vector2(entrance) - Vector2(footprint)
	var on_right_face := entrance.x == footprint.x - 1
	var door_mid := door_tile + (Vector2(1.0, 0.5) if on_right_face else Vector2(0.5, 1.0))
	var door_dir := Vector2(0, 0.2) if on_right_face else Vector2(0.2, 0)
	var d0 := Vector2(pivot) + IsoMath.grid_to_screen(door_mid - door_dir)
	var d1 := Vector2(pivot) + IsoMath.grid_to_screen(door_mid + door_dir)
	_fill_polygon(img, PackedVector2Array([d0, d1, d1 - Vector2(0, 20), d0 - Vector2(0, 20)]),
			Color(0.25, 0.16, 0.1))
	# Pyramid roof with a little overhang.
	var grown := PackedVector2Array()
	var center := -Vector2(footprint) * 0.5
	for p: Vector2 in base:
		grown.append(center + (p - center) * (1.0 + 0.25 / maxf(footprint.x, footprint.y)))
	_pyramid(img, pivot, grown, wall_h, roof_h, roof)
	_save(img, "buildings/%s/base.png" % id)
	var meta := {"footprint": [footprint.x, footprint.y], "entrance": [entrance.x, entrance.y],
			"pivot": [pivot.x, pivot.y]}
	var file := FileAccess.open(OUT.path_join("buildings/%s/base.json" % id), FileAccess.WRITE)
	file.store_string(JSON.stringify(meta, "\t"))


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
