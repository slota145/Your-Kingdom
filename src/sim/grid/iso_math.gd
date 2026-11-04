class_name IsoMath
extends RefCounted
## Pure isometric 2:1 math (ARCHITECTURE §6.1). Grid space is continuous: tile (x, y)
## covers [x, x+1) x [y, y+1); its top vertex projects to grid_to_screen(Vector2(x, y)).
##
## Grid +x points to screen right-down, grid +y to screen left-down.

const TILE_SIZE := Vector2i(64, 32)
const HALF_W := 32.0
const HALF_H := 16.0

## Screen directions used by character animations, clockwise from "towards the camera".
## The order matches sheet rows (ART_SPEC §4.1).
enum Dir { S, SE, E, NE, N, NW, W, SW }
const DIR_COUNT := 8

## Grid offset of one step that looks like each screen direction.
const DIR_GRID_STEP: Array[Vector2i] = [
	Vector2i(1, 1), Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]


static func grid_to_screen(grid: Vector2) -> Vector2:
	return Vector2((grid.x - grid.y) * HALF_W, (grid.x + grid.y) * HALF_H)


static func screen_to_grid(screen: Vector2) -> Vector2:
	return Vector2(screen.x / HALF_W + screen.y / HALF_H, screen.y / HALF_H - screen.x / HALF_W) * 0.5


static func tile_at_screen(screen: Vector2) -> Vector2i:
	var grid := screen_to_grid(screen)
	return Vector2i(floori(grid.x), floori(grid.y))


static func tile_center(tile: Vector2i) -> Vector2:
	return Vector2(tile) + Vector2(0.5, 0.5)


## Screen position of a tile's center.
static func tile_center_screen(tile: Vector2i) -> Vector2:
	return grid_to_screen(tile_center(tile))


## Quantizes a grid-space movement vector to one of 8 screen directions (Dir), or -1
## for a zero vector. The isometric squash is undone first so diagonals split evenly.
static func screen_dir(grid_delta: Vector2) -> int:
	var screen := grid_to_screen(grid_delta)
	var unsquashed := Vector2(screen.x, screen.y * 2.0)
	if unsquashed.length_squared() < 1e-10:
		return -1
	var angle := atan2(unsquashed.y, unsquashed.x)
	return posmod(roundi((PI / 2.0 - angle) / (PI / 4.0)), DIR_COUNT)
