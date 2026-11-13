extends SceneTree
## Build menu pictures of buildings whose own art is not a finished building (UI-2 part 1,
## owner 2026-11-13: "some buildings in the build menu show their construction"):
##   storage yards (stockpile, port store and warehouses): their floor with full stacks of goods,
##     drawn by the game's own StockpileView,
##   port pieces (port, mooring, bollard, crane): their base art on a piece of stone quay over water.
## Writes assets/buildings/<id>/icon.png; BuildMenu shows it before the building's art.
## Needs a display: xvfb-run -a "$GODOT" --path . --rendering-driver opengl3 -s res://tools/render_menu_icons.gd

const YARDS: Array[StringName] = [&"stockpile", &"port_store", &"port_warehouse_small", &"port_warehouse"]
const PIECES: Array[StringName] = [&"port", &"mooring", &"bollard", &"crane"]
## Goods on the yards' stacks, slot by slot.
const GOODS: Array[StringName] = [&"wood", &"stone", &"planks", &"grain", &"beer", &"bread", &"bricks",
		&"cloth", &"fish", &"flour", &"iron", &"wool"]
const WATER := Color(0.2, 0.36, 0.52)
const WATER_EDGE := Color(0.14, 0.27, 0.42)
## Canvas border around the drawn picture (px), trimmed afterwards.
const PAD := 8

var _data: DataRegistry
var _viewport: SubViewport
var _queue: Array[Callable] = []
var _wait: int = 0
var _save_to: String = ""


func _init() -> void:
	_data = DataRegistry.new()
	_data.load_from("res://data")
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	for id: StringName in YARDS:
		_queue.append(_yard.bind(id))
	for id: StringName in PIECES:
		_queue.append(_piece.bind(id))


func _process(_delta: float) -> bool:
	if _wait > 0:
		_wait -= 1
		if _wait == 0:
			var img := _viewport.get_texture().get_image()
			var used := img.get_used_rect()
			img = img.get_region(used)
			img.save_png(ProjectSettings.globalize_path(_save_to))
			print("saved ", _save_to, " ", img.get_size())
		return false
	if _queue.is_empty():
		return true
	for child: Node in _viewport.get_children():
		child.queue_free()
	(_queue.pop_front() as Callable).call()
	_wait = 4
	return false


## A world of [param footprint] tiles round the grid origin, the camera on its middle.
func _world(footprint: Vector2i, height: int) -> Node2D:
	var top := IsoMath.grid_to_screen(Vector2.ZERO)
	var bottom := IsoMath.grid_to_screen(Vector2(footprint))
	var left := IsoMath.grid_to_screen(Vector2(0, footprint.y))
	var right := IsoMath.grid_to_screen(Vector2(footprint.x, 0))
	var width := int(right.x - left.x) + 2 * PAD + 64
	var tall := int(bottom.y - top.y) + height + 2 * PAD
	_viewport.size = Vector2i(width, tall)
	var world := Node2D.new()
	world.y_sort_enabled = true
	_viewport.add_child(world)
	var cam := Camera2D.new()
	cam.position = Vector2((left.x + right.x) / 2.0, bottom.y + PAD - tall / 2.0)
	_viewport.add_child(cam)
	cam.make_current()
	return world


func _target(id: StringName) -> String:
	var visual := BuildingVisualDef.for_building(id)
	var art_id := visual.art_id if visual != null else String(id)
	return "res://assets/buildings/%s/icon.png" % art_id


## A storage yard full of goods.
func _yard(id: StringName) -> void:
	var def := _data.get_building(id)
	var world := _world(def.footprint, 48)
	var state := BuildingState.new(1, def, Vector2i.ZERO)
	state.finish(_data)
	# Low stacks on most slots, a few left empty: the floor still shows (a yard, not a tower of goods).
	for slot: int in state.stock.slot_count():
		if slot % 4 == 3:
			continue
		var good := GOODS[slot % GOODS.size()]
		var full := state.stock.stack_size(good)
		state.stock.add(good, maxi(full / (3 if slot % 2 == 0 else 5), 1))
	var view := StockpileView.new()
	world.add_child(view)
	view.setup(state)
	view.update_view()
	_save_to = _target(id)


## A port piece standing on a stone quay with water round it.
func _piece(id: StringName) -> void:
	var def := _data.get_building(id)
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
			ArtPaths.resolve("buildings/%s/base.json" % id)))
	var tall := int((meta["size"] as Array)[1]) if meta.has("size") else 160
	var world := _world(def.footprint + Vector2i(2, 2), tall)
	var water := _Ground.new()
	# Half a tile of water round the quay.
	water.footprint = def.footprint + Vector2i(1, 1)
	water.color = WATER
	water.edge = WATER_EDGE
	water.position = IsoMath.grid_to_screen(Vector2(0.5, 0.5))
	water.z_index = -2
	world.add_child(water)
	var yard := StockpileView._Yard.new()
	yard.footprint = def.footprint
	yard.stone = true
	yard.position = IsoMath.grid_to_screen(Vector2(1, 1))
	yard.z_index = -1
	world.add_child(yard)
	BuildingLayer.add_art(world, "buildings/%s/base" % id, Vector2i(1, 1))
	_save_to = _target(id)


## A flat diamond of [member footprint] tiles.
class _Ground:
	extends Node2D
	var footprint: Vector2i
	var color: Color
	var edge: Color

	func _draw() -> void:
		var f := Vector2(footprint)
		var corners := PackedVector2Array([IsoMath.grid_to_screen(Vector2.ZERO), IsoMath.grid_to_screen(Vector2(f.x, 0)),
				IsoMath.grid_to_screen(f), IsoMath.grid_to_screen(Vector2(0, f.y))])
		draw_colored_polygon(corners, color)
		corners.append(corners[0])
		draw_polyline(corners, edge, 2.0)
