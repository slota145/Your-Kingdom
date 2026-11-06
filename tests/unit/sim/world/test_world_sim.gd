extends GdUnitTestSuite
## The world layer (M6 part 1): a single-map game is a world with one province, saves from
## before M6 load as such a world, and the world round-trips.


func test_single_map_game_is_a_world_with_one_province() -> void:
	var sim := Simulation.from_map(SimFixture.registry(), SimFixture.registry().get_map(&"riverlands"))
	assert_bool(sim.world.is_single()).is_true()
	assert_array(sim.runtime_ids()).is_equal([WorldSim.FIRST_ID])
	assert_int(sim.viewed_id).is_equal(WorldSim.FIRST_ID)
	assert_object(sim.province).is_same(sim.runtimes[WorldSim.FIRST_ID])
	assert_str(String(sim.world.get_province(WorldSim.FIRST_ID).map_id)).is_equal("riverlands")
	assert_str(String(sim.world.owner_of(WorldSim.FIRST_ID))).is_equal("player")


func test_v11_save_becomes_a_world_with_one_province() -> void:
	var document: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://tests/fixtures/saves/v11_voyage.json"))
	var state := SaveMigrations.migrate(document["state"], 11)
	assert_bool(state.has("province")).is_false()
	assert_int((state["provinces"] as Array).size()).is_equal(1)
	var sim := Simulation.from_dict(state, SimFixture.registry())
	assert_bool(sim.world.is_single()).is_true()
	assert_bool(sim.is_detailed(WorldSim.FIRST_ID)).is_true()
	assert_str(SimCodec.canonical(sim.to_dict())).is_equal(SimCodec.canonical(state))


func test_world_round_trips() -> void:
	var world := WorldSim.single(&"coast")
	world.provinces[2] = WorldProvince.new(2, &"x", &"lakeland", ProvinceDef.OWNER_NEUTRAL)
	var copy := WorldSim.from_dict(world.to_dict())
	assert_dict(copy.to_dict()).is_equal(world.to_dict())
	assert_str(String(copy.owner_of(2))).is_equal("neutral")


func test_kingdom_world_has_nine_consistent_provinces() -> void:
	var registry := SimFixture.registry()
	var world := registry.get_world(&"kingdom")
	assert_object(world).is_not_null()
	assert_int(world.provinces.size()).is_equal(9)
	assert_bool(world.provinces.has(world.start_province)).is_true()
	var empty := 0
	for id: StringName in world.provinces:
		var def := registry.get_province(id)
		assert_object(def).override_failure_message(String(id)).is_not_null()
		assert_bool(registry.get_map(def.template) != null) \
				.override_failure_message("template of %s" % id).is_true()
		assert_int(def.outline.size()).is_greater_equal(3)
		assert_bool(Geometry2D.is_point_in_polygon(def.world_pos, def.outline)) \
				.override_failure_message("town of %s outside its border" % id).is_true()
		for other: StringName in def.neighbours:
			assert_bool(registry.get_province(other).neighbours.has(id)) \
					.override_failure_message("%s - %s" % [id, other]).is_true()
		if def.island:
			assert_bool(def.coastal and def.neighbours.is_empty()).is_true()
		if def.owner == ProvinceDef.OWNER_NONE:
			empty += 1
	assert_int(empty).is_equal(7)
	assert_str(String(registry.get_province(&"vine_hills").rare_resource)).is_equal("vines")


func test_journeys_take_minutes() -> void:
	var registry := SimFixture.registry()
	var world := WorldSim.from_def(registry.get_world(&"kingdom"), registry)
	var start := world.id_of(&"landing_bay")
	# A wagon to a land neighbour: about 3 minutes.
	var wagon := world.travel_seconds(start, world.id_of(&"willow_vale"), false, registry)
	assert_float(wagon).is_between(120.0, 240.0)
	# A cog between ports: 3-6 minutes.
	for other: StringName in [&"amber_coast", &"gull_isle", &"salt_isle", &"horse_haven"]:
		var sail := world.travel_seconds(start, world.id_of(other), true, registry)
		assert_float(sail).override_failure_message(String(other)).is_between(150.0, 380.0)
	# No wagon to an island, no ship inland.
	assert_float(world.travel_seconds(start, world.id_of(&"gull_isle"), false, registry)).is_equal(-1.0)
	assert_float(world.travel_seconds(start, world.id_of(&"willow_vale"), true, registry)).is_equal(-1.0)


func test_new_game_starts_in_the_world() -> void:
	var registry := SimFixture.registry()
	var sim := Simulation.from_world(registry, registry.get_world(&"kingdom"))
	assert_object(sim).is_not_null()
	assert_bool(sim.world.is_single()).is_false()
	assert_int(sim.world.provinces.size()).is_equal(9)
	var start := sim.world.id_of(&"landing_bay")
	assert_int(sim.viewed_id).is_equal(start)
	assert_array(sim.runtime_ids()).is_equal([start])
	assert_object(sim.province.landing).is_not_null()
	assert_str(String(sim.world.owner_of(sim.world.id_of(&"iron_wold")))).is_equal("neutral")
	assert_str(String(sim.world.owner_of(sim.world.id_of(&"willow_vale")))).is_equal("")
	# Entering a province nobody settled is refused.
	assert_str(String(sim.execute(EnterProvinceCommand.new(sim.world.id_of(&"willow_vale"))))) \
			.is_equal("unknown_province")
	sim.run_ticks(SimFixture.ticks(30))
	var state := sim.to_dict()
	var loaded := Simulation.from_dict(JSON.parse_string(JSON.stringify(state, "", false, true)), registry)
	assert_str(SimCodec.canonical(loaded.to_dict())).is_equal(SimCodec.canonical(state))


## M6 part 1 world (v12): Landing Bay viewed during the landing, Willow Vale settled in the
## simplified mode; loads unchanged and both play on.
func test_v12_fixture_loads_and_continues() -> void:
	var document: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://tests/fixtures/saves/v12_world.json"))
	assert_int(int(document["header"]["save_version"])).is_equal(12)
	var state := SaveMigrations.migrate(document["state"], 12)
	var sim := Simulation.from_dict(state, SimFixture.registry())
	assert_str(SimCodec.canonical(sim.to_dict())).is_equal(SimCodec.canonical(state))
	var vale := sim.world.id_of(&"willow_vale")
	assert_bool(sim.is_detailed(sim.world.id_of(&"landing_bay"))).is_true()
	assert_bool(sim.is_detailed(vale)).is_false()
	var residents := WorldMapScreen._residents(sim.province_state(vale))
	assert_int(residents).is_greater(0)
	sim.run_ticks(SimFixture.ticks(120))
	assert_array(Array(sim.province.dangling_holds())).is_empty()
	assert_int(sim.province_state(vale).agents.count()).is_equal(0)


## M6 part 2 (v13): one expedition on its way to Willow Vale, a second one gathering for
## Amber Coast; loads unchanged, both go on.
func test_v13_fixture_loads_and_continues() -> void:
	var document: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://tests/fixtures/saves/v13_expedition.json"))
	assert_int(int(document["header"]["save_version"])).is_equal(13)
	var state := SaveMigrations.migrate(document["state"], 13)
	var sim := Simulation.from_dict(state, SimFixture.registry())
	assert_str(SimCodec.canonical(sim.to_dict())).is_equal(SimCodec.canonical(state))
	assert_int(sim.world.expeditions.size()).is_equal(1)
	assert_object(sim.province.departure).is_not_null()
	var coast := sim.world.id_of(&"amber_coast")
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return sim.world.expedition_to(coast) != null, 600)).is_true()
	assert_array(Array(sim.province.dangling_holds())).is_empty()


func test_v12_save_migrates_to_v13() -> void:
	var document: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://tests/fixtures/saves/v12_world.json"))
	var state := SaveMigrations.migrate(document["state"], 12)
	var sim := Simulation.from_dict(state, SimFixture.registry())
	assert_bool(sim.world.expeditions.is_empty()).is_true()
	assert_object(sim.province.departure).is_null()
