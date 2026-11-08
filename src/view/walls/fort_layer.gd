class_name FortLayer
extends Node2D
## The walls of a province (M7 part 2): stone walls as blocks (BlockWallModel) with the
## PixelLab stone, palisades as rows of logs, stone stairs. Gatehouses and towers are building
## art (BuildingLayer); here stone walls only join them. Child of the y-sorted world; every
## piece sorts on its own (ARCHITECTURE §6.3). Rebuilt when a wall changes.

var province: ProvinceSim
var _skin: WallSkin
var _dirty: bool = true
var _version: int = -1
## Stone crown sort keys of the last build (people on the walls sort with them).
var model: BlockWallModel = BlockWallModel.new()


func _init() -> void:
	y_sort_enabled = true


func setup(source: ProvinceSim) -> void:
	province = source
	_skin = WallSkin.shared()
	refresh()


func on_sim_event(event: Dictionary) -> void:
	match event["type"]:
		&"wall_changed", &"building_placed", &"building_removed", &"wall_damaged":
			_dirty = true


func update_view() -> void:
	if _dirty or province.walls.version != _version:
		refresh()


## Rebuilds every piece from the province's walls.
func refresh() -> void:
	_dirty = false
	_version = province.walls.version
	for child: Node in get_children():
		child.queue_free()
	var walls := province.walls
	model = BlockWallModel.new()
	model.draw_forts = false
	for tile: Vector2i in walls.tiles():
		if walls.is_stone(tile):
			model.walls[tile] = false
	for building: BuildingState in province.buildings.all():
		if building.def.is_gatehouse():
			model.add_gatehouse(building.origin, Vector2i(building.def.door_dir(building.orientation).abs()))
		elif building.def.is_fort():
			model.add_tower(building.origin, building.def.footprint.x)
	for piece: BlockWallModel.Piece in model.build():
		var node := WallPieceNode.new()
		node.setup(piece, _skin)
		if walls.is_stone(piece.tile):
			node.damage = 1.0 - walls.hp(piece.tile) / float(Walls.STONE_HP)
		add_child(node)
	# A palisade joins a palisade gate too (M7 part 3); it ends at the gate's post.
	var gates: Dictionary[Vector2i, bool] = {}
	for building: BuildingState in province.buildings.all():
		if building.def.is_gate() and not building.def.is_gatehouse():
			for t: Vector2i in building.tiles():
				gates[t] = true
	var is_fence := func(t: Vector2i) -> bool:
		return walls.kind(t) == Walls.PALISADE or walls.is_mass(t) or gates.has(t)
	for tile: Vector2i in walls.tiles():
		match walls.kind(tile):
			Walls.PALISADE:
				_add_palisade(tile, WallConnectivity.mask_at(tile, is_fence))
			Walls.STONE:
				pass
			_:
				var stairs := StairsNode.new()
				stairs.setup(tile, Walls.DIRS[walls.stairs_dir(tile)], _skin)
				add_child(stairs)


func _add_palisade(tile: Vector2i, mask: int) -> void:
	var c := IsoMath.tile_center(tile)
	var damage := 1.0 - province.walls.hp(tile) / float(Walls.PALISADE_HP)
	for dir: int in WallConnectivity.half_dirs(mask):
		var piece := PalisadeNode.new()
		piece.setup(c, c + Vector2(WallConnectivity.OFFSETS[dir]) * 0.5)
		piece.damage = damage
		add_child(piece)
	if WallConnectivity.needs_post(mask):
		var post := PalisadeNode.new()
		post.setup(c, c)
		add_child(post)


## Sort key (screen y) for a person standing on the crown at grid point [param p]: after the
## crown under him; on a gatehouse or tower, after its whole art (sorted at its front corner).
func crown_sort_key(p: Vector2) -> float:
	var tile := Vector2i(p.floor())
	var fort := province.buildings.get_building(province.walls.fort_tiles.get(tile, 0))
	if fort != null:
		return IsoMath.grid_to_screen(Vector2(fort.origin + fort.def.footprint)).y + 2.0
	return model.crown_sort_key(p)


## How high above the ground a fighter at [param p] on [param level] stands (screen px): on
## the wall-walk the crown (higher on a gatehouse or a tower), on stairs or a ladder part of
## the way up (M7 part 2).
static func height_at(province: ProvinceSim, p: Vector2, level: int) -> float:
	var tile := Vector2i(p.floor())
	var walls := province.walls
	if level == MilitaryNav.WALL:
		var fort := province.buildings.get_building(walls.fort_tiles.get(tile, 0))
		if fort != null:
			return BlockWallModel.HEIGHT + (BlockWallModel.GATEHOUSE_EXTRA if fort.def.is_gatehouse() \
					else BlockWallModel.TOWER_EXTRA)
		return BlockWallModel.HEIGHT
	var up := Vector2i.ZERO
	var d := walls.stairs_dir(tile)
	if d >= 0:
		up = Walls.DIRS[d]
	elif province.mil.ladders.has(tile):
		up = province.mil.ladders[tile] - tile
	if up == Vector2i.ZERO:
		return 0.0
	var t := clampf((p - IsoMath.tile_center(tile)).dot(Vector2(up)) + 0.5, 0.0, 1.0)
	return t * BlockWallModel.HEIGHT
