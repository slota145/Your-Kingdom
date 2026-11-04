class_name PoFile
extends RefCounted
## Minimal gettext .po reader for tests: collects msgids and checks for empty translations.

## msgid -> Array[String] of msgstr values (one, or one per plural form).
var entries: Dictionary[String, Array] = {}
var plural_ids: Dictionary[String, String] = {}


static func read(path: String) -> PoFile:
	var po := PoFile.new()
	var text := FileAccess.get_file_as_string(path)
	var current_id := ""
	for raw_line: String in text.split("\n"):
		var line := raw_line.strip_edges()
		if line.begins_with("msgid_plural "):
			po.plural_ids[current_id] = _unquote(line.trim_prefix("msgid_plural "))
		elif line.begins_with("msgid "):
			current_id = _unquote(line.trim_prefix("msgid "))
			if current_id != "":
				po.entries[current_id] = []
		elif line.begins_with("msgstr") and current_id != "":
			var value := _unquote(line.substr(line.find(" ") + 1))
			po.entries[current_id].append(value)
	return po


func keys() -> PackedStringArray:
	var result := PackedStringArray(entries.keys())
	result.sort()
	return result


func empty_translations() -> PackedStringArray:
	var result := PackedStringArray()
	for key: String in entries:
		for value: String in entries[key]:
			if value.is_empty():
				result.append(key)
	return result


static func _unquote(token: String) -> String:
	return token.strip_edges().trim_prefix("\"").trim_suffix("\"")
