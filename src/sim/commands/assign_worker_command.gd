class_name AssignWorkerCommand
extends Command
## Makes a person work in a building (up to its worker slots).

var agent_id: int
var building_id: int


func _init(agent: int, building: int) -> void:
	agent_id = agent
	building_id = building


func validate(sim: Simulation) -> StringName:
	var agent := sim.province.agents.get_agent(agent_id)
	var building := sim.province.buildings.get_building(building_id)
	if agent == null:
		return &"unknown_agent"
	if building == null:
		return &"unknown_building"
	if building.workers.has(agent_id):
		return &"already_assigned"
	if building.workers.size() >= building.def.worker_count():
		return &"no_worker_slot"
	return &""


func apply(sim: Simulation) -> void:
	sim.province.assign_worker(sim.province.agents.get_agent(agent_id),
			sim.province.buildings.get_building(building_id))


func get_name() -> StringName:
	return &"assign_worker"
