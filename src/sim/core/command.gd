class_name Command
extends RefCounted
## Base class of every state change requested from outside the simulation (ARCHITECTURE §4.3).
##
## UI, AI and tests submit commands; the simulation applies them at the start of a tick.

## Returns &"" when the command can be applied, otherwise a reason id
## (used as the "ui.command_error.<reason>" localization key by the UI).
func validate(_sim: Simulation) -> StringName:
	return &""


func apply(_sim: Simulation) -> void:
	pass


## Short name for events and debugging, e.g. &"place_building".
func get_name() -> StringName:
	return &"command"
