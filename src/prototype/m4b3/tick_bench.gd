extends SceneTree
## M4b-3 tick measurement (ROADMAP M4b-3, ARCHITECTURE §9.3): loads the big city fixture and
## times Simulation.step() headless.
##   "$GODOT" --headless --path . -s res://src/prototype/m4b3/tick_bench.gd -- [--minutes=10] [--skip=0] [--profile]
## --skip runs that many minutes first without measuring (the town grows to ~470 characters
## in the second hour). --profile also times the parts of ProvinceSim.step() (a copy of its
## order, kept here only; it adds its own overhead).

const BigCityScript := preload("res://tests/support/big_city.gd")

var _parts: Dictionary[String, int] = {}
## Average characters per 10 minute window.
var _chars: Array[int] = []
var _worst: Dictionary[String, int] = {}
## Part -> how many ticks over 8 ms it was the biggest part of.
var _slow_by: Dictionary[String, int] = {}
var _tick_parts: Dictionary[String, int] = {}


func _init() -> void:
	var minutes := 10
	var profile := false
	var skip := 0
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--minutes="):
			minutes = int(arg.get_slice("=", 1))
		elif arg == "--profile":
			profile = true
		elif arg.begins_with("--skip="):
			skip = int(arg.get_slice("=", 1))
	var registry := DataRegistry.new()
	registry.load_from("res://data")
	var sim: Simulation = BigCityScript.load_fixture(registry)
	for i: int in skip * 60 * SimClock.TICKS_PER_SECOND:
		sim.step()
		sim.events.drain()
	print(BigCityScript.summary(sim))
	var ticks := minutes * 60 * SimClock.TICKS_PER_SECOND
	var times := PackedInt64Array()
	times.resize(ticks)
	var agents_sum := 0
	var agents_min := 1 << 30
	var agents_max := 0
	for i: int in ticks:
		var t0 := Time.get_ticks_usec()
		if profile:
			_tick_parts.clear()
			_profiled_step(sim)
		else:
			sim.step()
		times[i] = Time.get_ticks_usec() - t0
		if profile and times[i] > 8000 and i > 10:
			var top := ""
			for key: String in _tick_parts:
				if top == "" or _tick_parts[key] > _tick_parts[top]:
					top = key
			_slow_by[top] = _slow_by.get(top, 0) + 1
		sim.events.drain()
		var n := sim.province.agents.all().size()
		if i % (10 * 60 * SimClock.TICKS_PER_SECOND) == 0:
			_chars.append(0)
		_chars[-1] += n
		agents_sum += n
		agents_min = mini(agents_min, n)
		agents_max = maxi(agents_max, n)
	# Every 10 minutes: average and 99th percentile tick, average characters.
	var window := 10 * 60 * SimClock.TICKS_PER_SECOND
	for start: int in range(0, ticks - window + 1, window):
		var part := times.slice(start, start + window)
		var part_sum := 0
		for t: int in part:
			part_sum += t
		part.sort()
		print("  min %3d-%3d: tick avg %.3f ms, p99 %.3f ms, characters %d" % [start / 600, (start + window) / 600,
				part_sum / 1000.0 / window, part[window * 99 / 100] / 1000.0, _chars[start / window] / window])
	var sorted := times.duplicate()
	sorted.sort()
	var total := 0
	for t: int in times:
		total += t
	print("tick over %d min (%d ticks): avg %.3f ms, median %.3f ms, p99 %.3f ms, max %.3f ms" % [
			minutes, ticks, total / 1000.0 / ticks, sorted[ticks / 2] / 1000.0,
			sorted[ticks * 99 / 100] / 1000.0, sorted[ticks - 1] / 1000.0])
	print("characters: avg %d, min %d, max %d" % [agents_sum / ticks, agents_min, agents_max])
	# The worst seconds at 4x: 4 ticks in one frame.
	var worst4 := 0
	for i: int in range(0, ticks - 3, 4):
		worst4 = maxi(worst4, times[i] + times[i + 1] + times[i + 2] + times[i + 3])
	print("worst 4 ticks in a row (one 4x frame): %.3f ms" % (worst4 / 1000.0))
	if profile:
		var keys := _parts.keys()
		keys.sort_custom(func(a: String, b: String) -> bool: return _parts[a] > _parts[b])
		for key: String in keys:
			print("  %-18s %.3f ms/tick, worst %.1f ms" % [key, _parts[key] / 1000.0 / ticks,
					_worst[key] / 1000.0])
	if profile:
		print("ticks over 8 ms by their biggest part: ", _slow_by)
	print(BigCityScript.summary(sim))
	quit()


func _profiled_step(sim: Simulation) -> void:
	var p := sim.province
	sim.events.tick = sim.clock.tick
	p.tick = sim.clock.tick
	var t := Time.get_ticks_usec()
	p.jobs.update(p)
	t = _lap("jobs", t)
	for agent: Agent in p.agents.all():
		if agent.task != null and (agent.path_state == Agent.PathState.MOVING \
				or agent.path_state == Agent.PathState.WAITING):
			continue
		if p.agents.has_agent(agent.id):
			_tick_agent(p, agent)
	t = Time.get_ticks_usec()
	Movement.serve_paths(p)
	t = _lap("paths", t)
	Movement.move_all(p)
	t = _lap("movement", t)
	p._remove_empty_piles()
	if p.tick % ProvinceSim.GROW_CHECK_TICKS == 0:
		p._grow_saplings()
		p._breed_herds()
		p._update_markets()
		p.merchant.update(p)
		p.jobs.trim_yard_requests(p)
	t = _lap("piles/grow/market", t)
	p.coverage.update(p)
	t = _lap("population: coverage", t)
	Population.update(p)
	t = _lap("population", t)
	sim.clock.tick += 1


func _lap(key: String, since: int) -> int:
	var now := Time.get_ticks_usec()
	_parts[key] = _parts.get(key, 0) + now - since
	_worst[key] = maxi(_worst.get(key, 0), now - since)
	_tick_parts[key] = _tick_parts.get(key, 0) + now - since
	return now


## TaskRunner.tick_agent with a timer per step kind.
func _tick_agent(province: ProvinceSim, agent: Agent) -> void:
	var t := Time.get_ticks_usec()
	if agent.task == null:
		if agent.cooldown > 0:
			agent.cooldown -= 1
			return
		TaskRunner._start_next(province, agent)
		t = _lap("tasks: start " + String(agent.kind), t)
		if agent.task == null:
			return
	if agent.path_state == Agent.PathState.MOVING or agent.path_state == Agent.PathState.WAITING:
		return
	var step := agent.task.current_step()
	if step == null:
		TaskRunner._finish(province, agent)
		_lap("tasks: finish", t)
		return
	var key := "tasks: " + String(step.get_step_kind())
	if step is GoToStepDef:
		key += ":" + String((step as GoToStepDef).target) + ":" + String(agent.kind)
	var status := TaskRunner.executor(step.get_step_kind()).run(province, agent, step)
	if status == TaskStep.Status.DONE:
		TaskRunner._advance(province, agent)
	elif status == TaskStep.Status.FAILED:
		TaskRunner.fail(province, agent)
	_lap(key, t)
