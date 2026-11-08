class_name SiegeLayer
extends Node2D
## Siege engines in the world (M7 part 2), drawn in code: rams (a shed of planks under wet
## hides on four wheels, an iron-shod log swinging inside, the crew's legs under it) and
## ladders leaning on walls. Child of the y-sorted world; every engine sorts at its foot.

var province: ProvinceSim
var _rams: Dictionary[int, _Ram] = {}
var _ballistas: Dictionary[int, _Ballista] = {}
var _ladders: Dictionary[Vector2i, _Ladder] = {}


func _init() -> void:
	y_sort_enabled = true


func setup(source: ProvinceSim) -> void:
	province = source


func update_view(alpha: float, time: float) -> void:
	var seen: Dictionary[int, bool] = {}
	for agent: Agent in province.agents.all():
		if agent.kind == Troops.BALLISTA:
			seen[agent.id] = true
			var ballista: _Ballista = _ballistas.get(agent.id)
			if ballista == null:
				ballista = _Ballista.new()
				_ballistas[agent.id] = ballista
				add_child(ballista)
			ballista.position = IsoMath.grid_to_screen(agent.prev_pos.lerp(agent.pos, alpha))
			ballista.facing = agent.facing
			ballista.walking = agent.activity == &"walk"
			ballista.loaded = agent.combat == null or agent.combat.cooldown <= SimClock.seconds_to_ticks(2.0)
			ballista.time = time + agent.id * 0.37
			ballista.hostile = agent.combat != null and agent.combat.faction != CombatState.PLAYER
			ballista.queue_redraw()
			continue
		if agent.kind != &"ram":
			continue
		seen[agent.id] = true
		var ram: _Ram = _rams.get(agent.id)
		if ram == null:
			ram = _Ram.new()
			_rams[agent.id] = ram
			add_child(ram)
		var at := agent.prev_pos.lerp(agent.pos, alpha)
		ram.position = IsoMath.grid_to_screen(at)
		ram.facing = agent.facing
		ram.walking = agent.activity == &"walk"
		ram.striking = agent.activity == &"drill"
		ram.time = time + agent.id * 0.37
		ram.hostile = agent.combat != null and agent.combat.faction != CombatState.PLAYER
		ram.queue_redraw()
	for id: int in _rams.keys():
		if not seen.has(id):
			_rams[id].queue_free()
			_rams.erase(id)
	for id: int in _ballistas.keys():
		if not seen.has(id):
			_ballistas[id].queue_free()
			_ballistas.erase(id)
	var ladders := province.mil.ladders
	for foot: Vector2i in _ladders.keys():
		if not ladders.has(foot):
			_ladders[foot].queue_free()
			_ladders.erase(foot)
	for foot: Vector2i in ladders:
		if not _ladders.has(foot):
			var ladder := _Ladder.new()
			ladder.foot = foot
			ladder.wall = ladders[foot]
			var s := IsoMath.tile_center_screen(foot)
			ladder.position = Vector2(roundf(s.x), roundf(s.y))
			_ladders[foot] = ladder
			add_child(ladder)


## A battering ram.
class _Ram:
	extends Node2D
	const HIDE := Color(0.47, 0.36, 0.26)
	const HIDE_DARK := Color(0.32, 0.24, 0.17)
	const WOOD := Color(0.5, 0.36, 0.22)
	const WOOD_DARK := Color(0.3, 0.21, 0.13)
	const IRON := Color(0.36, 0.36, 0.4)
	const LEG := Color(0.33, 0.27, 0.22)
	const OUTLINE := Color(0.14, 0.1, 0.07)
	var facing: int = 0
	var walking: bool = false
	var striking: bool = false
	var hostile: bool = false
	var time: float = 0.0

	func _draw() -> void:
		var step := Vector2(IsoMath.DIR_GRID_STEP[facing])
		var along := step.normalized()
		var across := Vector2(-along.y, along.x)
		var p := func(u: float, v: float, z: float) -> Vector2:
			return IsoMath.grid_to_screen(along * u + across * v) - Vector2(0, z)
		var half_l := 0.7
		var half_w := 0.36
		var h := 22.0
		var ridge := 36.0
		# Wheels and the crew's legs below.
		for u: float in [-0.5, 0.5]:
			for v: float in [-half_w, half_w]:
				var c: Vector2 = p.call(u, v * 1.05, 5.0)
				draw_circle(c, 5.0, WOOD_DARK)
				draw_circle(c, 3.5, WOOD)
				draw_circle(c, 1.2, IRON)
		for k: int in 4:
			var u := -0.45 + 0.3 * k
			var swing := sin(time * 8.0 + k) * 2.0 if walking else 0.0
			for v: float in [-0.12, 0.12]:
				var foot: Vector2 = p.call(u + swing * 0.02, v, 0.0)
				draw_line(foot, foot - Vector2(0, 9), LEG, 2.0)
				draw_line(foot, foot + Vector2(1.5, 0), OUTLINE, 1.0)
		# The log inside, swung forward while striking.
		var reach := 0.25 * (0.5 - 0.5 * cos(time * TAU / 1.5)) if striking else 0.0
		var log_a: Vector2 = p.call(-0.6 + reach, 0.0, 13.0)
		var log_b: Vector2 = p.call(0.85 + reach, 0.0, 13.0)
		draw_line(log_a, log_b, WOOD_DARK, 6.0)
		draw_line(log_a, log_b, WOOD, 4.0)
		draw_line(log_b, p.call(0.98 + reach, 0.0, 13.0), IRON, 7.0)
		# The shed: two sloping roofs of hides over a frame, ends of planks.
		var corners := [p.call(-half_l, -half_w, h), p.call(half_l, -half_w, h),
				p.call(half_l, half_w, h), p.call(-half_l, half_w, h)]
		var ridge_a: Vector2 = p.call(-half_l, 0.0, ridge)
		var ridge_b: Vector2 = p.call(half_l, 0.0, ridge)
		var roof_l := PackedVector2Array([corners[0], corners[1], ridge_b, ridge_a])
		var roof_r := PackedVector2Array([corners[3], corners[2], ridge_b, ridge_a])
		var lit := across.dot(Vector2(1, 1)) < 0.0
		for side: int in 2:
			var roof := roof_l if side == 0 else roof_r
			var bright := (side == 0) == lit
			draw_colored_polygon(roof, HIDE if bright else HIDE_DARK)
			for k: int in range(1, 5):
				var t := k / 5.0
				draw_line(roof[0].lerp(roof[1], t), roof[3].lerp(roof[2], t), (HIDE if bright else HIDE_DARK).darkened(0.25), 1.0)
			draw_polyline(roof + PackedVector2Array([roof[0]]), OUTLINE, 1.0)
		# Gable ends of planks at both ends of the ridge (the front one drawn last).
		for u: float in [-half_l, half_l]:
			var gable := PackedVector2Array([p.call(u, -half_w, h), p.call(u, half_w, h), p.call(u, 0.0, ridge)])
			draw_colored_polygon(gable, WOOD)
			draw_polyline(gable + PackedVector2Array([gable[0]]), OUTLINE, 1.0)
		# Posts at the corners down to the wheels.
		for k: int in 4:
			var top: Vector2 = corners[k]
			draw_line(top, top + Vector2(0, h - 6.0), WOOD_DARK, 2.0)
		# A small pennon: red for the kingdom, black for bandits.
		var pole: Vector2 = ridge_b
		draw_line(pole, pole - Vector2(0, 10), WOOD_DARK, 1.0)
		draw_colored_polygon(PackedVector2Array([pole - Vector2(0, 10), pole - Vector2(-7, 8),
				pole - Vector2(0, 6)]), Color(0.15, 0.13, 0.12) if hostile else Color(0.7, 0.12, 0.1))


## A ballista (J1 part 2, drawn in code like the ram): a great crossbow on a wheeled frame,
## its arms of wood bound with iron, the string drawn back to the winch while loaded and
## straight after the shot, a bolt in the groove; two crewmen at the winch behind it, pushing
## while it moves.
class _Ballista:
	extends Node2D
	const WOOD := Color(0.5, 0.36, 0.22)
	const WOOD_DARK := Color(0.3, 0.21, 0.13)
	const IRON := Color(0.36, 0.36, 0.4)
	const ROPE := Color(0.88, 0.84, 0.72)
	const SHIRT := Color(0.66, 0.58, 0.44)
	const LEG := Color(0.33, 0.27, 0.22)
	const SKIN := Color(0.86, 0.66, 0.5)
	const OUTLINE := Color(0.14, 0.1, 0.07)
	var facing: int = 0
	var walking: bool = false
	var loaded: bool = true
	var hostile: bool = false
	var time: float = 0.0

	func _draw() -> void:
		var step := Vector2(IsoMath.DIR_GRID_STEP[facing])
		var along := step.normalized()
		var across := Vector2(-along.y, along.x)
		var p := func(u: float, v: float, z: float) -> Vector2:
			return IsoMath.grid_to_screen(along * u + across * v) - Vector2(0, z)
		# The crew behind, drawn first when the engine faces the camera.
		var crew_behind := along.y + along.x > 0.0
		if not crew_behind:
			_crew(p)
		# Two big wheels and the frame on them.
		for v: float in [-0.34, 0.34]:
			var c: Vector2 = p.call(-0.2, v, 7.5)
			draw_circle(c, 7.5, WOOD_DARK)
			draw_circle(c, 6.0, WOOD)
			for k: int in 4:
				var a := k * PI / 4.0 + time * (2.0 if walking else 0.0)
				draw_line(c - Vector2(cos(a), sin(a)) * 5.5, c + Vector2(cos(a), sin(a)) * 5.5, WOOD_DARK, 1.0)
			draw_circle(c, 1.6, IRON)
		var tail: Vector2 = p.call(-0.7, 0.0, 13.0)
		var nose: Vector2 = p.call(0.7, 0.0, 21.0)
		# The trestle under the nose and the axle beam.
		draw_line(p.call(0.42, -0.12, 0.0), p.call(0.42, 0.0, 19.0), WOOD_DARK, 2.5)
		draw_line(p.call(0.42, 0.12, 0.0), p.call(0.42, 0.0, 19.0), WOOD_DARK, 2.5)
		draw_line(p.call(-0.2, -0.34, 7.5), p.call(-0.2, 0.34, 7.5), WOOD_DARK, 3.0)
		draw_line(p.call(-0.2, 0.0, 7.5), p.call(-0.2, 0.0, 15.0), WOOD_DARK, 3.0)
		# The stock: a long beam with a groove, sloping up to the nose.
		draw_line(tail, nose, WOOD_DARK, 6.0)
		draw_line(tail, nose, WOOD, 4.0)
		draw_line(tail, nose, WOOD.darkened(0.25), 1.0)
		# The arms: bent back from the nose, bound with iron, the string between their tips.
		var tip_a: Vector2 = p.call(0.45, -0.62, 23.0)
		var tip_b: Vector2 = p.call(0.45, 0.62, 23.0)
		var root_a: Vector2 = p.call(0.66, -0.14, 21.5)
		var root_b: Vector2 = p.call(0.66, 0.14, 21.5)
		draw_line(root_a, root_b, IRON, 4.0)
		for pair: Array in [[root_a, tip_a], [root_b, tip_b]]:
			draw_line(pair[0], pair[1], WOOD_DARK, 4.0)
			draw_line(pair[0], pair[1], WOOD.lightened(0.12), 2.0)
			draw_circle(pair[0].lerp(pair[1], 0.5), 1.6, IRON)
		var nut: Vector2 = p.call(-0.35, 0.0, 15.0) if loaded else p.call(0.44, 0.0, 20.5)
		draw_line(tip_a, nut, ROPE, 1.0)
		draw_line(nut, tip_b, ROPE, 1.0)
		if loaded:
			# The bolt in the groove, its iron head at the nose.
			var dir := (nose - tail).normalized()
			draw_line(nut, nose + dir * 4.0, WOOD.lightened(0.3), 2.0)
			draw_line(nose + dir * 2.0, nose + dir * 6.0, IRON, 3.0)
		# The winch at the back.
		draw_circle(tail, 2.5, IRON)
		if crew_behind:
			_crew(p)
		# A small pennon on the nose post: red for the kingdom, black for enemies.
		var pole: Vector2 = p.call(0.42, 0.0, 19.0)
		draw_line(pole, pole - Vector2(0, 12), WOOD_DARK, 1.0)
		draw_colored_polygon(PackedVector2Array([pole - Vector2(0, 12), pole - Vector2(-6, 10),
				pole - Vector2(0, 8)]), Color(0.15, 0.13, 0.12) if hostile else Color(0.7, 0.12, 0.1))

	## Two crewmen at the winch, as tall as the people of the town (pushing while it rolls,
	## winding the winch after a shot): legs, a quilted coat, arms to the winch, a kettle hat.
	func _crew(p: Callable) -> void:
		for v: float in [-0.24, 0.24]:
			var swing := sin(time * 8.0 + v * 10.0) if walking else 0.0
			var foot: Vector2 = p.call(-1.0, v, 0.0)
			var hip := foot - Vector2(0, 14)
			var shoulder := hip - Vector2(0, 13)
			for side: float in [-1.0, 1.0]:
				var f := foot + Vector2(side * 2.0 + swing * side * 1.5, 0)
				draw_line(f, hip + Vector2(side * 1.5, 0), LEG, 3.0)
				draw_line(f, f + Vector2(2.0, 0), OUTLINE, 2.0)
			var body := PackedVector2Array([hip + Vector2(-4.5, 1), hip + Vector2(4.5, 1),
					shoulder + Vector2(4.0, 0), shoulder + Vector2(-4.0, 0)])
			draw_colored_polygon(body, SHIRT)
			draw_line(hip + Vector2(-4.5, -4), hip + Vector2(4.5, -4), SHIRT.darkened(0.2), 1.0)
			var crank := sin(time * 6.0 + v) * 2.0 if not loaded else 0.0
			var hand: Vector2 = p.call(-0.72, v * 0.5, 14.0 + crank)
			draw_line(shoulder + Vector2(-3, 1), hand, SHIRT.darkened(0.12), 2.5)
			draw_line(shoulder + Vector2(3, 1), hand, SHIRT.darkened(0.12), 2.5)
			draw_circle(hand, 1.4, SKIN)
			var head := shoulder - Vector2(0, 4.5)
			draw_circle(head, 4.0, SKIN)
			draw_colored_polygon(PackedVector2Array([head + Vector2(-5.5, -0.5), head + Vector2(5.5, -0.5),
					head + Vector2(3.5, -4.5), head + Vector2(-3.5, -4.5)]), IRON.lightened(0.25))
			draw_line(head + Vector2(-6, 0), head + Vector2(6, 0), IRON, 1.0)
			draw_polyline(PackedVector2Array([hip + Vector2(-4.5, 1), shoulder + Vector2(-4.0, 0),
					shoulder + Vector2(4.0, 0), hip + Vector2(4.5, 1)]), OUTLINE, 1.0)


## A ladder leaning from a ground tile onto the wall.
class _Ladder:
	extends Node2D
	var foot: Vector2i
	var wall: Vector2i

	func _draw() -> void:
		var d := Vector2(wall - foot)
		var across := Vector2(-d.y, d.x) * 0.16
		var base := IsoMath.grid_to_screen(IsoMath.tile_center(foot) - d * 0.1) - position
		var top := IsoMath.grid_to_screen(IsoMath.tile_center(foot) + d * 0.5) - position \
				- Vector2(0, BlockWallModel.HEIGHT + 10.0)
		var sa := IsoMath.grid_to_screen(across) - IsoMath.grid_to_screen(Vector2.ZERO)
		var wood := Color(0.56, 0.41, 0.25)
		var dark := Color(0.28, 0.2, 0.12)
		for side: float in [-1.0, 1.0]:
			draw_line(base + sa * side, top + sa * side, dark, 3.0)
			draw_line(base + sa * side, top + sa * side, wood, 1.5)
		for k: int in range(1, 9):
			var t := k / 9.0
			var c := base.lerp(top, t)
			draw_line(c - sa, c + sa, wood, 1.5)
