extends GdUnitTestSuite
## Fetch -> Work -> Produce -> Deliver on a test mill, and the failure paths of each step.

var _registry: DataRegistry


func before() -> void:
	_registry = DataRegistry.new()
	_registry.load_from("res://data")
	var fetch := FetchStepDef.new()
	fetch.good = &"grain"
	fetch.amount = 2
	var work := WorkStepDef.new()
	work.activity = &"grind"
	work.duration = 2.0
	var produce := ProduceStepDef.new()
	produce.output = &"flour"
	produce.amount = 1
	var recipe := RecipeDef.new()
	recipe.id = &"test_milling"
	recipe.steps = [fetch, work, produce, DeliverStepDef.new()]
	_registry.register(recipe)
	var mill := BuildingDef.new()
	mill.id = &"test_mill"
	mill.footprint = Vector2i(2, 2)
	mill.entrance = Vector2i(1, 1)
	mill.worker_kinds = [&"miller"]
	mill.recipe = recipe
	_registry.register(mill)


func _mill_scene() -> Dictionary:
	var sim := Simulation.new(_registry, Vector2i(32, 32))
	var stock := SimFixture.place(sim, &"stockpile", Vector2i(2, 2))
	var mill := SimFixture.place(sim, &"test_mill", Vector2i(14, 3))
	var miller := SimFixture.spawn(sim, &"miller", mill.entrance_tile())
	# UI-2 part 2: the worker leaves what he made on his yard, a porter takes it to the storage.
	SimFixture.spawn(sim, &"porter", Vector2i(8, 8))
	sim.execute(AssignWorkerCommand.new(miller.id, mill.id))
	return {"sim": sim, "stock": stock, "mill": mill, "miller": miller}


func test_miller_turns_grain_into_flour() -> void:
	var scene := _mill_scene()
	var sim: Simulation = scene["sim"]
	var stock: Stockpile = (scene["stock"] as BuildingState).stock
	stock.add(&"grain", 4)
	sim.run_ticks(SimFixture.ticks(90))
	assert_int(stock.total(&"grain")).is_equal(0)
	assert_int(stock.total(&"flour")).is_equal(2)
	assert_array(Array(sim.province.dangling_holds())).is_empty()


func test_fetch_without_source_fails_and_retries_later() -> void:
	var scene := _mill_scene()
	var sim: Simulation = scene["sim"]
	var miller: Agent = scene["miller"]
	sim.run_ticks(2)
	assert_object(miller.task).is_null()
	assert_int(miller.cooldown).is_greater(0)
	(scene["stock"] as BuildingState).stock.add(&"grain", 2)
	sim.run_ticks(TaskRunner.RETRY_TICKS + 5)
	assert_object(miller.task).is_not_null()
	assert_int((scene["stock"] as BuildingState).stock.available(&"grain")).is_equal(0)


func test_source_demolished_while_walking_releases_everything() -> void:
	var scene := _mill_scene()
	var sim: Simulation = scene["sim"]
	var stock: BuildingState = scene["stock"]
	stock.stock.add(&"grain", 2)
	sim.run_ticks(20)
	assert_int(stock.stock.reservation_count()).is_equal(1)
	sim.execute(DemolishCommand.new(stock.id))
	sim.run_ticks(3)
	assert_int(sim.province.goods_total(&"grain")).is_equal(2)
	assert_int(sim.province.piles.size()).is_greater(0)
	assert_array(Array(sim.province.dangling_holds())).is_empty()


## M4b-3: with nothing to work on (no tree in reach) the worker waits longer before looking
## again than after a failure that may clear up soon.
func test_nothing_to_work_on_waits_longer() -> void:
	var sim := SimFixture.make_sim()
	SimFixture.place(sim, &"stockpile", Vector2i(4, 4))
	var hut := SimFixture.place(sim, &"woodcutter", Vector2i(12, 6))
	var worker := SimFixture.spawn(sim, &"woodcutter", hut.entrance_tile())
	assert_str(String(sim.execute(AssignWorkerCommand.new(worker.id, hut.id)))).is_empty()
	sim.run_ticks(2)
	assert_object(worker.task).is_null()
	assert_str(String(worker.last_fail)).is_equal("no_resource")
	assert_int(worker.cooldown).is_greater(TaskRunner.RETRY_TICKS)
	SimFixture.plant_trees(sim, Rect2i(16, 2, 2, 2))
	sim.run_ticks(TaskRunner.IDLE_RETRY_TICKS + 2)
	assert_object(worker.task).is_not_null()
