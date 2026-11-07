class_name CraneStepDef
extends StepDef
## The crane operator at his crane (N1 part 2): treads the wheel and lifts cargo, a few units
## at a time, between the quay yard and the ship at the berth the crane stands by.

## Activity shown by the view while the wheel turns (the operator walks inside it).
@export var activity: StringName = &"walk"


func get_step_kind() -> StringName:
	return &"crane"
