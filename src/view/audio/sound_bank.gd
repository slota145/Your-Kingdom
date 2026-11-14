class_name SoundBank
extends RefCounted
## The game's sounds and music, read once from data/audio (ROADMAP M10 part 1). The view
## asks it which sound an activity makes; the files themselves are in assets/audio
## (CREDITS.md there names their authors).

const SOUNDS_DIR := "res://data/audio/sounds"
const AMBIENCE_DIR := "res://data/audio/ambience"
const MUSIC_DIR := "res://data/audio/music"
const AUDIO_ROOT := "res://assets/audio/"

static var _loaded: bool = false
static var _sounds: Array[SoundDef] = []
static var _by_activity: Dictionary[StringName, SoundDef] = {}
static var _ambiences: Array[AmbienceDef] = []
static var _music: Array[MusicTrackDef] = []
static var _streams: Dictionary[String, AudioStream] = {}


static func sounds() -> Array[SoundDef]:
	_load()
	return _sounds


static func ambiences() -> Array[AmbienceDef]:
	_load()
	return _ambiences


static func music() -> Array[MusicTrackDef]:
	_load()
	return _music


## The sound of [param activity], or null when it makes none.
static func for_activity(activity: StringName) -> SoundDef:
	_load()
	return _by_activity.get(activity)


## The stream of a file under assets/audio, loaded once; null when it is missing.
static func stream(file: String) -> AudioStream:
	if not _streams.has(file):
		var path := AUDIO_ROOT + file
		_streams[file] = load(path) as AudioStream if ResourceLoader.exists(path) else null
	return _streams[file]


## A copy of the stream of [param file] that plays round and round (a background bed).
static func looping(file: String) -> AudioStream:
	var source := stream(file)
	if source == null:
		return null
	var copy := source.duplicate() as AudioStream
	if copy is AudioStreamOggVorbis:
		(copy as AudioStreamOggVorbis).loop = true
	return copy


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	for res: Resource in _resources(SOUNDS_DIR):
		var sound := res as SoundDef
		if sound == null:
			continue
		_sounds.append(sound)
		for activity: StringName in sound.activities:
			if _by_activity.has(activity):
				push_error("SoundBank: '%s' already makes the sound '%s'" % [activity, _by_activity[activity].id])
			_by_activity[activity] = sound
	for res: Resource in _resources(AMBIENCE_DIR):
		if res is AmbienceDef:
			_ambiences.append(res as AmbienceDef)
	for res: Resource in _resources(MUSIC_DIR):
		if res is MusicTrackDef:
			_music.append(res as MusicTrackDef)


static func _resources(dir_path: String) -> Array[Resource]:
	var result: Array[Resource] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return result
	var names := PackedStringArray()
	for file: String in dir.get_files():
		# Exported games list "x.tres.remap" for "x.tres".
		var name := file.trim_suffix(".remap")
		if name.ends_with(".tres") and not names.has(name):
			names.append(name)
	names.sort()
	for name: String in names:
		var res := load(dir_path.path_join(name))
		if res != null:
			result.append(res)
	return result
