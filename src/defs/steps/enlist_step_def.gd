class_name EnlistStepDef
extends StepDef
## A recruit fetches his gear (armoury, stud farm) and moves into his barracks (M7).


func get_step_kind() -> StringName:
	return &"enlist"
