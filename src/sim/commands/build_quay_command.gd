class_name BuildQuayCommand
extends Command
## Orders a timber pier or a stone quay on sea tiles (N1, GDD §5.4): 2 planks or 3 stones a
## tile, laid by a builder from the shore outwards (ProvinceSim.quay_plan). Tiles that cannot
## take a quay are skipped; the command is rejected only when none can.

var tiles: Array[Vector2i]
## TileGrid.PIER or TileGrid.STONE_QUAY.
var quay: int


func _init(quay_tiles: Array[Vector2i], kind: int = TileGrid.PIER) -> void:
	tiles = quay_tiles
	quay = kind


func validate(sim: Simulation) -> StringName:
	if quay != TileGrid.PIER and quay != TileGrid.STONE_QUAY:
		return &"bad_quay"
	var plan := sim.province.quay_plan(tiles)
	if not (plan["tiles"] as Array).is_empty():
		return &""
	var errors: Dictionary = plan["errors"]
	return errors.values()[0] if not errors.is_empty() else &"no_tiles"


func apply(sim: Simulation) -> void:
	var plan := sim.province.quay_plan(tiles)
	var accepted: Array[Vector2i] = []
	accepted.assign(plan["tiles"])
	sim.province.order_quay(accepted, quay)


## The tiles of a quay dragged from [param from] to [param to], like a wall (GDD §5.3, owner's
## request 2026-11-07): snapped to one of 8 directions. A diagonal line takes both tiles beside
## each step too (the wedges, as in the stone wall's "straight" diagonals, ARCHITECTURE §6.3),
## so people walk along it and its sides are drawn straight (QuayLayer).
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
	var tiles: Array[Vector2i] = []
	for i: int in n + 1:
		var t := from + dir * i
		if not tiles.has(t):
			tiles.append(t)
		if dir.x != 0 and dir.y != 0 and i < n:
			for wedge: Vector2i in [t + Vector2i(dir.x, 0), t + Vector2i(0, dir.y)]:
				if not tiles.has(wedge):
					tiles.append(wedge)
	return tiles


func get_name() -> StringName:
	return &"build_quay"
