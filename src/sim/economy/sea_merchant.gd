class_name SeaMerchant
extends RefCounted
## The sea merchant (ROADMAP M5 part 2, GDD §4.6). About every VISIT_EVERY seconds a foreign
## cog sails in from the edge of the sea to a port with a free berth (no port, no visit),
## reserving the berth on the way. Moored, it trades for STAY seconds through the port's
## dockers, unit by unit over the gangway:
## - he buys the player's surplus like the travelling merchant (the same "sell above N"
##   settings, Merchant.sell_above): porters bring it from the storages to the quay yard,
##   dockers carry it aboard, and each unit is paid at its base price when it is in the hold;
## - he sells the goods of his OFFER (in his hold when he comes) at a mark-up: when the
##   kingdom has less of one than the player's "buy up to N" setting, dockers carry units
##   from the hold to the quay yard, and the player pays for each unit as it leaves the hold;
##   porters then take it to a storage (Harbour.update).
## He does not buy goods he sells himself. Then the cog sails back out over the edge.

enum State { AWAY, COMING, TRADING, LEAVING }

const VISIT_EVERY := 720.0
const STAY := 240.0
## Longest wait after STAY for dockers still on the gangway with his goods.
const FINISH_WAIT := 30.0
const SHIP := &"foreign_cog"
## Units of the player's goods he buys at most per visit.
const MAX_BUY := 40
## What he brings to sell on every visit (good -> units).
const OFFER: Dictionary[StringName, int] = {&"cloth": 10, &"planks": 20, &"tar": 10}
## His price is the base price times this, rounded up.
const SELL_MARKUP := 1.5
## Highest "buy up to" setting the player can choose.
const MAX_BUY_UP_TO := 200
## Seconds before he looks again for a port when none could take him.
const RETRY := 60.0
## How many tiles of the map edge nearest to the port are tried as the way in.
const EDGE_TRIES := 8

var state: State = State.AWAY
## Tick of the next visit.
var next_visit: int = SimClock.seconds_to_ticks(VISIT_EVERY)
## Tick he stops trading (while TRADING).
var leave_at: int = 0
var ship_id: int = 0
var port_id: int = 0
## Deep water on the map edge where he comes in and goes out.
var edge: Vector2i = Vector2i.ZERO
## Units of each good in the hold already paid for (by him or by the player).
var paid: Dictionary[StringName, int] = {}
## Units of the player's goods he bought this visit.
var bought: int = 0
## Gold he paid this visit, and gold the player paid him (shown in the ship panel).
var earned: int = 0
var spent: int = 0
## Player setting (window "Kingdom stocks"): offer good -> units the kingdom should have; he
## sells up to that. A good without a setting is not bought.
var buy_up_to: Dictionary[StringName, int] = {}
## Goods he is buying this visit, kept on the quay for his ship (good -> true).
var _loading_goods: Dictionary = {}


func is_trading() -> bool:
	return state == State.TRADING


## What he asks for one unit of [param good].
static func sell_price(province: ProvinceSim, good: StringName) -> int:
	var def := province.data.get_good(good)
	return ceili(def.base_price * SELL_MARKUP) if def != null else 0


## Goods he buys this visit: the player's "sell above" goods that are not in his offer.
func buying(province: ProvinceSim) -> Array[StringName]:
	var goods: Array[StringName] = []
	for good: StringName in province.merchant.sell_above:
		if not OFFER.has(good):
			goods.append(good)
	goods.sort()
	return goods


## Goods the quay yard keeps for his ship while he buys (Harbour.update sends the rest of the
## quay to storages): good -> true.
func loading_goods() -> Dictionary:
	return _loading_goods


## Runs once per second (ProvinceSim.step).
func update(province: ProvinceSim) -> void:
	var ship := province.ships.get(ship_id) as ShipUnit
	if state != State.AWAY and ship == null:
		_reset()
		return
	match state:
		State.AWAY:
			if province.tick >= next_visit:
				# No port with a free berth (or no way in from the sea): he looks again soon,
				# so a new port gets its first visit within a minute.
				var came := _arrive(province)
				next_visit = province.tick + SimClock.seconds_to_ticks(VISIT_EVERY if came else RETRY)
		State.COMING:
			var port := province.buildings.get_building(port_id)
			if port == null or not port.def.is_port() or not port.is_complete():
				_depart(province, ship)
			elif ship.path_state == ShipUnit.PathState.ARRIVED and ship.tile() == port.berth_tile():
				_start_trading(province, ship, port)
			elif ship.path_state != ShipUnit.PathState.MOVING \
					and not Ships.sail_to(province, ship, port.berth_tile()):
				_depart(province, ship)
		State.TRADING:
			_settle(province, ship)
			if Harbour.port_of(province, ship_id) == null:
				_stop_trading(province)
				_depart(province, ship)
			elif province.tick < leave_at:
				_refresh_requests(province, ship)
			else:
				_stop_trading(province)
				var waited := province.tick >= leave_at + SimClock.seconds_to_ticks(FINISH_WAIT)
				if not _dockers_busy(province) or waited:
					_settle(province, ship)
					_depart(province, ship)
		State.LEAVING:
			if ship.path_state != ShipUnit.PathState.MOVING:
				province.ships.erase(ship_id)
				province.events.emit(&"sea_merchant_left", {"ship": ship_id, "earned": earned,
						"spent": spent})
				_reset()


## His visits while nobody looks at the province (M6, ARCHITECTURE §7.1): when one is due and
## a port stands, he trades at once (the same limits as a visit) and sails off. A visit under
## way when the province was left ends the same way with what is left in his hold.
func trade_at_once(province: ProvinceSim) -> void:
	var ship := province.ships.get(ship_id) as ShipUnit
	match state:
		State.AWAY:
			if province.tick < next_visit:
				return
			if _port(province) == null:
				next_visit = province.tick + SimClock.seconds_to_ticks(RETRY)
				return
			next_visit = province.tick + SimClock.seconds_to_ticks(VISIT_EVERY)
			bought = 0
			earned = 0
			spent = 0
			_trade_now(province, OFFER)
		State.COMING, State.TRADING:
			if ship != null:
				if state == State.TRADING:
					_settle(province, ship)
					_stop_trading(province)
				_trade_now(province, ship.hold.totals())
		State.LEAVING:
			pass
	if ship != null:
		province.jobs.cancel_for_entity(ship_id)
		province.ships.erase(ship_id)
	_reset()


## Buys the player's surplus (up to MAX_BUY in a visit) and sells from [param offer] what the
## player wants, straight from and into the storages.
func _trade_now(province: ProvinceSim, offer: Dictionary) -> void:
	var near := province.entry_tile
	for good: StringName in buying(province):
		var units := mini(province.merchant.surplus(province, good), MAX_BUY - bought)
		if units <= 0:
			continue
		units = province.take_from_storages(good, units, near)
		var gold := units * Merchant.price(province, good)
		province.treasury.add(gold)
		earned += gold
		bought += units
	var goods: Array[StringName] = []
	goods.assign(OFFER.keys())
	goods.sort()
	for good: StringName in goods:
		var wanted := int(buy_up_to.get(good, 0))
		var price := maxi(sell_price(province, good), 1)
		var units := mini(wanted - province.kingdom_stock(good), int(offer.get(good, 0)))
		units = mini(units, province.treasury.gold / price)
		var left := units
		while left > 0:
			var sink := province.nearest_sink(good, 1, near)
			if sink == 0:
				break
			var before := left
			left = province.storage(sink).add(good, left)
			if left == before:
				break
		var sold := units - left
		if sold <= 0:
			continue
		province.treasury.pay(sold * price)
		spent += sold * price
		province.ledger.made(good, sold, province.tick)


## Comes if a port has a free berth and the sea edge leads to it; false when he cannot.
func _arrive(province: ProvinceSim) -> bool:
	var port := _port(province)
	if port == null:
		return false
	var def := province.data.get_ship(SHIP)
	var nav := Ships.nav_for(province, def)
	var way_in := _edge_for(province, nav, port.berth_tile())
	if way_in == Agent.NO_TILE:
		return false
	var ship := ShipUnit.new(province.ids.take(), def, IsoMath.tile_center(way_in), province.data)
	province.ships[ship.id] = ship
	var goods: Array[StringName] = []
	goods.assign(OFFER.keys())
	goods.sort()
	for good: StringName in goods:
		ship.hold.add(good, OFFER[good])
	Harbour.claim_berth(province, ship, port)
	ship_id = ship.id
	port_id = port.id
	edge = way_in
	paid = ship.hold.totals()
	bought = 0
	earned = 0
	spent = 0
	Ships.sail_to(province, ship, port.berth_tile())
	state = State.COMING
	province.events.emit(&"sea_merchant_coming", {"ship": ship.id, "port": port.id})
	return true


## The first finished port (by id) with a free berth and dockers to serve it, or null.
static func _port(province: ProvinceSim) -> BuildingState:
	for building: BuildingState in province.buildings.all():
		if building.def.is_port() and building.is_complete() \
				and Harbour.berth_holder(province, building) == null \
				and not Harbour.crews_for(province, building).is_empty():
			return building
	return null


## Deep water on the map edge nearest to [param goal] from which [param nav] leads there;
## Agent.NO_TILE if none.
static func _edge_for(province: ProvinceSim, nav: NavGrid, goal: Vector2i) -> Vector2i:
	var size := province.grid.size
	var candidates: Array[Vector2i] = []
	for x: int in size.x:
		for y: int in [0, size.y - 1]:
			candidates.append(Vector2i(x, y))
	for y: int in range(1, size.y - 1):
		for x: int in [0, size.x - 1]:
			candidates.append(Vector2i(x, y))
	var open: Array[Vector2i] = []
	for tile: Vector2i in candidates:
		if nav.is_walkable(tile):
			open.append(tile)
	open.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := (a - goal).length_squared()
		var db := (b - goal).length_squared()
		return da < db or (da == db and (a.y < b.y or (a.y == b.y and a.x < b.x))))
	for i: int in mini(open.size(), EDGE_TRIES):
		if not nav.find_path(open[i], goal).is_empty():
			return open[i]
	return Agent.NO_TILE


func _start_trading(province: ProvinceSim, ship: ShipUnit, port: BuildingState) -> void:
	Harbour.moor(ship, port)
	state = State.TRADING
	leave_at = province.tick + SimClock.seconds_to_ticks(STAY)
	_loading_goods = {}
	for good: StringName in buying(province):
		_loading_goods[good] = true
	_refresh_requests(province, ship)
	province.events.emit(&"sea_merchant_arrived", {"ship": ship.id, "port": port.id})


## Pays for what changed hands since the last time: units of his goods that left the hold
## (the player pays) and units of the player's goods that came aboard (he pays).
func _settle(province: ProvinceSim, ship: ShipUnit) -> void:
	var goods: Array[StringName] = []
	goods.assign(paid.keys())
	for good: StringName in ship.hold.totals():
		if not goods.has(good):
			goods.append(good)
	goods.sort()
	for good: StringName in goods:
		var now := ship.hold.total(good)
		var change := now - int(paid.get(good, 0))
		paid[good] = now
		if OFFER.has(good) and change < 0:
			var cost := -change * sell_price(province, good)
			province.treasury.pay(mini(cost, province.treasury.gold))
			spent += cost
			province.ledger.made(good, -change, province.tick)
			province.events.emit(&"goods_bought", {"good": good, "amount": -change, "gold": cost})
		elif not OFFER.has(good) and change > 0:
			var gold := change * Merchant.price(province, good)
			province.treasury.add(gold)
			earned += gold
			bought += change
			province.ledger.used(good, change, province.tick)
			province.events.emit(&"goods_sold", {"good": good, "amount": change, "gold": gold})
	for good: StringName in paid.keys():
		if paid[good] == 0:
			paid.erase(good)


## Sets the requests of this second: the player's surplus to the quay and aboard, his goods
## off the ship while the kingdom has less than the player wants.
func _refresh_requests(province: ProvinceSim, ship: ShipUnit) -> void:
	# The quay yard of his port, or at a bollard the nearest port warehouse (P2 part 1), which
	# holds the kingdom's goods already: from there aboard only what the player sells.
	# Without a port warehouse near a bollard, straight from the storages (yard id 0).
	var yard := Harbour.yard(province, province.buildings.get_building(port_id))
	var yard_id := yard.id if yard != null else 0
	var store := yard != null and yard.def.is_port_storage()
	var quay := yard.stock if yard != null else null
	var jobs := province.jobs
	var goods := buying(province)
	var committed := bought
	for good: StringName in goods:
		committed += (0 if store or quay == null else quay.available(good)) \
				+ (jobs.in_flight(good, 0, yard_id) if quay != null else 0) + jobs.in_flight(good, yard_id, ship_id)
	var left := maxi(MAX_BUY - committed, 0)
	for good: StringName in goods:
		var surplus := province.merchant.surplus(province, good)
		if quay == null:
			var straight := clampi(surplus, 0, left)
			jobs.set_amount(good, 0, ship_id, straight)
			left -= straight
			continue
		if store:
			var take := mini(mini(quay.available(good), surplus), left)
			jobs.set_amount(good, yard_id, ship_id, take)
			left -= take
			surplus -= quay.available(good)
		else:
			jobs.set_amount(good, yard_id, ship_id, quay.available(good))
		var more := clampi(surplus, 0, left)
		jobs.set_amount(good, 0, yard_id, more)
		left -= more
	# Goods the player stopped selling: no more to the quay, what is there goes back.
	for good: StringName in _loading_goods.keys():
		if not goods.has(good):
			if yard_id != 0:
				jobs.set_amount(good, 0, yard_id, 0)
			jobs.set_amount(good, yard_id, ship_id, 0)
	_loading_goods = {}
	for good: StringName in goods:
		_loading_goods[good] = true
	var offer: Array[StringName] = []
	offer.assign(OFFER.keys())
	offer.sort()
	for good: StringName in offer:
		jobs.set_amount(good, ship_id, yard_id, _units_to_sell(province, ship, good))


## Units of [param good] to carry off the ship now: up to the player's setting, as far as
## his hold and the treasury go. Units reserved in the hold and goods in anybody's hands
## (dockers and porters on the way to a storage) count as the kingdom's already.
func _units_to_sell(province: ProvinceSim, ship: ShipUnit, good: StringName) -> int:
	var wanted := int(buy_up_to.get(good, 0))
	if wanted <= 0:
		return 0
	var reserved := ship.hold.total(good) - ship.hold.available(good)
	var carried := 0
	for agent: Agent in province.agents.all():
		if agent.carry_good == good:
			carried += agent.carry_amount
	var missing := wanted - province.kingdom_stock(good) - carried - reserved
	# Units off the ship since the last settling are not paid for yet.
	var unpaid := reserved + maxi(int(paid.get(good, 0)) - ship.hold.total(good), 0)
	var price := maxi(sell_price(province, good), 1)
	var affordable := province.treasury.gold / price - unpaid
	return clampi(mini(missing, affordable), 0, ship.hold.available(good))


## No more requests to or from his ship; goods kept on the quay for him go back to storages.
func _stop_trading(province: ProvinceSim) -> void:
	province.jobs.cancel_for_entity(ship_id)
	var yard_id := Harbour.yard_id(province, province.buildings.get_building(port_id))
	for good: StringName in _loading_goods:
		if yard_id != 0:
			province.jobs.set_amount(good, 0, yard_id, 0)
	_loading_goods = {}


## Whether a docker is still carrying goods to or from his ship.
func _dockers_busy(province: ProvinceSim) -> bool:
	for agent: Agent in province.agents.all():
		if agent.task != null and (int(agent.task.bb.get("_src", 0)) == ship_id \
				or int(agent.task.bb.get("_dst", 0)) == ship_id):
			return true
	return false


## Casts off: the berth is free again and the cog sails back out over the sea edge.
func _depart(province: ProvinceSim, ship: ShipUnit) -> void:
	for agent: Agent in province.agents.all():
		if agent.task != null and (int(agent.task.bb.get("_src", 0)) == ship_id \
				or int(agent.task.bb.get("_dst", 0)) == ship_id):
			TaskRunner.fail(province, agent)
	province.jobs.cancel_for_entity(ship_id)
	ship.berth_id = 0
	ship.dock_id = 0
	state = State.LEAVING
	if not Ships.sail_to(province, ship, edge):
		ship.clear_path()
	province.events.emit(&"sea_merchant_leaving", {"ship": ship.id})


func _reset() -> void:
	state = State.AWAY
	ship_id = 0
	port_id = 0
	paid = {}
	_loading_goods = {}


func to_dict() -> Dictionary:
	var d := {"state": state, "next": next_visit}
	var limits := {}
	for good: StringName in buy_up_to:
		limits[String(good)] = buy_up_to[good]
	if not limits.is_empty():
		d["buy_up_to"] = limits
	if state != State.AWAY:
		d["ship"] = ship_id
		d["port"] = port_id
		d["edge"] = SimCodec.vec2i(edge)
		d["leave_at"] = leave_at
		d["bought"] = bought
		d["earned"] = earned
		d["spent"] = spent
		var p := {}
		for good: StringName in paid:
			p[String(good)] = paid[good]
		d["paid"] = p
		var loading: Array = []
		for good: StringName in _loading_goods:
			loading.append(String(good))
		loading.sort()
		d["loading"] = loading
	return d


static func from_dict(d: Dictionary) -> SeaMerchant:
	var m := SeaMerchant.new()
	m.state = clampi(int(d.get("state", 0)), State.AWAY, State.LEAVING) as State
	m.next_visit = int(d.get("next", m.next_visit))
	var limits: Dictionary = d.get("buy_up_to", {})
	for good: Variant in limits:
		m.buy_up_to[StringName(String(good))] = int(limits[good])
	m.ship_id = int(d.get("ship", 0))
	m.port_id = int(d.get("port", 0))
	m.edge = SimCodec.to_vec2i(d.get("edge", [0, 0]))
	m.leave_at = int(d.get("leave_at", 0))
	m.bought = int(d.get("bought", 0))
	m.earned = int(d.get("earned", 0))
	m.spent = int(d.get("spent", 0))
	var p: Dictionary = d.get("paid", {})
	for good: Variant in p:
		m.paid[StringName(String(good))] = int(p[good])
	for good: Variant in d.get("loading", []):
		m._loading_goods[StringName(String(good))] = true
	return m
