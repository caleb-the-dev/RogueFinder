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
	test_equipment_library_all_items_common()
	test_equipment_library_granted_ability_ids_default_empty()
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

func test_equipment_library_all_items_common() -> void:
	for eq: EquipmentData in EquipmentLibrary.all_equipment():
		assert(eq.rarity == EquipmentData.Rarity.COMMON,
			"all placeholder items should be COMMON; '%s' is %d" % [eq.equipment_id, eq.rarity])
	print("  PASS test_equipment_library_all_items_common")

func test_equipment_library_granted_ability_ids_default_empty() -> void:
	for eq: EquipmentData in EquipmentLibrary.all_equipment():
		assert(eq.granted_ability_ids.is_empty(),
			"placeholder item '%s' should have empty granted_ability_ids" % eq.equipment_id)
	print("  PASS test_equipment_library_granted_ability_ids_default_empty")

func test_equipment_library_feat_id_default_empty() -> void:
	for eq: EquipmentData in EquipmentLibrary.all_equipment():
		assert(eq.feat_id == "",
			"placeholder item '%s' should have empty feat_id" % eq.equipment_id)
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

## Smoke: with only COMMON items in CSV, 100 rolls should all return COMMON.
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
	# All CSV items are COMMON right now, so fallback always returns COMMON.
	assert(common_count == total,
		"with only COMMON items in CSV, all rolls should be COMMON; got %d/%d" % [common_count, total])
	print("  PASS test_weighted_roll_smoke_mostly_common")
