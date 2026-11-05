class_name GoodsLedger
extends RefCounted
## How much of each good the province makes and uses per minute (ROADMAP M4b-2, the
## "Kingdom stocks" window): an average over the last WINDOW_MINUTES minutes of game time.
## "Made" counts goods coming into being (gathered, harvested, produced, born, bought from
## the merchant); "used" counts goods going away (eaten, worked up, built in, served, sold).
## Statistics only: nothing in the simulation reads it, and it is not saved.

const WINDOW_MINUTES := 5
const MINUTE_TICKS := 600

## Ring of per-minute buckets: index -> {good: units}.
var _made: Array[Dictionary] = []
var _used: Array[Dictionary] = []
## Minute (tick / MINUTE_TICKS) the current bucket belongs to; -1 = nothing recorded yet.
var _minute: int = -1
## Minute recording started at (after a load the window fills up again).
var _first_minute: int = -1


func _init() -> void:
	for i: int in WINDOW_MINUTES:
		_made.append({})
		_used.append({})


func made(good: StringName, amount: int, tick: int) -> void:
	_add(_made, good, amount, tick)


func used(good: StringName, amount: int, tick: int) -> void:
	_add(_used, good, amount, tick)


## Units of [param good] made per minute, averaged over the window up to [param tick].
func made_per_minute(good: StringName, tick: int) -> float:
	return _per_minute(_made, good, tick)


func used_per_minute(good: StringName, tick: int) -> float:
	return _per_minute(_used, good, tick)


## Every good made or used within the window.
func goods() -> Array[StringName]:
	var result: Array[StringName] = []
	for buckets: Array[Dictionary] in [_made, _used]:
		for bucket: Dictionary in buckets:
			for good: StringName in bucket:
				if not result.has(good):
					result.append(good)
	result.sort()
	return result


func _add(buckets: Array[Dictionary], good: StringName, amount: int, tick: int) -> void:
	if amount <= 0 or good == &"":
		return
	_advance(tick)
	var bucket := buckets[_minute % WINDOW_MINUTES]
	bucket[good] = int(bucket.get(good, 0)) + amount


func _per_minute(buckets: Array[Dictionary], good: StringName, tick: int) -> float:
	_advance(tick)
	if _first_minute < 0:
		return 0.0
	var sum := 0
	for bucket: Dictionary in buckets:
		sum += int(bucket.get(good, 0))
	# Minutes covered so far: the full ones plus the running one, at most the window.
	var span := clampf(float(tick) / MINUTE_TICKS - _first_minute, 1.0, float(WINDOW_MINUTES))
	return sum / span


## Moves to the minute of [param tick], clearing buckets that fell out of the window.
func _advance(tick: int) -> void:
	var minute := tick / MINUTE_TICKS
	if _minute < 0:
		_minute = minute
		_first_minute = minute
		return
	if minute <= _minute:
		return
	for m: int in range(_minute + 1, mini(minute, _minute + WINDOW_MINUTES) + 1):
		_made[m % WINDOW_MINUTES].clear()
		_used[m % WINDOW_MINUTES].clear()
	_minute = minute
