class_name ChooseStallStepDef
extends StepDef
## A stallholder picks what to bring to the market's stalls next (M4b-2): the stall good that
## is lowest and can be had from a storage. Later steps fetch it (blackboard "good" and
## "amount") and put it on the stalls (the market's store).

## Units fetched per trip at most.
@export_range(1, 9) var load: int = 2


func get_step_kind() -> StringName:
	return &"choose_stall"
