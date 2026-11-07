class_name Voyage
extends RefCounted
## Trade voyages of the player's cog (ROADMAP M5 part 3, GDD §4.6, §5.4). Every trading ship
## (ShipDef.trades) has one: its home port, its anchorage and the voyage plan the player sets
## in the port panel (goods to sell, goods to order from the sea merchant's offer).
##
## IDLE: the cog waits at anchor in deep water near its home port (owner's decision
##   2026-11-06: the berth stays free for the sea merchant).
## TO_BERTH: the player sent it out: it takes the berth (or waits at anchor while another
##   ship holds it) and moors.
## LOADING: porters bring the plan's goods from the storages to the quay yard, dockers carry
##   them aboard unit by unit. It casts off when the plan is aboard, when no more can come,
##   or when the player says so (after dockers on the gangway are back).
## OUTBOUND: the purse for the order is taken from the treasury (owner's decision: the order
##   is always paid for), and it sails to the sea edge nearest to the port.
## AWAY: over the horizon for AWAY_TIME: the cargo is sold at the base price + 25%, the
##   order is bought at the sea merchant's price and loaded.
## INBOUND: it sails back and moors at the berth (waiting at anchor while it is taken); the
##   gold of the sale goes into the treasury when it is back.
## UNLOADING: dockers carry the order onto the quay yard, porters take it to storages; then
##   back to anchor.

enum State { IDLE, TO_BERTH, LOADING, OUTBOUND, AWAY, INBOUND, UNLOADING }

## Seconds over the horizon; with sailing out and back about 6 minutes (ROADMAP M5).
const AWAY_TIME := 270.0
## The cargo sells for the base price times this, rounded up per unit.
const SALE_MARKUP := 1.25
## back_at of a cog away with an expedition until the Simulation knows when it is back.
const AWAY_WITH_EXPEDITION := 1 << 50
## Sailing out to the sea edge and back in, counted by the clock while nobody looks (s).
const SAIL_BY_CLOCK := 90.0
## Longest wait after loading stops for dockers still on the gangway.
const FINISH_WAIT := 30.0
## Units per step of the plan in the port panel.
const PLAN_STEP := 5
## Anchorage: deep water at least this far (tiles, Chebyshev) from the berth.
const ANCHOR_MIN := 3
## Tiles searched for an anchorage at most.
const ANCHOR_SEARCH := 600

var state: State = State.IDLE
## The plan: goods to sell (good -> units) and to order (offer good -> units).
var sell: Dictionary[StringName, int] = {}
## An expedition of settlers this cog takes (M6 part 2, Departure): it loads the start kit
## instead of the plan, buys nothing and waits for the settlers; over the horizon it is on
## the world map until the expedition has landed and it is back (Simulation). 0 = none.
var expedition: int = 0
var order: Dictionary[StringName, int] = {}
## The trade route this cog runs (M6 part 3, TradeRoute), 0 = none. On a route it loads the
## run the route asks for ([member route_run]) instead of the plan, buys nothing and over the
## horizon hands its cargo to the route ([member shipped]); it is away until the route is back.
var route: int = 0
var route_run: Dictionary[StringName, int] = {}
## Cargo that went over the horizon on a route run, until the Simulation takes it.
var shipped: Dictionary[StringName, int] = {}
## Deep water where it waits; Agent.NO_TILE = not chosen yet.
var anchor: Vector2i = Agent.NO_TILE
## Sea edge of the voyage under way.
var edge: Vector2i = Agent.NO_TILE
## Tick it comes back over the horizon (AWAY).
var back_at: int = 0
## The player asked it to cast off with what is aboard (LOADING).
var depart_now: bool = false
## Tick loading stopped (waiting for the dockers), 0 = still loading.
var stopped_at: int = 0
## Gold taken for the order (OUTBOUND, AWAY), and units it buys with it.
var purse: int = 0
var buying: Dictionary[StringName, int] = {}
## Gold of the sale carried home (AWAY, INBOUND); paid into the treasury on return.
var earned: int = 0
## The last finished voyage, for the port panel: gold of the sale, gold of the order,
## units sold and bought.
var last_earned: int = 0
var last_spent: int = 0
var last_sold: int = 0
var last_bought: int = 0
## Goods kept on the quay for this ship while loading (good -> true).
var _loading_goods: Dictionary = {}


func is_away() -> bool:
	return state == State.AWAY


func is_busy() -> bool:
	return state != State.IDLE


## Goods the quay of the home port keeps for this ship while it loads.
func loading_goods() -> Dictionary:
	return _loading_goods if state == State.LOADING else {}


## Slots of [param hold] that [param plan] (good -> units) needs.
static func slots_needed(plan: Dictionary, hold: Stockpile) -> int:
	var slots := 0
	for good: Variant in plan:
		slots += ceili(int(plan[good]) / float(maxi(hold.stack_size(StringName(String(good))), 1)))
	return slots


## What one unit of [param good] brings over the horizon.
static func sale_price(province: ProvinceSim, good: StringName) -> int:
	var def := province.data.get_good(good)
	return ceili(def.base_price * SALE_MARKUP) if def != null else 0


## Whether [param good] can go on a voyage: priced and not a live animal.
static func can_sell(province: ProvinceSim, good: StringName) -> bool:
	var def := province.data.get_good(good)
	return def != null and def.base_price > 0 and not def.is_live()


## Gold the order of the plan costs at the sea merchant's prices.
func order_cost(province: ProvinceSim) -> int:
	var sum := 0
	for good: StringName in order:
		sum += order[good] * SeaMerchant.sell_price(province, good)
	return sum


# --- Once a second -------------------------------------------------------------------------

## Runs every trading ship's voyage (ProvinceSim.step, once a second).
static func update_all(province: ProvinceSim) -> void:
	for ship: ShipUnit in province.ships.values():
		if ship.voyage != null:
			ship.voyage.update(province, ship)


func update(province: ProvinceSim, ship: ShipUnit) -> void:
	var port := province.buildings.get_building(ship.home_id)
	if port == null or not port.def.is_port() or not port.is_complete():
		port = null
		if ship.home_id != 0 and province.buildings.get_building(ship.home_id) == null:
			ship.home_id = 0
		if ship.home_id == 0:
			port = _find_home(province, ship)
	match state:
		State.IDLE:
			if port != null and not ship.hold.is_empty():
				state = State.INBOUND   # goods aboard (its port was gone): unload them first
			else:
				_go_to_anchor(province, ship, port)
		State.TO_BERTH, State.INBOUND:
			_to_berth(province, ship, port)
		State.LOADING:
			_load(province, ship, port)
		State.OUTBOUND:
			if ship.path_state != ShipUnit.PathState.MOVING:
				_go_over_horizon(province, ship)
		State.AWAY:
			if province.tick >= back_at:
				_come_back(province, ship)
		State.UNLOADING:
			_unload(province, ship, port)


## The voyage while nobody looks at the province (M6, ARCHITECTURE §7.1): the plan is loaded
## from the storages and unloaded into them at once, the sailing goes by the clock (out and
## back as long as on the map). The cog waits at its anchorage.
func sail_by_the_clock(province: ProvinceSim, ship: ShipUnit) -> void:
	var port := province.buildings.get_building(ship.home_id)
	if port != null and (not port.def.is_port() or not port.is_complete()):
		port = null
	match state:
		State.IDLE:
			if port != null and not ship.hold.is_empty():
				state = State.INBOUND
			else:
				_anchor_now(province, ship, port)
		State.TO_BERTH, State.LOADING:
			if port == null:
				return
			province.jobs.cancel_for_entity(ship.id)
			_loading_goods = {}
			if expedition != 0 and province.departure != null:
				province.departure.gather_at_once(province)
			var plan := cargo()
			for good: StringName in _sorted(plan):
				var units := plan[good] - ship.hold.total(good)
				if units <= 0:
					continue
				var taken := province.take_from_storages(good, units, port.entrance_tile(), false)
				var left := ship.hold.add(good, taken)
				if left > 0:
					province.drop_goods(province.door_tile(port), good, left)
			if _waits_to_be_sent(province):
				return
			_cast_off(province, ship)
			_go_over_horizon(province, ship)
			if expedition == 0 and route == 0:
				back_at += SimClock.seconds_to_ticks(SAIL_BY_CLOCK)
		State.OUTBOUND:
			_go_over_horizon(province, ship)
		State.AWAY:
			if province.tick >= back_at:
				_come_back(province, ship)
		State.INBOUND, State.UNLOADING:
			if port == null:
				return
			_pay_out(province, ship)
			province.jobs.cancel_for_entity(ship.id)
			var goods := ship.hold.totals()
			for good: StringName in _sorted(goods):
				var left := goods[good]
				while left > 0:
					var sink := province.nearest_sink(good, 1, port.entrance_tile())
					if sink == 0:
						break
					var before := left
					left = province.storage(sink).add(good, left)
					if left == before:
						break
				ship.hold.remove(good, goods[good] - left)
			if ship.hold.is_empty():
				state = State.IDLE
				_usual_hold(province, ship)
				_anchor_now(province, ship, port)


## The cog lies at its anchorage at once (no sailing).
func _anchor_now(province: ProvinceSim, ship: ShipUnit, port: BuildingState) -> void:
	if anchor == Agent.NO_TILE and port != null:
		anchor = anchorage(province, ship, port.berth_tile())
	ship.dock_id = 0
	ship.berth_id = 0
	ship.clear_path()
	if anchor != Agent.NO_TILE:
		ship.pos = IsoMath.tile_center(anchor)
		ship.prev_pos = ship.pos


## The nearest finished port without a trading ship that the ship can reach; null if none.
func _find_home(province: ProvinceSim, ship: ShipUnit) -> BuildingState:
	var taken: Dictionary[int, bool] = {}
	for other: ShipUnit in province.ships.values():
		if other != ship and other.voyage != null and other.home_id != 0:
			taken[other.home_id] = true
	var best: BuildingState = null
	var best_d := 1 << 30
	var nav := Ships.nav_for(province, ship.def)
	for building: BuildingState in province.buildings.all():
		if not building.def.is_port() or not building.is_complete() or taken.has(building.id):
			continue
		var d := (building.berth_tile() - ship.tile()).length_squared()
		if d < best_d and (ship.is_away() or ship.tile() == building.berth_tile() \
				or not nav.find_path(ship.tile(), building.berth_tile()).is_empty()):
			best_d = d
			best = building
	if best != null:
		ship.home_id = best.id
		anchor = Agent.NO_TILE
		province.events.emit(&"ship_assigned", {"ship": ship.id, "building": best.id})
	return best


## Waits at anchor near the home port (or near where it is, without a port).
func _go_to_anchor(province: ProvinceSim, ship: ShipUnit, port: BuildingState) -> void:
	if ship.berth_id != 0 and Harbour.port_of(province, ship.id) == null:
		ship.berth_id = 0
	if anchor == Agent.NO_TILE or not Ships.nav_for(province, ship.def).is_walkable(anchor):
		var near := port.berth_tile() if port != null else ship.tile()
		anchor = anchorage(province, ship, near)
		if anchor == Agent.NO_TILE:
			return
	if ship.tile() == anchor or ship.path_state == ShipUnit.PathState.MOVING:
		if ship.tile() == anchor and ship.path_state == ShipUnit.PathState.ARRIVED:
			ship.clear_path()
		return
	ship.berth_id = 0
	if not Ships.sail_to(province, ship, anchor):
		anchor = Agent.NO_TILE


## Deep water at least ANCHOR_MIN tiles from [param near], off the fairways and away from
## other ships' anchorages, nearest by water (breadth first in a fixed order); Agent.NO_TILE
## when none is found.
static func anchorage(province: ProvinceSim, ship: ShipUnit, near: Vector2i) -> Vector2i:
	var nav := Ships.nav_for(province, ship.def)
	var taken: Dictionary[Vector2i, bool] = {}
	for other: ShipUnit in province.ships.values():
		if other != ship and other.voyage != null and other.voyage.anchor != Agent.NO_TILE:
			taken[other.voyage.anchor] = true
	var start := near
	if not nav.is_walkable(start):
		start = ship.tile()
	if not nav.is_walkable(start):
		return Agent.NO_TILE
	var seen: Dictionary[Vector2i, bool] = {start: true}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size() and head < ANCHOR_SEARCH:
		var tile := queue[head]
		head += 1
		var d := tile - near
		if maxi(absi(d.x), absi(d.y)) >= ANCHOR_MIN and province.sail_depth(tile) >= 2 \
				and not province.fairway.has(tile) and not taken.has(tile):
			return tile
		for step: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
			var next := tile + step
			if not seen.has(next) and nav.is_walkable(next):
				seen[next] = true
				queue.append(next)
	return Agent.NO_TILE


## Takes the berth of the home port and moors there (to load, or to unload on return).
func _to_berth(province: ProvinceSim, ship: ShipUnit, port: BuildingState) -> void:
	if port == null:
		if state == State.INBOUND:
			_pay_out(province, ship)
		state = State.IDLE
		_go_to_anchor(province, ship, null)
		return
	if ship.is_moored() and ship.dock_id == port.id:
		_moored(province, ship, port)
		return
	if not Harbour.claim_berth(province, ship, port):
		_go_to_anchor(province, ship, port)   # another ship is there: wait at anchor
		return
	var berth := port.berth_tile()
	if ship.path_state == ShipUnit.PathState.ARRIVED and ship.tile() == berth:
		Harbour.moor(ship, port)
		_moored(province, ship, port)
	elif ship.path_state != ShipUnit.PathState.MOVING or ship.path_goal != berth:
		if not Ships.sail_to(province, ship, berth):
			ship.berth_id = 0
			if state == State.INBOUND:
				_pay_out(province, ship)
			state = State.IDLE


func _moored(province: ProvinceSim, ship: ShipUnit, port: BuildingState) -> void:
	if state == State.INBOUND:
		_pay_out(province, ship)
		state = State.UNLOADING
		province.events.emit(&"voyage_returned", {"ship": ship.id, "port": port.id,
				"gold": last_earned})
		_unload(province, ship, port)
	else:
		state = State.LOADING
		depart_now = false
		stopped_at = 0
		province.events.emit(&"voyage_loading", {"ship": ship.id, "port": port.id})
		_load(province, ship, port)


## Loading: the plan's goods to the quay and aboard. Casts off when it is done.
func _load(province: ProvinceSim, ship: ShipUnit, port: BuildingState) -> void:
	if port == null or Harbour.port_of(province, ship.id) == null:
		_stop_loading(province, ship, port)
		_cast_off(province, ship)
		return
	if stopped_at == 0:
		if depart_now or _loaded(province, ship, port):
			_stop_loading(province, ship, port)
			stopped_at = province.tick
		else:
			_refresh_loading(province, ship, port)
			return
	var waited := province.tick >= stopped_at + SimClock.seconds_to_ticks(FINISH_WAIT)
	if expedition != 0 and province.departure != null and not province.departure.all_aboard():
		return   # the settlers are not all aboard yet
	if not _dockers_busy(province, ship) or waited:
		if _waits_to_be_sent(province):
			return
		_cast_off(province, ship)


## An expedition aboard that is ready but not sent yet: the cog stays moored (M6 part 2).
func _waits_to_be_sent(province: ProvinceSim) -> bool:
	if expedition == 0 or province.departure == null or province.departure.id != expedition:
		return false
	if province.departure.is_sent():
		return false
	province.departure.mark_ready(province)
	return true


func _sorted(plan: Dictionary[StringName, int]) -> Array[StringName]:
	var goods: Array[StringName] = []
	goods.assign(plan.keys())
	goods.sort()
	return goods


## Units of [param good] still to come aboard: the plan minus what is aboard, on the quay,
## or on its way there or aboard.
func _missing(province: ProvinceSim, ship: ShipUnit, port: BuildingState, good: StringName) -> int:
	return int(cargo().get(good, 0)) - ship.hold.total(good) - port.stock.total(good) \
			- province.jobs.in_flight(good, 0, port.id) - province.jobs.in_flight(good, port.id, ship.id)


## Whether all of the plan is aboard, or nothing more can come (storages are out of it and
## nothing is on the way).
func _loaded(province: ProvinceSim, ship: ShipUnit, port: BuildingState) -> bool:
	var plan := cargo()
	for good: StringName in _sorted(plan):
		if ship.hold.total(good) >= plan[good]:
			continue
		if port.stock.total(good) > 0 or province.jobs.in_flight(good, 0, port.id) > 0 \
				or province.jobs.in_flight(good, port.id, ship.id) > 0:
			return false
		if province.stored(good) > 0 and ship.hold.free_space(good) > 0:
			return false
	return true


func _refresh_loading(province: ProvinceSim, ship: ShipUnit, port: BuildingState) -> void:
	_loading_goods = {}
	for good: StringName in _sorted(cargo()):
		_loading_goods[good] = true
		var more := mini(maxi(_missing(province, ship, port, good), 0), province.stored(good))
		province.jobs.set_amount(good, 0, port.id, more)
		province.jobs.set_amount(good, port.id, ship.id, port.stock.available(good))


## No more requests for loading; what is left on the quay goes back to storages.
func _stop_loading(province: ProvinceSim, ship: ShipUnit, port: BuildingState) -> void:
	province.jobs.cancel_for_entity(ship.id)
	if port != null:
		for good: StringName in _loading_goods:
			province.jobs.set_amount(good, 0, port.id, 0)
	_loading_goods = {}


static func _dockers_busy(province: ProvinceSim, ship: ShipUnit) -> bool:
	for agent: Agent in province.agents.all():
		if agent.task != null and (int(agent.task.bb.get("_src", 0)) == ship.id \
				or int(agent.task.bb.get("_dst", 0)) == ship.id):
			return true
	return false


static func _fail_dockers(province: ProvinceSim, ship: ShipUnit) -> void:
	for agent: Agent in province.agents.all():
		if agent.task != null and (int(agent.task.bb.get("_src", 0)) == ship.id \
				or int(agent.task.bb.get("_dst", 0)) == ship.id):
			TaskRunner.fail(province, agent)


## Takes the purse for the order and sails for the sea edge.
func _cast_off(province: ProvinceSim, ship: ShipUnit) -> void:
	_fail_dockers(province, ship)
	province.jobs.cancel_for_entity(ship.id)
	purse = 0
	buying = {}
	for good: StringName in (_sorted(order) if expedition == 0 and route == 0 else ([] as Array[StringName])):
		var price := maxi(SeaMerchant.sell_price(province, good), 1)
		# The cargo is sold before the order is loaded, so the whole hold is free for it.
		var units := mini(order[good], (province.treasury.gold - purse) / price)
		if units <= 0:
			continue
		buying[good] = units
		purse += units * price
	while slots_needed(buying, ship.hold) > ship.def.hold_slots:
		var last: StringName = _sorted(buying).back()
		buying[last] -= 1
		purse -= maxi(SeaMerchant.sell_price(province, last), 1)
		if buying[last] <= 0:
			buying.erase(last)
	province.treasury.pay(purse)
	var port := province.buildings.get_building(ship.home_id)
	var from := port.berth_tile() if port != null else ship.tile()
	edge = SeaMerchant._edge_for(province, Ships.nav_for(province, ship.def), from)
	ship.berth_id = 0
	ship.dock_id = 0
	state = State.OUTBOUND
	province.events.emit(&"voyage_departed", {"ship": ship.id, "cargo": ship.hold.total_amount(),
			"purse": purse})
	if edge == Agent.NO_TILE or not Ships.sail_to(province, ship, edge):
		ship.clear_path()   # no way out to sea: it sets off from where it is


## At the sea edge: over the horizon it sells the cargo and buys the order. With an
## expedition aboard it is on the world map instead, until the Simulation calls it home.
func _go_over_horizon(province: ProvinceSim, ship: ShipUnit) -> void:
	ship.clear_path()
	if expedition != 0:
		var kit := ship.hold.totals()
		for good: StringName in kit:
			ship.hold.remove(good, kit[good])
		if province.departure != null and province.departure.id == expedition:
			province.departure.sailed(kit)
		back_at = AWAY_WITH_EXPEDITION
		state = State.AWAY
		province.events.emit(&"expedition_sailed", {"ship": ship.id, "expedition": expedition})
		return
	if route != 0:
		shipped = ship.hold.totals()
		for good: StringName in shipped:
			ship.hold.remove(good, shipped[good])
		route_run = {}
		back_at = AWAY_WITH_EXPEDITION
		state = State.AWAY
		province.events.emit(&"route_sailed", {"ship": ship.id, "route": route})
		return
	earned = 0
	var sold := 0
	var cargo := ship.hold.totals()
	for good: StringName in _sorted(cargo):
		var units := ship.hold.remove(good, cargo[good])
		earned += units * sale_price(province, good)
		sold += units
		province.ledger.used(good, units, province.tick)
	var bought := 0
	for good: StringName in _sorted(buying):
		bought += buying[good] - ship.hold.add(good, buying[good])
	last_sold = sold
	last_bought = bought
	last_spent = purse
	purse = 0
	buying = {}
	back_at = province.tick + SimClock.seconds_to_ticks(AWAY_TIME)
	state = State.AWAY
	province.events.emit(&"voyage_away", {"ship": ship.id, "sold": sold, "gold": earned})


func _come_back(province: ProvinceSim, ship: ShipUnit) -> void:
	state = State.INBOUND
	if expedition != 0:
		_usual_hold(province, ship)
	expedition = 0
	var goods := ship.hold.totals()
	for good: StringName in _sorted(goods):
		province.ledger.made(good, goods[good], province.tick)
	province.events.emit(&"voyage_back", {"ship": ship.id})


## The gold of the sale goes into the treasury.
func _pay_out(province: ProvinceSim, ship: ShipUnit) -> void:
	if earned <= 0:
		return
	province.treasury.add(earned)
	last_earned = earned
	province.events.emit(&"goods_sold", {"good": &"", "amount": last_sold, "gold": earned,
			"ship": ship.id})
	earned = 0


## Unloading: dockers carry the order onto the quay; then back to anchor.
func _unload(province: ProvinceSim, ship: ShipUnit, port: BuildingState) -> void:
	if port == null or Harbour.port_of(province, ship.id) == null:
		province.jobs.cancel_for_entity(ship.id)
		state = State.IDLE
		return
	var goods := ship.hold.totals()
	for good: StringName in _sorted(goods):
		province.jobs.set_amount(good, ship.id, port.id, ship.hold.available(good))
	if ship.hold.is_empty() and not _dockers_busy(province, ship):
		province.jobs.cancel_for_entity(ship.id)
		state = State.IDLE
		_usual_hold(province, ship)
		ship.dock_id = 0
		ship.berth_id = 0
		province.events.emit(&"voyage_done", {"ship": ship.id, "port": port.id})
		_go_to_anchor(province, ship, port)


## Back from (or done with) an expedition and empty: the usual hold again (Departure.begin
## gave it a bigger one).
static func _usual_hold(province: ProvinceSim, ship: ShipUnit) -> void:
	if ship.hold.is_empty() and ship.hold.slot_count() != ship.def.hold_slots:
		ship.hold = Stockpile.new(ship.def.hold_slots, province.data)
		ship.hold.stack_limit = ship.def.hold_stack


## The expedition aboard was disbanded before it was sent (Departure.disband): dockers carry
## the kit back onto the quay (porters take it to storages), then the cog goes to anchor.
func abandon_expedition(province: ProvinceSim, ship: ShipUnit) -> void:
	if expedition == 0:
		return
	var port := province.buildings.get_building(ship.home_id)
	_fail_dockers(province, ship)
	_stop_loading(province, ship, port)
	province.jobs.cancel_for_entity(ship.id)
	expedition = 0
	stopped_at = 0
	depart_now = false
	if not ship.hold.is_empty():
		state = State.UNLOADING
	else:
		state = State.IDLE
		_usual_hold(province, ship)
		if ship.berth_id != 0 or ship.dock_id != 0:
			ship.dock_id = 0
			ship.berth_id = 0
			ship.clear_path()


## The player starts a voyage with the plan (StartVoyageCommand).
func start() -> void:
	if state == State.IDLE:
		state = State.TO_BERTH
		depart_now = false


## What it loads: the start kit of its expedition, a trade route's run, or the player's plan.
func cargo() -> Dictionary[StringName, int]:
	if expedition != 0:
		return Departure.KIT
	return route_run if route != 0 else sell


## A run of its trade route with [param run] (good -> units): it goes to the berth
## and loads (M6 part 3).
func start_route_run(run: Dictionary[StringName, int]) -> void:
	route_run = run.duplicate()
	shipped = {}
	start()


## The route of this cog came back (or let it go): it sails in from the horizon.
func call_home(tick: int) -> void:
	if state == State.AWAY and back_at == AWAY_WITH_EXPEDITION and expedition == 0:
		back_at = tick


## The ship (or its home port) is gone: drop its requests.
static func on_ship_removed(province: ProvinceSim, ship: ShipUnit) -> void:
	province.jobs.cancel_for_entity(ship.id)


func to_dict() -> Dictionary:
	var d := {"state": state, "anchor": SimCodec.vec2i(anchor)}
	if not sell.is_empty():
		d["sell"] = _plan_to_dict(sell)
	if expedition != 0:
		d["expedition"] = expedition
	if route != 0:
		d["route"] = route
	if not route_run.is_empty():
		d["route_run"] = _plan_to_dict(route_run)
	if not shipped.is_empty():
		d["shipped"] = _plan_to_dict(shipped)
	if not order.is_empty():
		d["order"] = _plan_to_dict(order)
	if state != State.IDLE:
		d["edge"] = SimCodec.vec2i(edge)
		d["back_at"] = back_at
		d["depart_now"] = depart_now
		d["stopped_at"] = stopped_at
		d["purse"] = purse
		d["earned"] = earned
		if not buying.is_empty():
			d["buying"] = _plan_to_dict(buying)
		var loading: Array = []
		for good: StringName in _loading_goods:
			loading.append(String(good))
		loading.sort()
		d["loading"] = loading
	if last_earned != 0 or last_spent != 0 or last_sold != 0 or last_bought != 0:
		d["last"] = [last_earned, last_spent, last_sold, last_bought]
	return d


static func _plan_to_dict(plan: Dictionary[StringName, int]) -> Dictionary:
	var d := {}
	for good: StringName in plan:
		d[String(good)] = plan[good]
	return d


static func _plan_from(d: Variant) -> Dictionary[StringName, int]:
	var plan: Dictionary[StringName, int] = {}
	if d is Dictionary:
		for good: Variant in d:
			plan[StringName(String(good))] = int(d[good])
	return plan


static func from_dict(d: Dictionary) -> Voyage:
	var v := Voyage.new()
	v.state = clampi(int(d.get("state", 0)), State.IDLE, State.UNLOADING) as State
	v.anchor = SimCodec.to_vec2i(d.get("anchor", [-1, -1]))
	v.sell = _plan_from(d.get("sell", {}))
	v.expedition = int(d.get("expedition", 0))
	v.route = int(d.get("route", 0))
	v.route_run = _plan_from(d.get("route_run", {}))
	v.shipped = _plan_from(d.get("shipped", {}))
	v.order = _plan_from(d.get("order", {}))
	v.edge = SimCodec.to_vec2i(d.get("edge", [-1, -1]))
	v.back_at = int(d.get("back_at", 0))
	v.depart_now = bool(d.get("depart_now", false))
	v.stopped_at = int(d.get("stopped_at", 0))
	v.purse = int(d.get("purse", 0))
	v.earned = int(d.get("earned", 0))
	v.buying = _plan_from(d.get("buying", {}))
	for good: Variant in d.get("loading", []):
		v._loading_goods[StringName(String(good))] = true
	var last: Array = d.get("last", [0, 0, 0, 0])
	v.last_earned = int(last[0])
	v.last_spent = int(last[1])
	v.last_sold = int(last[2])
	v.last_bought = int(last[3])
	return v
