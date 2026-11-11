class_name Researching
extends RefCounted
## Study of the player's kingdom (ROADMAP E4 part 2, owner's surveys 2026-11-11), once a second:
## each school with its teacher at work adds a second of study to the current research (two
## schools: twice as fast). A research starts when its gold is paid; when it is done the next
## one in the queue starts, or waits for gold.


## Once a second.
static func update(sim: Simulation) -> void:
	var research := sim.research
	if research.current == &"":
		_start_next(sim)
	if research.current == &"":
		return
	var def := sim.data.get_research(research.current)
	if def == null:
		research.current = &""
		return
	research.progress += teachers(sim, def.institution)
	if research.progress >= def.time:
		var id := research.current
		research.complete(id)
		sim.events.emit(&"research_finished", {"research": id})
		_start_next(sim)


## Starts [param id] now (gold paid) or puts it in the queue when another is studied.
static func plan(sim: Simulation, id: StringName) -> void:
	if sim.research.current == &"" and sim.research.queue.is_empty():
		_begin(sim, id)
	else:
		sim.research.queue.append(id)
		sim.events.emit(&"research_queued", {"research": id})


## Stops the current research (its gold comes back, its progress is lost) or takes [param id]
## out of the queue, with the queued researches that need it.
static func cancel(sim: Simulation, id: StringName) -> void:
	var research := sim.research
	if research.current == id:
		var def := sim.data.get_research(id)
		sim.treasury.add(def.gold_cost if def != null else 0)
		research.current = &""
		research.progress = 0.0
		research.unqueue(sim.data, id)
	else:
		research.unqueue(sim.data, id)
	sim.events.emit(&"research_cancelled", {"research": id})


## Teachers at work in the player's schools (or scholars at universities): one per staffed
## building of [param institution].
static func teachers(sim: Simulation, institution: StringName) -> int:
	var count := 0
	for id: int in sim.runtimes:
		if sim.world.owner_of(id) != ProvinceDef.OWNER_PLAYER:
			continue
		var abstract := sim.runtimes[id] as ProvinceAbstract
		var state := sim.province_state(id)
		for building: BuildingState in state.buildings.all():
			if building.def.research_institution != institution or not building.is_complete() \
					or building.paused:
				continue
			var staffed := int(abstract.staff.get(building.id, 0)) > 0 if abstract != null \
					else _teacher_at_work(state, building)
			if staffed:
				count += 1
	return count


## Schools (or universities) the player has built.
static func has_institution(sim: Simulation, institution: StringName) -> bool:
	for id: int in sim.runtimes:
		if sim.world.owner_of(id) != ProvinceDef.OWNER_PLAYER:
			continue
		var state := sim.province_state(id)
		for building: BuildingState in state.buildings.all():
			if building.def.research_institution == institution and building.is_complete():
				return true
	return false


## A teacher works when he is assigned and stands at his school (not on his way).
static func _teacher_at_work(province: ProvinceSim, building: BuildingState) -> bool:
	var area := Rect2i(building.origin, building.def.footprint).grow(1)
	for worker: int in building.workers:
		var agent := province.agents.get_agent(worker)
		if agent != null and agent.workplace_id == building.id and agent.path_state != Agent.PathState.MOVING \
				and area.has_point(agent.tile()):
			return true
	return false


static func _start_next(sim: Simulation) -> void:
	var research := sim.research
	while not research.queue.is_empty():
		var next: StringName = research.queue[0]
		var def := sim.data.get_research(next)
		if def == null or research.is_done(next):
			research.queue.remove_at(0)
			continue
		if not sim.treasury.can_pay(def.gold_cost):
			return   # waits for gold
		research.queue.remove_at(0)
		_begin(sim, next)
		return


static func _begin(sim: Simulation, id: StringName) -> void:
	var def := sim.data.get_research(id)
	if def == null or not sim.treasury.pay(def.gold_cost):
		return
	sim.research.current = id
	sim.research.progress = 0.0
	sim.events.emit(&"research_started", {"research": id})
