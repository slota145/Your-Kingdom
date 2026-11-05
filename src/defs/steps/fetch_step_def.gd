class_name FetchStepDef
extends StepDef
## Reserve goods in the nearest storage holding them, walk there and pick them up.

@export var good: StringName = &""
@export_range(1, 99) var amount: int = 1


func get_step_kind() -> StringName:
	return &"fetch"
