extends GdUnitTestSuite
## M4b-3: handcarts (GDD §5.2). A storage buys up to 2 for 3 planks each; its porters take one
## for requests of 2 or more units and carry 3; off the road a handcart is slower.


func _storage_with_porters(sim: Simulation, origin: Vector2i, porters: int) -> BuildingState:
	var storage := SimFixture.place(sim, &"stockpile", origin)
	for i: int in porters:
		var porter := SimFixture.spawn(sim, &"porter", storage.door_front_tile())
		assert_str(String(sim.execute(AssignWorkerCommand.new(porter.id, storage.id)))).is_empty()
	return storage


func _loads(sim: Simulation, seconds: float, dest: int) -> Array[int]:
	var loads: Array[int] = []
	for i: int in SimFixture.ticks(seconds):
		sim.step()
		for event: Dictionary in sim.events.drain():
			if event["type"] == &"good_stored" and int(event["storage"]) == dest:
				loads.append(int(event["amount"]))
	return loads


func test_buying_handcarts_costs_planks_and_stops_at_two() -> void:
	var sim := SimFixture.make_sim()
	var storage := SimFixture.place(sim, &"stockpile", Vector2i(4, 4))
	assert_str(String(sim.execute(BuyCartCommand.new(storage.id)))).is_equal("not_enough_goods")
	storage.stock.add(&"planks", 10)
	assert_str(String(sim.execute(BuyCartCommand.new(storage.id)))).is_empty()
	assert_str(String(sim.execute(BuyCartCommand.new(storage.id)))).is_empty()
	assert_str(String(sim.execute(BuyCartCommand.new(storage.id)))).is_equal("carts_full")
	assert_int(storage.carts).is_equal(2)
	assert_int(storage.stock.total(&"planks")).is_equal(4)
	var hut := SimFixture.place(sim, &"woodcutter", Vector2i(20, 20))
	assert_str(String(sim.execute(BuyCartCommand.new(hut.id)))).is_equal("no_carts_here")


func test_porter_with_handcart_carries_three() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	var a := _storage_with_porters(sim, Vector2i(4, 4), 1)
	var b := SimFixture.place(sim, &"stockpile", Vector2i(24, 4))
	a.carts = 1
	a.stock.add(&"bread", 7)
	sim.execute(RequestTransportCommand.new(&"bread", 7, a.id, b.id))
	var loads := _loads(sim, 120.0, b.id)
	# 3 + 3 on the handcart, then the last unit on foot.
	assert_array(loads).is_equal([3, 3, 1])
	assert_int(b.stock.total(&"bread")).is_equal(7)
	assert_array(Array(sim.province.dangling_holds())).is_empty()


func test_no_handcart_without_one_bought_or_for_a_single_unit() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	var a := _storage_with_porters(sim, Vector2i(4, 4), 1)
	var b := SimFixture.place(sim, &"stockpile", Vector2i(24, 4))
	a.stock.add(&"bread", 3)
	sim.execute(RequestTransportCommand.new(&"bread", 2, a.id, b.id))
	assert_array(_loads(sim, 60.0, b.id)).is_equal([1, 1])
	a.carts = 1
	sim.execute(RequestTransportCommand.new(&"bread", 1, a.id, b.id))
	assert_array(_loads(sim, 40.0, b.id)).is_equal([1])


func test_each_handcart_serves_one_porter_at_a_time() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	var a := _storage_with_porters(sim, Vector2i(4, 4), 2)
	var b := SimFixture.place(sim, &"stockpile", Vector2i(24, 4))
	a.carts = 1
	a.stock.add(&"bread", 20)
	sim.execute(RequestTransportCommand.new(&"bread", 20, a.id, b.id))
	var most := 0
	for i: int in SimFixture.ticks(60.0):
		sim.step()
		sim.events.drain()
		var using := 0
		for agent: Agent in sim.province.agents.all():
			if agent.vehicle == Carriers.HANDCART:
				using += 1
		most = maxi(most, using)
	assert_int(most).is_equal(1)


func _walk_time(on_road: bool) -> int:
	var sim := SimFixture.make_sim()
	if on_road:
		var tiles: Array[Vector2i] = []
		for x: int in range(2, 30):
			tiles.append(Vector2i(x, 10))
		sim.execute(BuildRoadCommand.new(tiles))
	var agent := SimFixture.spawn(sim, &"porter", Vector2i(2, 10))
	agent.vehicle = Carriers.HANDCART
	for i: int in 3000:
		if Movement.walk(sim.province, agent, Vector2i(29, 10)) == TaskStep.Status.DONE:
			return i
		Movement.serve_paths(sim.province)
		Movement.move_all(sim.province)
	return -1


func test_handcart_is_slow_off_the_road() -> void:
	var grass := _walk_time(false)
	var road := _walk_time(true)
	# On foot: grass 1.0, road 0.67. With a handcart grass costs 1 / 0.7.
	assert_float(float(grass) / road).is_between(2.0, 2.3)


func test_handcarts_survive_save_and_load() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	var a := _storage_with_porters(sim, Vector2i(4, 4), 1)
	var b := SimFixture.place(sim, &"stockpile", Vector2i(24, 4))
	a.carts = 2
	a.stock.add(&"bread", 9)
	sim.execute(RequestTransportCommand.new(&"bread", 9, a.id, b.id))
	sim.run_ticks(SimFixture.ticks(8))
	var text := SimCodec.canonical(sim.to_dict())
	assert_str(text).contains("\"vehicle\":\"handcart\"")
	var loaded := Simulation.from_dict(JSON.parse_string(text), SimFixture.registry())
	assert_str(SimCodec.canonical(loaded.to_dict())).is_equal(text)
	assert_int(loaded.province.buildings.get_building(a.id).carts).is_equal(2)
