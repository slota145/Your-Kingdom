extends Node
## Autoload "Diagnostics" (M10 part 2): writes a short header into the game's log file at
## start (game and engine version, system, language, loaded data), so a log sent after a
## crash says what ran. Godot itself writes the log (user://logs, debug/file_logging) with
## every error, warning and, on a crash, the backtrace.


func _ready() -> void:
	print(header())


func header() -> String:
	var version := str(ProjectSettings.get_setting("application/config/version", "dev"))
	var engine := Engine.get_version_info()
	var lines := PackedStringArray([
		"=== Your Kingdom %s (Godot %s) ===" % [version, engine.get("string", "?")],
		"started %s | %s %s | %s | locale %s" % [Time.get_datetime_string_from_system(false, true), OS.get_name(),
				OS.get_version(), OS.get_processor_name(), TranslationServer.get_locale()],
		"data: %d kinds, %d problems | saves in %s" % [Data.registry.kinds().size(), Data.registry.errors.size(),
				ProjectSettings.globalize_path(SaveService.SAVE_DIR)],
	])
	return "\n".join(lines)
