extends Node

## --- Unit Tests: Rarity Foundation ---
## Tests: EquipmentData defaults, rarity field parse, RARITY_COLORS lookup,
## RewardGenerator.RARITY_WEIGHTS structure, weighted roll distribution (smoke),
## rarity field presence in roll() output, EquipmentLibrary CSV rarity parse.

func _ready() -> void:
	print("=== test_rarity.gd ===")
	test_equipment_data_defaults()
	test_rarity_colors_all_four_tiers()
	test_rarity_color_convenience_method()
	test_equipment_library_parses_common_rarity()
	test_equipment_library_armor_accessory_all_common()
	test_equipment_library_weapon_tiers_exist()
	test_equipment_library_weapons_have_granted_ability()
	test_equipment_library_armor_accessory_granted_ability_ids_empty()
	test_equipment_library_feat_id_default_empty()
	test_reward_generator_weights_sum_to_100()
	test_reward_generator_roll_includes_rarity_field()
	test_reward_generator_roll_distinct_ids()
	test_weighted_roll_smoke_mostly_common()
	print("=== All rarity tests passed ===")

## --- EquipmentData defaults ---

func test_equipment_data_defaults() -> void:
	var eq := EquipmentData.new()
	assert(eq.rarity == EquipmentData.Rarity.COMMON,
		"default rarity should be COMMON (0), got %d" % eq.rarity)
	assert(eq.granted_ability_ids.is_empty(),
		"default granted_ability_ids should be empty")
	assert(eq.feat_id == "",
		"default feat_id should be empty string")
	print("  PASS test_equipment_data_defaults")

## --- RARITY_COLORS ---

func test_rarity_colors_all_four_tiers() -> void:
	for r in [EquipmentData.Rarity.COMMON, EquipmentData.Rarity.RARE,
			  EquipmentData.Rarity.EPIC, EquipmentData.Rarity.LEGENDARY]:
		assert(EquipmentData.RARITY_COLORS.has(r),
			"RARITY_COLORS missing entry for rarity %d" % r)
		var col: Color = EquipmentData.RARITY_COLORS[r]
		assert(col.a > 0.0, "rarity color alpha should be > 0 for tier %d" % r)
	print("  PASS test_rarity_colors_all_four_tiers")

func test_rarity_color_convenience_method() -> void:
	var eq := EquipmentData.new()
	eq.rarity = EquipmentData.Rarity.RARE
	var col: Color = eq.rarity_color()
	assert(col == EquipmentData.RARITY_COLORS[EquipmentData.Rarity.RARE],
		"rarity_color() should match RARITY_COLORS[RARE]")
	print("  PASS test_rarity_color_convenience_method")

## --- EquipmentLibrary CSV parse ---

func test_equipment_library_parses_common_rarity() -> void:
	var eq: EquipmentData = EquipmentLibrary.get_equipment("iron_sword")
	assert(eq.rarity == EquipmentData.Rarity.COMMON,
		"iron_sword rarity should be COMMON, got %d" % eq.rarity)
	print("  PASS test_equipment_library_parses_common_rarity")

func test_equipment_library_armor_accessory_all_common() -> void:
	# Armor and accessories now have all 4 rarity tiers (Slices 4 + 5).
	# Verify each slot type covers all tiers rather than asserting COMMON-only.
	var armor_rarities: Dictionary = {}
	var accessory_rarities: Dictionary = {}
	for eq: EquipmentData in EquipmentLibrary.all_equipment():
		if eq.slot == EquipmentData.Slot.ARMOR:
			armor_rarities[eq.rarity] = true
		elif eq.slot == EquipmentData.Slot.ACCESSORY:
			accessory_rarities[eq.rarity] = true
	for r in [EquipmentData.Rarity.COMMON, EquipmentData.Rarity.RARE,
			  EquipmentData.Rarity.EPIC, EquipmentData.Rarity.LEGENDARY]:
		assert(armor_rarities.has(r), "armor pool must include rarity tier %d" % r)
		assert(accessory_rarities.has(r), "accessory pool must include rarity tier %d" % r)
	print("  PASS test_equipment_library_armor_accessory_all_common")

func test_equipment_library_weapon_tiers_exist() -> void:
	var rarities_seen: Dictionary = {}
	for eq: EquipmentData in EquipmentLibrary.all_equipment():
		if eq.slot == EquipmentData.Slot.WEAPON:
			rarities_seen[eq.rarity] = true
	for r in [EquipmentData.Rarity.COMMON, EquipmentData.Rarity.RARE,
			  EquipmentData.Rarity.EPIC, EquipmentData.Rarity.LEGENDARY]:
		assert(rarities_seen.has(r), "weapon pool must include rarity tier %d" % r)
	print("  PASS test_equipment_library_weapon_tiers_exist")

func test_equipment_library_weapons_have_granted_ability() -> void:
	for eq: EquipmentData in EquipmentLibrary.all_equipment():
		if eq.slot == EquipmentData.Slot.WEAPON:
			assert(not eq.granted_ability_ids.is_empty(),
				"weapon '%s' must have at least one granted_ability_id" % eq.equipment_id)
	print("  PASS test_equipment_library_weapons_have_granted_ability")

func test_equipment_library_armor_accessory_granted_ability_ids_empty() -> void:
	# Armor items may carry granted_ability_ids (Slice 4). Accessories never do.
	for eq: EquipmentData in EquipmentLibrary.all_equipment():
		if eq.slot != EquipmentData.Slot.ACCESSORY:
			continue
		assert(eq.granted_ability_ids.is_empty(),
			"accessory '%s' should have empty granted_ability_ids" % eq.equipment_id)
	print("  PASS test_equipment_library_armor_accessory_granted_ability_ids_empty")

func test_equipment_library_feat_id_default_empty() -> void:
	# Weapons and armor never carry a feat_id. COMMON accessories have no feat_id.
	# RARE/EPIC/LEGENDARY accessories carry a background feat_id (Slice 5).
	for eq: EquipmentData in EquipmentLibrary.all_equipment():
		if eq.slot == EquipmentData.Slot.WEAPON or eq.slot == EquipmentData.Slot.ARMOR:
			assert(eq.feat_id == "",
				"weapon/armor '%s' should have empty feat_id" % eq.equipment_id)
		elif eq.slot == EquipmentData.Slot.ACCESSORY:
			if eq.rarity == EquipmentData.Rarity.COMMON:
				assert(eq.feat_id == "",
					"COMMON accessory '%s' should have empty feat_id" % eq.equipment_id)
			else:
				assert(eq.feat_id != "",
					"Rare+ accessory '%s' should have a non-empty feat_id" % eq.equipment_id)
	print("  PASS test_equipment_library_feat_id_default_empty")

## --- RewardGenerator ---

func test_reward_generator_weights_sum_to_100() -> void:
	var total: int = 0
	for w in RewardGenerator.RARITY_WEIGHTS.values():
		total += w
	assert(total == 100, "RARITY_WEIGHTS should sum to 100, got %d" % total)
	assert(RewardGenerator.RARITY_WEIGHTS.has(EquipmentData.Rarity.COMMON),
		"RARITY_WEIGHTS missing COMMON key")
	assert(RewardGenerator.RARITY_WEIGHTS.has(EquipmentData.Rarity.LEGENDARY),
		"RARITY_WEIGHTS missing LEGENDARY key")
	print("  PASS test_reward_generator_weights_sum_to_100")

func test_reward_generator_roll_includes_rarity_field() -> void:
	var items: Array = RewardGenerator.roll(3)
	for item: Dictionary in items:
		assert(item.has("rarity"),
			"reward dict must have 'rarity' key, got: %s" % str(item.keys()))
	print("  PASS test_reward_generator_roll_includes_rarity_field")

func test_reward_generator_roll_distinct_ids() -> void:
	var items: Array = RewardGenerator.roll(3)
	var seen: Dictionary = {}
	for item: Dictionary in items:
		var cid: String = item.get("id", "")
		assert(not seen.has(cid), "roll() returned duplicate id: %s" % cid)
		seen[cid] = true
	print("  PASS test_reward_generator_roll_distinct_ids")

## Smoke: COMMON weight is 60/100 so COMMON should dominate but not monopolize.
## With tiered weapons now in the pool, RARE/EPIC/LEGENDARY results are expected.
func test_weighted_roll_smoke_mostly_common() -> void:
	seed(42)
	var common_count: int = 0
	var total: int = 100
	for _i in range(total):
		var items: Array = RewardGenerator.roll(1)
		if items.size() > 0:
			var r: int = items[0].get("rarity", -1)
			if r == EquipmentData.Rarity.COMMON:
				common_count += 1
	assert(common_count >= 40,
		"with 60%% COMMON weight, at least 40/100 rolls should be COMMON; got %d" % common_count)
	assert(common_count < 100,
		"with tiered weapons in pool, not all 100 rolls should be COMMON; got %d" % common_count)
	print("  PASS test_weighted_roll_smoke_mostly_common")
