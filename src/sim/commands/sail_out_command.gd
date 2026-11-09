class_name SailOutCommand
extends Command
## A warship of the viewed province sails to the edge of the map and joins the province's
## fleet on the world map (M8 part 2, the ship's panel), with the soldiers aboard.

var ship_id: int


func _init(id: int) -> void:
	ship_id = id


func validate(sim: Simulation) -> StringName:
	return Fleets.sail_out_error(sim, ship_id)


func apply(sim: Simulation) -> void:
	Fleets.sail_out(sim, ship_id)


func get_name() -> StringName:
	return &"sail_out"
