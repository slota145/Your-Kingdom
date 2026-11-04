extends Control
## M1 PROTOTYPE: UI font comparison (the other M1 candidates VT323, Micro 5, Tiny5 and
## Silkscreen were rejected and removed; see ROADMAP M1 notes).
## Debug texts are hardcoded on purpose (prototype-only).

const SAMPLE := "Zboże 25 · 5 chlebów · Ż Ź Ś Ć Ń Ó Ł Ę Ą · 1 250 · Z2 S5 O0 Il1 · Piekarz piecze chleb"
const SIZES: PackedInt32Array = [16, 24, 32]
const FONTS: Array[String] = [
	"res://assets/fonts/PixelifySans-Variable.ttf",
	"res://assets/fonts/Jersey10-Regular.ttf",
]


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.14, 0.12, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := VBoxContainer.new()
	box.position = Vector2(12, 8)
	box.add_theme_constant_override(&"separation", 2)
	add_child(box)
	for path: String in FONTS:
		var crisp := (load(path) as FontFile).duplicate() as FontFile
		crisp.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		crisp.hinting = TextServer.HINTING_NONE
		crisp.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		var title := Label.new()
		title.text = path.get_file() + "   (left: no antialiasing)"
		title.add_theme_color_override(&"font_color", Color(0.95, 0.82, 0.5))
		title.add_theme_font_size_override(&"font_size", 14)
		box.add_child(title)
		for size: int in SIZES:
			var label := Label.new()
			label.text = "%d px  %s" % [size, SAMPLE]
			label.add_theme_font_override(&"font", crisp)
			label.add_theme_font_size_override(&"font_size", size)
			box.add_child(label)
