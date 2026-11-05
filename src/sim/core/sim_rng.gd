class_name SimRng
extends RefCounted
## Seeded random numbers with one independent stream per system (ARCHITECTURE §4.4).
##
## Streams are derived from the base seed and the stream name, so adding a stream does
## not shift the numbers of the others. 64-bit values are saved as strings because JSON
## numbers are doubles.

var base_seed: int

var _streams: Dictionary[StringName, RandomNumberGenerator] = {}


func _init(seed_value: int = 1) -> void:
	base_seed = seed_value


func stream(name: StringName) -> RandomNumberGenerator:
	if not _streams.has(name):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([base_seed, String(name)])
		_streams[name] = rng
	return _streams[name]


func to_dict() -> Dictionary:
	var states := {}
	for name: StringName in _streams:
		states[String(name)] = str(_streams[name].state)
	return {"seed": str(base_seed), "streams": states}


static func from_dict(d: Dictionary) -> SimRng:
	var rng := SimRng.new(String(d.get("seed", "1")).to_int())
	var states: Dictionary = d.get("streams", {})
	for name: String in states:
		rng.stream(StringName(name)).state = String(states[name]).to_int()
	return rng
