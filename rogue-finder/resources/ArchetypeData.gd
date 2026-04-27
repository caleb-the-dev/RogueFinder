class_name ArchetypeData
extends Resource

## --- ArchetypeData ---
## One archetype (enemy template or player blueprint). Holds all per-archetype
## fixed data and stat ranges. Populated by ArchetypeLibrary from archetypes.csv.
##
## Numeric range fields are [min, max] — ArchetypeLibrary.create() rolls within them.

@export var archetype_id:    String        = ""
@export var unit_class:      String        = ""
@export var kindred:         String        = ""
@export var backgrounds:     Array[String] = []
@export var abilities:       Array[String] = []  # exactly 4; "" = empty slot
@export var pool_extras:     Array[String] = []
@export var consumable:      String        = ""
@export var str_range:       Array[int]    = [0, 0]
@export var dex_range:       Array[int]    = [0, 0]
@export var cog_range:       Array[int]    = [0, 0]
@export var wil_range:       Array[int]    = [0, 0]
@export var vit_range:       Array[int]    = [1, 1]
@export var physical_armor_range: Array[int] = [0, 0]
@export var magic_armor_range:    Array[int] = [0, 0]
@export var qte_range:       Array[float]  = [0.0, 0.0]
@export var artwork_idle:    String        = ""
@export var artwork_attack:  String        = ""
