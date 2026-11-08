class_name RecruitCommand
extends Command
## Recruits a soldier in a barracks (GDD §6.1, M7): a free resident leaves his house, takes
## his gear from the armoury (and a horse from a stud farm) and moves into the barracks.

var building_id: int
var unit_id: StringName


func _init(building: int, unit: StringName) -> void:
	building_id = building
	unit_id = unit


func validate(sim: Simulation) -> StringName:
	var province := sim.province
	return Barracks.recruit_error(province, province.buildings.get_building(building_id),
			province.data.get_unit(unit_id))


func apply(sim: Simulation) -> void:
	var province := sim.province
	Barracks.recruit(province, province.buildings.get_building(building_id),
			province.data.get_unit(unit_id))


func get_name() -> StringName:
	return &"recruit"
