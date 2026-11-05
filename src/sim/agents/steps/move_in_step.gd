class_name MoveInStep
extends TaskStep
## A newcomer walks to the house and becomes one of its residents (the agent then vanishes).


func run(province: ProvinceSim, agent: Agent, _def: StepDef) -> Status:
	var house := province.buildings.get_building(agent.home_id)
	if house == null or house.house == null:
		return failed(agent, &"no_house")
	var status := Movement.walk(province, agent, house.entrance_tile())
	if status != Status.DONE:
		return status
	house.house.incoming = maxi(house.house.incoming - 1, 0)
	house.house.residents += 1
	agent.home_id = 0
	province.events.emit(&"resident_arrived", {"agent": agent.id, "house": house.id})
	return Status.DONE
