class_name ArtPaths
extends RefCounted
## Resolves art files under the configured art root (ART_SPEC §2). Final art in
## res://assets wins; missing files fall back to res://assets/_placeholder.

const SETTING := "your_kingdom/art_root"
const FINAL_ROOT := "res://assets"
const PLACEHOLDER_ROOT := "res://assets/_placeholder"


static func resolve(relative: String) -> String:
	var root: String = ProjectSettings.get_setting(SETTING, PLACEHOLDER_ROOT)
	if root != PLACEHOLDER_ROOT and ResourceLoader.exists(root.path_join(relative)):
		return root.path_join(relative)
	return PLACEHOLDER_ROOT.path_join(relative)


static func texture(relative: String) -> Texture2D:
	var path := resolve(relative)
	if not ResourceLoader.exists(path):
		push_error("ArtPaths: missing art %s" % path)
		return null
	return load(path) as Texture2D


## File names in an art folder, with export-time ".import"/".remap" suffixes removed.
static func list_files(relative_dir: String) -> PackedStringArray:
	var names := PackedStringArray()
	var dir := DirAccess.open(resolve(relative_dir))
	if dir == null:
		return names
	for file: String in dir.get_files():
		var name := file.trim_suffix(".import").trim_suffix(".remap")
		if not names.has(name):
			names.append(name)
	return names
