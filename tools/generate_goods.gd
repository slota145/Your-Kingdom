extends SceneTree
## Final art of goods and nature drawn in code (owner decision 2026-11-05, without PixelLab):
## - goods/stacks/<good>.png: 4 fill stages of a stockpile stack, 64x64 each, tile centre at
##   (32, 48) (ART_SPEC §2, §8),
## - goods/carried/<category>/<good>.png: the good in hand, 5 rows of 24x24 (ART_SPEC §5),
## - goods/icons/<good>.png: 32x32 UI icon,
## - nature/rock and nature/tree: grown, felled, stump; 64x96, tile centre at (32, 80).
##
## Run: godot --headless --path . -s res://tools/generate_goods.gd   (then --import)
##
## Items (logs, planks, sacks, barrels, crates, sheaves, baskets, blocks) are small 3D shapes
## placed on the tile in grid units and drawn back to front, so stacks grow like real heaps.

const OUT := "res://assets"
const STACK_FRAME := Vector2i(64, 64)
const STACK_CENTRE := Vector2(32, 48)
const NATURE_FRAME := Vector2i(64, 96)
const NATURE_CENTRE := Vector2(32, 80)

const C_WOOD := Color(0.55, 0.36, 0.2)
const C_WOOD_END := Color(0.86, 0.7, 0.46)
const C_PLANK := Color(0.82, 0.64, 0.4)
const C_SACK := Color(0.86, 0.8, 0.64)
const C_CANVAS := Color(0.9, 0.86, 0.74)
const C_FLOUR := Color(0.96, 0.95, 0.9)
const C_STONE := Color(0.64, 0.63, 0.6)
const C_IRON := Color(0.3, 0.3, 0.32)
const C_CRATE := Color(0.6, 0.44, 0.26)
const C_STRAW := Color(0.9, 0.76, 0.36)
const C_HOPS := Color(0.55, 0.75, 0.32)
const C_BREAD := Color(0.78, 0.52, 0.24)
const C_FISH := Color(0.7, 0.76, 0.8)
const C_BARREL := Color(0.56, 0.36, 0.2)
const C_BASKET := Color(0.7, 0.54, 0.3)
const C_WOOL := Color(0.95, 0.93, 0.86)
const C_CLOTH := Color(0.74, 0.27, 0.23)
const C_HONEY := Color(0.96, 0.72, 0.18)
const C_CLAY := Color(0.68, 0.5, 0.4)
const C_BRICK := Color(0.74, 0.36, 0.25)
const C_MEAT := Color(0.72, 0.3, 0.26)
const C_FAT := Color(0.95, 0.86, 0.78)
const C_HIDE := Color(0.55, 0.38, 0.24)
const C_PIG := Color(0.93, 0.68, 0.64)
const C_GRAPES := Color(0.42, 0.18, 0.45)
const C_WINE := Color(0.5, 0.1, 0.16)

## Good -> look of one unit: item kind and carry category.
const GOODS := {
	"wood": {"item": "log", "carry": "log"},
	"planks": {"item": "plank", "carry": "log"},
	"grain": {"item": "sheaf", "carry": "bundle"},
	"flour": {"item": "flour_sack", "carry": "sack"},
	"bread": {"item": "bread_crate", "carry": "basket"},
	"fish": {"item": "fish_crate", "carry": "basket"},
	"hops": {"item": "hop_basket", "carry": "bundle"},
	"beer": {"item": "barrel", "carry": "barrel"},
	"stone": {"item": "block", "carry": "stone"},
	# M4b (patricians)
	"wool": {"item": "wool_bale", "carry": "bundle"},
	"cloth": {"item": "cloth_bolt", "carry": "bundle"},
	"clothes": {"item": "clothes_basket", "carry": "basket"},
	"honey": {"item": "honey_pot", "carry": "barrel"},
	"mead": {"item": "mead_barrel", "carry": "barrel"},
	"clay": {"item": "clay_sack", "carry": "sack"},
	"bricks": {"item": "brick_pile", "carry": "stone"},
	# M4b-2 (meat)
	"meat": {"item": "meat_crate", "carry": "basket"},
	"hides": {"item": "hide_bundle", "carry": "bundle"},
	# A live pig: led beside the butcher (carried/animal: rows S, SE, E, NE, N), and a herd
	# grazing on its tile instead of a heap (1 to 4 pigs).
	"pig": {"item": "pig", "carry": "animal"},
	# M5 (the sea)
	"tar": {"item": "tar_barrel", "carry": "barrel"},
	# M6 part 3 (wine)
	"grapes": {"item": "grape_basket", "carry": "basket"},
	"wine": {"item": "wine_barrel", "carry": "barrel"},
}

## Item -> positions [grid x, grid y, z] in fill order (a quarter of them per stage).
var _layouts: Dictionary = {}
## Items to draw: [depth, callable].
var _items: Array = []


func _init() -> void:
	_build_layouts()
	for good: String in GOODS:
		var spec: Dictionary = GOODS[good]
		_stack(good, String(spec["item"]))
		_carried(good, String(spec["item"]), String(spec["carry"]))
		_icon(good, String(spec["item"]))
	_rocks()
	_trees()
	_merchant_cart()
	_handcart()
	_wagon()
	_wagon(true)
	_reeds()
	print("Goods and nature written to ", OUT)
	quit()


# --- Layouts -------------------------------------------------------------------------------

func _build_layouts() -> void:
	# Logs along grid x, in a pyramid: 4 + 3 + 2 + 1 rows... (two deep).
	var logs: Array = []
	for layer: int in 4:
		for k: int in 4 - layer:
			for depth: int in 2:
				logs.append(Vector3(0.0 + depth * 0.02, -0.27 + (k + layer * 0.5) * 0.18, 3.0 + layer * 5.0))
	_layouts["log"] = logs
	# Planks: layers crossing each other.
	var planks: Array = []
	for layer: int in 6:
		for k: int in 3:
			planks.append(Vector3(0, k, layer * 3.0))
	_layouts["plank"] = planks
	var grid: Array = []
	for layer: int in 3:
		for y: int in 2:
			for x: int in 2:
				grid.append(Vector3(-0.18 + x * 0.36, -0.18 + y * 0.36, layer))
	_layouts["grid"] = grid
	# Pigs stand on the ground, one more per stage.
	_layouts["pig"] = [Vector3(-0.12, -0.15, 0), Vector3(0.2, 0.12, 0), Vector3(-0.25, 0.22, 0),
			Vector3(0.18, -0.25, 0)]


func _positions(item: String) -> Array:
	match item:
		"log":
			return _layouts["log"]
		"plank":
			return _layouts["plank"]
		"pig":
			return _layouts["pig"]
	return _layouts["grid"]


# --- Stacks, carried goods, icons ----------------------------------------------------------

func _stack(good: String, item: String) -> void:
	var sheet := Image.create_empty(STACK_FRAME.x * 4, STACK_FRAME.y, false, Image.FORMAT_RGBA8)
	var positions := _positions(item)
	for stage: int in 4:
		var img := Image.create_empty(STACK_FRAME.x, STACK_FRAME.y, false, Image.FORMAT_RGBA8)
		var count := maxi(1, int(ceil(positions.size() * (stage + 1) / 4.0)))
		_items = []
		for i: int in count:
			_place(item, positions[i], i)
		_draw_items(img)
		_outline(img)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, STACK_FRAME), Vector2i(stage * STACK_FRAME.x, 0))
	_save(sheet, "goods/stacks/%s.png" % good)


func _carried(good: String, item: String, category: String) -> void:
	var sheet := Image.create_empty(24, 24 * 5, false, Image.FORMAT_RGBA8)
	for row: int in 5:
		var img := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
		_items = []
		_single(item, Vector2(16, 18), 0.75, row)
		_draw_items(img)
		_outline(img)
		sheet.blit_rect(img, Rect2i(4, 4, 24, 24), Vector2i(0, row * 24))
	_save(sheet, "goods/carried/%s/%s.png" % [category, good])


func _icon(good: String, item: String) -> void:
	var img := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	_items = []
	_single(item, Vector2(16, 21), 1.15, 1)
	_draw_items(img)
	_outline(img)
	_save(img, "goods/icons/%s.png" % good)


## One unit of an item at screen point [param at], scaled (carried goods and icons).
func _single(item: String, at: Vector2, scale: float, row: int) -> void:
	match item:
		"log":
			_queue(0.0, func(img: Image) -> void:
				var along := Vector2(1, 0.5) if row % 2 == 0 else Vector2(1, -0.5)
				_log(img, at - along * 8.0 * scale, at + along * 8.0 * scale, 3.5 * scale))
		"plank":
			_queue(0.0, func(img: Image) -> void:
				for k: int in 3:
					var o := Vector2(0, -k * 2.0 * scale)
					_beam(img, at + o - Vector2(9, 3) * scale, at + o + Vector2(9, 3) * scale, 2.0 * scale, C_PLANK.darkened(0.05 * k)))
		"pig":
			# Rows S, SE, E, NE, N: front, three-quarter and side views, back.
			_queue(0.0, func(img: Image) -> void: _pig(img, at + Vector2(0, 4), scale, row))
		_:
			_queue(0.0, func(img: Image) -> void: _draw_item(img, item, at, scale, 0))


## A pig seen from direction row 0..4 (S, SE, E, NE, N; facing right in the side views).
func _pig(img: Image, foot: Vector2, s: float, row: int) -> void:
	var leg := C_PIG.darkened(0.25)
	if row == 0 or row == 4:
		# Front or back: a round body, legs under it; snout or curly tail.
		for lx: float in [-3.0, 3.0]:
			_line(img, foot + Vector2(lx, -3) * s, foot + Vector2(lx, 0) * s, leg, 1)
		_ellipse(img, foot - Vector2(0, 6) * s, Vector2(5.5, 5.0) * s, C_PIG)
		if row == 0:
			_ellipse(img, foot - Vector2(0, 5) * s, Vector2(2.2, 1.6) * s, C_PIG.darkened(0.15))
			_pixel(img, foot + Vector2(-1, -5) * s, Color(0.45, 0.2, 0.2))
			_pixel(img, foot + Vector2(1, -5) * s, Color(0.45, 0.2, 0.2))
			_pixel(img, foot + Vector2(-2, -8) * s, Color(0.1, 0.08, 0.08))
			_pixel(img, foot + Vector2(2, -8) * s, Color(0.1, 0.08, 0.08))
			_line(img, foot + Vector2(-5, -11) * s, foot + Vector2(-3, -9) * s, C_PIG.darkened(0.1), 1)
			_line(img, foot + Vector2(5, -11) * s, foot + Vector2(3, -9) * s, C_PIG.darkened(0.1), 1)
		else:
			_pixel(img, foot + Vector2(0, -7) * s, C_PIG.darkened(0.3))
			_pixel(img, foot + Vector2(1, -8) * s, C_PIG.darkened(0.3))
		return
	var tilt := {1: 1.5, 2: 0.0, 3: -1.5}[row] as float
	for lx: float in [-4.0, -2.0, 3.0, 5.0]:
		_line(img, foot + Vector2(lx, -3 + tilt * lx / 6.0) * s, foot + Vector2(lx, tilt * lx / 6.0) * s, leg, 1)
	_ellipse(img, foot + Vector2(0, -6 + tilt * 0.2) * s, Vector2(7.0, 4.2) * s, C_PIG)
	_ellipse(img, foot + Vector2(-1, -8 + tilt * 0.2) * s, Vector2(4.0, 1.6) * s, C_PIG.lightened(0.12))
	var head := foot + Vector2(7, -6 + tilt) * s
	_ellipse(img, head, Vector2(3.0, 2.8) * s, C_PIG)
	_ellipse(img, head + Vector2(2.5, 0.8) * s, Vector2(1.4, 1.3) * s, C_PIG.darkened(0.15))
	_pixel(img, head + Vector2(0, -1) * s, Color(0.1, 0.08, 0.08))
	_line(img, head + Vector2(-1, -2) * s, head + Vector2(-2, -4) * s, C_PIG.darkened(0.1), 1)
	_pixel(img, foot + Vector2(-7.5, -8) * s, C_PIG.darkened(0.3))


# --- Items on a stack ----------------------------------------------------------------------

func _place(item: String, p: Vector3, index: int) -> void:
	var centre := STACK_CENTRE
	match item:
		"log":
			var a := centre + IsoMath.grid_to_screen(Vector2(-0.34, p.y)) - Vector2(0, p.z)
			var b := centre + IsoMath.grid_to_screen(Vector2(0.34, p.y)) - Vector2(0, p.z)
			_queue(p.y + p.z * 0.1, func(img: Image) -> void: _log(img, a, b, 3.0 + 0.3 * _hash(index, 1, 3)))
		"plank":
			# Boards along grid x, three side by side per layer, spacer sticks between layers.
			var off := -0.24 + p.y * 0.2
			var corner := Vector3(-0.36, off, p.z)
			var col := C_PLANK.darkened(0.1 * _hash(index, 2, 5))
			_queue(p.z * 10.0 + off, func(img: Image) -> void: _slab(img, corner, Vector3(0.72, 0.18, 2.4), col))
		_:
			var height := _item_height(item)
			var base := centre + IsoMath.grid_to_screen(Vector2(p.x, p.y)) - Vector2(0, p.z * height)
			_queue(p.z * 10.0 + p.x + p.y, func(img: Image) -> void: _draw_item(img, item, base, 1.0, index))


func _item_height(item: String) -> float:
	return {"flour_sack": 7.0, "sheaf": 12.0, "bread_crate": 7.0, "fish_crate": 7.0, "hop_basket": 8.0,
			"barrel": 11.0, "block": 7.0, "wool_bale": 8.0, "cloth_bolt": 5.0, "clothes_basket": 8.0,
			"honey_pot": 9.0, "mead_barrel": 11.0, "tar_barrel": 11.0, "clay_sack": 7.0, "brick_pile": 6.0,
			"meat_crate": 7.0, "hide_bundle": 4.0, "grape_basket": 8.0, "wine_barrel": 11.0}.get(item, 7.0)


func _draw_item(img: Image, item: String, foot: Vector2, s: float, index: int) -> void:
	var v := 0.1 * _hash(index, 7, 11)
	match item:
		"flour_sack":
			_ellipse(img, foot - Vector2(0, 4.5) * s, Vector2(6.5, 5.0) * s, C_FLOUR.darkened(v))
			_ellipse(img, foot - Vector2(-1, 9.0) * s, Vector2(2.0, 1.5) * s, C_FLOUR.darkened(0.15))
			_line(img, foot - Vector2(3, 4) * s, foot - Vector2(-1, 6) * s, Color(0.35, 0.45, 0.7), 1)
		"sheaf":
			for i: int in 7:
				var x := (i - 3) * 1.4 * s
				_line(img, foot + Vector2(x, 0), foot + Vector2(x * 1.8, -14.0 * s), C_STRAW.darkened(0.12 * float(i % 2) + v), 1)
			_ellipse(img, foot - Vector2(0, 15.0) * s, Vector2(4.0, 2.0) * s, C_STRAW.lightened(0.1))
			_line(img, foot - Vector2(3.5, 6.0) * s, foot - Vector2(-3.5, 6.0) * s, Color(0.55, 0.4, 0.2), 1)
		"bread_crate", "fish_crate", "hop_basket", "grape_basket":
			var basket := item == "hop_basket" or item == "grape_basket"
			var body := C_BASKET if basket else C_CRATE
			_box(img, foot, Vector2(14, 7) * s, 6.0 * s, body.darkened(v), "wicker" if basket else "planks")
			var top := foot - Vector2(0, 6.0 * s + 3.5 * s)
			match item:
				"bread_crate":
					_ellipse(img, top + Vector2(-2.5, 0.5) * s, Vector2(3.2, 2.0) * s, C_BREAD)
					_ellipse(img, top + Vector2(2.5, -0.5) * s, Vector2(3.2, 2.0) * s, C_BREAD.lightened(0.1))
				"fish_crate":
					for k: int in 3:
						var a := top + Vector2(-4 + k * 3.5, -1 + k * 0.6) * s
						_line(img, a, a + Vector2(3.5, 1.5) * s, C_FISH.darkened(0.1 * float(k % 2)), 2)
						_pixel(img, a + Vector2(4.5, 2.0) * s, C_FISH.darkened(0.3))
				"grape_basket":
					# Dark purple bunches heaped in the basket, a vine leaf on top.
					for k: int in 6:
						_ellipse(img, top + Vector2(-4.0 + k * 1.6, -0.5 + (k % 2) * 1.0) * s, Vector2(1.5, 1.5) * s,
								C_GRAPES.darkened(0.15 * float(k % 2)))
					_ellipse(img, top + Vector2(2.5, -1.8) * s, Vector2(2.0, 1.2) * s, Color(0.35, 0.55, 0.22))
				"hop_basket":
					for k: int in 5:
						_ellipse(img, top + Vector2(-3.5 + k * 1.8, sin(k) * 0.8) * s, Vector2(1.6, 1.6) * s, C_HOPS.darkened(0.12 * float(k % 2)))
		"barrel":
			_ellipse(img, foot - Vector2(0, 5.5) * s, Vector2(5.0, 6.0) * s, C_BARREL.darkened(v))
			_line(img, foot - Vector2(5, 8) * s, foot - Vector2(-5, 8) * s, C_IRON, 1)
			_line(img, foot - Vector2(5, 3) * s, foot - Vector2(-5, 3) * s, C_IRON, 1)
			_ellipse(img, foot - Vector2(0, 11.0) * s, Vector2(4.0, 1.6) * s, C_BARREL.lightened(0.18))
		"block":
			_box(img, foot, Vector2(14, 7) * s, 6.0 * s, C_STONE.darkened(v), "stone")
		"wool_bale":
			# Fleece: a fluffy white bundle of overlapping puffs tied with twine.
			for k: int in 5:
				var o := Vector2(-4 + k * 2, -4 - (k % 2) * 3) * s
				_ellipse(img, foot + o, Vector2(3.5, 3.0) * s, C_WOOL.darkened(v + 0.05 * float(k % 2)))
			_ellipse(img, foot - Vector2(0, 8) * s, Vector2(3.0, 2.2) * s, C_WOOL.lightened(0.05))
			_line(img, foot - Vector2(5, 4) * s, foot - Vector2(-5, 5) * s, Color(0.6, 0.45, 0.25), 1)
		"cloth_bolt":
			# A rolled bolt of red cloth lying along the tile, the roll end visible.
			var col := C_CLOTH.darkened(v)
			var a := foot + Vector2(-7, -1) * s
			var b := foot + Vector2(6, -4.5) * s
			_line(img, a - Vector2(0, 2) * s, b - Vector2(0, 2) * s, col, maxi(1, roundi(4 * s)))
			_line(img, a - Vector2(0, 4) * s, b - Vector2(0, 4) * s, col.lightened(0.15), 1)
			_ellipse(img, b - Vector2(-1, 2) * s, Vector2(2.0, 2.5) * s, col.lightened(0.25))
			_pixel(img, b - Vector2(-1, 2) * s, col.darkened(0.3))
		"clothes_basket":
			_box(img, foot, Vector2(14, 7) * s, 5.0 * s, C_BASKET.darkened(v), "wicker")
			var top := foot - Vector2(0, 5.0 * s + 3.5 * s)
			_ellipse(img, top + Vector2(-2.5, 0.5) * s, Vector2(3.5, 1.8) * s, Color(0.3, 0.42, 0.7))
			_ellipse(img, top + Vector2(2.5, -0.3) * s, Vector2(3.5, 1.8) * s, C_CLOTH)
			_ellipse(img, top + Vector2(0, -1.5) * s, Vector2(3.0, 1.5) * s, Color(0.92, 0.9, 0.82))
		"honey_pot":
			# Clay pot sealed with cloth, golden honey dripping down the side.
			_ellipse(img, foot - Vector2(0, 4.5) * s, Vector2(4.5, 5.0) * s, Color(0.7, 0.42, 0.28).darkened(v))
			_ellipse(img, foot - Vector2(0, 9.5) * s, Vector2(3.0, 1.4) * s, Color(0.92, 0.88, 0.78))
			_line(img, foot - Vector2(3, 9) * s, foot - Vector2(3, 5) * s, C_HONEY, 1)
			_ellipse(img, foot - Vector2(0, 5) * s, Vector2(1.6, 1.4) * s, C_HONEY)
		"mead_barrel":
			_ellipse(img, foot - Vector2(0, 5.5) * s, Vector2(5.0, 6.0) * s, C_BARREL.lightened(0.08).darkened(v))
			_line(img, foot - Vector2(5, 8) * s, foot - Vector2(-5, 8) * s, C_IRON, 1)
			_line(img, foot - Vector2(5, 3) * s, foot - Vector2(-5, 3) * s, C_IRON, 1)
			_ellipse(img, foot - Vector2(0, 11.0) * s, Vector2(4.0, 1.6) * s, C_BARREL.lightened(0.18))
			# Golden honey mark on the side tells mead from beer.
			_ellipse(img, foot - Vector2(0, 5.5) * s, Vector2(1.6, 1.3) * s, C_HONEY)
		"wine_barrel":
			# A barrel with red hoops of wine-stain and a purple mark: wine, not beer.
			_ellipse(img, foot - Vector2(0, 5.5) * s, Vector2(5.0, 6.0) * s, C_BARREL.darkened(0.05 + v))
			_line(img, foot - Vector2(5, 8) * s, foot - Vector2(-5, 8) * s, C_IRON, 1)
			_line(img, foot - Vector2(5, 3) * s, foot - Vector2(-5, 3) * s, C_IRON, 1)
			_ellipse(img, foot - Vector2(0, 11.0) * s, Vector2(4.0, 1.6) * s, C_WINE)
			_ellipse(img, foot - Vector2(0, 5.5) * s, Vector2(1.6, 1.3) * s, C_GRAPES)
		"tar_barrel":
			# A dark barrel with tar run down from the bung.
			_ellipse(img, foot - Vector2(0, 5.5) * s, Vector2(5.0, 6.0) * s, Color(0.26, 0.19, 0.14).darkened(v))
			_line(img, foot - Vector2(5, 8) * s, foot - Vector2(-5, 8) * s, C_IRON, 1)
			_line(img, foot - Vector2(5, 3) * s, foot - Vector2(-5, 3) * s, C_IRON, 1)
			_ellipse(img, foot - Vector2(0, 11.0) * s, Vector2(4.0, 1.6) * s, Color(0.1, 0.08, 0.07))
			_line(img, foot - Vector2(1, 11) * s, foot - Vector2(1, 6) * s, Color(0.06, 0.05, 0.05), 1)
		"clay_sack":
			_ellipse(img, foot - Vector2(0, 4.5) * s, Vector2(6.5, 5.0) * s, C_SACK.darkened(0.15 + v))
			_ellipse(img, foot - Vector2(0, 8.5) * s, Vector2(4.0, 2.0) * s, C_CLAY)
			_ellipse(img, foot - Vector2(1, 9.5) * s, Vector2(2.0, 1.2) * s, C_CLAY.lightened(0.12))
		"pig":
			_pig(img, foot, s, 1 if index % 2 == 0 else 2)
		"meat_crate":
			# A crate with a ham and a side of bacon.
			_box(img, foot, Vector2(14, 7) * s, 5.0 * s, C_CRATE.darkened(v), "planks")
			var top := foot - Vector2(0, 5.0 * s + 3.0 * s)
			_ellipse(img, top + Vector2(-2.5, 0.3) * s, Vector2(3.6, 2.4) * s, C_MEAT)
			_ellipse(img, top + Vector2(-3.5, -0.4) * s, Vector2(1.6, 1.0) * s, C_FAT)
			_line(img, top + Vector2(0.5, -1.0) * s, top + Vector2(5.0, 1.0) * s, C_MEAT.lightened(0.08), maxi(1, roundi(2 * s)))
			_line(img, top + Vector2(0.5, -2.0) * s, top + Vector2(5.0, 0.0) * s, C_FAT, 1)
		"hide_bundle":
			# Folded hides: brown skins with pale undersides showing at the edges.
			for k: int in 3:
				var o := foot - Vector2(0, 1.5 + k * 1.6) * s
				_ellipse(img, o + Vector2((k % 2) * 1.0, 0) * s, Vector2(6.5, 2.6) * s, C_HIDE.darkened(v + 0.06 * k))
				_line(img, o + Vector2(-6, 0.5) * s, o + Vector2(-3, 1.8) * s, C_HIDE.lightened(0.35), 1)
			_line(img, foot - Vector2(1, 7) * s, foot - Vector2(1, 1) * s, Color(0.35, 0.25, 0.15), 1)
		"brick_pile":
			for k: int in 2:
				_box(img, foot - Vector2(0, k * 3.0) * s, Vector2(12, 6) * s, 3.0 * s, C_BRICK.darkened(v + 0.06 * k), "brick")


# --- Vehicles ------------------------------------------------------------------------------

## The travelling merchant's covered cart (M4b-2): 96x80, the ground point under its middle at
## (48, 64). Two big wheels, a plank box with crates and sacks, a striped canvas cover, shafts.
func _merchant_cart() -> void:
	var img := Image.create_empty(96, 80, false, Image.FORMAT_RGBA8)
	var foot := Vector2(48, 64)
	# Shafts reaching forward to the left (along grid y).
	_line(img, foot + Vector2(-14, -10), foot + Vector2(-40, 3), C_WOOD.darkened(0.1), 2)
	_line(img, foot + Vector2(-6, -6), foot + Vector2(-32, 7), C_WOOD.darkened(0.2), 2)
	# Far wheel, box, near wheel.
	_wheel(img, foot + Vector2(10, -12))
	_box(img, foot + Vector2(0, -6), Vector2(40, 18), 12.0, C_PLANK.darkened(0.1), "planks")
	var top := foot + Vector2(0, -18)
	_box(img, top + Vector2(-8, -2), Vector2(10, 6), 6.0, C_CRATE, "planks")
	_ellipse(img, top + Vector2(6, -5), Vector2(4, 3), C_SACK)
	_ellipse(img, top + Vector2(-1, -7), Vector2(3.5, 3), C_BARREL)
	# Striped canvas cover over the back half, an arch.
	for k: int in 14:
		var t := float(k) / 13.0
		var base := top + Vector2(2, -3).lerp(Vector2(18, -11), t)
		var col := Color(0.82, 0.25, 0.2) if k % 4 < 2 else Color(0.94, 0.9, 0.78)
		_line(img, base, base + Vector2(-10, -16), col, 2)
	_line(img, top + Vector2(-8, -19), top + Vector2(8, -27), Color(0.55, 0.4, 0.3), 1)
	_wheel(img, foot + Vector2(-8, -2))
	_outline(img)
	_save(img, "vehicles/merchant_cart.png")


# --- Handcart (M4b-3) -----------------------------------------------------------------------

## Frame of one direction of a vehicle sheet, and the ground point under the vehicle's centre.
const CART_FRAME := Vector2i(48, 40)
const CART_CENTRE := Vector2(24, 30)
## Forward vector in grid space of rows S, SE, E, NE, N (the view mirrors the other three).
const ROW_FORWARD: Array[Vector2] = [Vector2(0.7071, 0.7071), Vector2(1, 0), Vector2(0.7071, -0.7071),
		Vector2(0, -1), Vector2(-0.7071, -0.7071)]
## Horse wagon frame and ground point under the wagon's local origin (between cart and horse).
const WAGON_FRAME := Vector2i(112, 80)
const WAGON_CENTRE := Vector2(56, 52)
const C_HORSE := Color(0.48, 0.3, 0.18)

## Ground point of the vehicle being drawn (_cart_point).
var _vehicle_origin: Vector2 = CART_CENTRE


## A two-wheeled handcart pushed by a porter: an open tray on two wheels with handles at the
## back. vehicles/handcart/{empty,loaded}.png, 5 rows (S, SE, E, NE, N), 48x40 per frame,
## the cart's centre on the ground at (24, 30).
func _handcart() -> void:
	for state: String in ["empty", "loaded"]:
		var sheet := Image.create_empty(CART_FRAME.x, CART_FRAME.y * 5, false, Image.FORMAT_RGBA8)
		for row: int in 5:
			var img := Image.create_empty(CART_FRAME.x, CART_FRAME.y, false, Image.FORMAT_RGBA8)
			var fwd := ROW_FORWARD[row]
			var parts: Array = []   # [depth, callable]
			for side: float in [-0.2, 0.2]:
				var hub := Vector3(0.04, side, 6.0)
				parts.append([_cart_depth(fwd, hub), _cart_wheel.bind(img, fwd, hub, 6.0)])
			parts.append([_cart_depth(fwd, Vector3(0, 0, 10)) + 0.001, func() -> void:
				_cart_box(img, fwd, Vector3(-0.22, -0.15, 8.0), Vector3(0.22, 0.15, 14.0),
						C_PLANK.darkened(0.15), C_WOOD.darkened(0.25))
				for side: float in [-0.1, 0.1]:
					_line(img, _cart_point(fwd, Vector3(-0.2, side, 13.0)),
							_cart_point(fwd, Vector3(-0.44, side, 16.0)), C_WOOD.darkened(0.1), 1)
				if state == "loaded":
					_cart_box(img, fwd, Vector3(-0.17, -0.12, 13.0), Vector3(0.01, 0.12, 18.0), C_SACK, C_SACK)
					_cart_box(img, fwd, Vector3(0.02, -0.11, 13.0), Vector3(0.18, 0.1, 17.0), C_CRATE, C_CRATE)
			])
			parts.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
			for part: Array in parts:
				(part[1] as Callable).call()
			_outline(img)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CART_FRAME), Vector2i(0, row * CART_FRAME.y))
		_save(sheet, "vehicles/handcart/%s.png" % state)


## Reed tufts for lake shallows (M4b-3): terrain/reeds/{a,b,c}.png, 24x32, the tuft's foot
## at (12, 29). Green blades leaning a little, some with a brown cattail head.
func _reeds() -> void:
	var greens := [Color(0.42, 0.55, 0.26), Color(0.5, 0.62, 0.3), Color(0.36, 0.48, 0.22), Color(0.6, 0.66, 0.34)]
	for v: int in 3:
		var img := Image.create_empty(24, 32, false, Image.FORMAT_RGBA8)
		var foot := Vector2(12, 29)
		var blades := 7 + v * 2
		for k: int in blades:
			var base := foot + Vector2(-6 + 12.0 * k / blades + _hash(k, v, 3) * 2.0, _hash(k, v, 5) * 2.0)
			var height := 14.0 + 12.0 * _hash(k, v, 7)
			var lean := (_hash(k, v, 11) - 0.5) * 8.0
			var tip := base + Vector2(lean, -height)
			var colour: Color = greens[(k + v) % greens.size()]
			_line(img, base, base.lerp(tip, 0.6), colour.darkened(0.1), 1)
			_line(img, base.lerp(tip, 0.6), tip, colour.lightened(0.08), 1)
			if k % 3 == v % 3 and height > 18.0:
				var head := base.lerp(tip, 0.78)
				_line(img, head, head + Vector2(lean * 0.1, -4), Color(0.45, 0.28, 0.16), 2)
		# A dark wet line where the stems meet the water.
		for x: int in range(5, 19):
			_pixel(img, Vector2(x, 30), Color(0.12, 0.2, 0.18, 0.55))
		_save(img, "terrain/reeds/%s.png" % ["a", "b", "c"][v])


## A horse wagon led by its carter (M4b-3): a four-wheeled wagon box with shafts and a brown
## horse in front. vehicles/wagon/{empty,loaded}.png, 5 rows (S, SE, E, NE, N) of 112x80;
## the local origin (between wagon and horse) on the ground at (56, 52). The carter walks
## 0.45 tiles in front of it, at the horse's head.
func _wagon(trade: bool = false) -> void:
	_vehicle_origin = WAGON_CENTRE
	for state: String in ["empty", "loaded"]:
		var sheet := Image.create_empty(WAGON_FRAME.x, WAGON_FRAME.y * 5, false, Image.FORMAT_RGBA8)
		for row: int in 5:
			var img := Image.create_empty(WAGON_FRAME.x, WAGON_FRAME.y, false, Image.FORMAT_RGBA8)
			var fwd := ROW_FORWARD[row]
			var parts: Array = []
			for f: float in ([-1.15, -0.4] if trade else [-0.95, -0.4]):
				for side: float in [-0.25, 0.25]:
					var hub := Vector3(f, side, 7.0)
					parts.append([_cart_depth(fwd, hub), _cart_wheel.bind(img, fwd, hub, 7.0)])
			parts.append([_cart_depth(fwd, Vector3(-0.68, 0, 0)) + 0.001, func() -> void:
				_cart_box(img, fwd, Vector3(-1.35 if trade else -1.1, -0.21, 9.0), Vector3(-0.25, 0.21, 17.0),
						C_PLANK.darkened(0.12), C_WOOD.darkened(0.3))
				if trade:
					# The merchant wagon: a tall canvas cover over hoops, tied down at the back.
					_cart_box(img, fwd, Vector3(-1.32, -0.2, 17.0), Vector3(-0.3, 0.2, 31.0), C_CANVAS, C_CANVAS.lightened(0.08))
					for hoop: float in [-1.1, -0.8, -0.5]:
						_line(img, _cart_point(fwd, Vector3(hoop, -0.2, 17.0)), _cart_point(fwd, Vector3(hoop, -0.2, 31.0)),
								C_CANVAS.darkened(0.2), 1)
				elif state == "loaded":
					_cart_box(img, fwd, Vector3(-1.02, -0.16, 17.0), Vector3(-0.72, 0.16, 24.0), C_SACK, C_SACK)
					_cart_box(img, fwd, Vector3(-0.68, -0.15, 17.0), Vector3(-0.47, 0.13, 23.0), C_CRATE, C_CRATE)
					_cart_box(img, fwd, Vector3(-0.44, -0.12, 17.0), Vector3(-0.3, 0.12, 21.0), C_BARREL, C_BARREL)
			])
			for side: float in [-0.13, 0.13]:
				parts.append([_cart_depth(fwd, Vector3(-0.05, side, 0)), _shaft.bind(img, fwd, side)])
			for f: float in [-0.05, 0.3]:
				for side: float in [-0.05, 0.05]:
					parts.append([_cart_depth(fwd, Vector3(f, side, 0)), _horse_leg.bind(img, fwd, Vector3(f, side, 0))])
			parts.append([_cart_depth(fwd, Vector3(0.12, 0, 0)) + 0.002, func() -> void:
				_cart_box(img, fwd, Vector3(-0.12, -0.08, 12.0), Vector3(0.36, 0.08, 21.0), C_HORSE, C_HORSE)
				_cart_box(img, fwd, Vector3(0.3, -0.05, 18.0), Vector3(0.42, 0.05, 29.0), C_HORSE, C_HORSE.darkened(0.15))
				_cart_box(img, fwd, Vector3(0.38, -0.045, 24.0), Vector3(0.56, 0.045, 29.0), C_HORSE.lightened(0.05), C_HORSE)
				_line(img, _cart_point(fwd, Vector3(-0.12, 0, 20.0)), _cart_point(fwd, Vector3(-0.2, 0, 11.0)),
						Color(0.2, 0.14, 0.1), 2)
			])
			parts.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
			for part: Array in parts:
				(part[1] as Callable).call()
			_outline(img)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, WAGON_FRAME), Vector2i(0, row * WAGON_FRAME.y))
		_save(sheet, "vehicles/%s/%s.png" % ["trade_wagon" if trade else "wagon", state])
	_vehicle_origin = CART_CENTRE


func _shaft(img: Image, fwd: Vector2, side: float) -> void:
	_line(img, _cart_point(fwd, Vector3(-0.25, side, 13.0)), _cart_point(fwd, Vector3(0.3, side, 17.0)),
			C_WOOD.darkened(0.15), 1)


func _horse_leg(img: Image, fwd: Vector2, foot: Vector3) -> void:
	_line(img, _cart_point(fwd, foot + Vector3(0, 0, 13.0)), _cart_point(fwd, foot), C_HORSE.darkened(0.25), 2)


## Screen point of a cart-local point (forward, side in tiles, height in px).
func _cart_point(fwd: Vector2, p: Vector3) -> Vector2:
	var side := Vector2(-fwd.y, fwd.x)
	var g := fwd * p.x + side * p.y
	return _vehicle_origin + Vector2((g.x - g.y) * 32.0, (g.x + g.y) * 16.0 - p.z)


## Farther parts first: larger grid x + y is nearer the camera.
func _cart_depth(fwd: Vector2, p: Vector3) -> float:
	var side := Vector2(-fwd.y, fwd.x)
	var g := fwd * p.x + side * p.y
	return g.x + g.y


## A box between two cart-local corners: faces turned to the camera, shaded by direction;
## the top in [param top] (the inside of an open tray or the top of a load).
func _cart_box(img: Image, fwd: Vector2, a: Vector3, b: Vector3, colour: Color, top: Color) -> void:
	var side := Vector2(-fwd.y, fwd.x)
	var faces := [
		[Vector3(1, 0, 0), [Vector3(b.x, a.y, a.z), Vector3(b.x, b.y, a.z), Vector3(b.x, b.y, b.z), Vector3(b.x, a.y, b.z)]],
		[Vector3(-1, 0, 0), [Vector3(a.x, a.y, a.z), Vector3(a.x, b.y, a.z), Vector3(a.x, b.y, b.z), Vector3(a.x, a.y, b.z)]],
		[Vector3(0, 1, 0), [Vector3(a.x, b.y, a.z), Vector3(b.x, b.y, a.z), Vector3(b.x, b.y, b.z), Vector3(a.x, b.y, b.z)]],
		[Vector3(0, -1, 0), [Vector3(a.x, a.y, a.z), Vector3(b.x, a.y, a.z), Vector3(b.x, a.y, b.z), Vector3(a.x, a.y, b.z)]],
	]
	for face: Array in faces:
		var n: Vector3 = face[0]
		var ng := fwd * n.x + side * n.y
		if ng.x + ng.y <= 0.01:
			continue
		var shade := 0.0 if ng.x >= ng.y else 0.18
		var points := PackedVector2Array()
		for corner: Vector3 in face[1]:
			points.append(_cart_point(fwd, corner))
		_polygon(img, points, colour.darkened(shade))
	var roof := PackedVector2Array([_cart_point(fwd, Vector3(a.x, a.y, b.z)), _cart_point(fwd, Vector3(b.x, a.y, b.z)),
			_cart_point(fwd, Vector3(b.x, b.y, b.z)), _cart_point(fwd, Vector3(a.x, b.y, b.z))])
	_polygon(img, roof, top.lightened(0.08))


## A spoked wheel standing in the forward/up plane around [param hub].
func _cart_wheel(img: Image, fwd: Vector2, hub: Vector3, radius: float) -> void:
	var rim := PackedVector2Array()
	for k: int in 16:
		var t := k * TAU / 16.0
		rim.append(_cart_point(fwd, hub + Vector3(cos(t) * radius / 36.0, 0.0, sin(t) * radius)))
	_polygon(img, rim, C_WOOD.darkened(0.3))
	var centre := _cart_point(fwd, hub)
	for k: int in 3:
		var t := k * PI / 3.0
		var d := _cart_point(fwd, hub + Vector3(cos(t) * radius * 0.8 / 36.0, 0.0, sin(t) * radius * 0.8)) - centre
		_line(img, centre - d, centre + d, C_WOOD_END.darkened(0.2), 1)
	_pixel(img, centre, C_IRON)


## Fills a polygon (pixel centres inside).
func _polygon(img: Image, points: PackedVector2Array, colour: Color) -> void:
	var box := Rect2(points[0], Vector2.ZERO)
	for p: Vector2 in points:
		box = box.expand(p)
	for y: int in range(floori(box.position.y), ceili(box.end.y) + 1):
		for x: int in range(floori(box.position.x), ceili(box.end.x) + 1):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), points):
				_pixel(img, Vector2(x, y), colour)


func _wheel(img: Image, centre: Vector2) -> void:
	_ellipse(img, centre, Vector2(6, 9), C_WOOD.darkened(0.25))
	_ellipse(img, centre, Vector2(4.5, 7), C_WOOD.lightened(0.05))
	for a: float in [0.0, PI / 3.0, 2.0 * PI / 3.0]:
		var d := Vector2(cos(a) * 4.0, sin(a) * 6.5)
		_line(img, centre - d, centre + d, C_WOOD.darkened(0.3), 1)
	_ellipse(img, centre, Vector2(1.5, 2), C_IRON)


# --- Nature --------------------------------------------------------------------------------

func _rocks() -> void:
	var states := {"grown": [[Vector2(-5, 2), 13.0, 15.0], [Vector2(8, 4), 9.0, 10.0], [Vector2(1, -5), 10.0, 12.0], [Vector2(-10, 6), 6.0, 6.0]],
			"felled": [[Vector2(-4, 3), 9.0, 9.0], [Vector2(7, 4), 7.0, 6.0]],
			"stump": [[Vector2(-5, 4), 5.0, 3.0], [Vector2(3, 5), 4.0, 2.5], [Vector2(8, 2), 3.0, 2.0]]}
	for state: String in states:
		var img := Image.create_empty(NATURE_FRAME.x, NATURE_FRAME.y, false, Image.FORMAT_RGBA8)
		var boulders: Array = states[state]
		boulders.sort_custom(func(a: Array, b: Array) -> bool: return (a[0] as Vector2).y < (b[0] as Vector2).y)
		for k: int in boulders.size():
			var b: Array = boulders[k]
			_boulder(img, NATURE_CENTRE + (b[0] as Vector2), b[1], b[2], k)
		if state == "stump":
			for k: int in 6:
				_pixel(img, NATURE_CENTRE + Vector2(-12 + k * 4, 6 + (k % 2) * 2), C_STONE.darkened(0.2))
		_outline(img)
		_save(img, "nature/rock/%s.png" % state)


## An irregular boulder: lit top, mid left face, dark right face, cracks and moss.
func _boulder(img: Image, foot: Vector2, radius: float, height: float, salt: int) -> void:
	var points := PackedVector2Array()
	for k: int in 9:
		var a := PI + k * PI / 8.0
		var r := radius * (0.8 + 0.25 * _hash(k, salt, 21))
		points.append(foot + Vector2(cos(a) * r, sin(a) * r * 0.55 - height * (0.6 + 0.4 * sin(k * PI / 8.0))))
	points.append(foot + Vector2(radius * 0.9, 1))
	points.append(foot + Vector2(0, radius * 0.4))
	points.append(foot + Vector2(-radius * 0.9, 1))
	var bounds := Rect2(points[0], Vector2.ZERO)
	for p: Vector2 in points:
		bounds = bounds.expand(p)
	for y: int in range(int(bounds.position.y), int(bounds.end.y) + 1):
		for x: int in range(int(bounds.position.x), int(bounds.end.x) + 1):
			var q := Vector2(x + 0.5, y + 0.5)
			if not Geometry2D.is_point_in_polygon(q, points):
				continue
			var rel := (q - foot) / Vector2(radius, height + radius * 0.5)
			var col := C_STONE
			if rel.y < -0.55:
				col = C_STONE.lightened(0.12)
			elif rel.x > 0.15:
				col = C_STONE.darkened(0.22)
			col = col.darkened(0.08 * _hash(x / 2, y / 2, salt + 31))
			if absf(rel.x + rel.y * 0.4 - 0.1) < 0.04 and rel.y > -0.6:
				col = C_STONE.darkened(0.4)
			if rel.y < -0.7 and _hash(x, y, salt + 41) > 0.7:
				col = Color(0.42, 0.55, 0.3)
			img.set_pixel(x, y, col)


func _trees() -> void:
	var trunk := Color(0.42, 0.28, 0.17)
	var leaves := Color(0.22, 0.44, 0.2)
	# Grown: trunk and a crown of overlapping leaf clusters.
	var img := _nature_image()
	var foot := NATURE_CENTRE
	_ellipse(img, foot + Vector2(0, 1), Vector2(10, 4), Color(0.2, 0.3, 0.14, 0.0))
	_trunk(img, foot, 34.0, 6.0, trunk)
	_line(img, foot - Vector2(0, 26), foot - Vector2(-7, 36), trunk, 2)
	_line(img, foot - Vector2(0, 28), foot - Vector2(6, 38), trunk, 2)
	var clusters: Array = [[Vector2(0, -50), 15.0], [Vector2(-11, -42), 11.0], [Vector2(11, -41), 11.0],
			[Vector2(-6, -60), 10.0], [Vector2(7, -58), 10.0], [Vector2(0, -36), 10.0], [Vector2(-14, -52), 7.0],
			[Vector2(14, -50), 7.0], [Vector2(0, -66), 7.0]]
	for k: int in clusters.size():
		var c: Array = clusters[k]
		_foliage(img, foot + (c[0] as Vector2), c[1], leaves, k)
	_outline(img)
	_save(img, "nature/tree/grown.png")
	# Felled: the trunk on the ground, a smaller crown at its end, the stump.
	img = _nature_image()
	_beam(img, foot + Vector2(-6, 1), foot + Vector2(14, -8), 5.0, trunk)
	_foliage(img, foot + Vector2(19, -13), 9.0, leaves.darkened(0.05), 3)
	_foliage(img, foot + Vector2(13, -18), 7.0, leaves, 5)
	_stump(img, foot - Vector2(4, 0), trunk)
	_outline(img)
	_save(img, "nature/tree/felled.png")
	img = _nature_image()
	_stump(img, foot, trunk)
	_line(img, foot + Vector2(-4, 1), foot + Vector2(-9, 4), trunk, 2)
	_line(img, foot + Vector2(4, 1), foot + Vector2(8, 3), trunk, 2)
	_outline(img)
	_save(img, "nature/tree/stump.png")
	# Sapling (planted by the forester, grows into a tree): thin stem tied to a stake, a few
	# small leaf clusters, a ring of loosened earth.
	img = _nature_image()
	_ellipse(img, foot + Vector2(0, 1), Vector2(7, 3), Color(0.42, 0.31, 0.2))
	_line(img, foot + Vector2(4, 1), foot + Vector2(4, -26), Color(0.72, 0.58, 0.38), 2)
	_trunk(img, foot, 20.0, 2.0, trunk)
	_line(img, foot + Vector2(0, -12), foot + Vector2(4, -12), Color(0.85, 0.8, 0.65), 1)
	_line(img, foot - Vector2(0, 16), foot - Vector2(-4, 21), trunk, 1)
	_line(img, foot - Vector2(0, 17), foot - Vector2(4, 22), trunk, 1)
	var small: Array = [[Vector2(0, -26), 6.0], [Vector2(-5, -22), 4.5], [Vector2(5, -21), 4.5], [Vector2(0, -31), 4.0]]
	for k: int in small.size():
		var c: Array = small[k]
		_foliage(img, foot + (c[0] as Vector2), c[1], leaves.lightened(0.1), k + 20)
	_outline(img)
	_save(img, "nature/sapling/grown.png")


func _foliage(img: Image, centre: Vector2, radius: float, colour: Color, salt: int) -> void:
	for y: int in range(int(centre.y - radius) - 1, int(centre.y + radius) + 2):
		for x: int in range(int(centre.x - radius) - 1, int(centre.x + radius) + 2):
			var d := Vector2(x + 0.5 - centre.x, (y + 0.5 - centre.y) * 1.1) / radius
			var ragged := 1.0 - 0.18 * _hash(x / 2, y / 2, salt + 51)
			if d.length() > ragged:
				continue
			var light := -d.x * 0.3 - d.y * 0.5
			var col := colour.lightened(clampf(light * 0.4, 0.0, 0.3)) if light > 0.0 else colour.darkened(clampf(-light * 0.5, 0.0, 0.35))
			if _hash(x, y, salt + 61) > 0.82:
				col = col.lightened(0.15)
			_pixel(img, Vector2(x, y), col)


func _stump(img: Image, foot: Vector2, trunk: Color) -> void:
	_trunk(img, foot, 6.0, 7.0, trunk)
	_ellipse(img, foot - Vector2(0, 6), Vector2(3.5, 1.8), C_WOOD_END)
	_pixel(img, foot - Vector2(0, 6), C_WOOD_END.darkened(0.3))


func _nature_image() -> Image:
	return Image.create_empty(NATURE_FRAME.x, NATURE_FRAME.y, false, Image.FORMAT_RGBA8)


# --- Primitives ----------------------------------------------------------------------------

func _queue(depth: float, draw: Callable) -> void:
	_items.append([depth, draw])


func _draw_items(img: Image) -> void:
	_items.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for item: Array in _items:
		(item[1] as Callable).call(img)
	_items = []


## A log lying from [param a] to [param b] (screen), cut end visible at [param b].
func _log(img: Image, a: Vector2, b: Vector2, radius: float) -> void:
	var steps := maxi(1, int(a.distance_to(b)))
	for i: int in steps + 1:
		var p := a.lerp(b, float(i) / steps)
		for dy: int in range(-int(radius), int(radius) + 1):
			var shade := float(dy) / radius
			var col := C_WOOD.lightened(0.15) if shade < -0.4 else (C_WOOD.darkened(0.2) if shade > 0.4 else C_WOOD)
			if (i + dy * 3) % 7 == 0:
				col = col.darkened(0.15)
			_pixel(img, p + Vector2(0, dy), col)
	_ellipse(img, b, Vector2(radius * 0.8, radius), C_WOOD_END)
	_ellipse(img, b, Vector2(radius * 0.35, radius * 0.45), C_WOOD_END.darkened(0.2))


## A thin box (board) in tile grid units from [param corner] (x, y, z px) with [param size].
func _slab(img: Image, corner: Vector3, size: Vector3, colour: Color) -> void:
	var g := func(x: float, y: float, z: float) -> Vector2:
		return STACK_CENTRE + IsoMath.grid_to_screen(Vector2(x, y)) - Vector2(0, z)
	var x0 := corner.x
	var y0 := corner.y
	var x1 := corner.x + size.x
	var y1 := corner.y + size.y
	var z0 := corner.z
	var z1 := corner.z + size.z
	var faces := [
		[[g.call(x0, y1, z0), g.call(x1, y1, z0), g.call(x1, y1, z1), g.call(x0, y1, z1)], 1.0],
		[[g.call(x1, y0, z0), g.call(x1, y1, z0), g.call(x1, y1, z1), g.call(x1, y0, z1)], 0.85],
		[[g.call(x0, y0, z1), g.call(x1, y0, z1), g.call(x1, y1, z1), g.call(x0, y1, z1)], 1.12]]
	for face: Array in faces:
		var poly := PackedVector2Array(face[0])
		var light: float = face[1]
		var bounds := Rect2(poly[0], Vector2.ZERO)
		for q: Vector2 in poly:
			bounds = bounds.expand(q)
		for y: int in range(int(bounds.position.y) - 1, int(bounds.end.y) + 2):
			for x: int in range(int(bounds.position.x) - 1, int(bounds.end.x) + 2):
				if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), poly):
					var c := colour.darkened(0.06 * float((x / 5) % 2))
					_pixel(img, Vector2(x, y), Color(minf(c.r * light, 1.0), minf(c.g * light, 1.0), minf(c.b * light, 1.0)))
		for i: int in poly.size():
			_line(img, poly[i], poly[(i + 1) % poly.size()], colour.darkened(0.35), 1)


## A vertical trunk from [param foot] up [param height] px, [param width] px wide.
func _trunk(img: Image, foot: Vector2, height: float, width: float, colour: Color) -> void:
	for y: int in int(height):
		var w := width * (1.0 - 0.3 * y / height)
		for x: int in range(int(-w * 0.5), int(ceil(w * 0.5))):
			var col := colour.lightened(0.1) if x < -w * 0.15 else (colour.darkened(0.2) if x > w * 0.2 else colour)
			if _hash(x, y / 3, 81) > 0.85:
				col = col.darkened(0.15)
			_pixel(img, foot + Vector2(x, -y), col)


## A flat board or beam from [param a] to [param b] with a lit top edge.
func _beam(img: Image, a: Vector2, b: Vector2, thickness: float, colour: Color) -> void:
	var steps := maxi(1, int(a.distance_to(b)))
	for i: int in steps + 1:
		var p := a.lerp(b, float(i) / steps)
		for dy: int in int(ceil(thickness)) + 1:
			var col := colour.lightened(0.12) if dy == 0 else colour.darkened(0.12 * dy / maxf(thickness, 1.0))
			_pixel(img, p + Vector2(0, dy - thickness * 0.5), col)


## A small box seen from the front corner at [param foot].
func _box(img: Image, foot: Vector2, size: Vector2, height: float, colour: Color, material: String) -> void:
	var w := size.x * 0.5
	var d := size.y * 0.5
	var faces := [
		[PackedVector2Array([foot + Vector2(-w, -d), foot, foot - Vector2(0, height), foot + Vector2(-w, -d - height)]), 1.0],
		[PackedVector2Array([foot, foot + Vector2(w, -d), foot + Vector2(w, -d - height), foot - Vector2(0, height)]), 0.8],
		[PackedVector2Array([foot + Vector2(-w, -d - height), foot - Vector2(0, height), foot + Vector2(w, -d - height), foot + Vector2(0, -2 * d - height)]), 1.15]]
	for face: Array in faces:
		var poly: PackedVector2Array = face[0]
		var light: float = face[1]
		var bounds := Rect2(poly[0], Vector2.ZERO)
		for p: Vector2 in poly:
			bounds = bounds.expand(p)
		for y: int in range(int(bounds.position.y) - 1, int(bounds.end.y) + 2):
			for x: int in range(int(bounds.position.x) - 1, int(bounds.end.x) + 2):
				if not Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), poly):
					continue
				var col := colour
				match material:
					"stone":
						col = colour.darkened(0.1 * _hash(x / 3, y / 2, 71))
						if (x + y) % 9 == 0:
							col = col.darkened(0.15)
					"planks":
						col = colour.darkened(0.25) if y % 3 == 0 else colour
					"wicker":
						col = colour.darkened(0.22) if (x + y) % 3 == 0 else colour
					"brick":
						col = colour.darkened(0.3) if y % 3 == 0 or (x + (y / 3) * 3) % 6 == 0 else colour
				_pixel(img, Vector2(x, y), Color(minf(col.r * light, 1.0), minf(col.g * light, 1.0), minf(col.b * light, 1.0)))


func _ellipse(img: Image, centre: Vector2, radius: Vector2, colour: Color) -> void:
	if colour.a == 0.0:
		return
	for y: int in range(int(floor(centre.y - radius.y)) - 1, int(ceil(centre.y + radius.y)) + 1):
		for x: int in range(int(floor(centre.x - radius.x)) - 1, int(ceil(centre.x + radius.x)) + 1):
			var d := Vector2((x + 0.5 - centre.x) / maxf(radius.x, 0.5), (y + 0.5 - centre.y) / maxf(radius.y, 0.5))
			if d.length() <= 1.0:
				var shade := clampf(d.y * 0.15 + d.x * 0.05, -0.12, 0.18)
				_pixel(img, Vector2(x, y), colour.darkened(shade) if shade > 0.0 else colour.lightened(-shade))


func _line(img: Image, a: Vector2, b: Vector2, colour: Color, width: int) -> void:
	var steps := maxi(1, int(ceil(a.distance_to(b))))
	for s: int in steps + 1:
		var p := a.lerp(b, float(s) / steps)
		for dx: int in width:
			for dy: int in width:
				_pixel(img, p + Vector2(dx - width / 2, dy - width / 2), colour)


func _pixel(img: Image, p: Vector2, colour: Color) -> void:
	var q := Vector2i(p.floor())
	if Rect2i(Vector2i.ZERO, img.get_size()).has_point(q):
		img.set_pixelv(q, colour)


func _hash(x: int, y: int, salt: int) -> float:
	var n := (x * 374761393 + y * 668265263 + salt * 1442695041) & 0xffffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0xffffffff
	return float((n ^ (n >> 16)) & 0xffff) / 65535.0


## Selective outline (ART_SPEC §1): a dark version of the neighbouring colour around shapes.
func _outline(img: Image) -> void:
	var size := img.get_size()
	var edge: Dictionary = {}
	for y: int in size.y:
		for x: int in size.x:
			var c := img.get_pixel(x, y)
			if c.a == 0.0:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q := Vector2i(x, y) + d
				if Rect2i(Vector2i.ZERO, size).has_point(q) and img.get_pixelv(q).a == 0.0 and not edge.has(q):
					edge[q] = Color(c.r * 0.32, c.g * 0.27, c.b * 0.24, 1.0)
	for q: Vector2i in edge:
		img.set_pixelv(q, edge[q])


func _save(img: Image, relative: String) -> void:
	var path := OUT.path_join(relative)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var err := img.save_png(path)
	if err != OK:
		push_error("Cannot save %s (%s)" % [path, error_string(err)])
