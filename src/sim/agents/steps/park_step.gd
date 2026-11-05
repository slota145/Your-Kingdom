class_name ParkStep
extends TaskStep
## Drives the wagon by road to the stable's door, leaves it there (the stable keeps it) and
## walks in. Without a wagon (a carter just hired) he only walks to the stable. When the
## stable cannot be reached by road the wagon is put away where it stands.


func run(province: ProvinceSim, agent: Agent, _def: StepDef) -> Status:
	var stable := province.buildings.get_building(agent.workplace_id)
	if stable == null:
		agent.vehicle = &""
		return Status.DONE
	if agent.vehicle == Carriers.WAGON:
		var stop := province.road_stop(stable.id, agent.tile())
		if stop != Agent.NO_TILE:
			var status := Movement.walk(province, agent, stop)
			if status == Status.RUNNING:
				return status
		agent.vehicle = &""
		agent.clear_path()
	var status := Movement.walk(province, agent, stable.entrance_tile())
	return Status.DONE if status == Status.FAILED else status
