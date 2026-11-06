class_name Merchant
extends RefCounted
## The travelling merchant (ROADMAP M4b-2, GDD §4.6). About every VISIT_EVERY seconds he
## comes from the map edge to the market (no market, no visit), stands by it for STAY seconds
## and buys what the player sells: of every good with a "sell above N" setting, porters carry
## what the storages hold above N to his wagon, and each unit is paid at its base price. He
## also sells pigs (BuyPigCommand): a porter leads each one to a pigsty. Then he leaves.
##
## The wagon is a storage with its own entity id while he trades; porters deliver to it.

enum State { AWAY, COMING, TRADING, LEAVING }

const VISIT_EVERY := 600.0
const STAY := 180.0
## Extra wait for porters to lead bought pigs away; pigs left after it are refunded.
const PIG_WAIT := 120.0
## Pigs he brings to sell on each visit, and the price of one.
const PIGS_PER_VISIT := 4
const PIG_PRICE := 30
const PIG := &"pig"
const AGENT_KIND := &"merchant"
const WAGON_SLOTS := 24
## Highest "sell above" setting the player can choose.
const MAX_SELL_ABOVE := 200

var state: State = State.AWAY
## Tick of the next visit.
var next_visit: int = SimClock.seconds_to_ticks(VISIT_EVERY)
## Tick he stops buying (while TRADING).
var leave_at: int = 0
var agent_id: int = 0
var market_id: int = 0
## Where the wagon stands (in front of the market's door).
var stand: Vector2i = Vector2i.ZERO
var wagon_id: int = 0
var wagon: Stockpile
var pigs_left: int = 0
## Player setting: good -> units the storages keep; the merchant buys only what is above.
## A good without a setting is not sold.
var sell_above: Dictionary[StringName, int] = {}
## Gold earned this visit (shown in the market panel).
var earned: int = 0


func is_trading() -> bool:
	return state == State.TRADING


## Price the merchant pays for one unit of [param good].
static func price(province: ProvinceSim, good: StringName) -> int:
	var def := province.data.get_good(good)
	return def.base_price if def != null else 0


## Runs once per second (ProvinceSim.step).
func update(province: ProvinceSim) -> void:
	if state != State.AWAY and state != State.TRADING and province.agents.get_agent(agent_id) == null:
		gone()
	match state:
		State.AWAY:
			if province.tick >= next_visit:
				next_visit = province.tick + SimClock.seconds_to_ticks(VISIT_EVERY)
				_arrive(province)
		State.TRADING:
			_pay_for_wagon(province)
			if province.tick < leave_at:
				_refresh_requests(province)
				return
			_stop_buying(province)
			if _pigs_waiting() == 0 or province.tick >= leave_at + SimClock.seconds_to_ticks(PIG_WAIT):
				_close(province)


## Whether the merchant can come now: a finished market with free ground in front of a door.
func _arrive(province: ProvinceSim) -> void:
	var market: BuildingState = null
	for building: BuildingState in province.buildings.all():
		if not building.def.stall_goods.is_empty() and building.is_complete():
			market = building
			break
	if market == null or not province.nav.is_walkable(province.entry_tile):
		return
	var door := province.door_tile(market)
	if door == Agent.NO_TILE:
		return
	market_id = market.id
	stand = door
	var agent := province.spawn_agent(AGENT_KIND, province.entry_tile)
	agent_id = agent.id
	var task := Task.new()
	task.kind = Task.KIND_MERCHANT
	task.steps = TaskRunner.merchant_steps()
	agent.task = task
	state = State.COMING
	province.events.emit(&"merchant_coming", {"agent": agent.id, "market": market.id})


## His visits while nobody looks at the province (M6, ARCHITECTURE §7.1): when one is due and
## a market stands, he buys the surplus of every good with a setting at once. A visit under way
## when the province was left ends: the wagon is paid for, unled pigs are refunded.
func trade_at_once(province: ProvinceSim) -> void:
	match state:
		State.TRADING:
			_pay_for_wagon(province)
			_close(province)
			gone()
		State.COMING, State.LEAVING:
			gone()
		State.AWAY:
			if province.tick < next_visit:
				return
			next_visit = province.tick + SimClock.seconds_to_ticks(VISIT_EVERY)
			var market := false
			for building: BuildingState in province.buildings.all():
				if not building.def.stall_goods.is_empty() and building.is_complete():
					market = true
			if not market:
				return
			earned = 0
			var goods: Array[StringName] = []
			goods.assign(sell_above.keys())
			goods.sort()
			for good: StringName in goods:
				var units := province.take_from_storages(good, surplus(province, good), province.entry_tile)
				earned += units * price(province, good)
			province.treasury.add(earned)


## The merchant reached the market: the wagon opens.
func start_trading(province: ProvinceSim) -> void:
	state = State.TRADING
	leave_at = province.tick + SimClock.seconds_to_ticks(STAY)
	wagon_id = province.ids.take()
	wagon = Stockpile.new(WAGON_SLOTS, province.data)
	pigs_left = PIGS_PER_VISIT
	earned = 0
	_refresh_requests(province)
	province.events.emit(&"merchant_arrived", {"agent": agent_id, "market": market_id})


## The merchant gave up on the way in (no path): he turns back.
func give_up(province: ProvinceSim) -> void:
	state = State.LEAVING
	province.events.emit(&"merchant_left", {"agent": agent_id, "earned": 0})


## The merchant is gone from the map.
func gone() -> void:
	state = State.AWAY
	agent_id = 0


## Sells one pig to the player: paid now, then a porter leads it from the wagon to the
## pigsty. &"" when done, otherwise the reason.
func buy_pig(province: ProvinceSim) -> StringName:
	var error := pig_error(province)
	if error != &"":
		return error
	var herd := province.nearest_sink(PIG, 1, stand)
	province.treasury.pay(PIG_PRICE)
	pigs_left -= 1
	wagon.add(PIG, 1)
	province.jobs.add(PIG, 1, wagon_id, herd)
	province.ledger.made(PIG, 1, province.tick)
	province.events.emit(&"pig_bought", {"herd": herd})
	return &""


func pig_error(province: ProvinceSim) -> StringName:
	if not is_trading() or province.tick >= leave_at:
		return &"merchant_away"
	if pigs_left <= 0:
		return &"no_pigs_left"
	if province.treasury.gold < PIG_PRICE:
		return &"not_enough_gold"
	if province.nearest_sink(PIG, 1, stand) == 0:
		return &"no_room_for_pigs"
	return &""


## Units of [param good] the merchant would buy now (what is above the player's setting).
func surplus(province: ProvinceSim, good: StringName) -> int:
	if not sell_above.has(good):
		return 0
	return maxi(province.stored(good) - int(sell_above[good]), 0)


## Pays for everything porters put on the wagon (pigs on the wagon are for sale, not bought).
func _pay_for_wagon(province: ProvinceSim) -> void:
	for slot: int in wagon.slot_count():
		var good := wagon.slot_good[slot]
		if good == &"" or good == PIG:
			continue
		var amount := wagon.remove(good, wagon.slot_amount[slot] - wagon.slot_out[slot])
		if amount <= 0:
			continue
		var gold := amount * price(province, good)
		province.treasury.add(gold)
		earned += gold
		province.ledger.used(good, amount, province.tick)
		province.events.emit(&"goods_sold", {"good": good, "amount": amount, "gold": gold})


## One request per good sold: what is above the setting, plus what porters already carry.
func _refresh_requests(province: ProvinceSim) -> void:
	for good: StringName in sell_above:
		var wanted := surplus(province, good)
		province.jobs.set_amount(good, 0, wagon_id, wanted)


func _stop_buying(province: ProvinceSim) -> void:
	for good: StringName in sell_above:
		province.jobs.set_amount(good, 0, wagon_id, 0)


func _pigs_waiting() -> int:
	return wagon.total(PIG) if wagon != null else 0


## Stops trading: requests to the wagon end, unled pigs are refunded, the merchant leaves.
func _close(province: ProvinceSim) -> void:
	province.jobs.cancel_for_entity(wagon_id)
	var refund := _pigs_waiting()
	if refund > 0:
		province.treasury.add(refund * PIG_PRICE)
	for agent: Agent in province.agents.all():
		if agent.task != null and (int(agent.task.bb.get("_src", 0)) == wagon_id \
				or int(agent.task.bb.get("_dst", 0)) == wagon_id):
			TaskRunner.fail(province, agent)
	wagon = null
	wagon_id = 0
	state = State.LEAVING
	province.events.emit(&"merchant_left", {"agent": agent_id, "earned": earned})


func to_dict() -> Dictionary:
	var d := {"state": state, "next": next_visit}
	var sells := {}
	for good: StringName in sell_above:
		sells[String(good)] = sell_above[good]
	if not sells.is_empty():
		d["sell_above"] = sells
	if state != State.AWAY:
		d["agent"] = agent_id
		d["market"] = market_id
		d["stand"] = SimCodec.vec2i(stand)
		d["leave_at"] = leave_at
		d["pigs"] = pigs_left
		d["earned"] = earned
	if wagon != null:
		d["wagon_id"] = wagon_id
		d["wagon"] = wagon.to_dict()
	return d


static func from_dict(d: Dictionary, data: DataRegistry) -> Merchant:
	var m := Merchant.new()
	m.state = clampi(int(d.get("state", 0)), State.AWAY, State.LEAVING) as State
	m.next_visit = int(d.get("next", m.next_visit))
	var sells: Dictionary = d.get("sell_above", {})
	for good: Variant in sells:
		m.sell_above[StringName(String(good))] = int(sells[good])
	m.agent_id = int(d.get("agent", 0))
	m.market_id = int(d.get("market", 0))
	m.stand = SimCodec.to_vec2i(d.get("stand", [0, 0]))
	m.leave_at = int(d.get("leave_at", 0))
	m.pigs_left = int(d.get("pigs", 0))
	m.earned = int(d.get("earned", 0))
	if d.has("wagon"):
		m.wagon_id = int(d["wagon_id"])
		m.wagon = Stockpile.from_dict(d["wagon"], data)
	return m
