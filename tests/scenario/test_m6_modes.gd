extends GdUnitTestSuite
## M6 part 1: switching a province between the detailed and the simplified mode
## (ARCHITECTURE §7.2) loses no goods, leaves nothing reserved and plays on, on every save
## fixture and on the big city.

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

