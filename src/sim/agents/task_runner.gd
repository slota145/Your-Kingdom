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
## Wait when there is simply nothing to work on (no tree to fell, no rock, no free tile to
## plant): 10 s. The worker stands idle either way; looking again costs a search of the
## whole work area (M4b-3).
const IDLE_RETRY_TICKS := 100
const NOTHING_TO_DO: Array[StringName] = [&"no_resource", &"no_plant_spot", &"no_order", &"no_boat"]

static var _executors: Dictionary[StringName, TaskStep] = {}
static var _transport_steps: Array[StepDef] = []
static var _stash_steps: Array[StepDef] = []
static var _build_steps: Array[StepDef] = []
static var _errand_steps: Array[StepDef] = []
static var _move_in_steps: Array[StepDef] = []
static var _merchant_steps: Array[StepDef] = []
static var _park_steps: Array[StepDef] = []
static var _sail_home_steps: Array[StepDef] = []
static var _land_steps: Array[StepDef] = []
static var _travel_steps: Array[StepDef] = []

const BUILDER_KIND := &"builder"


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
			&"build": BuildStep.new(), &"field": FieldStep.new(), &"move_in": MoveInStep.new(),
			&"deposit": DepositStep.new(), &"plant": PlantStep.new(), &"serve": ServeStep.new(),
			&"choose_stall": ChooseStallStep.new(), &"merchant": MerchantStep.new(),
			&"park": ParkStep.new(), &"sail": SailStep.new(), &"ship_build": ShipBuildStep.new(),
			&"land": LandStep.new(), &"travel": TravelStep.new(),
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


## Sends a householder for [param amount] of [param good] from the nearest storage (or from
## the stalls of market [param from]) to the house.
static func start_errand(agent: Agent, good: StringName, amount: int, house_id: int, from: int = 0) -> void:
	var task := Task.new()
	task.kind = Task.KIND_ERRAND
	task.bb = {"good": String(good), "amount": amount, "to": house_id}
	if from != 0:
		task.bb["from"] = from
	task.steps = errand_steps()
	agent.task = task


static func start_move_in(agent: Agent) -> void:
	var task := Task.new()
	task.kind = Task.KIND_MOVE_IN
	task.steps = move_in_steps()
	agent.task = task


## Cancels the agent's task: releases everything it holds and schedules a retry.
static func fail(province: ProvinceSim, agent: Agent) -> void:
	var task := agent.task
	if task == null:
		return
	Harbour.step_ashore(agent)
	province.release_agent(agent)
	if task.kind == Task.KIND_TRANSPORT:
		# Goods already picked up leave the request: the stash task takes care of them.
		var amount := int(task.bb.get("amount", 1))
		if agent.is_carrying():
			province.jobs.on_completed(task.request_id, amount)
		else:
			province.jobs.on_failed(province, task.request_id, amount)
	agent.last_fail = StringName(String(task.bb.get("fail_reason", "")))
	if task.kind == Task.KIND_RECIPE and agent.workplace_id != 0:
		province.production.note_failure(agent.workplace_id)
	var step := task.current_step()
	agent.last_fail_good = StringName(String(task.bb.get("good",
			(step as FetchStepDef).good if step is FetchStepDef else "")))
	province.events.emit(&"task_failed", {"agent": agent.id, "task": task.kind,
			"step": task.step_index, "reason": StringName(String(task.bb.get("fail_reason", "")))})
	agent.task = null
	if not agent.is_carrying() and agent.vehicle == Carriers.HANDCART:
		agent.vehicle = &""
	agent.clear_path()
	agent.activity = &"idle"
	agent.cooldown = IDLE_RETRY_TICKS if NOTHING_TO_DO.has(agent.last_fail) else RETRY_TICKS


## Rebuilds the step list of a task loaded from a save. Returns false if it cannot be resumed.
static func restore_steps(province: ProvinceSim, task: Task) -> bool:
	match task.kind:
		Task.KIND_TRANSPORT:
			task.steps = transport_steps()
		Task.KIND_STASH:
			task.steps = stash_steps()
		Task.KIND_BUILD:
			task.steps = build_steps()
		Task.KIND_ERRAND:
			task.steps = errand_steps()
		Task.KIND_MOVE_IN:
			task.steps = move_in_steps()
		Task.KIND_MERCHANT:
			task.steps = merchant_steps()
		Task.KIND_PARK:
			task.steps = park_steps()
		Task.KIND_SAIL_HOME:
			task.steps = sail_home_steps()
		Task.KIND_LAND:
			task.steps = land_steps()
		Task.KIND_TRAVEL:
			task.steps = travel_steps()
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


static func build_steps() -> Array[StepDef]:
	if _build_steps.is_empty():
		_build_steps = [BuildStepDef.new()]
	return _build_steps


static func errand_steps() -> Array[StepDef]:
	if _errand_steps.is_empty():
		_errand_steps = [FetchStepDef.new(), DeliverStepDef.new()]
	return _errand_steps


static func move_in_steps() -> Array[StepDef]:
	if _move_in_steps.is_empty():
		_move_in_steps = [MoveInStepDef.new()]
	return _move_in_steps


static func park_steps() -> Array[StepDef]:
	if _park_steps.is_empty():
		_park_steps = [ParkStepDef.new()]
	return _park_steps


static func sail_home_steps() -> Array[StepDef]:
	if _sail_home_steps.is_empty():
		var sail := SailStepDef.new()
		sail.target = &"home"
		_sail_home_steps = [sail]
	return _sail_home_steps


static func land_steps() -> Array[StepDef]:
	if _land_steps.is_empty():
		_land_steps = [LandStepDef.new()]
	return _land_steps


## A settler wades from [param from] (the ship at anchor) to [param to] (the beach).
static func start_landing(agent: Agent, from: Vector2i, to: Vector2i) -> void:
	var task := Task.new()
	task.kind = Task.KIND_LAND
	task.bb = {"from": SimCodec.vec2i(from), "to": SimCodec.vec2i(to), "t": 0}
	task.steps = land_steps()
	agent.task = task


static func travel_steps() -> Array[StepDef]:
	if _travel_steps.is_empty():
		_travel_steps = [TravelStepDef.new()]
	return _travel_steps


## [param agent] walks to [param to] for an expedition (M6 part 2): [param wait] stands still
## first while the expedition is still gathering, [param leave] goes with it on arrival.
static func start_travel(agent: Agent, to: Vector2i, wait: bool = false, leave: bool = false) -> void:
	var task := Task.new()
	task.kind = Task.KIND_TRAVEL
	task.bb = {"to": SimCodec.vec2i(to)}
	if wait:
		task.bb["wait"] = 1
	if leave:
		task.bb["leave"] = 1
	task.steps = travel_steps()
	agent.task = task


static func merchant_steps() -> Array[StepDef]:
	if _merchant_steps.is_empty():
		_merchant_steps = [MerchantStepDef.new()]
	return _merchant_steps


static func _start_next(province: ProvinceSim, agent: Agent) -> void:
	if not agent.is_carrying() and agent.vehicle == Carriers.HANDCART:
		agent.vehicle = &""   # the handcart goes back to the storage's yard
	if agent.vehicle == Ships.ABOARD:
		# A trip that ended at sea: the boat goes home first, goods stay in hand (M5).
		var back := Task.new()
		back.kind = Task.KIND_SAIL_HOME
		back.steps = sail_home_steps()
		agent.task = back
		return
	if agent.is_carrying():
		var stash := Task.new()
		stash.kind = Task.KIND_STASH
		stash.steps = stash_steps()
		agent.task = stash
		return
	match agent.kind:
		Population.HOUSEHOLDER_KIND:
			# Errand over (or impossible): the householder goes back inside.
			province.remove_agent(agent)
			return
		Merchant.AGENT_KIND:
			# His visit task was interrupted: he goes on with it, or leaves when it is over.
			if province.merchant.agent_id == agent.id and province.merchant.state != Merchant.State.AWAY:
				var visit := Task.new()
				visit.kind = Task.KIND_MERCHANT
				visit.steps = merchant_steps()
				agent.task = visit
			else:
				province.remove_agent(agent)
			return
		Population.SETTLER_KIND:
			var home := province.buildings.get_building(agent.home_id)
			if home == null or home.house == null:
				province.remove_agent(agent)
			else:
				start_move_in(agent)
			return
	var workplace := province.buildings.get_building(agent.workplace_id)
	if workplace != null and not workplace.is_complete():
		return
	if agent.kind == Carriers.CARTER_KIND and workplace != null:
		# Between jobs the wagon goes back to the stable (M4b-3).
		if agent.vehicle != &"" or province.building_entered_at(agent.tile()) != workplace:
			var park := Task.new()
			park.kind = Task.KIND_PARK
			park.steps = park_steps()
			agent.task = park
		return
	# The builder who came with the settlers' ship builds before the pioneer camp stands
	# (M5 part 3): without a workplace he still takes the nearest site.
	if agent.kind == BUILDER_KIND and (workplace != null or agent.workplace_id == 0):
		var site := Construction.site_for(province, agent)
		if site != 0:
			var build := Task.new()
			build.kind = Task.KIND_BUILD
			build.bb = {"site": site}
			build.steps = build_steps()
			agent.task = build
		return
	if workplace != null and workplace.paused:
		return
	if workplace != null and province.yard_blocked(workplace):
		agent.last_fail = &"yard_full"
		agent.last_fail_good = &""
		agent.cooldown = RETRY_TICKS
		return
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
	if not agent.is_carrying() and agent.vehicle == Carriers.HANDCART:
		agent.vehicle = &""
	if task.kind == Task.KIND_MERCHANT:
		if province.merchant.agent_id == agent.id:
			province.merchant.gone()
		province.remove_agent(agent)
	if task.kind == Task.KIND_ERRAND or task.kind == Task.KIND_MOVE_IN:
		province.remove_agent(agent)
	if task.kind == Task.KIND_TRAVEL and task.bb.has("leave"):
		if province.departure != null:
			province.departure.on_left(province, agent)
		province.remove_agent(agent)
