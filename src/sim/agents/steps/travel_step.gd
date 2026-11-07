class_name TravelStep
extends TaskStep
## Goes to the tile in the blackboard ("to") for an expedition of settlers (M6 part 2). With
## "wait" the agent first stands where he is while the province's expedition is still
## gathering (the settlers by their wagon), or a trade route's carter while his wagon is
## loaded ("route", M6 part 3). With no way there he simply stops where he is:
## a settler leaving the province is gone all the same.


func run(province: ProvinceSim, agent: Agent, _def: StepDef) -> Status:
	var bb := agent.task.bb
	if bb.has("wait") and bb.has("route"):
		var wagon := province.route_wagons.get(int(bb["route"])) as RouteWagon
		if wagon != null and wagon.holds(agent):
			agent.activity = &"idle"
			return Status.RUNNING
		bb.erase("wait")
	if bb.has("wait"):
		if province.departure != null and not province.departure.is_leaving():
			agent.activity = &"idle"
			return Status.RUNNING
		bb.erase("wait")
	var to := SimCodec.to_vec2i(bb["to"])
	if agent.tile() == to:
		return Status.DONE
	var status := Movement.walk(province, agent, to)
	if status == Status.FAILED:
		agent.clear_path()
		return Status.DONE
	return status
