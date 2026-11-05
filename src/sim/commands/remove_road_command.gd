class_name RemoveRoadCommand
extends Command
## Removes road from tiles.

var tiles: Array[Vector2i]


func _init(road_tiles: Array[Vector2i]) -> void:
	tiles = road_tiles


func validate(sim: Simulation) -> StringName:
	for tile: Vector2i in tiles:
		if sim.province.grid.has_road(tile):
			return &""
	return &"no_road"


func apply(sim: Simulation) -> void:
	for tile: Vector2i in tiles:
		if sim.province.grid.has_road(tile):
			sim.province.set_road(tile, false)


func get_name() -> StringName:
	return &"remove_road"
