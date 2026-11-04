extends RefCounted
## WALLS PROTOTYPE: places art generated in PixelLab (owner's library + the A1 trial) in
## the walls sandbox, to judge how it fits the isometric scale. Throwaway code.

const DIR := "res://src/prototype/walls/pixellab/"
## Gatehouse: 3x3 footprint, front (bottom) vertex of its ground plate in image pixels.
const GATEHOUSE_FOOTPRINT := Vector2i(3, 3)
const GATEHOUSE_PIVOT := Vector2i(96, 190)
## Wall block from create_isometric_tile: 64x64, tile center (ground) in image pixels.
const BLOCK_CENTER := Vector2(32, 47)


## Sprite whose node position is the sort point and whose [param foot] (image pixels)
## lands on screen point [param at].
static func sprite(texture: Texture2D, foot: Vector2, at: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = texture
	s.centered = false
	s.position = at
	s.offset = -foot
	return s


## Middle of the lowest opaque row: where a tree trunk or a stone touches the ground.
static func foot_of(texture: Texture2D) -> Vector2:
	var img := texture.get_image()
	for y: int in range(img.get_height() - 1, -1, -1):
		var x0 := -1
		var x1 := -1
		for x: int in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				if x0 < 0:
					x0 = x
				x1 = x
		if x0 >= 0:
			return Vector2((x0 + x1 + 1) * 0.5, y + 1)
	return Vector2(img.get_width() * 0.5, img.get_height())


static func textures(folder: String) -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	for file: String in ResourceLoader.list_directory(DIR + folder):
		if file.ends_with(".png"):
			result.append(load(DIR + folder + "/" + file) as Texture2D)
	return result


## Gatehouse cut into half-tile strips like a building (ARCHITECTURE §6.2).
static func gatehouse(origin: Vector2i) -> Node2D:
	var root := Node2D.new()
	root.y_sort_enabled = true
	root.position = IsoMath.grid_to_screen(Vector2(origin + GATEHOUSE_FOOTPRINT))
	var tex := load(DIR + "gate/gatehouse.png") as Texture2D
	for strip: BuildingSlicer.Strip in BuildingSlicer.slices(GATEHOUSE_FOOTPRINT, GATEHOUSE_PIVOT,
			Vector2i(tex.get_size())):
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.region_enabled = true
		s.region_rect = Rect2(strip.region)
		s.position = strip.sort_offset
		s.offset = Vector2(strip.region.position - GATEHOUSE_PIVOT) - strip.sort_offset
		root.add_child(s)
	return root
