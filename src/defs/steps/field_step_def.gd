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
## E1 part 2: units harvested per tile on average above [member harvest_amount] (the whole field
## grows together and waits for the last sown tile, so each tile gives more): 0.5 = every
## second tile one unit more. The farm keeps the fraction (BuildingState.field_yield_carry).
@export_range(0.0, 9.0) var harvest_extra: float = 0.0
## E1 part 2: seconds of weeding one growing tile while the field grows.
@export_range(0.1, 60.0) var weed_time: float = 6.0
## Seconds to wait when there is nothing to do.
@export_range(0.1, 60.0) var idle_time: float = 2.0


func get_step_kind() -> StringName:
	return &"field"
