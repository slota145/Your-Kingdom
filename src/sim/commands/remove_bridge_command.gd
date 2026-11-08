class_name RemoveBridgeCommand
extends Command
## Takes a whole bridge away, or the order for one not finished yet (B1).

var tile: Vector2i


func _init(at: Vector2i) -> void:
	tile = at


func validate(sim: Simulation) -> StringName:
	return sim.province.remove_bridge_error(tile)


func apply(sim: Simulation) -> void:
	sim.province.remove_bridge(tile)


func get_name() -> StringName:
	return &"remove_bridge"
