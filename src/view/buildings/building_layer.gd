class_name BuildingLayer
extends Node2D
## Every building of the province as it looks right now: construction site (phase 1 or 2)
## with its pile of delivered materials, the finished building, the house at its level
## (joined into rows), scaffolding while a house is upgraded, a stockpile yard with stacks.
## Child of the y-sorted world. Rebuilt per building on simulation events; stacks and
## material piles are refreshed every frame from the same stockpile data as the UI.

## Marker shown over buildings that miss workers (GDD §3.4).
const NO_WORKERS_MARK := "!"
## Marker shown over buildings whose production the player paused (M4b-1).
const PAUSED_MARK := "II"
## Art key suffix of a mirrored art (BuildingView.setup mirrored).
const MIRROR_SUFFIX := "@m"
## Opacity of the placement preview building.
const GHOST_ALPHA := 0.6

## Pieces of a yard's shed, back ones first (_add_yard_pieces).
const YARD_PIECES: Array[String] = ["shed_a_back", "shed_b_back", "shed_a_front", "shed_b_front"]
## Art path -> whether the file exists.
static var _exists: Dictionary[String, bool] = {}

var province: ProvinceSim

## Building id -> its current visual node.
var _views: Dictionary[int, Node2D] = {}
## Whether some buildings are see-through now ([method fade_in_front_of]).
var _fading: bool = false
## How far round the cursor's tile (screen px, each way) a building in front fades.
const FADE_REACH := Vector2(112, 72)
const NONE_TILE := Vector2i(-1, -1)
## Building id -> art key the view was built for (rebuild only when it changes).
var _keys: Dictionary[int, String] = {}
var _site_piles: Dictionary[int, StackSprite] = {}
var _stockpiles: Array[StockpileView] = []
var _quays: Array[QuayYard] = []
var _marks: Dictionary[int, Label] = {}
var _ghost: BuildingView
var _ghost_key: String = ""


func _init() -> void:
	y_sort_enabled = true


func setup(source: ProvinceSim) -> void:
	province = source
	refresh_all()


## Rebuilds the views whose look changed (cheap when nothing did).
func refresh_all() -> void:
	var rows := _house_rows()
	for id: int in _views.keys():
		if not province.buildings.has_building(id):
			_drop(id)
	for building: BuildingState in province.buildings.all():
		var key := _art_key(building, rows)
		if _keys.get(building.id, "") != key:
			_drop(building.id)
			_build(building, key)


func update_view() -> void:
	for view: StockpileView in _stockpiles:
		view.update_view()
	for quay: QuayYard in _quays:
		quay.update_view()
	for id: int in _site_piles:
		var building := province.buildings.get_building(id)
		var site := province.sites.get(building.site_id) as ConstructionSite if building != null else null
		var pile := _site_piles[id]
		if site == null or site.stock.total_amount() == 0:
			pile.visible = false
			continue
		var good := site.stock.slot_good[0]
		for s: int in site.stock.slot_count():
			if site.stock.slot_amount[s] > 0:
				good = site.stock.slot_good[s]
				break
		pile.show_stack(good, site.stock.total_amount(), 8)
	for building: BuildingState in province.buildings.all():
		_update_mark(building)


func _art_key(building: BuildingState, rows: Dictionary[int, String]) -> String:
	var visual := BuildingVisualDef.for_building(building.def.id)
	var art_id := visual.art_id if visual != null else String(building.def.id)
	var o := building.orientation
	if building.under_construction:
		var site := province.sites.get(building.site_id) as ConstructionSite
		var phase := site.phase if site != null else 1
		return oriented_art("buildings/%s/construction_%d" % [art_id, mini(phase, 2)], building.def, o)
	if visual != null and visual.yard:
		return "yard"
	var name := "base"
	if building.house != null and visual != null and not visual.level_art.is_empty():
		var level := building.house.level
		name = visual.level_art[clampi(level - 1, 0, visual.level_art.size() - 1)]
		if visual.row_from_level > 0 and level >= visual.row_from_level and rows.has(building.id):
			name = visual.row_variant_name("%s_%s" % [name, rows[building.id]], building.origin, building.look)
	if visual != null:
		name = visual.variant_name(name, building.origin, building.look)
	var key := oriented_art("buildings/%s/%s" % [art_id, name], building.def, o)
	var site := province.sites.get(building.site_id) as ConstructionSite
	if site != null and site.kind == ConstructionSite.KIND_UPGRADE:
		key += "|" + oriented_art("buildings/%s/upgrade_scaffold" % art_id, building.def, o)
	return key


## Art key of [param art] for a building of [param def] turned to [param orientation]
## (M4b-1.5): houses turned with the door to the back (2, 3) use the "_back" art when it
## exists, and orientations 1 and 3 are drawn mirrored (key suffix "@m"), unless a "_turned"
## art exists: drawn already turned, with the light still from the left (M7 part 2, owner's
## request 2026-11-08: a mirrored gatehouse had its shade on the wrong side).
static func oriented_art(art: String, def: BuildingDef, orientation: int) -> String:
	if def.is_house() and orientation >= 2 and _art_exists(art + "_back"):
		art += "_back"
	if orientation % 2 == 1 and _art_exists(art + "_turned"):
		return art + "_turned"
	return art + (MIRROR_SUFFIX if orientation % 2 == 1 else "")


## The art a new building of [param def] at [param origin] shows when finished (level 1).
static func base_art(def: BuildingDef, origin: Vector2i, orientation: int, look: int = 0) -> String:
	var visual := BuildingVisualDef.for_building(def.id)
	var art_id := visual.art_id if visual != null else String(def.id)
	if visual != null and visual.yard:
		return ""
	var name := "base"
	if visual != null and not visual.level_art.is_empty():
		name = visual.level_art[0]
	if visual != null:
		name = visual.variant_name(name, origin, look)
	return oriented_art("buildings/%s/%s" % [art_id, name], def, orientation)


static func _art_exists(art: String) -> bool:
	if not _exists.has(art):
		_exists[art] = ResourceLoader.exists(ArtPaths.resolve(art + ".png"))
	return _exists[art]


## Adds a BuildingView for an art key part ("path" or "path@m") under [param parent].
static func add_art(parent: Node, art: String, origin: Vector2i) -> BuildingView:
	var view := BuildingView.new()
	parent.add_child(view)
	var mirrored := art.ends_with(MIRROR_SUFFIX)
	view.setup(art.trim_suffix(MIRROR_SUFFIX), origin, mirrored)
	return view


## Shows a see-through building where the player is about to place one (M4b-1.5: the
## preview shows which way the door faces). Empty [param art] hides it.
func show_ghost(art: String, origin: Vector2i, ok: bool) -> void:
	var key := "%s#%s#%s" % [art, origin, ok]
	if key == _ghost_key:
		return
	_ghost_key = key
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	if art.is_empty():
		return
	_ghost = add_art(self, art, origin)
	_ghost.modulate = Color(1, 1, 1, GHOST_ALPHA) if ok else Color(1, 0.45, 0.4, GHOST_ALPHA)


func _build(building: BuildingState, key: String) -> void:
	_keys[building.id] = key
	var holder := Node2D.new()
	holder.y_sort_enabled = true
	add_child(holder)
	_views[building.id] = holder
	for art: String in key.split("|"):
		if art == "yard":
			var yard := StockpileView.new()
			holder.add_child(yard)
			yard.setup(building)
			_stockpiles.append(yard)
			_add_yard_pieces(holder, building)
		else:
			add_art(holder, art, building.origin)
	if building.def.is_port() and building.def.quay_slots > 0 and building.is_complete():
		var quay := QuayYard.new()
		holder.add_child(quay)
		quay.setup(building)
		_quays.append(quay)
	if building.under_construction or building.site_id != 0:
		var pile := StackSprite.new()
		# Materials lie on the tile in front of the door.
		pile.position = IsoMath.tile_center_screen(building.door_front_tile())
		holder.add_child(pile)
		_site_piles[building.id] = pile


## G3 part 4b: a yard's roofed shed (the warehouse), drawn as pieces each sorted on its own
## footprint (`offset` in tiles from the yard's origin, in its .json), so the goods stacks sort
## between them: the back walls behind every stack, the posts and the roof in front of the back
## row only. Mirrored yards (orientation 1) swap the offsets like the art.
func _add_yard_pieces(holder: Node2D, building: BuildingState) -> void:
	var visual := BuildingVisualDef.for_building(building.def.id)
	var art_id := visual.art_id if visual != null else String(building.def.id)
	var mirrored := building.orientation % 2 == 1
	for piece: String in YARD_PIECES:
		var art := "buildings/%s/%s" % [art_id, piece]
		if not _art_exists(art):
			continue
		var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ArtPaths.resolve(art + ".json")))
		var off: Array = meta.get("offset", [0, 0])
		var offset := Vector2i(int(off[0]), int(off[1]))
		if mirrored:
			offset = Vector2i(offset.y, offset.x)
		add_art(holder, art + (MIRROR_SUFFIX if mirrored else ""), building.origin + offset)


func _drop(id: int) -> void:
	var holder: Node2D = _views.get(id)
	if holder != null:
		for child: Node in holder.get_children():
			if child is StockpileView:
				_stockpiles.erase(child)
			if child is QuayYard:
				_quays.erase(child)
		holder.queue_free()
	_views.erase(id)
	_keys.erase(id)
	_site_piles.erase(id)
	if _marks.has(id):
		_marks[id].queue_free()
		_marks.erase(id)


func _house_rows() -> Dictionary[int, String]:
	var houses: Array[Dictionary] = []
	for building: BuildingState in province.buildings.all():
		if building.house != null and not building.under_construction:
			houses.append({"id": building.id, "origin": building.origin, "orientation": building.orientation,
					"footprint": building.def.footprint, "level": building.house.level})
	return HouseRowResolver.resolve(houses, func(t: Vector2i) -> bool:
		return province.grid.is_inside(t) and province.grid.has_road(t))


## UI-2 part 1 (owner 2026-11-13): while the player builds, buildings that stand in front of
## the tile under the cursor and cover the ground round it turn see-through, so the player sees
## where the road or the building goes. [param tile] NONE_TILE: everything solid again.
func fade_in_front_of(tile: Vector2i) -> void:
	if tile == NONE_TILE and not _fading:
		return
	_fading = tile != NONE_TILE
	var centre := IsoMath.tile_center_screen(tile)
	var focus := Rect2(centre - FADE_REACH, FADE_REACH * 2.0)
	for id: int in _views:
		for child: Node in _views[id].get_children():
			var view := child as BuildingView
			if view != null:
				view.set_faded(_fading and view.position.y > centre.y and view.get_screen_rect().intersects(focus))


## The building whose drawn art is under [param world_pos], the front one when several
## overlap; 0 = none (then the tile under the cursor decides).
func building_at(world_pos: Vector2) -> int:
	var best := 0
	var best_y := -INF
	for id: int in _views:
		for child: Node in _views[id].get_children():
			var view := child as BuildingView
			if view != null and view.position.y > best_y and view.is_opaque_at(world_pos):
				best = id
				best_y = view.position.y
	return best


func _update_mark(building: BuildingState) -> void:
	var missing := building.is_complete() and building.workers.size() < building.def.worker_count()
	var mark: Label = _marks.get(building.id)
	if not missing and not building.paused:
		if mark != null:
			mark.visible = false
		return
	if mark == null:
		mark = Label.new()
		mark.add_theme_font_size_override(&"font_size", 32)
		mark.add_theme_color_override(&"font_color", Color(1, 0.3, 0.2))
		mark.add_theme_color_override(&"font_outline_color", Color.BLACK)
		mark.add_theme_constant_override(&"outline_size", 6)
		var top := IsoMath.grid_to_screen(Vector2(building.origin) + Vector2(building.def.footprint) * 0.5)
		mark.position = top - Vector2(6, 110)
		mark.z_index = 10
		add_child(mark)
		_marks[building.id] = mark
	# Paused shows first: its workers are idle on purpose.
	mark.text = PAUSED_MARK if building.paused else NO_WORKERS_MARK
	mark.add_theme_color_override(&"font_color", Color(1, 0.8, 0.2) if building.paused else Color(1, 0.3, 0.2))
	mark.visible = true
