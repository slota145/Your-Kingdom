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


## The players' .exe (owner's choice 2026-11-14): newer versions from the public repository.
func test_versions_compare_as_numbers() -> void:
	assert_bool(UpdatesScript.is_newer("v0.9.1", "0.9.0")).is_true()
	assert_bool(UpdatesScript.is_newer("0.10.0", "0.9.9")).is_true()
	assert_bool(UpdatesScript.is_newer("1.0", "0.9.9")).is_true()
	assert_bool(UpdatesScript.is_newer("v0.9.0", "0.9.0")).is_false()
	assert_bool(UpdatesScript.is_newer("0.8.5", "0.9.0")).is_false()
	assert_bool(UpdatesScript.is_newer("0.9.0", "0.9")).is_false()


func test_a_release_needs_the_exe_and_its_checksum() -> void:
	var release := {
		"tag_name": "v0.9.1", "html_url": "https://github.com/x/y/releases/tag/v0.9.1",
		"assets": [
			{"name": "YourKingdom.exe", "browser_download_url": "https://example.org/YourKingdom.exe"},
			{"name": "YourKingdom.exe.sha256", "browser_download_url": "https://example.org/YourKingdom.exe.sha256"},
		],
	}
	var parsed := UpdatesScript.parse_release(release)
	assert_str(parsed["version"]).is_equal("0.9.1")
	assert_str(parsed["exe"]).is_equal("https://example.org/YourKingdom.exe")
	assert_str(parsed["sha"]).is_equal("https://example.org/YourKingdom.exe.sha256")
	(release["assets"] as Array).pop_back()
	assert_bool(UpdatesScript.parse_release(release).is_empty()).is_true()
	assert_bool(UpdatesScript.parse_release(null).is_empty()).is_true()
	assert_bool(UpdatesScript.parse_release({"message": "Not Found"}).is_empty()).is_true()


func test_checksums_are_read_strictly() -> void:
	var hex := "ab".repeat(32)
	assert_str(UpdatesScript.parse_checksum(hex + "\n")).is_equal(hex)
	assert_str(UpdatesScript.parse_checksum(hex.to_upper() + "  YourKingdom.exe\n")).is_equal(hex)
	assert_str(UpdatesScript.parse_checksum("<html>Not Found</html>")).is_equal("")
	assert_str(UpdatesScript.parse_checksum("abc")).is_equal("")
	# The same as Godot computes for a downloaded file.
	var path := "user://test_checksum.bin"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("Your Kingdom")
	file.close()
	assert_int(FileAccess.get_sha256(path).length()).is_equal(64)
	DirAccess.remove_absolute(path)


func test_the_new_exe_takes_the_place_of_the_running_one() -> void:
	var paths := UpdatesScript.swap_paths("C:/Games/YourKingdom.exe")
	assert_str(paths["new"]).is_equal("C:/Games/YourKingdom.exe.new")
	assert_str(paths["old"]).is_equal("C:/Games/YourKingdom.old.exe")
	if OS.get_name() != "Windows":
		assert_bool(UpdatesScript.releases_available()).is_false()


func test_the_release_workflow_publishes_where_the_game_looks() -> void:
	var workflow := FileAccess.get_file_as_string("res://.github/workflows/release.yml")
	assert_bool(workflow.contains("--repo " + UpdatesScript.RELEASES_REPO)).is_true()
	assert_bool(workflow.contains(UpdatesScript.EXE_ASSET)).is_true()
	assert_bool(workflow.contains(UpdatesScript.SHA_ASSET)).is_true()
	assert_bool(workflow.contains("secrets.RELEASES_TOKEN")).is_true()
