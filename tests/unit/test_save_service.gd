extends GdUnitTestSuite
## Save files round-trip their state and reject saves from newer versions.

const SaveServiceScript := preload("res://src/core/save_service.gd")
const TEST_PATH := "user://test_saves/roundtrip.sav"

var _service: Node


func before_test() -> void:
	_service = auto_free(SaveServiceScript.new())


func after_test() -> void:
	DirAccess.remove_absolute(TEST_PATH)


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
