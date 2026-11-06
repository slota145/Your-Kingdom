class_name ShipBuildStepDef
extends StepDef
## A shipwright works on the ship on his shipyard's slipway (M5): starts the current stage
## when its materials are there and works until the stage is done.

## Activity shown by the view.
@export var activity: StringName = &"hammer"


func get_step_kind() -> StringName:
	return &"ship_build"
