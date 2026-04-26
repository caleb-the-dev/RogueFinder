class_name BackgroundData
extends Resource

## --- BackgroundData ---
## One character background. Backgrounds own the feat lane — 1 defining feat granted at
## creation plus 2 pool feats available during the run. No ability granted.
##
## Archetypes restrict WHICH backgrounds a character can roll (see
## ArchetypeLibrary.ARCHETYPES[...].backgrounds). This resource defines what a
## background IS; it is not the place to express archetype restrictions.

@export var background_id:    String        = ""
@export var background_name:  String        = ""
@export var description:      String        = ""
@export var starting_feat_id: String        = ""
@export var feat_pool:        Array[String] = []
@export var unlocked_by_default: bool       = true
@export var tags:             Array[String] = []
@export var stat_bonuses:     Dictionary    = {}

## Convenience for event-hook style checks — "does this background carry the 'urban' tag?"
func has_tag(tag: String) -> bool:
	return tags.has(tag)
