class_name AgentSprite
extends Sprite2D
## Draws one person: picks the sheet frame from (animation, direction, time) and puts the
## carried good on the frame's anchor (ART_SPEC §4, §5). The node's position is the feet.

const CARRIED_FRAME := Vector2i(24, 24)
## Where a led animal walks (carry category "animal", M4b-2): beside the person's right hand,
## a little behind, relative to the feet (the overlay is centred).
const LED_OFFSET := Vector2(13.0, -7.0)

## Vehicle sheets (M4b-3, tools/generate_goods.gd): 5 rows (S, SE, E, NE, N) of "frame", the
## vehicle's origin on the ground at "centre"; it stands "ahead" tiles in front of the
## person's feet (a handcart is pushed, a wagon follows its carter).
const VEHICLES: Dictionary[StringName, Dictionary] = {
	&"handcart": {"frame": Vector2i(48, 40), "centre": Vector2(24, 30), "ahead": 0.4},
	&"wagon": {"frame": Vector2i(112, 80), "centre": Vector2(56, 52), "ahead": -0.6},
	&"trade_wagon": {"frame": Vector2i(112, 80), "centre": Vector2(56, 52), "ahead": -0.6},
}
## Forward vector in grid space of the vehicle rows (as in tools/generate_goods.gd).
const ROW_FORWARD: Array[Vector2] = [Vector2(0.7071, 0.7071), Vector2(1, 0), Vector2(0.7071, -0.7071),
		Vector2(0, -1), Vector2(-0.7071, -0.7071)]

static var _carried_cache: Dictionary[StringName, Texture2D] = {}

var _good_overlay: Sprite2D
var _vehicle: Sprite2D
var _sheet: CharacterSheet


func _init() -> void:
	centered = false
	offset = -Vector2(CharacterSheet.FOOT)
	_good_overlay = Sprite2D.new()
	_good_overlay.region_enabled = true
	add_child(_good_overlay)
	_vehicle = Sprite2D.new()
	_vehicle.region_enabled = true
	_vehicle.centered = false
	_vehicle.visible = false
	add_child(_vehicle)


## [param carry_category] and [param good] select the carried overlay; empty = hands free.
func show_state(visual: CharacterVisual, anim: StringName, dir: int, time: float,
		carry_category: String, good: StringName, vehicle: StringName = &"", loaded: bool = false) -> void:
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
	_update_vehicle(row_flip, vehicle, loaded)
	_update_good(sheet, row_flip, column, carry_category, &"" if vehicle != &"" else good)


## A handcart in front of the person (M4b-3), pushed by the handles; goods ride on it.
func _update_vehicle(row_flip: Vector2i, vehicle: StringName, loaded: bool) -> void:
	_vehicle.visible = vehicle != &""
	if vehicle == &"":
		return
	var spec: Dictionary = VEHICLES.get(vehicle, VEHICLES[&"handcart"])
	var frame_size: Vector2i = spec["frame"]
	var row := mini(row_flip.x, ROW_FORWARD.size() - 1)
	_vehicle.texture = _carried_texture_at("vehicles/%s/%s.png" % [vehicle, "loaded" if loaded else "empty"])
	_vehicle.region_rect = Rect2(0, row * frame_size.y, frame_size.x, frame_size.y)
	_vehicle.flip_h = row_flip.y == 1
	var ahead_tiles: float = spec["ahead"]
	var g := ROW_FORWARD[row] * ahead_tiles
	var ahead := Vector2((g.x - g.y) * IsoMath.HALF_W, (g.x + g.y) * IsoMath.HALF_H)
	var centre: Vector2 = spec["centre"]
	if row_flip.y == 1:
		ahead.x = -ahead.x
		centre.x = frame_size.x - centre.x
	# Children are placed from the node origin, which is the person's feet.
	_vehicle.position = ahead - centre
	# A vehicle farther from the camera than the person is drawn behind him: a pushed cart
	# when walking away, a following wagon when walking towards the camera or sideways.
	_vehicle.show_behind_parent = row >= 3 if ahead_tiles > 0.0 else row <= 2


func _update_good(sheet: CharacterSheet, row_flip: Vector2i, column: int,
		carry_category: String, good: StringName) -> void:
	var index := row_flip.x * sheet.frames + column
	if good != &"" and carry_category == "animal":
		_show_led(row_flip, carry_category, good)
		return
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


## A live animal walking beside the person (a pig led to the slaughterhouse): the same
## 5-row overlay sheet, placed by the feet instead of on a hand anchor.
func _show_led(row_flip: Vector2i, carry_category: String, good: StringName) -> void:
	_good_overlay.visible = true
	_good_overlay.texture = _carried_texture(carry_category, good)
	var good_row := mini(row_flip.x, 4)
	_good_overlay.region_rect = Rect2(0, good_row * CARRIED_FRAME.y, CARRIED_FRAME.x, CARRIED_FRAME.y)
	var at := LED_OFFSET
	if row_flip.y == 1:
		at.x = -at.x
	_good_overlay.position = at
	_good_overlay.flip_h = row_flip.y == 1
	# Walking away from the camera the person hides the animal on his far side.
	_good_overlay.show_behind_parent = good_row >= 3


static func _carried_texture_at(path: String) -> Texture2D:
	var key := StringName(path)
	if not _carried_cache.has(key):
		_carried_cache[key] = ArtPaths.texture(path)
	return _carried_cache[key]


static func _carried_texture(category: String, good: StringName) -> Texture2D:
	var key := StringName("%s/%s" % [category, good])
	if not _carried_cache.has(key):
		_carried_cache[key] = ArtPaths.texture("goods/carried/%s/%s.png" % [category, good])
	return _carried_cache[key]
