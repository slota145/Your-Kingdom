class_name HouseRowResolver
extends RefCounted
## Houses of the same level standing side by side, flush and aligned along a grid axis,
## join visually into a row (GDD §3.3, ARCHITECTURE §6.6). Pure function, view only:
## the simulation does not know about rows.


## [param houses]: Array of {"id": int, "origin": Vector2i, "footprint": Vector2i, "level": int}.
## Returns id -> [variant, axis] with variant single/end_a/middle/end_b and axis "x"/"y".
## end_a is the end with the smaller coordinate. Rows along x win over rows along y.
static func resolve(houses: Array[Dictionary]) -> Dictionary[int, Array]:
	var at: Dictionary[Vector2i, Dictionary] = {}
	for h: Dictionary in houses:
		at[h["origin"]] = h
	var result: Dictionary[int, Array] = {}
	for h: Dictionary in houses:
		var fp: Vector2i = h["footprint"]
		var picked := ["single", "x"]
		for axis: String in ["x", "y"]:
			var step := Vector2i(fp.x, 0) if axis == "x" else Vector2i(0, fp.y)
			var prev := _joins(h, at.get(h["origin"] - step, {}))
			var next := _joins(h, at.get(h["origin"] + step, {}))
			if prev or next:
				var variant := "middle" if prev and next else ("end_b" if prev else "end_a")
				picked = [variant, axis]
				break
		result[int(h["id"])] = picked
	return result


static func _joins(a: Dictionary, b: Dictionary) -> bool:
	return not b.is_empty() and b["level"] == a["level"] and b["footprint"] == a["footprint"]
