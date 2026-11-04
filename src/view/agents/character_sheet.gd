class_name CharacterSheet
extends RefCounted
## One animation of a character: a sheet with rows = screen directions and columns =
## frames (ART_SPEC §4), plus optional carry anchors read from <anim>.anchors.png.

const FRAME_SIZE := Vector2i(64, 64)
const FOOT := Vector2i(32, 58)
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


static func from_files(sheet_path: String, anchors_path: String, frames_per_second: float) -> CharacterSheet:
	var sheet := CharacterSheet.new()
	sheet.texture = load(sheet_path) as Texture2D
	sheet.frames = maxi(1, sheet.texture.get_width() / FRAME_SIZE.x)
	sheet.rows = maxi(1, sheet.texture.get_height() / FRAME_SIZE.y)
	sheet.fps = frames_per_second
	if anchors_path != "" and ResourceLoader.exists(anchors_path):
		sheet._read_anchors((load(anchors_path) as Texture2D).get_image())
	return sheet


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
			var origin := Vector2i(column, row) * FRAME_SIZE
			var index := row * frames + column
			anchors[index] = Vector2.ZERO
			for y: int in FRAME_SIZE.y:
				for x: int in FRAME_SIZE.x:
					var c := image.get_pixel(origin.x + x, origin.y + y)
					if c.a < 0.5:
						continue
					if c.is_equal_approx(ANCHOR_COLOR):
						anchors[index] = Vector2(x, y) - Vector2(FOOT)
					elif c.is_equal_approx(BEHIND_COLOR):
						anchor_behind[index] = 1
