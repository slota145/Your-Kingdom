extends Node2D
## WALLS PROTOTYPE: draws the pieces of a block wall model procedurally (no art files).
## Child of the y-sorted world; every piece is its own node with its own sort point.

const Model := preload("res://src/prototype/walls/block_wall_model.gd")
const _Props := preload("res://src/prototype/walls/pixellab_props.gd")

const STONE := Color(0.66, 0.64, 0.6)
const GATEHOUSE_STONE := Color(0.7, 0.66, 0.58)
const ROOF_WOOD := Color(0.47, 0.36, 0.25)
const DARK := Color(0.12, 0.1, 0.09)
const IRON := Color(0.22, 0.2, 0.2)
const DECK := Color(0.56, 0.54, 0.5)
const COURSE := 8.0
const JOINT_PERIOD := 0.25


## Optional textures cut from a PixelLab repaint (repaint_skin.gd); null = flat colours.
var skin: RefCounted = null


class PieceNode:
	extends Node2D
	var piece: Model.Piece
	var color: Color
	var skin: RefCounted = null

	func _draw() -> void:
		var poly := piece.poly
		var n := poly.size()
		var center := piece.centroid()
		var outline: Color = skin.outline if skin != null else color.darkened(0.6)
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
			if skin != null:
				_textured_face(face, a, b, normal)
			else:
				draw_colored_polygon(face, shade)
				_courses(a, b, shade.darkened(0.18))
			if piece.kind == &"gh_deck" and state == Model.Edge.EXPOSED:
				_arch(a, b, shade)
			elif piece.kind == &"gh_side" and state == Model.Edge.EXPOSED:
				_arrow_slit(a, b)
			draw_line(face[0], face[1], outline)
			if piece.edges[(i + n - 1) % n] != Model.Edge.JOINED:
				draw_line(face[0], face[3], outline)
			if piece.edges[(i + 1) % n] != Model.Edge.JOINED:
				draw_line(face[1], face[2], outline)
		var top := PackedVector2Array()
		for p: Vector2 in poly:
			top.append(_screen(p) - Vector2(0, piece.z1))
		var is_roof := piece.kind == &"gh_side" or piece.kind == &"gh_deck"
		if skin != null:
			var t: RefCounted = skin.top
			var uvs := PackedVector2Array()
			for p: Vector2 in poly:
				uvs.append((p - t.origin) / t.period)
			draw_polygon(top, PackedColorArray([Color.WHITE]), uvs, t.texture)
		else:
			draw_colored_polygon(top, ROOF_WOOD if is_roof else color.lightened(0.15))
		if is_roof:
			_planks(top)
		for i: int in n:
			if piece.edges[i] == Model.Edge.EXPOSED:
				draw_line(top[i], top[(i + 1) % n], outline)

	## Face drawn with a repaint sample: lit sample for faces turned to grid +y (also the
	## diagonal faces, slightly darker), dark sample for faces turned to grid +x.
	func _textured_face(face: PackedVector2Array, a: Vector2, b: Vector2, normal: Vector2) -> void:
		var s: RefCounted = skin.dark if normal.x > 0.9 else skin.lit
		var ua: float
		var ub: float
		if normal.x > 0.9:
			ua = a.y
			ub = b.y
		elif normal.y > 0.9:
			ua = a.x
			ub = b.x
		else:
			ua = a.x - a.y
			ub = b.x - b.y
		ua = (ua - (s.origin.y if normal.x > 0.9 else s.origin.x)) / s.period.x
		ub = (ub - (s.origin.y if normal.x > 0.9 else s.origin.x)) / s.period.x
		var v0: float = (s.height - piece.z0) / s.height
		var v1: float = (s.height - piece.z1) / s.height
		var uvs := PackedVector2Array([Vector2(ua, v0), Vector2(ub, v0), Vector2(ub, v1), Vector2(ua, v1)])
		var tint := Color.WHITE if absf(normal.x) > 0.9 or absf(normal.y) > 0.9 else Color(0.9, 0.9, 0.9)
		draw_polygon(face, PackedColorArray([tint]), uvs, s.texture)

	## Wooden roof boards across the box (top polygon corners: back u0, back u1, front u1, front u0).
	func _planks(top: PackedVector2Array) -> void:
		var line := ROOF_WOOD.darkened(0.3)
		for k: int in range(1, 6):
			var t := k / 6.0
			draw_line(top[0].lerp(top[1], t), top[3].lerp(top[2], t), line)

	## Arched opening on the face of a gatehouse deck: stone spandrels curving down from the
	## lintel to the jambs, and a raised portcullis showing under the arch.
	func _arch(a: Vector2, b: Vector2, shade: Color) -> void:
		var lintel := piece.z0
		var drop := 16.0
		var curve := PackedVector2Array()
		var steps := 12
		for k: int in steps + 1:
			var t := float(k) / steps
			var u := absf(t - 0.5) * 2.0
			curve.append(_screen(a.lerp(b, t)) - Vector2(0, lintel - drop * u * u * u))
		# Portcullis bars hanging a little below the arch.
		for k: int in range(1, steps):
			var p := curve[k]
			draw_line(p, p + Vector2(0, 7), IRON, 2.0)
		draw_line(curve[1] + Vector2(0, 5), curve[steps - 1] + Vector2(0, 5), IRON)
		for k: int in 2:
			# Two halves keep each polygon simple (the arch is concave as a whole).
			var half := PackedVector2Array()
			var from := 0 if k == 0 else steps / 2
			for m: int in range(from, from + steps / 2 + 1):
				half.append(curve[m])
			half.append(_screen(a.lerp(b, float(from + steps / 2) / steps)) - Vector2(0, lintel))
			half.append(_screen(a.lerp(b, float(from) / steps)) - Vector2(0, lintel))
			draw_colored_polygon(half, shade)
		draw_polyline(curve, color.darkened(0.6))

	## Cross-shaped arrow slit in the middle of a gatehouse face.
	func _arrow_slit(a: Vector2, b: Vector2) -> void:
		var mid := _screen((a + b) * 0.5) - Vector2(0, piece.z1 * 0.62)
		draw_rect(Rect2(mid + Vector2(-1, -8), Vector2(2, 16)), DARK)
		draw_rect(Rect2(mid + Vector2(-4, -3), Vector2(8, 2)), DARK)

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
	var pieces := model.build()
	if skin != null:
		for origin: Vector2i in model.gatehouses:
			var flipped: bool = model.gatehouses[origin] != Vector2i(0, 1)
			var tex: Texture2D = skin.gatehouse_flipped if flipped else skin.gatehouse
			var pivot: Vector2i = skin.gatehouse_pivot
			if flipped:
				pivot.x = tex.get_width() - pivot.x
			add_child(_Props.sliced(tex, origin, Vector2i(3, 3), pivot))
	for piece: Model.Piece in pieces:
		if skin != null and model.gatehouse_tiles.has(piece.tile):
			if String(piece.kind).begins_with("gh_"):
				continue
			# Battlements on top of gatehouse art: drawn after the whole building (whose strips
			# sort at most at its front vertex), keeping their order among themselves.
			var origin: Vector2i = model.gatehouse_tiles[piece.tile]
			var back := IsoMath.grid_to_screen(Vector2(origin)).y
			var front := IsoMath.grid_to_screen(Vector2(origin + Vector2i(3, 3))).y
			piece.sort_point.y += front - back + 1.0
		var node := PieceNode.new()
		node.skin = skin
		node.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		node.piece = piece
		node.color = GATEHOUSE_STONE if String(piece.kind).begins_with("gh_") else STONE
		if piece.kind == &"merlon" and model.gatehouse_tiles.has(piece.tile):
			node.color = GATEHOUSE_STONE
		if piece.kind == &"merlon" and skin != null:
			node.color = skin.merlon_color
		node.position = piece.sort_point
		add_child(node)
