class_name Departure
extends RefCounted
## An expedition of settlers getting ready in the province it sets out from (ROADMAP M6 part 2,
## owner's decision 2026-11-06: visibly). Lives in ProvinceSim.departure until it is gone; the
## journey itself is the world's (Expedition).
##
## The player prepares it with only its kind, by land or by sea (owner's decision 2026-11-06,
## PrepareExpeditionCommand); the province it goes to is chosen on the world map once it is
## ready (SendExpeditionCommand), and the gold is paid then.
##
## GATHERING: one by one, settlers leave their houses (a resident less each) and walk to the
## meeting point: by sea the port, where they go aboard the player's cog; by land the settlers'
## wagon waiting in front of the town hall. Porters bring the start kit: by sea to the quay,
## dockers carry it aboard (the cog's voyage loads the kit instead of its plan, Voyage); by land
## to the wagon.
## READY: everybody is there and the kit is loaded; it waits in town (the wagon in front of the
## town hall, the cog moored at the quay) until it is sent somewhere, or disbanded (settlers
## go home, the kit back to the storages: disband).
## LEAVING: it was sent. By sea the cog casts off for the sea edge (Voyage); by land the wagon
## and the settlers walking beside it head for the map edge.
## GONE: the last of them has left the map; the Simulation turns it into an Expedition.

# READY is last: saves keep the numbers of the older states.
enum State { GATHERING, LEAVING, GONE, READY }

## Who sets out: a builder and porters (the pioneer camp takes a builder and two porters, the
## others carry until there are huts, like the start from a ship).
const SETTLERS: Array[StringName] = [&"builder", &"porter", &"porter", &"porter", &"porter", &"porter"]
## The start kit taken from the province's storages (like the start from a ship).
const KIT: Dictionary[StringName, int] = {&"bread": 20, &"wood": 90}
## Gold an expedition costs (paid when it is sent).
const COST := 100
## Seconds between two settlers leaving their houses.
const CALL_EVERY := 2
## Slots of the cog's hold while it carries an expedition (full stacks of each good).
const EXPEDITION_HOLD_SLOTS := 8
## Slots of the settlers' wagon.
const WAGON_SLOTS := 8
const SETTLER_KIND := &"settler"

var state: State = State.GATHERING
## Expedition id (an entity id), the province it goes to (0 = not sent yet) and how.
var id: int = 0
var target: int = 0
var by_sea: bool = false
## By sea: the player's cog that takes it.
var ship_id: int = 0
## By land: the wagon (a store addressed by [member id], porters deliver to it), where it
## stands, and the agent driving it.
var wagon: Stockpile
var stand: Vector2i = Agent.NO_TILE
var wagon_agent: int = 0
## Settlers still to be called from their houses.
var to_call: int = SETTLERS.size()
## Settlers at the meeting point (aboard the cog, or by the wagon) and, while LEAVING, those
## who left the map.
var boarded: int = 0
var left_map: int = 0
## The start kit as it set out (filled when it is gone).
var kit: Dictionary[StringName, int] = {}
## Tick of the next settler's call.
var next_call: int = 0


## Sent and on its way out of the map (or gone).
func is_leaving() -> bool:
	return state == State.LEAVING or state == State.GONE


## Everybody is there and the kit is loaded; it waits to be sent.
func is_ready() -> bool:
	return state == State.READY


## Whether the player chose where it goes.
func is_sent() -> bool:
	return target != 0


## Whether it can still be disbanded (not sent yet).
func can_disband() -> bool:
	return target == 0 and (state == State.GATHERING or state == State.READY)


func is_gone() -> bool:
	return state == State.GONE


## The expedition gets ready in [param province] (PrepareExpeditionCommand has checked it):
## by sea on cog [param ship], by land with a wagon in front of the town hall.
static func begin(province: ProvinceSim, expedition_id: int, sea: bool, ship: int) -> Departure:
	var departure := Departure.new()
	departure.id = expedition_id
	departure.by_sea = sea
	departure.next_call = province.tick
	if sea:
		departure.ship_id = ship
		var cog := province.ships.get(ship) as ShipUnit
		# For the expedition the hold takes the whole kit (ROADMAP M6: settlers' gear and
		# stores fill the space of the trade goods); it is the usual hold again when back.
		cog.hold = Stockpile.new(EXPEDITION_HOLD_SLOTS, province.data)
		cog.voyage.expedition = expedition_id
		cog.voyage.start()
	else:
		departure.wagon = Stockpile.new(WAGON_SLOTS, province.data)
		departure.stand = province.door_tile(province.seat())
		departure._request_kit(province)
	province.events.emit(&"expedition_gathering", {"expedition": expedition_id, "by_sea": sea})
	return departure


## Once a second while the province is viewed.
func update(province: ProvinceSim) -> void:
	match state:
		State.GATHERING:
			if to_call > 0 and province.tick >= next_call:
				if _call_settler(province) != null:
					next_call = province.tick + CALL_EVERY * SimClock.TICKS_PER_SECOND
			if not by_sea:
				_ensure_wagon(province)
				_request_kit(province)
				if boarded == SETTLERS.size() and _kit_missing().is_empty():
					mark_ready(province)
		State.READY:
			if not by_sea:
				_ensure_wagon(province)
				if is_sent():
					_set_off(province)
		State.LEAVING:
			if not by_sea and left_map >= SETTLERS.size() + 1:
				state = State.GONE


## The settlers have to be all aboard before the cog casts off (Voyage asks).
func all_aboard() -> bool:
	return boarded >= SETTLERS.size()


## Everybody is there and the kit is loaded (by sea the cog's voyage says so): it waits to
## be sent from the world map.
func mark_ready(province: ProvinceSim) -> void:
	if state != State.GATHERING:
		return
	state = State.READY
	province.events.emit(&"expedition_ready", {"expedition": id, "by_sea": by_sea})


## The cog went over the horizon with [param cargo]: the expedition is on its way.
func sailed(cargo: Dictionary[StringName, int]) -> void:
	kit = cargo.duplicate()
	state = State.GONE


## [param agent] (on a travel task that leaves) reached the meeting point or the map edge.
func on_left(_province: ProvinceSim, agent: Agent) -> void:
	if agent.id == wagon_agent:
		wagon_agent = 0   # the wagon is taken off the map (it comes back while gathering)
		if state == State.LEAVING:
			left_map += 1
	elif state == State.GATHERING:
		boarded += 1
	else:
		left_map += 1


## A settler leaves the house with the most residents and walks to the meeting point. Null
## when no house has anybody.
func _call_settler(province: ProvinceSim) -> Agent:
	var house: BuildingState = null
	for building: BuildingState in province.buildings.all():
		if building.house != null and building.house.residents > 0 \
				and (house == null or building.house.residents > house.house.residents):
			house = building
	if house == null:
		return null
	house.house.residents -= 1
	to_call -= 1
	var agent := province.spawn_agent(SETTLER_KIND, house.entrance_tile())
	var meeting := stand
	if by_sea:
		var port := province.buildings.get_building((province.ships.get(ship_id) as ShipUnit).home_id) \
				if province.ships.has(ship_id) else null
		meeting = port.entrance_tile() if port != null else house.entrance_tile()
	TaskRunner.start_travel(agent, meeting, false, true)
	province.events.emit(&"settler_called", {"agent": agent.id, "house": house.id})
	return agent


## The settlers' wagon stands in front of the town hall while it is loaded.
func _ensure_wagon(province: ProvinceSim) -> void:
	if province.agents.get_agent(wagon_agent) != null:
		return
	var agent := province.spawn_agent(Carriers.CARTER_KIND, stand)
	agent.vehicle = Carriers.SETTLER_WAGON
	TaskRunner.start_travel(agent, province.entry_tile, true, true)
	wagon_agent = agent.id


## Goods of the kit not on the wagon yet.
func _kit_missing() -> Dictionary[StringName, int]:
	var missing: Dictionary[StringName, int] = {}
	for good: StringName in KIT:
		var n := KIT[good] - (wagon.total(good) if wagon != null else 0)
		if n > 0:
			missing[good] = n
	return missing


## Porters bring the missing kit to the wagon (the transport requests match what is missing).
func _request_kit(province: ProvinceSim) -> void:
	var goods: Array[StringName] = []
	goods.assign(KIT.keys())
	goods.sort()
	for good: StringName in goods:
		var on_way := province.jobs.in_flight(good, 0, id)
		var missing := KIT[good] - wagon.total(good) - on_way
		province.jobs.set_amount(good, 0, id, maxi(missing, 0))


## Everybody is by the wagon and it is loaded: they set off for the map edge.
func _set_off(province: ProvinceSim) -> void:
	province.jobs.cancel_for_entity(id)
	kit = wagon.totals()
	state = State.LEAVING
	for i: int in boarded:
		var agent := province.spawn_agent(SETTLER_KIND, stand)
		TaskRunner.start_travel(agent, province.entry_tile, false, true)
	if province.agents.get_agent(wagon_agent) == null:
		_ensure_wagon(province)
	wagon = null
	province.events.emit(&"expedition_leaving", {"expedition": id})


## The province is not viewed (ARCHITECTURE §7.1): the rest of the settlers and of the kit
## come at once, and a wagon sets off at once (a cog goes with Voyage.sail_by_the_clock).
func gather_at_once(province: ProvinceSim) -> void:
	if state == State.GATHERING:
		while to_call > 0:
			var house: BuildingState = null
			for building: BuildingState in province.buildings.all():
				if building.house != null and building.house.residents > 0 \
						and (house == null or building.house.residents > house.house.residents):
					house = building
			if house == null:
				break
			house.house.residents -= 1
			to_call -= 1
			boarded += 1
		if not by_sea:
			for good: StringName in _kit_missing():
				var taken := province.take_from_storages(good, _kit_missing()[good], stand, false)
				wagon.add(good, taken)
			if all_aboard() and _kit_missing().is_empty():
				mark_ready(province)
	if state == State.READY and not by_sea and is_sent():
		province.jobs.cancel_for_entity(id)
		kit = wagon.totals()
		wagon = null
		state = State.GONE
	elif state == State.LEAVING and not by_sea:
		state = State.GONE


## The player changed his mind before sending it (DisbandExpeditionCommand): the settlers go
## back to their houses, the kit goes back to the storages and the cog back to anchor. In a
## province nobody looks at ([param at_once]) the goods go into storages at once; in the
## viewed one they are put down where they are and porters take them back.
func disband(province: ProvinceSim, at_once: bool) -> void:
	province.jobs.cancel_for_entity(id)
	var people := boarded
	var walking: Array[Agent] = []
	for agent: Agent in province.agents.all():
		if agent.task == null or agent.id == wagon_agent:
			continue
		if agent.task.kind == Task.KIND_TRAVEL and agent.task.bb.has("leave"):
			walking.append(agent)
		elif int(agent.task.bb.get("_dst", 0)) == id:
			TaskRunner.fail(province, agent)   # a porter on his way to the wagon keeps his load
	for agent: Agent in walking:
		province.remove_agent(agent)
		people += 1
	var wagon_man := province.agents.get_agent(wagon_agent)
	if wagon_man != null:
		province.remove_agent(wagon_man)
	wagon_agent = 0
	_return_home(province, people)
	if wagon != null:
		var goods := wagon.totals()
		for good: StringName in _sorted(goods):
			wagon.remove(good, goods[good])
			give_back(province, good, goods[good], stand, at_once)
		wagon = null
	if by_sea:
		var cog := province.ships.get(ship_id) as ShipUnit
		if cog != null and cog.voyage != null and cog.voyage.expedition == id:
			cog.voyage.abandon_expedition(province, cog)
	boarded = 0
	to_call = 0
	province.events.emit(&"expedition_disbanded", {"expedition": id, "settlers": people})


## [param people] settlers move back in: into houses with room, the emptiest first.
static func _return_home(province: ProvinceSim, people: int) -> void:
	var left := people
	while left > 0:
		var best: BuildingState = null
		var best_room := 0
		for building: BuildingState in province.buildings.all():
			if building.house == null or not building.is_complete():
				continue
			var room := building.capacity() - building.house.residents - building.house.incoming
			if room > best_room:
				best = building
				best_room = room
		if best == null:
			return
		best.house.residents += 1
		left -= 1


## [param amount] of [param good] goes back to the storages: at once, or put down at
## [param tile] for porters (what does not fit in the storages is put down too).
static func give_back(province: ProvinceSim, good: StringName, amount: int, tile: Vector2i, at_once: bool) -> void:
	var left := amount
	while at_once and left > 0:
		var sink := province.nearest_sink(good, 1, tile)
		if sink == 0:
			break
		var before := left
		left = province.storage(sink).add(good, left)
		if left == before:
			break
	if left > 0:
		province.drop_goods(tile, good, left)


static func _sorted(goods: Dictionary[StringName, int]) -> Array[StringName]:
	var keys: Array[StringName] = []
	keys.assign(goods.keys())
	keys.sort()
	return keys


func to_dict() -> Dictionary:
	var d := {"state": state, "id": id, "target": target, "sea": by_sea, "call": to_call,
			"boarded": boarded, "next": next_call}
	if by_sea:
		d["ship"] = ship_id
	else:
		d["stand"] = SimCodec.vec2i(stand)
		d["wagon_agent"] = wagon_agent
		d["left"] = left_map
		if wagon != null:
			d["wagon"] = wagon.to_dict()
	if not kit.is_empty():
		d["kit"] = Expedition.goods_to_dict(kit)
	return d


static func from_dict(d: Dictionary, data: DataRegistry) -> Departure:
	var departure := Departure.new()
	departure.state = int(d.get("state", 0)) as State
	departure.id = int(d["id"])
	departure.target = int(d["target"])
	departure.by_sea = bool(d.get("sea", false))
	departure.to_call = int(d.get("call", 0))
	departure.boarded = int(d.get("boarded", 0))
	departure.next_call = int(d.get("next", 0))
	departure.ship_id = int(d.get("ship", 0))
	departure.stand = SimCodec.to_vec2i(d.get("stand", [-1, -1]))
	departure.wagon_agent = int(d.get("wagon_agent", 0))
	departure.left_map = int(d.get("left", 0))
	if d.has("wagon"):
		departure.wagon = Stockpile.from_dict(d["wagon"], data)
	departure.kit = Expedition.goods_from(d.get("kit", {}))
	return departure
