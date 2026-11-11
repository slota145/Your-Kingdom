class_name Population
extends RefCounted
## Houses, needs, happiness and the workforce (GDD §3, ROADMAP M3 decisions). Each house
## updates once per second of game time, in the tick of its id (step 8 of ARCHITECTURE §4.2):
## - households eat from their pantry; a householder fetches more when it runs low,
## - happiness moves towards the sum of satisfied need weights, less the weights of unmet
##   basic needs (the more is missing, the lower),
## - all basic needs met long enough -> upgrade site; a house never goes back a level: unmet
##   basic needs pull happiness down (less tax, slower work), then a warning, and a very
##   unhappy house slowly loses residents, but never below half of its places (decision
##   2026-11-06: a short supply must not empty the town and lock the player),
## - newcomers walk in from the map edge to free places of happy houses; a house with a
##   shortage still fills up to half,
## - houses pay taxes by class, happiness and the tax rate (GDD §3.5),
## - about half of the residents work: free ones are handed to buildings missing workers,
##   higher work priority first; a high-priority building may take a worker from a lower one.

const UPDATE_TICKS := 10
## Happiness points per second towards the target.
const HAPPINESS_SPEED := 2.0
## Seconds with all basic needs met before a house starts upgrading (GDD §3.3).
const UPGRADE_AFTER := 60
## E2 part 3 (owner 2026-11-11, "a few of many"): each need met gives its points (a level's
## sum is 100). A fed house with at least CALM_POINTS is calm: nobody leaves and newcomers come.
## Upgrading asks for UPGRADE_POINTS and the next level's food and goods in the storages.
const CALM_POINTS := 60.0
const UPGRADE_POINTS := 85.0
## Tax: each kind of food above the level's minimum adds this share, and each full 10 points
## above CALM_POINTS adds POINTS_TAX_BONUS.
const DIET_TAX_BONUS := 0.10
const POINTS_TAX_BONUS := 0.05
## Seconds with unmet basic needs before a warning (GDD §3.3).
const WARN_AFTER := 60
## While a basic need is unmet, happiness sinks at this (gentler) speed.
const SHORTAGE_SPEED := 1.0
## Below this happiness, with a basic need unmet for LEAVE_AFTER s or more, one resident
## moves out every LEAVE_EVERY s, while the house holds more than half of its places
## (the core stays; decision 2026-11-06).
const LEAVE_BELOW := 40.0
const LEAVE_AFTER := 300
const LEAVE_EVERY := 180
## Newcomers: at most one every IMMIGRATION_EVERY seconds, to houses this happy, or up to half
## of the places to houses at least IMMIGRATION_HALF_HAPPINESS happy.
const IMMIGRATION_EVERY := 10
const IMMIGRATION_MIN_HAPPINESS := 50.0
const IMMIGRATION_HALF_HAPPINESS := 30.0
## Work speed of a worker whose home has no happiness; it rises in a line to full speed at
## FULL_SPEED_HAPPINESS (GDD §3.2: unhappy people work slower).
const MIN_WORK_SPEED := 0.8
const FULL_SPEED_HAPPINESS := 50.0
## Units a householder carries at most.
const ERRAND_LOAD := 2
## Seconds between two top-ups of a pantry in the simplified mode (M6).
const REFILL_EVERY := 5

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


## One second of the houses of a province in the simplified mode (ARCHITECTURE §7.1): the
## same rules on numbers. Pantries are topped up straight from the storages (no
## householders), newcomers move in at once and nobody is hired (ProvinceAbstract staffs the
## workplaces by number).
static func update_abstract(province: ProvinceSim, doors: Dictionary[int, Array] = {}) -> void:
	province.coverage.update(province)
	var stored: Dictionary[StringName, int] = {}
	for building: BuildingState in province.buildings.all():
		if building.house != null:
			_update_house(province, building, stored, true, doors)
	# Newcomers come by the province's entry, as in the detailed mode (none without one).
	if province.tick % (IMMIGRATION_EVERY * UPDATE_TICKS) < UPDATE_TICKS \
			and province.nav.is_walkable(province.entry_tile):
		for building: BuildingState in province.buildings.all():
			var house := building.house
			if house != null and accepts_newcomer(building, province):
				house.residents += 1
				break


# --- Households ----------------------------------------------------------------------------

static func _update_house(province: ProvinceSim, building: BuildingState,
		stored: Dictionary[StringName, int], abstract: bool = false,
		door_cache: Dictionary[int, Array] = {}) -> void:
	var house := building.house
	var level := building.level_def()
	var target := 0.0
	var hungry := false
	var doors: Array[Vector2i] = []
	for need: NeedDef in level.needs:
		if need.is_service() and doors.is_empty():
			if abstract and door_cache.has(building.id):
				doors.assign(door_cache[building.id])
			else:
				doors = province.door_tiles(building)
				if abstract:
					door_cache[building.id] = doors
		var ok := _need_met(province, building, need, doors)
		house.satisfied[need.id] = ok
		if ok:
			target += level.weight_of(need)
		elif need.is_diet() and house.residents > 0:
			# Hungry (too few kinds of food): it counts against the house (E2 part 3).
			hungry = true
			target -= level.weight_of(need)
	house.points = maxf(target, 0.0)
	var calm := not hungry and target >= CALM_POINTS
	if province.raids.mood_until > province.tick:
		target -= Raids.MOOD_PENALTY   # looted by bandits (M7 part 2)
	target = clampf(target + province.treasury.rate_happiness(), 0.0, 100.0)
	var speed := HAPPINESS_SPEED
	if not calm and house.residents > 0:
		speed = SHORTAGE_SPEED
	var happiness := move_toward(house.happiness, target, speed)
	var grace := province.in_grace()
	# Start protection: happiness only rises, and a shortage is not counted yet.
	house.happiness = maxf(house.happiness, happiness) if grace else happiness
	if abstract:
		# Every few seconds is enough: a pantry holds several units (and saves the searches).
		if (province.tick / UPDATE_TICKS + building.id) % REFILL_EVERY == 0:
			_refill_pantry(province, building)
	else:
		_request_supplies(province, building, stored)
	_pay_taxes(province, building)
	if house.residents == 0:
		house.met_seconds = 0
		house.unmet_seconds = 0
		return
	if not hungry and house.points >= UPGRADE_POINTS:
		house.met_seconds += 1
		if house.met_seconds >= UPGRADE_AFTER and building.site_id == 0 \
				and house.level < building.def.house_levels.size() \
				and _next_level_ready(province, building, stored):
			Construction.open_upgrade_site(province, building, building.def.house_levels[house.level])
	else:
		house.met_seconds = 0
	if calm:
		house.unmet_seconds = 0
	elif grace:
		house.unmet_seconds = 0
	else:
		house.unmet_seconds += 1
		if house.unmet_seconds == WARN_AFTER:
			province.events.emit(&"house_warning", {"building": building.id})
		if house.happiness < LEAVE_BELOW and house.unmet_seconds >= LEAVE_AFTER \
				and (house.unmet_seconds - LEAVE_AFTER) % LEAVE_EVERY == 0 \
				and house.residents > core_residents(building):
			house.residents -= 1
			province.events.emit(&"resident_left", {"building": building.id})


## Why the player cannot upgrade [param building] at once ("Upgrade now", E1, owner
## 2026-11-10), &"" when they can: the same conditions as the automatic upgrade (every basic
## need met, the next level's basic goods in store) without the wait of UPGRADE_AFTER.
static func upgrade_blocker(province: ProvinceSim, building: BuildingState) -> StringName:
	if building == null or building.house == null or not building.is_complete():
		return &"not_a_house"
	var house := building.house
	if house.level >= building.def.house_levels.size():
		return &"house_top_level"
	if building.site_id != 0:
		return &"upgrade_running"
	if house.residents == 0:
		return &"house_empty"
	if not is_fed(building) or house.points < UPGRADE_POINTS:
		return &"house_needs_unmet"
	if not next_level_available(province, building):
		return &"house_next_goods_missing"
	return &""


## Opens the upgrade site of [param building] now (UpgradeHouseCommand); the materials still
## have to be carried to it. Returns whether it opened.
static func upgrade_now(province: ProvinceSim, building: BuildingState) -> bool:
	if upgrade_blocker(province, building) != &"":
		return false
	Construction.open_upgrade_site(province, building, building.def.house_levels[building.house.level])
	return building.site_id != 0


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
		if need.is_diet():
			# The next level's number of food kinds, each a full pantry (E2 part 3).
			var kinds := 0
			for good: StringName in need.goods:
				if building.supply.total(good) + _stored(province, good, stored) >= next.supply_units:
					kinds += 1
			if kinds < next.diet_min:
				return false
			continue
		if not need.is_basic or need.is_service():
			continue
		var found := 0
		for good: StringName in need.goods:
			found += building.supply.total(good) + _stored(province, good, stored)
		if found < next.supply_units:
			return false
	return true


## The extra share of tax [param building] pays for more than it needs (E2 part 3): each kind of
## food above the level's minimum and each full 10 points above CALM_POINTS.
static func tax_bonus(building: BuildingState) -> float:
	var house := building.house
	if house == null or house.residents == 0 or not is_fed(building):
		return 0.0
	var extra_kinds := maxi(house.diet_kinds - building.level_def().diet_min, 0)
	var extra_points := maxi(floori((house.points - CALM_POINTS) / 10.0), 0)
	return extra_kinds * DIET_TAX_BONUS + extra_points * POINTS_TAX_BONUS


## Gold a resident of [param building] pays per minute at full happiness and the normal rate:
## burghers and patricians pay their class's tax only in a province with a town hall (its
## seat, M6 part 2), elsewhere what peasants pay.
static func tax_per_minute(province: ProvinceSim, building: BuildingState) -> float:
	if building.house.level > 1 and not province.has_seat():
		return building.def.house_levels[0].tax_per_minute
	return building.level_def().tax_per_minute


## Taxes for one second: gold per resident per minute of the class, scaled by happiness
## and the tax rate.
static func _pay_taxes(province: ProvinceSim, building: BuildingState) -> void:
	var house := building.house
	var per_second := house.residents * tax_per_minute(province, building) / 60.0
	# Extra needs met (wine, M6 part 3) add their bonus.
	for need: NeedDef in building.level_def().needs:
		if need.extra and house.satisfied.get(need.id, false):
			per_second *= 1.0 + need.tax_bonus
	per_second *= 1.0 + tax_bonus(building)
	province.treasury.add(per_second * house.happiness / 100.0 * province.treasury.rate_factor())


## Eats from the pantry and tells whether the need is met right now.
static func _need_met(province: ProvinceSim, building: BuildingState, need: NeedDef,
		doors: Array[Vector2i]) -> bool:
	var house := building.house
	if need.is_diet():
		return _diet_met(province, building, need)
	if need.is_service():
		for door: Vector2i in doors:
			if province.coverage.covers(need.service, door, province.grid.size):
				return true
		return false
	var hunger: float = house.hunger.get(need.id, 0.0) + house.residents * need.per_resident_per_minute / 60.0
	# On a grid a save reads back exactly, so a loaded game goes on alike.
	hunger = SimCodec.savable(hunger)
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


## The diet (E2 part 3): the household eats the kind of food it has most of, so the kinds go
## down together; met while it is fed and keeps at least the level's diet_min kinds.
static func _diet_met(province: ProvinceSim, building: BuildingState, need: NeedDef) -> bool:
	var house := building.house
	var hunger: float = house.hunger.get(need.id, 0.0) + house.residents * need.per_resident_per_minute / 60.0
	hunger = SimCodec.savable(hunger)
	while hunger >= 1.0:
		var best := &""
		var most := 0
		for good: StringName in need.goods:
			var have := building.supply.total(good)
			if have > most:
				best = good
				most = have
		if best == &"" or building.supply.remove(best, 1) != 1:
			break
		hunger -= 1.0
		province.ledger.used(best, 1, province.tick)
		province.events.emit(&"good_consumed", {"building": building.id, "good": best, "amount": 1})
	house.hunger[need.id] = minf(hunger, 1.0)
	var kinds := 0
	for good: StringName in need.goods:
		if building.supply.total(good) > 0:
			kinds += 1
	house.diet_kinds = kinds
	if house.residents == 0:
		return true
	return hunger < 1.0 and kinds >= building.level_def().diet_min


## Fills in the house's points and kinds of food (derived, not saved) from the needs met at
## its last update and its pantry, without eating: right after loading a game, so a paused
## loaded game shows the faces and the panel as they were (E2 part 3).
static func refresh_derived(building: BuildingState) -> void:
	var house := building.house
	var level := building.level_def()
	var target := 0.0
	for need: NeedDef in level.needs:
		var ok := bool(house.satisfied.get(need.id, false))
		if ok:
			target += level.weight_of(need)
		elif need.is_diet() and house.residents > 0:
			target -= level.weight_of(need)
		if need.is_diet():
			var kinds := 0
			for good: StringName in need.goods:
				if building.supply.total(good) > 0:
					kinds += 1
			house.diet_kinds = kinds
	house.points = maxf(target, 0.0)


## Whether [param building]'s household has enough kinds of food (its diet need met).
static func is_fed(building: BuildingState) -> bool:
	for need: NeedDef in building.level_def().needs:
		if need.is_diet() and not bool(building.house.satisfied.get(need.id, false)):
			return false
	return true


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


## The simplified mode's householders: a good in the pantry down to half is topped up at
## once from the storages (ARCHITECTURE §7.1).
static func _refill_pantry(province: ProvinceSim, building: BuildingState) -> void:
	var house := building.house
	house.errands.clear()
	if house.residents == 0:
		return
	var limit := building.level_def().supply_units
	for need: NeedDef in building.level_def().needs:
		for good: StringName in need.goods:
			var have := building.supply.total(good)
			if have * 2 > limit:
				continue
			var room := limit - have
			while room > 0 and not building.supply.can_accept(good, room):
				room -= 1
			if room <= 0:
				continue
			var taken := province.take_from_storages(good, room, building.entrance_tile(), false)
			if taken > 0:
				building.supply.add(good, taken)


# --- Newcomers -----------------------------------------------------------------------------

## Residents an unhappy house keeps whatever happens: half of its places.
static func core_residents(building: BuildingState) -> int:
	return building.capacity() / 2


## Whether a newcomer may move into [param building] now: any free place of a happy house,
## up to half of the places of a less happy one (so a town with a shortage still grows its
## core and can fix the shortage; decision 2026-11-06).
static func accepts_newcomer(building: BuildingState, province: ProvinceSim = null) -> bool:
	var house := building.house
	var capacity := building.capacity()
	if house.free_places(capacity) <= 0:
		return false
	# Start protection keeps happiness up, not the pantry: newcomers come as they would to an
	# unprotected house, which heads for its target happiness (a house short of a basic need
	# fills only up to half when that target is low).
	var happiness := house.happiness
	if province != null and province.in_grace():
		happiness = minf(happiness, target_happiness(province, building))
	if happiness >= IMMIGRATION_MIN_HAPPINESS:
		return true
	return happiness >= IMMIGRATION_HALF_HAPPINESS \
			and house.residents + house.incoming < core_residents(building)


## The happiness [param building]'s house heads for by the needs met at its last update (as in
## _update_house).
static func target_happiness(province: ProvinceSim, building: BuildingState) -> float:
	var house := building.house
	var level := building.level_def()
	var target := 0.0
	for need: NeedDef in level.needs:
		if house.satisfied.get(need.id, false):
			target += level.weight_of(need)
		elif need.is_diet() and house.residents > 0:
			target -= level.weight_of(need)
	return clampf(target + province.treasury.rate_happiness(), 0.0, 100.0)


## Work speed (1 = normal) of a worker living in [param home]: slower when the home is
## unhappy, down to MIN_WORK_SPEED (GDD §3.2). A worker without a home works normally.
static func work_speed_of(home: BuildingState) -> float:
	if home == null or home.house == null:
		return 1.0
	var t := clampf(home.house.happiness / FULL_SPEED_HAPPINESS, 0.0, 1.0)
	return lerpf(MIN_WORK_SPEED, 1.0, t)


## Work speed of the province as a whole, for the simplified mode where workers have no
## homes: [method work_speed_of] averaged over the residents.
static func average_work_speed(province: ProvinceSim) -> float:
	var residents := 0
	var sum := 0.0
	for building: BuildingState in province.buildings.all():
		if building.house != null and building.house.residents > 0:
			residents += building.house.residents
			sum += work_speed_of(building) * building.house.residents
	return sum / residents if residents > 0 else 1.0


## [method work_speed_of] for [param agent].
static func work_speed(province: ProvinceSim, agent: Agent) -> float:
	if agent.home_id == 0:
		return 1.0
	return work_speed_of(province.buildings.get_building(agent.home_id))


static func _immigrate(province: ProvinceSim) -> void:
	if not province.nav.is_walkable(province.entry_tile):
		return
	for building: BuildingState in province.buildings.all():
		var house := building.house
		if house == null or not accepts_newcomer(building, province):
			continue
		var agent := province.spawn_agent(SETTLER_KIND, province.entry_tile)
		agent.home_id = building.id
		TaskRunner.start_move_in(agent)
		house.incoming += 1
		return


# --- Workforce -----------------------------------------------------------------------------

## Hires workers for every workplace short of them, the new ones standing at their
## workplaces (a province coming back from the simplified mode, ARCHITECTURE §7.2).
static func staff_at_workplaces(province: ProvinceSim) -> void:
	_balance_workforce(province, true)


## Workers each workplace would have by the rules of [method _balance_workforce] (player's
## priority, staffing priority, age), counted without people: building id -> workers. Workers
## without a house (the pioneer camp's settlers) come in [param homeless].
static func staffing(province: ProvinceSim, homeless: Dictionary[int, int]) -> Dictionary[int, int]:
	var free := 0
	for building: BuildingState in province.buildings.all():
		if building.house != null:
			free += building.house.workforce()
	var workplaces: Array[BuildingState] = []
	for building: BuildingState in province.buildings.all():
		if building.is_complete() and building.def.worker_count() > 0:
			workplaces.append(building)
	workplaces.sort_custom(_staffed_before)
	var result: Dictionary[int, int] = {}
	for workplace: BuildingState in workplaces:
		var have: int = mini(homeless.get(workplace.id, 0), workplace.def.worker_count())
		var hired := mini(workplace.def.worker_count() - have, free)
		free -= hired
		if have + hired > 0:
			result[workplace.id] = have + hired
	return result


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
static func _balance_workforce(province: ProvinceSim, at_workplace: bool = false) -> void:
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
	# A workplace that needs fewer workers than it has (the port warehouses lost their porters
	# in P2 part 1: an older game's go home).
	for building: BuildingState in province.buildings.all():
		while building.workers.size() > building.def.worker_count():
			var extra := province.agents.get_agent(building.workers.back())
			if extra == null:
				building.workers.pop_back()
			else:
				province.remove_agent(extra)
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
			var at := home.entrance_tile()
			if at_workplace:
				at = workplace.entrance_tile()
			var agent := province.spawn_agent(kind, at)
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


## Worker kinds [param workplace] still lacks.
static func missing_kinds(province: ProvinceSim, workplace: BuildingState) -> Array[StringName]:
	return _missing_kinds(province, workplace)


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
