class_name GameDef
extends Resource
## Base class for all data-driven game definitions stored in res://data.
##
## Player-visible texts are never stored here: names and descriptions are
## localization keys derived from [member id] (see [method name_key]).

## Stable identifier in snake_case. Persisted in save games, never rename after release.
@export var id: StringName = &""


## Category of definition, e.g. &"good" or &"building". Used as a registry bucket
## and as the localization key prefix. Subclasses must override.
func get_kind() -> StringName:
	return &""


func name_key() -> String:
	return "%s.%s.name" % [get_kind(), id]


func desc_key() -> String:
	return "%s.%s.desc" % [get_kind(), id]
