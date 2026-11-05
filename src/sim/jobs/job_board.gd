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


## Like [method add], but grows an open request with the same good, source and destination
## (a production yard filling up unit by unit keeps one request per good).
func add_or_merge(good: StringName, amount: int, source_id: int, dest_id: int) -> int:
	for request: TransportRequest in _requests.values():
		if request.good == good and request.source_id == source_id and request.dest_id == dest_id:
			request.amount += amount
			return request.id
	return add(good, amount, source_id, dest_id)


## Makes the request for [param good] from [param source_id] to [param dest_id] ask for
## [param wanted] more units than are already on the way (the merchant's wagon, M4b-2);
## dropped when nothing is wanted or carried any more.
func set_amount(good: StringName, source_id: int, dest_id: int, wanted: int) -> void:
	for request: TransportRequest in _requests.values():
		if request.good == good and request.source_id == source_id and request.dest_id == dest_id:
			request.amount = request.in_flight + maxi(wanted, 0)
			if request.amount <= 0:
				_requests.erase(request.id)
			return
	if wanted > 0:
		add(good, wanted, source_id, dest_id)


## Shrinks requests out of a production yard (negative source id) to what the yard still
## holds: others may take from a yard directly (M4b-2). Empty ones are dropped.
func trim_yard_requests(province: ProvinceSim) -> void:
	for request: TransportRequest in all():
		if request.source_id >= 0:
			continue
		var yard := province.storage(request.source_id)
		var left := yard.available(request.good) if yard != null else 0
		if request.unassigned() > left:
			request.amount = request.in_flight + left
			if request.amount <= 0:
				_requests.erase(request.id)


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
	# Construction leaves each storage's reserve alone (firewood for houses, ROADMAP M4).
	var keep_reserve := province.sites.has(request.dest_id) or province.paving.has(request.dest_id)
	var src := request.source_id
	if src == 0:
		src = province.nearest_source(request.good, load, province.access_tile(request.dest_id),
				request.dest_id, keep_reserve)
	var source := province.storage(src)
	if source == null or not province.can_give(src, request.good, load, keep_reserve):
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
	var vehicle := &""
	if request.unassigned() >= Carriers.HANDCART_MIN and Carriers.has_free_handcart(province, porter):
		var big := _largest_load(province, request, src, mini(Carriers.HANDCART_LOAD,
				request.unassigned()), keep_reserve)
		if big >= Carriers.HANDCART_MIN:
			load = big
			vehicle = Carriers.HANDCART
	TaskRunner.start_transport(porter, request, load)
	porter.vehicle = vehicle
	porter.task.bb["from"] = src
	porter.task.bb["_src"] = src
	porter.task.bb["_res"] = source.reserve_out(request.good, load, porter.id)
	request.in_flight += load
	return true


## The most units up to [param most] of [param request] that source [param src] can give in
## one load and its destination (or some storage) can take; 1 when only that fits.
static func _largest_load(province: ProvinceSim, request: TransportRequest, src: int, most: int,
		keep_reserve: bool) -> int:
	for load: int in range(most, 1, -1):
		if not province.can_give(src, request.good, load, keep_reserve):
			continue
		if request.dest_id != 0:
			if province.storage(request.dest_id).can_accept(request.good, load):
				return load
		elif province.nearest_sink(request.good, load, province.access_tile(src), src) != 0:
			return load
	return 1


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
