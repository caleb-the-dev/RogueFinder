class_name PricingFormula
extends RefCounted

## --- PricingFormula ---
## Single-responsibility helper: turns any item dict into a final integer price.
## Item dicts come from RewardGenerator._eq_to_dict / _con_to_dict — shape:
##   { id, name, description, item_type, rarity }
##
## Caller always supplies the RNG so pricing is deterministic when seeded by
## the vendor scene. No global randi() fallback — save-scumming prevention.

## Base prices per rarity tier. Tune these during playtesting.
const RARITY_BASE_PRICE: Dictionary = {
	EquipmentData.Rarity.COMMON:    10,
	EquipmentData.Rarity.RARE:      40,
	EquipmentData.Rarity.EPIC:     120,
	EquipmentData.Rarity.LEGENDARY: 400,
}

## --- Public API ---

## Returns the gold price for item using rng for the ±10% jitter.
## rarity absent/unknown → defaults to COMMON base price.
## Result is always at least 1.
static func price_for(item: Dictionary, rng: RandomNumberGenerator) -> int:
	var rarity: int = item.get("rarity", EquipmentData.Rarity.COMMON)
	var base: int   = RARITY_BASE_PRICE.get(rarity, RARITY_BASE_PRICE[EquipmentData.Rarity.COMMON])
	var mult: float = rng.randf_range(0.9, 1.1)
	return maxi(1, int(round(float(base) * mult)))
