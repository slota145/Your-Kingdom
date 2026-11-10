class_name Invasion
extends RefCounted
## The Invasion from the sea (ROADMAP M8 part 5, owner's survey 2026-11-10): the first wave of
## raiders comes in the 20th minute, then one every 5 minutes, eight in all, each stronger.
## A wave is a fleet of war cogs that sails in from the edge of the world map to a coastal town
## of the player (it can be caught at sea by his warships), puts its men ashore and storms the
## town: live in the viewed province (with the warning a minute before), at once elsewhere
## (RulerWar.arrive and assault, as a ruler's army). A wave that wins holds the town (the
## raiders, Rulers.RAIDERS: it stands, it does not grow; the player can take it back as a
## ruler's town). Raiders beaten or left in the field flee to their ships (they are gone); the
## empty fleets sail back over the horizon. The player wins by holding out
## GameSettings.SURVIVE_MINUTES (Victory). Static helpers like RulerWar; the state is
## [InvasionState] in WorldSim.invasion.

const FIRST_MINUTES := 20.0
const GAP_MINUTES := 5.0
## Men of each wave (about 30% more each time: 6 to 40, owner's survey).
const WAVE_MEN: Array[int] = [6, 8, 11, 14, 18, 23, 30, 40]
## The units of a wave, in turn (later waves take more kinds).
const MIX: Array[Array] = [
	[&"spearman", &"archer", &"spearman"],
	[&"spearman", &"archer", &"spearman"],
	[&"spearman", &"archer", &"swordsman"],
	[&"spearman", &"archer", &"swordsman", &"crossbowman"],
	[&"spearman", &"archer", &"swordsman", &"crossbowman"],
	[&"spearman", &"crossbowman", &"swordsman", &"halberdier"],
	[&"swordsman", &"crossbowman", &"halberdier", &"spearman", &"man_at_arms"],
	[&"swordsman", &"crossbowman", &"halberdier", &"man_at_arms", &"spearman"],
]
## From this wave on a ram comes along (taran, owner's survey).
const RAM_FROM := 5
## The war ship of the raiders and the men it carries.
const SHIP := &"warship"
## Seconds a wave waits when the player has no coastal town to attack (an expedition at sea).
const RETRY_SECONDS := 60.0
## The 6 soldiers the player's ship brings (owner's survey 2026-11-10).
const START_TROOPS: Dictionary[StringName, int] = {&"spearman": 4, &"archer": 2}


## A new Invasion game: the clock of the waves, the raiders' treasury (for the towns they take),
## and the player's 6 soldiers standing by his landing.
static func start(sim: Simulation) -> void:
	var state := InvasionState.new()
	state.started = sim.clock.tick
	state.next_wave = sim.clock.tick + SimClock.seconds_to_ticks(FIRST_MINUTES * 60.0)
	sim.world.invasion = state
	ensure_raiders(sim)
	var army := Army.new()
	army.id = sim.ids.take()
	army.owner = ProvinceDef.OWNER_PLAYER
	army.state = Army.State.IDLE
	army.at = sim.viewed_id
	army.home = sim.viewed_id
	army.pos = ArmyOrders.stand_point(sim, sim.viewed_id)
	for unit: StringName in START_TROOPS:
		army.add(unit, START_TROOPS[unit])
	army.food = army.food_cap()
	sim.world.armies[army.id] = army


static func ensure_raiders(sim: Simulation) -> void:
	if not sim.world.rulers.has(Rulers.RAIDERS):
		sim.world.rulers[Rulers.RAIDERS] = RulerState.create(Rulers.RAIDERS, 0, sim.clock.tick)


## Once a second (Simulation._update_world).
static func update(sim: Simulation) -> void:
	var state := sim.world.invasion
	if state == null or sim.world.result != &"":
		return
	_tidy(sim)
	if state.wave >= WAVE_MEN.size() or sim.clock.tick < state.next_wave:
		return
	if launch(sim, state.wave) != null:
		state.wave += 1
		state.next_wave = sim.clock.tick + SimClock.seconds_to_ticks(GAP_MINUTES * 60.0)
	else:
		state.next_wave = sim.clock.tick + SimClock.seconds_to_ticks(RETRY_SECONDS)


## The units of wave [param wave] (0-based).
static func units_of(wave: int) -> Dictionary[StringName, int]:
	var k := clampi(wave, 0, WAVE_MEN.size() - 1)
	var mix: Array = MIX[k]
	var units: Dictionary[StringName, int] = {}
	for i: int in WAVE_MEN[k]:
		var unit: StringName = mix[i % mix.size()]
		units[unit] = units.get(unit, 0) + 1
	if wave >= RAM_FROM:
		units[&"ram"] = 1
	return units


## The coastal towns of the player a wave may go for, sorted: settled (the landing done), with a
## town hall or not (without one, the town is fought for at once: RulerWar.assault).
static func targets(sim: Simulation) -> Array[int]:
	var result: Array[int] = []
	for id: int in sim.world.ids():
		if sim.world.owner_of(id) != ProvinceDef.OWNER_PLAYER:
			continue
		var def := sim.world.def_of(id, sim.data)
		var town := sim.province_state(id)
		if def == null or not def.coastal or town == null or town.buildings.all().is_empty():
			continue
		if town.landing == null or town.landing.state == Landing.State.DONE:
			result.append(id)
	return result


## Sends wave [param wave] at a coastal town of the player (in turn, when he has several); the
## fleet sets out from the edge of the world map nearest that town. Returns it, or null.
static func launch(sim: Simulation, wave: int) -> Army:
	var towns := targets(sim)
	if towns.is_empty():
		return null
	ensure_raiders(sim)
	for k: int in towns.size():
		var to := towns[(wave + k) % towns.size()]
		var fleet := _fleet(sim, wave, to)
		if fleet != null:
			sim.events.emit(&"invasion_wave", {"province": to, "wave": wave + 1, "waves": WAVE_MEN.size(),
					"men": fleet.men(), "army": fleet.id, "seconds": ArmyOrders.seconds_left(sim, fleet)})
			return fleet
	return null


static func _fleet(sim: Simulation, wave: int, to: int) -> Army:
	var n := ArmyOrders.nav(sim)
	var def := sim.world.def_of(to, sim.data)
	var world_def := sim.data.get_world(sim.world.world_id)
	if n == null or def == null or world_def == null:
		return null
	var ship := sim.data.get_ship(SHIP)
	var army := Army.new()
	army.owner = Rulers.RAIDERS
	army.state = Army.State.IDLE
	army.by_sea = true
	army.units = units_of(wave)
	var ships := maxi(ceili(float(army.men()) / maxi(ship.troops if ship != null else 30, 1)), 1)
	army.fleet[SHIP] = ships
	army.ships = ships
	army.food = army.food_cap()
	# The edge points nearest the town first (the fleet comes in over the horizon).
	var size := world_def.size
	var p := def.world_pos
	var edges: Array[Vector2] = [Vector2(4, p.y), Vector2(size.x - 4, p.y), Vector2(p.x, 4), Vector2(p.x, size.y - 4)]
	edges.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_to(p) < b.distance_to(p))
	for edge: Vector2 in edges:
		var start := n.nearest(edge, true)
		if start == Vector2.INF:
			continue
		army.pos = start
		var way := ArmyOrders.plan(sim, army, to, Vector2.INF)
		if way["error"] != &"":
			continue
		army.id = sim.ids.take()
		sim.world.armies[army.id] = army
		ArmyOrders.follow(sim, army, way, to)
		return army
	return null


## The raiders' ships whose men are ashore sail away; raiders standing about in the field (beaten,
## or the town they came for gone) flee to them; those at a town they hold stay there.
static func _tidy(sim: Simulation) -> void:
	var keys: Array[int] = []
	keys.assign(sim.world.armies.keys())
	keys.sort()
	for key: int in keys:
		var army := sim.world.armies[key]
		if army.owner != Rulers.RAIDERS or army.state != Army.State.IDLE:
			continue
		if army.is_fleet():
			if army.is_empty():
				sim.world.armies.erase(key)
			elif army.target == 0 and army.path.is_empty():
				sim.world.armies.erase(key)   # (nowhere to land: back over the horizon)
			continue
		if sim.world.owner_of(army.at) == Rulers.RAIDERS:
			Armies.join_barracks(sim, army)
			continue
		sim.events.emit(&"raiders_fled", {"army": army.id, "province": army.at})
		sim.world.armies.erase(key)


## Seconds until the next wave sets out (-1: all are on their way).
static func seconds_to_next(sim: Simulation) -> int:
	var state := sim.world.invasion
	if state == null or state.wave >= WAVE_MEN.size():
		return -1
	return maxi(state.next_wave - sim.clock.tick, 0) / SimClock.TICKS_PER_SECOND
