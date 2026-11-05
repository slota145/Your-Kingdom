class_name AgentVisualDef
extends Resource
## How a kind of person looks: which character art and a tint telling professions apart
## until each has its own art. File: data/visuals/agents/<kind>.tres.

@export var character: StringName = &"peasant"
@export var tint: Color = Color.WHITE


static func for_kind(kind: StringName) -> AgentVisualDef:
	var path := "res://data/visuals/agents/%s.tres" % kind
	return load(path) as AgentVisualDef if ResourceLoader.exists(path) else null
