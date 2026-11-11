class_name MoodBar
extends Control
## A house's points of needs met (E2 part 3): a bar coloured like its face over the house, with
## marks at the calm points and the upgrade points.

const HEIGHT := 14.0
const BACK := Color(0.2, 0.15, 0.1)
const MARK := Color(0.95, 0.92, 0.82)

var points: float = 0.0
var mood: int = 0


func _init() -> void:
	custom_minimum_size = Vector2(0, HEIGHT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func show_house(building: BuildingState) -> void:
	points = building.house.points if building.house != null else 0.0
	mood = maxi(MoodLayer.mood_of(building), 0)
	tooltip_text = tr("ui.house.mood_bar_tip") % [roundi(Population.CALM_POINTS), roundi(Population.UPGRADE_POINTS)]
	queue_redraw()


func _draw() -> void:
	var w := size.x
	draw_rect(Rect2(0, 0, w, HEIGHT), BACK)
	var colour: Color = [MoodLayer.SAD, MoodLayer.CALM, MoodLayer.HAPPY][mood]
	draw_rect(Rect2(1, 1, (w - 2) * clampf(points / 100.0, 0.0, 1.0), HEIGHT - 2), colour)
	for mark: float in [Population.CALM_POINTS, Population.UPGRADE_POINTS]:
		var x := roundf((w - 2) * mark / 100.0) + 1
		draw_line(Vector2(x, 0), Vector2(x, HEIGHT), MARK, 2.0)
