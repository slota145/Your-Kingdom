extends GdUnitTestSuite


func test_ten_ticks_per_game_second() -> void:
	var clock := SimClock.new()
	var total := 0
	for i: int in 60:
		total += clock.consume(1.0 / 60.0)
	assert_int(total).is_equal(10)


func test_four_times_speed_gives_forty_ticks_per_second() -> void:
	var clock := SimClock.new()
	var total := 0
	for i: int in 60:
		total += clock.consume(4.0 / 60.0)
	assert_int(total).is_equal(40)


func test_pause_gives_no_ticks() -> void:
	var clock := SimClock.new()
	assert_int(clock.consume(0.0)).is_equal(0)
	assert_int(clock.consume(-1.0)).is_equal(0)


func test_long_frame_is_capped() -> void:
	var clock := SimClock.new()
	assert_int(clock.consume(10.0)).is_equal(SimClock.MAX_TICKS_PER_FRAME)
	assert_int(clock.consume(0.0)).is_equal(0)


func test_alpha_tracks_partial_tick() -> void:
	var clock := SimClock.new()
	clock.consume(0.05)
	assert_float(clock.alpha()).is_equal_approx(0.5, 0.001)
