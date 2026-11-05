extends GdUnitTestSuite
## M2 DoD: a woodcutter fells trees and carries the wood to the stockpile.


func test_wood_reaches_stockpile_within_five_minutes() -> void:
	var sim := SimFixture.make_sim()
	var scene := SimFixture.woodcutter_scene(sim)
	var stock: BuildingState = scene["stock"]
	var gathered := 0
	var stored := 0
	for i: int in SimFixture.ticks(5 * 60):
		sim.step()
		for event: Dictionary in sim.events.drain():
			if event["type"] == &"good_gathered":
				gathered += int(event["amount"])
			elif event["type"] == &"good_stored" and event["storage"] == stock.id:
				stored += int(event["amount"])
	var wood := stock.stock.total(&"wood")
	assert_int(wood).is_greater(0)
	# Every log in the stockpile was cut from a tree and carried in by a visible delivery.
	assert_int(wood).is_equal(stored)
	assert_int(sim.province.goods_total(&"wood")).is_equal(gathered)
	# The UI list is the same data as the stacks on the ground.
	var from_stacks := 0
	for slot: int in stock.stock.slot_count():
		var visual := StockpileLayout.visual_for(stock.stock, slot)
		if visual["good"] == &"wood":
			from_stacks += int(visual["amount"])
	assert_int(stock.stock.totals().get(&"wood", 0)).is_equal(from_stacks)


## The last of the three logs takes the stump too: free ground is left (owner decision
## 2026-11-05).
func test_felled_trees_disappear_after_three_logs() -> void:
	var sim := SimFixture.make_sim()
	SimFixture.woodcutter_scene(sim)
	var depleted: Array[Vector2i] = []
	for i: int in SimFixture.ticks(5 * 60):
		sim.step()
		for event: Dictionary in sim.events.drain():
			if event["type"] == &"resource_depleted":
				depleted.append(event["tile"])
	assert_array(depleted).is_not_empty()
	for tile: Vector2i in depleted:
		assert_object(sim.province.resources.def_at(tile)).is_null()
		assert_bool(sim.province.nav.is_walkable(tile)).is_true()


func test_woodcutter_idles_without_trees_and_holds_nothing() -> void:
	var sim := SimFixture.make_sim()
	var hut := SimFixture.place(sim, &"woodcutter", Vector2i(12, 6))
	SimFixture.place(sim, &"stockpile", Vector2i(4, 4))
	var worker := SimFixture.spawn(sim, &"woodcutter", hut.entrance_tile())
	sim.execute(AssignWorkerCommand.new(worker.id, hut.id))
	sim.run_ticks(200)
	assert_bool(worker.is_carrying()).is_false()
	assert_int(sim.province.claim_count()).is_equal(0)
	assert_int(sim.province.reservation_count()).is_equal(0)
