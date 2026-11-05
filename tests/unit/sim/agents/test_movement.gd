extends GdUnitTestSuite


func _walk_until_done(sim: Simulation, agent: Agent, goal: Vector2i, max_ticks: int) -> int:
	for i: int in max_ticks:
		var status := Movement.walk(sim.province, agent, goal)
		if status != TaskStep.Status.RUNNING:
			return status
		Movement.serve_paths(sim.province)
		Movement.move_all(sim.province)
	return TaskStep.Status.RUNNING


func test_walks_at_base_speed() -> void:
	var sim := SimFixture.make_sim()
	var agent := SimFixture.spawn(sim, &"porter", Vector2i(0, 0))
	# 12 tiles at 1.2 tiles/s = 10 s = 100 ticks (+1 tick waiting for the path).
	var status := _walk_until_done(sim, agent, Vector2i(12, 0), 102)
	assert_int(status).is_equal(TaskStep.Status.DONE)
	assert_vector(agent.pos).is_equal(IsoMath.tile_center(Vector2i(12, 0)))
	assert_int(agent.facing).is_equal(IsoMath.Dir.SE)


func test_unreachable_goal_fails() -> void:
	var sim := SimFixture.make_sim(Vector2i(10, 10))
	for y: int in 10:
		sim.province.grid.set_blocked(Vector2i(5, y), true)
		sim.province.refresh_tile(Vector2i(5, y))
	var agent := SimFixture.spawn(sim, &"porter", Vector2i(1, 1))
	assert_int(_walk_until_done(sim, agent, Vector2i(8, 1), 10)).is_equal(TaskStep.Status.FAILED)


func test_replans_when_building_appears_on_the_way() -> void:
	var sim := SimFixture.make_sim()
	var agent := SimFixture.spawn(sim, &"porter", Vector2i(0, 10))
	for i: int in 3:
		Movement.walk(sim.province, agent, Vector2i(20, 10))
		Movement.serve_paths(sim.province)
		Movement.move_all(sim.province)
	SimFixture.place(sim, &"stockpile", Vector2i(8, 8))
	var status := _walk_until_done(sim, agent, Vector2i(20, 10), 400)
	assert_int(status).is_equal(TaskStep.Status.DONE)
	for t: Vector2i in agent.path:
		assert_bool(sim.province.nav.is_walkable(t)).is_true()
