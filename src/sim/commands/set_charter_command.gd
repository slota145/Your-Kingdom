class_name SetCharterCommand
extends Command
## Gives a farm, an orchard, a vineyard or a herd its charter, or takes it back (ROADMAP E4
## part 3, "Nadanie", owner's idea 2026-11-11): its fields, pens or hives ×2 and a second
## worker. Needs the research with ResearchDef.charter. Tiles beyond the limit stay when it is
## taken back (as with pens, Z1); the second worker goes home.

var building_id: int
var on: bool


func _init(building: int, enabled: bool) -> void:
	building_id = building
	on = enabled


func validate(sim: Simulation) -> StringName:
	var building := sim.province.buildings.get_building(building_id)
	if building == null:
		return &"unknown_building"
	if not building.can_have_charter():
		return &"no_charter_here"
	if on and not sim.province.research.allows_charter(sim.data):
		return &"needs_research"
	return &""


func apply(sim: Simulation) -> void:
	var building := sim.province.buildings.get_building(building_id)
	building.charter = on
	if building.def.has_pens():
		sim.province.update_herd_room(building)
	sim.events.emit(&"charter_changed", {"building": building_id, "on": on})


func get_name() -> StringName:
	return &"set_charter"
