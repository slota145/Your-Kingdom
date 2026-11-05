class_name HouseRowResolver
extends RefCounted
## Houses of the same level standing side by side, flush and aligned, facing the same way,
## join visually into a row (GDD §3.3, ARCHITECTURE §6.6). Pure function, view only: the
## simulation does not know about rows.
##
## A house's row runs along its front: houses turned to 0 or 2 (door towards +x or -x)
## form rows along grid y, houses turned to 1 or 3 rows along grid x. The pieces are drawn
## for a row along y and mirrored for rows along x (x and y swapped), so "a" is always the
## end with the smaller coordinate along the row.
##
## Where two rows meet at a right angle, the last house of one row stands right in front
## of a house of the other row, which faces across it: that house becomes a corner (its
## roof turns round the corner) and the house behind it joins it without a gable.
## A house at the end of a row with a road in front and a road beside its free end is a
## corner too (owner's decision 2026-11-05): it shows a front to the side street.


## [param houses]: Array of {"id": int, "origin": Vector2i, "orientation": int,
## "footprint": Vector2i, "level": int}. Returns id -> piece: single, end_a, middle, end_b,
## corner_a (joined at the "a" end and at the back), corner_b.
## [param has_road] (tile -> bool, optional) tells where roads are.
static func resolve(houses: Array[Dictionary], has_road: Callable = Callable()) -> Dictionary[int, String]:
	var at: Dictionary[Vector2i, Dictionary] = {}
	for h: Dictionary in houses:
		at[h["origin"]] = h
	# Corners first: the house behind a corner joins it like a row neighbour.
	var corners: Dictionary[int, String] = {}
	var joined_by_corner: Dictionary[int, Array] = {}
	for h: Dictionary in houses:
		var ends := _row_ends(h, at)
		if ends[0] == ends[1]:
			continue
		var behind: Dictionary = at.get(h["origin"] + _back_step(h), {})
		if _same_kind(h, behind) and int(behind["orientation"]) % 2 != int(h["orientation"]) % 2:
			corners[int(h["id"])] = "corner_a" if ends[0] else "corner_b"
			joined_by_corner.get_or_add(int(behind["id"]), []).append(h["origin"])
		elif has_road.is_valid() and _road_corner(h, ends[0], has_road):
			corners[int(h["id"])] = "corner_a" if ends[0] else "corner_b"
	var result: Dictionary[int, String] = {}
	for h: Dictionary in houses:
		var id := int(h["id"])
		if corners.has(id):
			result[id] = corners[id]
			continue
		var ends := _row_ends(h, at)
		var along := _along_step(h)
		for corner: Vector2i in joined_by_corner.get(id, []):
			if corner == h["origin"] - along:
				ends[0] = true
			elif corner == h["origin"] + along:
				ends[1] = true
		if ends[0] and ends[1]:
			result[id] = "middle"
		elif ends[0]:
			result[id] = "end_b"
		elif ends[1]:
			result[id] = "end_a"
		else:
			result[id] = "single"
	return result


## [joined at the "a" end (smaller coordinate), joined at the "b" end] by houses of the
## same row.
static func _row_ends(h: Dictionary, at: Dictionary[Vector2i, Dictionary]) -> Array[bool]:
	var along := _along_step(h)
	return [_joins(h, at.get(h["origin"] - along, {})), _joins(h, at.get(h["origin"] + along, {}))]


## Roads along the front of [param h] and along its free end ([param joined_a]: the free
## end is "b").
static func _road_corner(h: Dictionary, joined_a: bool, has_road: Callable) -> bool:
	var fp: Vector2i = h["footprint"]
	var o := int(h["orientation"])
	var origin: Vector2i = h["origin"]
	var front: Array[Vector2i] = []
	var side: Array[Vector2i] = []
	var along := Vector2i(0, 1) if o % 2 == 0 else Vector2i(1, 0)
	var across := Vector2i(1, 0) if o % 2 == 0 else Vector2i(0, 1)
	var depth := fp.x if o % 2 == 0 else fp.y
	var width := fp.y if o % 2 == 0 else fp.x
	var front_at := depth if o < 2 else -1
	var side_at := width if joined_a else -1
	for i: int in width:
		front.append(origin + across * front_at + along * i)
	for i: int in depth:
		side.append(origin + along * side_at + across * i)
	return front.any(has_road) and side.any(has_road)


## One house step along the row.
static func _along_step(h: Dictionary) -> Vector2i:
	var fp: Vector2i = h["footprint"]
	return Vector2i(0, fp.y) if int(h["orientation"]) % 2 == 0 else Vector2i(fp.x, 0)


## One house step from the front to the back of the house.
static func _back_step(h: Dictionary) -> Vector2i:
	var fp: Vector2i = h["footprint"]
	match int(h["orientation"]):
		0:
			return Vector2i(-fp.x, 0)
		1:
			return Vector2i(0, -fp.y)
		2:
			return Vector2i(fp.x, 0)
	return Vector2i(0, fp.y)


static func _same_kind(a: Dictionary, b: Dictionary) -> bool:
	return not b.is_empty() and b["level"] == a["level"] and b["footprint"] == a["footprint"]


static func _joins(a: Dictionary, b: Dictionary) -> bool:
	return _same_kind(a, b) and b["orientation"] == a["orientation"]
