extends Node
## Autoload "Music" (ROADMAP M10 part 1): plays the pieces that suit the moment (main menu,
## a province at peace), one after another with a quiet pause between them, as in Anno.
## A change of mood keeps the piece playing when it suits the new mood too.

const BUS := &"Music"
## Silence between two pieces, seconds (min, max).
const PAUSE := Vector2(20.0, 50.0)
const FADE_IN := 2.0
const FADE_OUT := 1.5
const SILENT_DB := -60.0

var mood: StringName = &""
var current: MusicTrackDef

## Pieces played lately, newest last: they wait until about half of the others have played.
var recent: Array[MusicTrackDef] = []

var _player: AudioStreamPlayer
var _fade: Tween
var _pause_left: float = -1.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = BUS
	add_child(_player)
	_player.finished.connect(_on_finished)
	_rng.randomize()


## Plays music for [param new_mood] (&"menu", &"peace"); nothing changes when it already does.
func play_mood(new_mood: StringName) -> void:
	if new_mood == mood:
		return
	mood = new_mood
	if current != null and current.moods.has(mood) and _player.playing:
		return
	_start(pick(SoundBank.music(), mood, recent, _rng))


func stop() -> void:
	mood = &""
	_pause_left = -1.0
	_fade_to(SILENT_DB, FADE_OUT, true)
	current = null


func _process(delta: float) -> void:
	if _pause_left < 0.0:
		return
	_pause_left -= delta
	if _pause_left < 0.0:
		_start(pick(SoundBank.music(), mood, recent, _rng))


## A piece for [param for_mood] that is not among the last half of [param played] (newest
## last), so with 11 pieces each comes back only after about five others.
static func pick(tracks: Array[MusicTrackDef], for_mood: StringName, played: Array[MusicTrackDef],
		rng: RandomNumberGenerator) -> MusicTrackDef:
	var fitting: Array[MusicTrackDef] = []
	for track: MusicTrackDef in tracks:
		if track.moods.has(for_mood):
			fitting.append(track)
	if fitting.is_empty():
		return null
	var fresh := fitting.duplicate()
	var keep_out := fitting.size() / 2
	for i: int in range(played.size() - 1, -1, -1):
		if keep_out <= 0 or fresh.size() <= 1:
			break
		if fresh.has(played[i]):
			fresh.erase(played[i])
			keep_out -= 1
	return fresh[rng.randi() % fresh.size()]


func _start(track: MusicTrackDef) -> void:
	_pause_left = -1.0
	current = track
	if track != null:
		recent.erase(track)
		recent.append(track)
	if track == null:
		_fade_to(SILENT_DB, FADE_OUT, true)
		return
	var stream := SoundBank.stream(track.file)
	if stream == null:
		push_error("Music: no file %s" % track.file)
		return
	_player.stream = stream
	_player.volume_db = SILENT_DB
	_player.play()
	_fade_to(track.volume_db, FADE_IN, false)


func _fade_to(volume_db: float, seconds: float, stop_after: bool) -> void:
	if _fade != null:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(_player, "volume_db", volume_db, seconds)
	if stop_after:
		_fade.tween_callback(_player.stop)


func _on_finished() -> void:
	if mood != &"":
		_pause_left = _rng.randf_range(PAUSE.x, PAUSE.y)
