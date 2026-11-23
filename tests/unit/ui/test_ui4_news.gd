extends GdUnitTestSuite
## UI-4 part 2 (owner's survey 2026-11-23): "What's new" lists every released version, newest
## first, in Polish and English, and opens by itself once after an update.

var _path: String
var _values: Dictionary


func before_test() -> void:
	_path = Options.path
	_values = Options.values.duplicate()
	Options.path = ""


func after_test() -> void:
	Options.values = _values
	Options.path = _path


func test_the_newest_entry_is_this_version_of_the_game() -> void:
	assert_str(String(ChangelogWindow.VERSIONS[0][0])).is_equal(ChangelogWindow.game_version())


func test_every_point_is_translated() -> void:
	for lang: String in ["pl", "en"]:
		var text := FileAccess.get_file_as_string("res://localization/%s.po" % lang)
		for entry: Array in ChangelogWindow.VERSIONS:
			for n: int in range(0, int(entry[2]) + 1):
				var key := ChangelogWindow.key(entry[0], n)
				assert_bool(text.contains('msgid "%s"\n' % key)).override_failure_message("%s: %s" % [lang, key]).is_true()
			# No point beyond the count is left out.
			var extra := ChangelogWindow.key(entry[0], int(entry[2]) + 1)
			assert_bool(text.contains('msgid "%s"\n' % extra)).override_failure_message("%s: %s" % [lang, extra]).is_false()


func test_the_news_open_once_per_version() -> void:
	Options.values[ChangelogWindow.SEEN_KEY] = "0.1.0"
	assert_bool(ChangelogWindow.take_unseen()).is_true()
	assert_str(String(Options.get_value(ChangelogWindow.SEEN_KEY))).is_equal(ChangelogWindow.game_version())
	assert_bool(ChangelogWindow.take_unseen()).is_false()


func test_the_window_lists_every_version() -> void:
	var window := auto_free(ChangelogWindow.new()) as ChangelogWindow
	add_child(window)
	window.open()
	var points := 0
	for entry: Array in ChangelogWindow.VERSIONS:
		points += int(entry[2])
	var list := window.find_children("*", "VBoxContainer", true, false)[1] as VBoxContainer
	# A heading and a line under each version, and its points.
	assert_int(list.get_child_count()).is_equal(points + 2 * ChangelogWindow.VERSIONS.size())
