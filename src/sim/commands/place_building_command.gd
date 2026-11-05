class_name PlaceBuildingCommand
extends Command
## Places a building at once (physical construction arrives in M3).

var def_id: StringName
var origin: Vector2i


func _init(building_id: StringName, at: Vector2i) -> void:
	def_id = building_id
	origin = at


func validate(sim: Simulation) -> StringName:
	return sim.province.placement_error(sim.data.get_building(def_id), origin)


func apply(sim: Simulation) -> void:
	sim.province.add_building(sim.data.get_building(def_id), origin)


func get_name() -> StringName:
	return &"place_building"
