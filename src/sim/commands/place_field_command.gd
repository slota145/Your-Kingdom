class_name PlaceFieldCommand
extends Command
## Adds one 1x1 field tile to a farm (ROADMAP M3 decisions: fields are placed separately).

var farm_id: int
var tile: Vector2i


func _init(farm: int, at: Vector2i) -> void:
	farm_id = farm
	tile = at


func validate(sim: Simulation) -> StringName:
	return sim.province.field_error(farm_id, tile)


func apply(sim: Simulation) -> void:
	sim.province.add_field(farm_id, tile)


func get_name() -> StringName:
	return &"place_field"
