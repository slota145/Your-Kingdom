class_name WallConnectivity
extends RefCounted
## Which neighbours a wall tile connects to, and which pieces render it (ARCHITECTURE §6.3).
##
## Directions here are GRID directions (not screen): E = +x, S = +y. Grid E looks like
## screen south-east, grid NE (+x, -y) looks like screen east, and so on.

enum GridDir { N, NE, E, SE, S, SW, W, NW }
const COUNT := 8
const NAMES: PackedStringArray = ["n", "ne", "e", "se", "s", "sw", "w", "nw"]
const OFFSETS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1),
]


static func is_diagonal(dir: int) -> bool:
	return dir % 2 == 1


static func opposite(dir: int) -> int:
	return (dir + 4) % COUNT


static func bit(dir: int) -> int:
	return 1 << dir


## 8-bit connection mask of the wall at [param tile]. [param is_wall] is
## func(Vector2i) -> bool. A diagonal link is dropped when one of the two orthogonal
## neighbours it passes between is also a wall: the wall already turns through that tile,
## and keeping both would draw a filled triangle.
static func mask_at(tile: Vector2i, is_wall: Callable) -> int:
	var mask := 0
	for dir: int in COUNT:
		if not is_wall.call(tile + OFFSETS[dir]):
			continue
		if is_diagonal(dir):
			var left: int = (dir + COUNT - 1) % COUNT
			var right: int = (dir + 1) % COUNT
			if is_wall.call(tile + OFFSETS[left]) or is_wall.call(tile + OFFSETS[right]):
				continue
		mask |= bit(dir)
	return mask


## Directions with a half segment in [param mask], in GridDir order.
static func half_dirs(mask: int) -> PackedInt32Array:
	var dirs := PackedInt32Array()
	for dir: int in COUNT:
		if mask & bit(dir):
			dirs.append(dir)
	return dirs


## The post is hidden on straight runs: exactly two connections pointing opposite ways.
static func needs_post(mask: int) -> bool:
	var dirs := half_dirs(mask)
	return not (dirs.size() == 2 and dirs[1] == opposite(dirs[0]))


## Gate axis for a wall tile: &"x" when the wall runs along grid x (E-W), &"y" along grid y,
## or &"" when no straight orthogonal run passes through the tile.
static func gate_axis(mask: int) -> StringName:
	if mask & bit(GridDir.E) and mask & bit(GridDir.W):
		return &"x"
	if mask & bit(GridDir.N) and mask & bit(GridDir.S):
		return &"y"
	return &""
