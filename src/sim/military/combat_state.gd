class_name CombatState
extends RefCounted
## A soldier's fighting state (ARCHITECTURE §10, M7): life, the enemy he aims at and the wait
## before his next blow. Part 1 only keeps the life; fighting comes in M7 part 2.

var hp: int = 0
## Agent id of the target, 0 = none.
var target_id: int = 0
## Ticks before the next attack.
var cooldown: int = 0


func _init(life: int = 0) -> void:
	hp = life


func to_dict() -> Dictionary:
	var d := {"hp": hp}
	if target_id != 0:
		d["target"] = target_id
	if cooldown != 0:
		d["cooldown"] = cooldown
	return d


static func from_dict(d: Dictionary) -> CombatState:
	var state := CombatState.new(int(d.get("hp", 0)))
	state.target_id = int(d.get("target", 0))
	state.cooldown = int(d.get("cooldown", 0))
	return state
