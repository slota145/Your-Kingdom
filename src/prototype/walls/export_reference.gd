extends SceneTree
## WALLS PROTOTYPE: renders code-drawn walls and a gatehouse on a transparent canvas, as a
## reference image for PixelLab edit/inpaint. Needs a display (xvfb-run, opengl3):
##   "$GODOT" --path . --rendering-driver opengl3 -s res://src/prototype/walls/export_reference.gd -- <out.png> [gate|wall]

const Model := preload("res://src/prototype/walls/block_wall_model.gd")
const View := preload("res://src/prototype/walls/block_wall_view.gd")
const SIZE := Vector2i(256, 256)

var _viewport: SubViewport
var _frames: int = 0
var _out: String = ""


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0]
	var what := args[1] if args.size() > 1 else "gate"
	var model := Model.new()
	model.wedge_leg = 1.0
	var focus := layout(model, what, Vector2i.ZERO)
	_viewport = SubViewport.new()
	_viewport.size = SIZE
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	var world := Node2D.new()
	world.y_sort_enabled = true
	_viewport.add_child(world)
	var view := View.new()
	world.add_child(view)
	view.rebuild(model)
	var cam := Camera2D.new()
	cam.position = IsoMath.grid_to_screen(focus) - Vector2(0, 40)
	_viewport.add_child(cam)
	cam.make_current()


## Builds the reference layout [param what] at [param origin]; returns the grid point the
## 256x256 image is centred on (40 px below the image center).
static func layout(model: Model, what: String, origin: Vector2i) -> Vector2:
	if what == "gate":
		for x: int in [-3, -2, -1, 3, 4, 5]:
			model.walls[origin + Vector2i(x, 1)] = false
		model.add_gatehouse(origin, Vector2i(0, 1))
		return Vector2(origin) + Vector2(1.5, 1.5)
	# Single and double wall with a corner and a short diagonal: every face type.
	for x: int in range(0, 4):
		model.walls[origin + Vector2i(x, 0)] = false
		model.walls[origin + Vector2i(x, 1)] = false
	for y: int in range(2, 4):
		model.walls[origin + Vector2i(0, y)] = false
	model.walls[origin + Vector2i(4, -1)] = false
	model.walls[origin + Vector2i(5, -2)] = false
	return Vector2(origin) + Vector2(2.5, 0.5)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 5:
		_viewport.get_texture().get_image().save_png(_out)
		quit()
	return false
