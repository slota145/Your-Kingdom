extends GdUnitTestSuite
## M7 part 2, steps B and C: soldiers under orders (ROADMAP M7, GDD §8, ARCHITECTURE §10).
## - the player sends soldiers in formation, on the ground or onto the wall-walk (up the
##   stairs, or through the door of a tower), and back to the ranks,
## - enemies cannot pass closed gates nor use the inner stairs of towers,
## - fighters strike, shoot and die; on the wall-walk an archer reaches farther and takes half
##   the damage from arrows; a spearman hits horsemen twice as hard.


func _soldier(sim: Simulation, kind: StringName, tile: Vector2i, faction: int = CombatState.PLAYER) -> Agent:
	var agent := sim.province.spawn_agent(kind, tile)
	agent.combat = CombatState.new(sim.data.get_unit(kind).combat.hp)
	agent.combat.faction = faction
	if faction != CombatState.PLAYER:
		Troops.take_command(agent)
	return agent


func _ids(agents: Array[Agent]) -> Array[int]:
	var ids: Array[int] = []
	for agent: Agent in agents:
		ids.append(agent.id)
	return ids


## A stone wall along y = 16 from x = 4 to 24, stairs at (10, 17) climbing to (10, 16).
func _walled(sim: Simulation) -> void:
	for x: int in range(4, 25):
		sim.province.lay_wall(Vector2i(x, 16), Walls.STONE)
	sim.province.lay_wall(Vector2i(10, 17), Walls.STAIRS + 3)


func _run(sim: Simulation, seconds: float) -> void:
	for i: int in SimFixture.ticks(seconds):
		sim.step()
		sim.events.drain()


func test_soldiers_march_in_formation_two_to_a_tile() -> void:
	var sim := SimFixture.make_sim(Vector2i(32, 32))
	var squad: Array[Agent] = []
	for i: int in 6:
		squad.append(_soldier(sim, &"spearman", Vector2i(3 + i, 3)))
	assert_str(String(sim.execute(OrderTroopsCommand.new(_ids(squad), OrderTroopsCommand.MOVE, Vector2i(20, 20))))).is_empty()
	_run(sim, 30)
	var tiles: Dictionary[Vector2i, int] = {}
	for agent: Agent in squad:
		assert_bool(agent.combat.commanded).is_true()
		assert_float(agent.pos.distance_to(agent.combat.post)).is_less(0.05)
		tiles[agent.tile()] = tiles.get(agent.tile(), 0) + 1
		assert_float(agent.pos.distance_to(Vector2(20.5, 20.5))).is_less(3.0)
	assert_int(tiles.size()).is_equal(3)


func test_soldiers_climb_the_stairs_onto_the_wall_and_come_down() -> void:
	var sim := SimFixture.make_sim(Vector2i(32, 32))
	_walled(sim)
	var archer := _soldier(sim, &"archer", Vector2i(18, 24))
	assert_str(String(sim.execute(OrderTroopsCommand.new([archer.id], OrderTroopsCommand.MOVE,
			Vector2i(20, 16), MilitaryNav.WALL)))).is_empty()
	_run(sim, 30)
	assert_int(archer.level).is_equal(MilitaryNav.WALL)
	assert_object(archer.tile()).is_equal(Vector2i(20, 16))
	# Down again, to the other side of the wall: there is no way round, only the stairs.
	assert_str(String(sim.execute(OrderTroopsCommand.new([archer.id], OrderTroopsCommand.MOVE,
			Vector2i(14, 26))))).is_empty()
	_run(sim, 30)
	assert_int(archer.level).is_equal(MilitaryNav.GROUND)
	assert_object(archer.tile()).is_equal(Vector2i(14, 26))


func test_a_place_on_a_wall_without_a_way_up_cannot_be_reached() -> void:
	var sim := SimFixture.make_sim(Vector2i(32, 32))
	for x: int in range(4, 10):
		sim.province.lay_wall(Vector2i(x, 16), Walls.STONE)
	var squad: Array[Agent] = [_soldier(sim, &"spearman", Vector2i(5, 24))]
	sim.execute(OrderTroopsCommand.new(_ids(squad), OrderTroopsCommand.MOVE, Vector2i(6, 16), MilitaryNav.WALL))
	_run(sim, 10)
	assert_int(squad[0].level).is_equal(MilitaryNav.GROUND)
	assert_bool(squad[0].combat.has_path()).is_false()


func test_tower_door_leads_up_for_the_town_only() -> void:
	var sim := SimFixture.make_sim(Vector2i(32, 32))
	for x: int in range(4, 25):
		if x < 12 or x > 13:
			sim.province.lay_wall(Vector2i(x, 16), Walls.STONE)
	# Turned so that its door faces into the town (+y), not along the wall.
	assert_str(String(sim.execute(PlaceBuildingCommand.new(&"tower", Vector2i(12, 15), true, 1)))).is_empty()
	var tower := sim.province.buildings.get_building(sim.ids.next_id - 1)
	var door := tower.door_front_tile()
	var soldier := _soldier(sim, &"swordsman", door + Vector2i(1, 2))
	sim.execute(OrderTroopsCommand.new([soldier.id], OrderTroopsCommand.MOVE, Vector2i(6, 16), MilitaryNav.WALL))
	_run(sim, 30)
	assert_int(soldier.level).is_equal(MilitaryNav.WALL)
	assert_object(soldier.tile()).is_equal(Vector2i(6, 16))
	var mil := sim.province.mil
	assert_array(mil.route(sim.province, door, 0, Vector2i(6, 16), 1, CombatState.BANDITS)).is_empty()


func test_closed_gate_stops_enemies_until_it_is_broken() -> void:
	var sim := SimFixture.make_sim(Vector2i(32, 32))
	var gate := SimFixture.place(sim, &"gatehouse", Vector2i(9, 15))
	for x: int in range(0, 32):
		if x < 9 or x > 11:
			sim.province.lay_wall(Vector2i(x, 16), Walls.STONE)
	var province := sim.province
	assert_array(province.mil.route(province, Vector2i(10, 26), 0, Vector2i(10, 6), 0, CombatState.PLAYER)).is_not_empty()
	assert_array(province.mil.route(province, Vector2i(10, 26), 0, Vector2i(10, 6), 0, CombatState.BANDITS)).is_empty()
	# The way an enemy would break in goes through the gate (cheaper than the stone).
	var siege := province.mil.siege_nav.find_path(Vector2i(10, 26), Vector2i(10, 6))
	assert_bool(siege.has(Vector2i(10, 16))).is_true()
	Troops.damage_structure(province, Vector2i(10, 16), gate.def.max_hp)
	assert_bool(gate.is_broken()).is_true()
	assert_array(province.mil.route(province, Vector2i(10, 26), 0, Vector2i(10, 6), 0, CombatState.BANDITS)).is_not_empty()


func test_soldiers_go_back_to_the_ranks() -> void:
	var sim := SimFixture.make_sim(Vector2i(32, 32))
	var barracks := SimFixture.place(sim, &"barracks", Vector2i(4, 4))
	var soldier := _soldier(sim, &"spearman", barracks.entrance_tile())
	soldier.home_id = barracks.id
	barracks.soldiers.append(soldier.id)
	sim.execute(OrderTroopsCommand.new([soldier.id], OrderTroopsCommand.MOVE, Vector2i(20, 20)))
	_run(sim, 20)
	assert_bool(soldier.combat.commanded).is_true()
	sim.execute(OrderTroopsCommand.new([soldier.id], OrderTroopsCommand.RETURN))
	_run(sim, 40)
	assert_bool(soldier.combat.commanded).is_false()
	assert_object(soldier.task).is_not_null()
	assert_float(soldier.pos.distance_to(IsoMath.tile_center(barracks.entrance_tile()))).is_less(6.0)


func test_melee_fight_ends_with_the_weaker_dead() -> void:
	var sim := SimFixture.make_sim(Vector2i(32, 32))
	var swordsman := _soldier(sim, &"swordsman", Vector2i(10, 10))
	sim.execute(OrderTroopsCommand.new([swordsman.id], OrderTroopsCommand.MOVE, Vector2i(10, 10)))
	var bandit := _soldier(sim, &"spearman", Vector2i(14, 10), CombatState.BANDITS)
	var died: Array[int] = []
	for i: int in SimFixture.ticks(60):
		sim.step()
		for event: Dictionary in sim.events.drain():
			if event["type"] == &"unit_died":
				died.append(int(event["agent"]))
		if not died.is_empty():
			break
	assert_array(died).contains_exactly([bandit.id])
	assert_bool(sim.province.agents.has_agent(bandit.id)).is_false()
	assert_int(swordsman.combat.hp).is_less(sim.data.get_unit(&"swordsman").combat.hp)


func test_spearman_hits_a_horseman_twice_as_hard() -> void:
	var sim := SimFixture.make_sim(Vector2i(32, 32))
	var spearman := _soldier(sim, &"spearman", Vector2i(10, 10))
	var knight := _soldier(sim, &"knight", Vector2i(10, 11), CombatState.BANDITS)
	var swordsman := _soldier(sim, &"swordsman", Vector2i(10, 12), CombatState.BANDITS)
	var unit := sim.data.get_unit(&"spearman")
	var dead: Array[Agent] = []
	Troops._strike(sim.province, spearman, unit, knight, false, dead)
	Troops._strike(sim.province, spearman, unit, swordsman, false, dead)
	assert_int(sim.data.get_unit(&"knight").combat.hp - knight.combat.hp).is_equal(2 * unit.combat.attack)
	assert_int(sim.data.get_unit(&"swordsman").combat.hp - swordsman.combat.hp).is_equal(unit.combat.attack)


func test_archer_on_the_wall_shoots_farther_and_is_covered() -> void:
	var sim := SimFixture.make_sim(Vector2i(32, 32))
	_walled(sim)
	var archer := _soldier(sim, &"archer", Vector2i(12, 16))
	archer.level = MilitaryNav.WALL
	sim.execute(OrderTroopsCommand.new([archer.id], OrderTroopsCommand.MOVE, Vector2i(12, 16), MilitaryNav.WALL))
	sim.execute(SetStanceCommand.new([archer.id], CombatState.Stance.HOLD))
	# 8 tiles away: beyond an archer's 7 on the ground, within 9 on the wall.
	var bandit := _soldier(sim, &"archer", Vector2i(12, 8), CombatState.BANDITS)
	bandit.combat.stance = CombatState.Stance.HOLD
	_run(sim, 4)
	assert_int(bandit.combat.hp).is_less(sim.data.get_unit(&"archer").combat.hp)
	assert_int(archer.combat.hp).is_equal(sim.data.get_unit(&"archer").combat.hp)   # out of his reach
	# Arrows hitting a man on the wall-walk do half the damage.
	var dead: Array[Agent] = []
	var arrow := Troops.Arrow.new()
	arrow.target_id = archer.id
	arrow.to = archer.pos
	arrow.ticks = 1
	arrow.damage = 8
	sim.province.arrows.append(arrow)
	Troops._fly_arrows(sim.province, dead)
	assert_int(sim.data.get_unit(&"archer").combat.hp - archer.combat.hp).is_equal(4)


func test_troops_under_orders_survive_a_save() -> void:
	var sim := SimFixture.make_sim(Vector2i(32, 32))
	_walled(sim)
	var archer := _soldier(sim, &"archer", Vector2i(18, 24))
	sim.execute(OrderTroopsCommand.new([archer.id], OrderTroopsCommand.MOVE, Vector2i(20, 16), MilitaryNav.WALL))
	_run(sim, 3)
	var province := sim.province
	var copy := ProvinceSim.from_dict(JSON.parse_string(JSON.stringify(province.to_dict())),
			sim.data, SimEvents.new(), EntityIds.new())
	assert_str(SimCodec.canonical(copy.to_dict())).is_equal(SimCodec.canonical(province.to_dict()))
	var again := copy.agents.get_agent(archer.id)
	assert_int(again.combat.path.size()).is_equal(archer.combat.path.size())
