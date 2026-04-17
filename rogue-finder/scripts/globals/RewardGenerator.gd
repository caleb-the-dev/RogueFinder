class_name RewardGenerator
extends RefCounted

## --- RewardGenerator ---
## Builds a randomized reward pool from all equipment + consumables.
## Returns plain Dictionaries so EndCombatScreen has no resource dependencies.

## Returns `count` distinct items as Dicts: {id, name, description, item_type}.
static func roll(count: int) -> Array:
	var pool: Array = []

	for eq in EquipmentLibrary.all_equipment():
		pool.append({
			"id":          eq.equipment_id,
			"name":        eq.equipment_name,
			"description": eq.description,
			"item_type":   "equipment",
		})

	for id in ConsumableLibrary.CONSUMABLES:
		var c: ConsumableData = ConsumableLibrary.get_consumable(id)
		pool.append({
			"id":          c.consumable_id,
			"name":        c.consumable_name,
			"description": c.description,
			"item_type":   "consumable",
		})

	# Fisher-Yates shuffle then take first `count`
	for i in range(pool.size() - 1, 0, -1):
		var j: int = randi() % (i + 1)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp

	return pool.slice(0, mini(count, pool.size()))
