extends Node

## --- Unit Tests: Vendor Stock Generation ---
## Tests: determinism, seed variance, category filtering, stock count, sold-flag
## round-trip, and regen_world_vendor_stocks() WORLD-only regeneration.

func _ready() -> void:
	print("=== test_vendor_stock.gd ===")
	VendorLibrary.reload()
	EquipmentLibrary.reload()
	ConsumableLibrary.reload()
	test_determinism()
	test_different_seeds_vary()
	test_category_filter_weapon_only()
	test_mixed_pool_covers_multiple_categories()
	test_stock_count_matches_vendor()
	test_sold_flag_json_round_trip()
	test_regen_world_leaves_city_untouched()
	print("=== All vendor stock tests passed ===")

## Same seed → identical item ids and prices across two independent roll_stock calls.
func test_determinism() -> void:
	var vendor: VendorData = VendorLibrary.get_vendor("road_peddler")
	var a: Array = StockGenerator.roll_stock(vendor, 12345)
	var b: Array = StockGenerator.roll_stock(vendor, 12345)
	assert(a.size() == b.size(), "determinism: size mismatch")
	assert(a.size() > 0, "determinism: stock must not be empty")
	for i in range(a.size()):
		assert(a[i]["item"]["id"] == b[i]["item"]["id"],
			"determinism: item id mismatch at index %d" % i)
		assert(a[i]["price"] == b[i]["price"],
			"determinism: price mismatch at index %d" % i)

## Different seeds → at least one id differs across 5 trial pairs.
func test_different_seeds_vary() -> void:
	var vendor: VendorData = VendorLibrary.get_vendor("road_peddler")
	var base_ids: Array = StockGenerator.roll_stock(vendor, 111).map(
		func(e: Dictionary) -> String: return e["item"]["id"]
	)
	var found_diff: bool = false
	for trial in range(5):
		var other_ids: Array = StockGenerator.roll_stock(vendor, 222 + trial * 999).map(
			func(e: Dictionary) -> String: return e["item"]["id"]
		)
		if base_ids != other_ids:
			found_diff = true
			break
	assert(found_diff, "different seeds should produce different item orderings in at least 1 of 5 trials")

## Weapon-only vendor only stocks WEAPON-slot equipment (no armor, accessory, consumable).
func test_category_filter_weapon_only() -> void:
	var vendor: VendorData = VendorLibrary.get_vendor("vendor_weapon")
	var stock: Array = StockGenerator.roll_stock(vendor, 42)
	assert(stock.size() > 0, "weapon vendor stock must not be empty")
	for entry: Dictionary in stock:
		assert(entry["item"]["item_type"] == "equipment",
			"weapon vendor: expected item_type=equipment, got '%s'" % entry["item"]["item_type"])
		var eq: EquipmentData = EquipmentLibrary.get_equipment(entry["item"]["id"])
		assert(eq.slot == EquipmentData.Slot.WEAPON,
			"weapon vendor: item '%s' is not WEAPON slot" % entry["item"]["id"])

## Mixed-pool vendor (weapon|armor|accessory|consumable) stocks ≥2 distinct categories
## across 10 rolls with varying seeds.
func test_mixed_pool_covers_multiple_categories() -> void:
	var vendor: VendorData = VendorLibrary.get_vendor("road_peddler")
	var seen_categories: Dictionary = {}
	for trial in range(10):
		var stock: Array = StockGenerator.roll_stock(vendor, 1000 + trial * 7)
		for entry: Dictionary in stock:
			if entry["item"]["item_type"] == "consumable":
				seen_categories["consumable"] = true
			else:
				var eq: EquipmentData = EquipmentLibrary.get_equipment(entry["item"]["id"])
				var cat: String = EquipmentData.Slot.keys()[eq.slot].to_lower()
				seen_categories[cat] = true
	assert(seen_categories.size() >= 2,
		"mixed vendor: expected >= 2 categories across 10 rolls, got %d" % seen_categories.size())

## stock count in the returned array matches vendor.stock_count (when pool is large enough).
func test_stock_count_matches_vendor() -> void:
	var vendor: VendorData = VendorLibrary.get_vendor("vendor_consumable")
	var stock: Array = StockGenerator.roll_stock(vendor, 777)
	assert(stock.size() == vendor.stock_count,
		"stock count %d != vendor.stock_count %d" % [stock.size(), vendor.stock_count])

## sold=true flag survives JSON encode → decode (mirrors the save-file round-trip).
func test_sold_flag_json_round_trip() -> void:
	var test_stocks: Dictionary = {
		"vendor_weapon": [{
			"vendor_id": "vendor_weapon",
			"item": {"id": "iron_sword", "name": "Iron Sword", "description": "A sword.",
					 "item_type": "equipment", "rarity": 0},
			"price": 15,
			"sold":  true,
		}]
	}
	var json_str: String = JSON.stringify({"vendor_stocks": test_stocks})
	var decoded = JSON.parse_string(json_str)
	assert(decoded is Dictionary, "sold round-trip: JSON parse failed")
	var decoded_entry: Dictionary = decoded["vendor_stocks"]["vendor_weapon"][0]
	assert(decoded_entry["sold"] == true,
		"sold round-trip: sold flag lost after JSON encode/decode")
	assert(decoded_entry["price"] == 15,
		"sold round-trip: price changed after JSON encode/decode")

## regen_world_vendor_stocks() rerolls WORLD entries and leaves CITY entries untouched.
func test_regen_world_leaves_city_untouched() -> void:
	# Snapshot old state so we can restore it after the test
	var saved_node_types: Dictionary = GameState.node_types.duplicate()
	var saved_map_seed: int = GameState.map_seed
	var saved_stocks: Dictionary = GameState.vendor_stocks.duplicate(true)

	# Set up a controlled scenario
	GameState.map_seed = 55555
	GameState.node_types = {"node_o1": "VENDOR", "node_m2": "COMBAT", "badurga": "CITY"}
	GameState.vendor_stocks = {
		# CITY stock — a sentinel the regen must NOT touch
		"vendor_weapon": [{"vendor_id": "vendor_weapon",
			"item": {"id": "sentinel_item"}, "price": 99999, "sold": false}],
		# WORLD stock — a placeholder the regen MUST replace
		"node_o1": [{"vendor_id": "placeholder", "item": {"id": "placeholder_item"},
			"price": 00001, "sold": true}],
	}

	GameState.regen_world_vendor_stocks()

	# CITY stock must be untouched
	assert(GameState.vendor_stocks.has("vendor_weapon"),
		"regen: CITY key vendor_weapon missing after regen")
	assert(GameState.vendor_stocks["vendor_weapon"][0]["price"] == 99999,
		"regen: CITY stock must not be modified")

	# WORLD stock must be regenerated (no longer the placeholder)
	assert(GameState.vendor_stocks.has("node_o1"),
		"regen: WORLD key node_o1 missing after regen")
	var world_stock: Array = GameState.vendor_stocks["node_o1"]
	var is_still_placeholder: bool = (world_stock.size() == 1
		and world_stock[0].get("price", -1) == 1
		and world_stock[0].get("item", {}).get("id", "") == "placeholder_item")
	assert(not is_still_placeholder,
		"regen: WORLD stock should be regenerated, not still placeholder")

	# Restore state
	GameState.node_types  = saved_node_types
	GameState.map_seed    = saved_map_seed
	GameState.vendor_stocks = saved_stocks
