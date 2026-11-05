class_name Construction
extends RefCounted
## Physical construction (GDD §5.1, ROADMAP M3 decisions): a placed building is a site that
## asks porters for its materials; builders use up each phase's share and work it off.
## Phase 1 = foundations and scaffolding, phase 2 = walls and roof. House upgrades are
## one-phase sites on a finished house.

## Share of the build cost returned when a building is demolished (GDD §5.1).
const REFUND_SHARE := 0.5


## Opens a 2-phase construction site for a freshly placed building.
static func open_build_site(province: ProvinceSim, building: BuildingState) -> ConstructionSite:
	var costs: Array[Dictionary] = []
	for phase: int in [1, 2]:
		costs.append(building.def.phase_cost(phase))
	var ticks := SimClock.seconds_to_ticks(building.def.build_time / 2.0)
	return _open(province, building, ConstructionSite.KIND_BUILD, costs, ticks)


## Opens a 1-phase upgrade site (scaffolding on the house) for the next house level.
static func open_upgrade_site(province: ProvinceSim, building: BuildingState,
		next: HouseLevelDef) -> ConstructionSite:
	var costs: Array[Dictionary] = [next.upgrade_cost.duplicate()]
	return _open(province, building, ConstructionSite.KIND_UPGRADE, costs,
			SimClock.seconds_to_ticks(next.upgrade_time))


static func _open(province: ProvinceSim, building: BuildingState, kind: StringName,
		costs: Array[Dictionary], ticks: int) -> ConstructionSite:
	var site := ConstructionSite.new(province.ids.take(), building.id, kind, costs, maxi(ticks, 1),
			province.data)
	province.sites[site.id] = site
	building.site_id = site.id
	var total := site.total_cost()
	var goods: Array[StringName] = []
	goods.assign(total.keys())
	goods.sort()
	for good: StringName in goods:
		province.jobs.add(good, total[good], 0, site.id)
	province.events.emit(&"site_opened", {"site": site.id, "building": building.id,
			"kind": kind})
	return site


static func start_phase(province: ProvinceSim, site: ConstructionSite) -> void:
	var cost := site.current_cost()
	for good: StringName in cost:
		site.stock.remove(good, int(cost[good]))
	site.phase_started = true
	site.work_left = site.phase_ticks
	province.events.emit(&"site_phase_started", {"site": site.id, "building": site.building_id,
			"phase": site.phase})


static func finish_phase(province: ProvinceSim, site: ConstructionSite) -> void:
	province.events.emit(&"site_phase_finished", {"site": site.id, "building": site.building_id,
			"phase": site.phase})
	if site.phase < site.phase_count():
		site.phase += 1
		site.phase_started = false
		site.work_left = site.phase_ticks
		return
	_close(province, site, true)


## Removes a site; [param finished] completes the building or the upgrade.
static func _close(province: ProvinceSim, site: ConstructionSite, finished: bool) -> void:
	var building := province.buildings.get_building(site.building_id)
	province.sites.erase(site.id)
	province.jobs.cancel_for_entity(site.id)
	for agent: Agent in province.agents.all():
		if agent.task != null and int(agent.task.bb.get("_dst", 0)) == site.id:
			TaskRunner.fail(province, agent)
	if building == null:
		return
	building.site_id = 0
	var leftovers := site.stock.totals()
	var door := province.door_tile(building)
	for good: StringName in leftovers:
		province.drop_goods(door if door != Agent.NO_TILE else building.entrance_tile(), good, leftovers[good])
	if not finished:
		return
	if site.kind == ConstructionSite.KIND_UPGRADE:
		building.house.level += 1
		building.supply.stack_limit = building.level_def().supply_units
		province.events.emit(&"house_upgraded", {"building": building.id,
				"level": building.house.level})
	else:
		building.finish(province.data)
		province.events.emit(&"building_completed", {"building": building.id,
				"def": building.def.id})


## Cancels the site of a building being removed and puts its materials on the ground.
static func cancel_site(province: ProvinceSim, building: BuildingState) -> void:
	var site := province.sites.get(building.site_id) as ConstructionSite
	if site == null:
		return
	# Materials of phases already started are partly recovered like a demolition.
	var spent := {}
	for p: int in range(1, site.phase + (1 if site.phase_started else 0)):
		var cost := site.phase_costs[p - 1]
		for good: StringName in cost:
			spent[good] = int(spent.get(good, 0)) + int(cost[good])
	_close(province, site, false)
	for good: StringName in spent:
		var amount := floori(int(spent[good]) * REFUND_SHARE)
		if amount > 0:
			province.drop_goods(building.entrance_tile(), good, amount)
	if site.kind == ConstructionSite.KIND_BUILD:
		# Gold comes back in full until work starts, then like a demolition.
		var untouched := site.phase == 1 and not site.phase_started
		province.treasury.add(building.def.gold_cost if untouched \
				else floori(building.def.gold_cost * REFUND_SHARE))


## Goods returned by demolishing a finished building.
static func refund(def: BuildingDef) -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	for good: StringName in def.build_cost:
		var amount := floori(def.build_cost[good] * REFUND_SHARE)
		if amount > 0:
			result[good] = amount
	return result


## The nearest site a builder can work on now and walk to; 0 if none. A site cut off from
## the builder is skipped, so it never holds up the others.
static func site_for(province: ProvinceSim, builder: Agent) -> int:
	var candidates: Array[Array] = []
	for site: ConstructionSite in province.sites.values():
		if not site.is_workable():
			continue
		var building := province.buildings.get_building(site.building_id)
		candidates.append([(building.entrance_tile() - builder.tile()).length_squared(), site.id,
				building.entrance_tile()])
	candidates.sort_custom(func(a: Array, b: Array) -> bool:
		return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	for candidate: Array in candidates:
		if not province.find_path(builder.tile(), candidate[2]).is_empty():
			return candidate[1]
	return 0
