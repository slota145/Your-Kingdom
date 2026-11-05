class_name SimFixture
extends RefCounted
## Small helpers to build simulations for tests.

static var _registry: DataRegistry


## The real game data, loaded once per test run.
static func registry() -> DataRegistry:
	if _registry == null:
		_registry = DataRegistry.new()
		_registry.load_from("res://data")
	return _registry


static func make_sim(size: Vector2i = Vector2i(32, 32), seed_value: int = 1) -> Simulation:
	return Simulation.new(registry(), size, seed_value)


## Places a building directly and returns it; fails loudly when it does not fit.
static func place(sim: Simulation, def_id: StringName, origin: Vector2i) -> BuildingState:
	var command := PlaceBuildingCommand.new(def_id, origin, true)
	var error := sim.execute(command)
	assert(error == &"", "cannot place %s at %s: %s" % [def_id, origin, error])
	return sim.province.buildings.get_building(sim.ids.next_id - 1)


static func spawn(sim: Simulation, kind: StringName, tile: Vector2i) -> Agent:
	var error := sim.execute(SpawnAgentCommand.new(kind, tile))
	assert(error == &"", "cannot spawn %s at %s: %s" % [kind, tile, error])
	return sim.province.agents.get_agent(sim.ids.next_id - 1)


static func plant_trees(sim: Simulation, rect: Rect2i) -> void:
	place_nodes(sim, rect, &"tree")


## Resource nodes of [param node_id] on every tile of [param rect] (rocks block the way,
## trees do not since M4b-2).
static func place_nodes(sim: Simulation, rect: Rect2i, node_id: StringName) -> void:
	var node := registry().get_resource_node(node_id)
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			sim.province.resources.place(Vector2i(x, y), node)
			sim.province.refresh_tile(Vector2i(x, y))


## A woodcutter's hut with its worker, a stockpile and a small forest.
static func woodcutter_scene(sim: Simulation) -> Dictionary:
	var stock := place(sim, &"stockpile", Vector2i(4, 4))
	var hut := place(sim, &"woodcutter", Vector2i(12, 6))
	plant_trees(sim, Rect2i(16, 2, 4, 4))
	var worker := spawn(sim, &"woodcutter", hut.entrance_tile())
	assert(sim.execute(AssignWorkerCommand.new(worker.id, hut.id)) == &"")
	return {"stock": stock, "hut": hut, "worker": worker}


## Seconds of game time to ticks.
static func ticks(seconds: float) -> int:
	return roundi(seconds * SimClock.TICKS_PER_SECOND)


## A finished hut with residents (and a full pantry unless [param pantry] is false).
static func house(sim: Simulation, origin: Vector2i, residents: int = 4, pantry: bool = true) -> BuildingState:
	var hut := place(sim, &"hut", origin)
	hut.house.residents = residents
	if pantry:
		for good: StringName in hut.house_goods():
			hut.supply.add(good, hut.level_def().supply_units)
	return hut


## Town hall, a stockpile with [param wood] wood and [param bread] bread, and 2 full huts
## (8 residents = 4 workers: the builder and the porters of the town hall, plus one more).
static func village(sim: Simulation, wood: int = 40, bread: int = 20) -> Dictionary:
	var hall := place(sim, &"town_hall", Vector2i(2, 2))
	var stock := place(sim, &"stockpile", Vector2i(8, 2))
	stock.stock.add(&"wood", wood)
	stock.stock.add(&"bread", bread)
	var a := house(sim, Vector2i(2, 8))
	var b := house(sim, Vector2i(5, 8))
	return {"hall": hall, "stock": stock, "houses": [a, b]}


## Runs until [param condition] is true or [param seconds] pass. Returns whether it became true.
static func run_until(sim: Simulation, condition: Callable, seconds: float) -> bool:
	for i: int in ticks(seconds):
		sim.step()
		sim.events.drain()
		if condition.call():
			return true
	return false
