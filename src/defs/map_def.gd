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
## Start from a ship (M5 part 3): no buildings stand; a cog anchors at [member landing_tile]
## (deep water), the settlers wade to [member beach_tile] and the start kit lies there.
@export var start_by_ship: bool = false
@export var landing_tile: Vector2i = Vector2i(-1, -1)
@export var beach_tile: Vector2i = Vector2i(-1, -1)
## Kinds of the settlers aboard, in the order they come ashore.
@export var start_settlers: Array[StringName] = []
## The start kit on the beach: good -> units.
@export var start_pile: Dictionary[StringName, int] = {}
## The only building the player may place until it stands (the pioneer camp); empty = any.
@export var first_building: StringName = &""


func get_kind() -> StringName:
	return &"map"


func size() -> Vector2i:
	return Vector2i(terrain_image.get_width(), terrain_image.get_height()) \
			if terrain_image != null else Vector2i.ZERO
