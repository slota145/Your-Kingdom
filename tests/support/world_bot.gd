class_name WorldBot
extends RefCounted
## The automatic player of a world game (ROADMAP M6 part 3): SliceBot builds the start town on
## the Coast (Landing Bay), with a town hall (the seat, M6 part 2) and a trading post added; then
## the world bot settles the land neighbours one after another (Willow Vale, Amber Coast) by
## land expeditions, looks at each new province for a few minutes while its own SliceBot lays
## out the camp and the first buildings, goes home, and sets up a merchant wagon route with bread to
## the first of them. Each province's SliceBot acts only while its province is viewed (its
## plan runs on its own clock, counting only those seconds).

## When the town hall and the trading post go up in the start town (game seconds).
const HALL_AT := 900
const STABLE_AT := 1500
## From when expeditions are prepared, and how long a new province is looked at.
const EXPEDITIONS_FROM := 1800
const LOOK_SECONDS := 240
## Provinces settled by land, in order.
const TARGETS: Array[StringName] = [&"willow_vale", &"amber_coast"]

var sim: Simulation
var home: int = 0
## Province id -> its SliceBot and the seconds it has been viewed.
var bots: Dictionary[int, SliceBot] = {}
var bot_seconds: Dictionary[int, int] = {}
var log: PackedStringArray = PackedStringArray()
## Game second each target was settled (landed), the route made.
var settled_at: Dictionary[StringName, int] = {}
var route_at: int = -1

var _next: int = 0
var _visiting: int = 0
var _visit_until: int = 0


func _init(simulation: Simulation) -> void:
	sim = simulation
	home = sim.viewed_id
	var bot := SliceBot.new(sim)
	bot.add({"at": HALL_AT, "build": &"town_hall", "near": bot.town() + Vector2i(2, 2)})
	bot.add({"at": STABLE_AT, "build": &"trading_post", "near": bot.town() + Vector2i(-2, 4)})
	bots[home] = bot
	bot_seconds[home] = 0


## Runs [param seconds] of game time.
func run(seconds: int, on_minute: Callable = Callable()) -> void:
	for second: int in seconds:
		var viewed := sim.viewed_id
		if bots.has(viewed):
			bots[viewed].act(bot_seconds[viewed])
			bot_seconds[viewed] += 1
		if second % 10 == 0:
			_world(second)
		for i: int in SimClock.TICKS_PER_SECOND:
			sim.step()
			for e: Dictionary in sim.events.drain():
				if bots.has(sim.viewed_id):
					bots[sim.viewed_id].note(e)
		if second % 60 == 59 and on_minute.is_valid():
			on_minute.call(second / 60 + 1)


func owned() -> int:
	var n := 0
	for id: int in sim.world.ids():
		if sim.world.owner_of(id) == ProvinceDef.OWNER_PLAYER:
			n += 1
	return n


## Every ten seconds: the expeditions, the visits and the route.
func _world(second: int) -> void:
	if _visiting != 0:
		if second >= _visit_until:
			sim.execute(EnterProvinceCommand.new(home))
			_visiting = 0
		return
	_route(second)
	if second < EXPEDITIONS_FROM or _next >= TARGETS.size():
		return
	var target := sim.world.id_of(TARGETS[_next])
	var waiting := sim.world.expedition_to(target)
	if waiting != null and waiting.state == Expedition.State.WAITING:
		if sim.execute(EnterProvinceCommand.new(target)) == &"":
			settled_at[TARGETS[_next]] = second
			bots[target] = SliceBot.new(sim)
			bot_seconds[target] = 0
			_visiting = target
			_visit_until = second + LOOK_SECONDS
			_next += 1
		return
	if waiting != null:
		return
	var p := sim.province_state(home)
	if p.departure == null:
		sim.execute(PrepareExpeditionCommand.new(home, false))
	elif p.departure.is_ready():
		var error := sim.execute(SendExpeditionCommand.new(home, target))
		if error != &"" and error != &"not_enough_gold" and not log.has(String(error)):
			log.append(String(error))


## Once the first new province is settled and the trading post stands: bread to it by its
## merchant wagon.
func _route(second: int) -> void:
	if route_at >= 0 or settled_at.is_empty():
		return
	var to := sim.world.id_of(TARGETS[0])
	var vehicles := CreateTradeRouteCommand.free_vehicles(sim, home, false)
	if vehicles.is_empty():
		return
	var lines: Array[Dictionary] = [TradeRoute.line(&"bread", TradeRoute.WAGON_LOAD, 20),
			TradeRoute.line(&"wood", 6, 30)]
	if sim.execute(CreateTradeRouteCommand.new(home, to, false, vehicles[0], lines)) == &"":
		route_at = second
