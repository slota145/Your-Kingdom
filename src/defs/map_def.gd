class_name MapDef
extends GameDef
## A hand-made province map: an image where each pixel colour is a terrain (TerrainDef.map_color)
## plus the start layout (ROADMAP M3).

## Imported as an Image (not a texture) so the simulation can read pixels headless.
@export var terrain_image: Image
## Map-edge tile where newcomers enter the province.
@export var entry_tile: Vector2i = Vector2i.ZERO
@export var start_buildings: Array[StartBuildingDef] = []
## Gold in the treasury at the start (GDD §3.5).
@export_range(0, 99999) var start_gold: int = 0
## Single resource nodes placed on top of the terrain (rock outcrops): tile -> node id.
@export var resource_spots: Dictionary[Vector2i, StringName] = {}


func get_kind() -> StringName:
	return &"map"


func size() -> Vector2i:
	return Vector2i(terrain_image.get_width(), terrain_image.get_height()) \
			if terrain_image != null else Vector2i.ZERO
