class_name FleetOutCommand
extends Command
## All free warships of the player's province go out to the world map as a fleet (M8 part 2,
## the province's panel on the world map), with the soldiers aboard.

var province_id: int


func _init(id: int) -> void:
	province_id = id


func validate(sim: Simulation) -> StringName:
	return Fleets.fleet_out_error(sim, province_id)


func apply(sim: Simulation) -> void:
	Fleets.fleet_out(sim, province_id)


func get_name() -> StringName:
	return &"fleet_out"
