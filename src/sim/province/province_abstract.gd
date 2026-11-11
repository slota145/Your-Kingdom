class_name ProvinceAbstract
extends RefCounted
## A province nobody looks at, in the simplified mode (ARCHITECTURE §7.1): no people, only
## numbers, updated once a second of game time.
##
## It keeps the province's detail (map, buildings, stores, fields, ships) frozen without people
## and works on those numbers directly, so leaving and entering a province never copies goods:
## - workplaces are staffed by number (Population.staffing) and work in cycles (WorkCycle) at
##   the speed measured while the province was viewed (ProductionLog), or estimated from the
##   work and the walk to the nearest storage; inputs come from the storages, outputs go to
##   them, a full kingdom or a missing input stops the cycle,
## - houses eat, pay taxes, grow and decline by the same rules (Population.update_abstract),
## - porters bring materials to construction sites and slipways, builders and shipwrights
##   work them off,
## - goods on the ground, on quays and in production yards go to storages,
## - herds breed, trees grow, merchants come and trade at once, the player's cog sails its
##   voyage by the clock.

## Ticks between two updates (1 s of game time).
const STEP_TICKS := 10
## Units a porter brings to sites per second in the simplified mode (a walk there and back
## with a load of two takes about 20 s).
const PORTER_RATE := 0.1
## Walk to a storage assumed when none can be reached (tiles).
const DEFAULT_WALK := 10.0
## Sailing out to fish and back, for a wharf's boat without a measurement (seconds).
const SAIL_SECONDS := 40.0
## Seconds a workplace waits after a cycle could not happen (no input, no tree, no room)
## before it looks again: the searches cost, and the detailed mode waits too
## (TaskRunner.RETRY_TICKS, IDLE_RETRY_TICKS).
const RETRY_SECONDS := 5
## Seconds between two countings of the workers (houses grow and shrink slowly).
const STAFF_EVERY := 10
## Seconds between two rounds of the porters and builders (sites and hauling): they do the
## work of all those seconds at once.
const BUILD_EVERY := 5

## The frozen province: everything but people. Its events go to a private queue nobody reads.
var detail: ProvinceSim
## Building id -> workers it has now (counted every second).
var staff: Dictionary[int, int] = {}
## Building id -> kinds of its workers without a house (the pioneer camp's settlers).
var homeless: Dictionary[int, Array] = {}
## Settlers of a landing without a house or a workplace yet (kinds).
var wanderers: Array[StringName] = []
## Building id -> cycles done towards the next one (0..1).
var progress: Dictionary[int, float] = {}
## Building id -> tick before which a workplace whose cycle could not happen waits.
var _wait_until: Dictionary[int, int] = {}
## Units porters may still bring to sites this second (fractions carry over).
var _carry_budget: float = 0.0
## House id -> its door tiles (the map does not change without people); derived, not saved.
var _doors: Dictionary[int, Array] = {}
## Building id -> work cycles per second, refreshed with the staff; derived, not saved.
var _rates: Dictionary[int, float] = {}
## Construction site or slipway id -> whether its transport requests match what it still needs.
var _synced: Dictionary[int, bool] = {}
## Good -> storage id last used to put it away / take it from (searches are dear; any store
## does without people walking); derived, not saved.
var _sinks: Dictionary[StringName, int] = {}
var _sources: Dictionary[StringName, int] = {}
## Forester id -> next tile of its work area to try for planting; derived, not saved.
var _plant_cursor: Dictionary[int, int] = {}
## Farm id -> its fields, counted once per update; derived, not saved.
var _fields: Dictionary[int, int] = {}
## Building id -> estimated walk to the nearest storage (tiles); derived, not saved.
var _walk: Dictionary[int, float] = {}


## The simplified mode of [param province] from now on (ARCHITECTURE §7.2): what is under way
## is finished at once (the landing, ships sailing), people leave the map, what they carry
## goes to where it was going (or a storage, or the ground), nothing stays reserved.
static func freeze(province: ProvinceSim, tick: int) -> ProvinceAbstract:
	var abstract := ProvinceAbstract.new()
	abstract.detail = province
	province.tick = tick
	if province.landing != null:
		province.landing.finish_at_once(province)
	for ship: ShipUnit in province.ships.values():
		if ship.path_state == ShipUnit.PathState.MOVING and ship.path_goal != Agent.NO_TILE:
			ship.pos = IsoMath.tile_center(ship.path_goal)
			ship.prev_pos = ship.pos
			ship.clear_path()
			ship.path_state = ShipUnit.PathState.ARRIVED
	var settlers: Array[int] = []
	if province.landing != null:
		settlers = province.landing.settlers.duplicate()
	for agent: Agent in province.agents.all():
		abstract._take_off(agent, settlers.has(agent.id))
	if province.landing != null:
		province.landing.settlers.clear()
	for wagon: RouteWagon in province.route_wagons.values():
		wagon.finish_at_once(province)
	province.paths = PathRequestQueue.new()
	for ship: ShipUnit in province.ships.values():
		abstract._berth_boat(ship)
	province.events = SimEvents.new()
	abstract._count_staff()
	return abstract


## The province in detail again, sharing [param events] with the simulation (ARCHITECTURE
## §7.2): settlers and workers without a house stand at their camp or on the beach, every
## other worker is hired from the houses and stands at his workplace.
func thaw(tick: int, events: SimEvents) -> ProvinceSim:
	detail.tick = tick
	detail.events = events
	detail.abstract_staff = {}
	var ids: Array[int] = []
	ids.assign(homeless.keys())
	ids.sort()
	for id: int in ids:
		var workplace := detail.buildings.get_building(id)
		if workplace == null:
			continue
		for kind: Variant in homeless[id]:
			var agent := detail.spawn_agent(StringName(kind), workplace.entrance_tile())
			detail.assign_worker(agent, workplace)
	for kind: StringName in wanderers:
		var at := detail.landing.beach if detail.landing != null else detail.entry_tile
		var agent := detail.spawn_agent(kind, at)
		if detail.landing != null:
			detail.landing.settlers.append(agent.id)
	Population.staff_at_workplaces(detail)
	Barracks.thaw(detail)
	return detail


## One second of the province without people.
func step(tick: int) -> void:
	detail.tick = tick
	if detail.dev_mode:
		detail.finish_works_now()   # developer mode (E4 part 1)
	if tick % (STAFF_EVERY * STEP_TICKS) == 0 or not wanderers.is_empty():
		_count_staff()
	_settle_wanderers()
	_work()
	if tick % (BUILD_EVERY * STEP_TICKS) == 0:
		_build()
		_haul()
	detail._grow_saplings()
	detail._regrow_nodes()
	detail._breed_herds()
	if tick % (SimClock.TICKS_PER_SECOND) == 0:
		detail.wild.update(detail)
	Population.update_abstract(detail, _doors)
	Barracks.update_abstract(detail)
	_trade()
	detail.events.drain()


# --- Leaving -------------------------------------------------------------------------------

## Takes [param agent] off the map; [param settler]: a landing settler without a home yet.
func _take_off(agent: Agent, settler: bool) -> void:
	var p := detail
	var good := agent.carry_good
	var amount := agent.carry_amount
	var task := agent.task
	var bb: Dictionary = task.bb if task != null else {}
	agent.carry_good = &""
	agent.carry_amount = 0
	if agent.vehicle == Ships.ABOARD:
		var ship := Ships.ship_with_crew(p, agent)
		if ship != null and amount > 0:
			amount = ship.hold.add(good, amount)
	if Barracks.is_military(p, agent) and Barracks.take_off(p, agent):
		# A soldier (or a recruit, armed at once) is kept by kind in his barracks (M7).
		amount = 0
		p.remove_agent(agent)
		return
	if agent.home_id != 0 and agent.workplace_id == 0:
		var home := p.buildings.get_building(agent.home_id)
		if home != null and home.house != null and task != null and task.kind == Task.KIND_MOVE_IN:
			# A newcomer on his way in lives there now.
			home.house.incoming = maxi(home.house.incoming - 1, 0)
			home.house.residents = mini(home.house.residents + 1, home.capacity())
		elif home != null and home.supply != null and amount > 0:
			amount = home.supply.add(good, amount)   # a householder brings his errand home
	elif task != null and task.kind == Task.KIND_TRAVEL and bb.has("route"):
		pass   # a trade route's carter: his wagon finishes at once (RouteWagon.finish_at_once)
	elif task != null and task.kind == Task.KIND_TRAVEL and bb.has("leave") and p.departure != null:
		p.departure.on_left(p, agent)   # a settler of the expedition: as good as there
	elif agent.workplace_id != 0 and agent.home_id == 0:
		var kinds: Array = homeless.get(agent.workplace_id, [])
		kinds.append(String(agent.kind))
		homeless[agent.workplace_id] = kinds
	elif settler or (agent.home_id == 0 and agent.workplace_id == 0 \
			and agent.kind != Merchant.AGENT_KIND and p.landing != null):
		wanderers.append(agent.kind)
	var tile := agent.tile()
	p.remove_agent(agent)
	if amount > 0:
		_put_away(good, amount, int(bb.get("_dst", bb.get("to", 0))), tile)


## Puts [param amount] of [param good] where it was going ([param dest]), else into the
## nearest storage, else on the ground at [param tile].
func _put_away(good: StringName, amount: int, dest: int, tile: Vector2i) -> void:
	var p := detail
	# Never aboard a ship: a cog of the merchant would sail off with it.
	if dest != 0 and not p.ships.has(dest) and p.accepts_deliveries(dest) and p.storage(dest) != null:
		amount = p.storage(dest).add(good, amount)
	while amount > 0:
		var sink := p.nearest_sink(good, 1, tile)
		if sink == 0:
			break
		var store := p.storage(sink)
		var before := amount
		amount = store.add(good, amount)
		if amount == before:
			break
	if amount > 0:
		p.drop_goods(tile, good, amount)


## A boat left at sea without its crew is towed home and unloads into the storages.
func _berth_boat(ship: ShipUnit) -> void:
	if ship.voyage != null or ship.def.id == SeaMerchant.SHIP or ship.def.id == Landing.SHIP:
		return
	var home := detail.buildings.get_building(ship.home_id)
	if home != null and ship.dock_id == 0:
		Ships.dock(ship, home)
	var goods := ship.hold.totals()
	for good: StringName in goods:
		var left := ship.hold.remove(good, goods[good])
		_put_away(good, left, 0, ship.tile())


# --- People by number -----------------------------------------------------------------------

func _count_staff() -> void:
	_rates.clear()
	_doors.clear()
	var counts: Dictionary[int, int] = {}
	for id: int in homeless:
		counts[id] = homeless[id].size()
	staff = Population.staffing(detail, counts)
	detail.abstract_staff = staff


## Workers of [param kind] at work in the province now, including settlers who help out
## during a landing (builders build, porters carry).
func _workers_of(kind: StringName) -> int:
	var sum := 0
	for id: int in staff:
		var building := detail.buildings.get_building(id)
		if building == null:
			continue
		var kinds := building.worker_kinds()
		var homeless_kinds: Array = homeless.get(id, [])
		for i: int in mini(staff[id], kinds.size()):
			if kinds[i] == kind:
				sum += 1
		for k: Variant in homeless_kinds:
			if StringName(k) == kind and not kinds.has(kind):
				sum += 1
	return sum + wanderers.count(kind)


## Landing settlers: the pioneer camp takes its workers from them, the others move into houses
## with free places (Landing._settle without people).
func _settle_wanderers() -> void:
	var landing := detail.landing
	if wanderers.is_empty():
		if landing != null and landing.is_over():
			detail.landing = null
		return
	for building: BuildingState in detail.buildings.all():
		if not building.def.unique or not building.is_complete() or building.def.worker_count() == 0:
			continue
		var have: Array = homeless.get(building.id, [])
		for kind: StringName in building.def.worker_kinds:
			if have.count(String(kind)) >= building.def.worker_kinds.count(kind):
				continue
			if wanderers.has(kind):
				wanderers.erase(kind)
				have.append(String(kind))
		if not have.is_empty():
			homeless[building.id] = have
	for kind: StringName in wanderers.duplicate():
		var house: BuildingState = null
		for building: BuildingState in detail.buildings.all():
			if building.house != null and building.is_complete() \
					and building.house.free_places(building.capacity()) > 0:
				house = building
				break
		if house == null:
			break
		house.house.residents += 1
		wanderers.erase(kind)


# --- Work ----------------------------------------------------------------------------------

func _work() -> void:
	_fields = detail.fields.counts()
	# Nobody has a home here, so the town's average mood sets the pace (GDD §3.2).
	var speed := Population.average_work_speed(detail)
	for building: BuildingState in detail.buildings.all():
		var workers: int = staff.get(building.id, 0)
		if workers == 0 or building.paused or not building.is_complete():
			continue
		var cycle := WorkCycle.of(building.def, detail.data)
		if not cycle.is_productive():
			continue
		# A flock's pace changes with its size (Z1 part 2): never kept.
		if not _rates.has(building.id) or building.def.paced_work():
			_rates[building.id] = cycles_per_second(building)
		var per_second: float = _rates[building.id]
		if per_second <= 0.0:
			continue
		var share := workers / float(maxi(building.worker_count(), 1))
		var done: float = progress.get(building.id, 0.0) + per_second * share * speed
		if done >= 1.0 and detail.tick >= _wait_until.get(building.id, 0):
			if _cycle(building, cycle):
				done -= 1.0
			else:
				_wait_until[building.id] = detail.tick + RETRY_SECONDS * STEP_TICKS
		progress[building.id] = minf(done, 1.0)


## Work cycles per second of [param building] with all its workers: measured while viewed
## (ProductionLog), else estimated from the work and the walks (ARCHITECTURE §7.1).
func cycles_per_second(building: BuildingState) -> float:
	var cycle := WorkCycle.of(building.def, detail.data)
	# A farm works in rounds (E1 part 2: sow the whole field, wait, reap it): the intervals the
	# log keeps are the quick ones of the harvest, so a farm is always estimated.
	var measured := detail.production.rate(building.id) \
			if not building.def.paced_work() and not cycle.fields else 0.0
	if measured > 0.0:
		return measured / maxf(cycle.primary_amount, 1.0)
	# A charter's second worker works his own fields or pens (E4 part 3).
	var parallel := building.worker_count() if building.def.parallel_work or building.charter else 1
	return parallel / estimated_cycle_seconds(building)


## Seconds of one cycle without a measurement: the work, the walks to the nearest storage and
## back (path length × 2 / walking speed), the way to a tree or a rock, crops growing.
func estimated_cycle_seconds(building: BuildingState) -> float:
	var cycle := WorkCycle.of(building.def, detail.data)
	var walk := _walk_to_storage(building)
	# The owner's research (E4 part 2: forestry, fishing) speeds the work up (a measured rate
	# has it already).
	var work := cycle.work_seconds / detail.research.work_speed(detail.data, building.def.id)
	if building.def.paced_work():
		# A flock shears faster when bigger, and gives nothing without sheep (Z1 part 2).
		if not building.has_work_source():
			return INF
		work *= building.work_factor()
	var seconds := work + cycle.trips * 2.0 * walk / Movement.BASE_SPEED
	if cycle.hunts:
		# Out to a herd and back with the carcass: about half the hunting radius each way.
		seconds += 2.0 * maxf(building.def.work_radius / 2.0, 1.0) / Movement.BASE_SPEED
	if cycle.gather != &"" and not cycle.by_sea:
		seconds += 2.0 * maxf(building.def.work_radius / 2.0, 1.0) / Movement.BASE_SPEED
	if cycle.by_sea:
		seconds += SAIL_SECONDS
	if cycle.plants != &"":
		seconds += 2.0 * maxf(building.def.work_radius / 2.0, 1.0) / Movement.BASE_SPEED
	if cycle.fields:
		# One field gives a harvest every grow time plus its three jobs; a farmer works one at
		# a time. E1 part 2: the whole field now waits for its last tile and grows once, and
		# the extra yield makes up for it (measured in the detailed mode: a farm harvests as
		# much an hour as before, farm_yield_probe), so the estimate stays as it was.
		if _fields.is_empty():
			_fields = detail.fields.counts()
		var count: int = _fields.get(building.id, 0)
		if count == 0:
			return INF
		var per_field := building.def.field_grow_time + cycle.work_seconds
		seconds = maxf(seconds, per_field / count)
	return maxf(seconds, 1.0)


func _walk_to_storage(building: BuildingState) -> float:
	if _walk.has(building.id):
		return _walk[building.id]
	var best := DEFAULT_WALK
	var from := building.entrance_tile()
	var nearest := 0
	var nearest_d := 1 << 30
	for store: BuildingState in detail.storage_buildings():
		var d := (store.entrance_tile() - from).length_squared()
		if store.id != building.id and d < nearest_d:
			nearest_d = d
			nearest = store.id
	if nearest != 0:
		var path := detail.find_path(from, detail.buildings.get_building(nearest).entrance_tile())
		if not path.is_empty():
			best = float(path.size())
	_walk[building.id] = best
	return best


## One finished cycle: takes what it needs and puts what it makes away. False (nothing
## changes) when an input, a tree or room in the storages is missing.
func _cycle(building: BuildingState, cycle: WorkCycle) -> bool:
	var p := detail
	var near := building.entrance_tile()
	for good: StringName in cycle.inputs:
		var have := building.supply.total(good) if building.supply != null and building.house == null else 0
		if have < cycle.inputs[good] and _source(good) == null:
			return false
		if have < cycle.inputs[good] and (p.stored(good) + have < cycle.inputs[good] \
				or not p.workshop_may_take(good, cycle.inputs[good])):
			return false
	if building.def.uses_ship != &"" and Ships.ship_of(p, building) == null:
		return false
	if cycle.fields and _fields.get(building.id, 0) == 0:
		return false
	var herd: WildHerds.Herd = null
	if cycle.hunts:
		herd = p.wild.nearest(near, building.def.work_radius)
		if herd == null:
			return false
	for good: StringName in cycle.outputs:
		if _sink(good) == null and (building.yard == null \
				or not building.yard.can_accept(good, cycle.outputs[good])):
			return false
	var node := Agent.NO_TILE
	if cycle.gather != &"":
		var radius := building.def.work_radius if building.def.work_radius > 0 else 64
		var from := building.berth_tile() if cycle.by_sea else near
		node = p.resources.find_nearest(cycle.gather, from, radius)
		if node == Agent.NO_TILE:
			return false
	var spot := Agent.NO_TILE
	if cycle.plants != &"":
		spot = _plant_spot(building, cycle.plants)
		if spot == Agent.NO_TILE:
			return false
	# Everything is there: the cycle happens.
	if herd != null:
		p.wild.take_one(p, herd, near)
	for good: StringName in cycle.inputs:
		var need := cycle.inputs[good]
		if building.supply != null and building.house == null:
			need -= building.supply.remove(good, need)
			p.ledger.used(good, cycle.inputs[good] - need, p.tick)
		while need > 0:
			var store := _source(good)
			if store == null:
				break
			var got := store.remove(good, mini(need, store.available(good)))
			if got <= 0:
				break
			need -= got
			p.ledger.used(good, got, p.tick)
	if node != Agent.NO_TILE:
		var node_def := p.resources.def_at(node)
		var taken := p.resources.take(node)
		if p.resources.is_depleted(node):
			if node_def.remove_when_depleted:
				p.resources.clear(node)
				p.clear_forest_floor(node)
			p.leave_terrain(node, node_def)
			p.refresh_tile(node)
		if taken <= 0:
			return true
	if spot != Agent.NO_TILE:
		p.plant(spot, p.data.get_resource_node(cycle.plants))
	if not cycle.serves.is_empty():
		building.serving_until = p.tick + SimClock.seconds_to_ticks(cycle.serve_hold)
	for good: StringName in cycle.outputs:
		var amount := cycle.outputs[good]
		if cycle.fields:
			amount += building.fertile_extra(amount, p.field_yield())   # E3 part 4
		p.ledger.made(good, amount, p.tick)
		var left := _store(good, amount)
		if left > 0 and building.yard != null:
			left = building.yard.add(good, left)
		if left > 0:
			p.drop_goods(building.door_front_tile(), good, left)
	return true


## A storage that takes [param good] now (the last one used while it has room), or null.
func _sink(good: StringName) -> Stockpile:
	var id: int = _sinks.get(good, 0)
	var store := detail.storage(id) if id != 0 else null
	if store == null or not store.can_accept(good, 1):
		id = detail.nearest_sink(good, 1, detail.entry_tile)
		_sinks[good] = id
		store = detail.storage(id) if id != 0 else null
	return store


## Puts [param amount] of [param good] into storages; returns what found no room.
func _store(good: StringName, amount: int) -> int:
	var left := amount
	while left > 0:
		var store := _sink(good)
		if store == null:
			break
		var before := left
		left = store.add(good, left)
		if left == before:
			_sinks.erase(good)
			break
	return left


## A storage (or yard, or pile) that gives [param good] now, or null.
func _source(good: StringName) -> Stockpile:
	var id: int = _sources.get(good, 0)
	var store := detail.storage(id) if id != 0 else null
	if store == null or store.available(good) - _keep(id, good) <= 0:
		id = detail.nearest_source(good, 1, detail.entry_tile)
		_sources[good] = id
		store = detail.storage(id) if id != 0 else null
	return store


## Units a herd keeps for breeding (nobody takes its last animals).
func _keep(id: int, good: StringName) -> int:
	if id >= 0:
		return 0
	var building := detail.buildings.get_building(-id)
	return building.herd_keep if building != null and building.def.herd_good == good else 0


## The next tile of the forester's marked area (or work area) where a sapling may go,
## Agent.NO_TILE if none; tried in turn from where the last search stopped.
func _plant_spot(building: BuildingState, node_id: StringName) -> Vector2i:
	var tiles: Array[Vector2i] = building.plant_area
	var area := detail._work_area(building)
	var count := tiles.size() if not tiles.is_empty() else area.size.x * area.size.y
	var start: int = _plant_cursor.get(building.id, 0)
	var tree := detail.data.get_resource_node(&"tree")
	for i: int in mini(count, 64):
		var k := (start + i) % maxi(count, 1)
		var tile := tiles[k] if not tiles.is_empty() \
				else area.position + Vector2i(k % area.size.x, k / area.size.x)
		if detail.can_plant(tile, tree.id if tree != null else node_id):
			_plant_cursor[building.id] = k + 1
			return tile
	_plant_cursor[building.id] = start + 64
	return Agent.NO_TILE


# --- Construction --------------------------------------------------------------------------

## Porters bring materials to construction sites and slipways (oldest first), builders and
## shipwrights work them off.
func _build() -> void:
	var p := detail
	for building: BuildingState in p.buildings.all():
		if not building.def.ship_kinds.is_empty() and building.is_complete() \
				and not building.ship_orders.is_empty() and Ships.build_at(p, building) == null:
			Ships.open_build(p, building)
	_carry_budget = minf(_carry_budget + _workers_of(&"porter") * PORTER_RATE * BUILD_EVERY
			* detail.research.porter_load(detail.data), 40.0)
	var site_ids: Array[int] = []
	site_ids.assign(p.sites.keys())
	site_ids.sort()
	for id: int in site_ids:
		var site := p.sites[id] as ConstructionSite
		var target := p.buildings.get_building(site.building_id)
		if target != null:
			_supply(site.id, site.stock, _site_needs(site), target.entrance_tile())
	var build_ids: Array[int] = []
	build_ids.assign(p.ship_builds.keys())
	build_ids.sort()
	for id: int in build_ids:
		var build := p.ship_builds[id] as ShipBuild
		var shipyard := p.buildings.get_building(build.shipyard_id)
		if shipyard != null:
			_supply(build.id, build.stock, build.still_needed(), shipyard.entrance_tile())
	var builders := _workers_of(TaskRunner.BUILDER_KIND)
	for id: int in site_ids:
		if builders <= 0:
			break
		var site := p.sites.get(id) as ConstructionSite
		if site == null:
			continue
		if not site.phase_started:
			if not site.has_phase_materials():
				continue
			Construction.start_phase(p, site)
		builders -= 1
		site.work_left -= STEP_TICKS * BUILD_EVERY
		if site.work_left <= 0:
			Construction.finish_phase(p, site)
	for id: int in build_ids:
		var build := p.ship_builds.get(id) as ShipBuild
		if build == null or staff.get(build.shipyard_id, 0) == 0:
			continue
		if not build.stage_started:
			if build.missing_good() != &"":
				continue
			Ships.start_stage(p, build)
		build.work_left -= STEP_TICKS * BUILD_EVERY
		if build.work_left <= 0:
			Ships.finish_stage(p, build)


## Goods [param site] still needs brought (all its phases, less what lies there).
func _site_needs(site: ConstructionSite) -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	for p: int in range(site.phase, site.phase_count() + 1):
		if p == site.phase and site.phase_started:
			continue
		var cost := site.phase_costs[p - 1]
		for good: StringName in cost:
			result[good] = result.get(good, 0) + int(cost[good])
	return result


## Porters bring what [param stock] (entity [param id]) still needs, within this second's
## budget; the matching transport requests shrink so nothing is brought twice later.
func _supply(id: int, stock: Stockpile, needs: Dictionary[StringName, int], near: Vector2i) -> void:
	if _carry_budget < 1.0 and _synced.has(id):
		return
	var goods: Array[StringName] = []
	goods.assign(needs.keys())
	goods.sort()
	for good: StringName in goods:
		var missing := needs[good] - stock.total(good)
		var amount := mini(missing, floori(_carry_budget))
		var moved := 0
		if amount > 0 and detail.stored(good) > 0:
			var taken := detail.take_from_storages(good, amount, near, false, true)
			var left := stock.add(good, taken)
			if left > 0:
				_put_away(good, left, 0, near)
			moved = taken - left
			_carry_budget -= moved
			missing -= moved
		if moved > 0 or not _synced.has(id):
			detail.jobs.set_amount(good, 0, id, maxi(missing, 0))
	_synced[id] = true


## Goods on the ground, on quays (not waiting for a ship) and in production yards go to the
## storages.
func _haul() -> void:
	var p := detail
	for pile: GroundPile in p.piles.values():
		var goods := pile.stock.totals()
		for good: StringName in goods:
			_move_to_storage(pile.stock, good, goods[good], pile.tile)
	for building: BuildingState in p.buildings.all():
		if building.yard != null and building.def.herd_good == &"":
			var goods := building.yard.totals()
			for good: StringName in goods:
				_move_to_storage(building.yard, good, goods[good], building.entrance_tile())
		if building.def.is_port() and building.stock != null and not _port_busy(building):
			var goods := building.stock.totals()
			for good: StringName in goods:
				_move_to_storage(building.stock, good, goods[good], building.entrance_tile())
	p._remove_empty_piles()


func _move_to_storage(from: Stockpile, good: StringName, amount: int, near: Vector2i) -> void:
	var left := mini(amount, from.available(good))
	while left > 0:
		var sink := detail.nearest_sink(good, 1, near)
		if sink == 0:
			return
		var store := detail.storage(sink)
		if store == from:
			return
		var room := left
		while room > 0 and not store.can_accept(good, room):
			room -= 1
		if room <= 0:
			return
		from.remove(good, room)
		store.add(good, room)
		left -= room


## A ship is moored at [param port] (its quay goods wait for it).
func _port_busy(port: BuildingState) -> bool:
	return Harbour.berth_holder(detail, port) != null


# --- Merchants and voyages -----------------------------------------------------------------

func _trade() -> void:
	var p := detail
	if p.departure != null:
		p.departure.gather_at_once(p)
	if p.tick % (STEP_TICKS * 10) == 0:
		p.merchant.trade_at_once(p)
		p.sea_merchant.trade_at_once(p)
	for ship: ShipUnit in p.ships.values():
		if ship.voyage != null:
			ship.voyage.sail_by_the_clock(p, ship)


# --- Save ----------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var d := {"province": detail.to_dict()}
	if not homeless.is_empty():
		var h := {}
		for id: int in homeless:
			h[str(id)] = homeless[id].duplicate()
		d["homeless"] = h
	if not wanderers.is_empty():
		var w: Array = []
		for kind: StringName in wanderers:
			w.append(String(kind))
		d["wanderers"] = w
	var pr := {}
	var ids: Array[int] = []
	ids.assign(progress.keys())
	ids.sort()
	for id: int in ids:
		if progress[id] > 0.0:
			pr[str(id)] = progress[id]
	if not pr.is_empty():
		d["progress"] = pr
	if _carry_budget > 0.0:
		d["carry"] = _carry_budget
	return d


static func from_dict(d: Dictionary, registry: DataRegistry, ids: EntityIds,
		treasury: Treasury) -> ProvinceAbstract:
	var abstract := ProvinceAbstract.new()
	abstract.detail = ProvinceSim.from_dict(d["province"], registry, SimEvents.new(), ids)
	abstract.detail.treasury = treasury
	var h: Dictionary = d.get("homeless", {})
	for key: Variant in h:
		var kinds: Array = []
		for k: Variant in h[key]:
			kinds.append(String(k))
		abstract.homeless[int(String(key))] = kinds
	for kind: Variant in d.get("wanderers", []):
		abstract.wanderers.append(StringName(String(kind)))
	var pr: Dictionary = d.get("progress", {})
	for key: Variant in pr:
		abstract.progress[int(String(key))] = float(pr[key])
	abstract._carry_budget = float(d.get("carry", 0.0))
	abstract._count_staff()
	return abstract
