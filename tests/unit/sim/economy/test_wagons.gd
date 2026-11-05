extends GdUnitTestSuite
## M4b-3: horse wagons (GDD §5.2). A carter of a stable takes requests of 4+ units over 10+
## tiles when both ends have a road in front of a door, carries up to 6, drives on roads
## only, faster than on foot, and takes the wagon back to the stable between jobs.


## Lays dirt road from [param a] to [param b]: along x first, then along y.
func _road(sim: Simulation, a: Vector2i, b: Vector2i) -> void:
	var tiles: Array[Vector2i] = []
	var t := a
	tiles.append(t)
	while t.x != b.x:
		t.x += signi(b.x - t.x)
		tiles.append(t)
	while t.y != b.y:
		t.y += signi(b.y - t.y)
		tiles.append(t)
	sim.execute(BuildRoadCommand.new(tiles))


## Two storages 30 tiles apart and a stable between them, all joined by a road along y = 12;
## one carter in the stable.
func _scene(sim: Simulation, roads: bool = true) -> Dictionary:
	var a := SimFixture.place(sim, &"stockpile", Vector2i(4, 4))
	var b := SimFixture.place(sim, &"stockpile", Vector2i(36, 4))
	var stable := SimFixture.place(sim, &"stable", Vector2i(20, 6))
	if roads:
		_road(sim, a.door_front_tile(), Vector2i(a.door_front_tile().x, 12))
		_road(sim, Vector2i(a.door_front_tile().x, 12), Vector2i(b.door_front_tile().x, 12))
		_road(sim, b.door_front_tile(), Vector2i(b.door_front_tile().x, 12))
		_road(sim, stable.door_front_tile(), Vector2i(stable.door_front_tile().x, 12))
	var carter := SimFixture.spawn(sim, Carriers.CARTER_KIND, stable.entrance_tile())
	assert_str(String(sim.execute(AssignWorkerCommand.new(carter.id, stable.id)))).is_empty()
	return {"a": a, "b": b, "stable": stable, "carter": carter}


func test_wagon_carries_six_on_roads_only_and_parks() -> void:
	var sim := SimFixture.make_sim(Vector2i(48, 24))
	var scene := _scene(sim)
	var a: BuildingState = scene["a"]
	var b: BuildingState = scene["b"]
	var stable: BuildingState = scene["stable"]
	var carter: Agent = scene["carter"]
	a.stock.add(&"bread", 12)
	sim.execute(RequestTransportCommand.new(&"bread", 12, a.id, b.id))
	var loads: Array[int] = []
	var off_road := 0
	for i: int in SimFixture.ticks(240.0):
		sim.step()
		for event: Dictionary in sim.events.drain():
			if event["type"] == &"good_stored" and int(event["storage"]) == b.id:
				loads.append(int(event["amount"]))
		if carter.vehicle == Carriers.WAGON and not sim.province.grid.has_road(carter.tile()) \
				and sim.province.building_entered_at(carter.tile()) == null:
			off_road += 1
	assert_array(loads).is_equal([6, 6])
	assert_int(off_road).is_equal(0)
	# Back in the stable, the wagon put away.
	assert_str(String(carter.vehicle)).is_empty()
	assert_object(sim.province.building_entered_at(carter.tile())).is_same(stable)
	assert_array(Array(sim.province.dangling_holds())).is_empty()


func test_no_wagon_for_small_or_short_jobs() -> void:
	var sim := SimFixture.make_sim(Vector2i(48, 24))
	var scene := _scene(sim)
	var a: BuildingState = scene["a"]
	var b: BuildingState = scene["b"]
	a.stock.add(&"bread", 12)
	# 3 units: below the wagon's minimum, and there are no porters.
	sim.execute(RequestTransportCommand.new(&"bread", 3, a.id, b.id))
	sim.run_ticks(SimFixture.ticks(30.0))
	assert_int(b.stock.total(&"bread")).is_equal(0)
	# A storage 6 tiles from A: too close for a wagon.
	var near := SimFixture.place(sim, &"stockpile", Vector2i(10, 4))
	_road(sim, near.door_front_tile(), Vector2i(near.door_front_tile().x, 12))
	sim.execute(RequestTransportCommand.new(&"bread", 6, a.id, near.id))
	sim.run_ticks(SimFixture.ticks(30.0))
	assert_int(near.stock.total(&"bread")).is_equal(0)


func test_no_wagon_without_a_road_to_the_door() -> void:
	var sim := SimFixture.make_sim(Vector2i(48, 24))
	var scene := _scene(sim, false)
	var a: BuildingState = scene["a"]
	var b: BuildingState = scene["b"]
	a.stock.add(&"bread", 12)
	sim.execute(RequestTransportCommand.new(&"bread", 12, a.id, b.id))
	sim.run_ticks(SimFixture.ticks(30.0))
	assert_int(b.stock.total(&"bread")).is_equal(0)
	assert_str(String((scene["carter"] as Agent).vehicle)).is_empty()


func test_wagon_is_faster_than_walking_on_the_same_road() -> void:
	var times: Array[int] = []
	for vehicle: StringName in [&"", Carriers.WAGON]:
		var sim := SimFixture.make_sim()
		_road(sim, Vector2i(2, 10), Vector2i(29, 10))
		var agent := SimFixture.spawn(sim, &"porter", Vector2i(2, 10))
		agent.vehicle = vehicle
		for i: int in 3000:
			if Movement.walk(sim.province, agent, Vector2i(29, 10)) == TaskStep.Status.DONE:
				times.append(i)
				break
			Movement.serve_paths(sim.province)
			Movement.move_all(sim.province)
	assert_float(float(times[0]) / times[1]).is_between(1.2, 1.4)


func test_wagon_trip_survives_save_and_load() -> void:
	var sim := SimFixture.make_sim(Vector2i(48, 24))
	var scene := _scene(sim)
	var a: BuildingState = scene["a"]
	var b: BuildingState = scene["b"]
	a.stock.add(&"bread", 12)
	sim.execute(RequestTransportCommand.new(&"bread", 12, a.id, b.id))
	sim.run_ticks(SimFixture.ticks(20.0))
	assert_str(String((scene["carter"] as Agent).vehicle)).is_equal("wagon")
	var text := SimCodec.canonical(sim.to_dict())
	var loaded := Simulation.from_dict(JSON.parse_string(text), SimFixture.registry())
	assert_str(SimCodec.canonical(loaded.to_dict())).is_equal(text)
	var target := loaded.province.buildings.get_building(b.id)
	assert_bool(SimFixture.run_until(loaded, func() -> bool: return target.stock.total(&"bread") == 12,
			240.0)).is_true()
