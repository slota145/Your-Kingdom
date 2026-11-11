extends GdUnitTestSuite
## Moved from test_m6_modes.gd (speed-up 2026-11-11).


const FIXTURES: Array[String] = ["v1_woodcutter", "v2_village", "v3_town", "v4_town", "v5_town",
		"v6_town", "v7_town", "v8_town", "v9_harbour", "v10_port", "v11_voyage", "v12_world", "v13_expedition",
		"v14_routes", "v15_quays", "v16_crane", "big_city"]

func _load(name: String) -> Simulation:
	var document: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://tests/fixtures/saves/%s.json" % name))
	var state := SaveMigrations.migrate(document["state"], int(document["header"]["save_version"]))
	return Simulation.from_dict(state, SimFixture.registry())

func test_leaving_and_entering_loses_no_goods_on_every_fixture() -> void:
	for name: String in FIXTURES:
		var sim := _load(name)
		var province := sim.province
		var before := KingdomGoods.of(province)
		var residents := _residents(province)
		var abstract := ProvinceAbstract.freeze(province, sim.clock.tick)
		assert_int(province.agents.count()).override_failure_message(name).is_equal(0)
		assert_dict(KingdomGoods.of(province)).override_failure_message(name + " frozen").is_equal(before)
		assert_int(province.reservation_count()).override_failure_message(name).is_equal(0)
		assert_array(Array(province.dangling_holds())).override_failure_message(name).is_empty()
		assert_int(_residents(province)).override_failure_message(name).is_greater_equal(residents)
		# A round trip through the save keeps the simplified province as it is.
		var saved := abstract.to_dict()
		abstract = ProvinceAbstract.from_dict(JSON.parse_string(JSON.stringify(saved, "", false, true)),
				SimFixture.registry(), sim.ids, sim.treasury)
		assert_str(SimCodec.canonical(abstract.to_dict())).override_failure_message(name) \
				.is_equal(SimCodec.canonical(saved))
		province = abstract.thaw(sim.clock.tick, sim.events)
		assert_dict(KingdomGoods.of(province)).override_failure_message(name + " thawed").is_equal(before)
		sim.runtimes[sim.viewed_id] = province
		sim.province = province
		sim.run_ticks(SimFixture.ticks(60))
		assert_array(Array(province.dangling_holds())).override_failure_message(name + " later").is_empty()

func _residents(province: ProvinceSim) -> int:
	var sum := 0
	for b: BuildingState in province.buildings.all():
		if b.house != null:
			sum += b.house.residents + b.house.incoming
	return sum
