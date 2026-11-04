class_name ProtoCrowd
extends RefCounted
## M1 PROTOTYPE ONLY: people wandering between random tiles, ticked like the real
## simulation (fixed 10 Hz, path budget per tick) so the benchmark is representative.
## Replaced by the real AgentStore/TaskRunner in M2.

const TICK := 0.1
const SPEED := 1.2           # tiles per second (ARCHITECTURE §5.4)
const PATH_BUDGET := 32      # path queries per tick (ARCHITECTURE §5.3)
const CARRY_CYCLE: Array[StringName] = [&"", &"flour", &"bread", &"grain"]

var nav: NavGrid
var area: Rect2i
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var count: int = 0

var pos: PackedVector2Array = PackedVector2Array()
var prev: PackedVector2Array = PackedVector2Array()
var facing: PackedByteArray = PackedByteArray()
var moving: PackedByteArray = PackedByteArray()
var wait: PackedFloat32Array = PackedFloat32Array()
var path_index: PackedInt32Array = PackedInt32Array()
var paths: Array[Array] = []
var good: Array[StringName] = []
var character: Array[StringName] = []

## Duration of the last tick in microseconds.
var last_tick_usec: int = 0

var _queue: Array[int] = []


func _init(nav_grid: NavGrid, walk_area: Rect2i, seed_value: int = 1) -> void:
	nav = nav_grid
	area = walk_area
	rng.seed = seed_value


func spawn(amount: int, characters: Array[StringName]) -> void:
	for i: int in amount:
		var tile := _random_walkable()
		pos.append(IsoMath.tile_center(tile))
		prev.append(pos[count])
		facing.append(rng.randi_range(0, IsoMath.DIR_COUNT - 1))
		moving.append(0)
		wait.append(rng.randf_range(0.0, 2.0))
		path_index.append(0)
		paths.append([])
		good.append(CARRY_CYCLE[rng.randi_range(0, CARRY_CYCLE.size() - 1)])
		character.append(characters[i % characters.size()])
		count += 1


func tick() -> void:
	var start := Time.get_ticks_usec()
	prev = pos.duplicate()
	for i: int in count:
		if moving[i] == 1:
			_advance(i)
		elif wait[i] > 0.0:
			wait[i] -= TICK
			if wait[i] <= 0.0:
				_queue.append(i)
	var budget := PATH_BUDGET
	while budget > 0 and not _queue.is_empty():
		_plan(_queue.pop_front())
		budget -= 1
	last_tick_usec = Time.get_ticks_usec() - start


## Call after walls/buildings changed: people standing on new obstacles step aside.
func on_nav_changed() -> void:
	for i: int in count:
		var tile := Vector2i(pos[i].floor())
		if not nav.is_walkable(tile):
			var free := _nearest_walkable(tile)
			pos[i] = IsoMath.tile_center(free)
			prev[i] = pos[i]
			moving[i] = 0
			wait[i] = 0.2


func _advance(i: int) -> void:
	var path: Array = paths[i]
	var remaining := SPEED * TICK
	var p := pos[i]
	while remaining > 0.0 and path_index[i] < path.size():
		var next_tile: Vector2i = path[path_index[i]]
		if not nav.is_walkable(next_tile):
			moving[i] = 0
			wait[i] = 0.1   # blocked by a new wall: re-plan
			pos[i] = p
			return
		var target := IsoMath.tile_center(next_tile)
		var d := target - p
		var dist := d.length()
		if dist > 0.0001:
			facing[i] = IsoMath.screen_dir(d)
		if dist <= remaining:
			p = target
			remaining -= dist
			path_index[i] += 1
		else:
			p += d / dist * remaining
			remaining = 0.0
	pos[i] = p
	if path_index[i] >= path.size():
		moving[i] = 0
		wait[i] = rng.randf_range(0.5, 2.0)
		good[i] = CARRY_CYCLE[(CARRY_CYCLE.find(good[i]) + 1) % CARRY_CYCLE.size()]


func _plan(i: int) -> void:
	var from := Vector2i(pos[i].floor())
	var path := nav.find_path(from, _random_walkable())
	if path.size() < 2:
		wait[i] = 0.5
		return
	paths[i] = path
	path_index[i] = 1
	moving[i] = 1


func _random_walkable() -> Vector2i:
	for attempt: int in 50:
		var tile := Vector2i(rng.randi_range(area.position.x, area.end.x - 1),
				rng.randi_range(area.position.y, area.end.y - 1))
		if nav.is_walkable(tile):
			return tile
	return area.position


func _nearest_walkable(tile: Vector2i) -> Vector2i:
	for radius: int in range(1, 6):
		for dy: int in range(-radius, radius + 1):
			for dx: int in range(-radius, radius + 1):
				if nav.is_walkable(tile + Vector2i(dx, dy)):
					return tile + Vector2i(dx, dy)
	return _random_walkable()
