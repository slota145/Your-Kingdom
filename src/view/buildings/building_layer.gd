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

var province: ProvinceSim

## Building id -> its current visual node.
var _views: Dictionary[int, Node2D] = {}
## Building id -> art key the view was built for (rebuild only when it changes).
var _keys: Dictionary[int, String] = {}
var _site_piles: Dictionary[int, StackSprite] = {}
var _stockpiles: Array[StockpileView] = []
var _marks: Dictionary[int, Label] = {}


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
		pile.show_stack(good, StockpileLayout.fill_stage(site.stock.total_amount(), 8))
	for building: BuildingState in province.buildings.all():
		_update_mark(building)


func _art_key(building: BuildingState, rows: Dictionary[int, Array]) -> String:
	var visual := BuildingVisualDef.for_building(building.def.id)
	var art_id := visual.art_id if visual != null else String(building.def.id)
	if building.under_construction:
		var site := province.sites.get(building.site_id) as ConstructionSite
		var phase := site.phase if site != null else 1
		return "buildings/%s/construction_%d" % [art_id, mini(phase, 2)]
	if visual != null and visual.yard:
		return "yard"
	var name := "base"
	if building.house != null and visual != null and not visual.level_art.is_empty():
		var level := building.house.level
		name = visual.level_art[clampi(level - 1, 0, visual.level_art.size() - 1)]
		if visual.row_from_level > 0 and level >= visual.row_from_level and rows.has(building.id):
			var row: Array = rows[building.id]
			name = "%s_%s_%s" % [name, row[0], row[1]]
	if visual != null:
		name = visual.variant_name(name, building.origin)
	var key := "buildings/%s/%s" % [art_id, name]
	var site := province.sites.get(building.site_id) as ConstructionSite
	if site != null and site.kind == ConstructionSite.KIND_UPGRADE:
		key += "|buildings/%s/upgrade_scaffold" % art_id
	return key


func _build(building: BuildingState, key: String) -> void:
	_keys[building.id] = key
	var holder := Node2D.new()
	holder.y_sort_enabled = true
	add_child(holder)
	_views[building.id] = holder
	if key == "yard":
		var yard := StockpileView.new()
		holder.add_child(yard)
		yard.setup(building)
		_stockpiles.append(yard)
	else:
		for art: String in key.split("|"):
			var view := BuildingView.new()
			holder.add_child(view)
			view.setup(art, building.origin)
	if building.under_construction or building.site_id != 0:
		var pile := StackSprite.new()
		# Materials lie on the tile in front of the entrance.
		pile.position = IsoMath.tile_center_screen(building.entrance_tile() + Vector2i(1, 1))
		holder.add_child(pile)
		_site_piles[building.id] = pile


func _drop(id: int) -> void:
	var holder: Node2D = _views.get(id)
	if holder != null:
		for child: Node in holder.get_children():
			if child is StockpileView:
				_stockpiles.erase(child)
		holder.queue_free()
	_views.erase(id)
	_keys.erase(id)
	_site_piles.erase(id)
	if _marks.has(id):
		_marks[id].queue_free()
		_marks.erase(id)


func _house_rows() -> Dictionary[int, Array]:
	var houses: Array[Dictionary] = []
	for building: BuildingState in province.buildings.all():
		if building.house != null and not building.under_construction:
			houses.append({"id": building.id, "origin": building.origin,
					"footprint": building.def.footprint, "level": building.house.level})
	return HouseRowResolver.resolve(houses)


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
