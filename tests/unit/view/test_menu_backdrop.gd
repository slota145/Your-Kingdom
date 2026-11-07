extends GdUnitTestSuite
## Review fixes 2026-11-07 (UI-1): the menu layers follow the mouse smoothly and never move
## past their mirrored margin, so the edge of the picture never shows.


func test_layers_never_move_past_the_margin() -> void:
	assert_float(MenuBackdrop.SKY_SHIFT).is_less_equal(MenuBackdrop.PAD)
	assert_float(MenuBackdrop.LAND_SHIFT).is_less_equal(MenuBackdrop.PAD)


func test_follow_eases_in_without_jumps_or_overshoot() -> void:
	var backdrop: MenuBackdrop = auto_free(MenuBackdrop.new())
	var target := Vector2(1.0, -1.0)
	var last := 0.0
	var last_step := 0.0
	var steps: Array[float] = []
	for frame: int in 120:
		backdrop._follow(target, 1.0 / 60.0)
		var at: float = backdrop._mouse.x
		assert_float(at).is_less_equal(1.0)
		assert_float(at).is_greater_equal(last)
		steps.append(at - last)
		last_step = at - last
		last = at
	# Starts slowly (eases in), then has caught up after 2 seconds.
	assert_float(steps[0]).is_less(steps[5])
	assert_float(last).is_greater(0.99)
	# A long frame (a hitch) does not throw the layers past the target.
	backdrop._follow(Vector2.ZERO, 0.5)
	assert_float(backdrop._mouse.x).is_greater_equal(0.0)
	assert_float(last_step).is_less(0.01)
