extends Node
## Autoload "Data": the game's read-only definition registry.
##
## Simulation code must not reach for this autoload directly; it receives the
## [DataRegistry] instance explicitly (ARCHITECTURE §14).

const DATA_ROOT := "res://data"

var registry: DataRegistry = DataRegistry.new()


func _ready() -> void:
	registry.load_from(DATA_ROOT)
	for error: String in registry.errors:
		push_error("Data: " + error)
