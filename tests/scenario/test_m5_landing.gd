extends GdUnitTestSuite
## M5 part 3 DoD: the start from a ship on the Coast map. A cog comes in over the sea edge,
## drops anchor off the beach, six settlers wade ashore and the start kit lies on the beach;
## only the pioneer camp can be placed until it is; the camp takes its builder and porters
## from the settlers, the others carry until a hut stands and then move in; the ship sails
## away. Saves during the landing play on alike.


func _new_game(seed_value: int = 1) -> Simulation:
	var registry := SimFixture.registry()
	var problems := PackedStringArray()
	var sim := Simulation.from_map(registry, registry.get_map(&"coast"), seed_value, problems)
	assert_array(Array(problems)).is_empty()
	return sim


## The free spot nearest to [param near] for [param id] (with a free tile around it).
func _spot(sim: Simulation, id: StringName, near: Vector2i) -> Vector2i:
	var def := sim.data.get_building(id)
	for r: int in 20:
		for y: int in range(near.y - r, near.y + r + 1):
			for x: int in range(near.x - r, near.x + r + 1):
				if maxi(absi(x - near.x), absi(y - near.y)) != r:
					continue
				var origin := Vector2i(x, y)
				if sim.province.placement_error(def, origin) != &"":
					continue
				var free := true
				for ty: int in range(y - 1, y + def.footprint.y + 1):
					for tx: int in range(x - 1, x + def.footprint.x + 1):
						if sim.province.grid.occupant(Vector2i(tx, ty)) != 0 \
								or not sim.province.nav.is_walkable(Vector2i(tx, ty)):
							free = false
				if free:
					return origin
	return Agent.NO_TILE


func _place(sim: Simulation, id: StringName, near: Vector2i) -> BuildingState:
	var spot := _spot(sim, id, near)
	assert_vector(spot).is_not_equal(Agent.NO_TILE)
	assert_str(String(sim.execute(PlaceBuildingCommand.new(id, spot)))).is_empty()
	return sim.province.buildings.get_building(sim.province.grid.occupant(spot))


func test_settlers_land_from_the_ship_and_build_the_pioneer_camp() -> void:
	var sim := _new_game()
	var province := sim.province
	var landing := province.landing
	assert_object(landing).is_not_null()
	assert_int(province.buildings.count()).is_equal(0)
	assert_int(province.agents.count()).is_equal(0)
	var ship := province.ships[landing.ship_id] as ShipUnit
	var at := ship.tile()
	assert_bool(at.x == 0 or at.y == 0 or at.x == 127 or at.y == 127).is_true()
	# Only the pioneer camp can be placed first.
	var beach := landing.beach
	assert_str(String(province.placement_error(sim.data.get_building(&"stockpile"), beach + Vector2i(-8, -4)))) \
			.is_equal("build_camp_first")
	# The ship anchors, six settlers wade ashore and the kit lies on the beach.
	var waded := {"seen": false}
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		for agent: Agent in province.agents.all():
			if agent.task != null and agent.task.kind == Task.KIND_LAND \
					and province.sail_depth(agent.tile()) > 0:
				waded["seen"] = true
		return landing.state == Landing.State.LEAVING, 400)).is_true()
	assert_bool(waded["seen"]).is_true()
	assert_int(province.agents.count()).is_equal(6)
	assert_int(province.kingdom_stock(&"wood")).is_equal(90)
	assert_int(province.kingdom_stock(&"bread")).is_equal(20)
	for pile: GroundPile in province.piles.values():
		assert_int((pile.tile - beach).length_squared()).is_less_equal(32)
	# The camp first; a second one is refused.
	var camp := _place(sim, &"pioneer_camp", beach + Vector2i(-7, -3))
	assert_str(String(province.placement_error(sim.data.get_building(&"pioneer_camp"), beach + Vector2i(-14, -8)))) \
			.is_equal("only_one")
	assert_bool(SimFixture.run_until(sim, func() -> bool: return camp.is_complete(), 300)).is_true()
	sim.run_ticks(SimFixture.ticks(2))
	# The builder and two porters work for the camp; the ship is gone.
	assert_int(camp.workers.size()).is_equal(3)
	assert_bool(SimFixture.run_until(sim, func() -> bool: return not province.ships.has(landing.ship_id), 300)).is_true()
	# Then a storage and huts: the other settlers move in.
	_place(sim, &"stockpile", camp.origin + Vector2i(5, 0))
	var huts: Array[BuildingState] = []
	for i: int in 3:
		huts.append(_place(sim, &"hut", camp.origin + Vector2i(-1 + 3 * i, 5)))
	assert_bool(SimFixture.run_until(sim, func() -> bool: return province.landing == null, 900)).is_true()
	var residents := 0
	for hut: BuildingState in huts:
		residents += hut.house.residents
	print("landing over at tick ", province.tick, "; residents ", residents)
	assert_int(residents).is_greater_equal(3)
	assert_array(Array(province.dangling_holds())).is_empty()


func test_save_during_the_landing_continues_alike() -> void:
	var sim := _new_game(2)
	var province := sim.province
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		for agent: Agent in province.agents.all():
			if agent.task != null and agent.task.kind == Task.KIND_LAND and int(agent.task.bb["t"]) > 5:
				return true
		return false, 400)).is_true()
	var copy := Simulation.from_dict(JSON.parse_string(JSON.stringify(sim.to_dict(), "", true, true)),
			SimFixture.registry())
	assert_str(SimCodec.canonical(copy.to_dict())).is_equal(SimCodec.canonical(sim.to_dict()))
	for i: int in SimFixture.ticks(60):
		sim.step()
		copy.step()
		sim.events.drain()
		copy.events.drain()
	assert_str(SimCodec.canonical(copy.to_dict())).is_equal(SimCodec.canonical(sim.to_dict()))
