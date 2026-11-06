class_name BuildPavingCommand
extends Command
## Orders cobbles on tiles (GDD §5.2, M4b-3): 1 stone per tile, laid by a builder. Dirt road
## or free ground; free ground becomes dirt road at once. Tiles that cannot be paved are
## skipped; the command is rejected only when none can.

var tiles: Array[Vector2i]


func _init(paving_tiles: Array[Vector2i]) -> void:
	tiles = paving_tiles


func validate(sim: Simulation) -> StringName:
	var error := &"no_tiles"
	for tile: Vector2i in tiles:
		error = sim.province.paving_error(tile)
		if error == &"":
			return &""
	return error


func apply(sim: Simulation) -> void:
	var ordered: Array[Vector2i] = []
	var new_road: Array[Vector2i] = []
	for tile: Vector2i in tiles:
		if not ordered.has(tile) and sim.province.paving_error(tile) == &"":
			if not sim.province.grid.has_road(tile):
				new_road.append(tile)
			ordered.append(tile)
	sim.province.order_paving(ordered)
	sim.province.turn_houses_to_road(new_road)


func get_name() -> StringName:
	return &"build_paving"
