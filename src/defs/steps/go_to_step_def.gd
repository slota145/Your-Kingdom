class_name GoToStepDef
extends StepDef
## Walk somewhere. Targets: &"workplace" (its entrance), &"resource" (claims the nearest
## node of [member resource] within the workplace's work radius and walks next to it) or
## &"shore" (the nearest free walkable tile next to the workplace's needs_terrain_near terrain)
## or &"plant_spot" (a depleted [member resource] node or free ground in the work radius, for
## a forester; it walks next to it) or &"pen" (a pen tile of the workplace, Z1) or &"hive" (beside a hive of the workplace, Z1
## part 3; the worker faces it).

@export var target: StringName = &"workplace"
## Resource node id, used when [member target] is &"resource".
@export var resource: StringName = &""


func get_step_kind() -> StringName:
	return &"go_to"
