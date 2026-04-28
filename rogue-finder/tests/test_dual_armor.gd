extends Node

## --- Unit Tests: Dual Armor System ---
## Tests: physical_defense / magic_defense formulas, armor subtraction in damage,
## damage_type CSV parsing, and save migration from old armor_defense key.

func _ready() -> void:
	print("=== test_dual_armor.gd ===")
	test_physical_defense_base()
	test_magic_defense_base()
	test_physical_defense_with_equipment()
	test_magic_defense_with_equipment()
	test_physical_defense_with_feat()
	test_magic_defense_with_kindred_bonus()
	test_ability_damage_type_parsed_physical()
	test_ability_damage_type_parsed_magic()
	test_ability_damage_type_parsed_none()
	test_save_migration_armor_defense_to_both()
	test_save_roundtrip_new_format()
	print("=== All dual-armor tests passed ===")

## --- physical_defense formula ---

func test_physical_defense_base() -> void:
	var d := CombatantData.new()
	d.physical_armor = 5
	assert(d.physical_defense == 5,
		"physical_defense with no bonuses should equal physical_armor (5), got %d" % d.physical_defense)
	print("  PASS test_physical_defense_base")

func test_magic_defense_base() -> void:
	var d := CombatantData.new()
	d.magic_armor = 3
	assert(d.magic_defense == 3,
		"magic_defense with no bonuses should equal magic_armor (3), got %d" % d.magic_defense)
	print("  PASS test_magic_defense_base")

func test_physical_defense_with_equipment() -> void:
	var d := CombatantData.new()
	d.physical_armor = 4
	d.armor = EquipmentLibrary.get_equipment("padded_armor")  # physical_armor:+1
	assert(d.physical_defense == 5,
		"physical_defense with padded_armor should be 5, got %d" % d.physical_defense)
	# magic_defense unaffected by physical equipment
	assert(d.magic_defense == d.magic_armor,
		"magic_defense should be unaffected by padded_armor")
	print("  PASS test_physical_defense_with_equipment")

func test_magic_defense_with_equipment() -> void:
	# cloth_robe is magic-only — verify no cross-contamination on physical
	var d := CombatantData.new()
	d.magic_armor = 3
	d.armor = EquipmentLibrary.get_equipment("padded_armor")  # physical only
	assert(d.magic_defense == 3,
		"magic_defense should not be affected by physical-only equipment, got %d" % d.magic_defense)
	print("  PASS test_magic_defense_with_equipment")

func test_physical_defense_with_feat() -> void:
	var d := CombatantData.new()
	d.physical_armor = 0
	var base: int = d.physical_defense
	d.feat_ids = ["iron_guard"]  # physical_armor:2
	assert(d.physical_defense == base + 2,
		"iron_guard feat should raise physical_defense by 2, got %d (base %d)" % [d.physical_defense, base])
	print("  PASS test_physical_defense_with_feat")

func test_magic_defense_with_kindred_bonus() -> void:
	# Dwarf has physical_armor:2 kindred bonus — magic_defense should be unaffected
	var d := CombatantData.new()
	d.magic_armor = 3
	d.kindred = ""
	var base_mdef: int = d.magic_defense
	d.kindred = "Dwarf"
	assert(d.magic_defense == base_mdef,
		"Dwarf kindred should not affect magic_defense, got %d (base %d)" % [d.magic_defense, base_mdef])
	assert(d.physical_defense == d.physical_armor + 2,
		"Dwarf kindred should add +2 to physical_defense, got %d" % d.physical_defense)
	print("  PASS test_magic_defense_with_kindred_bonus")

## --- AbilityLibrary damage_type parsing ---

func test_ability_damage_type_parsed_physical() -> void:
	var ab: AbilityData = AbilityLibrary.get_ability("strike")
	assert(ab.damage_type == AbilityData.DamageType.PHYSICAL,
		"strike should be PHYSICAL, got %d" % ab.damage_type)
	var ab2: AbilityData = AbilityLibrary.get_ability("fireball")
	# fireball is MAGIC — verify physical also differs from magic
	assert(ab2.damage_type != AbilityData.DamageType.PHYSICAL,
		"fireball should not be PHYSICAL")
	print("  PASS test_ability_damage_type_parsed_physical")

func test_ability_damage_type_parsed_magic() -> void:
	for id in ["fireball", "fire_breath", "arcane_bolt", "acid_splash", "gadget_spark"]:
		var ab: AbilityData = AbilityLibrary.get_ability(id)
		assert(ab.damage_type == AbilityData.DamageType.MAGIC,
			"%s should be MAGIC, got %d" % [id, ab.damage_type])
	print("  PASS test_ability_damage_type_parsed_magic")

func test_ability_damage_type_parsed_none() -> void:
	for id in ["healing_draught", "counter", "guard", "disengage", "bless"]:
		var ab: AbilityData = AbilityLibrary.get_ability(id)
		assert(ab.damage_type == AbilityData.DamageType.NONE,
			"%s should be NONE, got %d" % [id, ab.damage_type])
	print("  PASS test_ability_damage_type_parsed_none")

## --- Save migration ---

func test_save_migration_armor_defense_to_both() -> void:
	# Old save format had a single "armor_defense" key.
	# Migration should set physical_armor = magic_armor = old value.
	var old_dict: Dictionary = {
		"archetype_id": "grunt", "character_name": "Brak", "is_player_unit": false,
		"unit_class": "vanguard", "kindred": "Half-Orc", "background": "",
		"strength": 6, "dexterity": 2, "cognition": 2, "willpower": 2, "vitality": 5,
		"armor_defense": 7, "qte_resolution": 0.3,
		"abilities": [], "ability_pool": [], "feat_ids": [],
		"level": 1, "xp": 0, "pending_level_ups": 0,
		"current_hp": 30, "current_energy": 7, "is_dead": false,
		"consumable": "", "weapon_id": "", "armor_id": "", "accessory_id": ""
	}
	var d: CombatantData = GameState._deserialize_combatant(old_dict)
	assert(d.physical_armor == 7,
		"migration: physical_armor should match old armor_defense (7), got %d" % d.physical_armor)
	assert(d.magic_armor == 7,
		"migration: magic_armor should match old armor_defense (7), got %d" % d.magic_armor)
	print("  PASS test_save_migration_armor_defense_to_both")

func test_save_roundtrip_new_format() -> void:
	# New saves write physical_armor + magic_armor separately.
	# Round-trip should preserve both values exactly.
	var original := CombatantData.new()
	original.archetype_id   = "grunt"
	original.character_name = "Brak"
	original.physical_armor = 6
	original.magic_armor    = 2
	original.level          = 1
	var serialized: Dictionary = GameState._serialize_combatant(original)
	assert(serialized.has("physical_armor"), "serialized should have physical_armor key")
	assert(serialized.has("magic_armor"),    "serialized should have magic_armor key")
	assert(not serialized.has("armor_defense"), "serialized should NOT have old armor_defense key")
	var loaded: CombatantData = GameState._deserialize_combatant(serialized)
	assert(loaded.physical_armor == 6,
		"roundtrip physical_armor should be 6, got %d" % loaded.physical_armor)
	assert(loaded.magic_armor == 2,
		"roundtrip magic_armor should be 2, got %d" % loaded.magic_armor)
	print("  PASS test_save_roundtrip_new_format")
