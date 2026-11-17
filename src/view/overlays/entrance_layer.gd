class_name EntranceLayer
extends Node2D
## The entrances of the buildings while a road is being laid (M10 part 5, friend's playtest
## 2026-11-17): the tile in front of every door gets a mark, green when a road already reaches
## it and red when not, so the player sees where to take the road. Roads are not required
## (people walk anywhere), but they walk faster on them.

const REDRAW := 0.4
const RED := Color(0.86, 0.22, 0.14)
const GREEN := Color(0.3, 0.78, 0.28)

var province: ProvinceSim
var _time: float = 0.0


func _init() -> void:
	visible = false
	z_index = -1   # on the ground, like the other tile marks


func update_view(delta: float) -> void:
	if not visible:
		return
	_time -= delta
	if _time <= 0.0:
		_time = REDRAW
		queue_redraw()


func show_entrances(on: bool) -> void:
	if on != visible:
		visible = on
		_time = 0.0


## The tiles in front of the doors of every building and site: tile -> whether a road is there.
static func entrances(source: ProvinceSim) -> Dictionary[Vector2i, bool]:
	var result: Dictionary[Vector2i, bool] = {}
	for building: BuildingState in source.buildings.all():
		if building.def.is_port() or building.def.footprint == Vector2i.ONE:
			continue   # quay pieces and bollards: no door to bring a road to
		for o: int in building.def.door_orientations(building.orientation):
			var front := building.def.door_front(building.origin, o)
			if source.grid.is_inside(front) and source.grid.occupant(front) == 0:
				result[front] = source.grid.has_road(front)
	return result


func _draw() -> void:
	if province == null:
		return
	var marks := entrances(province)
	for tile: Vector2i in marks:
		var c := IsoMath.tile_center_screen(tile)
		var colour := GREEN if marks[tile] else RED
		var diamond := PackedVector2Array([c + Vector2(0, -IsoMath.HALF_H), c + Vector2(IsoMath.HALF_W, 0),
				c + Vector2(0, IsoMath.HALF_H), c + Vector2(-IsoMath.HALF_W, 0)])
		draw_colored_polygon(diamond, Color(colour, 0.35))
		diamond.append(diamond[0])
		draw_polyline(diamond, colour, 2.0)
		# A small door sign in the middle.
		draw_rect(Rect2(c + Vector2(-4, -7), Vector2(8, 10)), Color(0.12, 0.07, 0.04))
		draw_rect(Rect2(c + Vector2(-3, -6), Vector2(6, 9)), colour)
