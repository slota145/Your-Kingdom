class_name FieldStore
extends RefCounted
## Field tiles of farms (GDD §4.4): each 1x1 tile belongs to one farm and goes
## fallow -> ploughed -> sown (3 growth stages) -> ripe -> harvested (fallow again).
## A tile can be claimed by one farmer at a time.

enum Stage { FALLOW, PLOWED, SOWN, RIPE }
## Growth stages shown while a tile is SOWN (view).
const GROWTH_STAGES := 3

## tile -> [farm_id, stage, sown_tick, ripe_tick, claimant]
var _tiles: Dictionary[Vector2i, PackedInt64Array] = {}


func has_field(tile: Vector2i) -> bool:
	return _tiles.has(tile)


func add(tile: Vector2i, farm_id: int) -> void:
	_tiles[tile] = PackedInt64Array([farm_id, Stage.FALLOW, 0, 0, 0])


func remove(tile: Vector2i) -> void:
	_tiles.erase(tile)


func farm_of(tile: Vector2i) -> int:
	return int(_tiles[tile][0]) if _tiles.has(tile) else 0


func tiles_of(farm_id: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for tile: Vector2i in _tiles:
		if _tiles[tile][0] == farm_id:
			result.append(tile)
	result.sort()
	return result


func all_tiles() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	result.assign(_tiles.keys())
	result.sort()
	return result


## Stage at [param tick]: a sown tile turns ripe by itself once its time has come.
func stage(tile: Vector2i, tick: int) -> Stage:
	if not _tiles.has(tile):
		return Stage.FALLOW
	var f := _tiles[tile]
	if f[1] == Stage.SOWN and tick >= f[3]:
		return Stage.RIPE
	return int(f[1]) as Stage


## 1..GROWTH_STAGES while growing, 0 otherwise (view).
func growth_stage(tile: Vector2i, tick: int) -> int:
	if stage(tile, tick) != Stage.SOWN:
		return 0
	var f := _tiles[tile]
	var total := maxi(int(f[3] - f[2]), 1)
	return clampi(1 + (tick - int(f[2])) * GROWTH_STAGES / total, 1, GROWTH_STAGES)


func set_stage(tile: Vector2i, new_stage: Stage) -> void:
	if _tiles.has(tile):
		_tiles[tile][1] = new_stage


func sow(tile: Vector2i, tick: int, grow_ticks: int) -> void:
	if _tiles.has(tile):
		var f := _tiles[tile]
		f[1] = Stage.SOWN
		f[2] = tick
		f[3] = tick + grow_ticks
		_tiles[tile] = f


func claimant(tile: Vector2i) -> int:
	return int(_tiles[tile][4]) if _tiles.has(tile) else 0


func claim(tile: Vector2i, agent_id: int) -> bool:
	if not _tiles.has(tile) or claimant(tile) not in [0, agent_id]:
		return false
	_tiles[tile][4] = agent_id
	return true


func release(tile: Vector2i, agent_id: int) -> void:
	if _tiles.has(tile) and _tiles[tile][4] == agent_id:
		_tiles[tile][4] = 0


func release_owner(agent_id: int) -> void:
	for tile: Vector2i in _tiles:
		if _tiles[tile][4] == agent_id:
			_tiles[tile][4] = 0


func count() -> int:
	return _tiles.size()


func to_dict() -> Array:
	var list: Array = []
	for tile: Vector2i in all_tiles():
		var f := _tiles[tile]
		list.append([tile.x, tile.y, f[0], f[1], f[2], f[3], f[4]])
	return list


static func from_dict(list: Array) -> FieldStore:
	var store := FieldStore.new()
	for entry: Variant in list:
		var e: Array = entry
		store._tiles[Vector2i(int(e[0]), int(e[1]))] = PackedInt64Array(
				[int(e[2]), int(e[3]), int(e[4]), int(e[5]), int(e[6])])
	return store
