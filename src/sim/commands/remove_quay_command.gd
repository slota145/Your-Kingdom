class_name RemoveQuayCommand
extends Command
## Takes a quay tile away, or the order for one not laid yet (N1).

var tile: Vector2i


func _init(at: Vector2i) -> void:
	tile = at


func validate(sim: Simulation) -> StringName:
	return sim.province.remove_quay_error(tile)


func apply(sim: Simulation) -> void:
	sim.province.remove_quay(tile)


func get_name() -> StringName:
	return &"remove_quay"
