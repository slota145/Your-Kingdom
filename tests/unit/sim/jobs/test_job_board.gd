extends GdUnitTestSuite


func _two_stockpiles() -> Dictionary:
	var sim := SimFixture.make_sim()
	var a := SimFixture.place(sim, &"stockpile", Vector2i(2, 2))
	var b := SimFixture.place(sim, &"stockpile", Vector2i(20, 2))
	return {"sim": sim, "a": a, "b": b}


func test_nearest_idle_porter_gets_the_job_and_reserves() -> void:
	var s := _two_stockpiles()
	var sim: Simulation = s["sim"]
	var a: BuildingState = s["a"]
	a.stock.add(&"wood", 5)
	var far := SimFixture.spawn(sim, &"porter", Vector2i(28, 28))
	var near := SimFixture.spawn(sim, &"porter", Vector2i(3, 8))
	sim.execute(RequestTransportCommand.new(&"wood", 1, a.id, (s["b"] as BuildingState).id))
	sim.step()
	assert_object(near.task).is_not_null()
	assert_object(far.task).is_null()
	assert_int(a.stock.available(&"wood")).is_equal(4)


func test_request_split_between_porters_by_load() -> void:
	var s := _two_stockpiles()
	var sim: Simulation = s["sim"]
	var a: BuildingState = s["a"]
	a.stock.add(&"wood", 3)
	var porters: Array[Agent] = []
	for i: int in 5:
		porters.append(SimFixture.spawn(sim, &"porter", Vector2i(10 + i, 10)))
	sim.execute(RequestTransportCommand.new(&"wood", 3, a.id, (s["b"] as BuildingState).id))
	sim.step()
	var busy := 0
	for p: Agent in porters:
		if p.task != null:
			busy += 1
	assert_int(busy).is_equal(3)
	var request := sim.province.jobs.all()[0]
	assert_int(request.in_flight).is_equal(3)


func test_infeasible_request_waits_and_completed_request_disappears() -> void:
	var s := _two_stockpiles()
	var sim: Simulation = s["sim"]
	var a: BuildingState = s["a"]
	var b: BuildingState = s["b"]
	var porter := SimFixture.spawn(sim, &"porter", Vector2i(10, 10))
	sim.execute(RequestTransportCommand.new(&"wood", 2, a.id, b.id))
	sim.run_ticks(10)
	assert_object(porter.task).is_null()
	a.stock.add(&"wood", 2)
	sim.run_ticks(SimFixture.ticks(120))
	assert_int(b.stock.total(&"wood")).is_equal(2)
	assert_int(sim.province.jobs.count()).is_equal(0)


func test_matching_only_every_interval() -> void:
	var s := _two_stockpiles()
	var sim: Simulation = s["sim"]
	var a: BuildingState = s["a"]
	a.stock.add(&"wood", 1)
	var porter := SimFixture.spawn(sim, &"porter", Vector2i(10, 10))
	sim.step()  # tick 0 matches, but the request arrives with the next tick's commands
	sim.submit(RequestTransportCommand.new(&"wood", 1, a.id, (s["b"] as BuildingState).id))
	for i: int in JobBoard.MATCH_INTERVAL - 1:
		sim.step()
		assert_object(porter.task).is_null()
	sim.step()
	assert_object(porter.task).is_not_null()


## M4b-3: a request nobody can serve (nothing to take) is offered again after
## NO_MATCH_RETRY_TICKS, not every round, and is served once the goods are there.
func test_request_without_goods_waits_before_the_next_try() -> void:
	var s := _two_stockpiles()
	var sim: Simulation = s["sim"]
	var a: BuildingState = s["a"]
	var porter := SimFixture.spawn(sim, &"porter", Vector2i(10, 10))
	sim.execute(RequestTransportCommand.new(&"wood", 2, a.id, (s["b"] as BuildingState).id))
	sim.step()
	var request := sim.province.jobs.all()[0]
	assert_int(request.retry_at).is_equal(JobBoard.NO_MATCH_RETRY_TICKS)
	a.stock.add(&"wood", 2)
	sim.run_ticks(JobBoard.NO_MATCH_RETRY_TICKS - 1)
	assert_object(porter.task).is_null()
	sim.run_ticks(JobBoard.MATCH_INTERVAL + 1)
	assert_object(porter.task).is_not_null()
