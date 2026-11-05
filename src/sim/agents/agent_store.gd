class_name AgentStore
extends RefCounted
## All agents of a province by entity id, iterated in id order (spawn order).

var _by_id: Dictionary[int, Agent] = {}


func add(agent: Agent) -> void:
	_by_id[agent.id] = agent


func remove(id: int) -> void:
	_by_id.erase(id)


func get_agent(id: int) -> Agent:
	return _by_id.get(id) as Agent


func has_agent(id: int) -> bool:
	return _by_id.has(id)


func all() -> Array[Agent]:
	var result: Array[Agent] = []
	result.assign(_by_id.values())
	return result


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
