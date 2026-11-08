class_name RemoveWallCommand
extends Command
## Pulls down a wall tile or stairs (M7 part 2); part of the material goes on the ground.

var tile: Vector2i


func _init(at: Vector2i) -> void:
	tile = at


func validate(sim: Simulation) -> StringName:
	return sim.province.remove_wall_error(tile)


func apply(sim: Simulation) -> void:
	sim.province.remove_wall(tile)


func get_name() -> StringName:
	return &"remove_wall"
