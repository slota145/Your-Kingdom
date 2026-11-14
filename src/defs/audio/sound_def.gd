class_name SoundDef
extends Resource
## A work sound (ROADMAP M10 part 1): a few takes of the same blow, heard where somebody on
## screen does one of [member activities]. The blow falls once per loop of the work
## animation, so the sound keeps time with the swing (ARCHITECTURE §6.9).

@export var id: StringName = &""
## Takes under res://assets/audio/; one is picked at random for every blow.
@export var files: PackedStringArray = PackedStringArray()
## The agent activities (recipe steps' activity) that make this sound.
@export var activities: Array[StringName] = []
@export_range(-40.0, 12.0) var volume_db: float = 0.0
## Each blow is played this much higher or lower at random (0.08 = ±8%), so a row of
## woodcutters does not sound like one machine.
@export_range(0.0, 0.5) var pitch_jitter: float = 0.08
## Where in the loop of the work animation the blow falls (0 = its first frame).
@export_range(0.0, 1.0) var hit: float = 0.5
## Heard once every this many loops of the animation.
@export_range(1, 20) var every: int = 1
## Chance that a due blow is heard (a sheep does not bleat at every cut).
@export_range(0.0, 1.0) var chance: float = 1.0
## At most this many of this sound at once: of many woodcutters the nearest are heard.
@export_range(1, 16) var max_voices: int = 3
