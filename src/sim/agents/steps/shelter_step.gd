class_name ShelterStep
extends TaskStep
## A townsman runs to the town hall (or the pioneer camp) and stays inside until the bandits
## are gone or beaten (M7 part 2). Then his usual work goes on.


func run(province: ProvinceSim, agent: Agent, _def: StepDef) -> Status:
	var hall := province.seat()
	if hall == null or not province.raids.is_active():
		agent.activity = &"idle"
		return Status.DONE
	if agent.task.bb.has("_in"):
		return Status.RUNNING
	var status := Movement.walk(province, agent, hall.entrance_tile())
	if status == Status.FAILED:
		# No way to the hall: he stays where he is until it is over.
		agent.clear_path()
		agent.task.bb["_in"] = 1
		agent.activity = &"idle"
		return Status.RUNNING
	if status != Status.DONE:
		return status
	agent.task.bb["_in"] = 1
	agent.activity = &"idle"
	return Status.RUNNING
