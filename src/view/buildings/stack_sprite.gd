class_name StackSprite
extends Sprite2D
## One stack of goods on a tile, showing a fill stage of goods/stacks/<good>.png
## (4 stages side by side, tile diamond in the bottom 32 px, ART_SPEC §2).

const STAGES := 4

static var _sheets: Dictionary[StringName, Texture2D] = {}


func _init() -> void:
	centered = false
	region_enabled = true


func show_stack(good: StringName, stage: int) -> void:
	visible = good != &"" and stage > 0
	if not visible:
		return
	texture = _sheet(good)
	var frame := Vector2(texture.get_width() / float(STAGES), texture.get_height())
	region_rect = Rect2(frame.x * (stage - 1), 0, frame.x, frame.y)
	offset = -Vector2(frame.x / 2.0, frame.y - 16.0)


static func _sheet(good: StringName) -> Texture2D:
	if not _sheets.has(good):
		_sheets[good] = ArtPaths.texture("goods/stacks/%s.png" % good)
	return _sheets[good]
