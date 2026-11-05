class_name NavGrid
extends RefCounted
## Walkability and movement costs on the tile grid, wrapping AStarGrid2D (ARCHITECTURE §5.3).
##
## 8-directional movement; diagonal steps are only allowed when both orthogonal neighbours
## are free, so nobody slips through the joint of a diagonal wall.

## Bumped on every change, so cached paths can detect they are stale.
var version: int = 0
var size: Vector2i

var _astar: AStarGrid2D = AStarGrid2D.new()


func _init(grid_size: Vector2i) -> void:
	size = grid_size
	_astar.region = Rect2i(Vector2i.ZERO, grid_size)
	_astar.cell_size = Vector2.ONE
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.update()


func is_inside(tile: Vector2i) -> bool:
	return _astar.is_in_boundsv(tile)


func is_walkable(tile: Vector2i) -> bool:
	return is_inside(tile) and not _astar.is_point_solid(tile)


func set_solid(tile: Vector2i, solid: bool) -> void:
	if is_inside(tile) and _astar.is_point_solid(tile) != solid:
		_astar.set_point_solid(tile, solid)
		version += 1


func set_solid_rect(rect: Rect2i, solid: bool) -> void:
	_astar.fill_solid_region(rect.intersection(_astar.region), solid)
	version += 1


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
