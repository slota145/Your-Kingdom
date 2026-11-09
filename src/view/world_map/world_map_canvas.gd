class_name WorldMapCanvas
extends Control
## The world map drawn in code like an old map on parchment (ROADMAP M6, part 1): the sea
## with waves, the provinces as land with their borders, owners' colours and coats of arms,
## towns, names and rare resources. Reads the simulation only; a click selects a province.
## An expedition of settlers getting ready stands by its town (M6 part 2): a click on a ready
## one selects it, and a right click on a province then asks to send it there.
## Armies (M7 part 3) stand by towns or walk along the roads under their banners (the player's
## red, the bandits' black), with the number of men; the bandits' camp is a ring of tents.

signal province_clicked(id: int)
## A ready expedition (of province [param from]) was clicked.
signal expedition_clicked(from: int)
## Right click on province [param to] with the expedition of [param from] selected.
signal send_requested(from: int, to: int)
## An army (M7 part 3) was clicked; a right click on a province with it selected sends it.
signal army_clicked(id: int)
signal army_send_requested(army: int, to: int)

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
	# The AI rulers (M8): blue, green, purple.
	&"ruler_1": Color(0.16, 0.30, 0.70, 0.30),
	&"ruler_2": Color(0.18, 0.52, 0.20, 0.30),
	&"ruler_3": Color(0.48, 0.20, 0.60, 0.30),
}
const OWNER_ARMS: Dictionary[StringName, Color] = {
	ProvinceDef.OWNER_PLAYER: Color(0.70, 0.12, 0.10),
	ProvinceDef.OWNER_NEUTRAL: Color(0.45, 0.47, 0.46),
	&"ruler_1": Color(0.14, 0.26, 0.66),
	&"ruler_2": Color(0.14, 0.46, 0.16),
	&"ruler_3": Color(0.44, 0.16, 0.56),
}
const MARGIN := 24.0
## How near (parchment pixels) a click has to be to an expedition's mark.
const MARK_RADIUS := 22.0
const ROUTE_OK := Color(0.20, 0.45, 0.18)
const ROUTE_BAD := Color(0.65, 0.15, 0.10)
const ROUTE_TRADE := Color(0.50, 0.30, 0.10)
const BANDITS := Color(0.16, 0.15, 0.14)

var sim: Simulation
var selected: int = 0
## The province whose ready expedition is selected, 0 = none.
var expedition_from: int = 0
## The selected army, 0 = none.
var army_selected: int = 0
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


## The province whose expedition's mark is under [param at] (control pixels), 0 if none.
func expedition_at(at: Vector2) -> int:
	var local := _fit().affine_inverse() * at
	for id: int in sim.runtime_ids():
		var p := sim.province_state(id)
		if p != null and p.departure != null and not p.departure.is_sent() \
				and local.distance_to(departure_point(id)) <= MARK_RADIUS:
			return id
	return 0


## Where the expedition of province [param id] waits (parchment pixels): a cog off its coast,
## a wagon beside its town.
func departure_point(id: int) -> Vector2:
	var p := sim.province_state(id)
	if p != null and p.departure != null and p.departure.by_sea:
		return _offshore(id)
	return sim.world.def_of(id, sim.data).world_pos + Vector2(48, 14)


func _gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		_hover = province_at(motion.position)
	var button := event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		var from := expedition_at(button.position)
		var army := army_at(button.position)
		if army != 0:
			army_selected = army
			expedition_from = 0
			army_clicked.emit(army)
		elif from != 0:
			army_selected = 0
			expedition_from = from
			selected = from
			expedition_clicked.emit(from)
		else:
			var id := province_at(button.position)
			if id != 0:
				army_selected = 0
				selected = id
				province_clicked.emit(id)
		accept_event()
	elif button != null and button.pressed and button.button_index == MOUSE_BUTTON_RIGHT:
		var to := province_at(button.position)
		if army_selected != 0 and to != 0:
			army_send_requested.emit(army_selected, to)
		elif expedition_from != 0 and to != 0 and to != expedition_from:
			send_requested.emit(expedition_from, to)
		else:
			expedition_from = 0   # right click elsewhere lets go of the expedition
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
	for route: TradeRoute in sim.world.routes.values():
		_draw_trade_route(route)
	for expedition: Expedition in sim.world.expeditions.values():
		_draw_expedition(expedition)
	for id: int in sim.runtime_ids():
		_draw_departure(id)
	_draw_camp()
	var keys: Array[int] = []
	keys.assign(sim.world.armies.keys())
	keys.sort()
	for id: int in keys:
		_draw_army(sim.world.armies[id])
	_draw_planned_route()
	_draw_army_route()
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
	var camp := sim.world.camp
	if camp != null and camp.province == id:
		return   # the camp's tents stand there (_draw_camp)
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
	var back := e.state == Expedition.State.RETURNING
	return way_point(e.to if back else e.from, e.from if back else e.to, e.by_sea, t)


## A point [param t] (0..1) of the way from province [param from_id] to [param to_id].
func way_point(from_id: int, to_id: int, by_sea: bool, t: float) -> Vector2:
	if not by_sea:
		return sim.world.def_of(from_id, sim.data).world_pos.lerp(sim.world.def_of(to_id, sim.data).world_pos, t)
	var a := _offshore(from_id)
	var b := _offshore(to_id)
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
		_draw_cog(at, flip)
	else:
		_draw_wagon(at, flip)


## A trade route (M6 part 3): a dotted way between its provinces, a small sack at each end,
## and its cog or wagon while it is on the way (going loaded, coming back faint).
func _draw_trade_route(route: TradeRoute) -> void:
	if sim.world.def_of(route.from, sim.data) == null or sim.world.def_of(route.to, sim.data) == null:
		return
	var width := 2.0 / maxf(_fit().get_scale().x, 0.01)
	var steps := 16
	var color := Color(ROUTE_TRADE, 0.35 if route.paused else 0.75)
	for i: int in steps:
		if i % 2 == 0:
			draw_line(way_point(route.from, route.to, route.by_sea, i / float(steps)),
					way_point(route.from, route.to, route.by_sea, (i + 1) / float(steps)), color, width)
	if not route.is_on_the_way():
		return
	var back := route.state == TradeRoute.State.RETURNING
	var t := route.progress(sim.clock.tick)
	var a := route.to if back else route.from
	var b := route.from if back else route.to
	var at := way_point(a, b, route.by_sea, t)
	var ahead := way_point(a, b, route.by_sea, minf(t + 0.02, 1.0)) - at
	var flip := -1.0 if ahead.x < 0.0 else 1.0
	var alpha := 0.6 if back else 1.0
	if route.by_sea:
		_draw_cog(at, flip, alpha)
	else:
		_draw_wagon(at, flip, alpha)
	if not back:
		draw_circle(at + Vector2(0, -8), 3.5, Color(0.85, 0.65, 0.25))


## The expedition of province [param id] getting ready (faint) or ready (with a flag) by its
## town; the selected one glows.
func _draw_departure(id: int) -> void:
	var p := sim.province_state(id)
	if p == null or p.departure == null or p.departure.is_sent():
		return
	var at := departure_point(id)
	var ready := p.departure.is_ready()
	if id == expedition_from:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 200.0)
		draw_circle(at, 20.0 + pulse * 4.0, Color(SELECTED, 0.35 + 0.3 * pulse))
	elif ready:
		draw_arc(at, 19.0, 0.0, TAU, 24, Color(SELECTED, 0.8), 2.0)
	var alpha := 1.0 if ready else 0.45
	if p.departure.by_sea:
		_draw_cog(at, 1.0, alpha)
	else:
		_draw_wagon(at, 1.0, alpha)
	if ready:
		draw_line(at + Vector2(-14, -4), at + Vector2(-14, -26), INK, 1.5)
		draw_colored_polygon(PackedVector2Array([at + Vector2(-14, -26), at + Vector2(-2, -22),
				at + Vector2(-14, -18)]), OWNER_ARMS[ProvinceDef.OWNER_PLAYER])


## With an expedition selected: a dashed line to the province under the mouse, green where it
## can go, red where it cannot.
func _draw_planned_route() -> void:
	if expedition_from == 0 or _hover == 0 or _hover == expedition_from:
		return
	var p := sim.province_state(expedition_from)
	if p == null or p.departure == null or p.departure.is_sent():
		expedition_from = 0
		return
	var ok := SendExpeditionCommand.error_for(sim, expedition_from, _hover) == &""
	var to := sim.world.def_of(_hover, sim.data)
	if to == null:
		return
	var width := 3.0 / maxf(_fit().get_scale().x, 0.01)
	draw_dashed_line(departure_point(expedition_from), to.world_pos, ROUTE_OK if ok else ROUTE_BAD,
			width, width * 4.0)


func _draw_cog(at: Vector2, flip: float, alpha: float = 1.0) -> void:
	var hull := PackedVector2Array([at + Vector2(-12 * flip, -2), at + Vector2(12 * flip, -2),
			at + Vector2(8 * flip, 5), at + Vector2(-9 * flip, 5)])
	draw_colored_polygon(hull, Color(0.45, 0.28, 0.14, alpha))
	draw_line(at + Vector2(0, -2), at + Vector2(0, -20), Color(INK, alpha), 1.5)
	draw_colored_polygon(PackedVector2Array([at + Vector2(1 * flip, -19), at + Vector2(1 * flip, -5),
			at + Vector2(11 * flip, -6)]), Color(0.95, 0.92, 0.85, alpha))
	draw_rect(Rect2(at + Vector2(-1, -22), Vector2(2, 3)), Color(OWNER_ARMS[ProvinceDef.OWNER_PLAYER], alpha))


func _draw_wagon(at: Vector2, flip: float, alpha: float = 1.0) -> void:
	draw_rect(Rect2(at + Vector2(-10, -10), Vector2(20, 9)), Color(0.55, 0.38, 0.20, alpha))
	draw_arc(at + Vector2(0, -10), 9.0, PI, TAU, 10, Color(0.92, 0.88, 0.78, alpha), 3.0)
	for x: float in [-6.0, 6.0]:
		draw_circle(at + Vector2(x, 1), 3.5, Color(INK, alpha))
	draw_line(at + Vector2(10 * flip, -4), at + Vector2(17 * flip, -4), Color(INK, alpha), 1.5)


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


# --- Armies (M7 part 3) -----------------------------------------------------------------------

## Where [param army] is drawn (parchment pixels): beside its town (bandits below it), at the
## border of a settlement it waits at, or on its way.
func army_point(army: Army) -> Vector2:
	if army.state == Army.State.MOVING:
		return way_point(army.at, army.next, army.by_sea, army.progress(sim.clock.tick))
	var def := sim.world.def_of(army.at, sim.data)
	if def == null:
		return Vector2.ZERO
	if army.owner == Army.BANDITS:
		return def.world_pos + Vector2(-30, 40)
	if army.state == Army.State.WAITING:
		var from := sim.world.def_of(army.home, sim.data)
		var dir := (from.world_pos - def.world_pos).normalized() if from != null and from != def else Vector2.LEFT
		return def.world_pos + dir * 70.0
	return def.world_pos + Vector2(-50, 16)


## The army whose banner is under [param at] (control pixels), 0 if none; the player's only.
func army_at(at: Vector2) -> int:
	var local := _fit().affine_inverse() * at
	for army: Army in sim.world.armies.values():
		if army.owner == ProvinceDef.OWNER_PLAYER and army.state != Army.State.INSIDE \
				and local.distance_to(army_point(army) + Vector2(0, -15)) <= MARK_RADIUS * 1.3:
			return army.id
	return 0


## A banner on a pole over three little men, the number of men beside it.
func _draw_army(army: Army) -> void:
	if army.state == Army.State.INSIDE or army.men() == 0:
		return
	# Drawn 1.5 times larger around its point, then back to the map's transform.
	draw_set_transform_matrix(_fit() * Transform2D(0.0, Vector2(1.5, 1.5), 0.0, army_point(army)))
	var at := Vector2.ZERO
	var color: Color = OWNER_ARMS[ProvinceDef.OWNER_PLAYER] if army.owner == ProvinceDef.OWNER_PLAYER else BANDITS
	if army.id == army_selected:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 200.0)
		draw_circle(at + Vector2(0, -8), 22.0 + pulse * 4.0, Color(SELECTED, 0.35 + 0.3 * pulse))
	elif army.state == Army.State.WAITING:
		draw_arc(at + Vector2(0, -8), 21.0, 0.0, TAU, 24, Color(SELECTED, 0.8), 2.0)
	for k: int in 3:
		var man := at + Vector2(-9 + k * 9, 2 - (k % 2) * 3)
		draw_circle(man + Vector2(0, -9), 3.0, Color(0.85, 0.70, 0.55))
		draw_rect(Rect2(man + Vector2(-3, -6), Vector2(6, 8)), color)
		draw_line(man + Vector2(4, -14), man + Vector2(4, 3), INK, 1.2)   # a spear
	draw_line(at + Vector2(-14, 2), at + Vector2(-14, -30), INK, 1.8)
	var flag := PackedVector2Array([at + Vector2(-14, -30), at + Vector2(4, -26), at + Vector2(-2, -22),
			at + Vector2(4, -18), at + Vector2(-14, -16)])
	draw_colored_polygon(flag, color)
	if army.owner == Army.BANDITS:
		draw_circle(at + Vector2(-7, -23), 2.5, Color(0.92, 0.88, 0.80))   # a skull
	var font := get_theme_default_font()
	draw_string_outline(font, at + Vector2(9, -14), str(army.men()), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, PARCHMENT)
	draw_string(font, at + Vector2(9, -14), str(army.men()), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, INK)
	draw_set_transform_matrix(_fit())


## The bandits' camp: a ring of dark tents round a fire.
func _draw_camp() -> void:
	var camp := sim.world.camp
	if camp == null or not camp.is_up():
		return
	var def := sim.world.def_of(camp.province, sim.data)
	if def == null:
		return
	var at := def.world_pos
	for k: int in 4:
		var c := at + Vector2(cos(k * TAU / 4.0 + 0.4), sin(k * TAU / 4.0 + 0.4) * 0.6) * 16.0
		draw_colored_polygon(PackedVector2Array([c + Vector2(-8, 5), c + Vector2(0, -9), c + Vector2(8, 5)]),
				BANDITS.lightened(0.15 * (k % 2)))
		draw_line(c + Vector2(0, -9), c + Vector2(0, 5), Color(0.6, 0.5, 0.4), 1.0)
	draw_circle(at + Vector2(0, 2), 3.5, Color(0.95, 0.55, 0.15))
	draw_circle(at + Vector2(0, 0), 2.0, Color(1.0, 0.85, 0.3))


## With an army selected: a dashed line along its way to the province under the mouse (through
## the neighbours it walks), green where it can go, red where it cannot.
func _draw_army_route() -> void:
	var army := sim.world.armies.get(army_selected) as Army
	if army == null:
		army_selected = 0
		return
	var width := 3.0 / maxf(_fit().get_scale().x, 0.01)
	if army.state == Army.State.MOVING:
		var stops: Array[int] = [army.next]
		stops.append_array(army.route)
		var from := army_point(army)
		for stop: int in stops:
			var to := sim.world.def_of(stop, sim.data).world_pos
			draw_dashed_line(from, to, Color(ROUTE_OK, 0.6), width, width * 4.0)
			from = to
		return
	if _hover == 0 or _hover == army.at:
		return
	var ok := Armies.send_error(sim, army, _hover) == &""
	var stops: Array[int] = [_hover]
	if ok and not Armies.goes_by_sea(sim, army, _hover):
		stops = sim.world.land_route(army.at, _hover, sim.data)
	var from := army_point(army)
	for stop: int in stops:
		var def := sim.world.def_of(stop, sim.data)
		if def == null:
			continue
		draw_dashed_line(from, def.world_pos, ROUTE_OK if ok else ROUTE_BAD, width, width * 4.0)
		from = def.world_pos
