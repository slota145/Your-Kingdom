class_name EntityIds
extends RefCounted
## Source of unique entity ids (buildings, agents, piles). 0 means "none". Saved.

var next_id: int = 1


func take() -> int:
	var id := next_id
	next_id += 1
	return id
