extends SceneTree
## Draws the UI art of the "parchment and wood" style (ROADMAP UI-1, owner's decision
## 2026-11-07) into assets/ui/: panels (parchment in a dark wooden frame with iron corner
## brackets), wooden buttons in four states, the wooden board of the bars, tooltips, separators
## and small icons. Everything is drawn at art resolution and scaled 2x (one art pixel = 2x2
## screen pixels of the 1280x720 base viewport, like the main menu picture). The theme that uses
## them is UiKit.theme(); the nine-patch margins are UiKit.PANEL_MARGIN and friends.
## Run: "$GODOT" --headless --path . -s res://tools/generate_ui.gd

const OUT := "res://assets/ui"
const SCALE := 2

const PARCHMENT := Color(0.93, 0.86, 0.69)
const PARCHMENT_DARK := Color(0.84, 0.75, 0.56)
const PARCHMENT_LIGHT := Color(0.97, 0.92, 0.79)
const WOOD := Color(0.42, 0.27, 0.15)
const WOOD_DARK := Color(0.26, 0.16, 0.09)
const WOOD_LIGHT := Color(0.56, 0.38, 0.22)
const IRON := Color(0.36, 0.36, 0.38)
const IRON_LIGHT := Color(0.6, 0.6, 0.62)
const OUTLINE := Color(0.14, 0.08, 0.05)
const GOLD := Color(0.93, 0.74, 0.25)
const GOLD_DARK := Color(0.66, 0.45, 0.12)


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_save(_panel(24, false), "panel.png")
	_save(_panel(24, true), "panel_inset.png")
	_save(_tooltip(), "tooltip.png")
	_save(_board(32, 16), "board.png")
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		_save(_button(state), "button_%s.png" % state)
	_save(_separator(), "separator.png")
	_save(_coin(), "icon_gold.png")
	_save(_person(), "icon_people.png")
	_save(_hammer(), "icon_workers.png")
	_save(_hourglass(), "icon_time.png")
	_save(_pause_icon(), "icon_pause.png")
	for speed: int in [1, 2, 3]:
		_save(_play_icon(speed), "icon_speed_%d.png" % speed)
	print("UI art written to ", OUT)
	quit()


func _save(img: Image, name: String) -> void:
	img.resize(img.get_width() * SCALE, img.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	img.save_png(ProjectSettings.globalize_path(OUT.path_join(name)))


func _blank(w: int, h: int) -> Image:
	return Image.create_empty(w, h, false, Image.FORMAT_RGBA8)


## A fixed pseudo-random 0..99 for a pixel (the same art every run).
func _noise(x: int, y: int, salt: int = 0) -> int:
	var h := (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	return absi(h ^ (h >> 16)) % 100


## Parchment with fibres and soft stains.
func _parchment(img: Image, rect: Rect2i, inset: bool) -> void:
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var n := _noise(x, y)
			var c := PARCHMENT_DARK if inset else PARCHMENT
			if n < 6:
				c = c.darkened(0.06)
			elif n < 10:
				c = c.lightened(0.05)
			elif n < 12:
				c = c.darkened(0.1)
			img.set_pixel(x, y, c)


## Wooden boards along x with grain and knots inside [param rect].
func _wood(img: Image, rect: Rect2i, salt: int = 0) -> void:
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var c := WOOD
			var n := _noise(x / 3, y, salt)
			if n < 25:
				c = WOOD.darkened(0.12)
			elif n < 40:
				c = WOOD.lightened(0.07)
			if (y - rect.position.y) % 6 == 5:
				c = WOOD_DARK
			img.set_pixel(x, y, c)


## A parchment panel of [param size] art pixels in a 4-pixel wooden frame with iron brackets at
## the corners (nine-patch margin 6 art pixels = UiKit.PANEL_MARGIN screen pixels / 2).
func _panel(size: int, inset: bool) -> Image:
	var img := _blank(size, size)
	img.fill(OUTLINE)
	# Frame: lighter top-left, darker bottom-right edge of the wood.
	for y: int in range(1, size - 1):
		for x: int in range(1, size - 1):
			var c := WOOD
			if x == 1 or y == 1:
				c = WOOD_LIGHT
			elif x == size - 2 or y == size - 2:
				c = WOOD_DARK
			elif _noise(x, y, 7) < 20:
				c = WOOD.darkened(0.12)
			img.set_pixel(x, y, c)
	var inner := Rect2i(4, 4, size - 8, size - 8)
	for x: int in range(inner.position.x - 1, inner.end.x + 1):
		img.set_pixel(x, inner.position.y - 1, OUTLINE)
		img.set_pixel(x, inner.end.y, WOOD_LIGHT.darkened(0.1))
	for y: int in range(inner.position.y - 1, inner.end.y + 1):
		img.set_pixel(inner.position.x - 1, y, OUTLINE)
		img.set_pixel(inner.end.x, y, WOOD_LIGHT.darkened(0.1))
	_parchment(img, inner, inset)
	# Inner shadow under the frame.
	for x: int in range(inner.position.x, inner.end.x):
		img.set_pixel(x, inner.position.y, img.get_pixel(x, inner.position.y).darkened(0.12))
	for y: int in range(inner.position.y, inner.end.y):
		img.set_pixel(inner.position.x, y, img.get_pixel(inner.position.x, y).darkened(0.12))
	if not inset:
		for corner: Vector2i in [Vector2i(0, 0), Vector2i(size - 6, 0), Vector2i(0, size - 6), Vector2i(size - 6, size - 6)]:
			_bracket(img, corner)
	return img


## An iron corner bracket (6x6) with a rivet.
func _bracket(img: Image, at: Vector2i) -> void:
	for y: int in 6:
		for x: int in 6:
			var edge := x == 0 or y == 0 or x == 5 or y == 5
			img.set_pixel(at.x + x, at.y + y, OUTLINE if edge else IRON)
	img.set_pixel(at.x + 1, at.y + 1, IRON_LIGHT)
	img.set_pixel(at.x + 2, at.y + 2, IRON_LIGHT)
	img.set_pixel(at.x + 3, at.y + 3, OUTLINE)


func _tooltip() -> Image:
	var img := _blank(12, 12)
	img.fill(OUTLINE)
	_parchment(img, Rect2i(1, 1, 10, 10), false)
	return img


## A wooden board of planks with a dark outline (top bar, build menu), tiled along x (no
## nails: repeated, they made dotted lines).
func _board(w: int, h: int) -> Image:
	var img := _blank(w, h)
	img.fill(OUTLINE)
	_wood(img, Rect2i(0, 1, w, h - 2), 3)
	for x: int in w:
		img.set_pixel(x, 1, WOOD_LIGHT)
		img.set_pixel(x, h - 2, WOOD_DARK)
	return img


## A wooden plaque button (nine-patch margin 4 art pixels).
func _button(state: String) -> Image:
	var w := 20
	var h := 14
	var img := _blank(w, h)
	var face := WOOD
	match state:
		"hover":
			face = WOOD_LIGHT
		"pressed":
			face = WOOD_DARK.lightened(0.05)
		"disabled":
			face = Color(0.45, 0.4, 0.36)
	var top := 1 if state == "pressed" else 0
	for y: int in h:
		for x: int in w:
			var corner := (x == 0 or x == w - 1) and (y == top or y == h - 1)
			if corner or y < top:
				continue
			var edge := x == 0 or x == w - 1 or y == top or y == h - 1
			var c := face
			if edge:
				c = OUTLINE
			elif y == top + 1:
				c = face.lightened(0.18)
			elif y >= h - 3 and state != "pressed":
				c = face.darkened(0.3)
			elif _noise(x / 2, y, 5) < 18:
				c = face.darkened(0.08)
			img.set_pixel(x, y, c)
	if state != "disabled":
		for x: int in [2, w - 3]:
			img.set_pixel(x, top + 3, GOLD_DARK)
	return img


## A thin carved line with a diamond in the middle (HSeparator), 32x4 tiled.
func _separator() -> Image:
	var img := _blank(32, 4)
	for x: int in 32:
		img.set_pixel(x, 1, WOOD)
		img.set_pixel(x, 2, WOOD_LIGHT.darkened(0.2))
	return img


func _disc(img: Image, centre: Vector2, r: float, c: Color) -> void:
	for y: int in img.get_height():
		for x: int in img.get_width():
			if Vector2(x + 0.5, y + 0.5).distance_to(centre) <= r:
				img.set_pixel(x, y, c)


func _coin() -> Image:
	var img := _blank(10, 10)
	_disc(img, Vector2(5, 5), 4.6, OUTLINE)
	_disc(img, Vector2(5, 5), 3.7, GOLD_DARK)
	_disc(img, Vector2(4.6, 4.6), 3.0, GOLD)
	for y: int in range(3, 7):
		img.set_pixel(5, y, GOLD_DARK)
	img.set_pixel(3, 3, Color(1, 0.95, 0.7))
	return img


func _person() -> Image:
	var img := _blank(10, 10)
	_disc(img, Vector2(5, 2.8), 2.4, OUTLINE)
	_disc(img, Vector2(5, 2.8), 1.6, Color(0.93, 0.76, 0.6))
	for y: int in range(5, 10):
		for x: int in range(1, 9):
			var edge := y == 5 and (x == 1 or x == 8) or x == 1 or x == 8 or y == 9
			img.set_pixel(x, y, OUTLINE if edge else Color(0.36, 0.5, 0.72))
	return img


func _hammer() -> Image:
	var img := _blank(10, 10)
	for i: int in range(2, 10):
		img.set_pixel(i - 1, 10 - i, OUTLINE)
		img.set_pixel(i, 10 - i, WOOD_LIGHT)
	for y: int in range(0, 4):
		for x: int in range(5, 10):
			img.set_pixel(x, y, OUTLINE if y == 0 or y == 3 or x == 5 or x == 9 else IRON_LIGHT)
	return img


func _hourglass() -> Image:
	var img := _blank(10, 10)
	for y: int in 10:
		var half := absi(y * 2 - 9) / 2 + 1
		for x: int in range(5 - half, 5 + half):
			var edge := x == 5 - half or x == 4 + half or y == 0 or y == 9
			var sand := (y > 6 and y < 9) or (y > 1 and y < 4 and x > 3 and x < 6)
			img.set_pixel(x, y, OUTLINE if edge else (GOLD if sand else PARCHMENT_LIGHT))
	for x: int in range(1, 9):
		img.set_pixel(x, 0, WOOD)
		img.set_pixel(x, 9, WOOD)
	return img


## Time control icons (owner's request 2026-11-07): light symbols with a dark outline, drawn
## on the wooden buttons. Pause: two bars.
func _pause_icon() -> Image:
	var img := _blank(9, 9)
	for x: int in [1, 5]:
		for y: int in range(0, 9):
			for dx: int in 3:
				var edge := dx == 0 or dx == 2 or y == 0 or y == 8
				img.set_pixel(x + dx, y, OUTLINE if edge else PARCHMENT_LIGHT)
	return img


## [param count] play triangles side by side (1x, 2x, 4x).
func _play_icon(count: int) -> Image:
	var w := 4 * count + 2
	var img := _blank(w, 9)
	for i: int in count:
		var left := 1 + i * 4
		for y: int in 9:
			var half := 4 - absi(y - 4)
			for x: int in range(0, half + 1):
				var edge := x == half or x == 0 or y == 0 or y == 8
				img.set_pixel(left + x, y, OUTLINE if edge else PARCHMENT_LIGHT)
	return img
