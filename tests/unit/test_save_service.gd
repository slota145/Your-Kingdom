extends GdUnitTestSuite
## Save files round-trip their state and reject saves from newer versions.

const SaveServiceScript := preload("res://src/core/save_service.gd")
const TEST_PATH := "user://test_saves/roundtrip.sav"
const OTHER_PATH := "user://test_saves/other.sav"

var _service: Node


func before_test() -> void:
	_service = auto_free(SaveServiceScript.new())


func after_test() -> void:
	for path: String in [TEST_PATH, OTHER_PATH, TEST_PATH + ".tmp"]:
		DirAccess.remove_absolute(path)


## M10 part 2: a save goes through a temporary file and replaces the old one only when
## complete; nothing is left over.
func test_saving_again_replaces_the_save_and_leaves_no_temporary_file() -> void:
	assert_int(_service.save_state(TEST_PATH, {"tick": 1})).is_equal(OK)
	assert_int(_service.save_state(TEST_PATH, {"tick": 2})).is_equal(OK)
	assert_bool(FileAccess.file_exists(TEST_PATH + ".tmp")).is_false()
	assert_int(int(_service.load_state(TEST_PATH)["tick"])).is_equal(2)


## M10 part 2: "Load game" continues from the newer of the quick save and the autosave.
func test_newest_save_is_found() -> void:
	assert_str(_service.newest([TEST_PATH, OTHER_PATH] as Array[String])).is_equal("")
	_service.save_state(OTHER_PATH, {"tick": 1})
	assert_str(_service.newest([TEST_PATH, OTHER_PATH] as Array[String])).is_equal(OTHER_PATH)
	# File times have a resolution of one second.
	await get_tree().create_timer(1.1).timeout
	_service.save_state(TEST_PATH, {"tick": 2})
	assert_str(_service.newest([TEST_PATH, OTHER_PATH] as Array[String])).is_equal(TEST_PATH)


func test_round_trip_keeps_state() -> void:
	var state := {"tick": 1234, "goods": {"bread": 5, "wood": 12}, "name": "Gród"}
	assert_int(_service.save_state(TEST_PATH, state)).is_equal(OK)
	var loaded: Dictionary = _service.load_state(TEST_PATH)
	# JSON turns ints into floats; compare via a second serialization pass.
	assert_str(JSON.stringify(loaded, "", true)).is_equal(JSON.stringify(JSON.parse_string(
			JSON.stringify(state)), "", true))


func test_newer_save_version_is_rejected() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_PATH.get_base_dir())
	var file := FileAccess.open_compressed(TEST_PATH, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	file.store_string(JSON.stringify({"header": {"save_version": 999}, "state": {"x": 1}}))
	file.close()
	assert_dict(_service.load_state(TEST_PATH)).is_empty()


## UI-3 part 2: many saves, each with its name, time and game time beside it.
func test_many_saves_are_listed_newest_first_with_their_names() -> void:
	_service.save_dir = "user://test_saves/slots"
	for path: String in _service.list_saves().map(func(e: Dictionary) -> String: return e["path"]):
		_service.delete_save(path)
	assert_array(_service.list_saves()).is_empty()
	assert_str(_service.free_slot()).is_equal("slot_1")
	var sim := SimFixture.make_sim()
	sim.run_ticks(SimFixture.ticks(61))
	var first: String = _service.slot_path(_service.free_slot())
	assert_int(_service.save_simulation(first, sim, "  Northern farms  ")).is_equal(OK)
	assert_str(_service.free_slot()).is_equal("slot_2")
	await get_tree().create_timer(1.1).timeout
	assert_int(_service.save_simulation(_service.slot_path(_service.QUICK_SLOT), sim)).is_equal(OK)
	var saves: Array[Dictionary] = _service.list_saves()
	assert_int(saves.size()).is_equal(2)
	assert_str(String(saves[0]["kind"])).is_equal("quick")
	assert_str(String(saves[1]["kind"])).is_equal("slot")
	assert_str(String(saves[1]["name"])).is_equal("Northern farms")
	assert_int(int(saves[1]["game_seconds"])).is_equal(61)
	assert_str(SavesWindow.title_of(saves[1])).is_equal("Northern farms")
	assert_str(SavesWindow.details_of(saves[1])).contains("1:01")
	assert_str(_service.newest_save_path()).is_equal(_service.slot_path(_service.QUICK_SLOT))
	# Saving over it without a name keeps the name; the save loads.
	_service.save_simulation(first, sim)
	assert_str(String(_service.read_meta(first)["name"])).is_equal("Northern farms")
	assert_object(_service.load_simulation(first, SimFixture.registry())).is_not_null()
	# Deleting takes the description too.
	_service.delete_save(first)
	assert_bool(FileAccess.file_exists(first + _service.META_EXTENSION)).is_false()
	assert_int(_service.list_saves().size()).is_equal(1)
	_service.delete_save(_service.slot_path(_service.QUICK_SLOT))


func test_the_saves_window_lists_saves_to_load_and_only_own_ones_to_overwrite() -> void:
	SaveService.save_dir = "user://test_saves/window"
	var sim := SimFixture.make_sim()
	SaveService.save_simulation(SaveService.slot_path("slot_1"), sim, "A")
	SaveService.save_simulation(SaveService.slot_path(SaveService.AUTO_SLOT), sim)
	var window := auto_free(SavesWindow.new()) as SavesWindow
	add_child(window)
	window.open(SavesWindow.Mode.LOAD)
	assert_int(window.row_count()).is_equal(2)
	window.open(SavesWindow.Mode.SAVE)
	assert_int(window.row_count()).is_equal(1)
	var chosen: Array[String] = []
	window.save_chosen.connect(func(path: String, _name: String) -> void: chosen.append(path))
	window.call("_save_new")
	assert_array(chosen).contains_exactly([SaveService.slot_path("slot_2")])
	for path: String in [SaveService.slot_path("slot_1"), SaveService.slot_path(SaveService.AUTO_SLOT)]:
		SaveService.delete_save(path)
	SaveService.save_dir = SaveService.SAVE_DIR
