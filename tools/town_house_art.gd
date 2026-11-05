extends RefCounted
## Row-house art for M4b-1.5 "Town" (ART_SPEC §7), used by tools/generate_art.gd.
##
## Town houses stand gable to the street (owner's sketch 2026-11-05) on a cobbled lot.
## One 2x2 lot holds several narrow houses (owner's decision 2026-11-05, inspired by
## illustrations of the owner's choice, own style): burghers 1-3 houses with fronts set
## back by different amounts and narrow gaps between lots, patricians 1-2 taller houses
## forming a closed row. Each house has its own height, gable (plain with timber, curved,
## stepped), plaster colour from a muted palette and roof (burghers dull red tile or slate,
## patricians slate). The corner house turns round the corner with a gable on each street
## and either a cut-off corner with an entrance bay under its own diagonal gable or (one
## look of the patricians) an oriel turret.
##
## Six pieces (single, end_a, middle, end_b, corner_a, corner_b) in three looks each,
## seen from the front (door to grid +x) and from the back (door to -x: the camera sees
## the plain back gables with back doors). Rows along grid x use the same art mirrored.
##
## Drawn with a depth buffer: every surface is sampled densely in 3D and each sample keeps
## its pixel only if it is nearer to the camera. Edges between surfaces get a dark line.
##
## Local frame of a piece: t across the lot from the back (0) to the street (2), s along
## the row (0..2), z up in pixels. Front art: grid = (t, s). Back art: grid = (2 - t, 2 - s).

const U_PX := 36.0
const STEP := 0.007
const STEP_Z := 0.5
const OVERHANG := 0.08
## Gap between burgher lots: each side of a joined lot is set in by this much.
const BURGHER_GAP := 0.07
const BACK_INSET := 0.04

const STYLE_PLAIN := 0
const STYLE_STEPPED := 1
const STYLE_CURVED := 2

const LIGHT_SW := 1.0
const LIGHT_SE := 0.8
const LIGHT_ROOF_SW := 1.06
const LIGHT_ROOF_SE := 0.86
const LIGHT_ROOF_BACK := 0.72
const C_BEAM := Color(0.3, 0.2, 0.13)
const C_GLASS := Color(0.16, 0.2, 0.26)
const C_BRICK := Color(0.56, 0.3, 0.23)
const C_SLATE := Color(0.3, 0.32, 0.37)
const C_TILE_DULL := Color(0.55, 0.32, 0.25)
const C_ARCADE := Color(0.15, 0.13, 0.12)
const C_STONE_TRIM := Color(0.82, 0.79, 0.72)
const C_COBBLE := Color(0.6, 0.57, 0.52)

## Muted plasters: sand, stone grey, ochre, sage, pale terracotta, oat, grey blue, buff.
const BURGHER_PALETTE: Array[Color] = [
	Color(0.84, 0.78, 0.64), Color(0.76, 0.75, 0.71), Color(0.8, 0.68, 0.48), Color(0.68, 0.72, 0.62),
	Color(0.8, 0.64, 0.54), Color(0.86, 0.82, 0.72), Color(0.66, 0.7, 0.74), Color(0.78, 0.72, 0.6),
]
const PATRICIAN_PALETTE: Array[Color] = [
	Color(0.84, 0.8, 0.7), Color(0.7, 0.72, 0.74), Color(0.8, 0.7, 0.54), Color(0.74, 0.6, 0.5),
	Color(0.66, 0.68, 0.6), Color(0.88, 0.84, 0.76), Color(0.7, 0.62, 0.58),
]

var art: Object

var _img: Image
var _pivot: Vector2i
var _depth: PackedFloat32Array
var _surf: PackedInt32Array
var _w: int
var _h: int
var _back: bool
var _next_surface: int = 1
var _patrician: bool
var _seed: int
var _shutters: Color


func _init(generator: Object) -> void:
	art = generator


## Draws one piece. [param piece]: single, end_a, middle, end_b, corner_a, corner_b (grid
## names: "a" is the end with the smaller grid y). [param look]: 0..2. Returns {"img", "pivot"}.
func render(level: int, piece: String, back: bool, look: int) -> Dictionary:
	_patrician = level >= 3
	_back = back
	_seed = ["single", "end_a", "middle", "end_b", "corner_a", "corner_b"].find(piece) * 7 + look * 31 + level * 101
	_shutters = Color(0.24, 0.3, 0.26) if _patrician else Color(0.3, 0.34, 0.4)
	var joined_low_y := piece in ["end_b", "middle", "corner_a"]
	var joined_high_y := piece in ["end_a", "middle", "corner_b"]
	var j0 := joined_high_y if back else joined_low_y
	var j1 := joined_low_y if back else joined_high_y

	var c: Dictionary = art._canvas(150.0 if _patrician else 118.0, 6)
	_img = c["img"]
	_pivot = c["pivot"]
	_w = _img.get_width()
	_h = _img.get_height()
	_depth = PackedFloat32Array()
	_depth.resize(_w * _h)
	_depth.fill(-1.0e9)
	_surf = PackedInt32Array()
	_surf.resize(_w * _h)
	_next_surface = 1

	_draw_cobbles()
	if piece.begins_with("corner"):
		_draw_corner(-1 if j1 else 1, look)
	else:
		for house: Dictionary in _lot_houses(j0, j1, look):
			_draw_house(house)
	_draw_edges()
	_draw_props(piece.begins_with("corner"))
	art._finish(_img)
	return {"img": _img, "pivot": _pivot}


# --- Lot layout ----------------------------------------------------------------------------

func _rand(k: int) -> float:
	return art._hash(_seed, k, 913)


func _palette(k: int) -> Color:
	var pal: Array[Color] = PATRICIAN_PALETTE if _patrician else BURGHER_PALETTE
	return pal[int(_rand(k) * 997.0) % pal.size()]


## The houses standing on the lot, side by side along s.
func _lot_houses(j0: bool, j1: bool, look: int) -> Array[Dictionary]:
	var count: int
	if _patrician:
		count = [1, 2, 2][look]
	else:
		count = [2, 3, 1][look]
	var gap := 0.0 if _patrician else BURGHER_GAP
	var lo := (gap if j0 else 0.12)
	var hi := 2.0 - (gap if j1 else 0.12)
	# Unequal widths: a narrow house beside a wider one.
	var weights: Array[float] = []
	var total := 0.0
	for i: int in count:
		var wgt := 1.0 + 0.45 * (_rand(10 + i) - 0.5)
		weights.append(wgt)
		total += wgt
	var houses: Array[Dictionary] = []
	var s := lo
	for i: int in count:
		var width := (hi - lo) * weights[i] / total
		var h := {}
		h["sa"] = s
		h["sb"] = s + width
		h["exposed_a"] = i > 0 or not j0 or gap > 0.0
		h["exposed_b"] = i < count - 1 or not j1 or gap > 0.0
		h["end_a"] = i == 0 and not j0
		h["end_b"] = i == count - 1 and not j1
		# Fronts not in one line: some houses stand a little back from the street.
		var setback: float = [0.1, 0.24, 0.16][(i + look) % 3] if count > 1 or not _patrician else 0.12
		if _patrician:
			setback = [0.1, 0.18][(i + look) % 2]
		h["tf"] = 2.0 - setback
		h["tb"] = BACK_INSET
		var tall := _rand(20 + i)
		if _patrician:
			h["floors"] = 3 if tall > 0.35 or count == 1 else 2
			h["wall"] = 76.0 if h["floors"] == 3 else 58.0
			h["arcade"] = h["floors"] == 2 or count == 1 or tall > 0.7
		else:
			h["floors"] = 2
			h["wall"] = 50.0 + 8.0 * tall
			h["arcade"] = false
		var half := width * 0.5
		h["rh"] = minf(half * (66.0 if _patrician else 58.0), 46.0 if _patrician else 36.0)
		h["style"] = [STYLE_PLAIN, STYLE_CURVED, STYLE_STEPPED][(i + look + (1 if _patrician else 0)) % 3]
		h["tint"] = _palette(30 + i)
		h["slate"] = _patrician or _rand(40 + i) > 0.72
		houses.append(h)
		s += width
	return houses


# --- Projection ----------------------------------------------------------------------------

func _grid(t: float, s: float) -> Vector2:
	return Vector2(2.0 - t, 2.0 - s) if _back else Vector2(t, s)


func _grid_dir(d: Vector2) -> Vector2:
	return -d if _back else d


func _splat(t: float, s: float, z: float, colour: Color, surface: int, bias: float = 0.0) -> void:
	var g := _grid(t, s)
	var x := int(floor(float(_pivot.x) + (g.x - g.y) * 32.0))
	var y := int(floor(float(_pivot.y) + (g.x + g.y - 4.0) * 16.0 - z))
	if x < 0 or y < 0 or x >= _w or y >= _h:
		return
	var i := y * _w + x
	var d := (g.x + g.y) * 16.0 + z * 0.999 + bias
	if d > _depth[i]:
		_depth[i] = d
		_surf[i] = surface
		_img.set_pixel(x, y, colour)


func _new_surface() -> int:
	_next_surface += 1
	return _next_surface


func _wall_light(n: Vector2) -> float:
	var g := _grid_dir(n)
	if g.x > 0.5 and g.y > 0.5:
		return 0.9
	if g.y > 0.5:
		return LIGHT_SW
	if g.x > 0.5:
		return LIGHT_SE
	var gd := g.normalized()
	if gd.x + gd.y > 0.9:
		return 0.92
	return 0.62


func _roof_light(n: Vector2) -> float:
	var g := _grid_dir(n)
	if g.y > 0.5:
		return LIGHT_ROOF_SW
	if g.x > 0.5:
		return LIGHT_ROOF_SE
	if g.x + g.y > 0.5:
		return 0.96
	return LIGHT_ROOF_BACK


func _faces_camera(n: Vector2) -> bool:
	var g := _grid_dir(n)
	return g.x + g.y > 0.1


func _roof_colour(slate: bool, along: float, v: float, length: float, light: float) -> Color:
	var col: Color = art._roof_material("slate" if slate else "tile", along * U_PX, v, length)
	if not slate:
		# Dull, weathered tiles instead of bright red.
		col = col.lerp(C_TILE_DULL * (col.get_luminance() / C_TILE_DULL.get_luminance()), 0.55)
		col = col.lerp(Color(col.get_luminance(), col.get_luminance(), col.get_luminance()), 0.2)
	else:
		col = col.lerp(C_SLATE * (col.get_luminance() / C_SLATE.get_luminance()), 0.5)
	col.a = 1.0
	return art._lit(col, light)


# --- Ground --------------------------------------------------------------------------------

## The whole lot is paved: cobbles show in front of set-back houses and between lots.
func _draw_cobbles() -> void:
	var surface := _new_surface()
	var t := 0.0
	while t <= 2.0:
		var s := 0.0
		while s <= 2.0:
			var cu := int(t * 14.0 + (0.5 if int(s * 14.0) % 2 == 1 else 0.0))
			var cv := int(s * 14.0)
			var fu := fposmod(t * 14.0 + (0.5 if cv % 2 == 1 else 0.0), 1.0)
			var fv := fposmod(s * 14.0, 1.0)
			var col := C_COBBLE.darkened(0.14 * art._hash(cu, cv, 333))
			if fu < 0.14 or fv < 0.14:
				col = C_COBBLE.darkened(0.35)
			_splat(t, s, 0.0, art._lit(col, 1.0), surface, -2.0)
			s += STEP
		t += STEP


# --- One house of a lot --------------------------------------------------------------------

func _gable_rise(p: float, style: int, rh: float) -> float:
	match style:
		STYLE_STEPPED:
			return 4.0 + (rh + 6.0) * ceilf(p * 4.0 - 0.001) / 4.0
		STYLE_CURVED:
			if p < 0.45:
				return rh * (0.15 + 0.4 * sqrt(p / 0.45)) + 3.0
			if p < 0.6:
				return rh * 0.55 + 3.0 + (rh * 0.3) * ((p - 0.45) / 0.15)
			return rh * 0.85 + 3.0 + rh * 0.32 * (p - 0.6) / 0.4
	return rh * p


func _draw_house(h: Dictionary) -> void:
	var sa: float = h["sa"]
	var sb: float = h["sb"]
	var tf: float = h["tf"]
	var tb: float = h["tb"]
	var wall: float = h["wall"]
	var rh: float = h["rh"]
	var sc := (sa + sb) * 0.5
	var hs := (sb - sa) * 0.5
	var style: int = h["style"]
	var slate: bool = h["slate"]
	# Roof: ridge from the street to the back.
	var faces := {Vector2(0, 1): _new_surface(), Vector2(0, -1): _new_surface()}
	var ov_a := OVERHANG if h["exposed_a"] else 0.0
	var ov_b := OVERHANG if h["exposed_b"] else 0.0
	var t_hi := tf + (OVERHANG if style == STYLE_PLAIN else 0.0)
	var t := 0.0
	while t <= t_hi:
		var s := sa - ov_a
		while s <= sb + ov_b:
			var z := wall + rh * (1.0 - absf(s - sc) / hs)
			var d := Vector2(0, 1) if s > sc else Vector2(0, -1)
			var v := (z - (wall - 8.0)) * 1.15
			_splat(t, s, z, _roof_colour(slate, t, v, (rh + 8.0) * 1.15, _roof_light(d)), faces[d])
			s += STEP
		t += STEP
	# Walls.
	var front_top := func(s: float) -> float:
		var p := clampf(1.0 - absf(s - sc) / hs, 0.0, 1.0)
		return wall + _gable_rise(p, style, rh)
	var back_top := func(s: float) -> float:
		return wall + rh * clampf(1.0 - absf(s - sc) / hs, 0.0, 1.0)
	var flat := func(_x: float) -> float:
		return wall
	_wall(h, Vector2(tf, sa), Vector2(tf, sb), Vector2(1, 0), "front", front_top)
	_wall(h, Vector2(tb, sa), Vector2(tb, sb), Vector2(-1, 0), "back", back_top)
	_wall(h, Vector2(tb, sa), Vector2(tf, sa), Vector2(0, -1), "side", flat)
	_wall(h, Vector2(tb, sb), Vector2(tf, sb), Vector2(0, 1), "side", flat)
	_chimney(Vector2(0.5 + 0.3 * _rand(int(sa * 100.0)), sc + hs * 0.35), wall + rh * 0.65 - 2.0, wall + rh + 8.0)


## A wall from [param a] to [param b] (local) with outward normal [param n]; its top at
## each point along it comes from [param top] (called with s for walls across the lot,
## with t for walls along it).
func _wall(h: Dictionary, a: Vector2, b: Vector2, n: Vector2, kind: String, top: Callable) -> void:
	var seen := _faces_camera(n)
	if not seen and kind != "front":
		return
	var surface := _new_surface()
	var light := _wall_light(n) if seen else 0.62
	var tiles := a.distance_to(b)
	if tiles < 0.01:
		return
	var length := tiles * U_PX
	var wall: float = h["wall"]
	var holes := _holes(h, kind, tiles)
	var material := "patrician" if _patrician else "plaster_stone"
	var k := 0.0
	while k <= tiles + 0.0001:
		var p := a.lerp(b, k / tiles)
		var u := k * U_PX
		var zt: float = top.call(p.y if absf(a.x - b.x) < 0.001 else p.x)
		var z := 0.0 if seen else wall
		while z <= zt:
			var col: Color
			if z > wall + 0.5:
				col = _gable_px(h, kind, u, z, length, zt)
			else:
				col = _wall_px(h, material, kind, u, z, length, holes)
			if col.a > 0.0:
				_splat(p.x, p.y, z, art._lit(col, light), surface)
			z += STEP_Z
		k += STEP


func _holes(h: Dictionary, kind: String, tiles: float) -> Array:
	var holes: Array = []
	var length := tiles * U_PX
	var wall: float = h["wall"]
	var floors: int = h["floors"]
	var door_u := -100.0
	if kind == "front" or kind == "back":
		door_u = length * (0.5 if tiles < 1.2 else 0.68)
	var ground := wall * 0.34
	var arcade: bool = h["arcade"] and kind == "front"
	if arcade:
		var n := maxi(1, int(round(tiles / 0.58)))
		for i: int in n:
			var mid := (i + 0.5) * length / n
			holes.append([mid - 7.0, 0.0, mid + 7.0, ground - 2.0, "arcade"])
	elif kind == "front":
		holes.append([door_u - 6.0, 3.0, door_u + 6.0, 27.0, "door"])
	elif kind == "back":
		holes.append([door_u - 5.0, 3.0, door_u + 5.0, 23.0, "door"])
	var spacing := 0.42 if kind == "front" else 0.8
	var columns := maxi(1, int(round(tiles / spacing)))
	for i: int in columns:
		var mid := (i + 0.5) * length / columns
		for f: int in floors:
			var v0: float
			var wh := 12.0
			if floors == 3:
				v0 = [wall * 0.12, wall * 0.43, wall * 0.71][f]
				wh = [10.0, 15.0, 12.0][f]
			else:
				v0 = wall * 0.14 if f == 0 else wall * 0.6
				if _patrician:
					wh = 14.0
			if f == 0 and arcade:
				continue
			if absf(mid - door_u) < 11.0 and v0 < 30.0:
				continue
			holes.append([mid - 4.0, v0, mid + 4.0, v0 + wh, "window"])
	return holes


func _wall_px(h: Dictionary, material: String, kind: String, u: float, v: float, length: float, holes: Array) -> Color:
	for hole: Array in holes:
		if u >= hole[0] and u < hole[2] and v >= hole[1] and v < hole[3]:
			var hu: float = u - hole[0]
			var hv: float = v - hole[1]
			if hole[4] == "arcade":
				var ac := _arcade_px(hu, hv, hole[2] - hole[0], hole[3] - hole[1])
				if ac.a > 0.0:
					return ac
				continue
			var c: Color = art._opening(hu, hv, hole[2] - hole[0], hole[3] - hole[1], hole[4], _shutters)
			if c.a > 0.0:
				return c
	var tint: Color = h["tint"]
	var col: Color = art._wall_material(material, u, v, float(h["wall"]), length, tint)
	var plain := kind != "front"
	for hole: Array in holes:
		if hole[4] != "window":
			continue
		if not plain and not _patrician and v >= hole[1] and v < hole[3] \
				and (u >= hole[0] - 3.0 and u < hole[0] or u >= hole[2] and u < hole[2] + 3.0):
			return _shutters.darkened(0.15 * float(int(v) % 3 == 0))
		if not plain and v >= hole[3] and v < hole[3] + 2.0 and u >= hole[0] - 1.0 and u < hole[2] + 1.0:
			return C_STONE_TRIM.darkened(0.08)
	return col


func _arcade_px(hu: float, hv: float, hw: float, hh: float) -> Color:
	var r := hw * 0.5
	var spring := hh - r
	if hv > spring:
		var d := Vector2(hu - r, hv - spring).length()
		if d > r:
			return Color(0, 0, 0, 0)
		if d > r - 1.5:
			return Color(0.8, 0.77, 0.7)
	if hu < 1.0 or hu >= hw - 1.0:
		return Color(0.66, 0.63, 0.57)
	if hv < 1.0:
		return Color(0.48, 0.45, 0.4)
	return C_ARCADE.lightened(0.08 * (1.0 - hv / hh))


func _gable_px(h: Dictionary, kind: String, u: float, v: float, length: float, top: float) -> Color:
	var mid := length * 0.5
	var wall: float = h["wall"]
	var g := v - wall
	var front := kind == "front"
	var style: int = h["style"] if front else STYLE_PLAIN
	var tint: Color = h["tint"]
	if front:
		var two := length > 30.0
		for wu: float in ([mid - 8.0, mid + 2.0] if two else [mid - 3.0]):
			if u >= wu and u < wu + 6.0 and g >= 6.0 and g < 15.0:
				return art._opening(u - wu, g - 6.0, 6.0, 9.0, "window", _shutters)
		if u >= mid - 2.5 and u < mid + 2.5 and g >= 21.0 and g < 27.0 and top - v > 6.0:
			return art._opening(u - mid + 2.5, g - 21.0, 5.0, 6.0, "window", _shutters)
	elif Vector2(u - mid, g - 9.0).length() < 2.3:
		return C_GLASS
	if top - v < 2.0:
		return C_BEAM if style == STYLE_PLAIN and not _patrician else C_STONE_TRIM
	if style == STYLE_STEPPED and front and (_patrician or int(_rand(int(mid)) * 2.0) == 0):
		if _patrician and fposmod(u, 11.0) > 3.5 and fposmod(u, 11.0) < 8.5 and g > 16.0 and top - v > 5.0:
			return C_STONE_TRIM.darkened(0.06 * float(int(g) % 4 == 0))
		return _brick_px(u, v)
	if style == STYLE_PLAIN and not _patrician:
		if absf(g - 16.0) < 1.0 or fposmod(u, 11.0) < 1.5:
			return C_BEAM
	if front and absf(g - 16.0) < 0.8:
		return Color(tint.r * 0.7, tint.g * 0.7, tint.b * 0.7)
	return art._plaster(int(u), int(v), Color(tint.r * 0.96, tint.g * 0.96, tint.b * 0.96))


func _brick_px(u: float, v: float) -> Color:
	var iu := int(u)
	var iv := int(v)
	var row := iv / 3
	if iv % 3 == 0 or (iu + (row % 2) * 3) % 6 == 0:
		return Color(0.72, 0.67, 0.6)
	return C_BRICK.darkened(0.12 * art._hash((iu + (row % 2) * 3) / 6, row, 77))


func _chimney(at: Vector2, base: float, top: float) -> void:
	var hw := 0.07
	for n: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		if not _faces_camera(n):
			continue
		var surface := _new_surface()
		var light := _wall_light(n)
		var k := -hw
		while k <= hw:
			var t := at.x + (n.x * hw if n.x != 0.0 else k)
			var s := at.y + (n.y * hw if n.y != 0.0 else k)
			var z := base
			while z <= top:
				var col := _brick_px(k * U_PX + 20.0, z)
				if z > top - 2.5:
					col = Color(0.5, 0.46, 0.43)
				_splat(t, s, z, art._lit(col, light), surface)
				z += STEP_Z
			k += STEP


# --- Corner --------------------------------------------------------------------------------

## The corner house: a wing along the row (gable to the main street) and a wing to the side
## street (gable there), roofs meeting in a cross; either the corner is cut off with an
## entrance bay under its own diagonal gable, or (patricians, look 1) an oriel turret.
func _draw_corner(o: int, look: int) -> void:
	var wall := 76.0 if _patrician else 54.0
	var rh := 44.0 if _patrician else 32.0
	var floors := 3 if _patrician else 2
	var tf := 1.86
	var s_open := 1.86 if o > 0 else 0.14
	var s_joined := 0.0 if o > 0 else 2.0
	var sc := (s_open + s_joined) * 0.5
	var hs := absf(s_open - s_joined) * 0.5
	var tc := tf * 0.5
	var ht := tf * 0.5
	var turret := _patrician and look == 1
	var chamfer := 0.0 if turret else 0.42
	var bay_style := STYLE_CURVED if look != 2 else STYLE_STEPPED
	var slate := _patrician or look == 2
	var tint := _palette(50)
	var tint_side := _palette(51)
	var h_main := {"wall": wall, "floors": floors, "tint": tint, "arcade": _patrician, "style": STYLE_STEPPED if _patrician else STYLE_PLAIN, "rh": rh}
	var h_side := h_main.duplicate()
	h_side["tint"] = tint_side
	h_side["style"] = STYLE_CURVED if look == 0 else STYLE_STEPPED
	# Diagonal cut: the points of the cut-off corner and the bay axis.
	var ca := Vector2(tf, s_open - o * chamfer)
	var cb := Vector2(tf - chamfer, s_open)
	var mid := (ca + cb) * 0.5
	var inward := Vector2(-1, -o).normalized()
	var across := Vector2(1, -o).normalized()
	var cut := func(t: float, s: float) -> bool:
		return chamfer > 0.0 and (Vector2(t, s) - mid).dot(-inward) > 0.0
	# Roofs: main (ridge along t over the row wing), side wing (ridge along s), cross.
	var main := {Vector2(0, 1): _new_surface(), Vector2(0, -1): _new_surface()}
	var wing := {Vector2(1, 0): _new_surface(), Vector2(-1, 0): _new_surface()}
	var t := 0.0
	while t <= tf + OVERHANG:
		var s := minf(s_joined, s_open) - (OVERHANG if o < 0 else 0.0)
		var s_end := maxf(s_joined, s_open) + (OVERHANG if o > 0 else 0.0)
		while s <= s_end:
			if cut.call(t, s):
				s += STEP
				continue
			var zm := wall + rh * (1.0 - absf(s - sc) / hs)
			var zw := wall + rh * (1.0 - absf(t - tc) / ht)
			var in_side_half := (s - sc) * o > 0.0
			var use_wing := in_side_half and zw > zm
			if t > tf + 0.001 and not use_wing:
				s += STEP
				continue
			var z := zw if use_wing else zm
			var d: Vector2
			if use_wing:
				d = Vector2(1, 0) if t > tc else Vector2(-1, 0)
			else:
				d = Vector2(0, 1) if s > sc else Vector2(0, -1)
			var v := (z - (wall - 8.0)) * 1.15
			_splat(t, s, z, _roof_colour(slate, s if use_wing else t, v, (rh + 8.0) * 1.15, _roof_light(d)),
					wing[d] if use_wing else main[d])
			s += STEP
		t += STEP
	# Front (main street) wall with its gable, side-street wall with the wing's gable.
	var front_top := func(s: float) -> float:
		var p := clampf(1.0 - absf(s - sc) / hs, 0.0, 1.0)
		return wall + _gable_rise(p, h_main["style"], rh)
	var side_top := func(tt: float) -> float:
		var p := clampf(1.0 - absf(tt - tc) / ht, 0.0, 1.0)
		return wall + _gable_rise(p, h_side["style"], rh)
	_wall(h_main, Vector2(tf, s_joined), ca, Vector2(1, 0), "front", front_top)
	_wall(h_side, Vector2(0.0, s_open), cb, Vector2(0, o), "front", side_top)
	_chimney(Vector2(0.45, sc - o * hs * 0.4), wall + rh * 0.6, wall + rh + 8.0)
	if turret:
		_turret(Vector2(tf - 0.04, s_open - 0.04 * o), wall)
	elif chamfer > 0.0:
		_bay(ca, cb, inward, across, wall, rh, bay_style, slate)


## Entrance bay on the cut-off corner: a tall diagonal wall with a portal and its own
## gable, and a roof running from it into the corner.
func _bay(ca: Vector2, cb: Vector2, inward: Vector2, across: Vector2, wall: float, rh: float, style: int,
		slate: bool) -> void:
	var mid := (ca + cb) * 0.5
	var half := ca.distance_to(cb) * 0.5
	var bw := wall + 6.0
	var brh := rh * 0.8
	var roof := {Vector2(1, 0): _new_surface(), Vector2(-1, 0): _new_surface()}
	var a := 0.0
	while a <= 1.1:
		var c := -half - OVERHANG * 0.5
		while c <= half + OVERHANG * 0.5:
			var p := mid + inward * a + across * c
			var z := bw + brh * (1.0 - absf(c) / half)
			var d := Vector2(1, 0) if c > 0.0 else Vector2(-1, 0)
			var light := _roof_light(Vector2(1, 1)) * (1.04 if c < 0.0 else 0.92)
			var col := _roof_colour(slate, c + 2.0, (z - (bw - 6.0)) * 1.15, (brh + 6.0) * 1.15, light)
			_splat(p.x, p.y, z, col, roof[d])
			c += STEP
		a += STEP
	var h := {"wall": bw, "floors": 3 if _patrician else 2, "tint": _palette(52), "arcade": false,
			"style": style, "rh": brh}
	# The diagonal wall is sampled along its own length; the gable follows the bay roof.
	var surface := _new_surface()
	var n := -inward
	var light := _wall_light(n)
	var length := 2.0 * half * U_PX
	var holes := _bay_holes(h, length)
	var k := 0.0
	while k <= 2.0 * half:
		var p := ca.lerp(cb, k / (2.0 * half))
		var c := k - half
		var pz := clampf(1.0 - absf(c) / half, 0.0, 1.0)
		var zt := bw + _gable_rise(pz, style, brh)
		var u := k * U_PX
		var z := 0.0
		while z <= zt:
			var col: Color
			if z > bw + 0.5:
				col = _gable_px(h, "front", u, z, length, zt)
			else:
				col = _wall_px(h, "patrician" if _patrician else "plaster_stone", "front", u, z, length, holes)
			if col.a > 0.0:
				_splat(p.x, p.y, z, art._lit(col, light), surface)
			z += STEP_Z
		k += STEP


func _bay_holes(h: Dictionary, length: float) -> Array:
	var wall: float = h["wall"]
	var mid := length * 0.5
	# A round-headed portal and tall windows above it.
	var holes: Array = [[mid - 8.0, 0.0, mid + 8.0, 30.0, "arcade"]]
	var floors: int = h["floors"]
	for f: int in range(1, floors):
		var v0: float = wall * (0.43 if floors == 3 and f == 1 else (0.71 if floors == 3 else 0.6))
		holes.append([mid - 4.5, v0, mid + 4.5, v0 + 14.0, "window"])
	return holes


## Patrician corner: a round oriel on the outer corner, with a pointed slate roof.
func _turret(centre: Vector2, wall: float) -> void:
	var r := 0.24
	var z0 := wall * 0.4
	var z1 := wall + 4.0
	var apex := z1 + 34.0
	var tint := _palette(53)
	var surface := _new_surface()
	var a := 0.0
	while a < TAU:
		var n := Vector2(cos(a), sin(a))
		var light := 0.75 + 0.25 * maxf(0.0, _grid_dir(n).y) + 0.05 * _grid_dir(n).x
		var p := centre + n * r
		var z := z0
		while z <= z1:
			var u := a * r * U_PX
			var col: Color = art._plaster(int(u), int(z), tint)
			var g := _grid_dir(n)
			for v0: float in [wall * 0.48, wall * 0.74]:
				if z >= v0 and z < v0 + 12.0 and fposmod(u, 14.0) < 7.0 and g.x + g.y > 0.6:
					col = art._opening(fposmod(u, 14.0), z - v0, 7.0, 12.0, "window", _shutters)
			_splat(p.x, p.y, z, art._lit(col, light), surface)
			z += STEP_Z
		z = z0 - 12.0
		while z < z0:
			var q := centre + n * (r * (z - (z0 - 12.0)) / 12.0)
			_splat(q.x, q.y, z, art._lit(C_STONE_TRIM, light * 0.9), surface)
			z += STEP_Z
		a += 0.012
	var roof := _new_surface()
	var z := z1 - 2.0
	while z <= apex:
		var rr := (r + 0.05) * (1.0 - (z - z1 + 2.0) / (apex - z1 + 2.0))
		a = 0.0
		while a < TAU:
			var n := Vector2(cos(a), sin(a))
			var light := 0.7 + 0.35 * maxf(0.0, _grid_dir(n).y) + 0.1 * _grid_dir(n).x
			var col := C_SLATE.darkened(0.12 * float(int(a * 20.0) % 2)) if int(z) % 4 != 0 else C_SLATE.darkened(0.25)
			_splat(centre.x + n.x * rr, centre.y + n.y * rr, z, art._lit(col, light), roof)
			a += 0.02 / maxf(rr, 0.05)
		z += STEP_Z * 0.6


# --- Edges and props -----------------------------------------------------------------------

func _draw_edges() -> void:
	var dark: Array[int] = []
	for y: int in _h:
		for x: int in _w:
			var i := y * _w + x
			if _surf[i] == 0:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
				var q := Vector2i(x, y) + d
				if q.x < 0 or q.y < 0 or q.x >= _w or q.y >= _h:
					continue
				var j := q.y * _w + q.x
				if _surf[j] != 0 and _surf[j] != _surf[i] and _depth[j] > _depth[i] + 0.5:
					dark.append(i)
					break
	for i: int in dark:
		var c := _img.get_pixel(i % _w, i / _w)
		_img.set_pixel(i % _w, i / _w, c.darkened(0.45))


func _draw_props(corner: bool) -> void:
	var props: Array = []
	if _back:
		if not corner:
			props = [["barrel", Vector2(1.98, 0.3)]]
	elif _patrician:
		if not corner:
			props = [["lantern", Vector2(1.94, 0.3)]]
	else:
		props = [["flowers", Vector2(1.95, 0.55)]]
	for prop: Array in props:
		var p: Vector2 = prop[1]
		art._prop(_img, Vector2(_pivot) + IsoMath.grid_to_screen(p - Vector2(2, 2)), String(prop[0]))
