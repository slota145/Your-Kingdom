class_name CharacterVisual
extends RefCounted
## All animations of one character, loaded from characters/<id>/ (ART_SPEC §2, §4.3).

## Default playback speed by animation name prefix (ART_SPEC §4.3, to be tuned in M1).
const FPS_BY_PREFIX: Dictionary[String, float] = {"idle": 4.0, "walk": 10.0, "work": 8.0}

static var _cache: Dictionary[StringName, CharacterVisual] = {}

var id: StringName
var animations: Dictionary[StringName, CharacterSheet] = {}


static func get_visual(character_id: StringName) -> CharacterVisual:
	if not _cache.has(character_id):
		_cache[character_id] = _load(character_id)
	return _cache[character_id]


func get_sheet(anim: StringName) -> CharacterSheet:
	if animations.has(anim):
		return animations[anim]
	# A missing carry variant falls back to plain walking rather than failing.
	if String(anim).begins_with("walk") and animations.has(&"walk"):
		return animations[&"walk"]
	return animations.get(&"idle")


static func _load(character_id: StringName) -> CharacterVisual:
	var visual := CharacterVisual.new()
	visual.id = character_id
	var dir := "characters/%s" % character_id
	for file: String in ArtPaths.list_files(dir):
		if not file.ends_with(".png") or file.ends_with(".anchors.png"):
			continue
		var anim := file.get_basename()
		var sheet_path := ArtPaths.resolve(dir.path_join(file))
		var anchors_path := ArtPaths.resolve(dir.path_join(anim + ".anchors.png"))
		visual.animations[StringName(anim)] = CharacterSheet.from_files(
				sheet_path, anchors_path, _fps_for(anim))
	if visual.animations.is_empty():
		push_error("CharacterVisual: no animations for '%s'" % character_id)
	return visual


static func _fps_for(anim: String) -> float:
	for prefix: String in FPS_BY_PREFIX:
		if anim.begins_with(prefix):
			return FPS_BY_PREFIX[prefix]
	return 8.0
