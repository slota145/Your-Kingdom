class_name DepthOracle
extends RefCounted
## Ground truth for isometric draw order, used to verify sort keys.
##
## With a fixed 2:1 camera, a screen column x = const is the ground line x - y = const.
## Along it, larger x + y is closer to the camera. A person standing at ground point p is
## in front of an extruded footprint in a screen column when every footprint point in
## that column has smaller x + y than p.

const AGENT_HALF_WIDTH := 9.0
const AGENT_HEIGHT := 42.0

enum { BEHIND = -1, NONE = 0, IN_FRONT = 1 }


## Relation of a person at grid point [param p] to the convex ground polygon [param poly]
## (absolute grid coordinates) within screen columns [param x0, param x1] (screen pixels).
## NONE when the polygon does not reach those columns or p is inside its depth range.
static func relation(p: Vector2, poly: PackedVector2Array, x0: float, x1: float) -> int:
	var uv := PackedVector2Array()
	for g: Vector2 in poly:
		uv.append(Vector2((g.x - g.y) * IsoMath.HALF_W, g.x + g.y))
	uv = _clip(uv, x0, 1.0)
	uv = _clip(uv, x1, -1.0)
	if uv.is_empty():
		return NONE
	var v_min := INF
	var v_max := -INF
	for q: Vector2 in uv:
		v_min = minf(v_min, q.y)
		v_max = maxf(v_max, q.y)
	var depth := p.x + p.y
	if v_max <= depth:
		return IN_FRONT
	if v_min >= depth:
		return BEHIND
	return NONE


## Sutherland-Hodgman clip of polygon (u, v) to u >= limit (side 1) or u <= limit (side -1).
static func _clip(poly: PackedVector2Array, limit: float, side: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := poly.size()
	for i: int in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		var a_in := (a.x - limit) * side >= 0.0
		var b_in := (b.x - limit) * side >= 0.0
		if a_in:
			out.append(a)
		if a_in != b_in:
			var t := (limit - a.x) / (b.x - a.x)
			out.append(a.lerp(b, t))
	return out


## Points along every walkable 8-neighbour step between tile centers inside [param area],
## i.e. everywhere a walking person's feet can be. Diagonal steps follow NavGrid's rule.
static func walk_samples(area: Rect2i, is_blocked: Callable, step: float = 0.125) -> PackedVector2Array:
	var samples := PackedVector2Array()
	for x: int in range(area.position.x, area.end.x):
		for y: int in range(area.position.y, area.end.y):
			var tile := Vector2i(x, y)
			if is_blocked.call(tile):
				continue
			for offset: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]:
				var other := tile + offset
				if not area.has_point(other) or is_blocked.call(other):
					continue
				if offset.x != 0 and offset.y != 0:
					if is_blocked.call(tile + Vector2i(offset.x, 0)) \
							or is_blocked.call(tile + Vector2i(0, offset.y)):
						continue
				var a := IsoMath.tile_center(tile)
				var b := IsoMath.tile_center(other)
				var t := 0.0
				while t < 1.0:
					samples.append(a.lerp(b, t))
					t += step
	return samples
