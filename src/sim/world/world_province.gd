class_name WorldProvince
extends RefCounted
## What the world knows of one province (ROADMAP M6): its definition, the map it is played on
## and its owner. Its buildings and people live in the province runtime (Simulation.runtime).

var id: int
## ProvinceDef id; empty in a single-province game (the old maps, "Single province").
var def_id: StringName = &""
## MapDef id of the province map (the template).
var map_id: StringName = &""
## ProvinceDef.OWNER_*.
var owner: StringName = ProvinceDef.OWNER_NONE


func _init(province_id: int, province_def: StringName = &"", map: StringName = &"",
		owned_by: StringName = ProvinceDef.OWNER_NONE) -> void:
	id = province_id
	def_id = province_def
	map_id = map
	owner = owned_by


func to_dict() -> Dictionary:
	var d := {"id": id, "map": String(map_id), "owner": String(owner)}
	if def_id != &"":
		d["def"] = String(def_id)
	return d


static func from_dict(d: Dictionary) -> WorldProvince:
	return WorldProvince.new(int(d["id"]), StringName(String(d.get("def", ""))),
			StringName(String(d.get("map", ""))), StringName(String(d.get("owner", ""))))
