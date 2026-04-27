extends Node

## --- Unit Tests: EquipmentData + EquipmentLibrary ---
## Run via Project > Run This Scene (F6) with this script attached to a Node.
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
	test_leather_armor_defense_plus_one()
	test_chain_mail_defense_plus_two_speed_minus_one()
	test_equipment_library_all_returns_six_items()
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
	# weapon/armor/accessory are null by default
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
	# S29: speed = 1 + kindred_bonus; DEX no longer drives base speed.
	var d := CombatantData.new()
	d.dexterity = 4
	assert(d.speed == 1, "speed with no kindred should be 1 regardless of dex, got %d" % d.speed)
	d.dexterity = 0
	assert(d.speed == 1, "speed with no kindred should be 1 regardless of dex, got %d" % d.speed)
	print("  PASS test_null_equipment_speed_no_regression")

func test_null_equipment_hp_max_no_regression() -> void:
	# hp_max = 10 + kindred_bonus + VIT*4. No kindred → bonus=0; vit=3 → 10+0+12=22.
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

## --- Equipped item stat formulas ---

func test_leather_armor_defense_plus_one() -> void:
	var d := CombatantData.new()
	d.physical_armor = 5
	d.armor = EquipmentLibrary.get_equipment("leather_armor")
	# leather_armor: physical_armor +1
	assert(d.physical_defense == 6,
		"physical_defense with leather_armor (+1) should be 6, got %d" % d.physical_defense)
	print("  PASS test_leather_armor_defense_plus_one")

func test_chain_mail_defense_plus_two_speed_minus_one() -> void:
	var d := CombatantData.new()
	d.physical_armor = 5
	d.dexterity = 3
	d.armor = EquipmentLibrary.get_equipment("chain_mail")
	# chain_mail: physical_armor +2, dexterity -1
	assert(d.physical_defense == 7,
		"physical_defense with chain_mail (+2) should be 7, got %d" % d.physical_defense)
	# speed = 1 + kindred_bonus + equip_dex_bonus; chain_mail dex -1 → 1 + 0 + (-1) = 0
	assert(d.speed == 0,
		"speed with no kindred + chain_mail (dex-1) should be 0, got %d" % d.speed)
	print("  PASS test_chain_mail_defense_plus_two_speed_minus_one")

## --- EquipmentLibrary ---

func test_equipment_library_all_returns_six_items() -> void:
	var all: Array[EquipmentData] = EquipmentLibrary.all_equipment()
	assert(all.size() == 7,
		"all_equipment() should return 7 items, got %d" % all.size())
	# Verify no nulls slipped in
	for item in all:
		assert(item != null, "all_equipment() should not contain null entries")
		assert(item.equipment_id != "", "every item should have a non-empty equipment_id")
	print("  PASS test_equipment_library_all_returns_six_items")
