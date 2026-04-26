class_name KindredData
extends Resource

## --- KindredData ---
## One kindred (species/ancestry). Holds mechanical bonuses and the feat id
## granted at character creation. Name/description of the feat lives in FeatLibrary.

@export var kindred_id:  String        = ""
@export var speed_bonus: int           = 0
@export var hp_bonus:    int           = 0
@export var feat_id:     String        = ""
@export var name_pool:   Array[String] = []
