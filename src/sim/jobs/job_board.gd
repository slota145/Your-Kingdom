class_name JobBoard
extends RefCounted
## Open transport requests and their greedy matching to idle porters (ARCHITECTURE §5.2):
## every MATCH_INTERVAL ticks each request in id order gets the nearest idle porter,
## at most MAX_ASSIGNMENTS per round. Big requests over longer distances go to idle carters
## with horse wagons first (M4b-3, Carriers).

const MATCH_INTERVAL := 5
const MAX_ASSIGNMENTS := 32
## Units a porter carries per trip.
const PORTER_LOAD := 1
## Wait before a request is offered again after a failed trip (5 s).
const RETRY_TICKS := 50
## Wait before a request nobody could take (no goods, no room) is offered again (2 s).
const NO_MATCH_RETRY_TICKS := 20
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


## Units of the request for [param good] from [param source_id] to [param dest_id] being
## carried right now (0 when there is no such request).
func in_flight(good: StringName, source_id: int, dest_id: int) -> int:
	for request: TransportRequest in _requests.values():
		if request.good == good and request.source_id == source_id and request.dest_id == dest_id:
			return request.in_flight
	return 0


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
	var carters: Array[Agent] = []
	## Port id -> its idle dockers (M5 part 2): they carry only between its quay and a ship.
	var dockers: Dictionary[int, Array] = {}
	var docker_count := 0
	for agent: Agent in province.agents.all():
		if agent.kind == PORTER_KIND and agent.is_idle() and not agent.is_carrying():
			idle.append(agent)
		elif agent.kind == Carriers.CARTER_KIND and Carriers.carter_ready(province, agent):
			carters.append(agent)
		elif agent.kind == Harbour.DOCKER_KIND and agent.is_idle() and not agent.is_carrying():
			if not dockers.has(agent.workplace_id):
				dockers[agent.workplace_id] = [] as Array[Agent]
			dockers[agent.workplace_id].append(agent)
			docker_count += 1
	var assigned := 0
	for request: TransportRequest in all():
		var crews: Variant = Harbour.request_crews(province, request) if docker_count > 0 \
				or (not province.ships.is_empty() and _touches_ship(province, request)) else null
		if crews != null:
			# Port work (P2 part 1): the dockers of the crews that serve this dock or harbour
			# building; the cargo of a ship only them, other port goods them before porters.
			var ship_cargo := Harbour.request_port(province, request) != 0
			while assigned < MAX_ASSIGNMENTS and request.unassigned() > 0 and request.retry_at <= province.tick:
				var pool := _crew_pool(dockers, crews)
				if pool.is_empty():
					break
				var before := pool.size()
				if not _assign_one(province, request, pool):
					if ship_cargo and request.in_flight == 0:
						request.retry_at = province.tick + NO_MATCH_RETRY_TICKS
					break
				if pool.size() < before:
					_take_from_crews(dockers, crews, pool)
					docker_count -= 1
				assigned += 1
			if ship_cargo:
				continue
		var porter_failed := false
		while not carters.is_empty() and assigned < MAX_ASSIGNMENTS \
				and request.unassigned() >= Carriers.WAGON_MIN and request.retry_at <= province.tick:
			if not _assign_wagon(province, request, carters):
				break
			assigned += 1
		while not idle.is_empty() and assigned < MAX_ASSIGNMENTS and request.unassigned() > 0 \
				and request.retry_at <= province.tick:
			if not _assign_one(province, request, idle):
				porter_failed = true
				break
			assigned += 1
		if porter_failed and request.in_flight == 0:
			# Nothing to take or no room for it now: ask again a little later, not every
			# round (M4b-3: each try searches the storages).
			request.retry_at = province.tick + NO_MATCH_RETRY_TICKS
		if (idle.is_empty() and carters.is_empty() and docker_count <= 0) or assigned >= MAX_ASSIGNMENTS:
			return


static func _touches_ship(province: ProvinceSim, request: TransportRequest) -> bool:
	return province.ships.has(request.source_id) or province.ships.has(request.dest_id)


## The idle dockers of [param crews] (workplace ids) in one list.
static func _crew_pool(dockers: Dictionary[int, Array], crews: Array) -> Array[Agent]:
	var pool: Array[Agent] = []
	for crew: int in crews:
		for agent: Agent in dockers.get(crew, []):
			pool.append(agent)
	return pool


## Takes from [param dockers] the one docker of [param crews] no longer in [param pool] (the
## one [method _assign_one] just gave a task).
static func _take_from_crews(dockers: Dictionary[int, Array], crews: Array, pool: Array[Agent]) -> void:
	for crew: int in crews:
		var list: Array = dockers.get(crew, [])
		for i: int in list.size():
			if not pool.has(list[i]):
				list.remove_at(i)
				return


func _assign_one(province: ProvinceSim, request: TransportRequest, idle: Array[Agent]) -> bool:
	# E4 part 2: "Better carrying" lets a porter take 2.
	var load := mini(PORTER_LOAD * province.research.porter_load(province.data), request.unassigned())
	if (request.source_id != 0 and province.storage(request.source_id) == null) \
			or (request.dest_id != 0 and not province.accepts_deliveries(request.dest_id)):
		_requests.erase(request.id)
		return false
	# Construction leaves each storage's reserve alone (firewood for houses, ROADMAP M4).
	var keep_reserve := province.sites.has(request.dest_id) or province.paving.has(request.dest_id) \
			or province.ship_builds.has(request.dest_id)
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


## Gives one wagon load of [param request] to the nearest of [param carters] when both ends
## have a road in front of a door, far enough apart and joined by road (M4b-3).
func _assign_wagon(province: ProvinceSim, request: TransportRequest, carters: Array[Agent]) -> bool:
	var good_def := province.data.get_good(request.good)
	if good_def == null or good_def.is_live():
		return false
	if (request.source_id != 0 and province.storage(request.source_id) == null) \
			or (request.dest_id != 0 and not province.accepts_deliveries(request.dest_id)):
		return false
	var keep_reserve := province.sites.has(request.dest_id) or province.paving.has(request.dest_id) \
			or province.ship_builds.has(request.dest_id)
	var src := request.source_id
	if src == 0:
		src = province.nearest_source(request.good, Carriers.WAGON_MIN,
				province.access_tile(request.dest_id), request.dest_id, keep_reserve)
	if src == 0 or not province.can_give(src, request.good, Carriers.WAGON_MIN, keep_reserve):
		return false
	var src_stop := province.road_stop(src)
	if src_stop == Agent.NO_TILE:
		return false
	var dst := request.dest_id
	if dst == 0:
		dst = Carriers.road_sink(province, request.good, Carriers.WAGON_MIN, src_stop, src)
	var dst_stop := province.road_stop(dst, src_stop) if dst != 0 else Agent.NO_TILE
	if dst_stop == Agent.NO_TILE or src_stop.distance_to(dst_stop) < Carriers.WAGON_MIN_TILES:
		return false
	var load := 0
	for amount: int in range(mini(Carriers.WAGON_LOAD, request.unassigned()), Carriers.WAGON_MIN - 1, -1):
		if province.can_give(src, request.good, amount, keep_reserve) \
				and province.storage(dst).can_accept(request.good, amount):
			load = amount
			break
	if load == 0:
		return false
	var best := 0
	for i: int in range(1, carters.size()):
		if carters[i].pos.distance_squared_to(Vector2(src_stop)) < carters[best].pos.distance_squared_to(Vector2(src_stop)):
			best = i
	var carter := carters[best]
	if province.road_nav.find_path(src_stop, dst_stop).is_empty() \
			or province.find_road_path(carter.tile(), src_stop).is_empty():
		return false
	carters.remove_at(best)
	carter.clear_path()
	TaskRunner.start_transport(carter, request, load)
	carter.vehicle = Carriers.WAGON
	carter.task.bb["from"] = src
	carter.task.bb["to"] = dst
	carter.task.bb["_src"] = src
	carter.task.bb["_res"] = province.storage(src).reserve_out(request.good, load, carter.id)
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
