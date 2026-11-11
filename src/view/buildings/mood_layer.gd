class_name MoodLayer
extends Node2D
## How content the households are (E2 part 3, owner's survey 2026-11-11: a face over the house
## and a bar in its panel): a small face over each house, red and sad when it is hungry or
## below the calm points, yellow when calm, green and smiling when it has enough to upgrade.
## Restless houses always show theirs; all houses do while [member show_all] is on (the
## "Contentment" button of the top bar). Drawn by code over the buildings.

const RADIUS := 6.0
## Pixels above the centre of the house's footprint (where the missing-workers mark sits).
const LIFT := 92.0
const SAD := Color(0.86, 0.26, 0.2)
const CALM := Color(0.95, 0.78, 0.25)
const HAPPY := Color(0.42, 0.78, 0.3)
const INK := Color(0.12, 0.08, 0.06)
## Seconds between two redraws (houses update once a second).
const REDRAW := 0.5

var province: ProvinceSim
var show_all: bool = false:
	set(value):
		show_all = value
		queue_redraw()
var _clock: float = 0.0


func _init() -> void:
	z_index = 10


func setup(source: ProvinceSim) -> void:
	province = source


func update_view(delta: float) -> void:
	_clock += delta
	if _clock >= REDRAW:
		_clock = 0.0
		queue_redraw()


## 0 = sad, 1 = calm, 2 = happy, -1 = no face (empty or unfinished house).
static func mood_of(building: BuildingState) -> int:
	var house := building.house
	if house == null or not building.is_complete() or house.residents == 0:
		return -1
	if not Population.is_fed(building) or house.points < Population.CALM_POINTS:
		return 0
	return 2 if house.points >= Population.UPGRADE_POINTS else 1


func _draw() -> void:
	if province == null:
		return
	for building: BuildingState in province.buildings.all():
		var mood := mood_of(building)
		if mood < 0 or (mood > 0 and not show_all):
			continue
		var at := IsoMath.grid_to_screen(Vector2(building.origin) + Vector2(building.def.footprint) * 0.5) \
				- Vector2(0, LIFT)
		_face(at, mood)


func _face(at: Vector2, mood: int) -> void:
	var colour: Color = [SAD, CALM, HAPPY][mood]
	draw_circle(at, RADIUS + 1.0, INK)
	draw_circle(at, RADIUS, colour)
	draw_rect(Rect2(at + Vector2(-3, -2), Vector2(1, 2)), INK)
	draw_rect(Rect2(at + Vector2(2, -2), Vector2(1, 2)), INK)
	match mood:
		0:
			draw_arc(at + Vector2(0, 4.5), 2.6, PI * 1.15, PI * 1.85, 6, INK, 1.0)
		1:
			draw_line(at + Vector2(-2.5, 2.5), at + Vector2(2.5, 2.5), INK, 1.0)
		2:
			draw_arc(at + Vector2(0, 0.5), 3.0, PI * 0.15, PI * 0.85, 6, INK, 1.0)
