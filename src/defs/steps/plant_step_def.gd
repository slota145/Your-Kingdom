class_name PlantStepDef
extends StepDef
## Plant a young [member sapling] node on the tile chosen by an earlier
## GoToStepDef(&"plant_spot") (blackboard "node"). It grows into its grown form over time.

@export var sapling: StringName = &"sapling"


func get_step_kind() -> StringName:
	return &"plant"
