class_name PavingSite
extends RefCounted
## Tiles waiting for a builder (M4b-3, N1): porters bring the material into the site's own
## stock, a builder walks to the next tile and lays it. Addressed by its own entity id, like a
## construction site; porters deliver to where the builder stands for the next tile.
##
## [member kind] KIND_PAVING: cobbles on a road (1 stone per tile, the builder stands on the
## tile; until then it is dirt road). KIND_PIER and KIND_STONE_QUAY (N1): a quay over the sea
## (2 planks or 3 stones per tile); the builder stands on land or quay next to the tile, so
## the tiles are laid from the shore outwards.

const KIND_PAVING := 0
const KIND_PIER := 1
const KIND_STONE_QUAY := 2

## Kept for older callers: the cobbles' good and amount.
const GOOD := &"stone"
const STONE_PER_TILE := 1
## Builder work per tile (3 s; a quay tile 6 s).
const TILE_SECONDS := 3.0
const QUAY_TILE_SECONDS := 6.0

const _GOODS: Array[StringName] = [&"stone", &"planks", &"stone"]
const _PER_TILE: Array[int] = [1, 2, 3]

var id: int
var kind: int = KIND_PAVING
## Tiles still to lay, in the order they are laid.
var tiles: Array[Vector2i] = []
## Builder ticks left on the first tile.
var work_left: int = 0
## Material delivered and not laid yet.
var stock: Stockpile


func _init(entity_id: int, tile_list: Array[Vector2i], data: DataRegistry, site_kind: int = KIND_PAVING) -> void:
	id = entity_id
	kind = site_kind
	tiles = tile_list
	work_left = tile_ticks()
	var stack := maxi(data.get_good(good()).stack_size, 1)
	stock = Stockpile.new(maxi(ceili(tiles.size() * per_tile() / float(stack)), 1), data)


## The quay kind a site of [param quay] (TileGrid.PIER or STONE_QUAY) lays.
static func kind_for_quay(quay: int) -> int:
	return KIND_STONE_QUAY if quay == TileGrid.STONE_QUAY else KIND_PIER


static func good_of(site_kind: int) -> StringName:
	return _GOODS[clampi(site_kind, 0, 2)]


static func per_tile_of(site_kind: int) -> int:
	return _PER_TILE[clampi(site_kind, 0, 2)]


func good() -> StringName:
	return good_of(kind)


func per_tile() -> int:
	return per_tile_of(kind)


func is_quay() -> bool:
	return kind != KIND_PAVING


## TileGrid quay value this site lays (0 for paving).
func quay_value() -> int:
	match kind:
		KIND_PIER: return TileGrid.PIER
		KIND_STONE_QUAY: return TileGrid.STONE_QUAY
	return 0


func tile_ticks() -> int:
	return maxi(SimClock.seconds_to_ticks(QUAY_TILE_SECONDS if is_quay() else TILE_SECONDS), 1)


## The tile being laid next, or Agent.NO_TILE when done.
func next_tile() -> Vector2i:
	return tiles[0] if not tiles.is_empty() else Agent.NO_TILE


## Material still to be brought: tiles left minus what lies here.
func stone_missing() -> int:
	return maxi(tiles.size() * per_tile() - stock.total(good()), 0)


## Material for the next tile is here (whether the builder can reach it is the province's
## business, ProvinceSim.paving_stand).
func is_workable() -> bool:
	return not tiles.is_empty() and stock.available(good()) >= per_tile()


func to_dict() -> Dictionary:
	var d := {"id": id, "tiles": SimCodec.tiles(tiles), "work_left": work_left,
			"stock": stock.to_dict()}
	if kind != KIND_PAVING:
		d["kind"] = kind
	return d


static func from_dict(d: Dictionary, data: DataRegistry) -> PavingSite:
	var site := PavingSite.new(int(d["id"]), SimCodec.to_tiles(d["tiles"]), data, int(d.get("kind", KIND_PAVING)))
	site.work_left = int(d["work_left"])
	site.stock = Stockpile.from_dict(d["stock"], data)
	return site
