class_name WorkSounds
extends Node2D
## The sound effects of a province on screen (ROADMAP M10 part 1): the blows of people at
## work (an axe in a trunk, a hammer on the anvil), and the sounds queued by the view for
## simulation events and animals (a sword blow, a building placed, a pig in its pen). Each
## worker the AgentViewPool drew this frame is heard once per loop of his work animation,
## from where he stands, quieter far from the middle of the screen and when the camera is
## zoomed out. Only [constant MAX_VOICES] sounds play at once and at most
## [member SoundDef.max_voices] of one sound: the nearest win.

const MAX_VOICES := 12
## World pixels from the middle of the screen at which a blow fades to nothing.
const HEAR_DISTANCE := 1800.0
## Queued sounds further off the screen than this (world pixels) are not heard.
const OFF_SCREEN := 160.0
const BUS := &"Effects"

var _players: Array[AudioStreamPlayer2D] = []
## The sound each player plays now (its SoundDef id).
var _playing: Array[StringName] = []
## Agent id -> the last blow counted (loops of his work animation).
var _last_blow: Dictionary[int, int] = {}
var _rng := RandomNumberGenerator.new()
## Blows played so far by sound id, and blows due (before the voice limits), for probes
## and tests. Without a sound card (headless) players never finish, so only [member struck]
## shows the rhythm there.
var played: Dictionary[StringName, int] = {}
var struck: Dictionary[StringName, int] = {}
## Sounds queued since the last update: {"sound", "at"} (world pixels; null = the middle of
## the screen, for sounds of the player's own doing such as a building placed).
var _queued: Array[Dictionary] = []


func _init() -> void:
	for i: int in MAX_VOICES:
		var player := AudioStreamPlayer2D.new()
		player.bus = BUS
		player.max_distance = HEAR_DISTANCE
		player.attenuation = 1.0
		add_child(player)
		_players.append(player)
		_playing.append(&"")


## Plays [param sound] at the next update, at [param at] (world pixels; null = the middle
## of the screen). With [param by_chance], [member SoundDef.chance] decides whether it is
## heard at all (animal calls have their own interval instead).
func queue(sound: SoundDef, at: Variant = null, by_chance: bool = true) -> void:
	if by_chance and sound.chance < 1.0 and _rng.randf() >= sound.chance:
		return
	_queued.append({"sound": sound, "at": at})


## Called every frame after the AgentViewPool has drawn its people. [param view]: the
## screen in world pixels.
func update_sounds(pool: AgentViewPool, view: Rect2, zoom: float, paused: bool) -> void:
	var listener := view.get_center()
	var due: Array[Dictionary] = []
	var near := view.grow(OFF_SCREEN)
	for item: Dictionary in _queued:
		var sound := item["sound"] as SoundDef
		var at: Vector2 = listener if item["at"] == null else item["at"]
		if paused or not near.has_point(at):
			continue
		struck[sound.id] = struck.get(sound.id, 0) + 1
		due.append({"sound": sound, "at": at, "distance": at.distance_to(listener)})
	_queued.clear()
	var seen: Dictionary[int, int] = {}
	for i: int in pool.work_ids.size():
		var sound := SoundBank.for_activity(pool.work_activities[i])
		if sound == null:
			continue
		var id := pool.work_ids[i]
		var blow := floori(pool.work_cycles[i] - sound.hit)
		seen[id] = blow
		if paused or not _last_blow.has(id) or _last_blow[id] == blow:
			continue
		if not heard(sound, id, blow):
			continue
		struck[sound.id] = struck.get(sound.id, 0) + 1
		var at := pool.work_positions[i]
		due.append({"sound": sound, "at": at, "distance": at.distance_to(listener)})
	_last_blow = seen
	if due.is_empty():
		return
	var busy: Dictionary[StringName, int] = {}
	var free: Array[int] = []
	for i: int in _players.size():
		if _players[i].playing:
			busy[_playing[i]] = busy.get(_playing[i], 0) + 1
		else:
			free.append(i)
	for pick: Dictionary in choose(due, busy, free.size()):
		var sound := pick["sound"] as SoundDef
		var slot: int = free.pop_back()
		var player := _players[slot]
		player.stream = SoundBank.stream(sound.files[_rng.randi() % sound.files.size()])
		if player.stream == null:
			continue
		player.global_position = pick["at"]
		player.volume_db = sound.volume_db + zoom_db(zoom)
		player.pitch_scale = 1.0 + _rng.randf_range(-sound.pitch_jitter, sound.pitch_jitter)
		_playing[slot] = sound.id
		player.play()
		played[sound.id] = played.get(sound.id, 0) + 1


## Whether the blow number [param blow] of agent [param id] is heard: every
## [member SoundDef.every] loops, with [member SoundDef.chance]. The same for the same blow,
## so it does not depend on the frame rate.
static func heard(sound: SoundDef, id: int, blow: int) -> bool:
	if posmod(blow, sound.every) != 0:
		return false
	if sound.chance >= 1.0:
		return true
	var roll := float(absi(hash(Vector2i(id, blow))) % 1000) / 1000.0
	return roll < sound.chance


## Which of [param due] blows play: nearest first, at most [member SoundDef.max_voices] of
## one sound counting [param busy] (sound id -> playing now), at most [param free_voices].
static func choose(due: Array[Dictionary], busy: Dictionary[StringName, int], free_voices: int) -> Array[Dictionary]:
	var sorted := due.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["distance"] < b["distance"])
	var counts := busy.duplicate()
	var result: Array[Dictionary] = []
	for item: Dictionary in sorted:
		if result.size() >= free_voices:
			break
		var sound := item["sound"] as SoundDef
		var count: int = counts.get(sound.id, 0)
		if count >= sound.max_voices:
			continue
		counts[sound.id] = count + 1
		result.append(item)
	return result


## Extra loudness at a zoom step: full at 1× and closer, 6 dB quieter at 0.5×.
static func zoom_db(zoom: float) -> float:
	return minf(0.0, 6.0 * log(zoom) / log(2.0))
