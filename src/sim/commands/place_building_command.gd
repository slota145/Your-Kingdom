class_name PlaceBuildingCommand
extends Command
## Opens a construction site for a building (GDD §5.1). [member instant] skips construction
## (map start, tests, prototypes).

var def_id: StringName
var origin: Vector2i
var instant: bool


func _init(building_id: StringName, at: Vector2i, finished: bool = false) -> void:
	def_id = building_id
	origin = at
	instant = finished


func validate(sim: Simulation) -> StringName:
	return sim.province.placement_error(sim.data.get_building(def_id), origin)


func apply(sim: Simulation) -> void:
	sim.province.add_building(sim.data.get_building(def_id), origin, instant)


func get_name() -> StringName:
	return &"place_building"
