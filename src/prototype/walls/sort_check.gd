extends SceneTree
## WALLS PROTOTYPE: checks block wall sort points against true isometric depth for a
## person walking anywhere on the ground around them (same method as test_sorting.gd).
## Run: "$GODOT" --headless --path . -s res://src/prototype/walls/sort_check.gd

const Model := preload("res://src/prototype/walls/block_wall_model.gd")


func _init() -> void:
	var scenarios := {
		"straight x": _line(Vector2i(0, 0), Vector2i(1, 0), 6),
		"straight y": _line(Vector2i(0, 0), Vector2i(0, 1), 6),
		"thick 2 x": _rect(Vector2i(0, 0), Vector2i(6, 1)),
		"thick 3 y": _rect(Vector2i(0, 0), Vector2i(2, 6)),
		"diagonal screen vertical": _line(Vector2i(0, 0), Vector2i(1, 1), 6),
		"diagonal screen horizontal": _line(Vector2i(0, 6), Vector2i(1, -1), 6),
		"thick diagonal vertical": _merge(_line(Vector2i(0, 0), Vector2i(1, 1), 6),
				_line(Vector2i(1, 0), Vector2i(1, 1), 6)),
		"thick diagonal horizontal": _merge(_line(Vector2i(0, 6), Vector2i(1, -1), 6),
				_line(Vector2i(1, 6), Vector2i(1, -1), 6)),
		"corner 90": _merge(_line(Vector2i(0, 0), Vector2i(1, 0), 4), _line(Vector2i(3, 1), Vector2i(0, 1), 3)),
		"corners 45 / 135": _merge(_line(Vector2i(0, 4), Vector2i(1, 0), 4), _line(Vector2i(4, 3), Vector2i(1, -1), 3),
				_line(Vector2i(0, 8), Vector2i(1, 0), 4), _line(Vector2i(4, 9), Vector2i(1, 1), 3)),
		"tee": _merge(_rect(Vector2i(0, 0), Vector2i(6, 1)), _line(Vector2i(3, 2), Vector2i(0, 1), 3)),
		"gate in single wall x": _gate(_line(Vector2i(0, 0), Vector2i(1, 0), 5), [Vector2i(2, 0)]),
		"gate in single wall y": _gate(_line(Vector2i(0, 0), Vector2i(0, 1), 5), [Vector2i(0, 2)]),
		"gate in thick wall": _gate(_rect(Vector2i(0, 0), Vector2i(4, 1)), [Vector2i(2, 0), Vector2i(2, 1)]),
		"gate in thick wall y": _gate(_rect(Vector2i(0, 0), Vector2i(1, 4)), [Vector2i(0, 2), Vector2i(1, 2)]),
	}
	var total := 0
	for leg: float in [0.0, 0.5, 1.0]:
		for name: String in scenarios:
			var failures := _check(scenarios[name], leg, 0.0)
			total += failures.size()
			if not failures.is_empty():
				print("FAIL [wedge %.1f] %s: %d\n  %s" % [leg, name, failures.size(),
						"\n  ".join(failures.slice(0, 6))])
	# Control: shifted sort points must be detected.
	var control := _check(scenarios["thick 2 x"], 0.5, 40.0).size() \
			+ _check(scenarios["diagonal screen horizontal"], 1.0, -40.0).size()
	print("SORT_CHECK failures=%d control_detected=%d" % [total, control])
	quit(1 if total > 0 or control == 0 else 0)


func _check(walls: Dictionary, leg: float, key_bias: float) -> PackedStringArray:
	var model := Model.new()
	model.walls.assign(walls)
	model.wedge_leg = leg
	var pieces := model.build()
	var blocked := model.blocked_tiles()
	var bounds := Rect2i(walls.keys()[0], Vector2i.ONE)
	for w: Vector2i in walls:
		bounds = bounds.expand(w).expand(w + Vector2i.ONE)
	var failures := PackedStringArray()
	for p: Vector2 in DepthOracle.walk_samples(bounds.grow(2), func(t: Vector2i) -> bool: return blocked.has(t)):
		var a := IsoMath.grid_to_screen(p)
		for piece: Model.Piece in pieces:
			var x0 := INF
			var x1 := -INF
			var y0 := INF
			var y1 := -INF
			for g: Vector2 in piece.poly:
				var s := IsoMath.grid_to_screen(g)
				x0 = minf(x0, s.x)
				x1 = maxf(x1, s.x)
				y0 = minf(y0, s.y)
				y1 = maxf(y1, s.y)
			var c0 := maxf(a.x - DepthOracle.AGENT_HALF_WIDTH, x0)
			var c1 := minf(a.x + DepthOracle.AGENT_HALF_WIDTH, x1)
			if c0 >= c1 or a.y <= y0 - piece.z1 or a.y - DepthOracle.AGENT_HEIGHT >= y1 - piece.z0:
				continue
			var rel := DepthOracle.relation(p, piece.poly, c0, c1)
			var key := piece.sort_point.y + key_bias
			if (rel == DepthOracle.IN_FRONT and a.y <= key) or (rel == DepthOracle.BEHIND and a.y >= key):
				failures.append("agent %s (y=%.1f) %s %s@%s (key %.1f)" % [p, a.y,
						"in front of" if rel == DepthOracle.IN_FRONT else "behind", piece.kind, piece.tile, key])
	return failures


func _line(start: Vector2i, step: Vector2i, n: int) -> Dictionary:
	var walls := {}
	for i: int in n:
		walls[start + step * i] = false
	return walls


func _rect(from: Vector2i, to: Vector2i) -> Dictionary:
	var walls := {}
	for x: int in range(from.x, to.x + 1):
		for y: int in range(from.y, to.y + 1):
			walls[Vector2i(x, y)] = false
	return walls


func _merge(a: Dictionary, b: Dictionary, c: Dictionary = {}, d: Dictionary = {}) -> Dictionary:
	var walls := a.duplicate()
	walls.merge(b)
	walls.merge(c)
	walls.merge(d)
	return walls


func _gate(walls: Dictionary, gates: Array[Vector2i]) -> Dictionary:
	for g: Vector2i in gates:
		walls[g] = true
	return walls
