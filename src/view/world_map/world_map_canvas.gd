class_name WorldMapCanvas
extends Control
## The world map drawn in code like an old map on parchment (ROADMAP M6, part 1): the sea
## with waves, the provinces as land with their borders, owners' colours and coats of arms,
## towns, names and rare resources. Reads the simulation only; a click selects a province.

signal province_clicked(id: int)

const PARCHMENT := Color(0.88, 0.80, 0.63)
const PARCHMENT_DARK := Color(0.62, 0.50, 0.33)
const SEA := Color(0.60, 0.70, 0.66)
const SEA_LINE := Color(0.42, 0.53, 0.52, 0.55)
const LAND := Color(0.82, 0.75, 0.55)
const BORDER := Color(0.42, 0.29, 0.17)
const SELECTED := Color(0.95, 0.74, 0.20)
const INK := Color(0.25, 0.17, 0.10)
## Owner -> fill tint and coat of arms colour.
const OWNER_TINT: Dictionary[StringName, Color] = {
	ProvinceDef.OWNER_PLAYER: Color(0.72, 0.16, 0.14, 0.30),
	ProvinceDef.OWNER_NEUTRAL: Color(0.40, 0.42, 0.40, 0.28),
}
const OWNER_ARMS: Dictionary[StringName, Color] = {
	ProvinceDef.OWNER_PLAYER: Color(0.70, 0.12, 0.10),
	ProvinceDef.OWNER_NEUTRAL: Color(0.45, 0.47, 0.46),
}
const MARGIN := 24.0

var sim: Simulation
var selected: int = 0
var _hover: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)


func _process(_delta: float) -> void:
	queue_redraw()


func world_def() -> WorldDef:
	return sim.data.get_world(sim.world.world_id) if sim != null else null


## Parchment pixels -> control pixels.
func _fit() -> Transform2D:
	var world := world_def()
	if world == null:
		return Transform2D.IDENTITY
	var area := size - Vector2(MARGIN, MARGIN) * 2.0
	var scale_by := minf(area.x / world.size.x, area.y / world.size.y)
	var offset := (size - world.size * scale_by) / 2.0
	return Transform2D(0.0, Vector2(scale_by, scale_by), 0.0, offset)


## The province under [param at] (control pixels), 0 if none.
func province_at(at: Vector2) -> int:
	var local := _fit().affine_inverse() * at
	for id: int in sim.world.ids():
		var def := sim.world.def_of(id, sim.data)
		if def != null and Geometry2D.is_point_in_polygon(local, def.outline):
			return id
	return 0


func _gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		_hover = province_at(motion.position)
	var button := event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		var id := province_at(button.position)
		if id != 0:
			selected = id
			province_clicked.emit(id)
		accept_event()


func _draw() -> void:
	var world := world_def()
	if world == null:
		return
	var fit := _fit()
	var frame := Rect2(fit.origin, world.size * fit.get_scale())
	_draw_parchment(frame)
	draw_rect(frame.grow(-6.0), SEA)
	_draw_waves(frame.grow(-6.0))
	draw_set_transform_matrix(fit)
	for id: int in sim.world.ids():
		_draw_shallows(id)
	for id: int in sim.world.ids():
		_draw_province(id)
	for id: int in sim.world.ids():
		_draw_town(id)
	for expedition: Expedition in sim.world.expeditions.values():
		_draw_expedition(expedition)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	for id: int in sim.world.ids():
		_draw_label(id, fit)
	_draw_compass(frame)
	draw_rect(frame.grow(-6.0), BORDER, false, 3.0)
	draw_rect(frame.grow(-12.0), Color(BORDER, 0.5), false, 1.0)


func _draw_parchment(frame: Rect2) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PARCHMENT_DARK.darkened(0.45))
	draw_rect(frame, PARCHMENT)
	# Darker, stained edges.
	for i: int in 10:
		draw_rect(frame.grow(-i * 2.0), Color(PARCHMENT_DARK, 0.10), false, 2.0)
	var stains: Array[Vector3] = [Vector3(0.12, 0.85, 60), Vector3(0.86, 0.14, 45),
			Vector3(0.70, 0.90, 35), Vector3(0.05, 0.30, 30)]
	for s: Vector3 in stains:
		draw_circle(frame.position + Vector2(s.x, s.y) * frame.size, s.z, Color(PARCHMENT_DARK, 0.08))


func _draw_waves(area: Rect2) -> void:
	var step := Vector2(70.0, 46.0)
	var row := 0
	var y := area.position.y + 20.0
	while y < area.end.y - 10.0:
		var x := area.position.x + 20.0 + (row % 2) * step.x / 2.0
		while x < area.end.x - 20.0:
			var a := Vector2(x, y)
			var points := PackedVector2Array([a, a + Vector2(6, -4), a + Vector2(12, 0),
					a + Vector2(18, -4), a + Vector2(24, 0)])
			draw_polyline(points, SEA_LINE, 1.5, true)
			x += step.x
		y += step.y
		row += 1


## Lighter water along the coast of a province by the sea.
func _draw_shallows(id: int) -> void:
	var def := sim.world.def_of(id, sim.data)
	if def == null or not def.coastal or def.outline.size() < 3:
		return
	var closed := _wobbly(def.outline)
	closed.append(closed[0])
	var width := 1.0 / maxf(_fit().get_scale().x, 0.01)
	draw_polyline(closed, SEA.lightened(0.18), width * 18.0, true)
	draw_polyline(closed, SEA.lightened(0.30), width * 8.0, true)


func _draw_province(id: int) -> void:
	var def := sim.world.def_of(id, sim.data)
	if def == null or def.outline.size() < 3:
		return
	var owner := sim.world.owner_of(id)
	var fill := LAND
	if def.island:
		fill = LAND.lightened(0.05)
	if id == _hover:
		fill = fill.lightened(0.15)
	var shape := _wobbly(def.outline)
	draw_colored_polygon(shape, fill)
	if OWNER_TINT.has(owner):
		draw_colored_polygon(shape, OWNER_TINT[owner])
	var closed := shape.duplicate()
	closed.append(shape[0])
	var width := 2.0 / maxf(_fit().get_scale().x, 0.01)
	draw_polyline(closed, BORDER, width * 1.2, true)
	if id == selected:
		draw_polyline(closed, SELECTED, width * 2.5, true)


## [param outline] with every edge broken into small wiggles, like a hand-drawn border. The
## wiggle of an edge depends only on its two ends, so neighbours share the same border.
static func _wobbly(outline: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i: int in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		var lo := a if a < b else b
		var seed_value := lo.x * 0.37 + lo.y * 0.61 + (a + b).length() * 0.13
		var flip := 1.0 if a < b else -1.0
		var normal := (b - a).orthogonal().normalized()
		var length := a.distance_to(b)
		var parts := maxi(int(length / 18.0), 1)
		result.append(a)
		for k: int in range(1, parts):
			var t := k / float(parts)
			# The same offset from either side (flip turns the normal back).
			var u := t if a < b else 1.0 - t
			var wiggle := sin(u * 9.0 + seed_value) * 4.0 + sin(u * 23.0 + seed_value * 2.0) * 2.0
			result.append(a.lerp(b, t) + normal * wiggle * flip * minf(length / 60.0, 1.0))
	return result


## A town for every settled or neutral province, a small cross for an empty one.
func _draw_town(id: int) -> void:
	var def := sim.world.def_of(id, sim.data)
	if def == null:
		return
	var at := def.world_pos
	var owner := sim.world.owner_of(id)
	if not sim.runtimes.has(id) and owner == ProvinceDef.OWNER_NONE:
		draw_line(at + Vector2(-5, -5), at + Vector2(5, 5), Color(INK, 0.5), 2.0)
		draw_line(at + Vector2(-5, 5), at + Vector2(5, -5), Color(INK, 0.5), 2.0)
		return
	var wall := Color(0.93, 0.89, 0.80)
	var roof := OWNER_ARMS.get(owner, Color(0.5, 0.3, 0.2)) as Color
	# A keep with two towers.
	draw_rect(Rect2(at + Vector2(-14, -10), Vector2(28, 14)), wall)
	draw_rect(Rect2(at + Vector2(-14, -10), Vector2(28, 14)), INK, false, 1.5)
	for x: float in [-16.0, 8.0]:
		draw_rect(Rect2(at + Vector2(x, -20), Vector2(8, 24)), wall)
		draw_rect(Rect2(at + Vector2(x, -20), Vector2(8, 24)), INK, false, 1.5)
		draw_colored_polygon(PackedVector2Array([at + Vector2(x - 1, -20), at + Vector2(x + 4, -28),
				at + Vector2(x + 9, -20)]), roof)
	draw_rect(Rect2(at + Vector2(-3, -4), Vector2(6, 8)), INK)
	if sim.runtimes.has(id) and id == sim.viewed_id:
		draw_arc(at + Vector2(0, -6), 26.0, 0.0, TAU, 32, SELECTED, 2.0)


func _draw_label(id: int, fit: Transform2D) -> void:
	var def := sim.world.def_of(id, sim.data)
	if def == null:
		return
	var font := get_theme_default_font()
	var at := fit * (def.world_pos + Vector2(0, 22))
	var text := tr(def.name_key())
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 18).x
	draw_string(font, at - Vector2(width / 2.0, -12.0), text, HORIZONTAL_ALIGNMENT_CENTER, -1, 18, INK)
	var owner := sim.world.owner_of(id)
	if OWNER_ARMS.has(owner):
		_draw_arms(at + Vector2(-width / 2.0 - 16.0, 4.0), OWNER_ARMS[owner])
	if def.rare_resource != &"":
		_draw_rare(at + Vector2(width / 2.0 + 16.0, 6.0), def.rare_resource)


## Where an expedition is on its way (parchment pixels): straight to a land neighbour, by
## ship in a curve out to sea (west of the coast, where the sea is on this map).
func route_point(e: Expedition, t: float) -> Vector2:
	var a := sim.world.def_of(e.from, sim.data).world_pos
	var b := sim.world.def_of(e.to, sim.data).world_pos
	if e.state == Expedition.State.RETURNING:
		var swap := a
		a = b
		b = swap
	if not e.by_sea:
		return a.lerp(b, t)
	var from_id := e.to if e.state == Expedition.State.RETURNING else e.from
	var to_id := e.from if e.state == Expedition.State.RETURNING else e.to
	a = _offshore(from_id)
	b = _offshore(to_id)
	var control := Vector2(minf(a.x, b.x) - 120.0, (a.y + b.y) / 2.0)
	return a.lerp(control, t).lerp(control.lerp(b, t), t)


## Water off the west coast of province [param id] (the sea lies west on this map), level
## with its town: where ships come and go.
func _offshore(id: int) -> Vector2:
	var def := sim.world.def_of(id, sim.data)
	var west := def.world_pos.x
	for point: Vector2 in def.outline:
		west = minf(west, point.x)
	return Vector2(west - 26.0, def.world_pos.y)


## A ship or a wagon on its way; one waiting at the border of the new province glows.
func _draw_expedition(e: Expedition) -> void:
	if e.state == Expedition.State.LANDED:
		return
	var t := e.progress(sim.clock.tick)
	if e.state == Expedition.State.WAITING:
		t = 1.0 if e.by_sea else 0.85
	var at := route_point(e, t)
	var ahead := route_point(e, minf(t + 0.02, 1.0)) - at
	var flip := -1.0 if ahead.x < 0.0 else 1.0
	if e.state == Expedition.State.WAITING:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 250.0)
		draw_circle(at, 18.0 + pulse * 4.0, Color(SELECTED, 0.25 + 0.25 * pulse))
	if e.by_sea:
		var hull := PackedVector2Array([at + Vector2(-12 * flip, -2), at + Vector2(12 * flip, -2),
				at + Vector2(8 * flip, 5), at + Vector2(-9 * flip, 5)])
		draw_colored_polygon(hull, Color(0.45, 0.28, 0.14))
		draw_line(at + Vector2(0, -2), at + Vector2(0, -20), INK, 1.5)
		draw_colored_polygon(PackedVector2Array([at + Vector2(1 * flip, -19), at + Vector2(1 * flip, -5),
				at + Vector2(11 * flip, -6)]), Color(0.95, 0.92, 0.85))
		draw_rect(Rect2(at + Vector2(-1, -22), Vector2(2, 3)), OWNER_ARMS[ProvinceDef.OWNER_PLAYER])
	else:
		draw_rect(Rect2(at + Vector2(-10, -10), Vector2(20, 9)), Color(0.55, 0.38, 0.20))
		draw_arc(at + Vector2(0, -10), 9.0, PI, TAU, 10, Color(0.92, 0.88, 0.78), 3.0)
		for x: float in [-6.0, 6.0]:
			draw_circle(at + Vector2(x, 1), 3.5, INK)
		draw_line(at + Vector2(10 * flip, -4), at + Vector2(17 * flip, -4), INK, 1.5)


## A small shield in the owner's colour.
func _draw_arms(at: Vector2, color: Color) -> void:
	var shield := PackedVector2Array([at + Vector2(-8, -9), at + Vector2(8, -9), at + Vector2(8, 2),
			at + Vector2(0, 10), at + Vector2(-8, 2)])
	draw_colored_polygon(shield, color)
	shield.append(shield[0])
	draw_polyline(shield, INK, 1.5, true)
	draw_line(at + Vector2(0, -9), at + Vector2(0, 9), Color(0.95, 0.80, 0.30), 2.0)


## The rare resource's mark: grapes, salt crystals, ore or a horseshoe.
func _draw_rare(at: Vector2, rare: StringName) -> void:
	match rare:
		&"vines":
			for p: Vector2 in [Vector2(-4, -4), Vector2(4, -4), Vector2(0, -4), Vector2(-2, 1),
					Vector2(2, 1), Vector2(0, 6)]:
				draw_circle(at + p, 3.2, Color(0.42, 0.18, 0.45))
			draw_line(at + Vector2(0, -8), at + Vector2(4, -12), Color(0.25, 0.45, 0.20), 2.0)
		&"salt":
			for p: Vector2 in [Vector2(-5, 2), Vector2(4, 0), Vector2(0, -5)]:
				var c := at + p
				var gem := PackedVector2Array([c + Vector2(0, -5), c + Vector2(4, 0), c + Vector2(0, 5),
						c + Vector2(-4, 0)])
				draw_colored_polygon(gem, Color(0.97, 0.97, 0.95))
				gem.append(gem[0])
				draw_polyline(gem, INK, 1.0)
		&"iron_ore":
			var rock := PackedVector2Array([at + Vector2(-8, 5), at + Vector2(-6, -4), at + Vector2(0, -8),
					at + Vector2(7, -3), at + Vector2(8, 5)])
			draw_colored_polygon(rock, Color(0.36, 0.34, 0.33))
			draw_circle(at + Vector2(-2, -1), 1.8, Color(0.70, 0.35, 0.15))
			draw_circle(at + Vector2(3, 2), 1.5, Color(0.70, 0.35, 0.15))
		&"horses":
			draw_arc(at, 7.0, PI * 0.15, PI * 1.85, 16, Color(0.30, 0.28, 0.26), 3.0)
		_:
			draw_circle(at, 4.0, INK)


func _draw_compass(frame: Rect2) -> void:
	var c := frame.end - Vector2(70, 70)
	var r := 34.0
	for i: int in 4:
		var dir := Vector2.UP.rotated(i * PI / 2.0)
		var side := dir.orthogonal() * 7.0
		draw_colored_polygon(PackedVector2Array([c + dir * r, c + side, c - side]),
				INK if i % 2 == 0 else PARCHMENT_DARK)
	draw_arc(c, r * 0.55, 0.0, TAU, 32, INK, 1.5)
	var font := get_theme_default_font()
	draw_string(font, c + Vector2(-5, -r - 6), tr("ui.world.north"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, INK)
