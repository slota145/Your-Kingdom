class_name JobBoard
extends RefCounted
## Open transport requests and their greedy matching to idle porters (ARCHITECTURE §5.2):
## every MATCH_INTERVAL ticks each request in id order gets the nearest idle porter,
## at most MAX_ASSIGNMENTS per round.

const MATCH_INTERVAL := 5
const MAX_ASSIGNMENTS := 32
## Units a porter carries per trip.
const PORTER_LOAD := 1
## Wait before a request is offered again after a failed trip (5 s).
const RETRY_TICKS := 50
const PORTER_KIND := &"porter"

var _requests: Dictionary[int, TransportRequest] = {}
var _next_id: int = 1


func add(good: StringName, amount: int, source_id: int, dest_id: int) -> int:
	if amount <= 0:
		return 0
	var request := TransportRequest.new(_next_id, good, amount, source_id, dest_id)
	_next_id += 1
	_requests[request.id] = request
	return request.id


func get_request(id: int) -> TransportRequest:
	return _requests.get(id) as TransportRequest


func all() -> Array[TransportRequest]:
	var result: Array[TransportRequest] = []
	result.assign(_requests.values())
	return result


func count() -> int:
	return _requests.size()


func cancel(id: int) -> void:
	_requests.erase(id)


## Drops requests that start or end at a removed entity. Porters on the way fail by themselves.
func cancel_for_entity(entity_id: int) -> void:
	for request: TransportRequest in all():
		if request.source_id == entity_id or request.dest_id == entity_id:
			_requests.erase(request.id)


func has_request_from(entity_id: int) -> bool:
	for request: TransportRequest in _requests.values():
		if request.source_id == entity_id:
			return true
	return false


func on_completed(id: int, amount: int) -> void:
	var request := get_request(id)
	if request == null:
		return
	request.amount -= amount
	request.in_flight = maxi(request.in_flight - amount, 0)
	if request.amount <= 0:
		_requests.erase(id)


func on_failed(province: ProvinceSim, id: int, amount: int) -> void:
	var request := get_request(id)
	if request == null:
		return
	request.in_flight = maxi(request.in_flight - amount, 0)
	request.retry_at = province.tick + RETRY_TICKS


func update(province: ProvinceSim) -> void:
	if province.tick % MATCH_INTERVAL != 0 or _requests.is_empty():
		return
	var idle: Array[Agent] = []
	for agent: Agent in province.agents.all():
		if agent.kind == PORTER_KIND and agent.is_idle() and not agent.is_carrying():
			idle.append(agent)
	var assigned := 0
	for request: TransportRequest in all():
		while not idle.is_empty() and assigned < MAX_ASSIGNMENTS and request.unassigned() > 0 \
				and request.retry_at <= province.tick:
			if not _assign_one(province, request, idle):
				break
			assigned += 1
		if idle.is_empty() or assigned >= MAX_ASSIGNMENTS:
			return


func _assign_one(province: ProvinceSim, request: TransportRequest, idle: Array[Agent]) -> bool:
	var load := mini(PORTER_LOAD, request.unassigned())
	if (request.source_id != 0 and province.storage(request.source_id) == null) \
			or (request.dest_id != 0 and not province.accepts_deliveries(request.dest_id)):
		_requests.erase(request.id)
		return false
	var src := request.source_id
	if src == 0:
		src = province.nearest_source(request.good, load, province.access_tile(request.dest_id),
				request.dest_id)
	var source := province.storage(src)
	if source == null or not source.can_supply(request.good, load):
		return false
	if request.dest_id != 0:
		if not province.storage(request.dest_id).can_accept(request.good, load):
			return false
	elif province.nearest_sink(request.good, load, province.access_tile(src), src) == 0:
		return false
	var from := IsoMath.tile_center(province.access_tile(src))
	var best := 0
	for i: int in range(1, idle.size()):
		if idle[i].pos.distance_squared_to(from) < idle[best].pos.distance_squared_to(from):
			best = i
	var porter := idle[best]
	idle.remove_at(best)
	TaskRunner.start_transport(porter, request, load)
	porter.task.bb["from"] = src
	porter.task.bb["_src"] = src
	porter.task.bb["_res"] = source.reserve_out(request.good, load, porter.id)
	request.in_flight += load
	return true


func to_dict() -> Dictionary:
	var list: Array = []
	for request: TransportRequest in _requests.values():
		list.append(request.to_dict())
	return {"requests": list, "next": _next_id}


static func from_dict(d: Dictionary) -> JobBoard:
	var board := JobBoard.new()
	for rd: Variant in d.get("requests", []):
		var request := TransportRequest.from_dict(rd)
		board._requests[request.id] = request
	board._next_id = int(d.get("next", 1))
	return board
