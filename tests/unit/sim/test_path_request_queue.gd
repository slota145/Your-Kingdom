extends GdUnitTestSuite


func test_budget_limits_batch_and_keeps_order() -> void:
	var queue := PathRequestQueue.new()
	queue.budget = 3
	for id: int in [5, 6, 7, 8, 9]:
		queue.push(id)
	assert_array(queue.take_batch()).is_equal([5, 6, 7])
	assert_array(queue.take_batch()).is_equal([8, 9])
	assert_array(queue.take_batch()).is_empty()


func test_round_trip_keeps_pending() -> void:
	var queue := PathRequestQueue.new()
	for id: int in [1, 2, 3]:
		queue.push(id)
	queue.budget = 1
	queue.take_batch()
	var back := PathRequestQueue.from_dict(JSON.parse_string(JSON.stringify(queue.to_dict())))
	assert_array(back.pending()).is_equal([2, 3])


func test_only_budget_paths_are_served_per_tick() -> void:
	var sim := SimFixture.make_sim()
	var porters: Array[Agent] = []
	for i: int in 40:
		porters.append(SimFixture.spawn(sim, &"porter", Vector2i(i % 8, i / 8)))
	for agent: Agent in porters:
		Movement.walk(sim.province, agent, Vector2i(20, 20))
	Movement.serve_paths(sim.province)
	var moving := 0
	for agent: Agent in porters:
		if agent.path_state == Agent.PathState.MOVING:
			moving += 1
	assert_int(moving).is_equal(PathRequestQueue.DEFAULT_BUDGET)
