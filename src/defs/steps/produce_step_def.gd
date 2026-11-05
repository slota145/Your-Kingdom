class_name ProduceStepDef
extends StepDef
## Turn what the worker carries (the recipe input) into the output good.

@export var output: StringName = &""
@export_range(1, 99) var amount: int = 1


func get_step_kind() -> StringName:
	return &"produce"
