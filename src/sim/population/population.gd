class_name Population
extends RefCounted
## Houses, needs, happiness and the workforce (GDD §3, ROADMAP M3 decisions). Runs once per
## second of game time (step 8 of ARCHITECTURE §4.2):
## - households eat from their pantry; a householder fetches more when it runs low,
## - happiness moves towards the sum of satisfied need weights,
## - all basic needs met long enough -> upgrade site; unmet too long -> warning, then decline,
## - newcomers walk in from the map edge to free places of happy houses,
## - about half of the residents work: free ones are handed to buildings missing workers.

const UPDATE_TICKS := 10
## Happiness points per second towards the target.
const HAPPINESS_SPEED := 2.0
## Seconds with all basic needs met before a house starts upgrading (GDD §3.3).
const UPGRADE_AFTER := 60
## Seconds with unmet basic needs before a warning / before decline (GDD §3.3).
const WARN_AFTER := 60
const DECLINE_AFTER := 180
## A level-1 house in decline loses one resident this often (seconds).
const LEAVE_EVERY := 60
## Newcomers: at most one every IMMIGRATION_EVERY seconds, only to houses this happy.
const IMMIGRATION_EVERY := 10
const IMMIGRATION_MIN_HAPPINESS := 50.0
## Units a householder carries at most.
const ERRAND_LOAD := 2

const HOUSEHOLDER_KIND := &"householder"
const SETTLER_KIND := &"settler"


static func update(province: ProvinceSim) -> void:
	if province.tick % UPDATE_TICKS != 0:
		return
	province.coverage.update(province)
	for building: BuildingState in province.buildings.all():
		if building.house != null:
			_update_house(province, building)
	if province.tick % (IMMIGRATION_EVERY * UPDATE_TICKS) == 0:
		_immigrate(province)
	_balance_workforce(province)


# --- Households ----------------------------------------------------------------------------

static func _update_house(province: ProvinceSim, building: BuildingState) -> void:
	var house := building.house
	var level := building.level_def()
	var target := 0.0
	var basic_met := true
	for need: NeedDef in level.needs:
		var ok := _need_met(province, building, need)
		house.satisfied[need.id] = ok
		if ok:
			target += need.weight
		elif need.is_basic:
			basic_met = false
	house.happiness = move_toward(house.happiness, target, HAPPINESS_SPEED)
	_request_supplies(province, building)
	if house.residents == 0:
		house.met_seconds = 0
		house.unmet_seconds = 0
		return
	if basic_met:
		house.met_seconds += 1
		house.unmet_seconds = 0
		if house.met_seconds >= UPGRADE_AFTER and building.site_id == 0 \
				and house.level < building.def.house_levels.size():
			Construction.open_upgrade_site(province, building, building.def.house_levels[house.level])
	else:
		house.met_seconds = 0
		house.unmet_seconds += 1
		if house.unmet_seconds == WARN_AFTER:
			province.events.emit(&"house_warning", {"building": building.id})
		if house.unmet_seconds >= DECLINE_AFTER:
			_decline(province, building)


## Eats from the pantry and tells whether the need is met right now.
static func _need_met(province: ProvinceSim, building: BuildingState, need: NeedDef) -> bool:
	var house := building.house
	if need.is_service():
		return province.coverage.covers(need.service, building.entrance_tile(), province.grid.size)
	var hunger: float = house.hunger.get(need.id, 0.0) + house.residents * need.per_resident_per_minute / 60.0
	for good: StringName in need.goods:
		while hunger >= 1.0 and building.supply.remove(good, 1) == 1:
			hunger -= 1.0
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


## Sends a householder to the nearest storage when a good in the pantry is down to half.
static func _request_supplies(province: ProvinceSim, building: BuildingState) -> void:
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
			while amount > 0 and province.nearest_source(good, amount, building.entrance_tile()) == 0:
				amount -= 1
			if amount <= 0 or not building.supply.can_accept(good, amount):
				continue
			var agent := province.spawn_agent(HOUSEHOLDER_KIND, building.entrance_tile())
			agent.home_id = building.id
			TaskRunner.start_errand(agent, good, amount, building.id)
			house.errands[good] = agent.id


static func _decline(province: ProvinceSim, building: BuildingState) -> void:
	var house := building.house
	if house.level > 1:
		if house.unmet_seconds == DECLINE_AFTER:
			house.level -= 1
			building.supply.stack_limit = building.level_def().supply_units
			_trim_pantry(province, building)
			var excess := house.residents - building.capacity()
			if excess > 0:
				house.residents -= excess
			house.unmet_seconds = 0
			province.events.emit(&"house_downgraded", {"building": building.id, "level": house.level})
	elif (house.unmet_seconds - DECLINE_AFTER) % LEAVE_EVERY == 0 and house.residents > 0:
		house.residents -= 1
		province.events.emit(&"resident_left", {"building": building.id})


## Goods above the smaller pantry go on the ground for porters.
static func _trim_pantry(province: ProvinceSim, building: BuildingState) -> void:
	for good: StringName in building.house_goods():
		var extra := building.supply.total(good) - building.level_def().supply_units
		if extra > 0:
			var taken := building.supply.remove(good, extra)
			if taken > 0:
				province.drop_goods(building.entrance_tile(), good, taken)


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
## workers (lowest staffing priority first, then oldest building; nearest house first).
static func _balance_workforce(province: ProvinceSim) -> void:
	var free: Dictionary[int, int] = {}
	var houses: Array[BuildingState] = []
	for building: BuildingState in province.buildings.all():
		if building.house == null:
			continue
		var employed := employed_from(province, building.id)
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
	workplaces.sort_custom(func(a: BuildingState, b: BuildingState) -> bool:
		if a.def.staffing_priority != b.def.staffing_priority:
			return a.def.staffing_priority < b.def.staffing_priority
		return a.id < b.id)
	for workplace: BuildingState in workplaces:
		for kind: StringName in _missing_kinds(province, workplace):
			var home := _nearest_free_house(houses, free, workplace.entrance_tile())
			if home == null:
				return
			free[home.id] -= 1
			var agent := province.spawn_agent(kind, home.entrance_tile())
			agent.home_id = home.id
			province.assign_worker(agent, workplace)
			province.events.emit(&"worker_hired", {"agent": agent.id, "building": workplace.id,
					"home": home.id})


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
