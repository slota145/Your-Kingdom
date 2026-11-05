extends GdUnitTestSuite
## M3: physical construction. Porters bring materials, the builder uses up each phase's
## share and works; 2 phases; nothing is lost on demolition.


func _site_of(sim: Simulation, building: BuildingState) -> ConstructionSite:
	return sim.province.sites.get(building.site_id) as ConstructionSite


func test_phase_costs_split_the_build_cost() -> void:
	for def: BuildingDef in SimFixture.registry().buildings():
		var sum := {}
		for phase: int in [1, 2]:
			var cost := def.phase_cost(phase)
			for good: StringName in cost:
				sum[good] = int(sum.get(good, 0)) + cost[good]
		assert_dict(sum).is_equal(def.build_cost)


func test_placed_building_is_a_site_until_built() -> void:
	var sim := SimFixture.make_sim()
	SimFixture.village(sim)
	assert_str(String(sim.execute(PlaceBuildingCommand.new(&"woodcutter", Vector2i(16, 10))))).is_equal("")
	var hut := sim.province.buildings.get_building(sim.ids.next_id - 2)
	assert_bool(hut.is_complete()).is_false()
	assert_int(hut.site_id).is_greater(0)
	assert_int(hut.workers.size()).is_equal(0)


func test_porters_bring_materials_and_builder_finishes_in_two_phases() -> void:
	var sim := SimFixture.make_sim()
	var village := SimFixture.village(sim, 40)
	var stock: BuildingState = village["stock"]
	var wood_before := sim.province.goods_total(&"wood")
	sim.execute(PlaceBuildingCommand.new(&"mill", Vector2i(16, 10)))
	var mill: BuildingState = null
	for b: BuildingState in sim.province.buildings.all():
		if b.def.id == &"mill":
			mill = b
	var phases: Array[int] = []
	var building_seen := false
	for i: int in SimFixture.ticks(240):
		sim.step()
		for event: Dictionary in sim.events.drain():
			if event["type"] == &"site_phase_started":
				phases.append(int(event["phase"]))
		for agent: Agent in sim.province.agents.all():
			if agent.kind == &"builder" and agent.activity == &"build":
				building_seen = true
		assert_array(Array(sim.province.dangling_holds())).is_empty()
		if mill.is_complete():
			break
	assert_bool(mill.is_complete()).is_true()
	assert_array(phases).is_equal([1, 2])
	assert_bool(building_seen).is_true()
	# Exactly the build cost was used up; the rest of the wood is still around.
	assert_int(sim.province.goods_total(&"wood")).is_equal(wood_before - 8)
	assert_int(stock.stock.total(&"wood")).is_less_equal(wood_before - 8)
	assert_int(sim.province.sites.size()).is_equal(0)


func test_builder_waits_without_materials() -> void:
	var sim := SimFixture.make_sim()
	SimFixture.village(sim, 0)
	sim.execute(PlaceBuildingCommand.new(&"well", Vector2i(16, 10)))
	sim.run_ticks(SimFixture.ticks(60))
	var well := sim.province.buildings.get_building(sim.province.sites.values()[0].building_id)
	assert_bool(well.is_complete()).is_false()
	assert_bool(_site_of(sim, well).phase_started).is_false()
	assert_array(Array(sim.province.dangling_holds())).is_empty()


func test_demolishing_a_site_returns_delivered_materials() -> void:
	var sim := SimFixture.make_sim()
	SimFixture.village(sim, 40)
	var before := sim.province.goods_total(&"wood")
	sim.execute(PlaceBuildingCommand.new(&"town_hall", Vector2i(16, 10)))
	var site: ConstructionSite = sim.province.sites.values()[0]
	SimFixture.run_until(sim, func() -> bool: return site.stock.total(&"wood") >= 3, 120)
	assert_bool(site.phase_started).is_false()
	sim.execute(DemolishCommand.new(site.building_id))
	# Nothing started yet: every delivered log goes back on the ground, none is lost.
	assert_int(sim.province.goods_total(&"wood")).is_equal(before)
	assert_int(sim.province.sites.size()).is_equal(0)
	sim.run_ticks(SimFixture.ticks(120))
	assert_int(sim.province.piles.size()).is_equal(0)
	assert_int(sim.province.goods_total(&"wood")).is_equal(before)
	assert_array(Array(sim.province.dangling_holds())).is_empty()


func test_demolishing_a_finished_building_refunds_half() -> void:
	var sim := SimFixture.make_sim()
	SimFixture.place(sim, &"stockpile", Vector2i(2, 2))
	var mill := SimFixture.place(sim, &"mill", Vector2i(12, 12))
	sim.execute(DemolishCommand.new(mill.id))
	assert_int(sim.province.goods_total(&"wood")).is_equal(4)


## Trees around [param rect] (its border), except the [param gaps].
func _tree_ring(sim: Simulation, rect: Rect2i, gaps: Array[Vector2i] = []) -> void:
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var tile := Vector2i(x, y)
			var border := x == rect.position.x or y == rect.position.y \
					or x == rect.end.x - 1 or y == rect.end.y - 1
			if border and not gaps.has(tile):
				SimFixture.plant_trees(sim, Rect2i(tile, Vector2i.ONE))


func test_building_people_cannot_reach_is_refused() -> void:
	var sim := SimFixture.make_sim()
	SimFixture.village(sim)
	_tree_ring(sim, Rect2i(18, 18, 7, 7))
	assert_str(String(sim.execute(PlaceBuildingCommand.new(&"well", Vector2i(21, 21))))) \
			.is_equal("no_access")


func test_building_that_walls_off_an_entrance_is_refused() -> void:
	var sim := SimFixture.make_sim()
	SimFixture.village(sim)
	# A walled garden with a 2-tile gate and a well inside.
	var gate: Array[Vector2i] = [Vector2i(21, 18), Vector2i(22, 18)]
	_tree_ring(sim, Rect2i(18, 18, 7, 7), gate)
	SimFixture.place(sim, &"well", Vector2i(21, 21))
	# A hut in the gate, its door to the garden, would seal the well off.
	assert_str(String(sim.execute(PlaceBuildingCommand.new(&"woodcutter", Vector2i(21, 17), false, 1)))) \
			.is_equal("blocks_access")
	# Turned with its door to the trees nobody could get in at all.
	assert_str(String(sim.execute(PlaceBuildingCommand.new(&"woodcutter", Vector2i(21, 17))))) \
			.is_equal("no_access")
	# Next to the gate it is fine.
	assert_str(String(sim.execute(PlaceBuildingCommand.new(&"woodcutter", Vector2i(24, 15))))) \
			.is_equal("")


func test_builder_skips_a_site_they_cannot_reach() -> void:
	var sim := SimFixture.make_sim()
	SimFixture.village(sim)
	assert_str(String(sim.execute(PlaceBuildingCommand.new(&"well", Vector2i(14, 8))))).is_equal("")
	var near: BuildingState = sim.province.buildings.get_building(sim.ids.next_id - 2)
	assert_str(String(sim.execute(PlaceBuildingCommand.new(&"well", Vector2i(20, 14))))).is_equal("")
	var far: BuildingState = sim.province.buildings.get_building(sim.ids.next_id - 2)
	# The near site has its materials but trees grew all around it (no way in).
	_site_of(sim, near).stock.add(&"wood", 2)
	_tree_ring(sim, Rect2i(13, 7, 3, 3))
	assert_bool(SimFixture.run_until(sim, func() -> bool: return far.is_complete(), 120)).is_true()
	assert_bool(near.is_complete()).is_false()
	assert_array(Array(sim.province.dangling_holds())).is_empty()


func test_fishing_hut_with_its_door_to_the_river_gets_a_clear_reason() -> void:
	var registry := SimFixture.registry()
	var sim := Simulation.from_map(registry, registry.get_map(&"riverlands"), 1, PackedStringArray())
	var def := registry.get_building(&"fishing_hut")
	# On the start map's east bank: the door corner lands on the river side.
	assert_str(String(sim.province.placement_error(def, Vector2i(64, 14)))) \
			.is_equal("entrance_faces_water")
	# One tile further from the river the door has ground in front of it.
	assert_str(String(sim.province.placement_error(def, Vector2i(62, 14)))).is_equal("")
