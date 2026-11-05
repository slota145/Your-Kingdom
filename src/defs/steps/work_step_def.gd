class_name WorkStepDef
extends StepDef
## Stand and do visible work for a while (chop, knead, bake...).

## Activity shown by the view, selects the work_<activity> animation.
@export var activity: StringName = &"work"
## Duration in seconds of game time.
@export_range(0.1, 600.0) var duration: float = 1.0
## Named work spot of the building (&"oven"); empty = where the worker stands.
@export var spot: StringName = &""


func get_step_kind() -> StringName:
	return &"work"
