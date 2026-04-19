class_name BackgroundData
extends Resource

## --- BackgroundData ---
## One character background. Defines the flavor + starting ability + feat pool
## handed to a character at creation (GAME_BIBLE: "1 action from their background";
## odd-level feat draws pull from class OR background pools).
##
## Archetypes restrict WHICH backgrounds a character can roll (see
## ArchetypeLibrary.ARCHETYPES[...].backgrounds). This resource defines what a
## background IS; it is not the place to express archetype restrictions.

@export var background_id:       String        = ""
@export var background_name:     String        = ""
@export var starting_ability_id: String        = ""
@export var feat_pool:           Array[String] = []
@export var unlocked_by_default: bool          = true
@export var tags:                Array[String] = []
@export var description:         String        = ""

## Convenience for event-hook style checks — "does this background carry the 'urban' tag?"
func has_tag(tag: String) -> bool:
	return tags.has(tag)
