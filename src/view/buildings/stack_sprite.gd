class_name StackSprite
extends Sprite2D
## One stack of goods on a tile, showing a fill stage of goods/stacks/<good>.png
## (4 stages side by side, tile diamond in the bottom 32 px, ART_SPEC §2).

const STAGES := 4

static var _sheets: Dictionary[StringName, Texture2D] = {}


func _init() -> void:
	centered = false
	region_enabled = true


## [param sort_shift]: the sprite stands that many pixels below the tile centre (to sort in
## front of a building) while the stack is still drawn on the tile. [param half]: 0 draws only
## the left half of the stack, 1 the right half (yard stacks sort each half on its own),
## -1 the whole stack.
func show_stack(good: StringName, stage: int, sort_shift: float = 0.0, half: int = -1) -> void:
	visible = good != &"" and stage > 0
	if not visible:
		return
	texture = _sheet(good)
	var frame := Vector2(texture.get_width() / float(STAGES), texture.get_height())
	region_rect = Rect2(frame.x * (stage - 1), 0, frame.x, frame.y)
	offset = -Vector2(frame.x / 2.0, frame.y - 16.0 + sort_shift)
	if half >= 0:
		region_rect = Rect2(region_rect.position.x + frame.x / 2.0 * half, 0, frame.x / 2.0, frame.y)
		offset.x = -frame.x / 2.0 + frame.x / 2.0 * half


static func _sheet(good: StringName) -> Texture2D:
	if not _sheets.has(good):
		_sheets[good] = ArtPaths.texture("goods/stacks/%s.png" % good)
	return _sheets[good]
