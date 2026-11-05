extends GdUnitTestSuite
## Goods made and used per minute (M4b-2 "Kingdom stocks"): an average over the last 5 minutes.


func test_average_over_the_minutes_so_far() -> void:
	var ledger := GoodsLedger.new()
	ledger.made(&"bread", 6, 0)
	ledger.made(&"bread", 6, 600)
	ledger.used(&"bread", 3, 650)
	# Two minutes recorded (the second one just started): 12 made in 2 minutes.
	assert_float(ledger.made_per_minute(&"bread", 1199)).is_equal_approx(6.0, 0.01)
	assert_float(ledger.used_per_minute(&"bread", 1199)).is_equal_approx(1.5, 0.01)
	assert_array(ledger.goods()).contains_exactly([&"bread"])


func test_old_minutes_fall_out_of_the_window() -> void:
	var ledger := GoodsLedger.new()
	ledger.made(&"wood", 10, 0)
	assert_float(ledger.made_per_minute(&"wood", 600 * 4)).is_equal_approx(2.5, 0.01)
	# Five minutes later the first minute is gone.
	assert_float(ledger.made_per_minute(&"wood", 600 * 5)).is_equal_approx(0.0, 0.01)
	assert_float(ledger.made_per_minute(&"stone", 600 * 5)).is_equal_approx(0.0, 0.01)


func test_province_counts_production_and_consumption() -> void:
	var sim := SimFixture.make_sim()
	SimFixture.woodcutter_scene(sim)
	sim.run_ticks(SimFixture.ticks(120))
	assert_float(sim.province.ledger.made_per_minute(&"wood", sim.province.tick)).is_greater(0.0)
