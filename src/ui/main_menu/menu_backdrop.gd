class_name MenuBackdrop
extends Control
## The living picture of the main menu (ROADMAP UI-1, owner's decision 2026-11-07): the harbour
## from PixelLab in layers (assets/ui/menu/, tools/split_menu_art.py). The sky moves a little
## with the mouse, the town and the sea a little more; clouds drift over the sky behind the
## town, the open sea glitters, smoke rises from the chimneys and gulls circle. Everything is
## drawn at art resolution and scaled to cover the window with whole pixels where it can.

const ART := "res://assets/ui/menu/"
## Size of the picture and the edge repeated around each layer (tools/split_menu_art.py).
const ART_SIZE := Vector2(640, 360)
const PAD := 8.0
## How far (art pixels) each layer moves when the mouse goes from the centre to an edge.
## Never more than PAD: the mirrored margin of each layer hides the picture's edge.
const SKY_SHIFT := 2.0
const LAND_SHIFT := 5.0
## Time (s) the layers take to catch up with the mouse: they ease in and out like on a
## spring instead of jumping (review fix 2026-11-07).
const FOLLOW_TIME := 0.45
## Chimneys the smoke rises from (art pixels of the picture).
const CHIMNEYS: Array[Vector2] = [Vector2(498, 142), Vector2(606, 157), Vector2(455, 172)]
const SMOKE_EVERY := 0.45
const GULLS := 4

var _sky: Texture2D
var _land: Texture2D
var _water: TextureRect
var _scale: float = 2.0
var _origin: Vector2 = Vector2.ZERO
var _mouse: Vector2 = Vector2.ZERO
var _mouse_speed: Vector2 = Vector2.ZERO
var _time: float = 0.0
var _smoke_timer: float = 0.0
## Puffs of smoke: [position, age, life, size].
var _puffs: Array[Array] = []
## Clouds drifting behind the town: [position, speed, width].
var _clouds: Array[Array] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sky = load(ART + "sky.png") as Texture2D
	_land = load(ART + "land.png") as Texture2D
	_rng.seed = 7
	for i: int in 3:
		_clouds.append([Vector2(_rng.randf_range(0, ART_SIZE.x), _rng.randf_range(30, 120)),
				_rng.randf_range(2.0, 4.5), _rng.randf_range(24, 44)])
	# The open sea glitters: a shader on the sea mask, drawn over the land layer.
	_water = TextureRect.new()
	_water.texture = load(ART + "water.png") as Texture2D
	_water.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_water.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_water.stretch_mode = TextureRect.STRETCH_SCALE
	var material := ShaderMaterial.new()
	material.shader = load("res://src/ui/main_menu/water_glint.gdshader") as Shader
	_water.material = material
	add_child(_water)
	resized.connect(_layout)
	_layout()


## Covers the control with the picture: whole-number scales when they cover, else the
## smallest scale that does.
func _layout() -> void:
	var need := maxf(size.x / ART_SIZE.x, size.y / ART_SIZE.y)
	_scale = ceilf(need) if ceilf(need) - need < 0.35 else need
	_origin = (size - ART_SIZE * _scale) / 2.0


func _process(delta: float) -> void:
	_time += delta
	var centre := size / 2.0
	var target := Vector2.ZERO
	if size.x > 0.0 and size.y > 0.0:
		target = ((get_local_mouse_position() - centre) / centre).clamp(Vector2(-1, -1), Vector2(1, 1))
	_follow(target, delta)
	for cloud: Array in _clouds:
		var at: Vector2 = cloud[0]
		at.x += float(cloud[1]) * delta
		if at.x > ART_SIZE.x + 60.0:
			at = Vector2(-60.0, _rng.randf_range(30, 120))
		cloud[0] = at
	_smoke_timer -= delta
	if _smoke_timer <= 0.0:
		_smoke_timer = SMOKE_EVERY
		var chimney := CHIMNEYS[_rng.randi() % CHIMNEYS.size()]
		_puffs.append([chimney, 0.0, _rng.randf_range(3.0, 4.5), _rng.randf_range(1.5, 2.5)])
	for puff: Array in _puffs:
		puff[1] = float(puff[1]) + delta
		var p: Vector2 = puff[0]
		puff[0] = p + Vector2(2.2, -4.0) * delta
	_puffs = _puffs.filter(func(puff: Array) -> bool: return float(puff[1]) < float(puff[2]))
	var land_at := _layer_origin(LAND_SHIFT)
	_water.position = land_at - Vector2(PAD, PAD) * _scale
	_water.size = (ART_SIZE + Vector2(PAD, PAD) * 2.0) * _scale
	queue_redraw()


## Moves _mouse towards [param target] on a critically damped spring (no overshoot): it
## speeds up gently, slows down before it arrives and never jumps, even after a long frame.
func _follow(target: Vector2, delta: float) -> void:
	var omega := 2.0 / FOLLOW_TIME
	var x := omega * delta
	var decay := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change := _mouse - target
	var temp := (_mouse_speed + change * omega) * delta
	_mouse_speed = (_mouse_speed - temp * omega) * decay
	_mouse = target + (change + temp) * decay


## Top-left corner (screen) of the picture's own area for a layer moving [param shift] pixels.
func _layer_origin(shift: float) -> Vector2:
	return (_origin - _mouse * shift * _scale).round()


func _art(at: Vector2, origin: Vector2) -> Vector2:
	return origin + (at * _scale).round()


func _draw() -> void:
	var sky_at := _layer_origin(SKY_SHIFT)
	var padded := (ART_SIZE + Vector2(PAD, PAD) * 2.0) * _scale
	draw_texture_rect(_sky, Rect2(sky_at - Vector2(PAD, PAD) * _scale, padded), false)
	for cloud: Array in _clouds:
		_draw_cloud(_art(cloud[0], sky_at), float(cloud[2]) * _scale)
	var land_at := _layer_origin(LAND_SHIFT)
	draw_texture_rect(_land, Rect2(land_at - Vector2(PAD, PAD) * _scale, padded), false)
	for puff: Array in _puffs:
		var t := float(puff[1]) / float(puff[2])
		var r := (float(puff[3]) + t * 3.0) * _scale
		draw_rect(Rect2(_art(puff[0], land_at) - Vector2(r, r) / 2.0, Vector2(r, r)).abs(),
				Color(0.86, 0.86, 0.84, 0.55 * (1.0 - t)))
	for i: int in GULLS:
		_draw_gull(i, sky_at)


## A small round cloud (behind the town: drawn before the land layer): rows of art pixels,
## widest at the bottom, a light top and a bluish shadow line under it.
func _draw_cloud(at: Vector2, width: float) -> void:
	var s := _scale
	var w := roundi(width / s)
	var rows := [0.55, 0.8, 0.95, 1.0, 1.0, 0.9]
	for i: int in rows.size():
		var row_w := roundi(w * float(rows[i]))
		var left := at + Vector2(roundi((w - row_w) / 2.0) * s, (i - rows.size()) * s)
		var colour := Color(1.0, 1.0, 0.97, 0.9) if i < 3 else Color(0.95, 0.96, 0.98, 0.9)
		draw_rect(Rect2(left, Vector2(row_w * s, s)), colour)
	draw_rect(Rect2(at + Vector2(roundi(w * 0.1) * s, 0), Vector2(roundi(w * 0.8) * s, s)),
			Color(0.78, 0.85, 0.94, 0.85))


## A gull circling: a dark "v" whose wings beat.
func _draw_gull(i: int, sky_at: Vector2) -> void:
	var t := _time * (0.18 + i * 0.03) + i * 1.7
	var centre := Vector2(180.0 + i * 70.0, 70.0 + (i % 2) * 30.0)
	var at := _art(centre + Vector2(cos(t) * (40.0 + i * 8.0), sin(t * 1.3) * 14.0), sky_at)
	var up := 1.0 if fmod(_time * 4.0 + i, 1.0) < 0.5 else -0.5
	var s := _scale
	var colour := Color(0.18, 0.2, 0.26)
	draw_rect(Rect2(at, Vector2(s, s)), colour)
	draw_rect(Rect2(at + Vector2(-s, -up * s), Vector2(s, s)), colour)
	draw_rect(Rect2(at + Vector2(s, -up * s), Vector2(s, s)), colour)
	draw_rect(Rect2(at + Vector2(-2.0 * s, -up * s), Vector2(s, s)), colour)
	draw_rect(Rect2(at + Vector2(2.0 * s, -up * s), Vector2(s, s)), colour)
