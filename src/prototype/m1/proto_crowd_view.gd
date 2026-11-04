class_name ProtoCrowdView
extends Node2D
## M1 PROTOTYPE ONLY: pooled sprites for the visible part of a ProtoCrowd
## (ARCHITECTURE §6.4). Child of the y-sorted world.

const VIEW_MARGIN := 96.0

var visible_count: int = 0
## Duration of the last update in microseconds.
var last_update_usec: int = 0

var _pool: Array[AgentSprite] = []
var _categories: Dictionary[StringName, String] = {}


func _init() -> void:
	y_sort_enabled = true


func update_view(crowd: ProtoCrowd, alpha: float, world_rect: Rect2, time: float) -> void:
	var start := Time.get_ticks_usec()
	var rect := world_rect.grow(VIEW_MARGIN)
	var used := 0
	for i: int in crowd.count:
		var grid := crowd.prev[i].lerp(crowd.pos[i], alpha)
		var screen := IsoMath.grid_to_screen(grid)
		if not rect.has_point(screen):
			continue
		var sprite := _sprite(used)
		used += 1
		# Small stable offset so people sharing a tile do not overlap exactly.
		var jitter := Vector2(float((i * 7) % 9) - 4.0, float((i * 5) % 5) - 2.0)
		sprite.position = screen + jitter
		var good := crowd.good[i]
		var walking := crowd.moving[i] == 1
		var category := _category(good)
		var anim := &"idle"
		if walking:
			anim = StringName("walk_carry_" + category) if good != &"" else &"walk"
		sprite.show_state(CharacterVisual.get_visual(crowd.character[i]), anim,
				crowd.facing[i], time + i * 0.137, category, good if walking else &"")
	for j: int in range(used, _pool.size()):
		_pool[j].visible = false
	visible_count = used
	last_update_usec = Time.get_ticks_usec() - start


func _sprite(index: int) -> AgentSprite:
	if index >= _pool.size():
		var sprite := AgentSprite.new()
		add_child(sprite)
		_pool.append(sprite)
	var s := _pool[index]
	s.visible = true
	return s


func _category(good: StringName) -> String:
	if good == &"":
		return ""
	if not _categories.has(good):
		var def := Data.registry.get_good(good)
		_categories[good] = def.carry_category if def != null else "crate"
	return _categories[good]
