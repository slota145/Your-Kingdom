extends GdUnitTestSuite
## M6 part 2 DoD: an expedition of settlers from a province with a town hall reaches an empty
## province, waits at its border, lands when the player comes and sets up camp; by land with
## a wagon to a neighbour, by sea on the player's cog, which then sails home. An island can
## be reached only by sea; without a town hall nothing is sent.


func _registry() -> DataRegistry:
	return SimFixture.registry()


## The Riverlands town playing Landing Bay in the world, with the start kit in store.
func _land_town() -> Simulation:
	var registry := _registry()
	var sim := Simulation.from_map(registry, registry.get_map(&"riverlands"))
	sim.world = WorldSim.from_def(registry.get_world(&"kingdom"), registry)
	sim.world.get_province(WorldSim.FIRST_ID).owner = ProvinceDef.OWNER_PLAYER
	for b: BuildingState in sim.province.buildings.all():
		if b.def.id == &"stockpile":
			b.stock.add(&"wood", 100)
			b.stock.add(&"bread", 30)
	sim.treasury.gold = 500
	# Porters without a house: the settlers leaving do not take them away mid-test.
	for i: int in 4:
		SimFixture.spawn(sim, JobBoard.PORTER_KIND, sim.province.seat().entrance_tile())
	return sim


func _residents(province: ProvinceSim) -> int:
	var sum := 0
	for b: BuildingState in province.buildings.all():
		if b.house != null:
			sum += b.house.residents
	return sum


func test_expedition_by_land_reaches_a_neighbour() -> void:
	var sim := _land_town()
	var vale := sim.world.id_of(&"willow_vale")
	var residents := _residents(sim.province)
	var wood := sim.province.kingdom_stock(&"wood")
	assert_str(String(sim.execute(SendExpeditionCommand.new(vale, true)))).is_equal("no_sea_route")
	assert_str(String(sim.execute(SendExpeditionCommand.new(vale, false)))).is_empty()
	assert_int(sim.treasury.gold).is_equal(500 - Departure.COST)
	assert_str(String(sim.execute(SendExpeditionCommand.new(vale, false)))).is_equal("province_taken")
	# Gathering: settlers leave their houses, porters load the wagon, then they all drive off.
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return sim.province.departure == null, 600)).is_true()
	assert_int(_residents(sim.province)).is_less_equal(residents - Departure.SETTLERS.size() + 2)
	assert_int(sim.province.kingdom_stock(&"wood")).is_less_equal(wood - Departure.KIT[&"wood"])
	assert_array(Array(sim.province.dangling_holds())).is_empty()
	var e := sim.world.expedition_to(vale)
	assert_object(e).is_not_null()
	assert_int(e.state).is_equal(Expedition.State.TRAVELLING)
	assert_dict(e.kit).is_equal(Departure.KIT)
	# It travels about three minutes and waits at the border for the player.
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return e.state == Expedition.State.WAITING, 260)).is_true()
	sim.run_ticks(SimFixture.ticks(30))
	assert_int(e.state).is_equal(Expedition.State.WAITING)
	assert_bool(sim.runtimes.has(vale)).is_false()
	assert_str(String(sim.execute(EnterProvinceCommand.new(vale)))).is_empty()
	assert_int(sim.viewed_id).is_equal(vale)
	assert_str(String(sim.world.owner_of(vale))).is_equal("player")
	var vale_sim := sim.province
	assert_object(vale_sim.landing).is_not_null()
	assert_str(String(vale_sim.first_building)).is_equal("pioneer_camp")
	assert_int(vale_sim.buildings.count()).is_equal(0)
	# The wagon reaches the camp site, the kit lies there, the wagon goes; the expedition ends.
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return not sim.world.expeditions.has(e.id), 200)).is_true()
	assert_int(vale_sim.kingdom_stock(&"wood")).is_equal(Departure.KIT[&"wood"])
	assert_int(vale_sim.kingdom_stock(&"bread")).is_equal(Departure.KIT[&"bread"])
	assert_int(vale_sim.landing.settlers.size()).is_equal(Departure.SETTLERS.size())
	# The camp can be placed; the settlers build it.
	assert_array(Array(vale_sim.dangling_holds())).is_empty()
	# Back home: the old town in detail again, the new one goes on without people.
	assert_str(String(sim.execute(EnterProvinceCommand.new(WorldSim.FIRST_ID)))).is_empty()
	sim.run_ticks(SimFixture.ticks(30))
	assert_int(sim.province_state(vale).agents.count()).is_equal(0)


func test_no_expedition_without_a_town_hall_and_none_by_land_to_an_island() -> void:
	var sim := _land_town()
	var isle := sim.world.id_of(&"salt_isle")
	assert_str(String(SendExpeditionCommand.error_for(sim, isle, false))).is_equal("not_a_neighbour")
	assert_str(String(SendExpeditionCommand.error_for(sim, isle, true))).is_equal("no_cog")
	var vale := sim.world.id_of(&"willow_vale")
	sim.execute(DemolishCommand.new(sim.province.seat().id))
	assert_str(String(SendExpeditionCommand.error_for(sim, vale, false))).is_equal("no_town_hall")
	var lakes := sim.world.id_of(&"mirror_lakes")
	assert_str(String(SendExpeditionCommand.error_for(sim, lakes, false))).is_equal("not_a_neighbour")


## 48x48 coast town with a port and the player's cog at anchor (as in test_m5_voyage).
func _sea_town() -> Dictionary:
	var sim := SimFixture.make_sim(Vector2i(48, 48))
	sim.world = WorldSim.from_def(_registry().get_world(&"kingdom"), _registry())
	sim.world.get_province(WorldSim.FIRST_ID).owner = ProvinceDef.OWNER_PLAYER
	SimFixture.coast(sim, 30, 33)
	SimFixture.village(sim, 200, 150)
	for i: int in 4:
		SimFixture.house(sim, Vector2i(2 + 3 * i, 12))
	sim.treasury.gold = 500
	var port := SimFixture.place(sim, &"port", Vector2i(20, 28))
	var shipyard := SimFixture.place(sim, &"shipyard", Vector2i(30, 28))
	for kind: StringName in [Harbour.DOCKER_KIND, Harbour.DOCKER_KIND]:
		var docker := SimFixture.spawn(sim, kind, port.entrance_tile())
		assert_str(String(sim.execute(AssignWorkerCommand.new(docker.id, port.id)))).is_empty()
	for i: int in 8:
		SimFixture.spawn(sim, JobBoard.PORTER_KIND, Vector2i(16, 20))
	sim.province.sea_merchant.next_visit = 1 << 30
	var cog := Ships.launch(sim.province, sim.data.get_ship(&"cog"), shipyard)
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return cog.home_id != 0 and cog.tile() == cog.voyage.anchor \
				and cog.path_state != ShipUnit.PathState.MOVING, 120)).is_true()
	return {"sim": sim, "cog": cog, "port": port}


func test_expedition_by_sea_lands_and_the_cog_comes_home() -> void:
	var scene := _sea_town()
	var sim: Simulation = scene["sim"]
	var cog: ShipUnit = scene["cog"]
	var coast := sim.world.id_of(&"amber_coast")
	assert_str(String(sim.execute(SendExpeditionCommand.new(coast, true)))).is_empty()
	assert_int(cog.voyage.expedition).is_not_equal(0)
	# Settlers walk to the port, the kit goes aboard, the cog sails over the horizon.
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return sim.province.departure == null, 900)).is_true()
	assert_bool(cog.is_away()).is_true()
	assert_bool(cog.hold.is_empty()).is_true()
	var e := sim.world.expedition_to(coast)
	assert_object(e).is_not_null()
	assert_bool(e.by_sea).is_true()
	assert_dict(e.kit).is_equal(Departure.KIT)
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return e.state == Expedition.State.WAITING, 400)).is_true()
	assert_str(String(sim.execute(EnterProvinceCommand.new(coast)))).is_empty()
	var settled := sim.province
	assert_object(settled.landing).is_not_null()
	assert_bool(settled.landing.by_land).is_false()
	# The settlers wade ashore; the ship leaves; the cog is called home.
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return e.state == Expedition.State.RETURNING, 300)).is_true()
	assert_int(settled.kingdom_stock(&"wood")).is_equal(Departure.KIT[&"wood"])
	sim.execute(EnterProvinceCommand.new(WorldSim.FIRST_ID))
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return cog.voyage.state == Voyage.State.IDLE and cog.voyage.expedition == 0, 700)).is_true()
	assert_bool(sim.world.expeditions.is_empty()).is_true()


## Sent and then left alone: the province not viewed gathers at once, and the save keeps the
## world with its expedition.
func test_expedition_from_a_province_nobody_looks_at() -> void:
	var sim := _land_town()
	var vale := sim.world.id_of(&"willow_vale")
	var lakes := sim.world.id_of(&"mirror_lakes")
	assert_str(String(sim.execute(SendExpeditionCommand.new(vale, false)))).is_empty()
	sim.run_ticks(SimFixture.ticks(10))
	# The player looks elsewhere: Mirror Lakes settled for the test, entered.
	sim.open_province(lakes, _registry().get_map(&"lakeland"))
	assert_str(String(sim.execute(EnterProvinceCommand.new(lakes)))).is_empty()
	sim.run_ticks(SimFixture.ticks(5))
	assert_object(sim.province_state(WorldSim.FIRST_ID).departure).is_null()
	var e := sim.world.expedition_to(vale)
	assert_object(e).is_not_null()
	var state := sim.to_dict()
	var loaded := Simulation.from_dict(JSON.parse_string(JSON.stringify(state, "", false, true)), _registry())
	assert_str(SimCodec.canonical(loaded.to_dict())).is_equal(SimCodec.canonical(state))
