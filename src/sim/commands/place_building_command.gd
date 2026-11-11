class_name PlaceBuildingCommand
extends Command
## Opens a construction site for a building (GDD §5.1). [member instant] skips construction
## (map start, tests, prototypes), and so does the developer mode (E4 part 1).

var def_id: StringName
var origin: Vector2i
var instant: bool
## Which way the building is turned (BuildingDef.entrance_at).
var orientation: int
## Look chosen by the player (BuildingState.look), 0 = by position.
var look: int


func _init(building_id: StringName, at: Vector2i, finished: bool = false, turned: int = 0,
		chosen_look: int = 0) -> void:
	def_id = building_id
	origin = at
	instant = finished
	orientation = turned
	look = chosen_look


func validate(sim: Simulation) -> StringName:
	var def := sim.data.get_building(def_id)
	var error := sim.province.placement_error(def, origin, orientation)
	if error == &"" and not instant:
		error = research_error(sim.province, def)
	if error == &"" and not _instant(sim) and not sim.treasury.can_pay(def.gold_cost):
		return &"not_enough_gold"
	return error


func apply(sim: Simulation) -> void:
	sim.province.add_building(sim.data.get_building(def_id), origin, _instant(sim), orientation, look)


## Why the player may not build [param def] in [param province] yet (E4 part 2), or &"": a
## research it needs, or the house its level asks for (the school after the first burghers).
static func research_error(province: ProvinceSim, def: BuildingDef) -> StringName:
	if def == null:
		return &""
	if not province.research.allows_building(province.data, def.id):
		return &"needs_research"
	if def.needs_house_level > 1 and not province.has_house_level(def.needs_house_level):
		return &"needs_burghers" if def.needs_house_level == 2 else &"needs_patricians"
	return &""


## Instant also in the developer mode in the player's province (E4 part 1): free, no site.
func _instant(sim: Simulation) -> bool:
	return instant or sim.province.dev_mode


func get_name() -> StringName:
	return &"place_building"
