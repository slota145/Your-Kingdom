class_name PlantStep
extends TaskStep
## Plants a sapling on the tile the forester walked to (blackboard "node"). The tile must
## still be free ground or a stump; otherwise the cycle fails and a new spot is chosen.


func run(province: ProvinceSim, agent: Agent, def: StepDef) -> Status:
	var step := def as PlantStepDef
	var bb := agent.task.bb
	if not bb.has("node"):
		return failed(agent, &"no_resource")
	var tile := SimCodec.to_vec2i(bb["node"])
	if not province.can_plant(tile):
		return failed(agent, &"no_resource")
	province.plant(tile, province.data.get_resource_node(step.sapling))
	bb.erase("plant")
	return Status.DONE
