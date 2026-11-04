extends Node2D
## WALLS PROTOTYPE: draws the pieces of a block wall model procedurally (no art files).
## Child of the y-sorted world; every piece is its own node with its own sort point.

const Model := preload("res://src/prototype/walls/block_wall_model.gd")

const STONE := Color(0.66, 0.64, 0.6)
const DECK := Color(0.56, 0.54, 0.5)
const COURSE := 8.0
const JOINT_PERIOD := 0.25


class PieceNode:
	extends Node2D
	var piece: Model.Piece
	var color: Color

	func _draw() -> void:
		var poly := piece.poly
		var n := poly.size()
		var center := piece.centroid()
		var outline := color.darkened(0.6)
		for i: int in n:
			var state := piece.edges[i]
			if state != Model.Edge.EXPOSED and state != Model.Edge.FACE_ONLY:
				continue
			var a := poly[i]
			var b := poly[(i + 1) % n]
			var normal := (b - a).orthogonal().normalized()
			if normal.dot((a + b) * 0.5 - center) < 0.0:
				normal = -normal
			if normal.dot(Vector2(1, 1)) <= 0.001:
				continue
			# Faces turned towards grid +y (screen left) are lit, towards +x darker.
			var shade := color.darkened(0.35 - 0.25 * clampf(normal.y - normal.x + 0.5, 0.0, 1.0))
			var sa := _screen(a)
			var sb := _screen(b)
			var face := PackedVector2Array([sa - Vector2(0, piece.z0), sb - Vector2(0, piece.z0),
					sb - Vector2(0, piece.z1), sa - Vector2(0, piece.z1)])
			draw_colored_polygon(face, shade)
			_courses(a, b, shade.darkened(0.18))
			draw_line(face[0], face[1], outline)
			if piece.edges[(i + n - 1) % n] != Model.Edge.JOINED:
				draw_line(face[0], face[3], outline)
			if piece.edges[(i + 1) % n] != Model.Edge.JOINED:
				draw_line(face[1], face[2], outline)
		var top := PackedVector2Array()
		for p: Vector2 in poly:
			top.append(_screen(p) - Vector2(0, piece.z1))
		draw_colored_polygon(top, color.lightened(0.15))
		for i: int in n:
			if piece.edges[i] == Model.Edge.EXPOSED:
				draw_line(top[i], top[(i + 1) % n], outline)

	## Mortar lines: horizontal courses, and staggered vertical joints on axis-aligned faces.
	func _courses(a: Vector2, b: Vector2, mortar: Color) -> void:
		if piece.kind == &"merlon":
			return
		var sa := _screen(a)
		var sb := _screen(b)
		var axis := -1
		if is_equal_approx(a.x, b.x):
			axis = 1
		elif is_equal_approx(a.y, b.y):
			axis = 0
		var z := piece.z0 + COURSE
		var row := int(piece.z0 / COURSE)
		while z < piece.z1 - 1.0:
			draw_line(sa - Vector2(0, z), sb - Vector2(0, z), mortar)
			row += 1
			z += COURSE
		if axis < 0:
			return
		var s0 := minf(a[axis], b[axis])
		var s1 := maxf(a[axis], b[axis])
		row = int(piece.z0 / COURSE)
		z = piece.z0
		while z < piece.z1 - 1.0:
			var z_top := minf(z + COURSE, piece.z1)
			var shift := JOINT_PERIOD * 0.5 if row % 2 == 1 else 0.0
			var s := ceilf((s0 - shift) / JOINT_PERIOD) * JOINT_PERIOD + shift
			while s < s1 - 0.01:
				if s > s0 + 0.01:
					var g := a.lerp(b, (s - a[axis]) / (b[axis] - a[axis]))
					var sg := _screen(g)
					draw_line(sg - Vector2(0, z + 1.0), sg - Vector2(0, z_top - 1.0), mortar)
				s += JOINT_PERIOD
			row += 1
			z += COURSE

	func _screen(g: Vector2) -> Vector2:
		return IsoMath.grid_to_screen(g) - position


func _init() -> void:
	y_sort_enabled = true


func rebuild(model: Model) -> void:
	for child: Node in get_children():
		child.queue_free()
	for piece: Model.Piece in model.build():
		var node := PieceNode.new()
		node.piece = piece
		node.color = STONE
		node.position = piece.sort_point
		add_child(node)
