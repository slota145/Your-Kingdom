extends GdUnitTestSuite
## M5 part 1: water for ships. Boats sail on shallow and deep sea, cogs only on deep sea and
## fairways; buildings partly on the water (a fishing wharf, a shipyard) and their rules.


## 40x40: land above row 24, shallow sea rows 24-26, deep sea from row 27.
func _sea_sim() -> Simulation:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	SimFixture.coast(sim, 24, 27)
	return sim


func test_boats_sail_shallow_and_deep_cogs_only_deep() -> void:
	var province := _sea_sim().province
	assert_bool(province.boat_nav.is_walkable(Vector2i(5, 24))).is_true()
	assert_bool(province.boat_nav.is_walkable(Vector2i(5, 30))).is_true()
	assert_bool(province.boat_nav.is_walkable(Vector2i(5, 23))).is_false()
	assert_bool(province.cog_nav.is_walkable(Vector2i(5, 24))).is_false()
	assert_bool(province.cog_nav.is_walkable(Vector2i(5, 30))).is_true()
	# People never walk on the sea.
	assert_bool(province.nav.is_walkable(Vector2i(5, 24))).is_false()
	assert_array(province.boat_nav.find_path(Vector2i(2, 24), Vector2i(30, 35))).is_not_empty()
	assert_array(province.cog_nav.find_path(Vector2i(2, 30), Vector2i(2, 25))).is_empty()


func test_shipyard_digs_a_fairway_for_cogs() -> void:
	var sim := _sea_sim()
	var province := sim.province
	var shipyard := SimFixture.place(sim, &"shipyard", Vector2i(10, 22))
	# Rows 24-25 of the shipyard are its slipway; the berth is the shallow tile below it.
	var berth := shipyard.berth_tile()
	assert_vector(berth).is_equal(Vector2i(11, 26))
	assert_int(province.sail_depth(berth)).is_equal(1)
	assert_bool(province.cog_nav.is_walkable(berth)).is_true()
	assert_array(province.cog_nav.find_path(Vector2i(30, 35), berth)).is_not_empty()
	# Other shallow water stays closed to cogs; the slipway is closed to every ship.
	assert_bool(province.cog_nav.is_walkable(Vector2i(30, 25))).is_false()
	assert_bool(province.boat_nav.is_walkable(Vector2i(11, 25))).is_false()
	province.remove_building(shipyard.id)
	assert_bool(province.cog_nav.is_walkable(berth)).is_false()


func test_buildings_on_the_water_need_the_sea_where_drawn() -> void:
	var sim := _sea_sim()
	var province := sim.province
	var wharf := sim.data.get_building(&"fishing_wharf")
	assert_str(String(province.placement_error(wharf, Vector2i(5, 22)))).is_empty()
	# All on land: the pier needs the sea.
	assert_str(String(province.placement_error(wharf, Vector2i(5, 10)))).is_equal("needs_sea")
	# Too far out: the hut would stand in the sea.
	assert_str(String(province.placement_error(wharf, Vector2i(5, 23)))).is_equal("terrain_not_buildable")
	# Mirrored, the pier is on the +x side: the sea is not there.
	assert_str(String(province.placement_error(wharf, Vector2i(5, 22), 1))).is_equal("needs_sea")


func test_shipyard_needs_deep_water_nearby() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	SimFixture.coast(sim, 24, 39)   # a wide shallow shelf: deep water only at the map edge
	var shipyard := sim.data.get_building(&"shipyard")
	assert_str(String(sim.province.placement_error(shipyard, Vector2i(10, 22)))).is_equal("no_deep_water")
	var wharf := sim.data.get_building(&"fishing_wharf")
	assert_str(String(sim.province.placement_error(wharf, Vector2i(5, 22)))).is_empty()


func test_ship_sails_only_on_its_water() -> void:
	var sim := _sea_sim()
	var province := sim.province
	var shipyard := SimFixture.place(sim, &"shipyard", Vector2i(10, 22))
	for kind: StringName in [&"fishing_boat", &"cog"]:
		var ship := Ships.launch(province, sim.data.get_ship(kind), shipyard)
		var goal := Vector2i(36, 25) if kind == &"fishing_boat" else Vector2i(36, 36)
		assert_bool(Ships.sail_to(province, ship, goal)).is_true()
		var nav := Ships.nav_for(province, ship.def)
		for i: int in 2000:
			Ships.move_all(province)
			assert_bool(nav.is_walkable(ship.tile())).override_failure_message(
					"%s on %s" % [kind, ship.tile()]).is_true()
			if ship.path_state == ShipUnit.PathState.ARRIVED:
				break
		assert_vector(ship.tile()).is_equal(goal)
		# Cogs never cut across the shallows (the fairway is the berth tile only).
		assert_bool(kind == &"fishing_boat" or ship.tile().y >= 27).is_true()
	# A cog cannot be sent into shallow water.
	var cog := Ships.launch(province, sim.data.get_ship(&"cog"), shipyard)
	assert_bool(Ships.sail_to(province, cog, Vector2i(30, 25))).is_false()


func test_coast_map_loads_with_sea_beach_bay_and_shoals() -> void:
	var problems := PackedStringArray()
	var registry := SimFixture.registry()
	var sim := Simulation.from_map(registry, registry.get_map(&"coast"), 1, problems)
	assert_array(Array(problems)).is_empty()
	var province := sim.province
	assert_vector(province.grid.size).is_equal(Vector2i(128, 128))
	var counts := {}
	var shoals := 0
	for y: int in 128:
		for x: int in 128:
			var id := province.terrain_at(Vector2i(x, y)).id
			counts[id] = int(counts.get(id, 0)) + 1
			if province.resources.has_node(Vector2i(x, y), &"fish_shoal"):
				shoals += 1
	var sea := int(counts.get(&"sea_shallow", 0)) + int(counts.get(&"sea_deep", 0))
	assert_int(sea).is_between(3000, 5500)   # about a quarter of the map
	assert_int(int(counts.get(&"sea_shallow", 0))).is_greater(300)
	assert_int(int(counts.get(&"sand", 0))).is_greater(300)
	assert_int(int(counts.get(&"water", 0))).is_greater(100)   # the river
	assert_int(shoals).is_greater_equal(10)
	# M5 part 3: the game starts from a ship; the beach is reachable from the way in.
	assert_int(province.buildings.count()).is_equal(0)
	assert_object(province.landing).is_not_null()
	var beach := province.landing.beach
	assert_array(province.find_path(province.entry_tile, beach)).is_not_empty()
	# A shipyard and a fishing wharf fit on the bay shore not far from the beach, and a cog
	# can sail from the shipyard out to the open sea.
	province.first_building = &""
	for id: StringName in [&"fishing_wharf", &"shipyard"]:
		var def := registry.get_def(&"building", id) as BuildingDef
		var spot := Agent.NO_TILE
		var turn := 0
		for y: int in range(48, 106):
			for x: int in range(56, 104):
				# Any way round (W1: the shores are curved, not straight runs facing one way).
				for o: int in def.orientation_count():
					if spot == Agent.NO_TILE and (Vector2i(x, y) - beach).length() < 30 \
							and province.placement_error(def, Vector2i(x, y), o) == &"":
						spot = Vector2i(x, y)
						turn = o
		assert_vector(spot).override_failure_message("no place for %s" % id).is_not_equal(Agent.NO_TILE)
		if id == &"fishing_wharf":
			province.add_building(def, spot, true, turn)
		if id == &"shipyard":
			var yard := province.add_building(def, spot, true, turn)
			assert_array(province.cog_nav.find_path(yard.berth_tile(), Vector2i(120, 120))).is_not_empty()


func test_a_building_on_the_water_cannot_be_turned() -> void:
	var sim := _sea_sim()
	var wharf := SimFixture.place(sim, &"fishing_wharf", Vector2i(5, 22))
	assert_str(String(sim.execute(RotateBuildingCommand.new(wharf.id)))).is_equal("cannot_turn_on_water")
	assert_int(wharf.orientation).is_equal(0)
