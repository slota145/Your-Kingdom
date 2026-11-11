class_name Barracks
extends RefCounted
## Barracks, recruitment and soldiers at home (GDD §6.1, ROADMAP M7 part 1):
## - a recruit is a free resident (one of a house's workforce without a job): he moves out of
##   his house (the house takes a newcomer later), fetches his gear from the armoury (and a
##   horse from a stud farm), changes his looks and moves into the barracks,
## - soldiers live in the barracks: they eat from its pantry (porters bring bread, fish or
##   meat); a shortage has no effect yet (owner's decision 2026-11-07, back at balancing).
##   No wages (owner's decision 2026-11-08, as in Stronghold and Anno): a recruit costs more
##   once instead,
## - at home they stand in ranks on the parade ground in front of the door and drill together
##   now and then; those without a place in the ranks rest inside.
## Each barracks updates once per second of game time, in the tick of its id (like houses).

const RECRUIT_KIND := &"recruit"
## What soldiers eat, in order of preference when the stores hold the same.
const FOOD: Array[StringName] = [&"bread", &"fish", &"meat", &"apples"]
## Units of each food the pantry holds.
const PANTRY_UNITS := 6
## Food a soldier eats per minute (like a resident's bread, data/needs/bread.tres).
const FOOD_PER_MINUTE := 0.06
## Soldiers drilling in the ranks in front of a barracks; the rest rest inside.
const PARADE_SLOTS := 16
## Soldiers per parade tile (side by side in a rank).
const PER_TILE := 2
## How far (path steps) from the door the parade ground reaches at most.
const PARADE_REACH := 6
## Drill: seconds of one round, the first DRILL_ON of them drilling, then at attention.
const DRILL_ROUND := 14
const DRILL_ON := 8
## How often a soldier checks his place in the ranks (2 s).
const RECHECK_TICKS := 20
## How often a recruit missing his gear looks again (2 s).
const WAIT_TICKS := 20

## Barracks id -> [blocking version, parade posts]: positions in grid space.
static var _posts: Dictionary[int, Array] = {}


static func update(province: ProvinceSim) -> void:
	var slot := province.tick % Population.UPDATE_TICKS
	for building: BuildingState in province.buildings.all():
		if building.def.soldier_beds > 0 and building.is_complete() \
				and building.id % Population.UPDATE_TICKS == slot:
			_update_barracks(province, building, false)


## One second of the barracks of a province in the simplified mode (ARCHITECTURE §7.1): food
## by numbers, the pantry topped up straight from the storages.
static func update_abstract(province: ProvinceSim) -> void:
	for building: BuildingState in province.buildings.all():
		if building.def.soldier_beds > 0 and building.is_complete():
			_update_barracks(province, building, true)


## Soldiers living in [param barracks] (seen or kept by number in the simplified mode).
static func strength(barracks: BuildingState) -> int:
	return barracks.soldiers.size() + barracks.garrison.size()


## Beds taken by soldiers and recruits on their way.
static func beds_taken(barracks: BuildingState) -> int:
	return strength(barracks) + barracks.recruits.size()


static func _update_barracks(province: ProvinceSim, barracks: BuildingState, abstract: bool) -> void:
	var count := strength(barracks)
	if count == 0:
		if not abstract:
			for good: StringName in FOOD:
				province.jobs.set_amount(good, 0, barracks.id, 0)
		return
	# Meals from the pantry; without food nothing happens yet (the hunger does not pile up).
	barracks.mess_hunger = SimCodec.savable(barracks.mess_hunger + count * FOOD_PER_MINUTE / 60.0)
	while barracks.mess_hunger >= 1.0:
		var eaten := false
		for good: StringName in FOOD:
			if barracks.supply.available(good) > 0:
				barracks.supply.remove(good, 1)
				province.ledger.used(good, 1, province.tick)
				eaten = true
				break
		if not eaten:
			barracks.mess_hunger = minf(barracks.mess_hunger, 1.0)
			break
		barracks.mess_hunger -= 1.0
	if abstract:
		_refill_pantry(province, barracks)
	else:
		_request_food(province, barracks)


## Porters keep the pantry full of the food the storages hold most of.
static func _request_food(province: ProvinceSim, barracks: BuildingState) -> void:
	var best: StringName = &""
	var best_stored := 0
	for good: StringName in FOOD:
		var stored := province.stored(good)
		if stored > best_stored:
			best = good
			best_stored = stored
	for good: StringName in FOOD:
		var wanted := 0
		if good == best:
			wanted = PANTRY_UNITS - barracks.supply.total(good) \
					- province.jobs.in_flight(good, 0, barracks.id)
			wanted = clampi(wanted, 0, best_stored)
		province.jobs.set_amount(good, 0, barracks.id, wanted)


static func _refill_pantry(province: ProvinceSim, barracks: BuildingState) -> void:
	for good: StringName in FOOD:
		var missing := PANTRY_UNITS - barracks.supply.total(good)
		if missing <= 0:
			continue
		var taken := province.take_from_storages(good, missing, barracks.entrance_tile(), false)
		if taken > 0:
			barracks.supply.add(good, taken)
		return


# --- Recruitment ---------------------------------------------------------------------------

## Why [param unit] cannot be recruited in [param barracks] now; &"" when it can.
static func recruit_error(province: ProvinceSim, barracks: BuildingState, unit: UnitDef) -> StringName:
	if barracks == null or barracks.def.soldier_beds <= 0:
		return &"not_barracks"
	if unit == null:
		return &"unknown_unit"
	if unit.siege != &"":
		return &"built_in_workshop"
	if not province.research.allows_unit(province.data, unit.id):
		return &"needs_research"   # E4 part 3
	if not barracks.is_complete():
		return &"not_finished"
	if beds_taken(barracks) >= barracks.def.soldier_beds:
		return &"barracks_full"
	if not province.treasury.can_pay(unit.gold_cost):
		return &"not_enough_gold"
	for good: StringName in unit.gear:
		if province.nearest_source(good, unit.gear[good], barracks.entrance_tile()) == 0:
			return &"no_gear"
	if free_resident_house(province, barracks) == null:
		return &"no_free_resident"
	return &""


## The house nearest to [param barracks] with a resident of working age without a job; null
## when everybody able to work has one.
static func free_resident_house(province: ProvinceSim, barracks: BuildingState) -> BuildingState:
	var employed: Dictionary[int, int] = {}
	for agent: Agent in province.agents.all():
		if agent.home_id != 0 and agent.workplace_id != 0:
			employed[agent.home_id] = employed.get(agent.home_id, 0) + 1
	var best: BuildingState = null
	var best_d := 1 << 30
	for building: BuildingState in province.buildings.all():
		var house := building.house
		if house == null or house.residents <= 0:
			continue
		if house.workforce() - employed.get(building.id, 0) <= 0:
			continue
		var d := (building.entrance_tile() - barracks.entrance_tile()).length_squared()
		if d < best_d:
			best_d = d
			best = building
	return best


## Recruits [param unit] (checked with [method recruit_error]): pays, takes the resident out
## of his house and sends him for his gear, which is reserved for him at once.
static func recruit(province: ProvinceSim, barracks: BuildingState, unit: UnitDef) -> Agent:
	var home := free_resident_house(province, barracks)
	province.treasury.pay(unit.gold_cost)
	home.house.residents -= 1
	var agent := province.spawn_agent(RECRUIT_KIND, home.entrance_tile())
	agent.home_id = barracks.id
	var picks: Array[int] = []
	for good: StringName in gear_goods(unit):
		var src := province.nearest_source(good, unit.gear[good], barracks.entrance_tile())
		var stock := province.storage(src)
		var res := stock.reserve_out(good, unit.gear[good], agent.id) if stock != null else 0
		picks.append(src if res != 0 else 0)
		picks.append(res)
	var task := Task.new()
	task.kind = Task.KIND_ENLIST
	task.bb = {"unit": String(unit.id), "picks": picks, "pick": 0}
	task.steps = enlist_steps()
	agent.task = task
	barracks.recruits.append(agent.id)
	province.events.emit(&"recruit_called", {"agent": agent.id, "barracks": barracks.id,
			"unit": unit.id, "house": home.id})
	return agent


## Gear goods of [param unit] in a fixed (sorted) order: the order of a recruit's pick-ups.
static func gear_goods(unit: UnitDef) -> Array[StringName]:
	var goods: Array[StringName] = []
	goods.assign(unit.gear.keys())
	goods.sort()
	return goods


static var _enlist_steps: Array[StepDef] = []
static var _soldier_steps: Array[StepDef] = []


static func enlist_steps() -> Array[StepDef]:
	if _enlist_steps.is_empty():
		_enlist_steps = [EnlistStepDef.new()]
	return _enlist_steps


static func soldier_steps() -> Array[StepDef]:
	if _soldier_steps.is_empty():
		_soldier_steps = [SoldierStepDef.new()]
	return _soldier_steps


## A soldier (or a recruit) of [param agent]'s kind: the unit he is, or null.
static func unit_of(province: ProvinceSim, agent: Agent) -> UnitDef:
	return province.data.get_unit(agent.kind)


## Sets a soldier without a task to his place at the barracks. A soldier or recruit whose
## barracks is gone, or a recruit who lost his task (he never fails it otherwise), leaves:
## he walks off the map like nobody's newcomer (a house takes a newcomer later).
static func start_next(province: ProvinceSim, agent: Agent) -> void:
	var barracks := province.buildings.get_building(agent.home_id)
	if barracks == null or barracks.def.soldier_beds <= 0 or agent.kind == RECRUIT_KIND:
		if barracks != null:
			barracks.recruits.erase(agent.id)
			barracks.soldiers.erase(agent.id)
		province.remove_agent(agent)
		return
	var task := Task.new()
	task.kind = Task.KIND_SOLDIER
	task.steps = soldier_steps()
	agent.task = task


## Whether [param agent] is a recruit or a soldier of a barracks (M7).
static func is_military(province: ProvinceSim, agent: Agent) -> bool:
	return agent.kind == RECRUIT_KIND or province.data.get_unit(agent.kind) != null


## Where the soldier at [param index] of the barracks' soldiers stands: a position on the
## parade ground (grid space), or Agent.NO_TILE's centre-less marker (-1, -1) to rest inside.
static func post_of(province: ProvinceSim, barracks: BuildingState, index: int) -> Vector2:
	if index < 0 or index >= PARADE_SLOTS:
		return Vector2(-1, -1)
	var posts := parade_posts(province, barracks)
	return posts[index] if index < posts.size() else Vector2(-1, -1)


## The parade ground of [param barracks]: up to PARADE_SLOTS places, PER_TILE side by side on
## each free walkable tile, nearest the door first (a breadth-first walk from the door).
static func parade_posts(province: ProvinceSim, barracks: BuildingState) -> Array:
	var version := province.blocking_version()
	var cached: Array = _posts.get(barracks.id, [])
	if not cached.is_empty() and int(cached[0]) == version:
		return cached[1]
	var posts: Array = []
	var start := province.door_tile(barracks)
	if start != Agent.NO_TILE:
		var seen: Dictionary[Vector2i, int] = {start: 0}
		var queue: Array[Vector2i] = [start]
		var head := 0
		while head < queue.size() and posts.size() < PARADE_SLOTS:
			var tile := queue[head]
			head += 1
			if _parade_tile(province, tile):
				# Side by side on the screen: both on the same x + y (one screen row).
				posts.append(Vector2(tile) + Vector2(0.3, 0.7))
				posts.append(Vector2(tile) + Vector2(0.7, 0.3))
			if seen[tile] >= PARADE_REACH:
				continue
			for step: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
				var next := tile + step
				if seen.has(next) or not province.nav.is_walkable(next):
					continue
				seen[next] = seen[tile] + 1
				queue.append(next)
	posts.resize(mini(posts.size(), PARADE_SLOTS))
	_posts[barracks.id] = [version, posts]
	return posts


## Open ground for drilling: walkable, no building, road, field or pile on it.
static func _parade_tile(province: ProvinceSim, tile: Vector2i) -> bool:
	if not province.grid.is_inside(tile) or not province.nav.is_walkable(tile):
		return false
	if province.grid.occupant(tile) != 0 or province.grid.has_road(tile):
		return false
	return not province.fields.has_field(tile) and province.resources.amount(tile) <= 0


## Whether the ranks of a barracks drill at [param tick] (all together), else stand at attention.
static func drilling(tick: int) -> bool:
	return (tick / SimClock.TICKS_PER_SECOND) % DRILL_ROUND < DRILL_ON


# --- Simplified mode -----------------------------------------------------------------------

## A soldier or recruit leaving the map as the province is frozen (ProvinceAbstract): kept by
## kind in the barracks; a recruit takes his reserved gear at once.
static func take_off(province: ProvinceSim, agent: Agent) -> bool:
	var barracks := province.buildings.get_building(agent.home_id)
	if barracks == null or barracks.def.soldier_beds <= 0:
		return false
	var unit_id := agent.kind
	if agent.kind == RECRUIT_KIND:
		if agent.task == null:
			return false
		unit_id = StringName(String(agent.task.bb.get("unit", "")))
		var unit := province.data.get_unit(unit_id)
		if unit == null:
			return false
		EnlistStep.take_rest_at_once(province, agent, unit)
		barracks.recruits.erase(agent.id)
	barracks.soldiers.erase(agent.id)
	barracks.garrison.append(unit_id)
	return true


## The soldiers kept by number come back as people at the door of their barracks.
static func thaw(province: ProvinceSim) -> void:
	for barracks: BuildingState in province.buildings.all():
		for unit_id: StringName in barracks.garrison:
			var unit := province.data.get_unit(unit_id)
			if unit == null:
				continue
			var agent := province.spawn_agent(unit_id, barracks.entrance_tile())
			agent.home_id = barracks.id
			agent.combat = CombatState.new(unit.combat.hp if unit.combat != null else 100)
			barracks.soldiers.append(agent.id)
		barracks.garrison.clear()
