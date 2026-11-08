class_name OrderTroopsCommand
extends Command
## The player's order to his soldiers (M7 part 2, GDD §8): go to a place (on the ground or on
## the wall-walk) in formation, attack an enemy, or go back to the ranks of their barracks;
## M7 part 3: break an enemy's wall, gate or town hall door (BREAK; what stands in the way
## first).

const MOVE := &"move"
const ATTACK := &"attack"
const RETURN := &"return"
const BREAK := &"break"

var ids: Array[int]
var order: StringName
var tile: Vector2i
## 0 ground, 1 wall-walk.
var level: int
var target_id: int


func _init(soldier_ids: Array[int], what: StringName, at: Vector2i = Vector2i(-1, -1), on_level: int = 0,
		target: int = 0) -> void:
	ids = soldier_ids
	order = what
	tile = at
	level = on_level
	target_id = target


func _soldiers(sim: Simulation) -> Array[Agent]:
	var result: Array[Agent] = []
	for id: int in ids:
		var agent := sim.province.agents.get_agent(id)
		if Troops.is_soldier(sim.province, agent):
			result.append(agent)
	return result


func validate(sim: Simulation) -> StringName:
	if _soldiers(sim).is_empty():
		return &"no_soldiers"
	match order:
		MOVE:
			if Troops.formation(sim.province, tile, level, 1, CombatState.PLAYER).is_empty():
				return &"cannot_go_there"
		ATTACK:
			var target := sim.province.agents.get_agent(target_id)
			if target == null or target.combat == null or target.combat.faction == CombatState.PLAYER:
				return &"not_an_enemy"
		RETURN:
			pass
		BREAK:
			if sim.province.home_faction == CombatState.PLAYER:
				return &"not_an_enemy"
			if not Troops.structure_standing(sim.province, tile):
				return &"nothing_to_break"
		_:
			return &"bad_order"
	return &""


func apply(sim: Simulation) -> void:
	var soldiers := _soldiers(sim)
	match order:
		MOVE:
			Troops.order_move(sim.province, soldiers, tile, level)
		ATTACK:
			Troops.order_attack(soldiers, sim.province.agents.get_agent(target_id))
		RETURN:
			Troops.order_return(sim.province, soldiers)
		BREAK:
			Troops.order_break(sim.province, soldiers, tile)


func get_name() -> StringName:
	return &"order_troops"
