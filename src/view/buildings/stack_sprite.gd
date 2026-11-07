class_name StackSprite
extends Sprite2D
## One stack of goods on a tile, showing a fill stage of goods/stacks/<good>.png
## (frames FRAME_W wide side by side, tile diamond in the bottom 32 px, ART_SPEC §2/§8).
## G2: the sheet has as many frames as it has stages: one per piece for the goods drawn by
## PixelLab (stack_size frames), 4 for the older sheets (25/50/75/100%).

const FRAME_W := 64

static var _sheets: Dictionary[StringName, Texture2D] = {}


func _init() -> void:
	centered = false
	region_enabled = true


## Shows [param amount] of [param capacity] pieces (a slot's stack_size).
## [param sort_shift]: the sprite stands that many pixels below the tile centre (to sort in
## front of a building) while the stack is still drawn on the tile. [param half]: 0 draws only
## the left half of the stack, 1 the right half (yard stacks sort each half on its own),
## -1 the whole stack.
func show_stack(good: StringName, amount: int, capacity: int, sort_shift: float = 0.0,
		half: int = -1) -> void:
	visible = good != &"" and amount > 0
	if not visible:
		return
	texture = _sheet(good)
	var stages := maxi(1, texture.get_width() / FRAME_W)
	var stage := StockpileLayout.fill_stage(amount, capacity, stages)
	var frame := Vector2(texture.get_width() / float(stages), texture.get_height())
	region_rect = Rect2(frame.x * (stage - 1), 0, frame.x, frame.y)
	offset = -Vector2(frame.x / 2.0, frame.y - 16.0 + sort_shift)
	if half >= 0:
		region_rect = Rect2(region_rect.position.x + frame.x / 2.0 * half, 0, frame.x / 2.0, frame.y)
		offset.x = -frame.x / 2.0 + frame.x / 2.0 * half


static func _sheet(good: StringName) -> Texture2D:
	if not _sheets.has(good):
		_sheets[good] = ArtPaths.texture("goods/stacks/%s.png" % good)
	return _sheets[good]
