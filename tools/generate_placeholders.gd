extends SceneTree
## Generates placeholder art into res://assets/_placeholder using the same layout as final art
## (ART_SPEC §2, §9.1). Run:
##   "$GODOT" --headless --path . -s res://tools/generate_placeholders.gd
##
## M0 output: grass and grid terrain tiles, and a capsule character with idle/walk sheets
## (rows = 8 screen directions S, SE, E, NE, N, NW, W, SW; columns = frames).

const OUT := "res://assets/_placeholder"
const TILE := Vector2i(64, 32)
const FRAME := Vector2i(64, 64)
const FOOT := Vector2i(32, 58)
const CHARACTER_HEIGHT := 42
const DIRECTIONS := 8

const OUTLINE := Color(0.13, 0.09, 0.07)
const BODY := Color(0.55, 0.38, 0.22)
const SKIN := Color(0.93, 0.76, 0.6)
const NOSE := Color(1.0, 0.2, 0.2)


func _init() -> void:
	_save(_diamond(Color(0.36, 0.55, 0.25), Color(0.30, 0.48, 0.21)), "terrain/grass/a.png")
	_save(_diamond(Color(0, 0, 0, 0), Color(1, 1, 1, 0.35)), "terrain/grid/a.png")
	_save(_character_sheet(4, 0.0), "characters/capsule/idle.png")
	_save(_character_sheet(8, 2.0), "characters/capsule/walk.png")
	print("Placeholders written to ", OUT)
	quit()


## Isometric 2:1 diamond filling the 64x32 tile, with a 1 px border.
func _diamond(fill: Color, border: Color) -> Image:
	var img := Image.create_empty(TILE.x, TILE.y, false, Image.FORMAT_RGBA8)
	for y: int in TILE.y:
		var half_width := _diamond_half_width(y)
		for x: int in range(TILE.x / 2 - half_width, TILE.x / 2 + half_width):
			var edge := x <= TILE.x / 2 - half_width or x >= TILE.x / 2 + half_width - 1
			img.set_pixel(x, y, border if edge or y == 0 or y == TILE.y - 1 else fill)
	return img


func _diamond_half_width(y: int) -> int:
	var row := y if y < TILE.y / 2 else TILE.y - 1 - y
	return (row + 1) * 2


## Capsule body + head; a red "nose" points in the screen direction; walking frames bob.
func _character_sheet(frames: int, bob: float) -> Image:
	var img := Image.create_empty(FRAME.x * frames, FRAME.y * DIRECTIONS, false, Image.FORMAT_RGBA8)
	for dir: int in DIRECTIONS:
		# Screen directions clockwise from S (towards camera). Screen y grows downwards.
		var angle := PI / 2.0 - dir * TAU / DIRECTIONS
		var facing := Vector2(cos(angle), sin(angle) * 0.5)
		for frame: int in frames:
			var origin := Vector2i(frame * FRAME.x, dir * FRAME.y)
			var lift := int(round(absf(sin(frame * TAU / frames)) * bob))
			_draw_capsule(img, origin + FOOT - Vector2i(0, lift), facing)
	return img


func _draw_capsule(img: Image, foot: Vector2i, facing: Vector2) -> void:
	var body_height := CHARACTER_HEIGHT - 10
	var body_top := foot.y - body_height
	_ellipse(img, Vector2(foot.x, body_top + body_height / 2.0), Vector2(8, body_height / 2.0), BODY)
	var head := Vector2(foot.x, foot.y - CHARACTER_HEIGHT + 5)
	_ellipse(img, head, Vector2(5, 5), SKIN)
	var nose := head + facing * 5.0
	img.fill_rect(Rect2i(int(nose.x) - 1, int(nose.y) - 1, 3, 3), NOSE)


func _ellipse(img: Image, center: Vector2, radius: Vector2, color: Color) -> void:
	for y: int in range(int(center.y - radius.y) - 1, int(center.y + radius.y) + 2):
		for x: int in range(int(center.x - radius.x) - 1, int(center.x + radius.x) + 2):
			var d := Vector2((x - center.x) / radius.x, (y - center.y) / radius.y).length()
			if d <= 1.0:
				img.set_pixel(x, y, color)
			elif d <= 1.0 + 1.5 / minf(radius.x, radius.y) and img.get_pixel(x, y).a == 0.0:
				img.set_pixel(x, y, OUTLINE)


func _save(img: Image, relative: String) -> void:
	var path := OUT.path_join(relative)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var err := img.save_png(path)
	if err != OK:
		push_error("Cannot save %s (%s)" % [path, error_string(err)])
