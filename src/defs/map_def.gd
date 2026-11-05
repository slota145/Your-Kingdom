class_name MapDef
extends GameDef
## A hand-made province map: an image where each pixel colour is a terrain (TerrainDef.map_color)
## plus the start layout (ROADMAP M3).

## Imported as an Image (not a texture) so the simulation can read pixels headless.
@export var terrain_image: Image
## Map-edge tile where newcomers enter the province.
@export var entry_tile: Vector2i = Vector2i.ZERO
@export var start_buildings: Array[StartBuildingDef] = []


func get_kind() -> StringName:
	return &"map"


func size() -> Vector2i:
	return Vector2i(terrain_image.get_width(), terrain_image.get_height()) \
			if terrain_image != null else Vector2i.ZERO
