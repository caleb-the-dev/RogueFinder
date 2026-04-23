class_name PortraitData
extends Resource

## --- PortraitData ---
## One selectable portrait for character creation. `artwork_path` is a
## `res://` path loaded at runtime; all placeholder entries point at
## `res://icon.svg` per project convention (CLAUDE.md § placeholder art).
##
## `tags` hints at kindred affinity (e.g. "human", "dwarf") for downstream
## UI filtering. The library itself never filters on tags.

@export var portrait_id:   String        = ""
@export var portrait_name: String        = ""
@export var artwork_path:  String        = ""
@export var tags:          Array[String] = []

func has_tag(tag: String) -> bool:
	return tags.has(tag)
