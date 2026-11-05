class_name RemoveFieldCommand
extends Command
## Turns a field tile back into plain ground.

var tile: Vector2i


func _init(at: Vector2i) -> void:
	tile = at


func validate(sim: Simulation) -> StringName:
	return &"" if sim.province.fields.has_field(tile) else &"no_field"


func apply(sim: Simulation) -> void:
	sim.province.remove_field(tile)


func get_name() -> StringName:
	return &"remove_field"
