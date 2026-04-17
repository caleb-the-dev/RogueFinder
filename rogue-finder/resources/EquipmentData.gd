class_name EquipmentData
extends Resource

## --- EquipmentData ---
## One equipment item. Stored in a slot on CombatantData (weapon / armor / accessory).
## stat_bonuses keys are attribute names matching CombatantData fields.

enum Slot { WEAPON = 0, ARMOR = 1, ACCESSORY = 2 }

@export var equipment_id:   String = ""
@export var equipment_name: String = ""
@export var slot:           int    = Slot.WEAPON
@export var stat_bonuses:   Dictionary = {}
@export var description:    String = ""

## Returns the delta this item contributes to stat_name, or 0 if not present.
func get_bonus(stat_name: String) -> int:
	return stat_bonuses.get(stat_name, 0)
