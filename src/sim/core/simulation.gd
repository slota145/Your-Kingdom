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
	var sim := Simulation.new(registry, map.size(), seed_value)
	sim.world = world
	sim.runtimes.clear()
	sim.runtimes[start] = sim.province
	sim.viewed_id = start
	sim.world.get_province(start).owner = ProvinceDef.OWNER_PLAYER
	problems.append_array(sim.province.load_map(map))
	sim.events.drain()
	return sim


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
	# Each simplified province updates once a second, in the tick of its id within the second
	# (provinces do not all update in the same tick).
	var slot := clock.tick % ProvinceAbstract.STEP_TICKS
	for id: int in runtimes:
		if id % ProvinceAbstract.STEP_TICKS == slot:
			var abstract := runtimes[id] as ProvinceAbstract
			if abstract != null:
				abstract.step(clock.tick - slot)
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
	var opened := ProvinceSim.new(data, map.size(), SimEvents.new(), ids)
	opened.treasury = Treasury.new()
	opened.tick = clock.tick
	var problems := opened.load_map(map)
	opened.treasury = treasury
	runtimes[id] = ProvinceAbstract.freeze(opened, clock.tick)
	if world.get_province(id) == null:
		world.provinces[id] = WorldProvince.new(id, &"", map.id, owner)
	world.get_province(id).owner = owner
	return problems


## Makes [param id] the viewed province (EnterProvinceCommand): the province viewed so far
## goes to the simplified mode, [param id] comes back in detail (ARCHITECTURE §7.2).
func view_province(id: int) -> void:
	if id == viewed_id or not runtimes.has(id):
		return
	runtimes[viewed_id] = ProvinceAbstract.freeze(province, clock.tick)
	var abstract := runtimes[id] as ProvinceAbstract
	province = abstract.thaw(clock.tick, events)
	runtimes[id] = province
	viewed_id = id
	events.emit(&"province_entered", {"province": id})


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
	return sim
