extends Node

## --- Unit Tests: Vendor Buy Transaction ---
## Tests: gold debit, inventory insertion with rarity, sold-flag flip,
## insufficient-gold rejection, already-sold rejection, save round-trip.

func _ready() -> void:
	print("=== test_vendor_buy.gd ===")
	EquipmentLibrary.reload()
	ConsumableLibrary.reload()
	VendorLibrary.reload()
	test_buy_debits_gold()
	test_buy_adds_item_with_rarity()
	test_buy_flips_sold_flag()
	test_insufficient_gold_rejected()
	test_already_sold_rejected()
	test_save_round_trip()
	print("=== All vendor buy tests passed ===")

## --- Helpers ---

func _make_entry(price: int, sold: bool = false, rarity: int = EquipmentData.Rarity.RARE) -> Dictionary:
	return {
		"vendor_id": "vendor_weapon",
		"item": {
			"id":          "iron_sword",
			"name":        "Iron Sword",
			"description": "A basic sword.",
			"item_type":   "equipment",
			"rarity":      rarity,
		},
		"price": price,
		"sold":  sold,
	}

func _reset_state() -> void:
	GameState.gold = 0
	GameState.inventory.clear()

## --- Tests ---

## Gold decrements by exactly the item price on a successful buy.
func test_buy_debits_gold() -> void:
	_reset_state()
	GameState.gold = 50
	var entry := _make_entry(20)
	var ok: bool = VendorOverlay.try_buy(entry)
	assert(ok, "buy should succeed when gold >= price")
	assert(GameState.gold == 30, "gold should be 50 - 20 = 30, got %d" % GameState.gold)

## Item lands in inventory with the rarity field intact.
func test_buy_adds_item_with_rarity() -> void:
	_reset_state()
	GameState.gold = 100
	var entry := _make_entry(15, false, EquipmentData.Rarity.EPIC)
	VendorOverlay.try_buy(entry)
	assert(GameState.inventory.size() == 1, "inventory should have 1 item after buy")
	var item: Dictionary = GameState.inventory[0]
	assert(item.get("id", "") == "iron_sword", "item id should be iron_sword")
	assert(item.get("rarity", -1) == EquipmentData.Rarity.EPIC,
		"rarity should be EPIC, got %d" % item.get("rarity", -1))

## sold flag on the entry dict is true after a successful purchase.
func test_buy_flips_sold_flag() -> void:
	_reset_state()
	GameState.gold = 100
	var entry := _make_entry(10)
	assert(not entry["sold"], "entry should start unsold")
	VendorOverlay.try_buy(entry)
	assert(entry["sold"], "sold flag should be true after buy")

## When GameState.gold < price the buy is rejected and all state is unchanged.
func test_insufficient_gold_rejected() -> void:
	_reset_state()
	var price: int = 25
	GameState.gold = price - 1
	var entry := _make_entry(price)
	var ok: bool = VendorOverlay.try_buy(entry)
	assert(not ok, "buy should fail when gold < price")
	assert(GameState.gold == price - 1, "gold must be unchanged on rejection")
	assert(GameState.inventory.is_empty(), "inventory must be empty on rejection")
	assert(not entry["sold"], "sold flag must be unchanged on rejection")

## Calling try_buy on an already-sold entry leaves state unchanged.
func test_already_sold_rejected() -> void:
	_reset_state()
	GameState.gold = 100
	var entry := _make_entry(10, true)
	var ok: bool = VendorOverlay.try_buy(entry)
	assert(not ok, "buy should fail when already sold")
	assert(GameState.gold == 100, "gold must be unchanged when already sold")
	assert(GameState.inventory.is_empty(), "inventory must be empty when already sold")

## After a purchase, gold + inventory item + sold flag all survive a save/load round-trip.
func test_save_round_trip() -> void:
	_reset_state()
	var saved_stocks: Dictionary = GameState.vendor_stocks.duplicate(true)
	var saved_party: Array = GameState.party

	GameState.gold = 60
	var stock: Array = [_make_entry(10)]
	GameState.vendor_stocks["_test_key_"] = stock

	VendorOverlay.try_buy(stock[0])

	## Snapshot post-buy values before wiping
	var expected_gold: int = GameState.gold
	assert(expected_gold == 50, "gold should be 60 - 10 = 50 before save, got %d" % expected_gold)

	GameState.save()

	## Wipe in-memory state, then reload from disk
	GameState.gold = 0
	GameState.inventory.clear()
	GameState.vendor_stocks.clear()
	GameState.load_save()

	assert(GameState.gold == expected_gold,
		"gold should persist: expected %d, got %d" % [expected_gold, GameState.gold])
	assert(GameState.inventory.size() >= 1,
		"inventory item should persist after save/load")
	assert(GameState.vendor_stocks.has("_test_key_"),
		"vendor_stocks key should persist")
	assert(GameState.vendor_stocks["_test_key_"][0]["sold"] == true,
		"sold flag should persist after save/load")

	## Restore state so subsequent tests in the same session aren't affected
	GameState.vendor_stocks = saved_stocks
	GameState.party = saved_party
