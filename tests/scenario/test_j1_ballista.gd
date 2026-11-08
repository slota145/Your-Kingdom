extends GdUnitTestSuite
## J1 part 2: the ballista. Built in the siege workshop (16 planks, 4 iron, a crew of 2), it
## shoots heavy bolts 10 tiles at men and engines (three times as hard at rams and other
## ballistas), and at walls and gates only a fifth of its bolt.


func _soldier(sim: Simulation, kind: StringName, tile: Vector2i, faction: int = CombatState.PLAYER) -> Agent:
	var agent := sim.province.spawn_agent(kind, tile)
	agent.combat = CombatState.new(sim.data.get_unit(kind).combat.hp)
	agent.combat.unit = kind
	agent.combat.faction = faction
	Troops.take_command(agent)
	agent.combat.order = CombatState.Order.MOVE
	agent.combat.post = agent.pos
	agent.combat.goal = agent.pos
	return agent


func _run(sim: Simulation, seconds: float) -> void:
	for i: int in SimFixture.ticks(seconds):
		sim.step()
		sim.events.drain()


func _residents(sim: Simulation) -> int:
	var n := 0
	for b: BuildingState in sim.province.buildings.all():
		if b.house != null:
			n += b.house.residents
	return n


func test_siege_workshop_builds_a_ballista_with_a_crew_of_two() -> void:
	var sim := SimFixture.make_sim(Vector2i(40, 40))
	var v := SimFixture.village(sim, 60)
	var stock: BuildingState = v["stock"]
	stock.stock.add(&"planks", 40)
	stock.stock.add(&"iron", 10)
	for i: int in 4:
		SimFixture.house(sim, Vector2i(2 + 3 * i, 14))
	var workshop := SimFixture.place(sim, &"siege_workshop", Vector2i(20, 6))
	assert_str(String(sim.execute(OrderSiegeCommand.new(workshop.id, &"ballista")))).is_empty()
	var residents_before := _residents(sim)
	var built := [0]
	assert_bool(SimFixture.run_until(sim, func() -> bool:
		for agent: Agent in sim.province.agents.all():
			if agent.kind == &"ballista":
				built[0] = agent.id
				return true
		return false, 300)).is_true()
	assert_int(residents_before - _residents(sim)).is_equal(2)
	assert_int(sim.province.goods_total(&"iron")).is_equal(6)
	assert_bool(Troops.is_soldier(sim.province, sim.province.agents.get_agent(built[0]))).is_true()


func test_ballista_shoots_men_from_far_away() -> void:
	var sim := SimFixture.make_sim(Vector2i(32, 32))
	var ballista := _soldier(sim, &"ballista", Vector2i(6, 16))
	var enemy := _soldier(sim, &"spearman", Vector2i(15, 16), CombatState.BANDITS)
	enemy.combat.stance = CombatState.Stance.HOLD
	ballista.combat.stance = CombatState.Stance.HOLD
	_run(sim, 1)
	# 9 tiles away: within its reach (an archer's is 7).
	assert_int(ballista.combat.target_id).is_equal(enemy.id)
	assert_bool(SimFixture.run_until(sim, func() -> bool: return not sim.province.agents.has_agent(enemy.id), 30)).is_true()
	assert_float(ballista.pos.distance_to(IsoMath.tile_center(Vector2i(6, 16)))).is_less(0.5)


func test_ballista_bolts_are_deadly_to_rams() -> void:
	var sim := SimFixture.make_sim(Vector2i(32, 32))
	var ballista := _soldier(sim, &"ballista", Vector2i(6, 16))
	var ram := _soldier(sim, &"ram", Vector2i(12, 16), CombatState.BANDITS)
	ram.combat.stance = CombatState.Stance.HOLD
	ballista.combat.stance = CombatState.Stance.HOLD
	# The first bolt: 60 x 3 against a ram, of which the ram's roof of hides keeps out 4/5.
	assert_bool(SimFixture.run_until(sim, func() -> bool: return ram.combat.hp < 500, 15)).is_true()
	assert_int(500 - ram.combat.hp).is_equal(36)
	# An archer's arrow: 8 x 1/5.
	var dead: Array[Agent] = []
	var arrow := Troops.Arrow.new()
	arrow.target_id = ram.id
	arrow.to = ram.pos
	arrow.ticks = 1
	arrow.damage = 8
	var hp := ram.combat.hp
	sim.province.arrows.append(arrow)
	Troops._fly_arrows(sim.province, dead)
	assert_int(hp - ram.combat.hp).is_equal(2)


func test_ballista_chips_at_a_wall_from_afar() -> void:
	var sim := SimFixture.make_sim(Vector2i(32, 32))
	for x: int in range(4, 25):
		sim.province.lay_wall(Vector2i(x, 16), Walls.STONE)
	var ballista := _soldier(sim, &"ballista", Vector2i(14, 24))
	# (Breaking walls is ordered in an enemy's province; here straight through Troops.)
	var agents: Array[Agent] = [ballista]
	Troops.order_break(sim.province, agents, Vector2i(14, 16))
	var before := sim.province.walls.hp(Vector2i(14, 16))
	_run(sim, 12)
	var after := sim.province.walls.hp(Vector2i(14, 16))
	# Two or three bolts of 60 / 5 = 12, shot from where it stands, 8 tiles off.
	assert_int(before - after).is_between(12, 36)
	assert_float(ballista.pos.distance_to(IsoMath.tile_center(Vector2i(14, 24)))).is_less(0.5)


func test_bolts_in_flight_survive_a_save() -> void:
	var sim := SimFixture.make_sim(Vector2i(32, 32))
	var bolt := Troops.Arrow.new()
	bolt.bolt = true
	bolt.wall = Vector2i(5, 6)
	bolt.ticks = 4
	bolt.total = 6
	bolt.damage = 12
	sim.province.arrows.append(bolt)
	var state := sim.to_dict()
	var copy := Simulation.from_dict(state, SimFixture.registry())
	assert_str(SimCodec.canonical(copy.to_dict())).is_equal(SimCodec.canonical(state))
	var again: Troops.Arrow = copy.province.arrows[0]
	assert_bool(again.bolt).is_true()
	assert_vector(again.wall).is_equal(Vector2i(5, 6))
