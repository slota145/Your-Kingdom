class_name PathRequestQueue
extends RefCounted
## FIFO of agents waiting for a path, served with a fixed budget per tick (ARCHITECTURE §5.3).

const DEFAULT_BUDGET := 32

var budget: int = DEFAULT_BUDGET

var _queue: Array[int] = []
var _head: int = 0


func push(agent_id: int) -> void:
	_queue.append(agent_id)


func size() -> int:
	return _queue.size() - _head


func pending() -> Array[int]:
	return _queue.slice(_head)


## Pops up to [member budget] agent ids for this tick.
func take_batch() -> Array[int]:
	var n := mini(budget, size())
	var batch: Array[int] = _queue.slice(_head, _head + n)
	_head += n
	if _head > 256 and _head * 2 > _queue.size():
		_queue = _queue.slice(_head)
		_head = 0
	return batch


func to_dict() -> Array:
	return pending()


static func from_dict(list: Array) -> PathRequestQueue:
	var queue := PathRequestQueue.new()
	queue._queue = SimCodec.int_array(list)
	return queue
