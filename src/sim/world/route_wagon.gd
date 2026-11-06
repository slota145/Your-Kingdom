class_name RouteWagon
extends RefCounted
## The wagon of a trade route in the viewed province (ROADMAP M6 part 3, GDD §4.5): a store
## addressed by the route's id, standing in front of a building, and its carter.
##
## Loading (province A): the wagon stands in front of the stable that lent it; porters bring
## the goods of the run from the storages; when all is aboard (or nothing more can come) the
## carter drives to the map edge and is gone.
## Unloading (province B): the carter drives in from the map edge to the storage nearest to it;
## porters carry the goods into the storages; then he drives off again.
## While nobody looks (ProvinceAbstract.freeze) it finishes at once (finish_at_once).

enum State { ARRIVING, WORKING, LEAVING, GONE }

## Slots of the wagon's store: enough for a full load of any mix of goods.
const SLOTS := TradeRoute.WAGON_LOAD
## Longest wait (s) for porters to unload before what is left is put down by the wagon.
const UNLOAD_WAIT := 120
## Seconds loading may go on without a unit coming aboard before it sets off with what it has
## (goods counted as stored may lie where porters do not fetch them, e.g. market stalls).
const LOAD_WAIT := 45

## The route's id, also the id of its store.
var id: int = 0
var unloading: bool = false
var state: State = State.WORKING
var store: Stockpile
## Where it stands while porters work.
var stand: Vector2i = Agent.NO_TILE
var agent_id: int = 0
## Loading: what the run takes (good -> units).
var plan: Dictionary[StringName, int] = {}
## Unloading: tick it started to be unloaded; loading: tick the last unit came aboard.
var since: int = 0
## Loading: units aboard when [member since] was set.
var seen: int = 0


## A wagon to load in front of [param stable] with [param run] (good -> units).
static func to_load(province: ProvinceSim, route_id: int, run: Dictionary[StringName, int],
		stable: BuildingState) -> RouteWagon:
	var wagon := RouteWagon.new()
	wagon.id = route_id
	wagon.store = Stockpile.new(SLOTS, province.data)
	wagon.plan = run.duplicate()
	wagon.stand = province.door_tile(stable) if stable != null else province.entry_tile
	wagon.state = State.WORKING
	wagon.since = province.tick
	wagon._ensure_carter(province)
	wagon._request(province)
	province.events.emit(&"route_loading", {"route": route_id})
	return wagon


## A wagon with [param cargo] driving in to be unloaded at the storage nearest to the map edge.
static func to_unload(province: ProvinceSim, route_id: int, cargo: Dictionary[StringName, int]) -> RouteWagon:
	var wagon := RouteWagon.new()
	wagon.id = route_id
	wagon.unloading = true
	wagon.store = Stockpile.new(maxi(SLOTS, cargo.size()), province.data)
	for good: StringName in _sorted(cargo):
		var left := wagon.store.add(good, cargo[good])
		if left > 0:
			province.drop_goods(province.entry_tile, good, left)
	var best: BuildingState = null
	var best_d := 1 << 30
	for building: BuildingState in province.storage_buildings():
		if building.stock == null or not building.is_complete():
			continue
		var d := (building.entrance_tile() - province.entry_tile).length_squared()
		if d < best_d:
			best_d = d
			best = building
	if best == null:
		best = province.seat()
	wagon.stand = province.door_tile(best) if best != null else province.entry_tile
	wagon.state = State.ARRIVING
	var carter := province.spawn_agent(Carriers.CARTER_KIND, province.entry_tile)
	carter.vehicle = Carriers.TRADE_WAGON
	TaskRunner.start_travel(carter, wagon.stand)
	carter.task.bb["route"] = route_id
	wagon.agent_id = carter.id
	wagon.since = province.tick
	province.events.emit(&"route_arrived", {"route": route_id})
	return wagon


func is_gone() -> bool:
	return state == State.GONE


## Porters may bring goods to it (loading) while it waits.
func accepts() -> bool:
	return not unloading and state == State.WORKING


## Once a second while the province is viewed.
func update(province: ProvinceSim) -> void:
	match state:
		State.ARRIVING:
			var carter := province.agents.get_agent(agent_id)
			if carter == null or carter.task == null or carter.tile() == stand:
				state = State.WORKING
				since = province.tick
		State.WORKING:
			if unloading:
				_unload(province)
			else:
				_ensure_carter(province)
				if store.total_amount() != seen:
					seen = store.total_amount()
					since = province.tick
				var stalled := province.tick >= since + LOAD_WAIT * SimClock.TICKS_PER_SECOND \
						and not _porters_busy(province)
				if stalled or _loaded(province):
					_set_off(province)
				else:
					_request(province)
		State.LEAVING:
			if province.agents.get_agent(agent_id) == null:
				state = State.GONE


## The carter reached the map edge.
func on_left(_province: ProvinceSim, agent: Agent) -> void:
	if agent.id == agent_id:
		agent_id = 0
		if state == State.LEAVING:
			state = State.GONE


## Whether the carter of [param agent]'s travel task waits (loading, not set off yet).
func holds(agent: Agent) -> bool:
	return agent.id == agent_id and state == State.WORKING and not unloading


## Goods aboard as it set out (loading) — read when it is gone.
func cargo() -> Dictionary[StringName, int]:
	return store.totals() if store != null else {} as Dictionary[StringName, int]


## Nobody looks at the province any more (freeze; after people are taken off): loading takes
## what is missing from the storages at once and it is gone; unloading puts everything into
## the storages at once.
func finish_at_once(province: ProvinceSim) -> void:
	province.jobs.cancel_for_entity(id)
	if state == State.GONE:
		return
	if unloading:
		var goods := store.totals()
		for good: StringName in _sorted(goods):
			store.remove(good, goods[good])
			Departure.give_back(province, good, goods[good], stand, true)
	elif state == State.WORKING:
		for good: StringName in _sorted(plan):
			var missing := plan[good] - store.total(good)
			if missing > 0:
				var taken := province.take_from_storages(good, missing, stand, false)
				var left := store.add(good, taken)
				if left > 0:
					Departure.give_back(province, good, left, stand, true)
	state = State.GONE


func _ensure_carter(province: ProvinceSim) -> void:
	if province.agents.get_agent(agent_id) != null:
		return
	var carter := province.spawn_agent(Carriers.CARTER_KIND, stand)
	carter.vehicle = Carriers.TRADE_WAGON
	TaskRunner.start_travel(carter, province.entry_tile, true, true)
	carter.task.bb["route"] = id
	agent_id = carter.id


func _request(province: ProvinceSim) -> void:
	for good: StringName in _sorted(plan):
		var missing := plan[good] - store.total(good) - province.jobs.in_flight(good, 0, id)
		province.jobs.set_amount(good, 0, id, mini(maxi(missing, 0), province.stored(good)))


## All of the run is aboard, or nothing more can come.
func _loaded(province: ProvinceSim) -> bool:
	for good: StringName in _sorted(plan):
		if store.total(good) >= plan[good]:
			continue
		if province.jobs.in_flight(good, 0, id) > 0 or province.stored(good) > 0:
			return false
	return not _porters_busy(province)


func _set_off(province: ProvinceSim) -> void:
	province.jobs.cancel_for_entity(id)
	state = State.LEAVING
	province.events.emit(&"route_departed", {"route": id})


func _unload(province: ProvinceSim) -> void:
	var goods := store.totals()
	for good: StringName in _sorted(goods):
		province.jobs.set_amount(good, id, 0, store.available(good))
	var waited := province.tick >= since + UNLOAD_WAIT * SimClock.TICKS_PER_SECOND
	if (store.is_empty() and not _porters_busy(province)) or waited:
		province.jobs.cancel_for_entity(id)
		for good: StringName in _sorted(store.totals()):
			var n := store.available(good)
			if n > 0:
				store.remove(good, n)
				province.drop_goods(stand, good, n)
		var carter := province.agents.get_agent(agent_id)
		if carter == null:
			state = State.GONE
			return
		TaskRunner.start_travel(carter, province.entry_tile, false, true)
		carter.task.bb["route"] = id
		state = State.LEAVING


func _porters_busy(province: ProvinceSim) -> bool:
	for agent: Agent in province.agents.all():
		if agent.task != null and agent.id != agent_id and (int(agent.task.bb.get("_src", 0)) == id \
				or int(agent.task.bb.get("_dst", 0)) == id):
			return true
	return false


static func _sorted(goods: Dictionary[StringName, int]) -> Array[StringName]:
	var keys: Array[StringName] = []
	keys.assign(goods.keys())
	keys.sort()
	return keys


func to_dict() -> Dictionary:
	var d := {"id": id, "state": state, "store": store.to_dict(), "stand": SimCodec.vec2i(stand),
			"agent": agent_id, "since": since}
	if seen != 0:
		d["seen"] = seen
	if unloading:
		d["unloading"] = true
	if not plan.is_empty():
		d["plan"] = Expedition.goods_to_dict(plan)
	return d


static func from_dict(d: Dictionary, data: DataRegistry) -> RouteWagon:
	var wagon := RouteWagon.new()
	wagon.id = int(d["id"])
	wagon.state = clampi(int(d.get("state", 0)), State.ARRIVING, State.GONE) as State
	wagon.store = Stockpile.from_dict(d["store"], data)
	wagon.stand = SimCodec.to_vec2i(d.get("stand", [-1, -1]))
	wagon.agent_id = int(d.get("agent", 0))
	wagon.since = int(d.get("since", 0))
	wagon.seen = int(d.get("seen", 0))
	wagon.unloading = bool(d.get("unloading", false))
	wagon.plan = Expedition.goods_from(d.get("plan", {}))
	return wagon
