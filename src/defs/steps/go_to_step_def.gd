class_name GoToStepDef
extends StepDef
## Walk somewhere. Targets: &"workplace" (its entrance) or &"resource" (claims the nearest
## node of [member resource] within the workplace's work radius and walks next to it).

@export var target: StringName = &"workplace"
## Resource node id, used when [member target] is &"resource".
@export var resource: StringName = &""


func get_step_kind() -> StringName:
	return &"go_to"
