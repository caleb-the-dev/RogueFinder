class_name RewardGenerator
extends RefCounted

## --- RewardGenerator ---
## Builds a randomized reward pool from all equipment + consumables.
## Equipment is selected with weighted rarity — Common 60% / Rare 25% / Epic 12% / Legendary 3%.
## Returns plain Dictionaries so EndCombatScreen has no resource dependencies.

## Sum must equal 100. Scale these later by boss iteration / player level.
const RARITY_WEIGHTS: Dictionary = {
	EquipmentData.Rarity.COMMON:    60,
	EquipmentData.Rarity.RARE:      25,
	EquipmentData.Rarity.EPIC:      12,
	EquipmentData.Rarity.LEGENDARY:  3,
}

## Returns `count` distinct items as Dicts: {id, name, description, item_type, rarity}.
## Equipment selection is rarity-weighted; consumables are included in the COMMON bucket.
static func roll(count: int) -> Array:
	# Bucket equipment by rarity
	var eq_buckets: Dictionary = {}
	for eq: EquipmentData in EquipmentLibrary.all_equipment():
		if not eq_buckets.has(eq.rarity):
			eq_buckets[eq.rarity] = []
		(eq_buckets[eq.rarity] as Array).append(_eq_to_dict(eq))

	# Consumables land in the COMMON bucket
	if not eq_buckets.has(EquipmentData.Rarity.COMMON):
		eq_buckets[EquipmentData.Rarity.COMMON] = []
	for c: ConsumableData in ConsumableLibrary.all_consumables():
		(eq_buckets[EquipmentData.Rarity.COMMON] as Array).append(_con_to_dict(c))

	var result: Array = []
	var used_ids: Dictionary = {}
	var max_attempts: int = count * 20

	for _attempt in range(max_attempts):
		if result.size() >= count:
			break
		var rarity: int = _roll_rarity()
		var bucket: Array = eq_buckets.get(rarity, [])
		if bucket.is_empty():
			bucket = eq_buckets.get(EquipmentData.Rarity.COMMON, [])
		if bucket.is_empty():
			continue
		var candidate: Dictionary = bucket[randi() % bucket.size()]
		var cid: String = candidate["id"]
		if used_ids.has(cid):
			continue
		used_ids[cid] = true
		result.append(candidate)

	return result

## Weighted pick across configured rarity tiers (all 100 weight, no redistribution).
## Falls back to COMMON in callers when the rolled tier bucket is empty.
static func _roll_rarity() -> int:
	var roll: int = randi() % 100
	var acc: int = 0
	for tier in [EquipmentData.Rarity.COMMON, EquipmentData.Rarity.RARE,
				 EquipmentData.Rarity.EPIC, EquipmentData.Rarity.LEGENDARY]:
		acc += RARITY_WEIGHTS[tier]
		if roll < acc:
			return tier
	return EquipmentData.Rarity.COMMON

static func _eq_to_dict(eq: EquipmentData) -> Dictionary:
	return {
		"id":          eq.equipment_id,
		"name":        eq.equipment_name,
		"description": eq.description,
		"item_type":   "equipment",
		"rarity":      eq.rarity,
	}

static func _con_to_dict(c: ConsumableData) -> Dictionary:
	return {
		"id":          c.consumable_id,
		"name":        c.consumable_name,
		"description": c.description,
		"item_type":   "consumable",
		"rarity":      EquipmentData.Rarity.COMMON,
	}
