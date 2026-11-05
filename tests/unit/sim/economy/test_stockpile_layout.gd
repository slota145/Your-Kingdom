extends GdUnitTestSuite


func test_fill_stages() -> void:
	assert_int(StockpileLayout.fill_stage(0, 20)).is_equal(0)
	assert_int(StockpileLayout.fill_stage(1, 20)).is_equal(1)
	assert_int(StockpileLayout.fill_stage(5, 20)).is_equal(1)
	assert_int(StockpileLayout.fill_stage(6, 20)).is_equal(2)
	assert_int(StockpileLayout.fill_stage(15, 20)).is_equal(3)
	assert_int(StockpileLayout.fill_stage(16, 20)).is_equal(4)
	assert_int(StockpileLayout.fill_stage(20, 20)).is_equal(4)


## The UI list (Stockpile.totals) always equals the sum of the drawn stacks (ARCHITECTURE §6.5).
func test_ui_totals_equal_sum_of_stacks_for_random_states() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var goods: Array[StringName] = [&"wood", &"bread", &"flour", &"grain"]
	for round: int in 200:
		var stock := Stockpile.new(12, SimFixture.registry())
		for i: int in rng.randi_range(0, 30):
			stock.add(goods[rng.randi_range(0, 3)], rng.randi_range(1, 25))
		var from_stacks: Dictionary[StringName, int] = {}
		for slot: int in stock.slot_count():
			var visual := StockpileLayout.visual_for(stock, slot)
			var good: StringName = visual["good"]
			if good == &"":
				assert_int(visual["fill_stage"]).is_equal(0)
				continue
			from_stacks[good] = from_stacks.get(good, 0) + int(visual["amount"])
			assert_int(visual["fill_stage"]).is_equal(
					StockpileLayout.fill_stage(int(visual["amount"]), stock.stack_size(good)))
		var ui := stock.totals()
		assert_int(ui.size()).is_equal(from_stacks.size())
		for good: StringName in ui:
			assert_int(ui[good]).is_equal(from_stacks[good])


func test_slot_tiles_skip_entrance_and_are_unique() -> void:
	var seen: Array[Vector2i] = []
	for slot: int in 12:
		var t := StockpileLayout.slot_tile(slot, Vector2i(4, 4), Vector2i(1, 3))
		assert_bool(t == Vector2i(1, 3)).is_false()
		assert_bool(seen.has(t)).is_false()
		seen.append(t)
