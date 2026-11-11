extends GdUnitTestSuite
## M6 part 2 DoD: an expedition of settlers from a province with a town hall reaches an empty
## province, waits at its border, lands when the player comes and sets up camp; by land with
## a wagon to a neighbour, by sea on the player's cog, which then sails home. An island can
## be reached only by sea; without a town hall nothing is sent.
## Since 2026-11-06 (owner's decision) it is prepared with only its kind, waits in town when
## ready, is sent from the world map (gold paid then) and can be disbanded before that.


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
	# E2 part 3: fed and warm houses are calm and take newcomers; none here, so the settlers
	# can be counted.
	sim.province.entry_tile = Vector2i(-1, -1)
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
	var home := WorldSim.FIRST_ID
	var vale := sim.world.id_of(&"willow_vale")
	var residents := _residents(sim.province)
	var wood := sim.province.kingdom_stock(&"wood")
	assert_str(String(sim.execute(PrepareExpeditionCommand.new(home, true)))).is_equal("no_cog")
	assert_str(String(sim.execute(PrepareExpeditionCommand.new(home, false)))).is_empty()
	assert_int(sim.treasury.gold).is_equal(500)   # paid when it is sent
	assert_str(String(sim.execute(PrepareExpeditionCommand.new(home, false)))).is_equal("expedition_gathering")
	assert_str(String(SendExpeditionCommand.error_for(sim, home, vale))).is_equal("expedition_not_ready")
	# Gathering: settlers leave their houses, porters load the wagon; then it waits in town.
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return sim.province.departure.is_ready(), 600)).is_true()
	sim.run_ticks(SimFixture.ticks(20))
	var departure := sim.province.departure
	assert_bool(departure.is_ready()).is_true()
	assert_int(departure.wagon.total_amount()).is_equal(110)
	assert_object(sim.province.agents.get_agent(departure.wagon_agent)).is_not_null()
	assert_bool(sim.world.expeditions.is_empty()).is_true()
	assert_str(String(SendExpeditionCommand.error_for(sim, home, sim.world.id_of(&"salt_isle")))).is_equal("not_a_neighbour")
	var gold := sim.treasury.gold
	assert_str(String(sim.execute(SendExpeditionCommand.new(home, vale)))).is_empty()
	assert_int(sim.treasury.gold).is_equal(gold - Departure.COST)
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return sim.province.departure == null, 300)).is_true()
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
	var home := WorldSim.FIRST_ID
	assert_str(String(SendExpeditionCommand.error_for(sim, home, sim.world.id_of(&"salt_isle")))).is_equal("no_expedition")
	sim.province.departure = Departure.new()   # a ready land expedition, as if gathered
	sim.province.departure.state = Departure.State.READY
	assert_str(String(SendExpeditionCommand.error_for(sim, home, sim.world.id_of(&"salt_isle")))).is_equal("not_a_neighbour")
	assert_str(String(SendExpeditionCommand.error_for(sim, home, sim.world.id_of(&"mirror_lakes")))).is_equal("not_a_neighbour")
	sim.treasury.gold = 0
	assert_str(String(SendExpeditionCommand.error_for(sim, home, sim.world.id_of(&"willow_vale")))).is_equal("not_enough_gold")
	sim.province.departure = null
	sim.treasury.gold = 500
	sim.execute(DemolishCommand.new(sim.province.seat().id))
	assert_str(String(PrepareExpeditionCommand.error_for(sim, home, false))).is_equal("no_town_hall")


## Disbanded while gathering and when ready: the settlers move back in, the kit goes back to
## the storages, no gold is taken.
func test_disbanded_expedition_gives_everything_back() -> void:
	var sim := _land_town()
	var home := WorldSim.FIRST_ID
	var residents := _residents(sim.province)
	assert_str(String(sim.execute(PrepareExpeditionCommand.new(home, false)))).is_empty()
	sim.run_ticks(SimFixture.ticks(8))
	assert_int(_residents(sim.province)).is_less(residents)
	assert_str(String(sim.execute(DisbandExpeditionCommand.new(home)))).is_empty()
	assert_object(sim.province.departure).is_null()
	assert_int(_residents(sim.province)).is_equal(residents)
	# Again, until it is ready; then disbanded: the kit is put down, porters take it back.
	assert_str(String(sim.execute(PrepareExpeditionCommand.new(home, false)))).is_empty()
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return sim.province.departure.is_ready(), 600)).is_true()
	assert_str(String(sim.execute(DisbandExpeditionCommand.new(home)))).is_empty()
	assert_str(String(sim.execute(DisbandExpeditionCommand.new(home)))).is_equal("no_expedition")
	assert_int(_residents(sim.province)).is_equal(residents)
	assert_int(_on_piles(sim.province, &"wood")).is_equal(Departure.KIT[&"wood"])
	assert_int(_on_piles(sim.province, &"bread")).is_equal(Departure.KIT[&"bread"])
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return _on_piles(sim.province, &"wood") + _on_piles(sim.province, &"bread") == 0, 600)).is_true()
	assert_int(sim.treasury.gold).is_greater_equal(500)   # taxes come in; nothing was paid
	assert_array(Array(sim.province.dangling_holds())).is_empty()
	for agent: Agent in sim.province.agents.all():
		assert_str(String(agent.kind)).is_not_equal(String(Departure.SETTLER_KIND))
		assert_str(String(agent.vehicle)).is_not_equal(String(Carriers.SETTLER_WAGON))


func _on_piles(province: ProvinceSim, good: StringName) -> int:
	var sum := 0
	for pile: GroundPile in province.piles.values():
		sum += pile.stock.total(good)
	return sum


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
	sim.province.entry_tile = Vector2i(-1, -1)   # no newcomers (E2 part 3): settlers are counted
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
	assert_str(String(sim.execute(PrepareExpeditionCommand.new(WorldSim.FIRST_ID, true)))).is_empty()
	assert_int(cog.voyage.expedition).is_not_equal(0)
	# Settlers walk to the port, the kit goes aboard; the cog waits moored until it is sent.
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return sim.province.departure.is_ready(), 900)).is_true()
	sim.run_ticks(SimFixture.ticks(20))
	assert_int(cog.voyage.state).is_equal(Voyage.State.LOADING)
	assert_int(cog.hold.total_amount()).is_equal(110)
	assert_str(String(sim.execute(SendExpeditionCommand.new(WorldSim.FIRST_ID, coast)))).is_empty()
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
	assert_str(String(sim.execute(PrepareExpeditionCommand.new(WorldSim.FIRST_ID, false)))).is_empty()
	sim.run_ticks(SimFixture.ticks(10))
	# The player looks elsewhere: Mirror Lakes settled for the test, entered.
	sim.open_province(lakes, _registry().get_map(&"lakeland"))
	assert_str(String(sim.execute(EnterProvinceCommand.new(lakes)))).is_empty()
	sim.run_ticks(SimFixture.ticks(5))
	# Nobody looks: it is ready at once, and sent from the world map it is gone at once.
	var home := sim.province_state(WorldSim.FIRST_ID)
	assert_bool(home.departure.is_ready()).is_true()
	assert_str(String(sim.execute(SendExpeditionCommand.new(WorldSim.FIRST_ID, vale)))).is_empty()
	sim.run_ticks(SimFixture.ticks(5))
	assert_object(home.departure).is_null()
	var e := sim.world.expedition_to(vale)
	assert_object(e).is_not_null()
	var state := sim.to_dict()
	var loaded := Simulation.from_dict(JSON.parse_string(JSON.stringify(state, "", false, true)), _registry())
	assert_str(SimCodec.canonical(loaded.to_dict())).is_equal(SimCodec.canonical(state))


## A sea expedition disbanded at the quay: the kit is unloaded back to storages and the cog
## returns to anchor with its usual hold; one prepared in a province nobody looks at and
## disbanded there gives everything back at once.
func test_sea_expedition_disbanded_and_one_far_away() -> void:
	var scene := _sea_town()
	var sim: Simulation = scene["sim"]
	var cog: ShipUnit = scene["cog"]
	var wood := sim.province.kingdom_stock(&"wood")
	assert_str(String(sim.execute(PrepareExpeditionCommand.new(WorldSim.FIRST_ID, true)))).is_empty()
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return sim.province.departure.is_ready(), 900)).is_true()
	assert_str(String(sim.execute(DisbandExpeditionCommand.new(WorldSim.FIRST_ID)))).is_empty()
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return cog.voyage.state == Voyage.State.IDLE and cog.hold.is_empty() \
				and sim.province.stored(&"wood") >= wood, 900)).is_true()
	assert_int(cog.voyage.expedition).is_equal(0)
	assert_int(cog.hold.slot_count()).is_equal(cog.def.hold_slots)
	assert_int(sim.province.kingdom_stock(&"wood")).is_equal(wood)
	# The same far away: the town is frozen while the player looks at Mirror Lakes.
	var lakes := sim.world.id_of(&"mirror_lakes")
	sim.open_province(lakes, _registry().get_map(&"lakeland"))
	assert_str(String(sim.execute(EnterProvinceCommand.new(lakes)))).is_empty()
	var home := sim.province_state(WorldSim.FIRST_ID)
	var residents := _residents(home)
	assert_str(String(sim.execute(PrepareExpeditionCommand.new(WorldSim.FIRST_ID, true)))).is_empty()
	sim.run_ticks(SimFixture.ticks(3))
	assert_bool(home.departure.is_ready()).is_true()
	assert_int(_residents(home)).is_equal(residents - Departure.SETTLERS.size())
	assert_str(String(sim.execute(DisbandExpeditionCommand.new(WorldSim.FIRST_ID)))).is_empty()
	sim.run_ticks(SimFixture.ticks(3))
	assert_int(_residents(home)).is_equal(residents)
	assert_int(home.kingdom_stock(&"wood")).is_equal(wood)
	assert_bool(cog.hold.is_empty()).is_true()
	assert_int(cog.voyage.state).is_equal(Voyage.State.IDLE)
