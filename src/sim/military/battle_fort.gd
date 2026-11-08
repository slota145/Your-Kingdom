class_name BattleFort
extends RefCounted
## What the defender of a siege stands behind.

## Walls.NONE, Walls.PALISADE or Walls.STONE: the weakest ring around the town hall.
var wall: int = Walls.NONE
## Life of one tile of it (ProvinceSim.wall_hp) and of the gate (0 = no gate).
var wall_hp: int = 0
var gate_hp: int = 0
## Life of the town hall's door.
var door_hp: int = 1500


func _init(kind: int = Walls.NONE, tile_hp: int = 0, gate: int = 0, door: int = 1500) -> void:
	wall = kind
	wall_hp = tile_hp
	gate_hp = gate
	door_hp = door
