class_name SimCodec
extends RefCounted
## Helpers turning simulation values into JSON-safe values and back (ARCHITECTURE §8).
##
## JSON knows only doubles, strings, arrays and objects: ints come back as floats,
## StringNames as Strings, so every from_dict reads through these helpers.


static func vec2i(v: Vector2i) -> Array:
	return [v.x, v.y]


static func to_vec2i(a: Variant) -> Vector2i:
	var arr: Array = a
	return Vector2i(int(arr[0]), int(arr[1]))


static func vec2(v: Vector2) -> Array:
	return [v.x, v.y]


static func to_vec2(a: Variant) -> Vector2:
	var arr: Array = a
	return Vector2(float(arr[0]), float(arr[1]))


static func tiles(path: Array[Vector2i]) -> Array:
	var flat: Array = []
	for t: Vector2i in path:
		flat.append(t.x)
		flat.append(t.y)
	return flat


static func to_tiles(a: Variant) -> Array[Vector2i]:
	var flat: Array = a
	var result: Array[Vector2i] = []
	for i: int in range(0, flat.size() - 1, 2):
		result.append(Vector2i(int(flat[i]), int(flat[i + 1])))
	return result


static func int_array(a: Variant) -> Array[int]:
	var result: Array[int] = []
	for v: Variant in a:
		result.append(int(v))
	return result


## Canonical JSON text of a state dictionary; equal states give equal text.
static func canonical(d: Dictionary) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(d, "", true, true)), "", true, true)
