class_name SailStepDef
extends StepDef
## Sail the workplace's ship (M5). Targets: &"shoal" (board the boat at its berth, fetching
## it first from the shipyard where it was launched, claim the nearest shoal of
## [member resource] and sail onto it) or &"home" (sail back to the workplace's berth and
## go ashore).

@export var target: StringName = &"shoal"
## Resource node id of the shoal, used when [member target] is &"shoal".
@export var resource: StringName = &"fish_shoal"


func get_step_kind() -> StringName:
	return &"sail"
