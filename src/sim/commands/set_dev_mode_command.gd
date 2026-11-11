class_name SetDevModeCommand
extends Command
## Switches the developer mode on or off (ROADMAP E4 part 1, F12 in a game): a full treasury,
## free and instant building, and residents who never leave (Simulation.dev_mode).

var on: bool


func _init(enabled: bool) -> void:
	on = enabled


func validate(_sim: Simulation) -> StringName:
	return &""


func apply(sim: Simulation) -> void:
	sim.set_dev_mode(on)


func get_name() -> StringName:
	return &"set_dev_mode"
