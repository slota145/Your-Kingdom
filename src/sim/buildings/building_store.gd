class_name BuildingStore
extends RefCounted
## All buildings of a province by entity id, iterated in id order.

var _by_id: Dictionary[int, BuildingState] = {}


func add(building: BuildingState) -> void:
	_by_id[building.id] = building


func remove(id: int) -> void:
	_by_id.erase(id)


func get_building(id: int) -> BuildingState:
	return _by_id.get(id) as BuildingState


func has_building(id: int) -> bool:
	return _by_id.has(id)


func all() -> Array[BuildingState]:
	var result: Array[BuildingState] = []
	result.assign(_by_id.values())
	return result


func count() -> int:
	return _by_id.size()


func to_dict() -> Array:
	var list: Array = []
	for b: BuildingState in _by_id.values():
		list.append(b.to_dict())
	return list


static func from_dict(list: Array, data: DataRegistry) -> BuildingStore:
	var store := BuildingStore.new()
	for d: Variant in list:
		store.add(BuildingState.from_dict(d, data))
	return store
