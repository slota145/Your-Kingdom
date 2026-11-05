class_name DemolishCommand
extends Command
## Removes a building at once. Its goods go on the ground and are carried away by porters.

var building_id: int


func _init(id: int) -> void:
	building_id = id


func validate(sim: Simulation) -> StringName:
	return &"" if sim.province.buildings.has_building(building_id) else &"unknown_building"


func apply(sim: Simulation) -> void:
	sim.province.remove_building(building_id)


func get_name() -> StringName:
	return &"demolish"
