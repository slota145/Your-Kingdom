class_name StockpileView
extends Node2D
## A stockpile yard: the ground of the footprint plus one stack per slot. The stacks come
## from StockpileLayout over the same slots the UI lists (ARCHITECTURE §6.5).
## Child of the y-sorted world.

const YARD_COLOR := Color(0.55, 0.45, 0.32)
const YARD_EDGE := Color(0.4, 0.31, 0.2)

var building: BuildingState
var _stacks: Array[StackSprite] = []


class _Yard:
	extends Node2D
	var footprint: Vector2i

	func _draw() -> void:
		var corners := PackedVector2Array()
		for p: Vector2 in [Vector2.ZERO, Vector2(footprint.x, 0), Vector2(footprint), Vector2(0, footprint.y)]:
			corners.append(IsoMath.grid_to_screen(p))
		draw_colored_polygon(corners, YARD_COLOR)
		corners.append(corners[0])
		draw_polyline(corners, YARD_EDGE, 2.0)


func _init() -> void:
	y_sort_enabled = true


func setup(state: BuildingState) -> void:
	building = state
	var yard := _Yard.new()
	yard.footprint = state.def.footprint
	yard.position = IsoMath.grid_to_screen(Vector2(state.origin))
	# Ground decal: below everything that stands in the y-sorted world.
	yard.z_index = -1
	add_child(yard)
	for slot: int in state.stock.slot_count():
		var sprite := StackSprite.new()
		var tile := state.origin + StockpileLayout.slot_tile(slot, state.def.footprint, state.def.entrance)
		sprite.position = IsoMath.tile_center_screen(tile)
		add_child(sprite)
		_stacks.append(sprite)


func update_view() -> void:
	for slot: int in _stacks.size():
		var visual := StockpileLayout.visual_for(building.stock, slot)
		_stacks[slot].show_stack(visual["good"], visual["fill_stage"])
