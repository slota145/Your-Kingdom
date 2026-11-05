extends GdUnitTestSuite
## M4b-1.5 DoD: two rows of houses back to back, each facing its own road, work in the
## game: newcomers move in and householders keep the pantries supplied, always through
## the door on the street side.

const ROW_LENGTH := 3


## Row A (x 10..11) turned to 2 faces the road at x = 9; row B (x 12..13) turned to 0
## faces the road at x = 14. Their backs touch. A stockpile and two wells serve both.
func _town(residents: int, pantry: bool) -> Dictionary:
	var sim := SimFixture.make_sim(Vector2i(32, 32))
	sim.province.entry_tile = Vector2i(0, 20)
	var stock := SimFixture.place(sim, &"stockpile", Vector2i(2, 2))
	stock.stock.add(&"bread", 40)
	stock.stock.add(&"wood", 40)
	var houses: Array[BuildingState] = []
	for row: Array in [[10, 2], [12, 0]]:
		for i: int in ROW_LENGTH:
			var origin := Vector2i(int(row[0]), 10 + 2 * i)
			assert_str(String(sim.execute(PlaceBuildingCommand.new(&"hut", origin, true, int(row[1]))))).is_equal("")
			var hut := sim.province.buildings.get_building(sim.ids.next_id - 1)
			hut.house.residents = residents
			if pantry:
				for good: StringName in hut.house_goods():
					hut.supply.add(good, hut.level_def().supply_units)
			houses.append(hut)
	var roads: Array[Vector2i] = []
	for y: int in range(6, 18):
		roads.append(Vector2i(9, y))
		roads.append(Vector2i(14, y))
	assert_str(String(sim.execute(BuildRoadCommand.new(roads)))).is_equal("")
	SimFixture.place(sim, &"well", Vector2i(7, 12))
	SimFixture.place(sim, &"well", Vector2i(16, 12))
	return {"sim": sim, "houses": houses}


## Runs [param seconds] and returns entries into a house through any tile but its door.
func _run_checking_doors(sim: Simulation, houses: Array[BuildingState], seconds: float) -> PackedStringArray:
	var wrong := PackedStringArray()
	var last: Dictionary[int, Vector2i] = {}
	for i: int in SimFixture.ticks(seconds):
		sim.step()
		sim.events.drain()
		for agent: Agent in sim.province.agents.all():
			var tile := agent.tile()
			var before: Vector2i = last.get(agent.id, tile)
			last[agent.id] = tile
			if tile == before:
				continue
			for hut: BuildingState in houses:
				if tile == hut.entrance_tile() and agent.path_goal == tile and before != hut.door_front_tile():
					wrong.append("agent %d entered %s from %s" % [agent.id, tile, before])
	return wrong


func test_newcomers_move_into_both_rows() -> void:
	var town := _town(0, true)
	var sim: Simulation = town["sim"]
	var houses: Array[BuildingState] = []
	houses.assign(town["houses"])
	var wrong := _run_checking_doors(sim, houses, 420)
	assert_array(Array(wrong)).is_empty()
	for hut: BuildingState in houses:
		assert_int(hut.house.residents).override_failure_message("house at %s: %d %s %.1f" % [hut.origin,
				hut.house.residents, hut.house.satisfied, hut.house.happiness]) \
				.is_equal(hut.capacity())


func test_householders_supply_both_rows() -> void:
	var town := _town(4, false)
	var sim: Simulation = town["sim"]
	var houses: Array[BuildingState] = []
	houses.assign(town["houses"])
	var wrong := _run_checking_doors(sim, houses, 120)
	assert_array(Array(wrong)).is_empty()
	for hut: BuildingState in houses:
		assert_int(hut.supply.total(&"bread")).override_failure_message("house at %s" % hut.origin).is_greater(0)
		assert_int(hut.supply.total(&"wood")).override_failure_message("house at %s" % hut.origin).is_greater(0)
		assert_float(hut.house.happiness).is_greater(Population.IMMIGRATION_MIN_HAPPINESS)
	assert_array(Array(sim.province.dangling_holds())).is_empty()
