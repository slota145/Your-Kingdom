class_name TroopsLayer
extends Node2D
## What a battle shows over the world (M7 part 2): life bars over wounded and selected
## fighters (red for enemies), a mark over the selected, arrows in flight, the box the
## player drags to select and a short mark where an order sends the soldiers.

const BAR_SIZE := Vector2(18, 3)
const BAR_BACK := Color(0.08, 0.06, 0.05, 0.85)
const OWN := Color(0.35, 0.85, 0.3)
const ENEMY := Color(0.9, 0.22, 0.18)
const MARK := Color(1.0, 0.86, 0.35)
const SHAFT := Color(0.32, 0.22, 0.12)
const HEAD := Color(0.75, 0.75, 0.78)
const BOX := Color(1.0, 0.95, 0.7, 0.9)
const ORDER_MARK_SECONDS := 0.8
## UI-4 part 1 (owner 2026-11-23): where each selected soldier is going, and whom he attacks.
const GOAL := Color(1.0, 0.86, 0.35, 0.95)
const GOAL_LINE := Color(1.0, 0.92, 0.6, 0.55)
const TARGET := Color(0.95, 0.18, 0.12)
## A soldier this close to his place (tiles) has arrived: his marker goes.
const ARRIVED := 0.35
## Head to feet of a soldier on the screen (AgentViewPool.heads).
const FEET := 44.0
## Dashes of the line to a soldier's place (pixels).
const DASH := 5.0

var province: ProvinceSim
var agents: AgentViewPool
## Ids of the soldiers the player selected (game scene).
var selected: Array[int] = []
## Drag-select box in world space (size zero = none).
var box: Rect2 = Rect2()
var _order_at: Vector2 = Vector2.ZERO
var _order_time: float = 0.0
var _alpha: float = 0.0


func setup(source: ProvinceSim, pool: AgentViewPool) -> void:
	province = source
	agents = pool
	z_index = 2


func show_order(world_pos: Vector2) -> void:
	_order_at = world_pos
	_order_time = ORDER_MARK_SECONDS


func update_view(alpha: float, delta: float) -> void:
	_alpha = alpha
	_order_time = maxf(_order_time - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	for id: int in agents.heads:
		var agent := province.agents.get_agent(id)
		if agent == null or agent.combat == null:
			continue
		var unit := province.data.get_unit(agent.combat.unit if agent.combat.unit != &"" else agent.kind)
		var full := unit.combat.hp if unit != null else maxi(agent.combat.hp, 1)
		var chosen := selected.has(id)
		if not chosen and agent.combat.hp >= full:
			continue
		var head: Vector2 = agents.heads[id]
		var at := head - Vector2(BAR_SIZE.x / 2.0, 6.0)
		draw_rect(Rect2(at - Vector2.ONE, BAR_SIZE + Vector2(2, 2)), BAR_BACK)
		var share := clampf(float(agent.combat.hp) / full, 0.0, 1.0)
		draw_rect(Rect2(at, Vector2(BAR_SIZE.x * share, BAR_SIZE.y)),
				OWN if agent.combat.faction == CombatState.PLAYER else ENEMY)
		if chosen:
			draw_colored_polygon(PackedVector2Array([head + Vector2(-4, -14), head + Vector2(4, -14),
					head + Vector2(0, -9)]), MARK)
	_draw_orders()
	for arrow: Troops.Arrow in province.arrows:
		_draw_arrow(arrow)
	if box.size != Vector2.ZERO:
		draw_rect(box.abs(), Color(BOX, 0.12))
		draw_rect(box.abs(), BOX, false, 1.0)
	if _order_time > 0.0:
		var k := _order_time / ORDER_MARK_SECONDS
		var r := 6.0 + 10.0 * (1.0 - k)
		draw_arc(_order_at, r, 0.0, TAU, 20, Color(MARK, k), 1.5)


## The selected soldiers' orders (UI-4 part 1): a marker on each one's place in the ranks with a
## dashed line from him to it until he gets there; a red target over each enemy they attack.
func _draw_orders() -> void:
	var targets: Dictionary[int, bool] = {}
	for id: int in selected:
		var agent := province.agents.get_agent(id)
		if agent == null or agent.combat == null or not agents.heads.has(id):
			continue
		var c := agent.combat
		if c.order == CombatState.Order.ATTACK and c.target_id != 0:
			targets[c.target_id] = true
			continue
		if c.order != CombatState.Order.MOVE or c.post.x < 0.0 or agent.pos.distance_to(c.post) <= ARRIVED:
			continue
		var feet: Vector2 = agents.heads[id] + Vector2(0, FEET)
		var goal := _screen(c.post, c.post_level)
		_dashed(feet, goal)
		_goal_marker(goal)
	for id: int in targets:
		if agents.heads.has(id):
			_target_marker(agents.heads[id] - Vector2(0, 14))


func _dashed(a: Vector2, b: Vector2) -> void:
	var length := a.distance_to(b)
	if length < 1.0:
		return
	var dir := (b - a) / length
	var t := 0.0
	while t < length:
		draw_line(a + dir * t, a + dir * minf(t + DASH, length), GOAL_LINE, 1.0)
		t += DASH * 2.0


## A small flat diamond on the ground (the shape of a tile) with a dot in it.
func _goal_marker(at: Vector2) -> void:
	var r := Vector2(7, 3.5)
	var points := PackedVector2Array([at + Vector2(-r.x, 0), at + Vector2(0, -r.y), at + Vector2(r.x, 0),
			at + Vector2(0, r.y), at + Vector2(-r.x, 0)])
	draw_polyline(points, Color(0.1, 0.06, 0.03, 0.8), 3.0)
	draw_polyline(points, GOAL, 1.5)
	draw_circle(at, 1.5, GOAL)


## A red target over an attacked enemy's head: a ring with four ticks and a pulsing dot.
func _target_marker(at: Vector2) -> void:
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 160.0)
	draw_arc(at, 6.0, 0.0, TAU, 20, Color(0.1, 0.03, 0.02, 0.8), 3.5)
	draw_arc(at, 6.0, 0.0, TAU, 20, TARGET, 1.5)
	for dir: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(at + dir * 4.0, at + dir * 9.0, TARGET, 1.5)
	draw_circle(at, 1.5 + pulse, TARGET)


## An arrow along its arc: from the bow to where it was aimed, high in the middle.
func _draw_arrow(arrow: Troops.Arrow) -> void:
	var t := 1.0 - (float(arrow.ticks) - _alpha) / float(arrow.total)
	t = clampf(t, 0.0, 1.0)
	var a := _screen(arrow.from, arrow.from_level) - Vector2(0, 26)
	var b := _screen(arrow.to, arrow.to_level) - Vector2(0, 18)
	var arc := a.distance_to(b) * (0.08 if arrow.bolt else 0.25)
	var p := a.lerp(b, t) - Vector2(0, arc * 4.0 * t * (1.0 - t))
	var t2 := minf(t + 0.04, 1.0)
	var q := a.lerp(b, t2) - Vector2(0, arc * 4.0 * t2 * (1.0 - t2))
	var dir := (q - p).normalized() if q != p else (b - a).normalized()
	if arrow.bolt:
		# A ballista's bolt (J1 part 2): long, thick, a flat flight, an iron head, wooden vanes.
		draw_line(p - dir * 12.0, p, SHAFT.darkened(0.2), 3.0)
		draw_line(p - dir * 12.0, p - dir * 15.0 + dir.orthogonal() * 3.0, SHAFT.lightened(0.2), 1.5)
		draw_line(p - dir * 12.0, p - dir * 15.0 - dir.orthogonal() * 3.0, SHAFT.lightened(0.2), 1.5)
		draw_line(p, p + dir * 4.0, HEAD, 3.0)
		return
	draw_line(p - dir * 7.0, p, SHAFT, 1.5)
	draw_line(p - dir * 7.0, p - dir * 9.0 + dir.orthogonal() * 2.0, Color.WHITE, 1.0)
	draw_line(p, p + dir * 2.0, HEAD, 1.5)


func _screen(g: Vector2, level: int) -> Vector2:
	return IsoMath.grid_to_screen(g) - Vector2(0, FortLayer.height_at(province, g, level))
