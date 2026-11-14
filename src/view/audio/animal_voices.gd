class_name AnimalVoices
extends RefCounted
## When the herds on screen call (M10 part 1): each pen, hive and wild herd in view makes its
## sound now and then, every [member SoundDef.interval] seconds, the first time at a random
## moment so that a farm does not answer all at once.

var _next: Dictionary[String, float] = {}
var _clock: float = 0.0
var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = 0) -> void:
	if seed_value != 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()


## The calls due now, as {"sound", "at"}, for [param herds] on screen ({"key", "kind", "at"}).
func update(herds: Array[Dictionary], delta: float) -> Array[Dictionary]:
	_clock += delta
	var due: Array[Dictionary] = []
	var seen: Dictionary[String, float] = {}
	for herd: Dictionary in herds:
		var sound := SoundBank.for_animal(herd["kind"])
		if sound == null:
			continue
		var key: String = herd["key"]
		var next: float = _next.get(key, _clock + _rng.randf_range(0.0, sound.interval.y))
		if _clock >= next:
			due.append({"sound": sound, "at": herd["at"]})
			next = _clock + _rng.randf_range(sound.interval.x, sound.interval.y)
		seen[key] = next
	_next = seen
	return due
