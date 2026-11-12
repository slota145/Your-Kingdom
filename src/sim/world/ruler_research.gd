class_name RulerResearch
extends RefCounted
## What the AI rulers study (ROADMAP E4 part 5, owner's surveys 2026-11-11): each ruler's
## kingdom studies one research at a time, in a fixed order by difficulty, in the schools and
## the university his planner puts up (RulerPlanner.PLAN). He starts a research when its gold
## leaves [constant RESERVE_GOLD] in his treasury for the construction sites. A research of an
## institution he has not built yet is passed over until he has (so the university's soldiers
## come first as soon as it stands); "Shipbuilding" waits for a port. While he may put up his
## university and has none, the school's research waits: his gold goes to the university.
## The automatic player of the test games studies so too (AutoPlayer).

## Gold a ruler keeps after paying a research (as after a recruit, RulerWar.RESERVE_GOLD).
const RESERVE_GOLD := 150
## A ruler looks at his research every this many seconds.
const EVERY := 5
## The order of study by growth level (easy, normal, hard; peaceful = easy). First what his
## plan builds (butchery, tailoring, beekeeping), then by difficulty: on easy the economy
## first and the soldiers last, on hard the soldiers (knights too) before the economy. The
## charter, the siege engines, the large shipyard, brickmaking and winemaking are not studied:
## the rulers have no use for them.
const ORDER: Array[Array] = [
	[&"butchery", &"tailoring", &"beekeeping", &"forestry", &"fishing", &"large_barracks",
			&"larger_fields", &"carts", &"better_carrying", &"larger_fields_2", &"deep_learning",
			&"larger_pens", &"larger_pens_2", &"shipbuilding", &"armouring", &"crossbows",
			&"defensive_masonry"],
	[&"butchery", &"tailoring", &"large_barracks", &"armouring", &"crossbows", &"beekeeping",
			&"shipbuilding", &"forestry", &"fishing", &"carts", &"larger_fields", &"deep_learning",
			&"better_carrying", &"larger_fields_2", &"larger_pens", &"chivalry", &"larger_pens_2",
			&"defensive_masonry"],
	[&"butchery", &"tailoring", &"large_barracks", &"armouring", &"crossbows", &"shipbuilding",
			&"chivalry", &"beekeeping", &"deep_learning", &"forestry", &"fishing", &"carts",
			&"larger_fields", &"better_carrying", &"larger_fields_2", &"larger_pens",
			&"larger_pens_2", &"defensive_masonry"],
]


## Once a second (Simulation._update_world): each ruler in his own second.
static func update(sim: Simulation) -> void:
	var second := sim.clock.tick / SimClock.TICKS_PER_SECOND
	var owners: Array[StringName] = []
	owners.assign(sim.world.rulers.keys())
	owners.sort()
	for k: int in owners.size():
		var ruler := sim.world.rulers[owners[k]] as RulerState
		if Rulers.is_raiders(ruler.owner) or ruler.defeated or (second + k) % EVERY != 0:
			continue
		update_owner(sim, ruler)


## Starts the next research of [param ruler] when none is under way and he can pay for it.
## Returns the research started, or &"".
static func update_owner(sim: Simulation, ruler: RulerState) -> StringName:
	var research := ruler.research
	if research == null or research.open or research.current != &"":
		return &""
	var id := next(sim, ruler)
	if id == &"":
		return &""
	var def := sim.data.get_research(id)
	if ruler.treasury.gold < def.gold_cost + RESERVE_GOLD:
		return &""
	if def.institution == ResearchDef.SCHOOL and saving_for_university(sim, ruler.owner) \
			and ruler.treasury.gold < _university_gold(sim) + def.gold_cost + RESERVE_GOLD:
		return &""   # (with gold for both, the university waits for room, not for gold)
	return id if Researching.begin_for(sim, ruler.owner, research, ruler.treasury, id) else &""


## The research [param ruler] studies next: the first of his order not done whose needs are
## done, of an institution he has built (and useful to him now), or &"".
static func next(sim: Simulation, ruler: RulerState) -> StringName:
	var research := ruler.research
	var order: Array = ORDER[RulerPlanner.difficulty(sim)]
	for id: StringName in order:
		if research.is_done(id):
			continue
		var def := sim.data.get_research(id)
		if def == null or not Researching.has_institution(sim, def.institution, ruler.owner):
			continue
		var ready := true
		for need: StringName in def.requires:
			if not research.is_done(need):
				ready = false
		if not ready:
			continue
		if id == &"shipbuilding" and not _has_port(sim, ruler.owner):
			continue
		return id
	return &""


## Whether [param owner] may put up his university and has none yet: his gold goes to it, not
## to the school's research (it costs 500; spent on every research, his gold never got there).
static func saving_for_university(sim: Simulation, owner: StringName) -> bool:
	if RulerPlanner._realm_has(sim, owner, RulerPlanner.UNIVERSITY):
		return false
	var def := sim.data.get_building(RulerPlanner.UNIVERSITY)
	for id: int in Rulers.provinces_of(sim.world, owner):
		var town := sim.province_state(id)
		if town != null and def != null and RulerPlanner._allowed(town, def):
			return true
	return false


static func _university_gold(sim: Simulation) -> int:
	var def := sim.data.get_building(RulerPlanner.UNIVERSITY)
	return def.gold_cost if def != null else 0


static func _has_port(sim: Simulation, owner: StringName) -> bool:
	for id: int in Rulers.provinces_of(sim.world, owner):
		var town := sim.province_state(id)
		if town == null:
			continue
		for building: BuildingState in town.buildings.all():
			if building.def.is_port() and building.is_complete():
				return true
	return false
