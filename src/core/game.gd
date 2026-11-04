extends Node
## Autoload "Game": owns the running simulation and the game speed.
##
## M0 skeleton only. The fixed 10 Hz tick loop and Simulation ownership arrive in M2
## (ARCHITECTURE §4.2).

const SPEEDS: PackedFloat32Array = [1.0, 2.0, 4.0]

var paused: bool = false
var speed_index: int = 0


func get_speed() -> float:
	return 0.0 if paused else SPEEDS[speed_index]


func set_speed_index(index: int) -> void:
	speed_index = clampi(index, 0, SPEEDS.size() - 1)


func toggle_pause() -> void:
	paused = not paused
