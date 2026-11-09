class_name StockpileView
extends Node2D
## A stockpile yard: the ground of the footprint plus one stack per slot. The stacks come
## from StockpileLayout over the same slots the UI lists (ARCHITECTURE §6.5).
## Child of the y-sorted world.

const YARD_COLOR := Color(0.55, 0.45, 0.32)
const YARD_EDGE := Color(0.4, 0.31, 0.2)
## P2 part 3 (owner's request): a storage's floor is a timber deck, a port warehouse's a stone
## pavement; both stand a little above the ground, their edge showing towards the camera.
const PLANK := Color(0.6, 0.45, 0.28)
const PLANK_DARK := Color(0.42, 0.3, 0.18)
const BEAM := Color(0.33, 0.23, 0.14)
const FLAG := Color(0.66, 0.64, 0.59)
const FLAG_DARK := Color(0.5, 0.48, 0.44)
const KERB := Color(0.56, 0.54, 0.5)
## How high the floor stands (px), its edge seen at the front.
const RISE := 3.0

var building: BuildingState
var _stacks: Array[StackSprite] = []


class _Yard:
	extends Node2D
	var footprint: Vector2i
	var stone: bool = false

	func _p(x: float, y: float) -> Vector2:
		return IsoMath.grid_to_screen(Vector2(x, y))

	func _draw() -> void:
		var f := Vector2(footprint)
		var up := Vector2(0, -RISE)
		var corners := PackedVector2Array([_p(0, 0) + up, _p(f.x, 0) + up, _p(f.x, f.y) + up, _p(0, f.y) + up])
		# The front edges (towards +x and +y) standing out of the ground.
		var side := (FLAG_DARK if stone else BEAM)
		draw_colored_polygon(PackedVector2Array([_p(f.x, 0) + up, _p(f.x, f.y) + up, _p(f.x, f.y), _p(f.x, 0)]),
				side.darkened(0.15))
		draw_colored_polygon(PackedVector2Array([_p(0, f.y) + up, _p(f.x, f.y) + up, _p(f.x, f.y), _p(0, f.y)]),
				side.darkened(0.3))
		draw_colored_polygon(corners, FLAG if stone else PLANK)
		if stone:
			_flagstones(f, up)
		else:
			_planks(f, up)
		corners.append(corners[0])
		draw_polyline(corners, KERB.darkened(0.35) if stone else BEAM, 2.0)

	## Planks running along x, each a shade of its own, joints staggered, nail heads at the
	## joints; a beam along the two back edges.
	func _planks(f: Vector2, up: Vector2) -> void:
		var rows := int(f.y * 4)
		for r: int in rows:
			var y0 := r / 4.0
			var y1 := (r + 1) / 4.0
			var x := 0.0
			var k := 0
			while x < f.x:
				var length := 1.5 if (r + k) % 2 == 0 else 1.0
				var x1 := minf(x + length - (0.5 if k == 0 and r % 2 == 1 else 0.0), f.x)
				var h := absi(r * 7 + k * 13) % 4
				var shade := PLANK.darkened(0.06 * h) if h != 3 else PLANK.lightened(0.05)
				draw_colored_polygon(PackedVector2Array([_p(x, y0) + up, _p(x1, y0) + up, _p(x1, y1) + up,
						_p(x, y1) + up]), shade)
				if x1 < f.x:
					draw_line(_p(x1, y0) + up, _p(x1, y1) + up, PLANK_DARK, 1.0)
					draw_rect(Rect2(_p(x1 - 0.05, (y0 + y1) * 0.5) + up, Vector2(1, 1)), PLANK_DARK.darkened(0.4))
				x = x1
				k += 1
			draw_line(_p(0, y1) + up, _p(f.x, y1) + up, PLANK_DARK, 1.0)
		draw_line(_p(0, 0) + up, _p(f.x, 0) + up, BEAM, 3.0)
		draw_line(_p(0, 0) + up, _p(0, f.y) + up, BEAM, 3.0)

	## Flagstones: two rows per tile, the joints across staggered, each stone a shade of its
	## own; a kerb of long stones along the edge.
	func _flagstones(f: Vector2, up: Vector2) -> void:
		var rows := int(f.y * 2)
		for r: int in rows:
			var y0 := r / 2.0
			var y1 := (r + 1) / 2.0
			var x := 0.0 if r % 2 == 0 else -0.35
			var k := 0
			while x < f.x:
				var x1 := minf(x + (0.7 if (r + k) % 3 != 0 else 0.55), f.x)
				var x0 := maxf(x, 0.0)
				var h := absi(r * 11 + k * 5) % 4
				var shade := FLAG.darkened(0.05 * h) if h != 2 else FLAG.lightened(0.05)
				draw_colored_polygon(PackedVector2Array([_p(x0, y0) + up, _p(x1, y0) + up, _p(x1, y1) + up,
						_p(x0, y1) + up]), shade)
				if x1 < f.x:
					draw_line(_p(x1, y0) + up, _p(x1, y1) + up, FLAG_DARK, 1.0)
				x = x1
				k += 1
			draw_line(_p(0, y1) + up, _p(f.x, y1) + up, FLAG_DARK, 1.0)
		# Kerb: a band of lighter stone just inside the edge.
		var kerb := 0.12
		for edge: Array in [[Vector2(0, 0), Vector2(f.x, 0)], [Vector2(0, 0), Vector2(0, f.y)],
				[Vector2(f.x, 0), Vector2(f.x, f.y)], [Vector2(0, f.y), Vector2(f.x, f.y)]]:
			var a: Vector2 = edge[0]
			var b: Vector2 = edge[1]
			var inward := (f * 0.5 - (a + b) * 0.5).sign() * Vector2(1 if a.x == b.x else 0, 1 if a.y == b.y else 0)
			draw_colored_polygon(PackedVector2Array([_p(a.x, a.y) + up, _p(b.x, b.y) + up,
					_p(b.x + inward.x * kerb, b.y + inward.y * kerb) + up, _p(a.x + inward.x * kerb, a.y + inward.y * kerb) + up]),
					KERB)


func _init() -> void:
	y_sort_enabled = true


func setup(state: BuildingState) -> void:
	building = state
	var yard := _Yard.new()
	yard.footprint = state.def.footprint
	yard.stone = state.def.is_port_storage()
	yard.position = IsoMath.grid_to_screen(Vector2(state.origin))
	# Ground decal: below everything that stands in the y-sorted world.
	yard.z_index = -1
	add_child(yard)
	for slot: int in state.stock.slot_count():
		var sprite := StackSprite.new()
		var tile := state.origin + StockpileLayout.slot_tile(slot, state.def.footprint,
				state.def.entrance_at(state.orientation))
		sprite.position = IsoMath.tile_center_screen(tile)
		add_child(sprite)
		_stacks.append(sprite)


func update_view() -> void:
	for slot: int in _stacks.size():
		var visual := StockpileLayout.visual_for(building.stock, slot)
		_stacks[slot].show_stack(visual["good"], visual["amount"], visual["stack_size"])
