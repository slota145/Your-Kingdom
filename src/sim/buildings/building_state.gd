class_name BuildingState
extends RefCounted
## Runtime state of one placed building.

var id: int
var def: BuildingDef
## Footprint origin in grid space (the tile with the smallest x and y).
var origin: Vector2i
## Present when def.storage_slots > 0.
var stock: Stockpile
## Agent ids of assigned workers, in assignment order.
var workers: Array[int] = []


func _init(entity_id: int, building_def: BuildingDef, at: Vector2i, data: DataRegistry) -> void:
	id = entity_id
	def = building_def
	origin = at
	if def.storage_slots > 0:
		stock = Stockpile.new(def.storage_slots, data)


func entrance_tile() -> Vector2i:
	return origin + def.entrance


func tiles() -> Array[Vector2i]:
	return def.footprint_tiles(origin)


func to_dict() -> Dictionary:
	var d := {"id": id, "def": String(def.id), "origin": SimCodec.vec2i(origin), "workers": workers}
	if stock != null:
		d["stock"] = stock.to_dict()
	return d


static func from_dict(d: Dictionary, data: DataRegistry) -> BuildingState:
	var b := BuildingState.new(int(d["id"]), data.get_building(StringName(String(d["def"]))),
			SimCodec.to_vec2i(d["origin"]), data)
	b.workers = SimCodec.int_array(d.get("workers", []))
	if d.has("stock"):
		b.stock = Stockpile.from_dict(d["stock"], data)
	return b
