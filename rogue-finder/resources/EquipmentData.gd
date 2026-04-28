class_name EquipmentData
extends Resource

## --- EquipmentData ---
## One equipment item. Stored in a slot on CombatantData (weapon / armor / accessory).
## stat_bonuses keys are attribute names matching CombatantData fields.

enum Slot { WEAPON = 0, ARMOR = 1, ACCESSORY = 2 }
enum Rarity { COMMON = 0, RARE = 1, EPIC = 2, LEGENDARY = 3 }

## Canonical rarity colors: grey / green / blue / orange.
## Used for item name text and card borders across all UI surfaces.
const RARITY_COLORS: Dictionary = {
	0: Color(0.65, 0.65, 0.65),   # COMMON   — grey
	1: Color(0.25, 0.80, 0.35),   # RARE     — green
	2: Color(0.30, 0.55, 1.00),   # EPIC     — blue
	3: Color(1.00, 0.55, 0.10),   # LEGENDARY — orange
}

@export var equipment_id:         String         = ""
@export var equipment_name:       String         = ""
@export var slot:                 int            = Slot.WEAPON
@export var rarity:               int            = Rarity.COMMON
@export var stat_bonuses:         Dictionary     = {}
@export var granted_ability_ids:  Array[String]  = []
@export var feat_id:              String         = ""
@export var description:          String         = ""

## Returns the delta this item contributes to stat_name, or 0 if not present.
func get_bonus(stat_name: String) -> int:
	return stat_bonuses.get(stat_name, 0)

## Convenience accessor for the rarity display color.
func rarity_color() -> Color:
	return RARITY_COLORS.get(rarity, RARITY_COLORS[Rarity.COMMON])
