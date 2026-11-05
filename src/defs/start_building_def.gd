class_name StartBuildingDef
extends Resource
## One building standing, finished, when a map starts (part of a MapDef).

@export var building: StringName = &""
@export var origin: Vector2i = Vector2i.ZERO
## For houses: residents living there at the start.
@export_range(0, 64) var residents: int = 0
## For storages: goods stored at the start.
@export var goods: Dictionary[StringName, int] = {}
