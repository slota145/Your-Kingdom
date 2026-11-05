class_name GatherStepDef
extends StepDef
## Take goods from the resource node claimed by an earlier GoToStepDef(&"resource").


func get_step_kind() -> StringName:
	return &"gather"
