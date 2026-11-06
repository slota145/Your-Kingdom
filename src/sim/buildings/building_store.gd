class_name BuildingStore
extends RefCounted
## All buildings of a province by entity id, iterated in id order.

var _by_id: Dictionary[int, BuildingState] = {}
## all() cached until the next add or remove (callers must not change it; a removal during a
## loop over it is safe: the old list stays as it was).
var _list: Array[BuildingState] = []
var _list_valid: bool = false
## Bumped on every add or remove (indexes built from the list check it).
var version: int = 0


func add(building: BuildingState) -> void:
	_by_id[building.id] = building
	_list_valid = false
	version += 1


func remove(id: int) -> void:
	if _by_id.erase(id):
		_list_valid = false
		version += 1


func get_building(id: int) -> BuildingState:
	return _by_id.get(id) as BuildingState


func has_building(id: int) -> bool:
	return _by_id.has(id)


## Every entry in id order. Read only: the same list is returned until something changes.
func all() -> Array[BuildingState]:
	if not _list_valid:
		_list = []
		_list.assign(_by_id.values())
		_list_valid = true
	return _list


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
