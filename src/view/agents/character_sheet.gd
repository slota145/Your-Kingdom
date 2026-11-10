class_name CharacterSheet
extends RefCounted
## One animation of a character: a sheet with rows = screen directions and columns =
## frames (ART_SPEC §4), plus optional carry anchors read from <anim>.anchors.png.
## Frames are square, 64 px by default; a character with a long weapon may use bigger ones
## (a halberd, 96 px, owner 2026-11-10): the size follows from the sheet's height (8 or 5 rows).
## Riders take 128 px frames (owner 2026-11-10) with the feet higher in the frame: facing the
## viewer the horse's forelegs reach in front of (below) the feet.

const FRAME_SIZE := Vector2i(64, 64)
const FOOT := Vector2i(32, 58)
## How far the feet stand above a frame's bottom edge (FOOT in a 64 px frame).
const FOOT_MARGIN := 6
## The same for frames of RIDER_FRAME px and bigger (a horse's legs reach beyond the feet).
const RIDER_FOOT_MARGIN := 16
const RIDER_FRAME := 128
const ANCHOR_COLOR := Color(1, 0, 0)
const BEHIND_COLOR := Color(0, 0, 1)

var texture: Texture2D
var frames: int = 1
## 8 when every direction is drawn, 5 when W-side directions are mirrored.
var rows: int = 8
var fps: float = 10.0
var loops: bool = true
## Per frame (row * frames + column): carried-good position relative to the feet.
var anchors: PackedVector2Array = PackedVector2Array()
## Per frame: 1 when the carried good is drawn behind the body.
var anchor_behind: PackedByteArray = PackedByteArray()
## This sheet's frame size and the feet in a frame (FRAME_SIZE and FOOT unless bigger frames).
var frame_size: Vector2i = FRAME_SIZE
var foot: Vector2i = FOOT


static func from_files(sheet_path: String, anchors_path: String, frames_per_second: float) -> CharacterSheet:
	var sheet := CharacterSheet.new()
	sheet.texture = load(sheet_path) as Texture2D
	var side := frame_side(sheet.texture.get_height())
	sheet.frame_size = Vector2i(side, side)
	sheet.foot = Vector2i(side / 2, side - foot_margin(side))
	sheet.frames = maxi(1, sheet.texture.get_width() / side)
	sheet.rows = maxi(1, sheet.texture.get_height() / side)
	sheet.fps = frames_per_second
	if anchors_path != "" and ResourceLoader.exists(anchors_path):
		sheet._read_anchors((load(anchors_path) as Texture2D).get_image())
	return sheet


## Side of a square frame of a sheet [param height] px tall: 8 rows when that gives a multiple
## of 32 px (512 = 8 x 64, 768 = 8 x 96), else 5 rows (320 = 5 x 64, mirrored sheets).
static func frame_side(height: int) -> int:
	if height % 8 == 0 and (height / 8) % 32 == 0:
		return height / 8
	if height % 5 == 0 and height >= 5 * FRAME_SIZE.y:
		return height / 5
	return FRAME_SIZE.y


## How far the feet stand above the bottom of a frame [param side] px square.
static func foot_margin(side: int) -> int:
	return RIDER_FOOT_MARGIN if side >= RIDER_FRAME else FOOT_MARGIN


## Sheet row and horizontal flip for a screen direction (IsoMath.Dir).
func row_for(dir: int) -> Vector2i:
	if rows >= IsoMath.DIR_COUNT or dir <= IsoMath.Dir.N:
		return Vector2i(mini(dir, rows - 1), 0)
	return Vector2i(IsoMath.DIR_COUNT - dir, 1)   # NW->NE, W->E, SW->SE, flipped


func frame_at(time: float) -> int:
	var index := int(time * fps)
	return index % frames if loops else mini(index, frames - 1)


func _read_anchors(image: Image) -> void:
	anchors.resize(rows * frames)
	anchor_behind.resize(rows * frames)
	for row: int in rows:
		for column: int in frames:
			var origin := Vector2i(column, row) * frame_size
			var index := row * frames + column
			anchors[index] = Vector2.ZERO
			for y: int in frame_size.y:
				for x: int in frame_size.x:
					var c := image.get_pixel(origin.x + x, origin.y + y)
					if c.a < 0.5:
						continue
					if c.is_equal_approx(ANCHOR_COLOR):
						anchors[index] = Vector2(x, y) - Vector2(foot)
					elif c.is_equal_approx(BEHIND_COLOR):
						anchor_behind[index] = 1
