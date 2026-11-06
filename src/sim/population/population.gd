class_name Population
extends RefCounted
## Houses, needs, happiness and the workforce (GDD §3, ROADMAP M3 decisions). Each house
## updates once per second of game time, in the tick of its id (step 8 of ARCHITECTURE §4.2):
## - households eat from their pantry; a householder fetches more when it runs low,
## - happiness moves towards the sum of satisfied need weights,
## - all basic needs met long enough -> upgrade site; a house never goes back a level: unmet
##   basic needs pull happiness down, then a warning, and an unhappy house loses residents
##   one by one (it fills up again once the needs are met; decision 2026-11-05),
## - newcomers walk in from the map edge to free places of happy houses,
## - houses pay taxes by class, happiness and the tax rate (GDD §3.5),
## - about half of the residents work: free ones are handed to buildings missing workers,
##   higher work priority first; a high-priority building may take a worker from a lower one.

const UPDATE_TICKS := 10
## Happiness points per second towards the target.
const HAPPINESS_SPEED := 2.0
## Seconds with all basic needs met before a house starts upgrading (GDD §3.3).
const UPGRADE_AFTER := 60
## Seconds with unmet basic needs before a warning (GDD §3.3).
const WARN_AFTER := 60
## While a basic need is unmet, happiness sinks towards this cap, at this (gentler) speed.
const SHORTAGE_HAPPINESS := 20.0
const SHORTAGE_SPEED := 1.0
## Below this happiness, with a basic need unmet for LEAVE_AFTER s or more, one resident
## moves out every LEAVE_EVERY s.
const LEAVE_BELOW := 25.0
const LEAVE_AFTER := 180
const LEAVE_EVERY := 60
## Newcomers: at most one every IMMIGRATION_EVERY seconds, only to houses this happy.
const IMMIGRATION_EVERY := 10
const IMMIGRATION_MIN_HAPPINESS := 50.0
## Units a householder carries at most.
const ERRAND_LOAD := 2

const HOUSEHOLDER_KIND := &"householder"
const SETTLER_KIND := &"settler"


static func update(province: ProvinceSim) -> void:
	# Each house has its own tick within the second (its id), so a big town does not do all
	# its houses in one tick (M4b-3, ARCHITECTURE §9.3).
	var slot := province.tick % UPDATE_TICKS
	province.coverage.update(province)
	# Goods in storage do not change while houses update (errands and upgrade sites reserve
	# nothing yet), so each good is counted once per tick.
	var stored: Dictionary[StringName, int] = {}
	for building: BuildingState in province.buildings.all():
		if building.house != null and building.id % UPDATE_TICKS == slot:
			_update_house(province, building, stored)
	# Newcomers choose in the last tick of the second, when every house has updated.
	if province.tick % (IMMIGRATION_EVERY * UPDATE_TICKS) == UPDATE_TICKS - 1:
		_immigrate(province)
	if slot == 0:
		_balance_workforce(province)


# --- Households ----------------------------------------------------------------------------

static func _update_house(province: ProvinceSim, building: BuildingState,
		stored: Dictionary[StringName, int]) -> void:
	var house := building.house
	var level := building.level_def()
	var target := 0.0
	var basic_met := true
	var doors: Array[Vector2i] = []
	for need: NeedDef in level.needs:
		if need.is_service() and doors.is_empty():
			doors = province.door_tiles(building)
		var ok := _need_met(province, building, need, doors)
		house.satisfied[need.id] = ok
		if ok:
			target += level.weight_of(need)
		elif need.is_basic:
			basic_met = false
	target = clampf(target + province.treasury.rate_happiness(), 0.0, 100.0)
	var speed := HAPPINESS_SPEED
	if not basic_met and house.residents > 0:
		target = minf(target, SHORTAGE_HAPPINESS)
		speed = SHORTAGE_SPEED
	house.happiness = move_toward(house.happiness, target, speed)
	_request_supplies(province, building, stored)
	_pay_taxes(province, building)
	if house.residents == 0:
		house.met_seconds = 0
		house.unmet_seconds = 0
		return
	if basic_met:
		house.met_seconds += 1
		house.unmet_seconds = 0
		if house.met_seconds >= UPGRADE_AFTER and building.site_id == 0 \
				and house.level < building.def.house_levels.size() \
				and _next_level_ready(province, building, stored):
			Construction.open_upgrade_site(province, building, building.def.house_levels[house.level])
	else:
		house.met_seconds = 0
		house.unmet_seconds += 1
		if house.unmet_seconds == WARN_AFTER:
			province.events.emit(&"house_warning", {"building": building.id})
		if house.happiness < LEAVE_BELOW and house.unmet_seconds >= LEAVE_AFTER \
				and (house.unmet_seconds - LEAVE_AFTER) % LEAVE_EVERY == 0:
			house.residents -= 1
			province.events.emit(&"resident_left", {"building": building.id})


## Whether the town can already supply the basic goods of the next level: a full pantry of
## each (the next level's supply units) in the pantry and the storages together. Without it a
## house would upgrade, go short and decline again, wasting the materials (M4a balance, found
## by the automatic player).
static func next_level_available(province: ProvinceSim, building: BuildingState) -> bool:
	return _next_level_ready(province, building, {})


## [method next_level_available] with the storage totals counted so far in [param stored].
static func _next_level_ready(province: ProvinceSim, building: BuildingState,
		stored: Dictionary[StringName, int]) -> bool:
	var next := building.def.house_levels[building.house.level]
	for need: NeedDef in next.needs:
		if not need.is_basic or need.is_service():
			continue
		var found := 0
		for good: StringName in need.goods:
			found += building.supply.total(good) + _stored(province, good, stored)
		if found < next.supply_units:
			return false
	return true


## Taxes for one second: gold per resident per minute of the class, scaled by happiness
## and the tax rate.
static func _pay_taxes(province: ProvinceSim, building: BuildingState) -> void:
	var house := building.house
	var per_second := house.residents * building.level_def().tax_per_minute / 60.0
	province.treasury.add(per_second * house.happiness / 100.0 * province.treasury.rate_factor())


## Eats from the pantry and tells whether the need is met right now.
static func _need_met(province: ProvinceSim, building: BuildingState, need: NeedDef,
		doors: Array[Vector2i]) -> bool:
	var house := building.house
	if need.is_service():
		for door: Vector2i in doors:
			if province.coverage.covers(need.service, door, province.grid.size):
				return true
		return false
	var hunger: float = house.hunger.get(need.id, 0.0) + house.residents * need.per_resident_per_minute / 60.0
	for good: StringName in need.goods:
		while hunger >= 1.0 and building.supply.remove(good, 1) == 1:
			hunger -= 1.0
			province.ledger.used(good, 1, province.tick)
			province.events.emit(&"good_consumed", {"building": building.id, "good": good,
					"amount": 1})
	# Unfed hunger does not pile up beyond one unit: the house is simply short.
	house.hunger[need.id] = minf(hunger, 1.0)
	if hunger >= 1.0:
		return false
	for good: StringName in need.goods:
		if building.supply.total(good) > 0:
			return true
	return house.residents == 0


## Units of [param good] in storages, stalls and ground piles: what the searches for a source
## can find at most. Counted once per update ([param stored]).
static func _stored(province: ProvinceSim, good: StringName, stored: Dictionary[StringName, int]) -> int:
	if not stored.has(good):
		stored[good] = province.stored(good)
	return stored[good]


static func _findable(province: ProvinceSim, good: StringName, cache: Dictionary[StringName, int]) -> int:
	var key := StringName("pile:" + good)
	if not cache.has(key):
		var sum := 0
		for pile: GroundPile in province.piles.values():
			sum += pile.stock.total(good)
		cache[key] = sum
	return cache[key] + _stored(province, good, cache)


## Sends a householder to the nearest storage when a good in the pantry is down to half.
static func _request_supplies(province: ProvinceSim, building: BuildingState,
		stored: Dictionary[StringName, int]) -> void:
	var house := building.house
	if house.residents == 0:
		return
	var limit := building.level_def().supply_units
	for need: NeedDef in building.level_def().needs:
		for good: StringName in need.goods:
			if house.errands.has(good):
				continue
			var have := building.supply.total(good)
			if have * 2 > limit:
				continue
			var amount := mini(limit - have, ERRAND_LOAD)
			# No search can find more than the town holds (cheap check first, M4b-3).
			amount = mini(amount, _findable(province, good, stored))
			if amount <= 0 or not building.supply.can_accept(good, 1):
				continue
			# A market in range with the good on its stalls comes first (M4b-2).
			var market := 0
			while amount > 0:
				market = province.market_source(good, amount, building)
				if market != 0 or province.nearest_source(good, amount, building.entrance_tile()) != 0:
					break
				amount -= 1
			if amount <= 0 or not building.supply.can_accept(good, amount):
				continue
			var agent := province.spawn_agent(HOUSEHOLDER_KIND, building.entrance_tile())
			agent.home_id = building.id
			TaskRunner.start_errand(agent, good, amount, building.id, market)
			house.errands[good] = agent.id


# --- Newcomers -----------------------------------------------------------------------------

static func _immigrate(province: ProvinceSim) -> void:
	if not province.nav.is_walkable(province.entry_tile):
		return
	for building: BuildingState in province.buildings.all():
		var house := building.house
		if house == null or house.free_places(building.capacity()) <= 0 \
				or house.happiness < IMMIGRATION_MIN_HAPPINESS:
			continue
		var agent := province.spawn_agent(SETTLER_KIND, province.entry_tile)
		agent.home_id = building.id
		TaskRunner.start_move_in(agent)
		house.incoming += 1
		return


# --- Workforce -----------------------------------------------------------------------------

static func workforce(province: ProvinceSim) -> int:
	var sum := 0
	for building: BuildingState in province.buildings.all():
		if building.house != null:
			sum += building.house.workforce()
	return sum


static func employed_from(province: ProvinceSim, house_id: int) -> Array[Agent]:
	var result: Array[Agent] = []
	for agent: Agent in province.agents.all():
		if agent.home_id == house_id and agent.workplace_id != 0:
			result.append(agent)
	return result


## Fires workers of houses that shrank, then hands free residents to buildings missing
## workers (player's work priority first, then the building's staffing priority, then the
## oldest building; nearest house first). When nobody is free and a building stays short,
## one worker of the lowest-priority building below it goes home, to be hired again next
## second by the more important one.
static func _balance_workforce(province: ProvinceSim) -> void:
	var free: Dictionary[int, int] = {}
	var houses: Array[BuildingState] = []
	var employed_by_house: Dictionary[int, Array] = {}
	for agent: Agent in province.agents.all():
		if agent.home_id != 0 and agent.workplace_id != 0:
			if not employed_by_house.has(agent.home_id):
				employed_by_house[agent.home_id] = []
			employed_by_house[agent.home_id].append(agent)
	for building: BuildingState in province.buildings.all():
		if building.house == null:
			continue
		var employed: Array = employed_by_house.get(building.id, [])
		var spare := building.house.workforce() - employed.size()
		while spare < 0:
			province.remove_agent(employed.pop_back())
			spare += 1
		free[building.id] = spare
		houses.append(building)
	var workplaces: Array[BuildingState] = []
	for building: BuildingState in province.buildings.all():
		if building.is_complete() and building.workers.size() < building.def.worker_count():
			workplaces.append(building)
	workplaces.sort_custom(_staffed_before)
	for workplace: BuildingState in workplaces:
		for kind: StringName in _missing_kinds(province, workplace):
			var home := _nearest_free_house(houses, free, workplace.entrance_tile())
			if home == null:
				_free_worker_for(province, workplace)
				return
			free[home.id] -= 1
			var agent := province.spawn_agent(kind, home.entrance_tile())
			agent.home_id = home.id
			province.assign_worker(agent, workplace)
			province.events.emit(&"worker_hired", {"agent": agent.id, "building": workplace.id,
					"home": home.id})


static func _staffed_before(a: BuildingState, b: BuildingState) -> bool:
	if a.priority != b.priority:
		return a.priority < b.priority
	if a.def.staffing_priority != b.def.staffing_priority:
		return a.def.staffing_priority < b.def.staffing_priority
	return a.id < b.id


## Sends home one worker of the lowest-priority (then newest) building whose player priority
## is below [param needy]'s.
static func _free_worker_for(province: ProvinceSim, needy: BuildingState) -> void:
	var victim: BuildingState = null
	for building: BuildingState in province.buildings.all():
		if building.priority <= needy.priority or building.workers.is_empty():
			continue
		if victim == null or building.priority > victim.priority \
				or (building.priority == victim.priority and building.id > victim.id):
			victim = building
	if victim == null:
		return
	var agent := province.agents.get_agent(victim.workers[victim.workers.size() - 1])
	if agent != null:
		province.remove_agent(agent)
		province.events.emit(&"worker_reassigned", {"agent": agent.id, "from": victim.id,
				"to": needy.id})


static func _missing_kinds(province: ProvinceSim, workplace: BuildingState) -> Array[StringName]:
	var missing: Array[StringName] = workplace.def.worker_kinds.duplicate()
	for id: int in workplace.workers:
		var agent := province.agents.get_agent(id)
		if agent != null:
			missing.erase(agent.kind)
	return missing


static func _nearest_free_house(houses: Array[BuildingState], free: Dictionary[int, int],
		to: Vector2i) -> BuildingState:
	var best: BuildingState = null
	var best_d := 1 << 30
	for house: BuildingState in houses:
		if free[house.id] <= 0:
			continue
		var d := (house.entrance_tile() - to).length_squared()
		if d < best_d:
			best_d = d
			best = house
	return best
