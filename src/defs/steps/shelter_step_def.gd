class_name ShelterStepDef
extends StepDef
## Hiding from bandits: off to the town hall (or the pioneer camp) and in, out again when the
## raid is over (M7 part 2).


func get_step_kind() -> StringName:
	return &"shelter"
