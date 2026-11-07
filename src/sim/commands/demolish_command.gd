class_name DemolishCommand
extends Command
## Removes a building at once. Its goods go on the ground and are carried away by porters.

var building_id: int


func _init(id: int) -> void:
	building_id = id


func validate(sim: Simulation) -> StringName:
	var building := sim.province.buildings.get_building(building_id)
	if building == null:
		return &"unknown_building"
	# Soldiers live in their barracks (M7): it stands while it has any.
	if building.def.soldier_beds > 0 and Barracks.beds_taken(building) > 0:
		return &"barracks_has_soldiers"
	return &""


func apply(sim: Simulation) -> void:
	sim.province.remove_building(building_id)


func get_name() -> StringName:
	return &"demolish"
