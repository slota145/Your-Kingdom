extends RefCounted
## WALLS PROTOTYPE: cuts PixelLab repaints of our reference images (export_reference.gd)
## into pieces the wall view can use (docs/ART_SPEC.md §10.1):
## - walls: texture samples of the lit face (+y), the dark face (+x) and the crown top,
##   unskewed into rectangles so any wall shape can be drawn with them,
## - gatehouse: the gatehouse pixels of the repaint, masked by the projected pieces and
##   used as building art (cut into strips like any building).
## Image pixel <-> world: the reference camera centres the 256x256 image 40 px above the
## layout's focus point, exactly as export_reference.gd renders it.

const Model := preload("res://src/prototype/walls/block_wall_model.gd")
const Reference := preload("res://src/prototype/walls/export_reference.gd")
const PX_PER_TILE := 32.0
const TOP_TEXELS := 64
## Extra pixels sampled past the end of a sample and cross-faded into its start, so the
## texture repeats without a visible seam.
const BLEND := 8

## A texture whose u (and v for tops) repeat every [member period] grid units, starting at
## grid coordinate [member origin].
class Sample:
	extends RefCounted
	var texture: Texture2D
	var origin: Vector2
	var period: Vector2
	var height: float

## Lit face (normal +y), dark face (normal +x), crown top.
var lit: Sample
var dark: Sample
var top: Sample
var merlon_color: Color
var outline: Color
## Gatehouse building art for a passage along grid y, and its pivot (front vertex).
var gatehouse: Texture2D
var gatehouse_flipped: Texture2D
var gatehouse_pivot: Vector2i


static func load_from(wall_path: String, gate_path: String) -> RefCounted:
	var skin: RefCounted = (load("res://src/prototype/walls/repaint_skin.gd") as GDScript).new()
	skin._cut_walls(load(wall_path).get_image())
	skin._cut_gatehouse(load(gate_path).get_image())
	return skin


func _cut_walls(img: Image) -> void:
	var model := Model.new()
	var focus := Reference.layout(model, "wall", Vector2i.ZERO)
	# Faces of the reference layout that nothing covers (see Reference.layout):
	# Kept away from corners, where the reference has outlines and shadows.
	lit = _face(img, focus, Vector2(1.6, 2), Vector2(3.6, 2), Model.HEIGHT)      # double wall, front
	dark = _face(img, focus, Vector2(1, 2.1), Vector2(1, 2.85), Model.HEIGHT)    # side wall, right
	top = _top(img, focus, Vector2(0.7, 0.3), Vector2(2, 0.75), Model.HEIGHT)    # double wall crown
	merlon_color = _average(top.texture.get_image()).lerp(_average(lit.texture.get_image()), 0.5)
	outline = _average(dark.texture.get_image()).darkened(0.55)


## Unskews the wall face from grid point a to b (one axis) into a rectangle: one column per
## screen pixel along the face, one row per pixel of height (row 0 = top of the wall).
func _face(img: Image, focus: Vector2, a: Vector2, b: Vector2, h: float) -> Sample:
	var width := roundi(a.distance_to(b) * PX_PER_TILE)
	var dir := (b - a).normalized()
	var raw := Image.create_empty(width + BLEND, int(h), false, Image.FORMAT_RGBA8)
	for c: int in width + BLEND:
		var p := a + dir * (c + 0.5) / PX_PER_TILE
		for r: int in int(h):
			raw.set_pixel(c, r, _at(img, focus, IsoMath.grid_to_screen(p) - Vector2(0, h - r - 0.5)))
	var s := Sample.new()
	s.texture = ImageTexture.create_from_image(_seamless(raw, Vector2i(width, int(h)), Vector2i(BLEND, 0)))
	s.origin = a
	s.period = Vector2(a.distance_to(b), 1)
	s.height = h
	return s


## Crown top resampled into grid space: TOP_TEXELS per tile in both grid axes.
func _top(img: Image, focus: Vector2, origin: Vector2, size: Vector2, h: float) -> Sample:
	var w := int(size.x * TOP_TEXELS)
	var hh := int(size.y * TOP_TEXELS)
	var raw := Image.create_empty(w + BLEND, hh + BLEND, false, Image.FORMAT_RGBA8)
	for i: int in w + BLEND:
		for j: int in hh + BLEND:
			var p := origin + Vector2(i + 0.5, j + 0.5) / TOP_TEXELS
			raw.set_pixel(i, j, _at(img, focus, IsoMath.grid_to_screen(p) - Vector2(0, h)))
	var s := Sample.new()
	s.texture = ImageTexture.create_from_image(_seamless(raw, Vector2i(w, hh), Vector2i(BLEND, BLEND)))
	s.origin = origin
	s.period = size
	return s


## Keeps only the pixels inside the projected gatehouse pieces (with their merlons and the
## arch hanging below the deck), so the wall stubs of the reference are dropped.
func _cut_gatehouse(img: Image) -> void:
	var model := Model.new()
	var focus := Reference.layout(model, "gate", Vector2i.ZERO)
	var mask := Image.create_empty(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	for piece: Model.Piece in model.build():
		# The body only: the repaint's own small merlons are dropped, the view stands the
		# current parapet and merlons on top instead.
		if not model.gatehouse_tiles.has(piece.tile) or not String(piece.kind).begins_with("gh_"):
			continue
		var z0 := piece.z0 - 16.0 if piece.kind == &"gh_deck" else piece.z0
		var pts := PackedVector2Array()
		for g: Vector2 in piece.poly:
			var s := IsoMath.grid_to_screen(g)
			pts.append(_image_point(focus, s - Vector2(0, z0)))
			pts.append(_image_point(focus, s - Vector2(0, piece.z1)))
		var hull := Geometry2D.convex_hull(pts)
		var box := Rect2i(Vector2i(hull[0]), Vector2i.ZERO)
		for p: Vector2 in hull:
			box = box.expand(Vector2i(p))
		box = box.grow(2).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		for y: int in range(box.position.y, box.end.y):
			for x: int in range(box.position.x, box.end.x):
				if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), hull):
					mask.set_pixel(x, y, img.get_pixel(x, y))
	gatehouse = ImageTexture.create_from_image(mask)
	var flipped := mask.duplicate() as Image
	flipped.flip_x()
	gatehouse_flipped = ImageTexture.create_from_image(flipped)
	gatehouse_pivot = Vector2i(_image_point(focus, IsoMath.grid_to_screen(Vector2(3, 3))).round())


## [param size] image from [param raw], whose extra [param blend] columns/rows past the end
## are cross-faded into the first ones, so the result tiles seamlessly.
static func _seamless(raw: Image, size: Vector2i, blend: Vector2i) -> Image:
	var out := Image.create_empty(size.x, size.y + blend.y, false, Image.FORMAT_RGBA8)
	for y: int in size.y + blend.y:
		for x: int in size.x:
			var c := raw.get_pixel(x, y)
			if x < blend.x:
				c = raw.get_pixel(x + size.x, y).lerp(c, (x + 0.5) / blend.x)
			out.set_pixel(x, y, c)
	var result := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y: int in size.y:
		for x: int in size.x:
			var c := out.get_pixel(x, y)
			if y < blend.y:
				c = out.get_pixel(x, y + size.y).lerp(c, (y + 0.5) / blend.y)
			result.set_pixel(x, y, c)
	return result


static func _image_point(focus: Vector2, screen: Vector2) -> Vector2:
	return screen - (IsoMath.grid_to_screen(focus) - Vector2(0, 40)) + Vector2(128, 128)


static func _at(img: Image, focus: Vector2, screen: Vector2) -> Color:
	var p := Vector2i(_image_point(focus, screen).floor())
	p = p.clamp(Vector2i.ZERO, img.get_size() - Vector2i.ONE)
	return img.get_pixelv(p)


static func _average(img: Image) -> Color:
	var sum := Color(0, 0, 0, 0)
	var count := 0
	for x: int in img.get_width():
		for y: int in img.get_height():
			var c := img.get_pixel(x, y)
			if c.a > 0.5:
				sum += c
				count += 1
	return Color(sum.r / count, sum.g / count, sum.b / count) if count > 0 else Color.GRAY
