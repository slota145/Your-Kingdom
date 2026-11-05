class_name PlaceBuildingCommand
extends Command
## Opens a construction site for a building (GDD §5.1). [member instant] skips construction
## (map start, tests, prototypes).

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
	if error == &"" and not instant and not sim.treasury.can_pay(def.gold_cost):
		return &"not_enough_gold"
	return error


func apply(sim: Simulation) -> void:
	sim.province.add_building(sim.data.get_building(def_id), origin, instant, orientation, look)


func get_name() -> StringName:
	return &"place_building"
