extends GdUnitTestSuite
## M6 part 1: switching a province between the detailed and the simplified mode
## (ARCHITECTURE §7.2) loses no goods, leaves nothing reserved and plays on, on every save
## fixture and on the big city.

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


func test_leaving_during_the_landing_puts_everybody_ashore() -> void:
	var sim := Simulation.from_map(SimFixture.registry(), SimFixture.registry().get_map(&"coast"))
	sim.run_ticks(SimFixture.ticks(20))
	var before := KingdomGoods.of(sim.province)
	var abstract := ProvinceAbstract.freeze(sim.province, sim.clock.tick)
	assert_dict(KingdomGoods.of(abstract.detail)).is_equal(before)
	assert_int(abstract.wanderers.size()).is_equal(6)
	for ship: ShipUnit in abstract.detail.ships.values():
		assert_str(String(ship.def.id)).is_not_equal("settler_cog")
	var province := abstract.thaw(sim.clock.tick, sim.events)
	assert_int(province.agents.count()).is_equal(6)
	assert_int(province.landing.settlers.size()).is_equal(6)
	sim.runtimes[sim.viewed_id] = province
	sim.province = province
	sim.run_ticks(SimFixture.ticks(30))
	assert_array(Array(province.dangling_holds())).is_empty()


## Two provinces: entering the second freezes the first, and back again; the goods of both
## stay theirs.
func test_entering_another_province_switches_modes() -> void:
	var registry := SimFixture.registry()
	var sim := Simulation.from_map(registry, registry.get_map(&"riverlands"))
	sim.run_ticks(SimFixture.ticks(120))
	assert_array(Array(sim.open_province(2, registry.get_map(&"lakeland")))).is_empty()
	assert_bool(sim.is_detailed(1)).is_true()
	assert_bool(sim.is_detailed(2)).is_false()
	sim.run_ticks(SimFixture.ticks(60))
	var first := KingdomGoods.of(sim.province)
	var second := KingdomGoods.of(sim.province_state(2))
	assert_bool(sim.execute(EnterProvinceCommand.new(2)) == &"").is_true()
	assert_int(sim.viewed_id).is_equal(2)
	assert_bool(sim.is_detailed(2)).is_true()
	assert_dict(KingdomGoods.of(sim.province_state(1))).is_equal(first)
	assert_dict(KingdomGoods.of(sim.province)).is_equal(second)
	assert_int(sim.province_state(1).agents.count()).is_equal(0)
	sim.run_ticks(SimFixture.ticks(30))
	assert_int(sim.province.agents.count()).is_greater(0)
	# The whole world saves and loads in both modes.
	var state := sim.to_dict()
	var loaded := Simulation.from_dict(JSON.parse_string(JSON.stringify(state, "", false, true)), registry)
	assert_str(SimCodec.canonical(loaded.to_dict())).is_equal(SimCodec.canonical(state))
	assert_bool(sim.execute(EnterProvinceCommand.new(1)) == &"").is_true()
	assert_bool(sim.is_detailed(1)).is_true()
	sim.run_ticks(SimFixture.ticks(30))
	assert_array(Array(sim.province.dangling_holds())).is_empty()
	assert_str(String(sim.execute(EnterProvinceCommand.new(5)))).is_equal("unknown_province")


func _residents(province: ProvinceSim) -> int:
	var sum := 0
	for b: BuildingState in province.buildings.all():
		if b.house != null:
			sum += b.house.residents + b.house.incoming
	return sum
