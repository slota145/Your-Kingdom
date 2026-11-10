class_name RulerExpansion
extends RefCounted
## How the AI rulers spread (ROADMAP M8 part 3, owner's survey 2026-11-10): expeditions of
## settlers to empty provinces (by land to a neighbour with a wagon, by sea with their cog),
## buying neutral settlements, and trade routes between their provinces. They use the
## player's rules (PrepareExpeditionCommand, SendExpeditionCommand, CreateTradeRouteCommand)
## and pay from their own treasuries. Whoever comes first takes a province or a settlement.

## Minutes before a ruler's first expedition and between two, by difficulty (easy, normal,
## hard): easy about 40% slower, hard about 30% faster.
const EXPEDITION_MINUTES: Array[float] = [17.0, 12.0, 8.5]
## People a province needs before settlers leave it.
const MIN_PEOPLE := 40
## How much a richer province weighs against distance when a target is chosen (parchment
## pixels per point of richness).
const RICH_BONUS := 120.0
## Seconds between two looks at trade (settlements, routes).
const TRADE_SECONDS := 60
## Gold a ruler keeps after paying for a settlement.
const GOLD_RESERVE := 150
## Minutes a demand must still have left for a ruler to start paying it.
const DEMAND_MINUTES_LEFT := 6.0
## A province of a ruler with fewer buildings than this gets bread and wood from a neighbour.
const YOUNG_BUILDINGS := 40
## A pioneer camp and a storage come with a ruler's expedition (it lands in the simplified
## mode, where nobody would carry the kit off the beach to the first sites).
const FOUNDED: Array[StringName] = [&"pioneer_camp", &"stockpile"]


## Once a second (Simulation._update_world).
static func update(sim: Simulation) -> void:
	var owners: Array[StringName] = []
	owners.assign(sim.world.rulers.keys())
	owners.sort()
	for owner: StringName in owners:
		var ruler := sim.world.rulers[owner]
		_expeditions(sim, ruler)
		if sim.clock.tick >= ruler.next_trade:
			ruler.next_trade = sim.clock.tick + SimClock.seconds_to_ticks(TRADE_SECONDS)
			_buy_settlement(sim, ruler)
			_supply_young(sim, ruler)


# --- Neutral settlements -----------------------------------------------------------------------

## A ruler buys a neutral settlement he can reach (owner's survey 2026-11-10: whoever comes
## first): when he can pay the gold and has the goods in a province by it, he pays and sends
## the goods by a one-off route (wagon to a neighbour, cog over the sea). One at a time.
static func _buy_settlement(sim: Simulation, ruler: RulerState) -> void:
	var owner := ruler.owner
	var buying := false
	for route: TradeRoute in sim.world.routes.values():
		if sim.world.owner_of(route.from) != owner:
			continue
		if sim.world.settlements.has(route.to):
			buying = true
		elif sim.world.owner_of(route.to) != owner:
			route.closing = true   # someone else bought it: the wagon comes home and stops
	if buying:
		return   # one at a time
	var ids: Array[int] = []
	ids.assign(sim.world.settlements.keys())
	ids.sort()
	for id: int in ids:
		var s := sim.world.settlements[id]
		if s.state != NeutralSettlement.State.ASKING or not sim.runtimes.has(id):
			continue
		if s.until - sim.clock.tick < SimClock.seconds_to_ticks(DEMAND_MINUTES_LEFT * 60.0):
			continue
		if not ruler.treasury.can_pay(s.gold_missing(owner) + GOLD_RESERVE):
			continue
		var lines := TradeRoutes.demand_lines(sim, id, owner)
		var source := _source_for(sim, owner, id, lines)
		if lines.is_empty() or not source.is_empty():
			var gold := s.gold_missing(owner)
			ruler.treasury.pay(gold)
			s.pay(gold, owner)
			if not lines.is_empty():
				# A route like the player's "Send goods": it runs until the demand is met (and
				# then keeps bringing the same goods to the town, now his).
				CreateTradeRouteCommand.create(sim, int(source["from"]), id, bool(source["sea"]),
						int(source["vehicle"]), lines)
			sim.events.emit(&"ruler_buys_settlement", {"owner": owner, "province": id})
			return


## A province of [param owner] that has all of [param lines] in store and a free vehicle to
## province [param to]: {from, sea, vehicle}, or {}.
static func _source_for(sim: Simulation, owner: StringName, to: int, lines: Array[Dictionary]) -> Dictionary:
	for id: int in Rulers.provinces_of(sim.world, owner):
		var p := sim.province_state(id)
		if p == null:
			continue
		var enough := true
		for line: Dictionary in lines:
			if p.stored(StringName(line["good"])) < int(line["amount"]):
				enough = false
		if not enough:
			continue
		for sea: bool in [false, true]:
			if CreateTradeRouteCommand.route_error(sim, id, to, sea) != &"":
				continue
			var vehicles := CreateTradeRouteCommand.free_vehicles(sim, id, sea)
			if not vehicles.is_empty():
				return {"from": id, "sea": sea, "vehicle": vehicles[0]}
	return {}


# --- Routes between his provinces --------------------------------------------------------------

## A young province of the ruler gets bread and wood from an older one by a route (as the
## automatic player does): a merchant wagon to a neighbour or the cog over the sea.
static func _supply_young(sim: Simulation, ruler: RulerState) -> void:
	var owned := Rulers.provinces_of(sim.world, ruler.owner)
	for young: int in owned:
		var y := sim.province_state(young)
		if y == null or y.buildings.all().size() >= YOUNG_BUILDINGS or not sim.world.routes_of(young).is_empty():
			continue
		for from: int in owned:
			if from == young:
				continue
			for sea: bool in [false, true]:
				if CreateTradeRouteCommand.route_error(sim, from, young, sea) != &"":
					continue
				var vehicles := CreateTradeRouteCommand.free_vehicles(sim, from, sea)
				if vehicles.is_empty():
					continue
				var load := TradeRoute.WAGON_LOAD
				var lines: Array[Dictionary] = [TradeRoute.line(&"bread", load / 2, 20),
						TradeRoute.line(&"wood", load / 2, 30)]
				CreateTradeRouteCommand.create(sim, from, young, sea, vehicles[0], lines)
				return


## A ruler's expedition landed in province [param id] ([param settled], before it is frozen):
## the landing is done at once, a pioneer camp and a storage stand by the kit.
static func found(sim: Simulation, id: int, settled: ProvinceSim) -> void:
	var beach := settled.landing.beach if settled.landing != null else settled.grid.size / 2
	if settled.landing != null:
		settled.landing.finish_at_once(settled)
	for building_id: StringName in FOUNDED:
		var def := sim.data.get_building(building_id)
		if NeutralTown.place(settled, def, beach + Vector2i(-3, -3)) == null:
			push_warning("ruler's province %d: no room for %s" % [id, building_id])


static func _expeditions(sim: Simulation, ruler: RulerState) -> void:
	var gathering := 0
	for id: int in Rulers.provinces_of(sim.world, ruler.owner):
		var home := sim.province_state(id)
		if home == null or home.departure == null:
			continue
		gathering += 1
		var departure := home.departure
		if departure.is_ready() and not departure.is_sent():
			var target := best_target(sim, ruler.owner, id, departure.by_sea)
			if target != 0 and SendExpeditionCommand.error_for(sim, id, target) == &"":
				SendExpeditionCommand.send(sim, id, target)
			elif target == 0:
				departure.disband(home, not sim.is_detailed(id))
				home.departure = null
	var tick := sim.clock.tick
	if gathering > 0 or tick < ruler.next_expedition:
		return
	var plan := _next_expedition(sim, ruler.owner)
	if plan.is_empty():
		ruler.saving_for = 0
		return
	if bool(plan["saving"]):
		ruler.saving_for = int(plan["from"])   # the kit is not there yet: save up for it
		return
	ruler.saving_for = 0
	PrepareExpeditionCommand.prepare(sim, int(plan["from"]), bool(plan["sea"]))
	ruler.next_expedition = tick + SimClock.seconds_to_ticks(
			EXPEDITION_MINUTES[RulerPlanner.difficulty(sim)] * 60.0)


## Where the next expedition of [param owner] leaves from and how: {from, sea, to}, or {}.
static func _next_expedition(sim: Simulation, owner: StringName) -> Dictionary:
	var best := {}
	var best_score := INF
	for id: int in Rulers.provinces_of(sim.world, owner):
		var home := sim.province_state(id)
		if home == null or RulerPlanner.residents(home) < MIN_PEOPLE:
			continue
		for sea: bool in [false, true]:
			var error := PrepareExpeditionCommand.error_for(sim, id, sea, owner)
			# Without the kit in store yet the province saves up for it.
			if error != &"" and error != &"not_enough_goods":
				continue
			var target := best_target(sim, owner, id, sea)
			if target == 0:
				continue
			var score := _score(sim, id, target)
			if score < best_score:
				best_score = score
				best = {"from": id, "sea": sea, "to": target, "saving": error != &""}
	return best


## The empty province an expedition of [param owner] from [param from] goes to (by land: a
## neighbour; by sea: any coast it can sail to): near and rich first; 0 when none.
static func best_target(sim: Simulation, owner: StringName, from: int, sea: bool) -> int:
	var world := sim.world
	var best := 0
	var best_score := INF
	for id: int in world.ids():
		if id == from or sim.runtimes.has(id) or world.is_claimed(id, owner) \
				or world.expedition_to(id, owner) != null:
			continue
		if world.camp != null and world.camp.province == id:
			continue
		if sim.data.get_map(world.get_province(id).map_id) == null:
			continue
		if sea and not world.sea_route(from, id, sim.data):
			continue
		if not sea and not world.are_neighbours(from, id, sim.data):
			continue
		if _targeted(sim, owner, id):
			continue
		var score := _score(sim, from, id)
		if score < best_score:
			best_score = score
			best = id
	return best


static func _score(sim: Simulation, from: int, to: int) -> float:
	var a := sim.world.def_of(from, sim.data)
	var b := sim.world.def_of(to, sim.data)
	if a == null or b == null:
		return INF
	return a.world_pos.distance_to(b.world_pos) - b.richness * RICH_BONUS


## Whether a departure of [param owner] already goes to [param id].
static func _targeted(sim: Simulation, owner: StringName, id: int) -> bool:
	for other: int in Rulers.provinces_of(sim.world, owner):
		var p := sim.province_state(other)
		if p != null and p.departure != null and p.departure.target == id:
			return true
	return false
