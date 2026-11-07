class_name SoldierStepDef
extends StepDef
## A soldier at home: in the ranks on the parade ground, drilling with the others, or
## resting inside the barracks (M7). Never ends on its own.


func get_step_kind() -> StringName:
	return &"soldier"
