extends RefCounted
## Row-house art for M4b-1.5 "Town" (ART_SPEC §7), used by tools/generate_art.gd.
##
## Town houses stand gable to the street (owner's sketch 2026-11-05): the ridge runs from
## the street to the back, every house shows the street a tall gable of its own, and the
## roofs of neighbours meet in valleys. Burgher houses (level 2: plaster, timber or simple
## gables) and patrician townhouses (level 3: ashlar ground floor with arcades, three
## storeys, stepped brick or curved gables, an oriel turret on the corner).
##
## Six row pieces: single, end_a, middle, end_b, corner_a, corner_b, each in three gable
## styles, seen from the front (door to grid +x) and from the back (door to -x: the camera
## sees the plain back gable with a back door). Rows along grid x use the same art mirrored.
## Own style; the owner's illustrations were only an inspiration.
##
## Drawn with a depth buffer: every surface (walls with gables, roof as a height field,
## chimney, turret) is sampled densely in 3D and each sample keeps its pixel only if it is
## nearer to the camera. Edges between surfaces get a 1 px dark line.
##
## Local frame of a piece: t across the house from the back (0) to the street (2), s along
## the row (0..2), z up in pixels. Front art: grid = (t, s). Back art: grid = (2 - t, 2 - s).

## Pixels of material per tile along a wall or roof.
const U_PX := 36.0
## Insets of the walls from the footprint edge, in tiles.
const FRONT_INSET := 0.16
const BACK_INSET := 0.04
const END_INSET := 0.14
## Roof overhang at an eave or over a plain gable, in tiles.
const OVERHANG := 0.1
## Sampling steps: along surfaces in tiles, up walls in pixels.
const STEP := 0.007
const STEP_Z := 0.5
## Gable styles (three looks per piece, picked by position on the map).
const STYLE_PLAIN := 0
const STYLE_STEPPED := 1
const STYLE_CURVED := 2

## Same light and colours as generate_art.gd (ART_SPEC §1).
const LIGHT_SW := 1.0
const LIGHT_SE := 0.8
const LIGHT_ROOF_SW := 1.06
const LIGHT_ROOF_SE := 0.86
const LIGHT_ROOF_BACK := 0.72
const C_BEAM := Color(0.33, 0.21, 0.13)
const C_PLASTER := Color(0.9, 0.85, 0.73)
const C_GLASS := Color(0.16, 0.2, 0.26)
const C_BRICK := Color(0.63, 0.3, 0.22)
const C_SLATE := Color(0.33, 0.37, 0.45)
const C_ARCADE := Color(0.16, 0.13, 0.12)
const C_STONE_TRIM := Color(0.88, 0.85, 0.78)

var art: Object

var _img: Image
var _pivot: Vector2i
var _depth: PackedFloat32Array
var _surf: PackedInt32Array
var _w: int
var _h: int
var _back: bool
var _next_surface: int = 1

# The piece being drawn.
var _wall_h: float
var _roof_h: float
var _floors: int
var _patrician: bool
var _style: int
var _tint: Color
var _shutters: Color
var _tb: float
var _tf: float
var _s0: float
var _s1: float
var _j0: bool
var _j1: bool
var _corner: bool
## Corner: which end of the row is open (the side street): 1 = s1, -1 = s0.
var _open_side: int = 0
## Main roof: ridge along t at _sc, half width _hs (to the eaves on the sides).
var _sc: float
var _hs: float
## Corner wing roof: ridge along s at _tc, half width _ht.
var _tc: float
var _ht: float


func _init(generator: Object) -> void:
	art = generator


## Draws one piece. [param piece]: single, end_a, middle, end_b, corner_a, corner_b (grid
## names: "a" is the end with the smaller grid y). [param style]: STYLE_*. Returns
## {"img", "pivot"}.
func render(level: int, piece: String, back: bool, tint: Color, style: int) -> Dictionary:
	_patrician = level >= 3
	_back = back
	_style = style
	_wall_h = 76.0 if _patrician else 54.0
	_roof_h = 46.0 if _patrician else 34.0
	_floors = 3 if _patrician else 2
	_tint = tint
	_shutters = Color(0.2, 0.32, 0.25) if _patrician else Color(0.3, 0.38, 0.5)
	var joined_low_y := piece in ["end_b", "middle", "corner_a"]
	var joined_high_y := piece in ["end_a", "middle", "corner_b"]
	_corner = piece.begins_with("corner")
	_j0 = joined_high_y if back else joined_low_y
	_j1 = joined_low_y if back else joined_high_y
	_open_side = 0
	if _corner:
		_open_side = -1 if _j1 else 1
	_tb = 0.0 if _corner else BACK_INSET
	_tf = 2.0 - FRONT_INSET
	_s0 = 0.0 if _j0 else (FRONT_INSET if _corner else END_INSET)
	_s1 = 2.0 if _j1 else 2.0 - (FRONT_INSET if _corner else END_INSET)
	_sc = (_s0 + _s1) * 0.5
	_hs = (_s1 - _s0) * 0.5
	_tc = (_tb + _tf) * 0.5
	_ht = (_tf - _tb) * 0.5

	var c: Dictionary = art._canvas(_wall_h + _roof_h + 40.0, 6)
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

	_draw_roof()
	_draw_walls()
	_draw_chimney()
	if _patrician and _corner and not back:
		_draw_turret()
	_draw_edges()
	_draw_props()
	art._finish(_img)
	return {"img": _img, "pivot": _pivot}


# --- Projection ----------------------------------------------------------------------------

func _grid(t: float, s: float) -> Vector2:
	return Vector2(2.0 - t, 2.0 - s) if _back else Vector2(t, s)


## Grid direction of a local direction (dt, ds).
func _grid_dir(d: Vector2) -> Vector2:
	return -d if _back else d


func _splat(t: float, s: float, z: float, colour: Color, surface: int) -> void:
	var g := _grid(t, s)
	var x := int(floor(float(_pivot.x) + (g.x - g.y) * 32.0))
	var y := int(floor(float(_pivot.y) + (g.x + g.y - 4.0) * 16.0 - z))
	if x < 0 or y < 0 or x >= _w or y >= _h:
		return
	var i := y * _w + x
	var d := (g.x + g.y) * 16.0 + z * 0.999
	if d > _depth[i]:
		_depth[i] = d
		_surf[i] = surface
		_img.set_pixel(x, y, colour)


func _new_surface() -> int:
	_next_surface += 1
	return _next_surface


## Light of a vertical face whose outward local normal is [param n].
func _wall_light(n: Vector2) -> float:
	var g := _grid_dir(n)
	if g.y > 0.5:
		return LIGHT_SW
	if g.x > 0.5:
		return LIGHT_SE
	return 0.62


func _roof_light(n: Vector2) -> float:
	var g := _grid_dir(n)
	if g.y > 0.5:
		return LIGHT_ROOF_SW
	if g.x > 0.5:
		return LIGHT_ROOF_SE
	return LIGHT_ROOF_BACK


func _faces_camera(n: Vector2) -> bool:
	var g := _grid_dir(n)
	return g.x + g.y > 0.1


# --- Roof ----------------------------------------------------------------------------------

## Main roof (ridge from the street to the back) at s.
func _main_z(s: float) -> float:
	return _wall_h + _roof_h * (1.0 - absf(s - _sc) / _hs)


## Corner wing (ridge along the row, gable to the side street) at t.
func _wing_z(t: float) -> float:
	return _wall_h + _roof_h * (1.0 - absf(t - _tc) / _ht)


## Whether s lies in the corner wing, i.e. on the side-street half of the house.
func _in_wing(s: float) -> bool:
	return _corner and ((s >= _sc) if _open_side > 0 else (s <= _sc))


## The roof over a plain front gable overhangs it; a decorative gable rises above the roof.
func _front_overhang() -> float:
	return OVERHANG if _style == STYLE_PLAIN else 0.0


func _draw_roof() -> void:
	var ov0 := 0.0 if _j0 else OVERHANG
	var ov1 := 0.0 if _j1 else OVERHANG
	var t_hi := _tf + _front_overhang()
	var main := {Vector2(0, 1): _new_surface(), Vector2(0, -1): _new_surface()}
	var wing := {Vector2(1, 0): _new_surface(), Vector2(-1, 0): _new_surface()}
	var t := 0.0
	while t <= _tf + OVERHANG + 0.0001:
		var s := _s0 - ov0
		while s <= _s1 + ov1 + 0.0001:
			var z := _main_z(s)
			var d := Vector2(0, 1) if s > _sc else Vector2(0, -1)
			var surface: int = main[d]
			var along := t
			var draw := t <= t_hi
			if _in_wing(s):
				var zw := _wing_z(t)
				if zw > z or not draw:
					z = zw
					d = Vector2(1, 0) if t > _tc else Vector2(-1, 0)
					surface = wing[d]
					along = s
					draw = true
			if draw:
				var v := (z - (_wall_h - 8.0)) * 1.15
				var col: Color = art._roof_material("tile", along * U_PX, v, (_roof_h + 8.0) * 1.15)
				_splat(t, s, z, art._lit(col, _roof_light(d)), surface)
			s += STEP
		t += STEP


# --- Gable profiles ------------------------------------------------------------------------

## Height above the eaves of a gable of [param style] at p (0 at the sides, 1 at the ridge).
func _gable_rise(p: float, style: int) -> float:
	match style:
		STYLE_STEPPED:
			return 4.0 + (_roof_h + 6.0) * ceilf(p * 4.0 - 0.001) / 4.0
		STYLE_CURVED:
			# Scrolls on the shoulders, a tall middle with a small pediment on top.
			if p < 0.45:
				return _roof_h * (0.15 + 0.4 * sqrt(p / 0.45)) + 3.0
			if p < 0.6:
				return _roof_h * 0.55 + 3.0 + (_roof_h * 0.3) * ((p - 0.45) / 0.15)
			return _roof_h * 0.85 + 3.0 + _roof_h * 0.32 * (p - 0.6) / 0.4
	return _roof_h * p


## Top of the front gable at s.
func _front_top(s: float) -> float:
	var p := clampf(1.0 - absf(s - _sc) / _hs, 0.0, 1.0)
	return _wall_h + _gable_rise(p, _style)


# --- Walls ---------------------------------------------------------------------------------

func _draw_walls() -> void:
	# Street front with its gable (drawn even facing away: a tall gable shows over the roof).
	_wall(Vector2(_tf, _s0), Vector2(_tf, _s1), Vector2(1, 0), "front")
	if not _corner:
		_wall(Vector2(_tb, _s0), Vector2(_tb, _s1), Vector2(-1, 0), "back")
		# Free ends of a row: side walls under the eaves.
		if not _j0:
			_wall(Vector2(_tb, _s0), Vector2(_tf, _s0), Vector2(0, -1), "side")
		if not _j1:
			_wall(Vector2(_tb, _s1), Vector2(_tf, _s1), Vector2(0, 1), "side")
	else:
		var s_open := _s1 if _open_side > 0 else _s0
		_wall(Vector2(_tb, s_open), Vector2(_tf, s_open), Vector2(0, _open_side), "corner_side")


## A vertical wall from local [param a] to [param b] with outward normal [param n].
func _wall(a: Vector2, b: Vector2, n: Vector2, kind: String) -> void:
	var seen := _faces_camera(n)
	if not seen and kind != "front":
		return
	var surface := _new_surface()
	var light := _wall_light(n) if seen else 0.62
	var tiles := a.distance_to(b)
	var length := tiles * U_PX
	var holes := _holes(kind, tiles, a, b)
	var material := "patrician" if _patrician else "plaster_stone"
	if kind == "back" and not _patrician:
		material = "plaster"
	var k := 0.0
	while k <= tiles + 0.0001:
		var p := a.lerp(b, k / tiles)
		var u := k * U_PX
		var top := _wall_h
		match kind:
			"front":
				top = _front_top(p.y)
			"back":
				top = _main_z(p.y)
			"corner_side":
				top = _wing_z(p.x)
		# Facing away only the part of the gable above the roof can show.
		var z := 0.0 if seen else _wall_h
		while z <= top:
			var col: Color
			if z > _wall_h + 0.5:
				col = _gable_px(kind, u, z, length, top)
			else:
				col = _wall_px(material, kind, u, z, length, holes)
			if col.a > 0.0:
				_splat(p.x, p.y, z, art._lit(col, light), surface)
			z += STEP_Z
		k += STEP


## Openings of a wall: [u0, v0, u1, v1, kind] in pixels.
func _holes(kind: String, tiles: float, a: Vector2, b: Vector2) -> Array:
	var holes: Array = []
	var length := tiles * U_PX
	var door_u := -100.0
	# The door is on the entrance tile: local s in 1..2 (grid y in front art).
	if kind == "front" or kind == "back":
		door_u = (1.5 - a.y) / (b.y - a.y) * length
	var ground := _wall_h * 0.34
	if _patrician and (kind == "front" or kind == "corner_side"):
		var n := maxi(2, int(round(tiles / 0.62)))
		for i: int in n:
			var mid := (i + 0.5) * length / n
			holes.append([mid - 7.0, 0.0, mid + 7.0, ground - 3.0, "arcade"])
	elif kind == "front":
		holes.append([door_u - 6.0, 3.0, door_u + 6.0, 28.0, "door"])
	elif kind == "back":
		holes.append([door_u - 5.0, 3.0, door_u + 5.0, 24.0, "door"])
	var spacing := 0.75
	if kind == "back" or kind == "side":
		spacing = 1.1
	var columns := maxi(1, int(round(tiles / spacing)))
	for i: int in columns:
		var mid := (i + 0.5) * length / columns
		for f: int in _floors:
			var v0: float
			var wh := 12.0
			if _patrician:
				if f == 0 and kind != "back" and kind != "side":
					continue   # the arcade
				v0 = [_wall_h * 0.12, _wall_h * 0.43, _wall_h * 0.71][f]
				wh = [10.0, 15.0, 12.0][f]
			else:
				v0 = _wall_h * 0.14 if f == 0 else _wall_h * 0.6
			if absf(mid - door_u) < 13.0 and v0 < 30.0:
				continue
			holes.append([mid - 4.5, v0, mid + 4.5, v0 + wh, "window"])
	return holes


func _wall_px(material: String, kind: String, u: float, v: float, length: float, holes: Array) -> Color:
	for hole: Array in holes:
		if u >= hole[0] and u < hole[2] and v >= hole[1] and v < hole[3]:
			var hu: float = u - hole[0]
			var hv: float = v - hole[1]
			var hw: float = hole[2] - hole[0]
			var hh: float = hole[3] - hole[1]
			if hole[4] == "arcade":
				var ac := _arcade_px(hu, hv, hw, hh)
				if ac.a > 0.0:
					return ac
				continue
			var c: Color = art._opening(hu, hv, hw, hh, hole[4], _shutters)
			if c.a > 0.0:
				return c
	var tint := _tint if kind != "back" else _tint.darkened(0.06)
	var col: Color = art._wall_material(material, u, v, _wall_h, length, tint)
	var plain := kind == "back" or kind == "side"
	for hole: Array in holes:
		if hole[4] != "window":
			continue
		if not plain and v >= hole[1] and v < hole[3] \
				and (u >= hole[0] - 3.0 and u < hole[0] or u >= hole[2] and u < hole[2] + 3.0):
			return _shutters.darkened(0.15 * float(int(v) % 3 == 0))
		if kind == "front" and not _patrician and v >= hole[1] - 2.0 and v < hole[1] \
				and u >= hole[0] - 1.0 and u < hole[2] + 1.0 and hole[1] > 20.0:
			return Color(0.75, 0.3, 0.3) if int(u) % 3 != 0 else Color(0.35, 0.55, 0.25)
		if _patrician and not plain and v >= hole[3] and v < hole[3] + 2.0 \
				and u >= hole[0] - 2.0 and u < hole[2] + 2.0:
			return C_STONE_TRIM
	return col


## A ground-floor arch of the arcade: stone arch, the shaded walk behind.
func _arcade_px(hu: float, hv: float, hw: float, hh: float) -> Color:
	var r := hw * 0.5
	var spring := hh - r
	if hv > spring:
		var d := Vector2(hu - r, hv - spring).length()
		if d > r:
			return Color(0, 0, 0, 0)
		if d > r - 1.5:
			return Color(0.86, 0.83, 0.76)
	if hu < 1.0 or hu >= hw - 1.0:
		return Color(0.7, 0.67, 0.6)
	if hv < 1.0:
		return Color(0.5, 0.47, 0.42)
	return C_ARCADE.lightened(0.08 * (1.0 - hv / hh))


## The gable above the eaves: attic windows, the style's surface and trim.
func _gable_px(kind: String, u: float, v: float, length: float, top: float) -> Color:
	var mid := length * 0.5
	var g := v - _wall_h
	var front := kind == "front"
	var style := _style if front else STYLE_PLAIN
	if front or kind == "corner_side":
		for wu: float in [mid - 9.0, mid + 3.0]:
			if u >= wu and u < wu + 6.0 and g >= 6.0 and g < 15.0:
				return art._opening(u - wu, g - 6.0, 6.0, 9.0, "window", _shutters)
		if u >= mid - 3.0 and u < mid + 3.0 and g >= 22.0 and g < 29.0 and top - v > 6.0:
			return art._opening(u - mid + 3.0, g - 22.0, 6.0, 7.0, "window", _shutters)
	elif Vector2(u - mid, g - 10.0).length() < 2.6:
		return C_GLASS
	if top - v < 2.0:
		return C_BEAM if style == STYLE_PLAIN and not _patrician else C_STONE_TRIM
	if _patrician:
		if style == STYLE_STEPPED and front:
			# Brick with white blind niches, like the gables of the Baltic towns.
			if fposmod(u, 11.0) > 3.5 and fposmod(u, 11.0) < 8.5 and g > 18.0 and top - v > 5.0:
				return C_STONE_TRIM.darkened(0.06 * float(int(g) % 4 == 0))
			return _brick_px(u, v)
		if front and absf(g - 17.0) < 1.0:
			return C_STONE_TRIM
		return art._plaster(int(u), int(v), Color(0.94, 0.92, 0.86) * _tint)
	if style == STYLE_PLAIN:
		# Timber framing in the gable.
		if absf(g - 18.0) < 1.0 or fposmod(u, 12.0) < 1.5:
			return C_BEAM
		return art._plaster(int(u), int(v), C_PLASTER * _tint)
	if front and absf(g - 18.0) < 0.8:
		return (C_PLASTER * _tint).darkened(0.25)
	return art._plaster(int(u), int(v), Color(0.94, 0.92, 0.86) * _tint)


func _brick_px(u: float, v: float) -> Color:
	var iu := int(u)
	var iv := int(v)
	var row := iv / 3
	if iv % 3 == 0 or (iu + (row % 2) * 3) % 6 == 0:
		return Color(0.78, 0.72, 0.64)
	return C_BRICK.darkened(0.12 * art._hash((iu + (row % 2) * 3) / 6, row, 77))


# --- Chimney, turret -----------------------------------------------------------------------

func _draw_chimney() -> void:
	var t_c := 0.5
	var s_c := _sc + 0.22
	var base := _main_z(s_c + 0.1) - 2.0
	var top := _wall_h + _roof_h + 9.0
	var hw := 0.08
	for n: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		if not _faces_camera(n):
			continue
		var surface := _new_surface()
		var light := _wall_light(n)
		var k := -hw
		while k <= hw:
			var t := t_c + (n.x * hw if n.x != 0.0 else k)
			var s := s_c + (n.y * hw if n.y != 0.0 else k)
			var z := base
			while z <= top:
				var col := _brick_px(k * U_PX + 20.0, z)
				if z > top - 2.5:
					col = Color(0.55, 0.5, 0.46)
				_splat(t, s, z, art._lit(col, light), surface)
				z += STEP_Z
			k += STEP


## Patrician corner: a round oriel on the outer corner from the first floor up, with a
## pointed slate roof.
func _draw_turret() -> void:
	var s_corner := _s1 if _open_side > 0 else _s0
	var centre := Vector2(_tf - 0.04, s_corner - 0.04 * _open_side)
	var r := 0.24
	var z0 := _wall_h * 0.4
	var z1 := _wall_h + 4.0
	var apex := z1 + 34.0
	var wall := _new_surface()
	var a := 0.0
	while a < TAU:
		var n := Vector2(cos(a), sin(a))
		var light := 0.75 + 0.25 * maxf(0.0, _grid_dir(n).y) + 0.05 * _grid_dir(n).x
		var p := centre + n * r
		var z := z0
		while z <= z1:
			_splat(p.x, p.y, z, art._lit(_turret_px(a * r * U_PX, z, a), light), wall)
			z += STEP_Z
		z = z0 - 12.0
		while z < z0:
			var q := centre + n * (r * (z - (z0 - 12.0)) / 12.0)
			_splat(q.x, q.y, z, art._lit(Color(0.8, 0.77, 0.7), light * 0.9), wall)
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
	var ball := _new_surface()
	for k: int in 30:
		var ang := k * TAU / 30.0
		for zz: float in [apex + 1.0, apex + 2.0, apex + 3.0]:
			_splat(centre.x + cos(ang) * 0.025, centre.y + sin(ang) * 0.025, zz, Color(0.86, 0.7, 0.3), ball)


func _turret_px(u: float, z: float, a: float) -> Color:
	var g := _grid_dir(Vector2(cos(a), sin(a)))
	for v0: float in [_wall_h * 0.48, _wall_h * 0.74]:
		if z >= v0 and z < v0 + 12.0 and fposmod(u, 14.0) < 7.0 and g.x + g.y > 0.6:
			return art._opening(fposmod(u, 14.0), z - v0, 7.0, 12.0, "window", _shutters)
	if absf(z - _wall_h * 0.68) < 1.0:
		return (C_PLASTER * _tint).darkened(0.3)
	return art._plaster(int(u), int(z), Color(0.94, 0.92, 0.86) * _tint)


# --- Edges and props -----------------------------------------------------------------------

## A dark line where one surface ends in front of another (silhouettes, ridges, valleys).
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


func _draw_props() -> void:
	var props: Array = []
	if _back:
		if not _corner:
			props = [["barrel", Vector2(1.98, 0.3)], ["log_stack", Vector2(1.99, 1.15)]]
	elif _patrician:
		if not _corner:
			props = [["lantern", Vector2(1.94, 0.3)]]
	else:
		props = [["flowers", Vector2(1.92, 0.55)]]
	for prop: Array in props:
		var p: Vector2 = prop[1]
		art._prop(_img, Vector2(_pivot) + IsoMath.grid_to_screen(p - Vector2(2, 2)), String(prop[0]))
