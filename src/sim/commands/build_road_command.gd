class_name BuildRoadCommand
extends Command
## Lays dirt road on tiles (GDD §5.2): free and instant in M3. Tiles that cannot take a road
## are skipped; the command is rejected only when none can.

var tiles: Array[Vector2i]


func _init(road_tiles: Array[Vector2i]) -> void:
	tiles = road_tiles


func validate(sim: Simulation) -> StringName:
	var error := &"no_tiles"
	for tile: Vector2i in tiles:
		error = sim.province.road_error(tile)
		if error == &"":
			return &""
	return error


func apply(sim: Simulation) -> void:
	var built: Array[Vector2i] = []
	for tile: Vector2i in tiles:
		if sim.province.road_error(tile) == &"":
			sim.province.set_road(tile, true)
			built.append(tile)
	sim.province.turn_houses_to_road(built)


func get_name() -> StringName:
	return &"build_road"
