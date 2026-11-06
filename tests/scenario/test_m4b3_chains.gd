extends GdUnitTestSuite
## M4b-3 DoD: the stable's carters do the big jobs in a town joined by road (event counters):
## they bring materials to a building site, take a workshop's yard to a storage and load the
## travelling merchant's wagon. Porters keep the small leftovers.


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


## Joins the door of [param building] to the main road along y = 14.
func _spur(sim: Simulation, building: BuildingState) -> void:
	_road(sim, building.door_front_tile(), Vector2i(building.door_front_tile().x, 14))


## A storage with wood and planks, a stable with 2 carters and a porter, all north of a long
## road along y = 14 that ends at the map edge (the merchant's way in).
func _town(sim: Simulation) -> Dictionary:
	var store := SimFixture.place(sim, &"stockpile", Vector2i(3, 4))
	store.stock.add(&"wood", 40)
	store.stock.add(&"planks", 40)
	store.stock.add(&"stone", 20)
	var stable := SimFixture.place(sim, &"stable", Vector2i(10, 6))
	_road(sim, Vector2i(1, 14), Vector2i(63, 14))
	_spur(sim, store)
	_spur(sim, stable)
	for i: int in 2:
		var carter := SimFixture.spawn(sim, Carriers.CARTER_KIND, stable.entrance_tile())
		sim.execute(AssignWorkerCommand.new(carter.id, stable.id))
	var porter := SimFixture.spawn(sim, &"porter", store.entrance_tile())
	sim.execute(AssignWorkerCommand.new(porter.id, store.id))
	sim.province.entry_tile = Vector2i(63, 14)
	return {"store": store, "stable": stable}


## Runs [param seconds]; counts units each kind of person brought into [param storages]
## ("carter:<id>" / "porter:<id>") and took out of them ("carter_took:<id>").
func _run_counting(sim: Simulation, seconds: float, storages: Array[int]) -> Dictionary:
	var counts := {}
	for i: int in SimFixture.ticks(seconds):
		sim.step()
		for e: Dictionary in sim.events.drain():
			if e["type"] != &"good_stored" and e["type"] != &"good_taken":
				continue
			var id := int(e["storage"])
			var agent := sim.province.agents.get_agent(int(e["agent"]))
			if agent == null or not storages.has(id):
				continue
			var key := "%s%s:%d" % [agent.kind, "" if e["type"] == &"good_stored" else "_took", id]
			counts[key] = int(counts.get(key, 0)) + int(e["amount"])
	return counts


func test_wagons_bring_materials_to_a_far_building_site() -> void:
	var sim := SimFixture.make_sim(Vector2i(64, 24))
	_town(sim)
	# A brewery far east: 30 gold and its materials in 2 phases.
	sim.province.treasury.gold = 200
	assert_str(String(sim.execute(PlaceBuildingCommand.new(&"brewery", Vector2i(50, 8))))).is_empty()
	var brewery: BuildingState = null
	for b: BuildingState in sim.province.buildings.all():
		if b.def.id == &"brewery":
			brewery = b
	_spur(sim, brewery)
	var site := brewery.site_id
	var counts := _run_counting(sim, 300.0, [site])
	print("site deliveries: ", counts)
	var cost := 0
	for good: StringName in brewery.def.build_cost:
		cost += brewery.def.build_cost[good]
	assert_int(int(counts.get("carter:%d" % site, 0))).is_greater_equal(Carriers.WAGON_MIN)
	assert_int(int(counts.get("carter:%d" % site, 0)) + int(counts.get("porter:%d" % site, 0))).is_equal(cost)


func test_wagons_take_a_full_yard_to_storage() -> void:
	var sim := SimFixture.make_sim(Vector2i(64, 24))
	var town := _town(sim)
	var store: BuildingState = town["store"]
	var hut := SimFixture.place(sim, &"woodcutter", Vector2i(52, 9))
	_spur(sim, hut)
	var yard := ProvinceSim.yard_id(hut.id)
	hut.yard.add(&"wood", 10)
	sim.province.jobs.add_or_merge(&"wood", 10, yard, 0)
	var counts := _run_counting(sim, 240.0, [yard, store.id])
	print("yard: ", counts)
	assert_int(hut.yard.total(&"wood")).is_equal(0)
	assert_int(int(counts.get("carter_took:%d" % yard, 0))).is_greater_equal(Carriers.WAGON_MIN)
	assert_int(store.stock.total(&"wood")).is_equal(50)


func test_wagons_load_the_merchants_wagon() -> void:
	var sim := SimFixture.make_sim(Vector2i(64, 24))
	_town(sim)
	var market := SimFixture.place(sim, &"market", Vector2i(44, 8))
	_spur(sim, market)
	sim.execute(SetSellAboveCommand.new(&"planks", 16))
	sim.province.merchant.next_visit = sim.province.tick + 10
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return sim.province.merchant.state == Merchant.State.TRADING, 120.0)).is_true()
	var wagon := sim.province.merchant.wagon_id
	var counts := _run_counting(sim, Merchant.STAY - 5.0, [wagon])
	print("merchant loads: ", counts)
	assert_int(int(counts.get("carter:%d" % wagon, 0))).is_greater_equal(Carriers.WAGON_MIN)
	assert_array(Array(sim.province.dangling_holds())).is_empty()
