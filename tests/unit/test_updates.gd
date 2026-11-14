extends GdUnitTestSuite
## The "Update the game" button (M10, owner's idea 2026-11-14): only in the owner's game
## folder on Windows, never in an exported game; runs aktualizuj.ps1 with -Restart and the
## running Godot.

const UpdatesScript := preload("res://src/core/updates.gd")


func test_the_update_runs_the_script_and_starts_the_same_godot_again() -> void:
	var args := UpdatesScript.update_command("C:/Games/YourKingdom", "C:/Godot/godot.exe")
	assert_array(Array(args)).contains_exactly(["-ExecutionPolicy", "Bypass", "-File",
			"C:/Games/YourKingdom/aktualizuj.ps1", "-Restart", "-Godot", "C:/Godot/godot.exe"])
	assert_bool(FileAccess.file_exists("res://" + UpdatesScript.SCRIPT)).is_true()
	assert_bool(FileAccess.get_file_as_string("res://" + UpdatesScript.SCRIPT).contains("[switch]$Restart")).is_true()


func test_git_count_is_read_safely() -> void:
	assert_int(UpdatesScript.parse_count("3\n")).is_equal(3)
	assert_int(UpdatesScript.parse_count("0")).is_equal(0)
	assert_int(UpdatesScript.parse_count("fatal: not a git repository")).is_equal(-1)
	assert_int(UpdatesScript.parse_count("")).is_equal(-1)


func test_no_update_button_off_windows_or_in_an_exported_game() -> void:
	if OS.get_name() != "Windows":
		assert_bool(UpdatesScript.available()).is_false()
		assert_int(Updates.behind).is_equal(-1)
