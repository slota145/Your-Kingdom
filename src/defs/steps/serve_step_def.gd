class_name ServeStepDef
extends StepDef
## A service worker uses up goods from the workplace's input store (a tavern pours beer and
## mead). The service then reaches houses for [member hold] seconds (GDD §3.2, M4b-1).

@export var consume: Dictionary[StringName, int] = {}
## Seconds the service keeps working after one serving.
@export_range(1.0, 3600.0) var hold: float = 90.0


func get_step_kind() -> StringName:
	return &"serve"
