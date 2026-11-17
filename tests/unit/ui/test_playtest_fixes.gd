extends GdUnitTestSuite
## M10 part 5, a friend's playtest (2026-11-17): the interface grows with a big window, badges
## over buildings say what they mean, messages are kept with their place, building entrances
## are marked while a road is laid.

const OptionsScript := preload("res://src/core/options.gd")
const TEST_PATH := "user://test_settings_playtest.cfg"


func after_test() -> void:
	DirAccess.remove_absolute(TEST_PATH)


func test_automatic_interface_scale_follows_the_window() -> void:
	assert_float(OptionsScript.auto_ui_scale(720.0)).is_equal(1.0)     # 1280×720, 2560×1440, 3840×2160
	assert_float(OptionsScript.auto_ui_scale(768.0)).is_equal(1.0)     # 1366×768
	assert_float(OptionsScript.auto_ui_scale(900.0)).is_equal(1.25)    # 1600×900
	assert_float(OptionsScript.auto_ui_scale(1080.0)).is_equal(1.5)    # 1920×1080
	assert_float(OptionsScript.auto_ui_scale(5000.0)).is_equal(3.0)
	assert_float(float(OptionsScript.DEFAULTS["display/ui_scale"])).is_equal(OptionsScript.AUTO_UI_SCALE)


func test_old_settings_get_the_automatic_scale() -> void:
	var file := ConfigFile.new()
	file.set_value("display", "ui_scale", 1.0)   # written before the automatic scale
	file.save(TEST_PATH)
	var options := auto_free(OptionsScript.new()) as Node
	options.set("path", TEST_PATH)
	options.call("load_file")
	assert_float(float(options.call("get_value", "display/ui_scale"))).is_equal(OptionsScript.AUTO_UI_SCALE)
	# A scale chosen after that stays.
	(options.get("values") as Dictionary)["display/ui_scale"] = 2.0
	options.call("save_file")
	options.call("load_file")
	assert_float(float(options.call("get_value", "display/ui_scale"))).is_equal(2.0)


func test_messages_are_kept_with_their_time_and_place() -> void:
	var notes := auto_free(Notifications.new()) as Notifications
	add_child(notes)
	var sim := SimFixture.make_sim()
	notes.province = sim.province
	sim.province.tick = 12 * 60 * 10 + 50   # 12:05
	notes.push("first")
	notes.push("second", Vector2(100, 50))
	assert_int(notes.history.size()).is_equal(2)
	assert_str(notes.history[0]["text"]).is_equal("second")
	assert_object(notes.history[0]["at"]).is_equal(Vector2(100, 50))
	assert_object(notes.history[1]["at"]).is_null()
	assert_str(notes.history[0]["time"]).is_equal("12:05")
	assert_int(notes.unread).is_equal(2)
	notes.mark_read()
	assert_int(notes.unread).is_equal(0)
	for i: int in Notifications.HISTORY_SIZE + 10:
		notes.push("more %d" % i)
	assert_int(notes.history.size()).is_equal(Notifications.HISTORY_SIZE)
	assert_str(Notifications.game_time(3 * 3600 * 10 + 61 * 10)).is_equal("3:01:01")


func test_a_message_about_a_building_remembers_where_it_is() -> void:
	var notes := auto_free(Notifications.new()) as Notifications
	add_child(notes)
	var sim := SimFixture.make_sim()
	notes.province = sim.province
	sim.province.tick = 100
	var hut := SimFixture.place(sim, &"hut", Vector2i(10, 10))
	notes.on_sim_event({"type": &"building_completed", "building": hut.id})
	assert_int(notes.history.size()).is_equal(1)
	assert_object(notes.history[0]["at"]).is_equal(ProvinceView.event_point(sim.province, {"building": hut.id}))


func test_the_messages_window_lists_and_shows_places() -> void:
	var notes := auto_free(Notifications.new()) as Notifications
	add_child(notes)
	notes.push("a place", Vector2(7, 8))
	var window := auto_free(MessagesWindow.new()) as MessagesWindow
	window.notes = notes
	add_child(window)
	var shown: Array[Vector2] = []
	window.show_requested.connect(func(at: Vector2) -> void: shown.append(at))
	window.open()
	assert_int(notes.unread).is_equal(0)
	var buttons := window.find_children("*", "Button", true, false)
	var show: Button = null
	for b: Node in buttons:
		if (b as Button).text == "ui.messages.show":
			show = b as Button
	assert_object(show).is_not_null()
	show.pressed.emit()
	assert_array(shown).contains_exactly([Vector2(7, 8)])


func test_badges_say_what_they_mean() -> void:
	var sim := SimFixture.make_sim()
	var farm := SimFixture.place(sim, &"farm", Vector2i(10, 10))
	var text := GameScene_mark_text(farm)
	assert_str(text).contains("%d" % farm.def.worker_count())
	farm.paused = true
	assert_str(GameScene_mark_text(farm)).is_not_equal(text)
	assert_object(BuildingMark.icon_for(BuildingMark.Kind.NO_WORKERS)).is_not_null()
	assert_object(BuildingMark.icon_for(BuildingMark.Kind.PAUSED)).is_not_null()


func test_entrances_are_red_without_a_road_and_green_with_one() -> void:
	var sim := SimFixture.make_sim()
	var hut := SimFixture.place(sim, &"hut", Vector2i(10, 10))
	var marks := EntranceLayer.entrances(sim.province)
	var front := hut.def.door_front(hut.origin, hut.orientation)
	assert_bool(marks.has(front)).is_true()
	assert_bool(marks[front]).is_false()
	sim.province.grid.set_road(front, true)
	assert_bool(EntranceLayer.entrances(sim.province)[front]).is_true()


func GameScene_mark_text(building: BuildingState) -> String:
	return (load("res://src/main/game_scene.gd") as GDScript).call("mark_text", building)
