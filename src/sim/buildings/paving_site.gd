class_name PavingSite
extends RefCounted
## Road tiles waiting for cobbles (M4b-3, GDD §5.2): porters bring one stone per tile into
## the site's own stock, a builder walks to the next tile and lays it. Until then the tiles
## are dirt road. Addressed by its own entity id, like a construction site; porters deliver
## to the next tile to pave.

const GOOD := &"stone"
## Stone per paved tile.
const STONE_PER_TILE := 1
## Builder work per tile (3 s).
const TILE_SECONDS := 3.0

var id: int
## Tiles still to pave, in the order they are laid.
var tiles: Array[Vector2i] = []
## Builder ticks left on the first tile.
var work_left: int = 0
## Stone delivered and not laid yet.
var stock: Stockpile


func _init(entity_id: int, tile_list: Array[Vector2i], data: DataRegistry) -> void:
	id = entity_id
	tiles = tile_list
	work_left = tile_ticks()
	var stack := maxi(data.get_good(GOOD).stack_size, 1)
	stock = Stockpile.new(maxi(ceili(tiles.size() * STONE_PER_TILE / float(stack)), 1), data)


static func tile_ticks() -> int:
	return maxi(SimClock.seconds_to_ticks(TILE_SECONDS), 1)


## The tile being paved next (porters bring stone here), or Agent.NO_TILE when done.
func next_tile() -> Vector2i:
	return tiles[0] if not tiles.is_empty() else Agent.NO_TILE


## Stone still to be brought: tiles left minus what lies here.
func stone_missing() -> int:
	return maxi(tiles.size() * STONE_PER_TILE - stock.total(GOOD), 0)


## A builder has something to do here right now.
func is_workable() -> bool:
	return not tiles.is_empty() and stock.available(GOOD) >= STONE_PER_TILE


func to_dict() -> Dictionary:
	return {"id": id, "tiles": SimCodec.tiles(tiles), "work_left": work_left,
			"stock": stock.to_dict()}


static func from_dict(d: Dictionary, data: DataRegistry) -> PavingSite:
	var site := PavingSite.new(int(d["id"]), SimCodec.to_tiles(d["tiles"]), data)
	site.work_left = int(d["work_left"])
	site.stock = Stockpile.from_dict(d["stock"], data)
	return site
