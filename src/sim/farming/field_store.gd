class_name FieldStore
extends RefCounted
## Field tiles of farms (GDD §4.4): each 1x1 tile belongs to one farm and goes
## fallow -> ploughed -> sown (3 growth stages) -> ripe -> harvested (fallow again).
## A tile can be claimed by one farmer at a time.
##
## E1 part 2 (owner 2026-11-10): the whole field grows together. A sown tile waits (sown, not
## growing yet) until the farm has no fallow or ploughed tile left, then all its waiting tiles
## start growing at once; so the crop ripens together and is reaped together. A waiting tile
## keeps its grow time as a negative ripe tick (-ticks) until it starts.

enum Stage { FALLOW, PLOWED, SOWN, RIPE }
## Growth stages shown while a tile is SOWN (view).
const GROWTH_STAGES := 3

## A waiting tile starts after this long even if the farm still has unsown tiles (a farmer who
## cannot reach a tile, a farm without a farmer for its last tiles): no field waits forever.
const WAIT_LIMIT_SECONDS := 180.0

## tile -> [farm_id, stage, sown_tick (growth start once growing), ripe_tick (-grow ticks while
## waiting), claimant]
var _tiles: Dictionary[Vector2i, PackedInt64Array] = {}


func has_field(tile: Vector2i) -> bool:
	return _tiles.has(tile)


func add(tile: Vector2i, farm_id: int) -> void:
	_tiles[tile] = PackedInt64Array([farm_id, Stage.FALLOW, 0, 0, 0])


func remove(tile: Vector2i) -> void:
	_tiles.erase(tile)


func farm_of(tile: Vector2i) -> int:
	return int(_tiles[tile][0]) if _tiles.has(tile) else 0


## Fields per farm id (one pass over all fields).
func counts() -> Dictionary[int, int]:
	var result: Dictionary[int, int] = {}
	for tile: Vector2i in _tiles:
		var farm: int = _tiles[tile][0]
		result[farm] = result.get(farm, 0) + 1
	return result


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
	if f[1] == Stage.SOWN and f[3] >= 0 and tick >= f[3]:
		return Stage.RIPE
	return int(f[1]) as Stage


## Whether [param tile] is sown and waits for the rest of its field before it grows.
func is_waiting(tile: Vector2i) -> bool:
	return _tiles.has(tile) and _tiles[tile][1] == Stage.SOWN and _tiles[tile][3] < 0


## Whether [param tile] is sown and growing (not waiting, not ripe yet).
func is_growing(tile: Vector2i, tick: int) -> bool:
	return stage(tile, tick) == Stage.SOWN and not is_waiting(tile)


## 1..GROWTH_STAGES while growing, 0 otherwise (also while waiting: freshly sown soil, view).
func growth_stage(tile: Vector2i, tick: int) -> int:
	if stage(tile, tick) != Stage.SOWN or is_waiting(tile):
		return 0
	var f := _tiles[tile]
	var total := maxi(int(f[3] - f[2]), 1)
	return clampi(1 + (tick - int(f[2])) * GROWTH_STAGES / total, 1, GROWTH_STAGES)


func set_stage(tile: Vector2i, new_stage: Stage) -> void:
	if _tiles.has(tile):
		_tiles[tile][1] = new_stage


## Sows [param tile]: it waits for the rest of the field (E1), then grows [param grow_ticks];
## [param growing] starts it growing at [param tick] at once (map setup, screenshots).
func sow(tile: Vector2i, tick: int, grow_ticks: int, growing: bool = false) -> void:
	if _tiles.has(tile):
		var f := _tiles[tile]
		f[1] = Stage.SOWN
		f[2] = tick
		f[3] = tick + grow_ticks if growing else -maxi(grow_ticks, 1)
		_tiles[tile] = f


## Starts the waiting tiles of [param farm_id] growing when none of its tiles is fallow or
## ploughed any more, or when one has waited WAIT_LIMIT_SECONDS. Returns the tiles started.
func start_if_ready(farm_id: int, tick: int) -> Array[Vector2i]:
	var waiting: Array[Vector2i] = []
	var unsown := false
	var oldest := tick
	for tile: Vector2i in tiles_of(farm_id):
		var f := _tiles[tile]
		if f[1] == Stage.FALLOW or f[1] == Stage.PLOWED:
			unsown = true
		elif f[1] == Stage.SOWN and f[3] < 0:
			waiting.append(tile)
			oldest = mini(oldest, int(f[2]))
	if waiting.is_empty():
		return waiting
	if unsown and tick - oldest < SimClock.seconds_to_ticks(WAIT_LIMIT_SECONDS):
		return [] as Array[Vector2i]
	for tile: Vector2i in waiting:
		var f := _tiles[tile]
		f[3] = tick - f[3]
		f[2] = tick
		_tiles[tile] = f
	return waiting


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
