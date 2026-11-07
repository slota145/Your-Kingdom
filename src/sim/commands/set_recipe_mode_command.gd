class_name SetRecipeModeCommand
extends Command
## Chooses what a workshop with several work cycles makes (a blacksmith: spears, swords or
## each in turn; M7, owner's decision 2026-11-07). -1 = take turns.

var building_id: int
var mode: int


func _init(building: int, value: int) -> void:
	building_id = building
	mode = value


func validate(sim: Simulation) -> StringName:
	var building := sim.province.buildings.get_building(building_id)
	if building == null:
		return &"unknown_building"
	if building.def.recipe_choices.is_empty():
		return &"no_production"
	if mode < -1 or mode >= building.def.recipe_choices.size():
		return &"bad_choice"
	return &""


func apply(sim: Simulation) -> void:
	sim.province.buildings.get_building(building_id).recipe_mode = mode
	sim.events.emit(&"recipe_mode_changed", {"building": building_id, "mode": mode})


func get_name() -> StringName:
	return &"set_recipe_mode"
