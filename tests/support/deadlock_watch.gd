class_name DeadlockWatch
extends RefCounted
## Looks for deadlocks once a minute during long scenarios: goods reserved for nobody, and
## characters whose task stays on one step for [member STUCK_MINUTES] minutes (all real steps
## take seconds; waiting restarts the task). A worker waiting with his output because every
## storage and his yard are full is not stuck (M4b-2): he goes on as soon as there is room.

const STUCK_MINUTES := 5

var stuck: Array[String] = []
## Agent id -> [task, step index, minute first seen].
var _seen: Dictionary[int, Array] = {}


func check(sim: Simulation, minute: int) -> void:
	var holds := sim.province.dangling_holds()
	if not holds.is_empty():
		stuck.append("minute %d: %s" % [minute, ", ".join(holds)])
	var alive: Dictionary[int, bool] = {}
	for agent: Agent in sim.province.agents.all():
		alive[agent.id] = true
		# Waiting by design (M6): a settlers' wagon until its expedition is sent, a route's
		# carter while his wagon is loaded (it sets off on its own after a while).
		var waits := agent.task != null and agent.task.kind == Task.KIND_TRAVEL and agent.task.bb.has("wait")
		if agent.task == null or waits or _waits_for_room(sim, agent):
			_seen.erase(agent.id)
			continue
		var last: Array = _seen.get(agent.id, [])
		# The travelling merchant's whole visit is one step (coming, trading, leaving): each
		# stage of the visit counts as a step of its own.
		var step := agent.task.step_index
		if agent.task.kind == Task.KIND_MERCHANT and sim.province.merchant.agent_id == agent.id:
			step = 100 + sim.province.merchant.state
		if last.is_empty() or not is_same(last[0], agent.task) or last[1] != step:
			_seen[agent.id] = [agent.task, step, minute]
		elif minute - int(last[2]) >= STUCK_MINUTES:
			stuck.append("minute %d: %s %d on %s step %d at %s" % [minute, agent.kind, agent.id,
					agent.task.kind, agent.task.step_index, agent.tile()])
	for id: int in _seen.keys():
		if not alive.has(id):
			_seen.erase(id)


static func _waits_for_room(sim: Simulation, agent: Agent) -> bool:
	if not agent.task.bb.has("_yard_full"):
		return false
	var yard := sim.province.storage(ProvinceSim.yard_id(agent.workplace_id))
	return yard != null and not yard.can_accept(agent.carry_good, agent.carry_amount) \
			and sim.province.nearest_sink(agent.carry_good, agent.carry_amount, agent.tile()) == 0
