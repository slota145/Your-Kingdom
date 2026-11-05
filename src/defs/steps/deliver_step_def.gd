class_name DeliverStepDef
extends StepDef
## Reserve space in the nearest storage accepting the carried good, walk there and put it down.
## With [member drop_on_fail] the goods are put on the ground when no storage can take them.

@export var drop_on_fail: bool = false


func get_step_kind() -> StringName:
	return &"deliver"
