class_name BuildWallCommand
extends Command
## Orders a palisade, a stone wall or stairs on a line of tiles (M7 part 2, GDD §5.3): porters
## bring 2 wood, 3 or 4 stones a tile, a builder lays them one by one (ProvinceSim.wall_plan,
## order_walls). Tiles that cannot take a wall are skipped; the command is rejected only when
## none can.

## The research tool id of the stone wall (ResearchDef.tools, E4 part 3).
const STONE_TOOL := &"stone_wall"

var tiles: Array[Vector2i]
## Walls.PALISADE, Walls.STONE or Walls.STAIRS.
var wall: int


func _init(wall_tiles: Array[Vector2i], kind: int = Walls.STONE) -> void:
	tiles = wall_tiles
	wall = kind


func validate(sim: Simulation) -> StringName:
	if wall != Walls.PALISADE and wall != Walls.STONE and wall != Walls.STAIRS:
		return &"bad_wall"
	if wall == Walls.STONE and not sim.province.research.allows_tool(sim.data, STONE_TOOL):
		return &"needs_research"   # E4 part 3: "Defensive masonry"
	var plan := sim.province.wall_plan(tiles, wall)
	if not (plan["tiles"] as Array).is_empty():
		return &""
	var errors: Dictionary = plan["errors"]
	return errors.values()[0] if not errors.is_empty() else &"no_tiles"


func apply(sim: Simulation) -> void:
	var plan := sim.province.wall_plan(tiles, wall)
	var accepted: Array[Vector2i] = []
	accepted.assign(plan["tiles"])
	sim.province.order_walls(accepted, wall)


## The tiles of a wall dragged from [param from] to [param to]: a straight line snapped to one
## of 8 directions (GDD §5.3). Unlike a quay, a diagonal stone wall leaves the tiles beside its
## steps free: the wedges fill them (ARCHITECTURE §6.3).
static func line(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var d := to - from
	var ax := absi(d.x)
	var ay := absi(d.y)
	var dir := Vector2i(signi(d.x), signi(d.y))
	var n := 0
	if ax >= 2 * ay:
		dir.y = 0
		n = ax
	elif ay >= 2 * ax:
		dir.x = 0
		n = ay
	else:
		n = roundi((ax + ay) / 2.0)
	var result: Array[Vector2i] = []
	for i: int in n + 1:
		result.append(from + dir * i)
	return result


func get_name() -> StringName:
	return &"build_wall"
