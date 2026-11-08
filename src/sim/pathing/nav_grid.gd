class_name NavGrid
extends RefCounted
## Walkability and movement costs on the tile grid, wrapping AStarGrid2D (ARCHITECTURE §5.3).
##
## 8-directional movement; diagonal steps are only allowed when both orthogonal neighbours
## are free, so nobody slips through the joint of a diagonal wall.

const _STEPS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]

## Bumped on every change, so cached paths can detect they are stale.
var version: int = 0
## Bumped only when a tile turns solid or free (M4b-3): a planned path can only become
## impossible then, not when walking costs change.
var solid_version: int = 0
var size: Vector2i

## Solid tiles as a flat array (index y * size.x + x, 1 = solid) for fast floods in GDScript
## (ServiceCoverage, M4b-3).
var solid_map: PackedByteArray = PackedByteArray()

var _astar: AStarGrid2D = AStarGrid2D.new()
## Connected areas (components), cached for solid_version (M7 part 2).
var _labels: PackedInt32Array = PackedInt32Array()
var _labels_version: int = -1


func _init(grid_size: Vector2i) -> void:
	size = grid_size
	_astar.region = Rect2i(Vector2i.ZERO, grid_size)
	_astar.cell_size = Vector2.ONE
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.update()
	solid_map.resize(size.x * size.y)


func is_inside(tile: Vector2i) -> bool:
	return _astar.is_in_boundsv(tile)


func is_walkable(tile: Vector2i) -> bool:
	return is_inside(tile) and not _astar.is_point_solid(tile)


func set_solid(tile: Vector2i, solid: bool) -> void:
	if is_inside(tile) and _astar.is_point_solid(tile) != solid:
		_astar.set_point_solid(tile, solid)
		solid_map[tile.y * size.x + tile.x] = 1 if solid else 0
		version += 1
		solid_version += 1


func set_solid_rect(rect: Rect2i, solid: bool) -> void:
	var region := rect.intersection(_astar.region)
	_astar.fill_solid_region(region, solid)
	for y: int in range(region.position.y, region.end.y):
		for x: int in range(region.position.x, region.end.x):
			solid_map[y * size.x + x] = 1 if solid else 0
	version += 1
	solid_version += 1


## Movement cost multiplier of a tile (road < 1, forest > 1).
func set_cost(tile: Vector2i, cost: float) -> void:
	if is_inside(tile):
		_astar.set_point_weight_scale(tile, cost)
		version += 1


func get_cost(tile: Vector2i) -> float:
	return _astar.get_point_weight_scale(tile) if is_inside(tile) else 1.0


## Tile path including both ends, or empty when unreachable.
func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if not is_walkable(from) or not is_walkable(to):
		return []
	return _astar.get_id_path(from, to)


## Which of [param targets] can be walked to from [param start], treating [param blocked]
## tiles as solid too (placement checks before the building exists). Flood fill with
## 4 neighbours: diagonal steps need both orthogonal neighbours free, so they never connect
## areas that 4 neighbours do not. Stops early once every target is found.
func reachable(start: Vector2i, targets: Dictionary[Vector2i, bool],
		blocked: Dictionary[Vector2i, bool] = {}) -> Dictionary[Vector2i, bool]:
	var found: Dictionary[Vector2i, bool] = {}
	if not is_walkable(start) or blocked.has(start):
		return found
	var visited := PackedByteArray()
	visited.resize(size.x * size.y)
	visited[start.y * size.x + start.x] = 1
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var tile := queue[head]
		head += 1
		if targets.has(tile):
			found[tile] = true
			if found.size() == targets.size():
				break
		for step: Vector2i in _STEPS:
			var next := tile + step
			if not is_walkable(next) or blocked.has(next):
				continue
			var index := next.y * size.x + next.x
			if visited[index] == 1:
				continue
			visited[index] = 1
			queue.append(next)
	return found


## Label of the connected walkable area of [param tile] (4 neighbours, like [method
## reachable]); -1 when solid. Labels are worked out again only after a tile turned solid or
## free (M7 part 2: the troops' routes over walls and ladders).
func area_of(tile: Vector2i) -> int:
	if not is_inside(tile):
		return -1
	if _labels_version != solid_version:
		_label_areas()
	return _labels[tile.y * size.x + tile.x]


func _label_areas() -> void:
	_labels_version = solid_version
	_labels = PackedInt32Array()
	_labels.resize(size.x * size.y)
	_labels.fill(-1)
	var next := 0
	var queue := PackedInt32Array()
	for start: int in solid_map.size():
		if solid_map[start] == 1 or _labels[start] != -1:
			continue
		_labels[start] = next
		queue.resize(0)
		queue.append(start)
		var head := 0
		while head < queue.size():
			var i := queue[head]
			head += 1
			var x := i % size.x
			for j: int in [i - 1 if x > 0 else -1, i + 1 if x < size.x - 1 else -1, i - size.x, i + size.x]:
				if j < 0 or j >= solid_map.size() or solid_map[j] == 1 or _labels[j] != -1:
					continue
				_labels[j] = next
				queue.append(j)
		next += 1
