class_name AgentStore
extends RefCounted
## All agents of a province by entity id, iterated in id order (spawn order).

var _by_id: Dictionary[int, Agent] = {}
## all() cached until the next add or remove (callers must not change it; a removal during a
## loop over it is safe: the old list stays as it was).
var _list: Array[Agent] = []
var _list_valid: bool = false


func add(agent: Agent) -> void:
	_by_id[agent.id] = agent
	_list_valid = false


func remove(id: int) -> void:
	if _by_id.erase(id):
		_list_valid = false


func get_agent(id: int) -> Agent:
	return _by_id.get(id) as Agent


func has_agent(id: int) -> bool:
	return _by_id.has(id)


## Every entry in id order. Read only: the same list is returned until something changes.
func all() -> Array[Agent]:
	if not _list_valid:
		_list = []
		_list.assign(_by_id.values())
		_list_valid = true
	return _list


func count() -> int:
	return _by_id.size()


func to_dict() -> Array:
	var list: Array = []
	for a: Agent in _by_id.values():
		list.append(a.to_dict())
	return list


static func from_dict(list: Array) -> AgentStore:
	var store := AgentStore.new()
	for d: Variant in list:
		store.add(Agent.from_dict(d))
	return store
