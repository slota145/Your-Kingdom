extends GdUnitTestSuite
## M4b-1.5: buildings can be turned. Houses have 4 orientations, other buildings 2; the
## door faces the chosen side and people go in and out only through the tile in front of it.


func _defs() -> Array[BuildingDef]:
	return SimFixture.registry().buildings()


func test_every_orientation_has_its_door_on_the_edge_facing_out() -> void:
	for def: BuildingDef in _defs():
		var sides: Dictionary[Vector2i, bool] = {}
		for o: int in def.orientation_count():
			var e := def.entrance_at(o)
			var rect := Rect2i(Vector2i.ZERO, def.footprint)
			assert_bool(rect.has_point(e)).override_failure_message("%s %d: %s" % [def.id, o, e]).is_true()
			assert_bool(rect.has_point(e + def.door_dir(o))) \
					.override_failure_message("%s %d: door does not face out" % [def.id, o]).is_false()
			assert_int(absi(def.door_dir(o).x) + absi(def.door_dir(o).y)).is_equal(1)
			sides[def.door_dir(o)] = true
		# Every orientation opens to another side.
		assert_int(sides.size()).override_failure_message(String(def.id)).is_equal(def.orientation_count())


func test_houses_turn_four_ways_others_two() -> void:
	var reg := SimFixture.registry()
	assert_int(reg.get_building(&"hut").orientation_count()).is_equal(4)
	assert_int(reg.get_building(&"bakery").orientation_count()).is_equal(2)
	var sim := SimFixture.make_sim()
	assert_str(String(sim.execute(PlaceBuildingCommand.new(&"bakery", Vector2i(10, 10), true, 2)))) \
			.is_equal("bad_orientation")
	assert_str(String(sim.execute(PlaceBuildingCommand.new(&"hut", Vector2i(10, 10), true, 4)))) \
			.is_equal("bad_orientation")
	assert_str(String(sim.execute(PlaceBuildingCommand.new(&"hut", Vector2i(10, 10), true, 3)))).is_equal("")


func test_mirrored_hut_has_its_door_on_the_other_front_wall() -> void:
	var hut := SimFixture.registry().get_building(&"hut")
	# As drawn: front corner tile, door to +x (screen right).
	assert_vector(hut.entrance_at(0)).is_equal(Vector2i(1, 1))
	assert_vector(hut.door_dir(0)).is_equal(Vector2i(1, 0))
	assert_vector(hut.door_dir(1)).is_equal(Vector2i(0, 1))
	# Turned round: back corner tile, door to -x / -y (away from the camera).
	assert_vector(hut.entrance_at(2)).is_equal(Vector2i(0, 0))
	assert_vector(hut.door_dir(2)).is_equal(Vector2i(-1, 0))
	assert_vector(hut.door_dir(3)).is_equal(Vector2i(0, -1))


## Every building in every orientation: a person walking in arrives from the tile in front
## of the door, and leaves through it.
func test_people_go_in_and_out_through_the_door() -> void:
	for def: BuildingDef in _defs():
		if def.needs_terrain_near != &"":
			continue   # the fishing hut needs a river (its own test below)
		for o: int in def.orientation_count():
			var sim := SimFixture.make_sim(Vector2i(24, 24))
			var origin := Vector2i(10, 10)
			assert_str(String(sim.execute(PlaceBuildingCommand.new(def.id, origin, true, o)))).is_equal("")
			var building := sim.province.buildings.get_building(sim.ids.next_id - 1)
			var door := building.door_front_tile()
			for from: Vector2i in [Vector2i(1, 1), Vector2i(22, 22), Vector2i(1, 22), Vector2i(22, 1)]:
				var path := sim.province.find_path(from, building.entrance_tile())
				assert_int(path.size()).is_greater(1)
				assert_vector(path[-2]).override_failure_message("%s %d from %s: %s" % [def.id, o, from, path]) \
						.is_equal(door)
				var out := sim.province.find_path(building.entrance_tile(), from)
				assert_vector(out[1]).override_failure_message("%s %d out: %s" % [def.id, o, out]).is_equal(door)


func test_a_walking_worker_enters_from_the_chosen_side() -> void:
	for o: int in 4:
		var sim := SimFixture.make_sim(Vector2i(24, 24))
		assert_str(String(sim.execute(PlaceBuildingCommand.new(&"hut", Vector2i(10, 10), true, o)))).is_equal("")
		var hut := sim.province.buildings.get_building(sim.ids.next_id - 1)
		var walker := SimFixture.spawn(sim, &"porter", Vector2i(2, 20))
		var before := walker.tile()
		var arrived_from := Agent.NO_TILE
		for i: int in SimFixture.ticks(40):
			Movement.walk(sim.province, walker, hut.entrance_tile())
			sim.step()
			if walker.tile() != before:
				if walker.tile() == hut.entrance_tile():
					arrived_from = before
				before = walker.tile()
		assert_vector(arrived_from).override_failure_message("orientation %d" % o).is_equal(hut.door_front_tile())


func test_door_against_a_wall_or_water_is_refused() -> void:
	var sim := SimFixture.make_sim()
	SimFixture.place(sim, &"stockpile", Vector2i(2, 2))
	SimFixture.place(sim, &"bakery", Vector2i(14, 10))
	# A hut at (12, 10) turned to 0 would open into the bakery's wall.
	assert_str(String(sim.province.placement_error(SimFixture.registry().get_building(&"hut"),
			Vector2i(12, 10), 0))).is_equal("no_access")
	# Turned round (door to -x) it is fine, back to back with the bakery.
	assert_str(String(sim.province.placement_error(SimFixture.registry().get_building(&"hut"),
			Vector2i(12, 10), 2))).is_equal("")


func test_building_in_front_of_a_door_is_refused() -> void:
	var sim := SimFixture.make_sim()
	SimFixture.place(sim, &"stockpile", Vector2i(2, 2))
	var hut := sim.province.add_building(SimFixture.registry().get_building(&"hut"), Vector2i(10, 10), true, 1)
	# Mirrored: entrance (11, 11), door to +y.
	assert_vector(hut.door_front_tile()).is_equal(Vector2i(11, 12))
	assert_str(String(sim.province.placement_error(SimFixture.registry().get_building(&"well"),
			Vector2i(11, 12)))).is_equal("blocks_access")
	assert_str(String(sim.province.placement_error(SimFixture.registry().get_building(&"well"),
			Vector2i(12, 10)))).is_equal("")


func test_fishing_hut_turned_away_from_the_river_fits() -> void:
	var registry := SimFixture.registry()
	var sim := Simulation.from_map(registry, registry.get_map(&"riverlands"), 1, PackedStringArray())
	var def := registry.get_building(&"fishing_hut")
	assert_str(String(sim.province.placement_error(def, Vector2i(64, 12), 0))).is_equal("entrance_faces_water")
	assert_str(String(sim.province.placement_error(def, Vector2i(64, 12), 1))).is_equal("")


func test_preview_turns_the_door_to_an_adjacent_road() -> void:
	var sim := SimFixture.make_sim()
	var hut := SimFixture.registry().get_building(&"hut")
	var origin := Vector2i(10, 10)
	assert_int(sim.province.suggested_orientation(hut, origin)).is_equal(-1)
	# A road behind the house (smaller x): the door turns to the back.
	sim.execute(BuildRoadCommand.new([Vector2i(9, 10), Vector2i(9, 11)] as Array[Vector2i]))
	assert_int(sim.province.suggested_orientation(hut, origin)).is_equal(2)
	# A road on the +y side too: the preferred side wins when it has a road.
	sim.execute(BuildRoadCommand.new([Vector2i(10, 12), Vector2i(11, 12)] as Array[Vector2i]))
	assert_int(sim.province.suggested_orientation(hut, origin, 1)).is_equal(1)
	assert_int(sim.province.suggested_orientation(hut, origin, 2)).is_equal(2)
	# A workshop has only the two front sides: the road behind does not count.
	var bakery := SimFixture.registry().get_building(&"bakery")
	assert_int(sim.province.suggested_orientation(bakery, origin)).is_equal(1)


func test_placement_turn_auto_then_by_hand() -> void:
	var sim := SimFixture.make_sim()
	var hut := SimFixture.registry().get_building(&"hut")
	var turn := PlacementTurn.new()
	turn.begin()
	assert_int(turn.update(sim.province, hut, Vector2i(10, 10))).is_equal(0)
	sim.execute(BuildRoadCommand.new([Vector2i(9, 10)] as Array[Vector2i]))
	assert_int(turn.update(sim.province, hut, Vector2i(10, 10))).is_equal(2)
	# R: by hand from here on, roads no longer decide.
	turn.rotate(hut)
	assert_int(turn.orientation).is_equal(3)
	assert_bool(turn.is_manual()).is_true()
	assert_int(turn.update(sim.province, hut, Vector2i(10, 10))).is_equal(3)
	turn.placed()
	# A new tool: automatic again; with no road next to it the last side is kept.
	turn.begin()
	assert_int(turn.update(sim.province, hut, Vector2i(16, 16))).is_equal(3)
	assert_int(turn.update(sim.province, hut, Vector2i(10, 10))).is_equal(2)


func test_orientation_is_saved() -> void:
	var sim := SimFixture.make_sim()
	sim.province.add_building(SimFixture.registry().get_building(&"hut"), Vector2i(10, 10), true, 3)
	var copy := Simulation.from_dict(JSON.parse_string(JSON.stringify(sim.to_dict())), SimFixture.registry())
	var hut := copy.province.buildings.get_building(sim.ids.next_id - 1)
	assert_int(hut.orientation).is_equal(3)
	assert_vector(hut.entrance_tile()).is_equal(Vector2i(10, 10))
	assert_vector(hut.door_front_tile()).is_equal(Vector2i(10, 9))


## Owner's feedback 2026-11-05: houses placed beside a row line up with it, and the end of
## a row with a side street does not turn its side to the row.
func test_preview_lines_up_with_a_row_neighbour() -> void:
	var sim := SimFixture.make_sim()
	var hut := SimFixture.registry().get_building(&"hut")
	SimFixture.place(sim, &"stockpile", Vector2i(2, 2))
	sim.province.add_building(hut, Vector2i(10, 10), true, 2)
	# No road: the neighbour along the row decides.
	assert_int(sim.province.suggested_orientation(hut, Vector2i(10, 12))).is_equal(2)
	# A road in front of the row (x = 9) and a side street (y = 14) at its end: the row wins.
	var roads: Array[Vector2i] = []
	for y: int in range(8, 15):
		roads.append(Vector2i(9, y))
	for x: int in range(9, 14):
		roads.append(Vector2i(x, 14))
	sim.execute(BuildRoadCommand.new(roads))
	assert_int(sim.province.suggested_orientation(hut, Vector2i(10, 12), 1)).is_equal(2)


func test_a_house_without_a_road_turns_to_a_new_road() -> void:
	var sim := SimFixture.make_sim()
	var hut := SimFixture.registry().get_building(&"hut")
	SimFixture.place(sim, &"stockpile", Vector2i(2, 2))
	var lonely := sim.province.add_building(hut, Vector2i(10, 10), true, 0)
	var facing := sim.province.add_building(hut, Vector2i(16, 10), true, 0)
	sim.execute(BuildRoadCommand.new([Vector2i(18, 10), Vector2i(18, 11)] as Array[Vector2i]))
	var someone := SimFixture.spawn(sim, &"porter", lonely.entrance_tile())
	# A road behind both: the lonely house turns to it, the one with a road in front stays.
	var behind: Array[Vector2i] = [Vector2i(9, 10), Vector2i(9, 11), Vector2i(15, 10), Vector2i(15, 11)]
	sim.execute(BuildRoadCommand.new(behind))
	assert_int(lonely.orientation).is_equal(2)
	assert_int(facing.orientation).is_equal(0)
	# Whoever was inside is at the new entrance; the old one is a wall again.
	assert_vector(someone.tile()).is_equal(lonely.entrance_tile())
	assert_bool(sim.province.nav.is_walkable(Vector2i(11, 11))).is_false()
	assert_bool(sim.province.nav.is_walkable(lonely.entrance_tile())).is_true()
	var path := sim.province.find_path(Vector2i(1, 20), lonely.entrance_tile())
	assert_vector(path[-2]).is_equal(Vector2i(9, 10))


func test_chosen_look_is_saved_and_only_for_houses() -> void:
	var sim := SimFixture.make_sim()
	var hut := SimFixture.place(sim, &"hut", Vector2i(10, 10))
	var well := SimFixture.place(sim, &"well", Vector2i(16, 10))
	assert_str(String(sim.execute(SetLookCommand.new(well.id, 1)))).is_equal("not_a_house")
	assert_str(String(sim.execute(SetLookCommand.new(hut.id, 2)))).is_equal("")
	assert_str(String(sim.execute(PlaceBuildingCommand.new(&"hut", Vector2i(10, 16), true, 0, 3)))).is_equal("")
	var copy := Simulation.from_dict(JSON.parse_string(JSON.stringify(sim.to_dict())), SimFixture.registry())
	assert_int(copy.province.buildings.get_building(hut.id).look).is_equal(2)
	assert_int(copy.province.buildings.get_building(sim.ids.next_id - 1).look).is_equal(3)
