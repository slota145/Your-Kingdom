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
