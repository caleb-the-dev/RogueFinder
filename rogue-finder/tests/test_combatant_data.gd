extends Node

## --- Unit Tests: CombatantData + ArchetypeLibrary ---
## Run via Project > Run This Scene (F6) with this script attached to a Node.
## Tests cover derived stat formulas, alias fields, and archetype factory correctness.
## No scene nodes, timers, or signals required.

func _ready() -> void:
	print("=== test_combatant_data.gd ===")
	test_derived_hp()
	test_derived_energy()
	test_derived_energy_regen()
	test_derived_speed()
	test_derived_attack()
	test_derived_defense_alias()
	test_unit_name_alias()
	test_vitality_min_guard()
	test_ability_pool_size()
	test_archetype_archer_bandit_ranges()
	test_archetype_alchemist_background_pool()
	test_archetype_grunt_class()
	test_archetype_elite_guard_armor_range()
	test_archetype_unknown_falls_back_to_grunt()
	test_archetype_name_override()
	test_archetype_enemy_name_empty()
	test_archetype_ally_auto_name_from_pool()
	print("=== All CombatantData tests passed ===")

## --- Derived Stat Tests ---

func test_derived_hp() -> void:
	var d := CombatantData.new()
	d.vitality = 3
	assert(d.hp_max == 30, "hp_max should be 10 * vitality (30), got %d" % d.hp_max)
	d.vitality = 1
	assert(d.hp_max == 10, "hp_max should be 10 for vitality 1, got %d" % d.hp_max)
	print("  PASS test_derived_hp")

func test_derived_energy() -> void:
	var d := CombatantData.new()
	d.vitality = 4
	assert(d.energy_max == 9, "energy_max should be 5 + vitality (9), got %d" % d.energy_max)
	d.vitality = 1
	assert(d.energy_max == 6, "energy_max should be 6 for vitality 1, got %d" % d.energy_max)
	print("  PASS test_derived_energy")

func test_derived_energy_regen() -> void:
	var d := CombatantData.new()
	d.willpower = 3
	assert(d.energy_regen == 5, "energy_regen should be 2 + willpower (5), got %d" % d.energy_regen)
	d.willpower = 0
	assert(d.energy_regen == 2, "energy_regen should be 2 for willpower 0, got %d" % d.energy_regen)
	print("  PASS test_derived_energy_regen")

func test_derived_speed() -> void:
	var d := CombatantData.new()
	d.dexterity = 4
	assert(d.speed == 6, "speed should be 2 + dexterity (6), got %d" % d.speed)
	d.dexterity = 0
	assert(d.speed == 2, "speed should be 2 for dexterity 0, got %d" % d.speed)
	print("  PASS test_derived_speed")

func test_derived_attack() -> void:
	var d := CombatantData.new()
	d.strength = 5
	assert(d.attack == 10, "attack should be 5 + strength (10), got %d" % d.attack)
	d.strength = 0
	assert(d.attack == 5, "attack should be 5 for strength 0, got %d" % d.attack)
	print("  PASS test_derived_attack")

func test_derived_defense_alias() -> void:
	var d := CombatantData.new()
	d.armor_defense = 7
	assert(d.defense == 7, "defense should alias armor_defense (7), got %d" % d.defense)
	print("  PASS test_derived_defense_alias")

func test_unit_name_alias() -> void:
	var d := CombatantData.new()
	d.character_name = "Vael"
	assert(d.unit_name == "Vael", "unit_name alias should match character_name")
	print("  PASS test_unit_name_alias")

func test_vitality_min_guard() -> void:
	# ArchetypeLibrary guards vitality >= 1 so hp_max is never 0
	var d: CombatantData = ArchetypeLibrary.create("alchemist")
	assert(d.vitality >= 1, "vitality must be at least 1 after factory creation")
	assert(d.hp_max   >= 10, "hp_max must be >= 10 (vitality >= 1)")
	print("  PASS test_vitality_min_guard")

## --- Archetype Factory Tests ---

func test_ability_pool_size() -> void:
	var d: CombatantData = ArchetypeLibrary.create("archer_bandit")
	assert(d.abilities.size() == 4, "ability pool must have exactly 4 slots, got %d" % d.abilities.size())
	print("  PASS test_ability_pool_size")

func test_archetype_archer_bandit_ranges() -> void:
	# Run several times to catch out-of-range rolls statistically
	for i in range(20):
		var d: CombatantData = ArchetypeLibrary.create("archer_bandit")
		assert(d.dexterity >= 3 and d.dexterity <= 4,
			"archer_bandit dex out of range [3,4]: %d" % d.dexterity)
		assert(d.strength  >= 1 and d.strength  <= 2,
			"archer_bandit str out of range [1,2]: %d" % d.strength)
		assert(d.background in ["Crook", "Soldier"],
			"archer_bandit background not in pool: %s" % d.background)
	print("  PASS test_archetype_archer_bandit_ranges")

func test_archetype_alchemist_background_pool() -> void:
	var seen: Dictionary = {}
	# Draw enough times to hit all three backgrounds with high probability
	for i in range(60):
		var d: CombatantData = ArchetypeLibrary.create("alchemist")
		assert(d.background in ["Baker", "Scholar", "Merchant"],
			"alchemist background not in allowed pool: %s" % d.background)
		seen[d.background] = true
	# All three should appear in 60 draws (1/3 each → P(all seen) > 0.9999)
	assert(seen.has("Baker"),    "alchemist should occasionally roll Baker")
	assert(seen.has("Scholar"),  "alchemist should occasionally roll Scholar")
	assert(seen.has("Merchant"), "alchemist should occasionally roll Merchant")
	print("  PASS test_archetype_alchemist_background_pool")

func test_archetype_grunt_class() -> void:
	var d: CombatantData = ArchetypeLibrary.create("grunt")
	assert(d.unit_class == "Barbarian", "grunt class should be Barbarian, got %s" % d.unit_class)
	assert(d.archetype_id == "grunt",   "archetype_id should be 'grunt'")
	print("  PASS test_archetype_grunt_class")

func test_archetype_elite_guard_armor_range() -> void:
	for i in range(10):
		var d: CombatantData = ArchetypeLibrary.create("elite_guard")
		assert(d.armor_defense >= 7 and d.armor_defense <= 10,
			"elite_guard armor out of range [7,10]: %d" % d.armor_defense)
		assert(d.vitality >= 3 and d.vitality <= 5,
			"elite_guard vit out of range [3,5]: %d" % d.vitality)
	print("  PASS test_archetype_elite_guard_armor_range")

func test_archetype_unknown_falls_back_to_grunt() -> void:
	var d: CombatantData = ArchetypeLibrary.create("not_a_real_archetype")
	# Falls back to "grunt" definition, but keeps the passed archetype_id
	assert(d.unit_class == "Barbarian",
		"unknown archetype should fall back to grunt's class (Barbarian)")
	print("  PASS test_archetype_unknown_falls_back_to_grunt")

func test_archetype_name_override() -> void:
	var d: CombatantData = ArchetypeLibrary.create("grunt", "Claude")
	assert(d.character_name == "Claude",
		"character_name override should be 'Claude', got %s" % d.character_name)
	print("  PASS test_archetype_name_override")

func test_archetype_enemy_name_empty() -> void:
	# Enemies (is_player=false) with no explicit name should have an empty character_name.
	# Unit3D will display the archetype label above their head instead.
	for i in range(10):
		var d: CombatantData = ArchetypeLibrary.create("grunt")
		assert(d.character_name == "",
			"enemy grunt with no name should be empty, got '%s'" % d.character_name)
	print("  PASS test_archetype_enemy_name_empty")

func test_archetype_ally_auto_name_from_pool() -> void:
	# Player allies (is_player=true) with no explicit name draw from the flavor pool.
	var grunt_names: Array = ["Brak", "Mord", "Thug", "Krak", "Uge", "Dorn"]
	for i in range(20):
		var d: CombatantData = ArchetypeLibrary.create("grunt", "", true)
		assert(d.character_name in grunt_names,
			"ally grunt auto name '%s' is not in grunt name pool" % d.character_name)
	print("  PASS test_archetype_ally_auto_name_from_pool")
