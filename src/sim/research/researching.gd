class_name Researching
extends RefCounted
## Study of the player's kingdom (ROADMAP E4 part 2, owner's surveys 2026-11-11) and, from part
## 5, of each AI ruler's (RulerResearch chooses what he studies), once a second:
## each school with its teacher at work adds a second of study to the current research (two
## schools: twice as fast). A research starts when its gold is paid; when it is done the next
## one in the queue starts, or waits for gold.


## Once a second: the player's kingdom, then each AI ruler's (E4 part 5).
static func update(sim: Simulation) -> void:
	_study_player(sim)
	var owners: Array[StringName] = []
	owners.assign(sim.world.rulers.keys())
	owners.sort()
	for owner: StringName in owners:
		var ruler := sim.world.rulers[owner] as RulerState
		if not Rulers.is_raiders(owner) and not ruler.defeated and not ruler.research.open:
			study(sim, owner, ruler.research)


static func _study_player(sim: Simulation) -> void:
	var research := sim.research
	if research.current == &"":
		_start_next(sim)
	if research.current == &"":
		return
	if study(sim, ProvinceDef.OWNER_PLAYER, research) != &"":
		_start_next(sim)


## A second of study of [param owner]'s current research by his teachers and scholars at work;
## returns the research it finished, or &"". The player is told (research_finished); a ruler's
## is an event of his own (ruler_research_finished).
static func study(sim: Simulation, owner: StringName, research: ResearchState) -> StringName:
	if research.current == &"":
		return &""
	var def := sim.data.get_research(research.current)
	if def == null:
		research.current = &""
		return &""
	research.progress += study_rate(sim, def.institution, owner)
	if research.progress < def.time:
		return &""
	var id := research.current
	research.complete(id)
	if owner == ProvinceDef.OWNER_PLAYER:
		sim.events.emit(&"research_finished", {"research": id})
	else:
		sim.events.emit(&"ruler_research_finished", {"owner": owner, "research": id})
	return id


## Starts [param id] for an AI ruler (or the automatic player) now: its gold is paid from
## [param treasury]. Returns whether it started.
static func begin_for(sim: Simulation, owner: StringName, research: ResearchState, treasury: Treasury,
		id: StringName) -> bool:
	var def := sim.data.get_research(id)
	if def == null or research.current != &"" or not treasury.pay(def.gold_cost):
		return false
	research.current = id
	research.progress = 0.0
	if owner == ProvinceDef.OWNER_PLAYER:
		sim.events.emit(&"research_started", {"research": id})
	else:
		sim.events.emit(&"ruler_research_started", {"owner": owner, "research": id})
	return true


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


## Teachers at work in the schools of [param owner] (the player's by default; or scholars at
## universities, two each, E4 part 3).
static func teachers(sim: Simulation, institution: StringName, owner: StringName = ProvinceDef.OWNER_PLAYER) -> int:
	var count := 0
	for pair: Array in _at_work(sim, institution, owner):
		count += int(pair[1])
	return count


## Seconds of study a second: a second for each teacher or scholar at work, faster with research
## that speeds the institution up (E4 part 3: "Deep learning" doubles the schools).
static func study_rate(sim: Simulation, institution: StringName, owner: StringName = ProvinceDef.OWNER_PLAYER) -> float:
	var research := sim.research_of_owner(owner)
	var rate := 0.0
	for pair: Array in _at_work(sim, institution, owner):
		var building := pair[0] as BuildingState
		rate += int(pair[1]) * research.work_speed(sim.data, building.def.id)
	return rate


## [building, its workers at work] of every building of [param institution] of [param owner].
static func _at_work(sim: Simulation, institution: StringName, owner: StringName) -> Array[Array]:
	var result: Array[Array] = []
	for id: int in sim.runtimes:
		if sim.world.owner_of(id) != owner:
			continue
		var abstract := sim.runtimes[id] as ProvinceAbstract
		var state := sim.province_state(id)
		for building: BuildingState in state.buildings.all():
			if building.def.research_institution != institution or not building.is_complete() \
					or building.paused:
				continue
			var working := int(abstract.staff.get(building.id, 0)) if abstract != null \
					else _teachers_at_work(state, building)
			if working > 0:
				result.append([building, working])
	return result


## Schools (or universities) [param owner] has built (the player by default).
static func has_institution(sim: Simulation, institution: StringName, owner: StringName = ProvinceDef.OWNER_PLAYER) -> bool:
	for id: int in sim.runtimes:
		if sim.world.owner_of(id) != owner:
			continue
		var state := sim.province_state(id)
		for building: BuildingState in state.buildings.all():
			if building.def.research_institution == institution and building.is_complete():
				return true
	return false


## Teachers who are assigned and stand at their school (not on their way).
static func _teachers_at_work(province: ProvinceSim, building: BuildingState) -> int:
	var area := Rect2i(building.origin, building.def.footprint).grow(1)
	var count := 0
	for worker: int in building.workers:
		var agent := province.agents.get_agent(worker)
		if agent != null and agent.workplace_id == building.id and agent.path_state != Agent.PathState.MOVING \
				and area.has_point(agent.tile()):
			count += 1
	return count


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
