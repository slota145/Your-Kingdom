class_name Simulation
extends RefCounted
## The whole game state and its fixed-step update (ARCHITECTURE §4). No nodes, no autoloads:
## definitions come in through the DataRegistry, changes only through commands.
##
## The world (M6) holds provinces; the one the player looks at runs in detail (ProvinceSim,
## [member province]), every other settled province in the simplified mode (ProvinceAbstract,
## ARCHITECTURE §7). A game on a single map is a world with one province.

var data: DataRegistry
var clock: SimClock = SimClock.new()
var rng: SimRng
var ids: EntityIds = EntityIds.new()
var events: SimEvents = SimEvents.new()
## Gold is global (GDD §3.5); every province shares this object.
var treasury: Treasury = Treasury.new()
var world: WorldSim
## Settled provinces by world province id: ProvinceSim (the viewed one) or ProvinceAbstract.
## Empty provinces have no runtime.
var runtimes: Dictionary[int, RefCounted] = {}
## The province the player looks at (always in detail).
var viewed_id: int = WorldSim.FIRST_ID
## The viewed province: runtimes[viewed_id].
var province: ProvinceSim

var _commands: Array[Command] = []
## Bandit raids on the viewed province (M7 part 2): on in a game the player plays (the game
## scene turns them on), off in tests and benchmarks. Not saved.
var raids_enabled: bool = false


func _init(registry: DataRegistry, map_size: Vector2i = Vector2i(64, 64), seed_value: int = 1) -> void:
	data = registry
	rng = SimRng.new(seed_value)
	world = WorldSim.single(&"")
	province = ProvinceSim.new(registry, map_size, events, ids)
	province.treasury = treasury
	runtimes[WorldSim.FIRST_ID] = province


## A new game on a hand-made map (ROADMAP M3): terrain, trees and the start layout.
## Problems with the map (unknown colours, start buildings that do not fit) go to [param problems].
static func from_map(registry: DataRegistry, map: MapDef, seed_value: int = 1,
		problems: PackedStringArray = PackedStringArray()) -> Simulation:
	var sim := Simulation.new(registry, map.size(), seed_value)
	sim.world = WorldSim.single(map.id)
	problems.append_array(sim.province.load_map(map))
	sim.province.start_grace(sim.clock.tick)
	sim.events.drain()
	return sim


## A new game in a world (ROADMAP M6): the player starts in the world's start province (its
## map, usually a landing from a ship); every other province waits empty or neutral.
static func from_world(registry: DataRegistry, def: WorldDef, seed_value: int = 1,
		problems: PackedStringArray = PackedStringArray()) -> Simulation:
	var world := WorldSim.from_def(def, registry)
	var start := world.id_of(def.start_province)
	var map := registry.get_map(world.get_province(start).map_id) if start != 0 else null
	if map == null:
		problems.append("world %s: no start province map" % def.id)
		return null
	var pdef := world.def_of(start, registry)
	var sim := Simulation.new(registry, map.size_for(pdef.mirrored), seed_value)
	sim.world = world
	sim.runtimes.clear()
	sim.runtimes[start] = sim.province
	sim.viewed_id = start
	sim.world.get_province(start).owner = ProvinceDef.OWNER_PLAYER
	problems.append_array(sim.province.load_map(map, pdef.mirrored, pdef.richness, false, pdef.rare_resource))
	sim.province.start_grace(sim.clock.tick)
	problems.append_array(sim._open_neutral_towns())
	sim.events.drain()
	return sim


## A sandbox game (ROADMAP M8 part 1): the world of [param settings] (generated from its number,
## or a hand-made one), the player's landing, the neutral settlements and the AI rulers' towns.
static func from_settings(registry: DataRegistry, settings: GameSettings, seed_value: int = 1,
		problems: PackedStringArray = PackedStringArray()) -> Simulation:
	var def := WorldGenerator.generate(registry, settings) if settings.is_generated() \
			else registry.get_world(settings.world_def)
	if def == null:
		problems.append("no world %s" % settings.world_def)
		return null
	var sim := from_world(registry, def, seed_value, problems)
	if sim == null:
		return null
	sim.world.settings = settings
	problems.append_array(sim._open_ruler_towns())
	sim.events.drain()
	return sim


## Every AI ruler's province gets its town (M8 part 1: it waits there; part 3: it grows).
func _open_ruler_towns() -> PackedStringArray:
	var problems := PackedStringArray()
	for id: int in world.ids():
		if not Rulers.is_ruler(world.owner_of(id)) or runtimes.has(id):
			continue
		problems.append_array(NeutralTown.build(self, id))
		var town := province_state(id)
		if town != null:
			town.home_faction = faction_of(id)
	return problems


## Queues a command for the start of the next tick.
func submit(command: Command) -> void:
	_commands.append(command)


## Validates and applies a command right away (setup code and tests). Returns the reason
## it was rejected, or &"".
func execute(command: Command) -> StringName:
	var error := command.validate(self)
	if error == &"":
		command.apply(self)
	else:
		events.emit(&"command_rejected", {"command": command.get_name(), "reason": error})
	return error


## Runs one tick in the fixed system order (ARCHITECTURE §4.2): commands, the viewed province,
## then (once a second) the provinces in the simplified mode.
func step() -> void:
	events.tick = clock.tick
	var commands := _commands
	_commands = []
	for command: Command in commands:
		execute(command)
	province.tick = clock.tick
	province.step()
	if not province.marched.is_empty():
		Armies.absorb(self)
	if raids_enabled and clock.tick % SimClock.TICKS_PER_SECOND == 0 \
			and world.owner_of(viewed_id) == ProvinceDef.OWNER_PLAYER:
		Raids.update(province, rng.stream(&"raids"), world.is_single())
	# Each simplified province updates once a second, in the tick of its id within the second
	# (provinces do not all update in the same tick).
	var slot := clock.tick % ProvinceAbstract.STEP_TICKS
	for id: int in runtimes:
		if id % ProvinceAbstract.STEP_TICKS == slot:
			var abstract := runtimes[id] as ProvinceAbstract
			# A neutral town waits as it is until it joins the kingdom (M6 part 3).
			if abstract != null and world.owner_of(id) == ProvinceDef.OWNER_PLAYER:
				abstract.step(clock.tick - slot)
	if slot == 0:
		_update_world()
	clock.tick += 1


func run_ticks(count: int) -> void:
	for i: int in count:
		step()


## Settled provinces' ids, sorted.
func runtime_ids() -> Array[int]:
	var result: Array[int] = []
	result.assign(runtimes.keys())
	result.sort()
	return result


## The province [param id] in detail if it is viewed, else its frozen detail kept by the
## simplified mode (read only: buildings, stores, map); null for an empty province.
func province_state(id: int) -> ProvinceSim:
	var runtime: RefCounted = runtimes.get(id)
	if runtime is ProvinceSim:
		return runtime as ProvinceSim
	if runtime is ProvinceAbstract:
		return (runtime as ProvinceAbstract).detail
	return null


func is_detailed(id: int) -> bool:
	return runtimes.get(id) is ProvinceSim


## Settles province [param id] on [param map] with the map's start layout, in the simplified
## mode (nobody looks at it yet). Gold stays the kingdom's (the map's start gold is not
## added). Returns problems with the map.
func open_province(id: int, map: MapDef, owner: StringName = ProvinceDef.OWNER_PLAYER) -> PackedStringArray:
	var pdef := world.def_of(id, data)
	var mirrored := pdef.mirrored if pdef != null else false
	var opened := ProvinceSim.new(data, map.size_for(mirrored), SimEvents.new(), ids)
	opened.treasury = Treasury.new()
	opened.tick = clock.tick
	var problems := opened.load_map(map, mirrored, pdef.richness if pdef != null else 2, false,
			pdef.rare_resource if pdef != null else &"")
	opened.treasury = treasury
	runtimes[id] = ProvinceAbstract.freeze(opened, clock.tick)
	if world.get_province(id) == null:
		world.provinces[id] = WorldProvince.new(id, &"", map.id, owner)
	world.get_province(id).owner = owner
	return problems


## Once a second: expeditions set out, arrive, land and their cogs come home (M6 part 2);
## trade routes run (M6 part 3).
func _update_world() -> void:
	for id: int in runtime_ids():
		var p := province_state(id)
		if p.departure != null and p.departure.is_gone():
			_set_out(id, p)
	var ids_now: Array[int] = []
	ids_now.assign(world.expeditions.keys())
	ids_now.sort()
	for id: int in ids_now:
		var e := world.expeditions[id]
		match e.state:
			Expedition.State.TRAVELLING:
				if clock.tick >= e.arrive_at:
					e.state = Expedition.State.WAITING
					events.emit(&"expedition_arrived", {"expedition": e.id, "province": e.to})
			Expedition.State.LANDED:
				var there := province_state(e.to)
				if there == null or there.landing == null or there.landing.expedition != e.id \
						or there.landing.state == Landing.State.DONE:
					_landed(e)
			Expedition.State.RETURNING:
				if clock.tick >= e.arrive_at:
					world.expeditions.erase(id)
	TradeRoutes.update(self)
	_update_settlements()
	Armies.update(self)
	Victory.update(self)


## Every neutral province without a town gets one, and its first demand (a new game; a save
## from before M6 part 3 on its first second). Returns problems with the maps.
func _open_neutral_towns() -> PackedStringArray:
	var problems := PackedStringArray()
	for id: int in world.ids():
		if world.owner_of(id) != ProvinceDef.OWNER_NEUTRAL or runtimes.has(id):
			continue
		var def := world.def_of(id, data)
		if def == null or def.town_buildings.is_empty():
			continue
		problems.append_array(NeutralTown.build(self, id))
		world.settlements[id] = NeutralSettlement.first(id, def, clock.tick)
	problems.append_array(_fortify_towns())
	return problems


## Neutral towns get their walls and guards (M7 part 3; a save from before it too).
func _fortify_towns() -> PackedStringArray:
	var problems := PackedStringArray()
	var keys: Array[int] = []
	keys.assign(world.settlements.keys())
	keys.sort()
	for id: int in keys:
		if not world.settlements[id].fortified and runtimes.has(id):
			problems.append_array(NeutralTown.fortify(self, id))
			var town := province_state(id)
			if town != null:
				town.home_faction = CombatState.TOWN
	return problems


## Once a second: a neutral settlement whose demand is met joins the kingdom; one whose time
## ran out rests and asks again, dearer (M6 part 3).
func _update_settlements() -> void:
	if clock.tick % (ProvinceAbstract.STEP_TICKS * 10) == 0:
		_open_neutral_towns()
	var ids_now: Array[int] = []
	ids_now.assign(world.settlements.keys())
	ids_now.sort()
	for id: int in ids_now:
		var s := world.settlements[id]
		if world.owner_of(id) != ProvinceDef.OWNER_NEUTRAL:
			world.settlements.erase(id)
			continue
		match s.state:
			NeutralSettlement.State.ASKING:
				if s.is_met():
					world.settlements.erase(id)
					world.get_province(id).owner = ProvinceDef.OWNER_PLAYER
					events.emit(&"settlement_joined", {"province": id})
				elif clock.tick >= s.until:
					s.state = NeutralSettlement.State.RESTING
					s.round += 1
					s.until = clock.tick + SimClock.seconds_to_ticks(NeutralSettlement.REST_MINUTES * 60.0)
					events.emit(&"settlement_refused", {"province": id})
			NeutralSettlement.State.RESTING:
				if clock.tick >= s.until:
					s.ask(world.def_of(id, data), clock.tick)
					events.emit(&"settlement_asks", {"province": id})


## The expedition of province [param id] has left its map: it is on the world map now.
func _set_out(id: int, p: ProvinceSim) -> void:
	var d := p.departure
	var e := Expedition.new()
	e.id = d.id
	e.from = id
	e.to = d.target
	e.by_sea = d.by_sea
	e.ship_id = d.ship_id
	e.settlers = Departure.SETTLERS.duplicate()
	e.kit = d.kit.duplicate()
	e.depart_at = clock.tick
	e.arrive_at = clock.tick + SimClock.seconds_to_ticks(maxf(world.travel_seconds(id, e.to, e.by_sea, data), 0.0))
	world.expeditions[e.id] = e
	p.departure = null
	events.emit(&"expedition_departed", {"expedition": e.id, "province": e.to})


## The settlers are ashore: a cog sails home (as long as it took to come), a wagon stays.
func _landed(e: Expedition) -> void:
	if not e.by_sea:
		world.expeditions.erase(e.id)
		return
	e.state = Expedition.State.RETURNING
	e.depart_at = clock.tick
	e.arrive_at = clock.tick + SimClock.seconds_to_ticks(maxf(world.travel_seconds(e.from, e.to, true, data), 0.0))
	var home := province_state(e.from)
	var cog := home.ships.get(e.ship_id) as ShipUnit if home != null else null
	if cog != null and cog.voyage != null and cog.voyage.expedition == e.id:
		cog.voyage.back_at = e.arrive_at


## The province an expedition waits at becomes the player's: its map (the template's variant)
## without the start layout, and the landing of the expedition (ROADMAP M6 part 2).
func _settle(e: Expedition) -> ProvinceSim:
	var place := world.get_province(e.to)
	var def := world.def_of(e.to, data)
	var map := data.get_map(place.map_id)
	var mirrored := def.mirrored if def != null else false
	var settled := ProvinceSim.new(data, map.size_for(mirrored), events, ids)
	settled.treasury = treasury
	settled.tick = clock.tick
	settled.load_map(map, mirrored, def.richness if def != null else 2, true,
			def.rare_resource if def != null else &"")
	if e.by_sea and map.landing_tile != Agent.NO_TILE:
		settled.landing = Landing.arrive_by_sea(settled, map, mirrored, e.settlers, e.kit, e.id)
	else:
		settled.landing = Landing.arrive_by_land(settled, e.settlers, e.kit, e.id)
	settled.start_grace(clock.tick)
	place.owner = ProvinceDef.OWNER_PLAYER
	e.state = Expedition.State.LANDED
	events.emit(&"province_settled", {"province": e.to, "expedition": e.id})
	return settled


## Makes [param id] the viewed province (EnterProvinceCommand): the province viewed so far
## goes to the simplified mode, [param id] comes back in detail (ARCHITECTURE §7.2).
func view_province(id: int) -> void:
	if id == viewed_id:
		return
	var waiting := world.expedition_to(id)
	if not runtimes.has(id) and (waiting == null or waiting.state != Expedition.State.WAITING):
		return
	Armies.fold(self)
	runtimes[viewed_id] = ProvinceAbstract.freeze(province, clock.tick)
	if runtimes.has(id):
		province = (runtimes[id] as ProvinceAbstract).thaw(clock.tick, events)
	else:
		province = _settle(waiting)
	runtimes[id] = province
	viewed_id = id
	province.home_faction = faction_of(id)
	if world.owner_of(id) == ProvinceDef.OWNER_NEUTRAL:
		Armies.spawn_guards(self, id)
	events.emit(&"province_entered", {"province": id})


## The side whose walls the province's are (M7 part 3): the player's, or a neutral town's.
func faction_of(id: int) -> int:
	var owner := world.owner_of(id)
	return CombatState.TOWN if owner == ProvinceDef.OWNER_NEUTRAL or Rulers.is_ruler(owner) else CombatState.PLAYER


func to_dict() -> Dictionary:
	var list: Array = []
	for id: int in runtime_ids():
		var runtime: RefCounted = runtimes[id]
		if runtime is ProvinceSim:
			list.append({"id": id, "mode": "detail", "state": (runtime as ProvinceSim).to_dict()})
		else:
			list.append({"id": id, "mode": "abstract",
					"state": (runtime as ProvinceAbstract).to_dict()})
	return {
		"tick": clock.tick,
		"next_id": ids.next_id,
		"rng": rng.to_dict(),
		"treasury": treasury.to_dict(),
		"world": world.to_dict(),
		"viewed": viewed_id,
		"provinces": list,
	}


## Restores a saved state. Commands queued but not yet applied are not part of a save.
static func from_dict(d: Dictionary, registry: DataRegistry) -> Simulation:
	var sim := Simulation.new(registry, Vector2i.ONE)
	# A generated world is made again from its number (M8): its provinces are in no file.
	var world_d: Dictionary = d.get("world", {})
	if world_d.has("settings"):
		var settings := GameSettings.from_dict(world_d["settings"])
		if settings.is_generated():
			WorldGenerator.generate(registry, settings)
	sim.clock.tick = int(d["tick"])
	sim.ids.next_id = int(d["next_id"])
	sim.rng = SimRng.from_dict(d["rng"])
	sim.treasury = Treasury.from_dict(d.get("treasury", {}))
	sim.world = WorldSim.from_dict(d.get("world", {}))
	sim.viewed_id = int(d.get("viewed", WorldSim.FIRST_ID))
	sim.runtimes.clear()
	for entry: Variant in d.get("provinces", []):
		var e := entry as Dictionary
		var id := int(e["id"])
		if String(e.get("mode", "detail")) == "detail":
			var detailed := ProvinceSim.from_dict(e["state"], registry, sim.events, sim.ids)
			detailed.treasury = sim.treasury
			detailed.tick = sim.clock.tick
			sim.runtimes[id] = detailed
		else:
			sim.runtimes[id] = ProvinceAbstract.from_dict(e["state"], registry, sim.ids, sim.treasury)
	sim.province = sim.runtimes.get(sim.viewed_id) as ProvinceSim
	for id: int in sim.runtimes:
		var state := sim.province_state(id)
		if state != null:
			state.home_faction = sim.faction_of(id)
	return sim
