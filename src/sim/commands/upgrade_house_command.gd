class_name UpgradeHouseCommand
extends Command
## "Upgrade now" (E1, owner 2026-11-10): a house that meets the conditions of its next level
## starts the upgrade at once instead of after Population.UPGRADE_AFTER seconds. The upgrade
## site still waits for its materials like an automatic one.

var building_id: int


func _init(building: int) -> void:
	building_id = building


func validate(sim: Simulation) -> StringName:
	var building := sim.province.buildings.get_building(building_id)
	if building == null:
		return &"unknown_building"
	return Population.upgrade_blocker(sim.province, building)


func apply(sim: Simulation) -> void:
	var building := sim.province.buildings.get_building(building_id)
	if Population.upgrade_now(sim.province, building):
		sim.events.emit(&"house_upgrade_started", {"building": building_id})


func get_name() -> StringName:
	return &"upgrade_house"
