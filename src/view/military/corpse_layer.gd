class_name CorpseLayer
extends Node2D
## The fallen (M7 part 2): a fighter who dies lies where he fell for a while and fades away.
## Child of the y-sorted world; drawn from his character's first standing frame, laid down.

const LIE_SECONDS := 40.0
const FADE_SECONDS := 6.0
const BLOOD := Color(0.42, 0.05, 0.04, 0.75)

var province: ProvinceSim
var _bodies: Array[Dictionary] = []


func _init() -> void:
	y_sort_enabled = true


func setup(source: ProvinceSim) -> void:
	province = source


func on_sim_event(event: Dictionary) -> void:
	if event["type"] != &"unit_died":
		return
	var kind: StringName = event["kind"]
	var visual := AgentVisualDef.for_kind(kind)
	var character := visual.character if visual != null else kind
	var sheet := CharacterVisual.get_visual(character).get_sheet(&"idle")
	var pos: Vector2 = event["pos"]
	var level: int = event["level"]
	var node := Node2D.new()
	var screen := IsoMath.grid_to_screen(pos)
	var lift := FortLayer.height_at(province, pos, level) if level != 0 else 0.0
	node.position = Vector2(screen.x, screen.y + (2.0 if level != 0 else 0.0))
	var blood := _Blood.new()
	blood.position = Vector2(0, -lift)
	node.add_child(blood)
	var body := Sprite2D.new()
	body.texture = sheet.texture
	body.hframes = sheet.frames
	body.vframes = sheet.rows
	var row_flip := sheet.row_for(int(event["facing"]))
	body.frame = row_flip.x * sheet.frames
	body.flip_h = row_flip.y == 1
	body.centered = false
	body.offset = -Vector2(sheet.foot)
	# Laid on his side: turned about his feet, a little lower.
	body.rotation = -PI / 2.0 if (int(event["agent"]) % 2 == 0) else PI / 2.0
	body.position = Vector2(0, -lift - 4.0)
	body.modulate = Color(0.85, 0.82, 0.8)
	node.add_child(body)
	add_child(node)
	_bodies.append({"node": node, "time": 0.0})


func update_view(delta: float) -> void:
	for i: int in range(_bodies.size() - 1, -1, -1):
		var body := _bodies[i]
		body["time"] = float(body["time"]) + delta
		var node: Node2D = body["node"]
		var t: float = body["time"]
		if t > LIE_SECONDS:
			node.modulate.a = clampf(1.0 - (t - LIE_SECONDS) / FADE_SECONDS, 0.0, 1.0)
			if t > LIE_SECONDS + FADE_SECONDS:
				node.queue_free()
				_bodies.remove_at(i)


class _Blood:
	extends Node2D
	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
		draw_circle(Vector2(4, 0), 7.0, BLOOD)
		draw_circle(Vector2(-3, 2), 4.0, BLOOD)
