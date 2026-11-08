class_name Walls
extends RefCounted
## Walls of a province (M7 part 2, GDD §5.3, ARCHITECTURE §6.3): palisades, stone walls and
## stairs laid tile by tile, each tile with its own life. Gatehouses and towers are buildings
## (BuildingDef.fort_kind); their tiles are registered here too, because stone walls join
## them and people walk on their tops.
##
## Stone walls use the block model with "straight" diagonals: a free tile between two stone
## blocks standing corner to corner gets a wedge (wedge rule as the view, BlockWallModel). A
## wedge is solid on the ground and part of the crown people walk on.
##
## Stairs lean against a stone wall: walkable on the ground, they lead up to the wall tile in
## their direction ([method stairs_top]).

const NONE := 0
const PALISADE := 1
const STONE := 2
## Stairs: STAIRS + d, d = index in DIRS of the step from the stairs to the wall they climb.
const STAIRS := 3
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]

## Life of a tile of each kind (ROADMAP M7, starting values).
const PALISADE_HP := 300
const STONE_HP := 1000
const STAIRS_HP := 400

var size: Vector2i
var _kind: PackedByteArray = PackedByteArray()
var _hp: PackedInt32Array = PackedInt32Array()
## Tiles of fortification buildings (gatehouse, tower) -> building id. Not saved: rebuilt
## from the buildings on load.
var fort_tiles: Dictionary[Vector2i, int] = {}
## Wedge tiles of stone walls. Not saved: derived.
var wedges: Dictionary[Vector2i, bool] = {}
## Bumped on every change (views and the wall-top navigation rebuild then).
var version: int = 0
var _count: int = 0


func _init(grid_size: Vector2i) -> void:
	size = grid_size
	_kind.resize(size.x * size.y)
	_hp.resize(size.x * size.y)


func is_inside(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < size.x and tile.y < size.y


func kind(tile: Vector2i) -> int:
	return _kind[tile.y * size.x + tile.x] if is_inside(tile) else NONE


func is_empty() -> bool:
	return _count == 0 and fort_tiles.is_empty()


## A palisade or stone wall (not stairs).
func is_wall(tile: Vector2i) -> bool:
	var k := kind(tile)
	return k == PALISADE or k == STONE


func is_stone(tile: Vector2i) -> bool:
	return kind(tile) == STONE


## A stone wall tile or a tile of a gatehouse or tower: the stone mass walls join.
func is_mass(tile: Vector2i) -> bool:
	return kind(tile) == STONE or fort_tiles.has(tile)


func is_stairs(tile: Vector2i) -> bool:
	return kind(tile) >= STAIRS


## Direction index (DIRS) of the stairs at [param tile], -1 when none.
func stairs_dir(tile: Vector2i) -> int:
	var k := kind(tile)
	return k - STAIRS if k >= STAIRS else -1


## The wall-top tile the stairs at [param tile] lead to (Agent.NO_TILE when none).
func stairs_top(tile: Vector2i) -> Vector2i:
	var d := stairs_dir(tile)
	return tile + DIRS[d] if d >= 0 else Agent.NO_TILE


## Whether people cannot walk on the ground at [param tile] because of a wall.
func blocks_ground(tile: Vector2i) -> bool:
	return is_wall(tile) or wedges.has(tile)


## Whether people can stand on the crown at [param tile] (stone walls, wedges, gatehouse
## and tower tops). Palisades have no wall-walk.
func is_walkway(tile: Vector2i) -> bool:
	return kind(tile) == STONE or wedges.has(tile) or fort_tiles.has(tile)


func hp(tile: Vector2i) -> int:
	return _hp[tile.y * size.x + tile.x] if is_inside(tile) else 0


static func max_hp_of(wall_kind: int) -> int:
	match wall_kind:
		PALISADE: return PALISADE_HP
		STONE: return STONE_HP
		NONE: return 0
	return STAIRS_HP


## Lays (or with NONE removes) a wall tile at full life.
func set_kind(tile: Vector2i, wall_kind: int) -> void:
	if not is_inside(tile):
		return
	var i := tile.y * size.x + tile.x
	if (_kind[i] != NONE) != (wall_kind != NONE):
		_count += 1 if wall_kind != NONE else -1
	_kind[i] = wall_kind
	_hp[i] = max_hp_of(wall_kind)
	_update_wedges_near(tile)
	version += 1


## Takes [param amount] of life off the tile; true when it falls (the tile is gone then).
func damage(tile: Vector2i, amount: int) -> bool:
	if kind(tile) == NONE:
		return false
	var i := tile.y * size.x + tile.x
	_hp[i] = maxi(_hp[i] - amount, 0)
	if _hp[i] > 0:
		return false
	set_kind(tile, NONE)
	return true


func add_fort(tiles: Array[Vector2i], building_id: int) -> void:
	for tile: Vector2i in tiles:
		fort_tiles[tile] = building_id
		if kind(tile) != NONE:
			set_kind(tile, NONE)
	for tile: Vector2i in tiles:
		_update_wedges_near(tile)
	version += 1


func remove_fort(building_id: int) -> void:
	var tiles: Array[Vector2i] = []
	for tile: Vector2i in fort_tiles:
		if fort_tiles[tile] == building_id:
			tiles.append(tile)
	for tile: Vector2i in tiles:
		fort_tiles.erase(tile)
	for tile: Vector2i in tiles:
		_update_wedges_near(tile)
	version += 1


## Every laid tile (walls and stairs).
func tiles() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if _count == 0:
		return result
	for i: int in _kind.size():
		if _kind[i] != NONE:
			result.append(Vector2i(i % size.x, i / size.x))
	return result


func count() -> int:
	return _count


# --- Wedges (ARCHITECTURE §6.3, "straight" diagonals) ----------------------------------------

## Wedges that stone mass [param mass] (tile -> true, real or planned) makes. Same rule as the
## view: a free tile between two blocks corner to corner, unless the wall runs straight on
## through the other tile between them (a 90° corner or a T junction).
static func wedges_of(mass: Callable, around: Array[Vector2i]) -> Dictionary[Vector2i, bool]:
	var result: Dictionary[Vector2i, bool] = {}
	for tile: Vector2i in around:
		if not mass.call(tile):
			continue
		for d: Vector2i in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
			var other: Vector2i = tile + d
			if not mass.call(other):
				continue
			var sides: Array[Vector2i] = [tile + Vector2i(d.x, 0), tile + Vector2i(0, d.y)]
			for k: int in 2:
				if needs_wedge(mass, tile, other, sides[k], sides[1 - k]):
					result[sides[k]] = true
	return result


static func needs_wedge(mass: Callable, a: Vector2i, b: Vector2i, n: Vector2i, m: Vector2i) -> bool:
	if mass.call(n):
		return false
	if not mass.call(m):
		return true
	return not mass.call(a - (m - a)) and not mass.call(b + (b - m))


func _update_wedges_near(tile: Vector2i) -> void:
	# A wedge depends on tiles up to 2 steps away from it.
	var around: Array[Vector2i] = []
	for dy: int in range(-3, 4):
		for dx: int in range(-3, 4):
			var t := tile + Vector2i(dx, dy)
			around.append(t)
			if absi(dx) <= 2 and absi(dy) <= 2:
				wedges.erase(t)
	var found := wedges_of(is_mass, around)
	for t: Vector2i in found:
		if absi(t.x - tile.x) <= 2 and absi(t.y - tile.y) <= 2:
			wedges[t] = true


func rebuild_wedges() -> void:
	wedges = wedges_of(is_mass, tiles() + _fort_list())


func _fort_list() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	result.assign(fort_tiles.keys())
	return result


func to_dict() -> Dictionary:
	return {"kind": Marshalls.raw_to_base64(_kind),
			"hp": Marshalls.raw_to_base64(_hp.to_byte_array())}


static func from_dict(d: Dictionary, grid_size: Vector2i) -> Walls:
	var walls := Walls.new(grid_size)
	var cells := grid_size.x * grid_size.y
	var kinds := Marshalls.base64_to_raw(String(d.get("kind", "")))
	var hps := Marshalls.base64_to_raw(String(d.get("hp", ""))).to_int32_array()
	if kinds.size() == cells and hps.size() == cells:
		walls._kind = kinds
		walls._hp = hps
		walls._count = cells - kinds.count(NONE)
	return walls
