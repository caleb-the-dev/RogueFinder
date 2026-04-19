extends Node

## --- Unit Tests: GameState inventory — Persistent Party Slice 4 ---
## Covers add_to_inventory(), remove_from_inventory(), and save/load round-trip.
## No scene nodes, timers, or signals required.

func _ready() -> void:
	print("=== test_inventory.gd ===")
	test_add_equipment_to_inventory()
	test_add_consumable_to_party_slot()
	test_add_consumable_all_slots_full()
	test_remove_from_inventory()
	test_remove_item_not_in_inventory()
	test_round_trip()
	print("=== All inventory tests passed ===")

func _clean() -> void:
	GameState.delete_save()
	GameState.reset()

## --- Tests ---

func test_add_equipment_to_inventory() -> void:
	_clean()
	GameState.add_to_inventory({"id": "short_sword", "name": "Short Sword", "description": "A simple blade.", "item_type": "equipment"})
	assert(GameState.inventory.size() == 1,
		"inventory should have 1 item, got %d" % GameState.inventory.size())
	assert(GameState.inventory[0].equipment_id == "short_sword",
		"inventory[0] id mismatch: expected 'short_sword', got '%s'" % GameState.inventory[0].equipment_id)
	print("  PASS test_add_equipment_to_inventory")

func test_add_consumable_to_party_slot() -> void:
	_clean()
	GameState.init_party()
	GameState.party[0].consumable = ""
	GameState.add_to_inventory({"id": "health_potion", "name": "Health Potion", "description": "Heals.", "item_type": "consumable"})
	assert(GameState.party[0].consumable == "health_potion",
		"party[0].consumable should be 'health_potion', got '%s'" % GameState.party[0].consumable)
	assert(GameState.inventory.size() == 0,
		"consumable should not be in inventory, got %d items" % GameState.inventory.size())
	print("  PASS test_add_consumable_to_party_slot")

func test_add_consumable_all_slots_full() -> void:
	_clean()
	GameState.init_party()
	for member in GameState.party:
		member.consumable = "health_potion"
	GameState.add_to_inventory({"id": "energy_drink", "name": "Energy Drink", "description": "Restores energy.", "item_type": "consumable"})
	# All slots full — consumable should be silently dropped; no crash, inventory unchanged
	assert(GameState.inventory.size() == 0,
		"inventory should still be empty when all consumable slots full, got %d" % GameState.inventory.size())
	for member in GameState.party:
		assert(member.consumable == "health_potion",
			"party consumable slots should be unchanged when overflow occurs")
	print("  PASS test_add_consumable_all_slots_full")

func test_remove_from_inventory() -> void:
	_clean()
	GameState.add_to_inventory({"id": "iron_ring", "name": "Iron Ring", "description": "Adds constitution.", "item_type": "equipment"})
	var item: EquipmentData = GameState.inventory[0]
	var removed: bool = GameState.remove_from_inventory(item)
	assert(removed == true, "remove_from_inventory should return true for a present item")
	assert(GameState.inventory.size() == 0,
		"inventory should be empty after removal, got %d" % GameState.inventory.size())
	print("  PASS test_remove_from_inventory")

func test_remove_item_not_in_inventory() -> void:
	_clean()
	var phantom: EquipmentData = EquipmentLibrary.get_equipment("lucky_charm")
	var removed: bool = GameState.remove_from_inventory(phantom)
	assert(removed == false, "remove_from_inventory should return false for an absent item")
	print("  PASS test_remove_item_not_in_inventory")

func test_round_trip() -> void:
	_clean()
	GameState.add_to_inventory({"id": "leather_armor", "name": "Leather Armor", "description": "Light protection.", "item_type": "equipment"})
	GameState.add_to_inventory({"id": "hunters_bow", "name": "Hunter's Bow", "description": "Better range.", "item_type": "equipment"})
	assert(GameState.inventory.size() == 2, "pre-save inventory size should be 2")
	var ids_before: Array[String] = []
	for eq in GameState.inventory:
		ids_before.append(eq.equipment_id)
	GameState.save()
	GameState.reset()
	assert(GameState.inventory.size() == 0, "inventory should be empty after reset")
	GameState.load_save()
	assert(GameState.inventory.size() == 2,
		"inventory should have 2 items after load, got %d" % GameState.inventory.size())
	for i in range(ids_before.size()):
		assert(GameState.inventory[i].equipment_id == ids_before[i],
			"inventory[%d] id mismatch: expected '%s', got '%s'" %
			[i, ids_before[i], GameState.inventory[i].equipment_id])
	print("  PASS test_round_trip")
