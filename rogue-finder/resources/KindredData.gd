class_name KindredData
extends Resource

## --- KindredData ---
## One kindred (species/ancestry). Holds mechanical bonuses applied at creation.
## Kindreds own the ability lane — 1 natural-attack starter + 2 ancestry abilities in pool.
## Stat bonuses are structural (always-on via get_kindred_stat_bonus()); no feat granted.

@export var kindred_id:           String        = ""
@export var speed_bonus:          int           = 0
@export var hp_bonus:             int           = 0
@export var stat_bonuses:         Dictionary    = {}
@export var starting_ability_id:  String        = ""
@export var ability_pool:         Array[String] = []
@export var name_pool:            Array[String] = []
