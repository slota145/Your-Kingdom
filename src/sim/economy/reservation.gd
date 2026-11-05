class_name Reservation
extends RefCounted
## A claim on goods (outgoing) or on free space (incoming) in one stockpile slot
## (ARCHITECTURE §5.2). Owned by an agent and released if its task is cancelled.

var id: int
var owner: int
var slot: int
var good: StringName
var amount: int
var incoming: bool


func _init(res_id: int, owner_id: int, slot_index: int, good_id: StringName, qty: int,
		is_incoming: bool) -> void:
	id = res_id
	owner = owner_id
	slot = slot_index
	good = good_id
	amount = qty
	incoming = is_incoming


func to_dict() -> Dictionary:
	return {"id": id, "owner": owner, "slot": slot, "good": String(good), "amount": amount,
			"in": incoming}


static func from_dict(d: Dictionary) -> Reservation:
	return Reservation.new(int(d["id"]), int(d["owner"]), int(d["slot"]),
			StringName(String(d["good"])), int(d["amount"]), bool(d["in"]))
