class_name Pens
extends RefCounted
## Pens of animal herds (Z1): which pen tiles make one pen and where its gate is (the view
## draws the fence from them), and pen tiles placed for neutral towns, rulers and test players.
##
## Pen tiles are field tiles of a building with BuildingDef.max_pens (FieldStore); tiles of one
## building that touch by a side form one pen with a fence round it and a gate.

const SIDES: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]


## Places up to [param wanted] pen tiles for [param building] next to it and next to each other
## (one pen), never in front of a door; the tiles in [param first] are tried first (an old
## pigsty's freed ground). Returns how many it placed.
static func auto_place(province: ProvinceSim, building: BuildingState, wanted: int,
		first: Array[Vector2i] = []) -> int:
	if not building.def.has_tiles() or wanted <= 0:
		return 0
	var doors := _door_fronts(province)
	var own: Array[Vector2i] = province.fields.tiles_of(building.id)
	var queue: Array[Vector2i] = first.duplicate()
	var seen: Dictionary[Vector2i, bool] = {}
	# Ground round the footprint, beside the door first (not behind the building, where the
	# building would hide the animals; the door's own front tile stays free).
	var rect := Rect2i(building.origin, building.def.footprint)
	var around: Array[Vector2i] = []
	for tile: Vector2i in own:
		around.append(tile)
	for y: int in range(rect.position.y - 1, rect.end.y + 1):
		for x: int in range(rect.position.x - 1, rect.end.x + 1):
			var tile := Vector2i(x, y)
			if not rect.has_point(tile):
				around.append(tile)
	var door := building.door_front_tile()
	around.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _front_first(a, door) < _front_first(b, door))
	queue.append_array(around)
	var placed := 0
	var i := 0
	while i < queue.size() and placed < wanted:
		var tile := queue[i]
		i += 1
		if seen.has(tile):
			continue
		seen[tile] = true
		var mine := province.fields.has_field(tile) and province.fields.farm_of(tile) == building.id
		if not mine:
			if doors.has(tile) or province.field_error(building.id, tile) != &"":
				continue
			province.add_field(building.id, tile)
			placed += 1
		# Grow the pen from this tile, so the tiles stay together.
		for side: Vector2i in SIDES:
			if not seen.has(tile + side):
				queue.insert(i, tile + side)
	return placed


## Pen tiles [param building] should have for its herd: room for the animals it holds, at
## least [param least].
static func wanted_for(building: BuildingState, least: int) -> int:
	var herd := building.yard.total(building.def.herd_good) if building.yard != null else 0
	return clampi(maxi(ceili(herd / float(building.def.pen_animals)), least), 0, building.def.max_pens)


## Pens of [param building]: groups of its pen tiles that touch by a side (each a list of tiles).
static func groups(province: ProvinceSim, building_id: int) -> Array[Array]:
	var tiles := province.fields.tiles_of(building_id)
	var left: Dictionary[Vector2i, bool] = {}
	for tile: Vector2i in tiles:
		left[tile] = true
	var result: Array[Array] = []
	for start: Vector2i in tiles:
		if not left.has(start):
			continue
		var group: Array[Vector2i] = []
		var stack: Array[Vector2i] = [start]
		left.erase(start)
		while not stack.is_empty():
			var tile: Vector2i = stack.pop_back()
			group.append(tile)
			for side: Vector2i in SIDES:
				if left.has(tile + side):
					left.erase(tile + side)
					stack.append(tile + side)
		group.sort()
		result.append(group)
	return result


## The gate of a pen: the tile of [param group] nearest to the building's door and the side
## (one of SIDES) of that tile facing out, towards the door. Returns [tile, side].
static func gate(building: BuildingState, group: Array) -> Array:
	var door := building.door_front_tile()
	var best_tile: Vector2i = group[0]
	var best_side := Vector2i(1, 0)
	var best_d := 1 << 30
	var members: Dictionary[Vector2i, bool] = {}
	for tile: Vector2i in group:
		members[tile] = true
	for tile: Vector2i in group:
		for side: Vector2i in SIDES:
			var out: Vector2i = tile + side
			if members.has(out):
				continue
			var d := (out - door).length_squared() * 4 + (side.x + side.y + 2)
			if d < best_d:
				best_d = d
				best_tile = tile
				best_side = side
	return [best_tile, best_side]


## Sort key: tiles in front of the building (larger x + y, nearer the camera) and near the door
## come first.
static func _front_first(tile: Vector2i, door: Vector2i) -> int:
	return (tile - door).length_squared() * 4 - (tile.x + tile.y) * 2


static func _door_fronts(province: ProvinceSim) -> Dictionary[Vector2i, bool]:
	var doors: Dictionary[Vector2i, bool] = {}
	for other: BuildingState in province.buildings.all():
		doors[other.door_front_tile()] = true
		for tile: Vector2i in other.entrance_tiles():
			doors[tile] = true
	return doors
