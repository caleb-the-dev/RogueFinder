extends Node

func _ready() -> void:
	VendorLibrary.reload()

	# --- all 7 seed vendors load ---
	var all := VendorLibrary.all_vendors()
	assert(all.size() == 7, "expected 7 vendors, got %d" % all.size())

	# --- correct vendor_id and display_name spot-checks ---
	var wp := VendorLibrary.get_vendor("vendor_weapon")
	assert(wp.vendor_id == "vendor_weapon", "vendor_weapon id mismatch")
	assert(wp.display_name == "Ironmonger's Stall", "vendor_weapon display_name mismatch")
	assert(wp.scope == "CITY", "vendor_weapon scope should be CITY")

	var rp := VendorLibrary.get_vendor("road_peddler")
	assert(rp.vendor_id == "road_peddler", "road_peddler id mismatch")
	assert(rp.display_name == "Road Peddler", "road_peddler display_name mismatch")
	assert(rp.scope == "WORLD", "road_peddler scope should be WORLD")

	var aq := VendorLibrary.get_vendor("apothecary_caravan")
	assert(aq.vendor_id == "apothecary_caravan", "apothecary_caravan id mismatch")
	assert(aq.scope == "WORLD", "apothecary_caravan scope should be WORLD")

	# --- single-entry category_pool parses correctly ---
	assert(wp.category_pool.size() == 1, "vendor_weapon pool should have 1 entry")
	assert(wp.category_pool[0] == "weapon", "vendor_weapon pool[0] should be 'weapon'")

	# --- pipe-separated category_pool parses correctly ---
	assert(rp.category_pool.size() == 4, "road_peddler pool should have 4 entries")
	assert(rp.category_pool.has("weapon"), "road_peddler pool missing 'weapon'")
	assert(rp.category_pool.has("armor"), "road_peddler pool missing 'armor'")
	assert(rp.category_pool.has("accessory"), "road_peddler pool missing 'accessory'")
	assert(rp.category_pool.has("consumable"), "road_peddler pool missing 'consumable'")

	var wq := VendorLibrary.get_vendor("wandering_quartermaster")
	assert(wq.category_pool.size() == 2, "wandering_quartermaster pool should have 2 entries")
	assert(wq.category_pool.has("weapon"), "wandering_quartermaster pool missing 'weapon'")
	assert(wq.category_pool.has("armor"), "wandering_quartermaster pool missing 'armor'")

	# --- get_vendor("nonexistent") returns stub, not null ---
	var stub := VendorLibrary.get_vendor("nonexistent")
	assert(stub != null, "stub must not be null")
	assert(stub.vendor_id == "unknown", "stub vendor_id should be 'unknown'")

	# --- vendors_by_scope("CITY") returns exactly 4 ---
	var city := VendorLibrary.vendors_by_scope("CITY")
	assert(city.size() == 4, "expected 4 CITY vendors, got %d" % city.size())

	# --- vendors_by_scope("WORLD") returns exactly 3 ---
	var world := VendorLibrary.vendors_by_scope("WORLD")
	assert(world.size() == 3, "expected 3 WORLD vendors, got %d" % world.size())

	# --- reload() re-parses without leaking old state ---
	VendorLibrary.reload()
	var after := VendorLibrary.all_vendors()
	assert(after.size() == 7, "after reload expected 7 vendors, got %d" % after.size())

	print("test_vendor_library: all assertions passed")
	get_tree().quit()
