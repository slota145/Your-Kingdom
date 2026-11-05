class_name ResourceField
extends RefCounted
## Resource nodes on map tiles (trees...). A node keeps its kind when depleted, so a
## felled tree leaves a stump. Each node can be claimed by one worker at a time.

var size: Vector2i

## Node definitions by kind index; tile kind 0 = no node, k = _kinds[k - 1].
var _kinds: Array[ResourceNodeDef] = []
var _kind: PackedByteArray = PackedByteArray()
var _amount: PackedByteArray = PackedByteArray()
## Agent id holding the claim, 0 = free. Saved.
var _claim: PackedInt32Array = PackedInt32Array()


func _init(grid_size: Vector2i) -> void:
	size = grid_size
	_kind.resize(size.x * size.y)
	_amount.resize(size.x * size.y)
	_claim.resize(size.x * size.y)


func place(tile: Vector2i, def: ResourceNodeDef) -> void:
	if not _inside(tile):
		return
	var k := _kinds.find(def)
	if k == -1:
		_kinds.append(def)
		k = _kinds.size() - 1
	var i := _index(tile)
	_kind[i] = k + 1
	_amount[i] = def.amount
	_claim[i] = 0


func clear(tile: Vector2i) -> void:
	if _inside(tile):
		var i := _index(tile)
		_kind[i] = 0
		_amount[i] = 0
		_claim[i] = 0


## Node definition at the tile (also for depleted nodes), or null.
func def_at(tile: Vector2i) -> ResourceNodeDef:
	if not _inside(tile) or _kind[_index(tile)] == 0:
		return null
	return _kinds[_kind[_index(tile)] - 1]


func amount(tile: Vector2i) -> int:
	return _amount[_index(tile)] if _inside(tile) else 0


func has_node(tile: Vector2i, id: StringName = &"") -> bool:
	var def := def_at(tile)
	return def != null and amount(tile) > 0 and (id == &"" or def.id == id)


func is_depleted(tile: Vector2i) -> bool:
	return def_at(tile) != null and amount(tile) == 0


func blocks_movement(tile: Vector2i) -> bool:
	var def := def_at(tile)
	return def != null and def.solid and amount(tile) > 0


func claimant(tile: Vector2i) -> int:
	return _claim[_index(tile)] if _inside(tile) else 0


func claim(tile: Vector2i, agent_id: int) -> bool:
	if not has_node(tile) or claimant(tile) not in [0, agent_id]:
		return false
	_claim[_index(tile)] = agent_id
	return true


func release(tile: Vector2i, agent_id: int) -> void:
	if _inside(tile) and _claim[_index(tile)] == agent_id:
		_claim[_index(tile)] = 0


## Takes up to the node's per_gather amount. Returns the amount taken (0 = nothing left).
func take(tile: Vector2i) -> int:
	if not has_node(tile):
		return 0
	var i := _index(tile)
	var taken := mini(_kinds[_kind[i] - 1].per_gather, _amount[i])
	_amount[i] -= taken
	if _amount[i] == 0:
		_claim[i] = 0
	return taken


## Nearest unclaimed node of [param id] within [param radius] (Chebyshev) of [param center].
## Ties go to the lower row, then the lower column, so the result is deterministic.
## Returns Vector2i(-1, -1) when none.
func find_nearest(id: StringName, center: Vector2i, radius: int) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := 1 << 30
	for y: int in range(maxi(center.y - radius, 0), mini(center.y + radius + 1, size.y)):
		for x: int in range(maxi(center.x - radius, 0), mini(center.x + radius + 1, size.x)):
			var t := Vector2i(x, y)
			if not has_node(t, id) or _claim[_index(t)] != 0:
				continue
			var d := (t - center).length_squared()
			if d < best_d:
				best_d = d
				best = t
	return best


func tiles_with_nodes() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for i: int in _kind.size():
		if _kind[i] != 0:
			result.append(Vector2i(i % size.x, i / size.x))
	return result


func to_dict() -> Dictionary:
	var kinds: Array = []
	for def: ResourceNodeDef in _kinds:
		kinds.append(String(def.id))
	var claims: Array = []
	for i: int in _claim.size():
		if _claim[i] != 0:
			claims.append(i)
			claims.append(_claim[i])
	return {
		"kinds": kinds,
		"kind": Marshalls.raw_to_base64(_kind),
		"amount": Marshalls.raw_to_base64(_amount),
		"claims": claims,
	}


static func from_dict(d: Dictionary, grid_size: Vector2i, data: DataRegistry) -> ResourceField:
	var field := ResourceField.new(grid_size)
	for id: Variant in d.get("kinds", []):
		field._kinds.append(data.get_resource_node(StringName(String(id))))
	var kind := Marshalls.base64_to_raw(String(d.get("kind", "")))
	var amount := Marshalls.base64_to_raw(String(d.get("amount", "")))
	if kind.size() == field._kind.size() and amount.size() == field._amount.size():
		field._kind = kind
		field._amount = amount
	var claims := SimCodec.int_array(d.get("claims", []))
	for i: int in range(0, claims.size() - 1, 2):
		field._claim[claims[i]] = claims[i + 1]
	return field


func _inside(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < size.x and tile.y < size.y


func _index(tile: Vector2i) -> int:
	return tile.y * size.x + tile.x
