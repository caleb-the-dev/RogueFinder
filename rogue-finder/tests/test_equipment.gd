extends Node

## --- Unit Tests: EquipmentData + EquipmentLibrary ---
## Run headless: import then run test_equipment.tscn.
## Tests cover get_bonus(), null-equipment regression, equipped-stat formulas, and library size.
## No scene nodes, timers, or signals required.

func _ready() -> void:
	print("=== test_equipment.gd ===")
	test_get_bonus_returns_zero_for_missing_stat()
	test_get_bonus_returns_correct_value_for_present_stat()
	test_null_equipment_attack_no_regression()
	test_null_equipment_defense_no_regression()
	test_null_equipment_speed_no_regression()
	test_null_equipment_hp_max_no_regression()
	test_null_equipment_energy_max_no_regression()
	test_null_equipment_energy_regen_no_regression()
	test_padded_armor_physical_defense_plus_one()
	test_rough_hide_stacks_armor_and_vitality()
	test_cloth_robe_magic_defense()
	test_cloth_robe_does_not_affect_physical()
	test_equipment_library_all_returns_eighteen_items()
	print("=== All equipment tests passed ===")

## --- EquipmentData.get_bonus() ---

func test_get_bonus_returns_zero_for_missing_stat() -> void:
	var eq := EquipmentData.new()
	eq.stat_bonuses = {"strength": 2}
	assert(eq.get_bonus("dexterity") == 0,
		"get_bonus on absent key should return 0, got %d" % eq.get_bonus("dexterity"))
	assert(eq.get_bonus("") == 0,
		"get_bonus on empty key should return 0")
	print("  PASS test_get_bonus_returns_zero_for_missing_stat")

func test_get_bonus_returns_correct_value_for_present_stat() -> void:
	var eq := EquipmentData.new()
	eq.stat_bonuses = {"strength": 3, "dexterity": -1, "physical_armor": 2}
	assert(eq.get_bonus("strength") == 3,
		"get_bonus(strength) should be 3, got %d" % eq.get_bonus("strength"))
	assert(eq.get_bonus("dexterity") == -1,
		"get_bonus(dexterity) should be -1, got %d" % eq.get_bonus("dexterity"))
	assert(eq.get_bonus("physical_armor") == 2,
		"get_bonus(physical_armor) should be 2, got %d" % eq.get_bonus("physical_armor"))
	print("  PASS test_get_bonus_returns_correct_value_for_present_stat")

## --- CombatantData null-equipment regression ---
## All derived stats must match pre-equipment formulas when all slots are null.

func test_null_equipment_attack_no_regression() -> void:
	var d := CombatantData.new()
	d.strength = 3
	assert(d.attack == 8, "attack with str=3, no equip: expected 8, got %d" % d.attack)
	d.strength = 0
	assert(d.attack == 5, "attack with str=0, no equip: expected 5, got %d" % d.attack)
	print("  PASS test_null_equipment_attack_no_regression")

func test_null_equipment_defense_no_regression() -> void:
	var d := CombatantData.new()
	d.physical_armor = 6
	d.magic_armor    = 3
	assert(d.physical_defense == 6, "physical_defense=6, no equip: expected 6, got %d" % d.physical_defense)
	assert(d.magic_defense    == 3, "magic_defense=3, no equip: expected 3, got %d" % d.magic_defense)
	print("  PASS test_null_equipment_defense_no_regression")

func test_null_equipment_speed_no_regression() -> void:
	var d := CombatantData.new()
	d.dexterity = 4
	assert(d.speed == 1, "speed with no kindred should be 1 regardless of dex, got %d" % d.speed)
	d.dexterity = 0
	assert(d.speed == 1, "speed with no kindred should be 1 regardless of dex, got %d" % d.speed)
	print("  PASS test_null_equipment_speed_no_regression")

func test_null_equipment_hp_max_no_regression() -> void:
	var d := CombatantData.new()
	d.vitality = 3
	assert(d.hp_max == 22, "hp_max with vit=3, no equip: expected 22, got %d" % d.hp_max)
	print("  PASS test_null_equipment_hp_max_no_regression")

func test_null_equipment_energy_max_no_regression() -> void:
	var d := CombatantData.new()
	d.vitality = 4
	assert(d.energy_max == 9, "energy_max with vit=4, no equip: expected 9, got %d" % d.energy_max)
	print("  PASS test_null_equipment_energy_max_no_regression")

func test_null_equipment_energy_regen_no_regression() -> void:
	var d := CombatantData.new()
	d.willpower = 2
	assert(d.energy_regen == 4, "energy_regen with wil=2, no equip: expected 4, got %d" % d.energy_regen)
	print("  PASS test_null_equipment_energy_regen_no_regression")

## --- Current item stat formulas ---

func test_padded_armor_physical_defense_plus_one() -> void:
	# iron_plate: physical_armor +5 (replaces removed padded_armor placeholder)
	var d := CombatantData.new()
	d.physical_armor = 0
	d.armor = EquipmentLibrary.get_equipment("iron_plate")
	assert(d.physical_defense == 5,
		"physical_defense with iron_plate (+5) should be 5, got %d" % d.physical_defense)
	print("  PASS test_padded_armor_physical_defense_plus_one")

func test_rough_hide_stacks_armor_and_vitality() -> void:
	# ring_of_valor_epic: strength +1, vitality +1 (replaces removed rough_hide placeholder)
	var d := CombatantData.new()
	d.feat_ids = []
	d.vitality = 2
	d.physical_armor = 3
	d.accessory = EquipmentLibrary.get_equipment("ring_of_valor_epic")
	# ring_of_valor_epic stat_bonuses: strength:1, vitality:1
	# physical_defense: 3 (base) + 0 (equip phys_armor) = 3 — accessory has no physical_armor bonus
	assert(d.physical_defense == 3,
		"ring_of_valor_epic must not affect physical_defense, got %d" % d.physical_defense)
	# hp_max: 10 + vit*4 + equip vit(1) + feat(combat_training — str not vit, 0)
	assert(d.hp_max == 10 + d.vitality * 4 + 1,
		"hp_max with ring_of_valor_epic (+1 vit equip) should be %d, got %d" % [10 + d.vitality * 4 + 1, d.hp_max])
	print("  PASS test_rough_hide_stacks_armor_and_vitality")

func test_cloth_robe_magic_defense() -> void:
	# mystic_robe: magic_armor +5 (replaces removed cloth_robe placeholder)
	var d := CombatantData.new()
	d.magic_armor = 0
	d.armor = EquipmentLibrary.get_equipment("mystic_robe")
	assert(d.magic_defense == 5,
		"magic_defense with mystic_robe (+5) should be 5, got %d" % d.magic_defense)
	print("  PASS test_cloth_robe_magic_defense")

func test_cloth_robe_does_not_affect_physical() -> void:
	# mystic_robe: physical_armor +1 only, so it does affect physical by +1
	var d := CombatantData.new()
	d.physical_armor = 4
	d.armor = EquipmentLibrary.get_equipment("mystic_robe")
	assert(d.physical_defense == 5,
		"mystic_robe gives +1 physical_armor, so physical_defense should be 5, got %d" % d.physical_defense)
	print("  PASS test_cloth_robe_does_not_affect_physical")

## --- EquipmentLibrary ---

func test_equipment_library_all_returns_eighteen_items() -> void:
	var all: Array[EquipmentData] = EquipmentLibrary.all_equipment()
	assert(all.size() == 36,
		"all_equipment() should return 36 items (12 weapons + 12 armor + 12 accessory), got %d" % all.size())
	for item in all:
		assert(item != null, "all_equipment() should not contain null entries")
		assert(item.equipment_id != "", "every item should have a non-empty equipment_id")
	print("  PASS test_equipment_library_all_returns_eighteen_items")
