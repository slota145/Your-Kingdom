extends GdUnitTestSuite
## P2 part 2: soldiers go aboard a warship with a right click: the ship sails to a free berth
## (here a bollard), moors, takes them aboard and goes back to anchor; landing them works the
## other way round. Soldiers aboard move with the ship and cannot be commanded.


## 48x48: land above row 30, shallow sea rows 30-32, deep from row 33; a stone quay strip
## (10..21, 30..31) with a bollard at (16, 31) (berth (16, 32)); a warship at anchor and four
## spearmen on land.
func _scene() -> Dictionary:
	var sim := SimFixture.make_sim(Vector2i(48, 48), 1)
	SimFixture.coast(sim, 30, 33)
	var province := sim.province
	for y: int in range(30, 32):
		for x: int in range(10, 22):
			province.grid.set_quay(Vector2i(x, y), TileGrid.STONE_QUAY)
			province.refresh_tile(Vector2i(x, y))
	province.refresh_fairways()
	var bollard := SimFixture.place(sim, &"bollard", Vector2i(16, 31))
	var ship := ShipUnit.new(province.ids.take(), sim.data.get_ship(&"warship"), IsoMath.tile_center(Vector2i(24, 40)), sim.data)
	province.ships[ship.id] = ship
	var squad: Array[Agent] = []
	for i: int in 4:
		var agent := province.spawn_agent(&"spearman", Vector2i(13 + i, 25))
		agent.combat = CombatState.new(sim.data.get_unit(&"spearman").combat.hp)
		squad.append(agent)
	return {"sim": sim, "bollard": bollard, "ship": ship, "squad": squad}


func _ids(agents: Array) -> Array[int]:
	var ids: Array[int] = []
	for agent: Agent in agents:
		ids.append(agent.id)
	return ids


func test_soldiers_board_a_warship_at_a_bollard_and_land_again() -> void:
	var s := _scene()
	var sim: Simulation = s["sim"]
	var ship: ShipUnit = s["ship"]
	var bollard: BuildingState = s["bollard"]
	var squad: Array = s["squad"]
	assert_str(String(sim.execute(BoardShipCommand.new(_ids(squad), ship.id)))).is_empty()
	assert_int(ship.boarding.size()).is_equal(4)
	# It sails in, moors at the bollard, and the soldiers go aboard.
	var moored := [false]
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		moored[0] = moored[0] or (ship.is_moored() and ship.dock_id == bollard.id)
		return ship.troops.size() == 4, 300)).is_true()
	assert_bool(moored[0]).is_true()
	for agent: Agent in squad:
		assert_str(String(agent.vehicle)).is_equal(String(Ships.ABOARD))
		assert_bool(Troops.is_soldier(sim.province, agent)).is_false()
	# Then back to anchor: the berth is free again; the soldiers sail with it.
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return ship.berth_id == 0 and not ship.is_moored() and ship.path_state == ShipUnit.PathState.ARRIVED, 120)).is_true()
	assert_object(Harbour.berth_holder(sim.province, bollard)).is_null()
	for agent: Agent in squad:
		assert_float(agent.pos.distance_to(ship.pos)).is_less(0.01)
	# Saved and loaded alike.
	var state := sim.to_dict()
	var copy := Simulation.from_dict(state, SimFixture.registry())
	assert_str(SimCodec.canonical(copy.to_dict())).is_equal(SimCodec.canonical(state))
	# Landing: back to the bollard, the soldiers step ashore and stand by it.
	assert_str(String(sim.execute(LandTroopsCommand.new(ship.id)))).is_empty()
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		return ship.troops.is_empty() and ship.troop_order == &"", 300)).is_true()
	SimFixture.run_until(sim, func() -> bool: return false, 20)
	for agent: Agent in squad:
		assert_str(String(agent.vehicle)).is_equal("")
		assert_bool(Troops.is_soldier(sim.province, agent)).is_true()
		assert_float(agent.pos.distance_to(IsoMath.tile_center(bollard.entrance_tile()))).is_less(5.0)


func test_only_warships_with_room_take_soldiers() -> void:
	var s := _scene()
	var sim: Simulation = s["sim"]
	var province := sim.province
	var squad: Array = s["squad"]
	var cog := ShipUnit.new(province.ids.take(), sim.data.get_ship(&"cog"), IsoMath.tile_center(Vector2i(30, 40)), sim.data)
	province.ships[cog.id] = cog
	assert_str(String(sim.execute(BoardShipCommand.new(_ids(squad), cog.id)))).is_equal("not_a_warship")
	var ship: ShipUnit = s["ship"]
	for i: int in ship.def.troops:
		ship.troops.append(1000 + i)
	assert_int(TroopTransport.room(ship)).is_equal(0)
	assert_str(String(sim.execute(BoardShipCommand.new(_ids(squad), ship.id)))).is_equal("ship_full")
	ship.troops.clear()
	assert_str(String(sim.execute(LandTroopsCommand.new(ship.id)))).is_equal("no_troops_aboard")


## Another order takes a soldier off his way aboard.
func test_another_order_takes_a_soldier_off_his_way_aboard() -> void:
	var s := _scene()
	var sim: Simulation = s["sim"]
	var ship: ShipUnit = s["ship"]
	var squad: Array = s["squad"]
	sim.execute(BoardShipCommand.new(_ids(squad), ship.id))
	sim.execute(OrderTroopsCommand.new([squad[0].id], OrderTroopsCommand.MOVE, Vector2i(5, 20)))
	assert_int(ship.boarding.size()).is_equal(3)
	assert_bool(SimFixture.run_until(sim, func() -> bool: return ship.troops.size() == 3, 300)).is_true()
	assert_bool(ship.troops.has(squad[0].id)).is_false()
	assert_int(SaveMigrations.CURRENT_VERSION).is_greater_equal(25)
