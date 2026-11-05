class_name RotateBuildingCommand
extends Command
## Turns a placed building to its next orientation that keeps a usable door (M4b-1.5,
## "Turn" in the building panel).

var building_id: int


func _init(building: int) -> void:
	building_id = building


func validate(sim: Simulation) -> StringName:
	var building := sim.province.buildings.get_building(building_id)
	if building == null:
		return &"unknown_building"
	return &"" if next_orientation(sim.province, building) >= 0 else &"cannot_turn"


func apply(sim: Simulation) -> void:
	var building := sim.province.buildings.get_building(building_id)
	sim.province.turn_building(building, next_orientation(sim.province, building))


## The next orientation (in order) the building can be turned to, or -1.
static func next_orientation(province: ProvinceSim, building: BuildingState) -> int:
	var count := building.def.orientation_count()
	for i: int in range(1, count):
		var o := (building.orientation + i) % count
		if province.can_turn(building, o):
			return o
	return -1


func get_name() -> StringName:
	return &"rotate_building"
