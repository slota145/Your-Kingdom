class_name SimEvents
extends RefCounted
## One-off events from the simulation for the view and UI (ARCHITECTURE §4.3).
## Each event is a Dictionary with "type" (StringName), "tick" and type-specific fields.
## Events are drained every frame and are not part of the save.

var tick: int = 0

var _queue: Array[Dictionary] = []


func emit(type: StringName, fields: Dictionary = {}) -> void:
	var event := fields.duplicate()
	event["type"] = type
	event["tick"] = tick
	_queue.append(event)


func drain() -> Array[Dictionary]:
	var events := _queue
	_queue = []
	return events


func count() -> int:
	return _queue.size()
