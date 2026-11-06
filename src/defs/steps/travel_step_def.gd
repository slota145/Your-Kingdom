class_name TravelStepDef
extends StepDef
## Walking (or driving the settlers' wagon) to the tile in the blackboard ("to") for an
## expedition of settlers (M6 part 2). Built in code.


func get_step_kind() -> StringName:
	return &"travel"
