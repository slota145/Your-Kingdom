class_name FieldBattleCommand
extends Command
## The player chooses how his army fights the enemy it met in the field (M8 part 2): on the
## battlefield (LIVE) or at once (AUTO); RETREAT calls his men off the battlefield.

const RETREAT := &"retreat"

var battle_id: int
var mode: StringName


func _init(battle: int, how: StringName) -> void:
	battle_id = battle
	mode = how


func validate(sim: Simulation) -> StringName:
	if mode == RETREAT:
		return FieldBattles.retreat_error(sim)
	return FieldBattles.choose_error(sim, battle_id, mode)


func apply(sim: Simulation) -> void:
	if mode == RETREAT:
		FieldBattles.retreat(sim)
	else:
		FieldBattles.choose(sim, battle_id, mode)


func get_name() -> StringName:
	return &"field_battle"
