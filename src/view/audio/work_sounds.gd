class_name WorkSounds
extends Node2D
## The blows of people at work on screen (ROADMAP M10 part 1): an axe in a trunk, a hammer
## on the anvil, a pick on stone. Each worker the AgentViewPool drew this frame is heard
## once per loop of his work animation, from where he stands, quieter far from the middle
## of the screen and when the camera is zoomed out. Only [constant MAX_VOICES] blows play at
## once and at most [member SoundDef.max_voices] of one sound: the nearest win.

const MAX_VOICES := 12
## World pixels from the middle of the screen at which a blow fades to nothing.
const HEAR_DISTANCE := 1800.0
const BUS := &"Effects"

var _players: Array[AudioStreamPlayer2D] = []
## The sound each player plays now (its SoundDef id).
var _playing: Array[StringName] = []
## Agent id -> the last blow counted (loops of his work animation).
var _last_blow: Dictionary[int, int] = {}
var _rng := RandomNumberGenerator.new()
## Blows played so far by sound id (probes and tests).
var played: Dictionary[StringName, int] = {}


func _init() -> void:
	for i: int in MAX_VOICES:
		var player := AudioStreamPlayer2D.new()
		player.bus = BUS
		player.max_distance = HEAR_DISTANCE
		player.attenuation = 1.0
		add_child(player)
		_players.append(player)
		_playing.append(&"")


## Called every frame after the AgentViewPool has drawn its people.
func update_sounds(pool: AgentViewPool, listener: Vector2, zoom: float, paused: bool) -> void:
	var due: Array[Dictionary] = []
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
