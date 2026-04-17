class_name ConsumableData
extends Resource

## --- ConsumableData ---
## Typed data record for a single consumable item.
## Instances are created by ConsumableLibrary.get_consumable() — never set fields directly.
## Only MEND, BUFF, and DEBUFF effect types are valid — consumables never HARM, FORCE, or TRAVEL.

@export var consumable_id:   String               = ""
@export var consumable_name: String               = ""
@export var effect_type:     EffectData.EffectType = EffectData.EffectType.MEND
@export var base_value:      int                  = 0
## Stores an AbilityData.Attribute int — used by BUFF/DEBUFF only.
@export var target_stat:     int                  = 0
@export var description:     String               = ""
