extends GdUnitTestSuite
## UI-2 part 3 (owner's survey 2026-11-13): "New game" in its own window with a small map of the
## world, drawn again whenever an option changes, from the same generator the game uses.


func _window() -> NewGameWindow:
	var window: NewGameWindow = auto_free(NewGameWindow.new())
	add_child(window)
	window.open()
	return window


func _provinces_of(window: NewGameWindow) -> Array[StringName]:
	return window.preview.world.provinces


func test_the_preview_is_the_world_the_game_will_make() -> void:
	var window := _window()
	window.panel._seed.value = 4242
	window.panel._provinces.value = 18
	window.redraw()
	var settings := window.panel.settings()
	var same := WorldGenerator.geography(Data.registry, settings)
	assert_str(String(window.preview.world.id)).is_equal(String(same.id))
	assert_array(_provinces_of(window)).is_equal(same.provinces)
	assert_int(_provinces_of(window).size()).is_equal(18)


func test_a_change_of_an_option_draws_the_world_again() -> void:
	var window := _window()
	window.panel._seed.value = 101
	window.redraw()
	var before := window.preview.world
	window.panel._provinces.value = 30
	await await_millis(int(NewGameWindow.REDRAW_DELAY * 1000.0) + 150)
	assert_object(window.preview.world).is_not_same(before)
	assert_int(_provinces_of(window).size()).is_equal(30)


func test_roll_another_gives_a_new_world_number() -> void:
	var window := _window()
	var old := int(window.panel._seed.value)
	window.panel.reroll()
	window.redraw()
	assert_int(int(window.panel._seed.value)).is_not_equal(old)
	assert_str(String(window.preview.world.id)).is_equal(String(WorldGenerator.world_id(int(window.panel._seed.value))))


func test_the_kingdom_is_shown_as_it_is_and_cannot_be_rolled() -> void:
	var window := _window()
	window.panel._world.selected = 1
	window.panel._refresh()
	window.redraw()
	assert_str(String(window.preview.world.id)).is_equal("kingdom")
	assert_bool(window._reroll.disabled).is_true()
