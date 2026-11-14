class_name MusicTrackDef
extends Resource
## A piece of music (ROADMAP M10 part 1) and the moments it suits.

@export var id: StringName = &""
## File under res://assets/audio/.
@export var file: String = ""
## Where it may play: &"menu" (main menu), &"peace" (a province at peace).
@export var moods: Array[StringName] = []
@export_range(-40.0, 12.0) var volume_db: float = 0.0
## Who made it, for the credits (assets/audio/CREDITS.md has the full list).
@export var author: String = ""
