class_name TaskRunner
extends RefCounted
## Runs the current step of every agent and handles task start, end and failure
## (ARCHITECTURE §5.2).
##
## On failure: reservations and claims are released, a transport request goes back to the
## board, and an agent left holding goods first stashes them (storage or ground) after a
## short wait. Nothing is ever lost and nothing stays reserved.

## Wait after a failure before trying again (3 s).
const RETRY_TICKS := 30

static var _executors: Dictionary[StringName, TaskStep] = {}
static var _transport_steps: Array[StepDef] = []
static var _stash_steps: Array[StepDef] = []


static func tick_agent(province: ProvinceSim, agent: Agent) -> void:
	if agent.task == null:
		if agent.cooldown > 0:
			agent.cooldown -= 1
			return
		_start_next(province, agent)
		if agent.task == null:
			return
	# While walking a step has nothing to decide: Movement finishes the walk and the step
	# resumes on arrival. Targets that vanish meanwhile fail the task (ProvinceSim.remove_building).
	if agent.path_state == Agent.PathState.MOVING or agent.path_state == Agent.PathState.WAITING:
		return
	var step := agent.task.current_step()
	if step == null:
		_finish(province, agent)
		return
	var status := executor(step.get_step_kind()).run(province, agent, step)
	if status == TaskStep.Status.DONE:
		_advance(province, agent)
	elif status == TaskStep.Status.FAILED:
		fail(province, agent)


static func executor(kind: StringName) -> TaskStep:
	if _executors.is_empty():
		_executors = {
			&"go_to": GoToStep.new(), &"work": WorkStep.new(), &"gather": GatherStep.new(),
			&"fetch": FetchStep.new(), &"produce": ProduceStep.new(), &"deliver": DeliverStep.new(),
		}
	return _executors[kind]


## Gives a porter a transport task for one load of [param request].
static func start_transport(agent: Agent, request: TransportRequest, amount: int) -> void:
	var task := Task.new()
	task.kind = Task.KIND_TRANSPORT
	task.request_id = request.id
	task.bb = {"good": String(request.good), "amount": amount, "from": request.source_id,
			"to": request.dest_id}
	task.steps = transport_steps()
	agent.task = task


## Cancels the agent's task: releases everything it holds and schedules a retry.
static func fail(province: ProvinceSim, agent: Agent) -> void:
	var task := agent.task
	if task == null:
		return
	province.release_agent(agent)
	if task.kind == Task.KIND_TRANSPORT:
		# Goods already picked up leave the request: the stash task takes care of them.
		var amount := int(task.bb.get("amount", 1))
		if agent.is_carrying():
			province.jobs.on_completed(task.request_id, amount)
		else:
			province.jobs.on_failed(province, task.request_id, amount)
	province.events.emit(&"task_failed", {"agent": agent.id, "task": task.kind,
			"step": task.step_index, "reason": StringName(String(task.bb.get("fail_reason", "")))})
	agent.task = null
	agent.clear_path()
	agent.activity = &"idle"
	agent.cooldown = RETRY_TICKS


## Rebuilds the step list of a task loaded from a save. Returns false if it cannot be resumed.
static func restore_steps(province: ProvinceSim, task: Task) -> bool:
	match task.kind:
		Task.KIND_TRANSPORT:
			task.steps = transport_steps()
		Task.KIND_STASH:
			task.steps = stash_steps()
		Task.KIND_RECIPE:
			var recipe := province.data.get_recipe(task.recipe_id)
			if recipe == null:
				return false
			task.steps = recipe.steps
	return task.step_index <= task.steps.size()


static func transport_steps() -> Array[StepDef]:
	if _transport_steps.is_empty():
		_transport_steps = [FetchStepDef.new(), DeliverStepDef.new()]
	return _transport_steps


static func stash_steps() -> Array[StepDef]:
	if _stash_steps.is_empty():
		var deliver := DeliverStepDef.new()
		deliver.drop_on_fail = true
		_stash_steps = [deliver]
	return _stash_steps


static func _start_next(province: ProvinceSim, agent: Agent) -> void:
	if agent.is_carrying():
		var stash := Task.new()
		stash.kind = Task.KIND_STASH
		stash.steps = stash_steps()
		agent.task = stash
		return
	var workplace := province.buildings.get_building(agent.workplace_id)
	if workplace != null and workplace.def.recipe != null and not workplace.def.recipe.steps.is_empty():
		var task := Task.new()
		task.kind = Task.KIND_RECIPE
		task.recipe_id = workplace.def.recipe.id
		task.steps = workplace.def.recipe.steps
		agent.task = task


static func _advance(province: ProvinceSim, agent: Agent) -> void:
	var task := agent.task
	for key: Variant in task.bb.keys():
		if String(key).begins_with("_"):
			task.bb.erase(key)
	task.step_index += 1
	agent.clear_path()
	agent.activity = &"idle"
	if task.step_index >= task.steps.size():
		_finish(province, agent)


static func _finish(province: ProvinceSim, agent: Agent) -> void:
	var task := agent.task
	if task.kind == Task.KIND_TRANSPORT:
		province.jobs.on_completed(task.request_id, int(task.bb.get("amount", 1)))
	agent.task = null
