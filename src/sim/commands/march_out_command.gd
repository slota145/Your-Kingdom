class_name MarchOutCommand
extends Command
## The player's soldiers leave the viewed province for the world map (M7 part 3): in his own
## province they form a new army that stands by the town; soldiers of an army fighting in a
## settlement go back to it at the border (a retreat).

var ids: Array[int]


func _init(soldier_ids: Array[int]) -> void:
	ids = soldier_ids


func _soldiers(sim: Simulation, of_army: bool) -> Array[Agent]:
	var result: Array[Agent] = []
	for id: int in ids:
		var agent := sim.province.agents.get_agent(id)
		if Troops.is_soldier(sim.province, agent) and (agent.combat.army != 0) == of_army \
				and agent.combat.order != CombatState.Order.MARCH:
			result.append(agent)
	return result


func validate(sim: Simulation) -> StringName:
	if not _soldiers(sim, true).is_empty():
		return &""
	return Armies.march_error(sim, _soldiers(sim, false))


func apply(sim: Simulation) -> void:
	var retreating := _soldiers(sim, true)
	var armies: Dictionary[int, Array] = {}
	for agent: Agent in retreating:
		if not armies.has(agent.combat.army):
			armies[agent.combat.army] = []
		armies[agent.combat.army].append(agent)
	for army_id: int in armies:
		var army := sim.world.armies.get(army_id) as Army
		var agents: Array[Agent] = []
		agents.assign(armies[army_id])
		var exit := army.entry if army != null and army.entry.x >= 0 \
				else Armies.exit_tile(sim.province, agents[0].tile(), CombatState.PLAYER)
		Troops.order_march(sim.province, agents, army_id, exit)
	var leaving := _soldiers(sim, false)
	if not leaving.is_empty() and Armies.march_error(sim, leaving) == &"":
		Armies.march_out(sim, leaving)


func get_name() -> StringName:
	return &"march_out"
