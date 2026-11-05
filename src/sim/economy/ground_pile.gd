class_name GroundPile
extends RefCounted
## Goods lying on the ground (dropped after a failed delivery or left by a demolition).
## Porters pick them up; a pile only gives goods, it never accepts deliveries.

var id: int
var tile: Vector2i
var stock: Stockpile


func _init(entity_id: int, at: Vector2i, data: DataRegistry) -> void:
	id = entity_id
	tile = at
	stock = Stockpile.new(1, data)


func good() -> StringName:
	return stock.slot_good[0]


func to_dict() -> Dictionary:
	return {"id": id, "tile": SimCodec.vec2i(tile), "stock": stock.to_dict()}


static func from_dict(d: Dictionary, data: DataRegistry) -> GroundPile:
	var pile := GroundPile.new(int(d["id"]), SimCodec.to_vec2i(d["tile"]), data)
	pile.stock = Stockpile.from_dict(d["stock"], data)
	return pile
