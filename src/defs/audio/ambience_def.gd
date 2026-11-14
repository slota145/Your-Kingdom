class_name AmbienceDef
extends Resource
## A background sound (ROADMAP M10 part 1): a looping bed and sounds scattered over it (a
## wave, a gull, a bird), as loud as there is of its [member source] on screen.

## Forest: trees on screen. Water: sea, lakes and rivers on screen. Town: people on screen.
enum Source { FOREST, WATER, TOWN }

@export var id: StringName = &""
@export var source: Source = Source.FOREST
## Looping bed under res://assets/audio/ ("" = none).
@export var bed: String = ""
@export_range(-40.0, 12.0) var bed_db: float = 0.0
## One-shots played now and then over the bed.
@export var scatter: PackedStringArray = PackedStringArray()
@export_range(-40.0, 12.0) var scatter_db: float = 0.0
## Seconds between scattered sounds at full level (min, max); fewer when the level is low.
@export var scatter_every: Vector2 = Vector2(4.0, 10.0)
## Share of the screen covered (forest, water) or people seen / 100 (town) at full volume.
@export_range(0.01, 1.0) var full_at: float = 0.4
