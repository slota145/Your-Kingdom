class_name GatherStep
extends TaskStep
## Takes goods from the node claimed by GoToStep(&"resource"). A depleted node becomes walkable
## (a felled tree disappears with its stump, see ResourceNodeDef.remove_when_depleted).


func run(province: ProvinceSim, agent: Agent, _def: StepDef) -> Status:
	var bb := agent.task.bb
	if not bb.has("node"):
		return failed(agent, &"no_resource")
	var node := SimCodec.to_vec2i(bb["node"])
	var node_def := province.resources.def_at(node)
	if node_def == null or province.resources.claimant(node) != agent.id:
		return failed(agent, &"no_resource")
	if agent.is_carrying() and agent.carry_good != node_def.good:
		return failed(agent, &"hands_full")
	var taken := province.resources.take(node)
	if taken == 0:
		return failed(agent, &"no_resource")
	agent.carry_good = node_def.good
	agent.carry_amount += taken
	province.events.emit(&"good_gathered", {"agent": agent.id, "tile": node, "good": node_def.good,
			"amount": taken})
	if province.resources.is_depleted(node):
		agent.claimed_node = Agent.NO_TILE
		if node_def.remove_when_depleted:
			province.resources.clear(node)
		province.refresh_tile(node)
		province.events.emit(&"resource_depleted", {"tile": node, "node": node_def.id})
	return Status.DONE
