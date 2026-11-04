class_name BuildingSlicer
extends RefCounted
## Cuts a building image into vertical strips half a tile wide, each with its own sort
## point on the front edge of the footprint (ARCHITECTURE §6.2). This lets people stand
## beside a large building and still be drawn correctly in front of or behind it.
##
## Coordinates: B is the front (bottom) vertex of the footprint diamond. [param pivot] is
## B in image pixels. The footprint's front edge runs from L(-32w, -16w) through B(0, 0)
## to R(32h, -16h) relative to B.

const STRIP_WIDTH := 32


class Strip:
	extends RefCounted
	## Part of the image drawn by this strip.
	var region: Rect2i
	## Sort point relative to B, in screen pixels.
	var sort_offset: Vector2

	func _init(image_region: Rect2i, offset: Vector2) -> void:
		region = image_region
		sort_offset = offset


static func slices(footprint: Vector2i, pivot: Vector2i, image_size: Vector2i) -> Array[Strip]:
	var result: Array[Strip] = []
	var left := -STRIP_WIDTH * footprint.x
	var right := STRIP_WIDTH * footprint.y
	var count := footprint.x + footprint.y
	for i: int in count:
		var x0 := left + i * STRIP_WIDTH
		var x1 := x0 + STRIP_WIDTH
		var center := (x0 + x1) * 0.5
		# Overhanging art (eaves) beyond the footprint joins the outermost strips.
		var image_x0 := 0 if i == 0 else pivot.x + x0
		var image_x1 := image_size.x if i == count - 1 else pivot.x + x1
		var region := Rect2i(image_x0, 0, image_x1 - image_x0, image_size.y)
		result.append(Strip.new(region, Vector2(center, front_edge_y(center))))
	return result


## Screen y (relative to B) of the footprint's front edge at screen x (relative to B).
static func front_edge_y(x: float) -> float:
	return -absf(x) * 0.5
