class_name AgentSprite
extends Sprite2D
## Draws one person: picks the sheet frame from (animation, direction, time) and puts the
## carried good on the frame's anchor (ART_SPEC §4, §5). The node's position is the feet.

const CARRIED_FRAME := Vector2i(24, 24)

static var _carried_cache: Dictionary[StringName, Texture2D] = {}

var _good_overlay: Sprite2D
var _sheet: CharacterSheet


func _init() -> void:
	centered = false
	offset = -Vector2(CharacterSheet.FOOT)
	_good_overlay = Sprite2D.new()
	_good_overlay.region_enabled = true
	add_child(_good_overlay)


## [param carry_category] and [param good] select the carried overlay; empty = hands free.
func show_state(visual: CharacterVisual, anim: StringName, dir: int, time: float,
		carry_category: String, good: StringName) -> void:
	var sheet := visual.get_sheet(anim)
	if sheet != _sheet:
		_sheet = sheet
		texture = sheet.texture
		hframes = sheet.frames
		vframes = sheet.rows
	var row_flip := sheet.row_for(maxi(dir, 0))
	var column := sheet.frame_at(time)
	frame = row_flip.x * sheet.frames + column
	flip_h = row_flip.y == 1
	_update_good(sheet, row_flip, column, carry_category, good)


func _update_good(sheet: CharacterSheet, row_flip: Vector2i, column: int,
		carry_category: String, good: StringName) -> void:
	var index := row_flip.x * sheet.frames + column
	if good == &"" or sheet.anchors.is_empty() or index >= sheet.anchors.size():
		_good_overlay.visible = false
		return
	_good_overlay.visible = true
	_good_overlay.texture = _carried_texture(carry_category, good)
	var good_row := mini(row_flip.x, 4)
	_good_overlay.region_rect = Rect2(0, good_row * CARRIED_FRAME.y, CARRIED_FRAME.x, CARRIED_FRAME.y)
	var anchor := sheet.anchors[index]
	if row_flip.y == 1:
		anchor.x = -anchor.x - 1.0   # mirrored inside the 64 px frame around the feet (x = 32)
	_good_overlay.position = anchor
	_good_overlay.flip_h = row_flip.y == 1
	_good_overlay.show_behind_parent = sheet.anchor_behind[index] == 1


static func _carried_texture(category: String, good: StringName) -> Texture2D:
	var key := StringName("%s/%s" % [category, good])
	if not _carried_cache.has(key):
		_carried_cache[key] = ArtPaths.texture("goods/carried/%s/%s.png" % [category, good])
	return _carried_cache[key]
