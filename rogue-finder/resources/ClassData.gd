class_name ClassData
extends Resource

## --- ClassData ---
## One playable class. Defines flavor + the single ability granted at character
## creation. Class is an independent axis from Background and Kindred — a
## Barbarian Crook is valid.
##
## Feat system and level-up progression are not modeled here yet; `tags` is
## reserved for future filtering in character-creation UI.

@export var class_id:            String        = ""
@export var display_name:        String        = ""
@export var description:         String        = ""
@export var starting_ability_id: String        = ""
@export var feat_pool:           Array[String] = []
@export var unlocked_by_default: bool          = true
@export var tags:                Array[String] = []

func has_tag(tag: String) -> bool:
	return tags.has(tag)
