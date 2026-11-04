extends GdUnitTestSuite
## Static checks of project conventions (ARCHITECTURE §11, §13).

## Simulation must stay independent of nodes, the scene tree, view/UI code and autoloads.
const SIM_FORBIDDEN: Dictionary[String, String] = {
	"\\bextends\\s+(Node|Node2D|Control|CanvasItem)\\b": "simulation must not extend nodes",
	"\\bget_tree\\s*\\(": "simulation must not use the scene tree",
	"res://src/(view|ui)/": "simulation must not depend on view/ui",
	"\\b(Data|Game|EventBus|Loc|SaveService)\\.": "simulation must not use autoloads",
}

## Properties holding player-visible text. Their literals must be localization keys.
const TEXT_ASSIGNMENT := "\\b(text|tooltip_text|title|placeholder_text)\\s*=\\s*\"([^\"]*)\""
const KEY_PATTERN := "^[a-z0-9_]+(\\.[a-z0-9_]+)+$"
const UI_ROOTS: PackedStringArray = ["res://src/ui", "res://src/view", "res://src/main"]


func test_simulation_has_no_view_dependencies() -> void:
	var violations := PackedStringArray()
	for path: String in _files("res://src/sim", ["gd"]):
		var source := FileAccess.get_file_as_string(path)
		for pattern: String in SIM_FORBIDDEN:
			if RegEx.create_from_string(pattern).search(source) != null:
				violations.append("%s: %s" % [path, SIM_FORBIDDEN[pattern]])
	assert_array(Array(violations)).is_empty()


func test_no_hardcoded_player_text() -> void:
	var assignment := RegEx.create_from_string(TEXT_ASSIGNMENT)
	var key := RegEx.create_from_string(KEY_PATTERN)
	var letter := RegEx.create_from_string("\\p{L}")
	var violations := PackedStringArray()
	for root: String in UI_ROOTS:
		for path: String in _files(root, ["gd", "tscn"]):
			for found: RegExMatch in assignment.search_all(FileAccess.get_file_as_string(path)):
				var literal := found.get_string(2).c_unescape()
				# Separators like "\n" or ", " carry no words and are not translatable text.
				if letter.search(literal) != null and key.search(literal) == null:
					violations.append("%s: %s" % [path, found.get_string()])
	assert_array(Array(violations)).override_failure_message(
			"Hardcoded player-visible text, use a localization key:\n" + "\n".join(violations)
	).is_empty()


static func _files(root: String, extensions: PackedStringArray) -> PackedStringArray:
	var result := PackedStringArray()
	var dir := DirAccess.open(root)
	if dir == null:
		return result
	for sub: String in dir.get_directories():
		result.append_array(_files(root.path_join(sub), extensions))
	for file: String in dir.get_files():
		if file.get_extension() in extensions:
			result.append(root.path_join(file))
	return result
