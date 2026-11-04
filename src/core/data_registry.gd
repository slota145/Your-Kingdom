class_name DataRegistry
extends RefCounted
## Loads every GameDef resource under a root folder and indexes it by kind and id.
##
## Plain RefCounted (no Node) so simulation code and tests can own their own instance.

const ID_PATTERN := "^[a-z][a-z0-9_]*$"

## Problems found while loading (duplicate ids, bad ids, unreadable files).
var errors: PackedStringArray = PackedStringArray()

var _defs: Dictionary[StringName, Dictionary] = {}
var _id_regex: RegEx = RegEx.create_from_string(ID_PATTERN)


func load_from(root: String) -> void:
	errors.clear()
	_defs.clear()
	for path: String in _list_resource_files(root):
		var res: Resource = load(path)
		if res == null:
			errors.append("Cannot load %s" % path)
			continue
		var def := res as GameDef
		if def == null:
			continue
		_register(def, path)


func get_def(kind: StringName, id: StringName) -> GameDef:
	var bucket: Dictionary = _defs.get(kind, {})
	return bucket.get(id) as GameDef


func has_def(kind: StringName, id: StringName) -> bool:
	return get_def(kind, id) != null


func all_of(kind: StringName) -> Array[GameDef]:
	var result: Array[GameDef] = []
	var bucket: Dictionary = _defs.get(kind, {})
	for def: GameDef in bucket.values():
		result.append(def)
	result.sort_custom(func(a: GameDef, b: GameDef) -> bool: return a.id < b.id)
	return result


func kinds() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(_defs.keys())
	return result


func get_good(id: StringName) -> GoodDef:
	return get_def(&"good", id) as GoodDef


func get_building(id: StringName) -> BuildingDef:
	return get_def(&"building", id) as BuildingDef


func goods() -> Array[GoodDef]:
	var result: Array[GoodDef] = []
	result.assign(all_of(&"good"))
	return result


func buildings() -> Array[BuildingDef]:
	var result: Array[BuildingDef] = []
	result.assign(all_of(&"building"))
	return result


func _register(def: GameDef, path: String) -> void:
	var kind: StringName = def.get_kind()
	if kind == &"":
		errors.append("%s: definition class does not override get_kind()" % path)
		return
	if _id_regex.search(String(def.id)) == null:
		errors.append("%s: invalid id '%s' (expected snake_case)" % [path, def.id])
		return
	if not _defs.has(kind):
		_defs[kind] = {}
	var bucket: Dictionary = _defs[kind]
	if bucket.has(def.id):
		errors.append("%s: duplicate %s id '%s'" % [path, kind, def.id])
		return
	bucket[def.id] = def


## Recursively lists .tres/.res files. Handles ".remap" entries of exported builds.
static func _list_resource_files(root: String) -> PackedStringArray:
	var files := PackedStringArray()
	var dir := DirAccess.open(root)
	if dir == null:
		return files
	for sub: String in dir.get_directories():
		files.append_array(_list_resource_files(root.path_join(sub)))
	for file: String in dir.get_files():
		var name := file.trim_suffix(".remap")
		if name.ends_with(".tres") or name.ends_with(".res"):
			files.append(root.path_join(name))
	return files
