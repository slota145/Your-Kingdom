class_name SetPausedCommand
extends Command
## Pauses or resumes production of a workplace (ROADMAP M4b-1). Its workers stay, finish the
## cycle they are in and do not start a new one until resumed.

var building_id: int
var paused: bool


func _init(building: int, value: bool) -> void:
	building_id = building
	paused = value


func validate(sim: Simulation) -> StringName:
	var building := sim.province.buildings.get_building(building_id)
	if building == null:
		return &"unknown_building"
	if building.def.recipe == null:
		return &"no_production"
	return &""


func apply(sim: Simulation) -> void:
	sim.province.buildings.get_building(building_id).paused = paused
	sim.events.emit(&"paused_changed", {"building": building_id, "paused": paused})


func get_name() -> StringName:
	return &"set_paused"
