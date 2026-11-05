class_name RequestTransportCommand
extends Command
## Asks porters to move goods between storages (0 = nearest fitting storage).

var good: StringName
var amount: int
var source_id: int
var dest_id: int


func _init(good_id: StringName, qty: int, source: int, dest: int) -> void:
	good = good_id
	amount = qty
	source_id = source
	dest_id = dest


func validate(sim: Simulation) -> StringName:
	if sim.data.get_good(good) == null:
		return &"unknown_good"
	if amount <= 0 or (source_id == 0 and dest_id == 0) or source_id == dest_id:
		return &"invalid_request"
	if source_id != 0 and sim.province.storage(source_id) == null:
		return &"unknown_storage"
	if dest_id != 0 and not sim.province.accepts_deliveries(dest_id):
		return &"unknown_storage"
	return &""


func apply(sim: Simulation) -> void:
	sim.province.jobs.add(good, amount, source_id, dest_id)


func get_name() -> StringName:
	return &"request_transport"
