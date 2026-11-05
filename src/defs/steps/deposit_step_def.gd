class_name DepositStepDef
extends StepDef
## Put what the worker carries into the workplace's private input store (first input of a
## two-input recipe, e.g. grain for the brewery), standing at its entrance.


func get_step_kind() -> StringName:
	return &"deposit"
