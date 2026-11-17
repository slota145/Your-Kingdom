class_name BuildingMark
extends Node2D
## A badge over a building that needs the player (friend's playtest 2026-11-17, M10 part 5):
## red with a worker when people are missing, gold with a pause sign when the player paused
## it. Hovering it (or the building) shows what it means (GameScene).

enum Kind { NO_WORKERS, PAUSED }

const RADIUS := 12.0
const RED := Color(0.78, 0.16, 0.1)
const GOLD := Color(0.93, 0.7, 0.18)
const RIM := Color(0.12, 0.07, 0.04)

var kind: Kind = Kind.NO_WORKERS:
	set(value):
		kind = value
		queue_redraw()

static var _icons: Dictionary[Kind, Texture2D] = {}


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS + 2.0, RIM)
	draw_circle(Vector2.ZERO, RADIUS, RED if kind == Kind.NO_WORKERS else GOLD)
	draw_arc(Vector2.ZERO, RADIUS - 1.0, 0.0, TAU, 24, Color(1, 1, 1, 0.35), 1.0)
	var icon := icon_for(kind)
	if icon != null:
		draw_texture(icon, -icon.get_size() * 0.5)
	if kind == Kind.NO_WORKERS:
		# A small minus beside the worker: one is missing.
		draw_rect(Rect2(Vector2(4, -10), Vector2(7, 3)), RIM)
		draw_rect(Rect2(Vector2(5, -9), Vector2(5, 1)), Color.WHITE)


## Whether [param world_pos] is on the badge.
func covers(world_pos: Vector2) -> bool:
	return visible and world_pos.distance_to(global_position) <= RADIUS + 3.0


static func icon_for(which: Kind) -> Texture2D:
	if not _icons.has(which):
		var name := "workers" if which == Kind.NO_WORKERS else "pause"
		var path := "res://assets/ui/icon_%s.png" % name
		_icons[which] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _icons[which]
