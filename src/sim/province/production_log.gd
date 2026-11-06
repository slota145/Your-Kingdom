class_name ProductionLog
extends RefCounted
## How fast each building really works while the province is viewed (ARCHITECTURE §7.1, M6):
## the calibration of the simplified mode. For every building the last SAMPLES intervals
## between two outputs (ticks) with the units made at the end of each.
##
## An interval in which a worker of the building gave up a task (no input, no tree, no room)
## is not measured: the simplified mode counts shortages on its own, so only undisturbed work
## (walking, working, waiting for crops) goes into the rate.

const SAMPLES := 10

## Building id -> [tick, amount, tick, amount, ...] of the last SAMPLES intervals.
var _samples: Dictionary[int, PackedInt32Array] = {}
## Building id -> tick of its last output (-1 after a disturbance: the next output only
## starts a new interval).
var _last: Dictionary[int, int] = {}


## Building [param building_id] made [param amount] units at [param tick].
func note_output(building_id: int, amount: int, tick: int) -> void:
	var last: int = _last.get(building_id, -1)
	_last[building_id] = tick
	if last < 0 or tick <= last:
		return
	var samples: PackedInt32Array = _samples.get(building_id, PackedInt32Array())
	samples.append(tick - last)
	samples.append(amount)
	while samples.size() > SAMPLES * 2:
		samples.remove_at(0)
		samples.remove_at(0)
	_samples[building_id] = samples


## A worker of [param building_id] gave up a task: the running interval is not measured.
func note_failure(building_id: int) -> void:
	if _last.has(building_id):
		_last[building_id] = -1


## Measured units per second of [param building_id] at its staffing while measured; -1 when
## nothing has been measured yet.
func rate(building_id: int) -> float:
	var samples: PackedInt32Array = _samples.get(building_id, PackedInt32Array())
	if samples.is_empty():
		return -1.0
	var ticks := 0
	var units := 0
	for i: int in range(0, samples.size(), 2):
		ticks += samples[i]
		units += samples[i + 1]
	return units / (ticks / float(SimClock.TICKS_PER_SECOND))


## Number of measured intervals of [param building_id].
func sample_count(building_id: int) -> int:
	return (_samples.get(building_id, PackedInt32Array()) as PackedInt32Array).size() / 2


func forget(building_id: int) -> void:
	_samples.erase(building_id)
	_last.erase(building_id)


func is_empty() -> bool:
	return _samples.is_empty() and _last.is_empty()


func to_dict() -> Dictionary:
	var d := {}
	var ids: Array[int] = []
	ids.assign(_samples.keys())
	for id: int in _last:
		if not ids.has(id):
			ids.append(id)
	ids.sort()
	for id: int in ids:
		d[str(id)] = [int(_last.get(id, -1)), Array(_samples.get(id, PackedInt32Array()))]
	return d


static func from_dict(d: Dictionary) -> ProductionLog:
	var log := ProductionLog.new()
	for key: Variant in d:
		var id := int(String(key))
		var entry: Array = d[key]
		log._last[id] = int(entry[0])
		var samples := PackedInt32Array()
		for v: Variant in entry[1]:
			samples.append(int(v))
		if not samples.is_empty():
			log._samples[id] = samples
	return log
