class_name FieldStepDef
extends StepDef
## Farm work on the farm's field tiles (GDD §4.4): the farmer picks the most urgent job
## (harvest a ripe tile, sow a ploughed one, plough an empty one), walks there and does it.
## A harvest leaves the farmer carrying a sheaf of [member harvest_good].

@export var harvest_good: StringName = &"grain"
@export_range(1, 99) var harvest_amount: int = 1
@export_range(0.1, 600.0) var plow_time: float = 3.0
@export_range(0.1, 600.0) var sow_time: float = 2.0
@export_range(0.1, 600.0) var harvest_time: float = 3.0
@export_range(0.1, 600.0) var bind_time: float = 2.0
## Seconds to wait when there is nothing to do.
@export_range(0.1, 60.0) var idle_time: float = 2.0


func get_step_kind() -> StringName:
	return &"field"
