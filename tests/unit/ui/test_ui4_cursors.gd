extends GdUnitTestSuite
## UI-4 part 1 (owner's survey 2026-11-23): six cursors from SpriteKiln in two sizes, each with
## its hotspot; the bigger ones from an interface scale of 125%.


func test_every_cursor_has_both_sizes_and_a_hotspot() -> void:
	for kind: StringName in Cursors.ALL:
		for scale: float in [1.0, 1.5]:
			var name := Cursors.art_name(kind, scale)
			var texture := load(Cursors.ART + name + ".png") as Texture2D
			assert_object(texture).override_failure_message(name).is_not_null()
			var spot := Cursors.hotspot(name)
			assert_bool(spot.x >= 0.0 and spot.y >= 0.0 and spot.x < texture.get_width() and spot.y < texture.get_height()) \
					.override_failure_message(name).is_true()
	assert_str(Cursors.art_name(Cursors.ATTACK, 1.0)).is_equal("attack_32")
	assert_str(Cursors.art_name(Cursors.ATTACK, 1.25)).is_equal("attack_48")


func test_pointed_cursors_click_with_their_point() -> void:
	# The gauntlet's finger, the spear's and the sword's point are up-left; the others click
	# in their middle.
	for kind: StringName in [Cursors.POINTER, Cursors.COMMAND, Cursors.ATTACK]:
		var spot := Cursors.hotspot(Cursors.art_name(kind, 1.0))
		assert_bool(spot.x < 12.0 and spot.y < 12.0).override_failure_message(String(kind)).is_true()
	for kind: StringName in [Cursors.BREAK, Cursors.BOARD, Cursors.BLOCKED]:
		var spot := Cursors.hotspot(Cursors.art_name(kind, 1.0))
		assert_bool(absf(spot.x - 16.0) <= 2.0 and absf(spot.y - 16.0) <= 2.0).override_failure_message(String(kind)).is_true()


func test_showing_a_cursor_twice_changes_nothing() -> void:
	Cursors.show(Cursors.ATTACK)
	var first := Cursors.current()
	Cursors.show(Cursors.ATTACK)
	assert_str(Cursors.current()).is_equal(first)
	Cursors.show(Cursors.POINTER)
	assert_str(Cursors.current()).starts_with("pointer_")
