class_name RecipeDef
extends GameDef
## The work cycle of a building's worker: an ordered list of visible steps (ARCHITECTURE §5.2).

@export var steps: Array[StepDef] = []


func get_kind() -> StringName:
	return &"recipe"
