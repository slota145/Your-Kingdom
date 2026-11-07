class_name QuayYard
extends Node2D
## The quay yard of a port (M5 part 2): planked ground on the land tiles of the port, drawn
## under everything (the port art leaves it see-through; its quay over the water is the
## QuayLayer's, N1), and the stacks of goods waiting
## there, one per slot, from the same Stockpile as the building panel (ARCHITECTURE §6.5).
## Child of the y-sorted world.

const GROUND := Color(0.5, 0.4, 0.3)
const PLANK_LINE := Color(0.4, 0.31, 0.22)
const EDGE := Color(0.33, 0.25, 0.17)

var building: BuildingState
var _stacks: Array[StackSprite] = []


class _Ground:
	extends Node2D
	var tiles: Array[Vector2i] = []

	func _draw() -> void:
		for tile: Vector2i in tiles:
			var corners := PackedVector2Array()
			for p: Vector2 in [Vector2(tile), Vector2(tile + Vector2i(1, 0)), Vector2(tile + Vector2i(1, 1)),
					Vector2(tile + Vector2i(0, 1))]:
				corners.append(IsoMath.grid_to_screen(p))
			draw_colored_polygon(corners, GROUND)
			# Planks across the tile.
			for k: int in range(1, 4):
				var a := IsoMath.grid_to_screen(Vector2(tile) + Vector2(k / 4.0, 0.0))
				var b := IsoMath.grid_to_screen(Vector2(tile) + Vector2(k / 4.0, 1.0))
				draw_line(a, b, PLANK_LINE, 1.0)
			corners.append(corners[0])
			draw_polyline(corners, EDGE, 1.0)


func _init() -> void:
	y_sort_enabled = true


## Land tiles of [param port] (as placed), where its quay yard is.
static func land_tiles(port: BuildingState) -> Array[Vector2i]:
	var water := port.def.water_tiles_at(port.origin, port.orientation)
	var tiles: Array[Vector2i] = []
	for tile: Vector2i in port.tiles():
		if not water.has(tile):
			tiles.append(tile)
	return tiles


## Tile of slot [param slot] of the quay yard of [param port]: the land tiles row by row as
## drawn, skipping the entrance, turned with the building.
static func slot_tile(port: BuildingState, slot: int) -> Vector2i:
	var drawn := StockpileLayout.slot_tile(slot, port.def.footprint, port.def.entrance)
	return port.origin + port.def.turned(drawn, port.orientation)


func setup(state: BuildingState) -> void:
	building = state
	var ground := _Ground.new()
	ground.tiles = land_tiles(state)
	# Ground decals: below everything that stands in the y-sorted world.
	ground.z_index = -1
	add_child(ground)
	if state.stock == null:
		return
	for slot: int in state.stock.slot_count():
		var sprite := StackSprite.new()
		sprite.position = IsoMath.tile_center_screen(slot_tile(state, slot))
		add_child(sprite)
		_stacks.append(sprite)


func update_view() -> void:
	if building.stock == null:
		return
	for slot: int in _stacks.size():
		var visual := StockpileLayout.visual_for(building.stock, slot)
		_stacks[slot].show_stack(visual["good"], visual["fill_stage"])
