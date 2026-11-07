class_name Stockpile
extends RefCounted
## Goods stored in slots, one good per slot up to its stack size (GDD §4.2, ARCHITECTURE §6.5).
##
## Every pick-up and drop-off reserves first, so two carriers never take the same unit and
## nobody walks to a full store. Slot contents are the single source of truth for both the
## UI list and the stacks drawn on the ground.

## Good id per slot, &"" = empty slot.
var slot_good: Array[StringName] = []
var slot_amount: PackedInt32Array = PackedInt32Array()
var slot_in: PackedInt32Array = PackedInt32Array()
var slot_out: PackedInt32Array = PackedInt32Array()

## When > 0, no slot holds more than this (a house pantry), whatever the good's stack size.
var stack_limit: int = 0
## Each slot holds the good's stack size divided by this (rounded up): a production yard
## holds half a storage slot (M4b-2).
var stack_divisor: int = 1
## Each good keeps to one slot (market stalls, M4b-2): no second stack of a good it holds.
var one_slot_per_good: bool = false
## Good categories a storage takes (M7): an armoury only weapons; a common storage
## everything but the categories in [member never]. Set from the building's data, not saved.
var only: Array[StringName] = []
var never: Array[StringName] = []

var _data: DataRegistry
var _reservations: Dictionary[int, Reservation] = {}
var _next_reservation: int = 1


func _init(slots: int, data: DataRegistry) -> void:
	_data = data
	slot_good.resize(slots)
	slot_good.fill(&"")
	slot_amount.resize(slots)
	slot_in.resize(slots)
	slot_out.resize(slots)


func slot_count() -> int:
	return slot_good.size()


## Adds empty slots up to [param slots] (a pantry after new goods were added to the data).
func grow_to(slots: int) -> void:
	var old := slot_count()
	if slots <= old:
		return
	slot_good.resize(slots)
	for s: int in range(old, slots):
		slot_good[s] = &""
	slot_amount.resize(slots)
	slot_in.resize(slots)
	slot_out.resize(slots)


func stack_size(good: StringName) -> int:
	var def := _data.get_good(good)
	var size := def.stack_size if def != null else 1
	if stack_divisor > 1:
		size = maxi(ceili(float(size) / stack_divisor), 1)
	return mini(size, stack_limit) if stack_limit > 0 else size


func total(good: StringName) -> int:
	var sum := 0
	for s: int in slot_count():
		if slot_good[s] == good:
			sum += slot_amount[s]
	return sum


## Amount of every stored good, sorted by id. This is what the UI lists.
func totals() -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	var goods: Array[StringName] = []
	for s: int in slot_count():
		if slot_good[s] != &"" and slot_amount[s] > 0 and not goods.has(slot_good[s]):
			goods.append(slot_good[s])
	goods.sort()
	for good: StringName in goods:
		result[good] = total(good)
	return result


func total_amount() -> int:
	var sum := 0
	for a: int in slot_amount:
		sum += a
	return sum


func is_empty() -> bool:
	return total_amount() == 0 and _reservations.is_empty()


## Units that can still be reserved for pick-up.
func available(good: StringName) -> int:
	var sum := 0
	for s: int in slot_count():
		if slot_good[s] == good:
			sum += slot_amount[s] - slot_out[s]
	return sum


## Whether the categories of this storage allow [param good] at all (M7).
func takes(good: StringName) -> bool:
	if only.is_empty() and never.is_empty():
		return true
	var def := _data.get_good(good)
	var category := def.category if def != null else &""
	if not only.is_empty():
		return only.has(category)
	return not never.has(category)


## Units of space that can still be reserved for drop-off.
func free_space(good: StringName) -> int:
	if not takes(good):
		return 0
	var stack := stack_size(good)
	var sum := 0
	var held := false
	for s: int in slot_count():
		if slot_good[s] == good:
			sum += stack - slot_amount[s] - slot_in[s]
			held = true
	if held and one_slot_per_good:
		return sum
	for s: int in slot_count():
		if slot_good[s] == &"":
			sum += stack
			if one_slot_per_good:
				break
	return sum


## Whether a single reservation of [param amount] would fit (it must fit in one slot).
func can_accept(good: StringName, amount: int) -> bool:
	return _slot_for_incoming(good, amount) != -1


func can_supply(good: StringName, amount: int) -> bool:
	return _slot_for_outgoing(good, amount) != -1


## Reserves space for an incoming delivery. Returns the reservation id, 0 when it does not fit.
func reserve_in(good: StringName, amount: int, owner: int) -> int:
	var s := _slot_for_incoming(good, amount)
	if s == -1 or amount <= 0:
		return 0
	slot_good[s] = good
	slot_in[s] += amount
	return _add_reservation(owner, s, good, amount, true)


## Reserves stored goods for pick-up. Returns the reservation id, 0 when not enough.
func reserve_out(good: StringName, amount: int, owner: int) -> int:
	var s := _slot_for_outgoing(good, amount)
	if s == -1 or amount <= 0:
		return 0
	slot_out[s] += amount
	return _add_reservation(owner, s, good, amount, false)


func has_reservation(res_id: int) -> bool:
	return _reservations.has(res_id)


func get_reservation(res_id: int) -> Reservation:
	return _reservations.get(res_id) as Reservation


## Executes a reservation: puts goods into or takes them out of the slot.
## Returns the amount moved, 0 when the reservation does not exist.
func commit(res_id: int) -> int:
	var res := get_reservation(res_id)
	if res == null:
		return 0
	_reservations.erase(res_id)
	if res.incoming:
		slot_in[res.slot] -= res.amount
		slot_amount[res.slot] += res.amount
	else:
		slot_out[res.slot] -= res.amount
		slot_amount[res.slot] -= res.amount
	_tidy(res.slot)
	return res.amount


func cancel(res_id: int) -> void:
	var res := get_reservation(res_id)
	if res == null:
		return
	_reservations.erase(res_id)
	if res.incoming:
		slot_in[res.slot] -= res.amount
	else:
		slot_out[res.slot] -= res.amount
	_tidy(res.slot)


## Cancels every reservation of [param owner]. Returns how many were released.
func release_owner(owner: int) -> int:
	var ids: Array[int] = []
	for res: Reservation in _reservations.values():
		if res.owner == owner:
			ids.append(res.id)
	for res_id: int in ids:
		cancel(res_id)
	return ids.size()


func reservations() -> Array[Reservation]:
	var result: Array[Reservation] = []
	result.assign(_reservations.values())
	return result


func reservation_count() -> int:
	return _reservations.size()


## Takes unreserved goods directly, without carriers (households eating). Returns the amount taken.
func remove(good: StringName, amount: int) -> int:
	var left := amount
	for s: int in slot_count():
		if left == 0:
			break
		if slot_good[s] != good:
			continue
		var take := mini(left, slot_amount[s] - slot_out[s])
		if take > 0:
			slot_amount[s] -= take
			left -= take
			_tidy(s)
	return amount - left


## Stores goods directly, without carriers (map setup, tests). Returns what did not fit.
func add(good: StringName, amount: int) -> int:
	if not takes(good):
		return amount
	var left := amount
	var stack := stack_size(good)
	for pass_empty: bool in [false, true]:
		if pass_empty and one_slot_per_good and slot_good.has(good):
			return left
		for s: int in slot_count():
			if left == 0:
				return 0
			var fits := (slot_good[s] == good) if not pass_empty else (slot_good[s] == &"")
			if not fits:
				continue
			var put := mini(left, stack - slot_amount[s] - slot_in[s])
			if put <= 0:
				continue
			slot_good[s] = good
			slot_amount[s] += put
			left -= put
			if one_slot_per_good:
				return left
	return left


## Slot counters agree with the reservation list and stay within the stack size.
func is_consistent() -> bool:
	var ins := PackedInt32Array()
	var outs := PackedInt32Array()
	ins.resize(slot_count())
	outs.resize(slot_count())
	for res: Reservation in _reservations.values():
		if slot_good[res.slot] != res.good:
			return false
		if res.incoming:
			ins[res.slot] += res.amount
		else:
			outs[res.slot] += res.amount
	for s: int in slot_count():
		if ins[s] != slot_in[s] or outs[s] != slot_out[s]:
			return false
		if slot_amount[s] - slot_out[s] < 0:
			return false
		if slot_good[s] != &"" and slot_amount[s] + slot_in[s] > stack_size(slot_good[s]):
			return false
		if slot_good[s] == &"" and (slot_amount[s] != 0 or slot_in[s] != 0):
			return false
	return true


func to_dict() -> Dictionary:
	var slots: Array = []
	for s: int in slot_count():
		slots.append([String(slot_good[s]), slot_amount[s]])
	var reservations: Array = []
	for res: Reservation in _reservations.values():
		reservations.append(res.to_dict())
	var d := {"slots": slots, "reservations": reservations, "next": _next_reservation}
	if stack_limit > 0:
		d["limit"] = stack_limit
	if stack_divisor > 1:
		d["div"] = stack_divisor
	if one_slot_per_good:
		d["single"] = true
	return d


static func from_dict(d: Dictionary, data: DataRegistry) -> Stockpile:
	var slots: Array = d.get("slots", [])
	var stock := Stockpile.new(slots.size(), data)
	stock.stack_limit = int(d.get("limit", 0))
	stock.stack_divisor = maxi(int(d.get("div", 1)), 1)
	stock.one_slot_per_good = bool(d.get("single", false))
	for s: int in slots.size():
		var entry: Array = slots[s]
		stock.slot_good[s] = StringName(String(entry[0]))
		stock.slot_amount[s] = int(entry[1])
	for rd: Variant in d.get("reservations", []):
		var res := Reservation.from_dict(rd)
		stock._reservations[res.id] = res
		if res.incoming:
			stock.slot_in[res.slot] += res.amount
		else:
			stock.slot_out[res.slot] += res.amount
	stock._next_reservation = int(d.get("next", 1))
	return stock


func _slot_for_incoming(good: StringName, amount: int) -> int:
	if not takes(good):
		return -1
	var stack := stack_size(good)
	for s: int in slot_count():
		if slot_good[s] == good and slot_amount[s] + slot_in[s] + amount <= stack:
			return s
	if amount > stack:
		return -1
	if one_slot_per_good:
		for s: int in slot_count():
			if slot_good[s] == good:
				return -1
	for s: int in slot_count():
		if slot_good[s] == &"":
			return s
	return -1


func _slot_for_outgoing(good: StringName, amount: int) -> int:
	for s: int in slot_count():
		if slot_good[s] == good and slot_amount[s] - slot_out[s] >= amount:
			return s
	return -1


func _add_reservation(owner: int, slot: int, good: StringName, amount: int, incoming: bool) -> int:
	var res := Reservation.new(_next_reservation, owner, slot, good, amount, incoming)
	_next_reservation += 1
	_reservations[res.id] = res
	return res.id


func _tidy(slot: int) -> void:
	if slot_amount[slot] == 0 and slot_in[slot] == 0 and slot_out[slot] == 0:
		slot_good[slot] = &""
