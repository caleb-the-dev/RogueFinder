extends Node

## --- Unit Tests: GameState inventory (party bag) — Persistent Party Slice 4 ---
## All items land in the shared bag as raw dicts; nothing is auto-assigned on pickup.

func _ready() -> void:
	print("=== test_inventory.gd ===")
	test_add_equipment_to_bag()
	test_add_consumable_to_bag()
	test_remove_by_id()
	test_remove_id_not_in_bag()
	test_round_trip()
	print("=== All inventory tests passed ===")

func _clean() -> void:
	GameState.delete_save()
	GameState.reset()

## --- Tests ---

func test_add_equipment_to_bag() -> void:
	_clean()
	GameState.add_to_inventory({"id": "short_sword", "name": "Short Sword", "description": "A simple blade.", "item_type": "equipment"})
	assert(GameState.inventory.size() == 1,
		"bag should have 1 item, got %d" % GameState.inventory.size())
	assert(GameState.inventory[0]["id"] == "short_sword",
		"bag[0] id mismatch: expected 'short_sword', got '%s'" % GameState.inventory[0]["id"])
	assert(GameState.inventory[0]["item_type"] == "equipment", "item_type should be 'equipment'")
	print("  PASS test_add_equipment_to_bag")

func test_add_consumable_to_bag() -> void:
	_clean()
	GameState.add_to_inventory({"id": "health_potion", "name": "Health Potion", "description": "Heals.", "item_type": "consumable"})
	assert(GameState.inventory.size() == 1,
		"consumable should land in bag, got %d items" % GameState.inventory.size())
	assert(GameState.inventory[0]["item_type"] == "consumable", "item_type should be 'consumable'")
	print("  PASS test_add_consumable_to_bag")

func test_remove_by_id() -> void:
	_clean()
	GameState.add_to_inventory({"id": "iron_ring", "name": "Iron Ring", "description": "Adds constitution.", "item_type": "equipment"})
	var removed: bool = GameState.remove_from_inventory("iron_ring")
	assert(removed == true, "remove_from_inventory should return true for a present id")
	assert(GameState.inventory.size() == 0,
		"bag should be empty after removal, got %d" % GameState.inventory.size())
	print("  PASS test_remove_by_id")

func test_remove_id_not_in_bag() -> void:
	_clean()
	var removed: bool = GameState.remove_from_inventory("lucky_charm")
	assert(removed == false, "remove_from_inventory should return false for an absent id")
	print("  PASS test_remove_id_not_in_bag")

func test_round_trip() -> void:
	_clean()
	GameState.add_to_inventory({"id": "leather_armor", "name": "Leather Armor", "description": "Light protection.", "item_type": "equipment"})
	GameState.add_to_inventory({"id": "health_potion", "name": "Health Potion", "description": "Heals.", "item_type": "consumable"})
	assert(GameState.inventory.size() == 2, "pre-save bag size should be 2")
	GameState.save()
	GameState.reset()
	assert(GameState.inventory.size() == 0, "bag should be empty after reset")
	GameState.load_save()
	assert(GameState.inventory.size() == 2,
		"bag should have 2 items after load, got %d" % GameState.inventory.size())
	assert(GameState.inventory[0]["id"] == "leather_armor", "bag[0] id mismatch after round-trip")
	assert(GameState.inventory[1]["id"] == "health_potion", "bag[1] id mismatch after round-trip")
	assert(GameState.inventory[1]["item_type"] == "consumable", "item_type should survive round-trip")
	print("  PASS test_round_trip")
