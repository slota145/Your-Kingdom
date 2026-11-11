class_name HuntStepDef
extends StepDef
## The hunter's chase (E2 part 2): pick the nearest wild herd within the lodge's work radius,
## creep up to [member shot_range] tiles of it, aim, shoot one animal (the rest flees), walk to
## it and lift the carcass ([member carcass]) on his shoulders.

@export var carcass: StringName = &"game"
## Tiles from the herd the hunter shoots from.
@export_range(1, 10) var shot_range: int = 3
@export_range(0.1, 30.0) var aim_time: float = 2.0
@export_range(0.1, 30.0) var pick_time: float = 2.0


func get_step_kind() -> StringName:
	return &"hunt"
