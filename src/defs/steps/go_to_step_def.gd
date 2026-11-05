class_name GoToStepDef
extends StepDef
## Walk somewhere. Targets: &"workplace" (its entrance), &"resource" (claims the nearest
## node of [member resource] within the workplace's work radius and walks next to it) or
## &"shore" (the nearest free walkable tile next to the workplace's needs_terrain_near terrain).

@export var target: StringName = &"workplace"
## Resource node id, used when [member target] is &"resource".
@export var resource: StringName = &""


func get_step_kind() -> StringName:
	return &"go_to"
