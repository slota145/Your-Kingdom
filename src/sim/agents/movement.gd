class_name Movement
extends RefCounted
## Path requests and walking along paths (ARCHITECTURE §5.3, §5.4). No collisions between
## people: several may share a tile.

## Tiles per second on cost-1 ground.
const BASE_SPEED := 1.2


## Drives the agent towards [param goal]; call every tick until it is not RUNNING.
static func walk(province: ProvinceSim, agent: Agent, goal: Vector2i) -> TaskStep.Status:
	if agent.path_goal != goal or agent.path_state == Agent.PathState.NONE:
		agent.clear_path()
		agent.path_goal = goal
		agent.path_state = Agent.PathState.WAITING
		province.paths.push(agent.id)
		return TaskStep.Status.RUNNING
	match agent.path_state:
		Agent.PathState.ARRIVED:
			return TaskStep.Status.DONE
		Agent.PathState.FAILED:
			return TaskStep.Status.FAILED
	return TaskStep.Status.RUNNING


## Answers up to the queue budget of waiting path requests.
static func serve_paths(province: ProvinceSim) -> void:
	for id: int in province.paths.take_batch():
		var agent := province.agents.get_agent(id)
		if agent == null or agent.path_state != Agent.PathState.WAITING:
			continue
		var path := province.nav.find_path(agent.tile(), agent.path_goal)
		if path.is_empty():
			agent.path_state = Agent.PathState.FAILED
			continue
		agent.path = path
		agent.path_index = 0
		agent.path_version = province.nav.version
		agent.path_state = Agent.PathState.MOVING
		_face_segment(agent)


static func move_all(province: ProvinceSim) -> void:
	for agent: Agent in province.agents.all():
		agent.prev_pos = agent.pos
		if agent.path_state == Agent.PathState.MOVING:
			if agent.path_version != province.nav.version:
				_check_path(province, agent)
			if agent.path_state == Agent.PathState.MOVING:
				_advance(province, agent)


## Re-plans when a tile ahead became blocked (a building or a wall was placed on the way).
static func _check_path(province: ProvinceSim, agent: Agent) -> void:
	agent.path_version = province.nav.version
	for i: int in range(agent.path_index, agent.path.size()):
		if not province.nav.is_walkable(agent.path[i]):
			var goal := agent.path_goal
			agent.clear_path()
			agent.path_goal = goal
			agent.path_state = Agent.PathState.WAITING
			province.paths.push(agent.id)
			return


## Facing is set once per path segment, not every tick.
static func _face_segment(agent: Agent) -> void:
	var dir := IsoMath.screen_dir(IsoMath.tile_center(agent.path[agent.path_index]) - agent.pos)
	if dir >= 0:
		agent.facing = dir


static func _advance(province: ProvinceSim, agent: Agent) -> void:
	var budget := BASE_SPEED * SimClock.TICK
	while budget > 0.0:
		var target := IsoMath.tile_center(agent.path[agent.path_index])
		var delta := target - agent.pos
		var length := delta.length()
		var cost := province.nav.get_cost(agent.path[agent.path_index])
		var reach := budget / cost
		if length <= reach:
			agent.pos = target
			budget -= length * cost
			agent.path_index += 1
			if agent.path_index >= agent.path.size():
				agent.path_state = Agent.PathState.ARRIVED
				agent.activity = &"idle"
				return
			_face_segment(agent)
		else:
			agent.pos += delta / length * reach
			budget = 0.0
	agent.activity = &"walk"
