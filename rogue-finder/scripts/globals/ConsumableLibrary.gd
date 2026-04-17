class_name ConsumableLibrary
extends RefCounted

## --- ConsumableLibrary ---
## Static definitions for all consumable items in the game.
## A future CSV import will replace CONSUMABLES without changing the get_consumable() signature.
##
## Adding a consumable: add one entry to CONSUMABLES; nothing else changes.

## --- Schema ---
## "name"        : String
## "effect_type" : EffectData.EffectType  (MEND, BUFF, or DEBUFF only)
## "base_value"  : int
## "target_stat" : AbilityData.Attribute  (BUFF / DEBUFF only; omit for MEND)
## "description" : String

const CONSUMABLES: Dictionary = {
	"healing_potion": {
		"name":        "Healing Potion",
		"effect_type": EffectData.EffectType.MEND,
		"base_value":  15,
		"description": "Restore 15 HP.",
	},
	"power_tonic": {
		"name":        "Power Tonic",
		"effect_type": EffectData.EffectType.BUFF,
		"base_value":  2,
		"target_stat": AbilityData.Attribute.STRENGTH,
		"description": "Boost Strength by 2 for this battle.",
	},
}

## Returns a populated ConsumableData for the given ID.
## Falls back to a blank stub for unknown IDs — never returns null.
static func get_consumable(consumable_id: String) -> ConsumableData:
	if not CONSUMABLES.has(consumable_id):
		var stub := ConsumableData.new()
		stub.consumable_id   = "unknown"
		stub.consumable_name = "Unknown"
		stub.description     = "No consumable data found for ID: " + consumable_id
		return stub

	var def: Dictionary = CONSUMABLES[consumable_id]
	var c := ConsumableData.new()
	c.consumable_id   = consumable_id
	c.consumable_name = def["name"]
	c.effect_type     = def["effect_type"]
	c.base_value      = def["base_value"]
	c.target_stat     = def.get("target_stat", 0)
	c.description     = def["description"]
	return c
