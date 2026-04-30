class_name StockGenerator
extends RefCounted

## --- StockGenerator ---
## Pre-rolls a vendor's stock manifest from a deterministic seeded RNG.
## Each entry: { vendor_id: String, item: Dictionary, price: int, sold: bool }.
## Caller supplies seed_int so the same seed always yields the same manifest —
## save-scum prevention guarantee.

## Returns up to vendor.stock_count entries drawn from equipment + consumables
## matching vendor.category_pool. Uses a freshly seeded RNG so no global state bleeds in.
static func roll_stock(vendor: VendorData, seed_int: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_int

	var candidates: Array = _build_candidates(vendor.category_pool)

	# Deterministic Fisher-Yates with the seeded RNG
	for i in range(candidates.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Dictionary = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp

	var result: Array = []
	var count: int = mini(vendor.stock_count, candidates.size())
	for i in range(count):
		result.append({
			"vendor_id": vendor.vendor_id,
			"item":      candidates[i],
			"price":     PricingFormula.price_for(candidates[i], rng),
			"sold":      false,
		})
	return result

## --- Internal ---

static func _build_candidates(category_pool: Array[String]) -> Array:
	var candidates: Array = []
	for eq: EquipmentData in EquipmentLibrary.all_equipment():
		var cat: String = EquipmentData.Slot.keys()[eq.slot].to_lower()
		if cat in category_pool:
			candidates.append(RewardGenerator.eq_to_dict(eq))
	if "consumable" in category_pool:
		for c: ConsumableData in ConsumableLibrary.all_consumables():
			candidates.append(RewardGenerator.con_to_dict(c))
	return candidates
