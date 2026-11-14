extends GdUnitTestSuite
## M10 part 3: the player's options (Options autoload, OptionsWindow, UiScaler): kept in a
## file of their own, a volume slider scales its bus, a key moves from the action that had it,
## the interface scale keeps the interface on the screen.

const OptionsScript := preload("res://src/core/options.gd")
const TEST_PATH := "user://test_settings.cfg"


func after_test() -> void:
	DirAccess.remove_absolute(TEST_PATH)


func _fresh() -> Node:
	var options := auto_free(OptionsScript.new()) as Node
	options.set("path", TEST_PATH)
	return options


func test_settings_are_kept_and_read_back() -> void:
	var options := _fresh()
	options.call("load_file")
	var values: Dictionary = options.get("values")
	values["audio/music"] = 0.4
	values["game/autosave_minutes"] = 10
	values["display/resolution"] = Vector2i(1920, 1080)
	values["game/language"] = "en"
	options.call("save_file")
	var again := _fresh()
	again.call("load_file")
	assert_float(float(again.call("get_value", "audio/music"))).is_equal_approx(0.4, 0.001)
	assert_int(int(again.call("get_value", "game/autosave_minutes"))).is_equal(10)
	assert_object(again.call("get_value", "display/resolution")).is_equal(Vector2i(1920, 1080))
	assert_str(String(again.call("get_value", "game/language"))).is_equal("en")
	assert_float(float(again.call("autosave_seconds"))).is_equal(600.0)


func test_a_broken_file_falls_back_to_the_defaults() -> void:
	var file := ConfigFile.new()
	file.set_value("audio", "music", "loud")          # wrong type
	file.set_value("display", "vsync", false)          # fine
	file.set_value("keys", "no_such_action", [KEY_Q])  # unknown action
	file.save(TEST_PATH)
	var options := _fresh()
	options.call("load_file")
	assert_float(float(options.call("get_value", "audio/music"))).is_equal(1.0)
	assert_bool(bool(options.call("get_value", "display/vsync"))).is_false()
	assert_bool((options.get("bindings") as Dictionary).is_empty()).is_true()


func test_a_volume_slider_scales_its_bus() -> void:
	assert_float(OptionsScript.volume_db(-8.0, 1.0)).is_equal_approx(-8.0, 0.001)
	assert_float(OptionsScript.volume_db(-8.0, 0.5)).is_equal_approx(-14.02, 0.01)
	assert_float(OptionsScript.volume_db(0.0, 0.0)).is_less(-60.0)
	for key: String in OptionsScript.BUSES:
		assert_int(AudioServer.get_bus_index(OptionsScript.BUSES[key])).override_failure_message(key).is_not_equal(-1)


func test_a_key_moves_from_the_action_that_had_it() -> void:
	InputSetup.ensure_defaults()
	var options := _fresh()
	options.set("path", "")
	var taken: StringName = options.call("bind", &"world_map", KEY_B)
	assert_str(String(taken)).is_equal("toggle_build_menu")
	assert_int((options.call("keys_of", &"world_map") as Array)[0]).is_equal(KEY_B)
	assert_bool((options.call("keys_of", &"toggle_build_menu") as Array).has(KEY_B)).is_false()
	# A second key of an action stays (W and the up arrow move the camera up).
	options.call("bind", &"camera_up", KEY_I)
	assert_array(options.call("keys_of", &"camera_up") as Array).contains_exactly([KEY_I, KEY_UP])
	options.call("reset_keys")
	assert_int((options.call("keys_of", &"toggle_build_menu") as Array)[0]).is_equal(KEY_B)
	assert_int((options.call("keys_of", &"world_map") as Array)[0]).is_equal(KEY_M)
	assert_int((options.call("keys_of", &"camera_up") as Array)[0]).is_equal(KEY_W)


func test_every_action_has_a_name_and_a_key() -> void:
	InputSetup.ensure_defaults()
	var previous := TranslationServer.get_locale()
	for locale: String in ["pl", "en"]:
		TranslationServer.set_locale(locale)
		for action: StringName in OptionsScript.REBINDABLE:
			var key := "ui.action.%s" % action
			assert_str(tr(key)).override_failure_message(key).is_not_equal(key)
			assert_bool(InputSetup.DEFAULTS.has(action)).override_failure_message(String(action)).is_true()
	TranslationServer.set_locale(previous)
	assert_str(OptionsWindow.key_name(&"quick_save")).is_equal("F5")


func test_window_sizes_fit_the_screen() -> void:
	var sizes := OptionsScript.resolutions_for(Vector2i(1920, 1080))
	assert_bool(sizes.has(Vector2i(1920, 1080))).is_true()
	assert_bool(sizes.has(Vector2i(2560, 1440))).is_false()
	assert_int(OptionsScript.resolutions_for(Vector2i.ZERO).size()).is_equal(OptionsScript.RESOLUTIONS.size())


func test_interface_scale_keeps_the_interface_on_the_screen() -> void:
	var root := auto_free(Control.new()) as Control
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var before: Variant = Options.values.get("display/ui_scale")
	Options.values["display/ui_scale"] = 1.5
	var scaler := UiScaler.attach(root)
	scaler.fit()
	var screen := root.get_viewport().get_visible_rect().size
	assert_vector(root.scale).is_equal(Vector2(1.5, 1.5))
	assert_vector(root.size * root.scale).is_equal_approx(screen, Vector2(1, 1))
	Options.values["display/ui_scale"] = before


func test_options_window_opens_on_every_tab() -> void:
	var window := auto_free(OptionsWindow.new()) as OptionsWindow
	add_child(window)
	window.open()
	var tabs := window.get("_tabs") as TabContainer
	assert_int(tabs.get_tab_count()).is_equal(4)
	for i: int in tabs.get_tab_count():
		assert_str(tabs.get_tab_title(i)).is_not_empty()
		assert_bool(tabs.get_tab_title(i).begins_with("ui.")).is_false()
	window.close()
	assert_bool(window.visible).is_false()
