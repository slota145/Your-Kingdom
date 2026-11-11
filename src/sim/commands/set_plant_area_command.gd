class_name SetPlantAreaCommand
extends Command
## Marks tiles where a forester plants (M4b-1.5, owner's decision 2026-11-05), or clears the
## marks ([param tiles] empty). Tiles outside its work area are left out. With no marks it
## plants anywhere in range.

var building_id: int
var tiles: Array[Vector2i]


func _init(building: int, marked: Array[Vector2i]) -> void:
	building_id = building
	tiles = marked


func validate(sim: Simulation) -> StringName:
	var building := sim.province.buildings.get_building(building_id)
	if building == null:
		return &"unknown_building"
	if not building.def.plants_trees():
		return &"not_a_forester"
	return &""


func apply(sim: Simulation) -> void:
	var building := sim.province.buildings.get_building(building_id)
	if tiles.is_empty():
		building.plant_area.clear()
	else:
		var area := Rect2i(building.origin, building.def.footprint).grow(sim.province.work_radius(building))
		for t: Vector2i in tiles:
			if area.has_point(t) and sim.province.grid.is_inside(t) and not building.plant_area.has(t):
				building.plant_area.append(t)
	sim.events.emit(&"plant_area_changed", {"building": building_id})


func get_name() -> StringName:
	return &"set_plant_area"
