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
	var command := PlaceBuildingCommand.new(def_id, origin)
	var error := sim.execute(command)
	assert(error == &"", "cannot place %s at %s: %s" % [def_id, origin, error])
	return sim.province.buildings.get_building(sim.ids.next_id - 1)


static func spawn(sim: Simulation, kind: StringName, tile: Vector2i) -> Agent:
	var error := sim.execute(SpawnAgentCommand.new(kind, tile))
	assert(error == &"", "cannot spawn %s at %s: %s" % [kind, tile, error])
	return sim.province.agents.get_agent(sim.ids.next_id - 1)


static func plant_trees(sim: Simulation, rect: Rect2i) -> void:
	var tree := registry().get_resource_node(&"tree")
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			sim.province.resources.place(Vector2i(x, y), tree)
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
