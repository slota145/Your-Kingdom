class_name UiSounds
extends Node
## A click for every button in the game (M10 part 1): watches the scene tree for buttons
## and plays the &"ui_click" sound (data/audio/sounds) when one is pressed.

const BUS := &"Interface"

var _player: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = BUS
	add_child(_player)
	_rng.randomize()
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	var button := node as BaseButton
	if button != null and not button.pressed.is_connected(click):
		button.pressed.connect(click)


## Plays the click (also for clicks that are not buttons, such as a tile picked on a map).
func click() -> void:
	var sound := SoundBank.for_event(&"ui_click")
	if sound == null or sound.files.is_empty():
		return
	_player.stream = SoundBank.stream(sound.files[_rng.randi() % sound.files.size()])
	_player.bus = sound.bus
	_player.volume_db = sound.volume_db
	_player.pitch_scale = 1.0 + _rng.randf_range(-sound.pitch_jitter, sound.pitch_jitter)
	_player.play()
