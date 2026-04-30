class_name RewardGenerator
extends RefCounted

## --- RewardGenerator ---
## Builds a randomized reward pool from all equipment + consumables.
## Equipment is selected with weighted rarity — Common 60% / Rare 25% / Epic 12% / Legendary 3%.
## Returns plain Dictionaries so EndCombatScreen has no resource dependencies.

## --- Gold Drop Formula ---
## gold_drop(ring, threat, party_avg_level) -> int
## Base gold per ring reflects traversal depth — outer nodes are harder to reach.
## THREAT_COEFF scales 0–100 threat (percentage × 100 of GameState.threat_level) → 0–15 bonus.
## LEVEL_COEFF scales party avg level 1–20 → 3–60 bonus.
## Final value is jittered ±10% so back-to-back combats don't feel identical.
const RING_BASE: Dictionary = { "outer": 30, "middle": 20, "inner": 12 }
const THREAT_COEFF: float   = 0.15
const LEVEL_COEFF:  float   = 3.0

## Returns gold earned on combat victory. threat is 0–100 (GameState.threat_level * 100 rounded).
static func gold_drop(ring: String, threat: int, party_avg_level: int) -> int:
	var base: float = float(RING_BASE.get(ring, RING_BASE["inner"]))
	var raw:  float = (base + THREAT_COEFF * threat + LEVEL_COEFF * party_avg_level) \
		* randf_range(0.9, 1.1)
	return maxi(1, roundi(raw))

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
		(eq_buckets[eq.rarity] as Array).append(eq_to_dict(eq))

	# Consumables land in the COMMON bucket
	if not eq_buckets.has(EquipmentData.Rarity.COMMON):
		eq_buckets[EquipmentData.Rarity.COMMON] = []
	for c: ConsumableData in ConsumableLibrary.all_consumables():
		(eq_buckets[EquipmentData.Rarity.COMMON] as Array).append(con_to_dict(c))

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
	var r: int = randi() % 100
	var acc: int = 0
	for tier in [EquipmentData.Rarity.COMMON, EquipmentData.Rarity.RARE,
				 EquipmentData.Rarity.EPIC, EquipmentData.Rarity.LEGENDARY]:
		acc += RARITY_WEIGHTS[tier]
		if r < acc:
			return tier
	return EquipmentData.Rarity.COMMON

## Public helpers — used by StockGenerator to build item dicts without duplication.
static func eq_to_dict(eq: EquipmentData) -> Dictionary:
	return {
		"id":          eq.equipment_id,
		"name":        eq.equipment_name,
		"description": eq.description,
		"item_type":   "equipment",
		"rarity":      eq.rarity,
	}

static func con_to_dict(c: ConsumableData) -> Dictionary:
	return {
		"id":          c.consumable_id,
		"name":        c.consumable_name,
		"description": c.description,
		"item_type":   "consumable",
		"rarity":      EquipmentData.Rarity.COMMON,
	}
