class_name StepDef
extends Resource
## One step of a work cycle. Pure data: the simulation executes it (src/sim/agents/steps).


## Executor key, e.g. &"go_to". Subclasses must override.
func get_step_kind() -> StringName:
	return &""
