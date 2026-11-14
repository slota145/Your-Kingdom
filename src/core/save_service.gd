extends Node
## Autoload "SaveService": writes and reads save files (ARCHITECTURE §8).
##
## A save is a compressed JSON document: {"header": {...}, "state": {...}} where state is
## Simulation.to_dict(). Migrations are added whenever SAVE_VERSION is bumped.

const SAVE_VERSION := SaveMigrations.CURRENT_VERSION
const SAVE_DIR := "user://saves"
const EXTENSION := ".sav"
## Slots: F5 and the pause menu, and the autosave every few minutes (M10 part 2).
const QUICK_SLOT := "quick"
const AUTO_SLOT := "auto"
## Godot writes its log here (debug/file_logging, project settings).
const LOG_DIR := "user://logs"


func slot_path(slot_name: String) -> String:
	return SAVE_DIR.path_join(slot_name + EXTENSION)


## The newest of the quick save and the autosave ("" when there is none): what "Load
## game" continues from.
func latest_slot_path() -> String:
	return newest([slot_path(QUICK_SLOT), slot_path(AUTO_SLOT)])


## The most recently written of [param paths] that exist ("" when none does).
func newest(paths: Array[String]) -> String:
	var best := ""
	var best_time := -1
	for path: String in paths:
		if not FileAccess.file_exists(path):
			continue
		var time := FileAccess.get_modified_time(path)
		if time > best_time:
			best_time = time
			best = path
	return best


## Opens the folder with the game's log files (errors and warnings, M10 part 2), so the
## owner can send the newest one after a crash.
func open_logs() -> void:
	var folder := ProjectSettings.globalize_path(LOG_DIR)
	DirAccess.make_dir_recursive_absolute(folder)
	OS.shell_open(folder)


func save_simulation(path: String, sim: Simulation) -> Error:
	return save_state(path, sim.to_dict())


## Returns null when the file cannot be read.
func load_simulation(path: String, registry: DataRegistry) -> Simulation:
	var state := load_state(path)
	if state.is_empty():
		return null
	return Simulation.from_dict(state, registry)


## Writes to a temporary file first and puts it in place only when it is complete, so a
## crash or a power cut while saving keeps the previous save (M10 part 2).
func save_state(path: String, state: Dictionary) -> Error:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var temp := path + ".tmp"
	var error := _write(temp, state)
	if error != OK:
		DirAccess.remove_absolute(temp)
		return error
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(temp, path)


func _write(path: String, state: Dictionary) -> Error:
	var file := FileAccess.open_compressed(path, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if file == null:
		return FileAccess.get_open_error()
	var document := {
		"header": {
			"save_version": SAVE_VERSION,
			"game_version": str(ProjectSettings.get_setting("application/config/version", "dev")),
			"saved_at": Time.get_datetime_string_from_system(true),
		},
		"state": state,
	}
	# Full precision: positions are floats and must come back bit-identical (determinism).
	file.store_string(JSON.stringify(document, "", false, true))
	file.close()
	return OK


## Returns the stored state, or an empty Dictionary on failure.
func load_state(path: String) -> Dictionary:
	var file := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if file == null:
		push_error("SaveService: cannot open %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		push_error("SaveService: corrupt save %s" % path)
		return {}
	var document: Dictionary = parsed
	var header: Dictionary = document.get("header", {})
	var version := int(header.get("save_version", 0))
	if version > SAVE_VERSION:
		push_error("SaveService: save %s is from a newer game version" % path)
		return {}
	return _migrate(document.get("state", {}), version)


func _migrate(state: Dictionary, from_version: int) -> Dictionary:
	return SaveMigrations.migrate(state, from_version)
