class_name KindredData
extends Resource

## --- KindredData ---
## One kindred (species/ancestry). Holds mechanical bonuses and the placeholder
## feat granted at character creation.
## Feats are named but have no gameplay effect yet — mechanical effects land
## when the feat system is implemented.

@export var kindred_id:  String        = ""
@export var speed_bonus: int           = 0
@export var hp_bonus:    int           = 0
@export var feat_id:     String        = ""
@export var feat_name:   String        = ""
@export var feat_desc:   String        = ""
@export var name_pool:   Array[String] = []  # flavor names for auto-naming; owned by kindred, not archetype (S36-prep)
