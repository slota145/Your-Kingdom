extends GdUnitTestSuite
## Production yard (ROADMAP M4b-2, UI-2 part 2): a worker always puts his output on the stack by
## his building, porters bring it to a storage; when the stack is full he carries it to a storage
## himself, and with every storage full too he waits. Anybody may take from it. Nothing of
## production lies on the ground.


## Fills every slot of [param stock] with stone, so nothing else fits.
func _fill(stock: BuildingState) -> void:
	stock.stock.add(&"stone", stock.stock.slot_count() * stock.stock.stack_size(&"stone"))


func test_workshop_gets_a_yard_of_half_a_stack() -> void:
	var sim := SimFixture.make_sim()
	var scene := SimFixture.woodcutter_scene(sim)
	var hut: BuildingState = scene["hut"]
	assert_object(hut.yard).is_not_null()
	assert_int(hut.yard.slot_count()).is_equal(1)
	assert_int(hut.yard.stack_size(&"wood")).is_equal(10)
	var stock: BuildingState = scene["stock"]
	assert_object(stock.yard).is_null()
	assert_object(SimFixture.place(sim, &"well", Vector2i(20, 20)).yard).is_null()
	assert_object(SimFixture.place(sim, &"forester", Vector2i(24, 20)).yard).is_null()


func test_full_storages_fill_the_yard_then_the_worker_waits() -> void:
	var sim := SimFixture.make_sim()
	var scene := SimFixture.woodcutter_scene(sim)
	var hut: BuildingState = scene["hut"]
	var worker: Agent = scene["worker"]
	_fill(scene["stock"])
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return hut.yard.total(&"wood") == 10, 600)).is_true()
	# The worker then waits with the next log (or before his next cycle); nothing on the ground.
	sim.run_ticks(SimFixture.ticks(120))
	assert_int(hut.yard.total(&"wood")).is_equal(10)
	assert_int(sim.province.piles.size()).is_equal(0)
	assert_int(sim.province.goods_total(&"wood")).is_less_equal(11)
	var waiting := worker.task != null and worker.task.bb.has("_yard_full") \
			or worker.last_fail == &"yard_full"
	assert_bool(waiting).is_true()
	assert_array(Array(sim.province.dangling_holds())).is_empty()


func test_porters_bring_the_yard_to_a_storage_with_room() -> void:
	var sim := SimFixture.make_sim()
	var scene := SimFixture.woodcutter_scene(sim)
	var hut: BuildingState = scene["hut"]
	var stock: BuildingState = scene["stock"]
	_fill(stock)
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return hut.yard.total(&"wood") >= 4, 600)).is_true()
	stock.stock.remove(&"stone", 100)
	var porter := SimFixture.spawn(sim, &"porter", stock.entrance_tile())
	assert_str(String(sim.execute(AssignWorkerCommand.new(porter.id, stock.id)))).is_equal("")
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return hut.yard.total(&"wood") == 0 and stock.stock.total(&"wood") >= 4, 300)).is_true()
	assert_int(sim.province.piles.size()).is_equal(0)


func test_anybody_may_take_from_a_yard() -> void:
	var sim := SimFixture.make_sim()
	var scene := SimFixture.woodcutter_scene(sim)
	var hut: BuildingState = scene["hut"]
	hut.yard.add(&"wood", 5)
	sim.province.jobs.add_or_merge(&"wood", 5, ProvinceSim.yard_id(hut.id), 0)
	sim.province.jobs.add_or_merge(&"wood", 0, ProvinceSim.yard_id(hut.id), 0)
	assert_int(sim.province.jobs.count()).is_equal(1)
	assert_int(sim.province.nearest_source(&"wood", 1, Vector2i(20, 20))).is_equal(-hut.id)
	assert_int(sim.province.stored(&"wood")).is_equal(5)
	# Taken directly (a workshop or a householder): the porters' request shrinks with it.
	hut.yard.remove(&"wood", 5)
	sim.province.jobs.trim_yard_requests(sim.province)
	assert_int(sim.province.jobs.count()).is_equal(0)


func test_a_workshop_takes_its_input_from_another_yard() -> void:
	var sim := SimFixture.make_sim()
	var scene := SimFixture.woodcutter_scene(sim)
	var hut: BuildingState = scene["hut"]
	hut.yard.add(&"wood", 3)
	var mill := SimFixture.place(sim, &"sawmill", Vector2i(20, 12))
	var sawyer := SimFixture.spawn(sim, &"sawyer", mill.entrance_tile())
	assert_str(String(sim.execute(AssignWorkerCommand.new(sawyer.id, mill.id)))).is_equal("")
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return hut.yard.total(&"wood") < 3, 120)).is_true()


func test_demolished_workshop_leaves_its_yard_on_the_ground() -> void:
	var sim := SimFixture.make_sim()
	var scene := SimFixture.woodcutter_scene(sim)
	var hut: BuildingState = scene["hut"]
	hut.yard.add(&"wood", 7)
	var before := sim.province.goods_total(&"wood")
	sim.execute(DemolishCommand.new(hut.id))
	# Its yard plus half its building cost.
	assert_int(sim.province.goods_total(&"wood")).is_greater_equal(before)
	assert_int(sim.province.jobs.count()).is_greater(0)


func test_yard_survives_save_and_load() -> void:
	var sim := SimFixture.make_sim()
	var scene := SimFixture.woodcutter_scene(sim)
	var hut: BuildingState = scene["hut"]
	hut.yard.add(&"wood", 6)
	var text := JSON.stringify(sim.to_dict(), "", false, true)
	var loaded := Simulation.from_dict(JSON.parse_string(text), SimFixture.registry())
	var again: BuildingState = loaded.province.buildings.get_building(hut.id)
	assert_int(again.yard.total(&"wood")).is_equal(6)
	assert_int(again.yard.stack_size(&"wood")).is_equal(10)


## UI-2 part 2 (owner 2026-11-13): with room in the storage the woodcutter still leaves his logs
## on the yard and goes back to the trees; without a porter they stay there.
func test_the_worker_leaves_his_output_on_the_yard_even_with_room_in_a_storage() -> void:
	var sim := SimFixture.make_sim()
	var scene := SimFixture.woodcutter_scene(sim)
	var hut: BuildingState = scene["hut"]
	var stock: BuildingState = scene["stock"]
	assert_bool(SimFixture.run_until(sim, func() -> bool: return hut.yard.total(&"wood") >= 2, 300)).is_true()
	assert_int(stock.stock.total(&"wood")).is_equal(0)


## UI-2 part 2: when the porters cannot keep up (a few logs already wait on the yard), the
## worker walks to a storage with room himself.
func test_a_yard_waiting_for_porters_sends_the_worker_to_a_storage_himself() -> void:
	var sim := SimFixture.make_sim()
	var scene := SimFixture.woodcutter_scene(sim)
	var hut: BuildingState = scene["hut"]
	var stock: BuildingState = scene["stock"]
	hut.yard.add(&"wood", DeliverStep.YARD_WAITING)
	assert_bool(SimFixture.run_until(sim, func() -> bool: return stock.stock.total(&"wood") >= 1, 300)).is_true()
	assert_int(hut.yard.total(&"wood")).is_equal(DeliverStep.YARD_WAITING)
