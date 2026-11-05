class_name SetPriorityCommand
extends Command
## Sets a workplace's work priority (GDD §3.4): high, normal or low.

var building_id: int
var priority: int


func _init(building: int, value: int) -> void:
	building_id = building
	priority = value


func validate(sim: Simulation) -> StringName:
	var building := sim.province.buildings.get_building(building_id)
	if building == null:
		return &"unknown_building"
	if building.def.worker_count() == 0:
		return &"no_worker_slot"
	if priority < BuildingState.Priority.HIGH or priority > BuildingState.Priority.LOW:
		return &"invalid_value"
	return &""


func apply(sim: Simulation) -> void:
	sim.province.buildings.get_building(building_id).priority = priority as BuildingState.Priority
	sim.events.emit(&"priority_changed", {"building": building_id, "priority": priority})


func get_name() -> StringName:
	return &"set_priority"
