extends GdUnitTestSuite
## M2 DoD: full stockpile, target demolished mid-task, no path. Each time no goods are lost
## and no reservation or claim is left hanging.


## Runs ticks while checking after every tick that goods are conserved and nothing dangles.
func _run_checked(sim: Simulation, ticks: int, good: StringName, expected: Callable) -> void:
	for i: int in ticks:
		sim.step()
		sim.events.drain()
		var holds := sim.province.dangling_holds()
		if not holds.is_empty():
			fail("tick %d: %s" % [sim.clock.tick, ", ".join(holds)])
			return
		var want: int = expected.call()
		if sim.province.goods_total(good) != want:
			fail("tick %d: %d %s, expected %d" % [sim.clock.tick, sim.province.goods_total(good), good, want])
			return


func _wood_cut(sim: Simulation) -> Callable:
	return func() -> int:
		var cut := 0
		for tile: Vector2i in sim.province.resources.tiles_with_nodes():
			cut += sim.province.resources.def_at(tile).amount - sim.province.resources.amount(tile)
		return cut


func test_full_stockpile_puts_wood_on_ground_then_porters_store_it() -> void:
	var sim := SimFixture.make_sim()
	var scene := SimFixture.woodcutter_scene(sim)
	var stock: BuildingState = scene["stock"]
	for slot: int in stock.stock.slot_count():
		stock.stock.add(&"bread", 20)
	var bread := 12 * 20
	_run_checked(sim, SimFixture.ticks(90), &"wood", _wood_cut(sim))
	assert_int(stock.stock.total(&"wood")).is_equal(0)
	assert_int(sim.province.piles.size()).is_greater(0)
	assert_int(sim.province.goods_total(&"bread")).is_equal(bread)
	# A new stockpile and a porter: the dropped wood is collected.
	var second := SimFixture.place(sim, &"stockpile", Vector2i(4, 16))
	SimFixture.spawn(sim, &"porter", Vector2i(10, 12))
	_run_checked(sim, SimFixture.ticks(120), &"wood", _wood_cut(sim))
	assert_int(second.stock.total(&"wood")).is_greater(0)


func test_stockpile_demolished_during_delivery() -> void:
	var sim := SimFixture.make_sim()
	var scene := SimFixture.woodcutter_scene(sim)
	var stock: BuildingState = scene["stock"]
	var worker: Agent = scene["worker"]
	var other := SimFixture.place(sim, &"stockpile", Vector2i(4, 20))
	stock.stock.add(&"wood", 30)
	for i: int in 6:
		SimFixture.spawn(sim, &"porter", Vector2i(8 + i, 12))
	# Demolition gives back half of the stockpile's building materials (GDD §5.1).
	var start := 30 + int(Construction.refund(stock.def).get(&"wood", 0))
	var counter := _wood_cut(sim)
	var expected := func() -> int: return start + int(counter.call())
	# Wait until the woodcutter walks to the stockpile with a log and has reserved space there.
	for i: int in 2000:
		sim.step()
		if worker.task != null and int(worker.task.bb.get("_dst", 0)) == stock.id:
			break
	assert_int(int(worker.task.bb.get("_dst", 0))).is_equal(stock.id)
	sim.execute(DemolishCommand.new(stock.id))
	_run_checked(sim, SimFixture.ticks(300), &"wood", expected)
	assert_int(sim.province.piles.size()).is_equal(0)
	assert_int(other.stock.total(&"wood")).is_equal(sim.province.goods_total(&"wood")
			- (worker.carry_amount if worker.carry_good == &"wood" else 0))


func test_transport_source_demolished_while_porter_walks() -> void:
	var sim := SimFixture.make_sim()
	var a := SimFixture.place(sim, &"stockpile", Vector2i(20, 2))
	var b := SimFixture.place(sim, &"stockpile", Vector2i(2, 20))
	a.stock.add(&"bread", 10)
	var porter := SimFixture.spawn(sim, &"porter", Vector2i(2, 2))
	sim.execute(RequestTransportCommand.new(&"bread", 10, a.id, b.id))
	sim.run_ticks(15)
	assert_int(porter.task.request_id).is_greater(0)
	sim.execute(DemolishCommand.new(a.id))
	var ten := func() -> int: return 10
	_run_checked(sim, SimFixture.ticks(600), &"bread", ten)
	assert_int(b.stock.total(&"bread")).is_equal(10)
	# Only the demolition refund (wood) may still be waiting for porters.
	for request: TransportRequest in sim.province.jobs.all():
		assert_str(String(request.good)).is_equal("wood")


func test_destination_demolished_while_porter_carries() -> void:
	var sim := SimFixture.make_sim()
	var a := SimFixture.place(sim, &"stockpile", Vector2i(2, 2))
	var b := SimFixture.place(sim, &"stockpile", Vector2i(22, 22))
	var c := SimFixture.place(sim, &"stockpile", Vector2i(2, 22))
	a.stock.add(&"bread", 3)
	var porter := SimFixture.spawn(sim, &"porter", Vector2i(3, 8))
	sim.execute(RequestTransportCommand.new(&"bread", 3, a.id, b.id))
	for i: int in 400:
		sim.step()
		if porter.is_carrying():
			break
	assert_bool(porter.is_carrying()).is_true()
	sim.execute(DemolishCommand.new(b.id))
	var three := func() -> int: return 3
	_run_checked(sim, SimFixture.ticks(240), &"bread", three)
	assert_int(a.stock.total(&"bread") + c.stock.total(&"bread")).is_equal(3)
	assert_int(sim.province.jobs.count()).is_equal(0)


func test_no_path_to_stockpile() -> void:
	var sim := SimFixture.make_sim()
	var scene := SimFixture.woodcutter_scene(sim)
	var stock: BuildingState = scene["stock"]
	# Wall in the stockpile entrance (row below the stockpile).
	for x: int in range(3, 9):
		sim.province.grid.set_blocked(Vector2i(x, 8), true)
		sim.province.refresh_tile(Vector2i(x, 8))
	_run_checked(sim, SimFixture.ticks(120), &"wood", _wood_cut(sim))
	assert_int(stock.stock.total(&"wood")).is_equal(0)
	assert_int(stock.stock.reservation_count()).is_equal(0)
	assert_int(sim.province.piles.size()).is_greater(0)


func test_porter_request_with_unreachable_source_waits_without_holding() -> void:
	var sim := SimFixture.make_sim()
	var a := SimFixture.place(sim, &"stockpile", Vector2i(2, 2))
	var b := SimFixture.place(sim, &"stockpile", Vector2i(20, 20))
	for x: int in range(1, 7):
		sim.province.grid.set_blocked(Vector2i(x, 6), true)
		sim.province.refresh_tile(Vector2i(x, 6))
	a.stock.add(&"bread", 5)
	SimFixture.spawn(sim, &"porter", Vector2i(15, 15))
	sim.execute(RequestTransportCommand.new(&"bread", 5, a.id, b.id))
	var five := func() -> int: return 5
	_run_checked(sim, SimFixture.ticks(60), &"bread", five)
	assert_int(a.stock.total(&"bread")).is_equal(5)
	assert_int(sim.province.jobs.count()).is_equal(1)
