class_name SetStanceCommand
extends Command
## How the player's soldiers fight (M7 part 2): attack on sight, defend their place, or hold it.

var ids: Array[int]
var stance: int


func _init(soldier_ids: Array[int], new_stance: int) -> void:
	ids = soldier_ids
	stance = new_stance


func validate(sim: Simulation) -> StringName:
	if stance < 0 or stance > CombatState.Stance.HOLD:
		return &"bad_stance"
	for id: int in ids:
		if Troops.is_soldier(sim.province, sim.province.agents.get_agent(id)):
			return &""
	return &"no_soldiers"


func apply(sim: Simulation) -> void:
	var soldiers: Array[Agent] = []
	for id: int in ids:
		var agent := sim.province.agents.get_agent(id)
		if Troops.is_soldier(sim.province, agent):
			soldiers.append(agent)
	Troops.set_stance(soldiers, stance as CombatState.Stance)


func get_name() -> StringName:
	return &"set_stance"
