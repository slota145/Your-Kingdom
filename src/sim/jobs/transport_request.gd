class_name TransportRequest
extends RefCounted
## "Move [member amount] of [member good] from source to destination" (ARCHITECTURE §5.2).
## Source or destination 0 means "the nearest storage that fits".

var id: int
var good: StringName
## Units not yet delivered (including those on the way).
var amount: int
var source_id: int
var dest_id: int
## Units currently carried or reserved by assigned porters.
var in_flight: int = 0
## No new porters before this tick (set after a failure).
var retry_at: int = 0


func _init(request_id: int, good_id: StringName, qty: int, source: int, dest: int) -> void:
	id = request_id
	good = good_id
	amount = qty
	source_id = source
	dest_id = dest


func unassigned() -> int:
	return amount - in_flight


func to_dict() -> Dictionary:
	return {"id": id, "good": String(good), "amount": amount, "from": source_id, "to": dest_id,
			"in_flight": in_flight, "retry_at": retry_at}


static func from_dict(d: Dictionary) -> TransportRequest:
	var r := TransportRequest.new(int(d["id"]), StringName(String(d["good"])), int(d["amount"]),
			int(d["from"]), int(d["to"]))
	r.in_flight = int(d.get("in_flight", 0))
	r.retry_at = int(d.get("retry_at", 0))
	return r
