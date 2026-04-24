extends Node

## --- Unit Tests: CharacterCreationManager._build_pc() ---
## No scene nodes required — _build_pc() is a static function.
## Run via test_character_creation.tscn headlessly.

func _ready() -> void:
	print("=== test_character_creation.gd ===")
	test_archetype_and_player_flag()
	test_kindred_feat_id()
	test_unit_class_from_class_pick()
	test_background_stored_as_id()
	test_abilities_four_slots()
	test_abilities_from_class_and_background()
	test_ability_pool_superset_of_slots()
	test_ability_pool_deduplicated()
	test_hp_and_energy_seeded_at_max()
	test_build_pc_uses_rolled_stats_when_provided()
	test_build_pc_rolls_internally_when_stats_empty()
	print("=== All character creation tests passed ===")

func test_archetype_and_player_flag() -> void:
	var pc := CharacterCreationManager._build_pc("Tess", "Human", "wizard", "crook", "portrait_human_f")
	assert(pc.archetype_id == "RogueFinder",
		"archetype_id must be 'RogueFinder', got '%s'" % pc.archetype_id)
	assert(pc.is_player_unit == true, "is_player_unit must be true")
	assert(pc.character_name == "Tess",
		"character_name must match input, got '%s'" % pc.character_name)
	print("  PASS test_archetype_and_player_flag")

func test_kindred_feat_id() -> void:
	var pc := CharacterCreationManager._build_pc("Tess", "Human", "wizard", "crook", "portrait_human_f")
	var expected := KindredLibrary.get_feat_id("Human")
	assert(pc.kindred_feat_id == expected,
		"kindred_feat_id must be '%s' for Human, got '%s'" % [expected, pc.kindred_feat_id])
	print("  PASS test_kindred_feat_id")

func test_unit_class_from_class_pick() -> void:
	var pc := CharacterCreationManager._build_pc("Tess", "Human", "wizard", "crook", "portrait_human_f")
	var expected := ClassLibrary.get_class_data("wizard").display_name
	assert(pc.unit_class == expected,
		"unit_class must be '%s', got '%s'" % [expected, pc.unit_class])
	print("  PASS test_unit_class_from_class_pick")

func test_background_stored_as_id() -> void:
	var pc := CharacterCreationManager._build_pc("Tess", "Human", "wizard", "crook", "portrait_human_f")
	assert(pc.background == "crook",
		"background must be snake_case id 'crook', got '%s'" % pc.background)
	print("  PASS test_background_stored_as_id")

func test_abilities_four_slots() -> void:
	var pc := CharacterCreationManager._build_pc("Tess", "Human", "wizard", "crook", "portrait_human_f")
	assert(pc.abilities.size() == 4,
		"abilities must have exactly 4 slots, got %d" % pc.abilities.size())
	assert(pc.abilities[2] == "", "slot 2 must be empty, got '%s'" % pc.abilities[2])
	assert(pc.abilities[3] == "", "slot 3 must be empty, got '%s'" % pc.abilities[3])
	print("  PASS test_abilities_four_slots")

func test_abilities_from_class_and_background() -> void:
	var pc := CharacterCreationManager._build_pc("Tess", "Human", "wizard", "crook", "portrait_human_f")
	# wizard → fireball; crook → smoke_bomb (from classes.csv / backgrounds.csv)
	assert(pc.abilities[0] == "fireball",
		"slot 0 must be wizard starting ability 'fireball', got '%s'" % pc.abilities[0])
	assert(pc.abilities[1] == "smoke_bomb",
		"slot 1 must be crook starting ability 'smoke_bomb', got '%s'" % pc.abilities[1])
	print("  PASS test_abilities_from_class_and_background")

func test_ability_pool_superset_of_slots() -> void:
	var pc := CharacterCreationManager._build_pc("Tess", "Human", "wizard", "crook", "portrait_human_f")
	for ab in pc.abilities:
		if ab != "":
			assert(pc.ability_pool.has(ab),
				"ability_pool must contain active slot ability '%s'" % ab)
	print("  PASS test_ability_pool_superset_of_slots")

func test_ability_pool_deduplicated() -> void:
	# warrior → shield_bash; soldier → shield_bash — same ability, pool must have it once
	var pc := CharacterCreationManager._build_pc("Tess", "Dwarf", "warrior", "soldier", "portrait_dwarf")
	var seen: Dictionary = {}
	for ab in pc.ability_pool:
		assert(not seen.has(ab), "ability_pool must not contain duplicate '%s'" % ab)
		seen[ab] = true
	print("  PASS test_ability_pool_deduplicated")

func test_hp_and_energy_seeded_at_max() -> void:
	var pc := CharacterCreationManager._build_pc("Tess", "Human", "wizard", "crook", "portrait_human_f")
	assert(pc.current_hp == pc.hp_max,
		"current_hp must equal hp_max at creation (got %d, max %d)" % [pc.current_hp, pc.hp_max])
	assert(pc.current_energy == pc.energy_max,
		"current_energy must equal energy_max (got %d, max %d)" % [pc.current_energy, pc.energy_max])
	print("  PASS test_hp_and_energy_seeded_at_max")

func test_build_pc_uses_rolled_stats_when_provided() -> void:
	# When the manager has pre-rolled stats (via Reroll button), _build_pc must
	# honor them exactly so "what you see is what you get" at the commit point.
	var stats := {"str": 4, "dex": 3, "cog": 2, "wil": 1, "vit": 4, "armor": 7}
	var pc := CharacterCreationManager._build_pc("Tess", "Human", "wizard", "crook", "portrait_human_f", stats)
	assert(pc.strength      == 4, "strength must use rolled 4, got %d" % pc.strength)
	assert(pc.dexterity     == 3, "dexterity must use rolled 3, got %d" % pc.dexterity)
	assert(pc.cognition     == 2, "cognition must use rolled 2, got %d" % pc.cognition)
	assert(pc.willpower     == 1, "willpower must use rolled 1, got %d" % pc.willpower)
	assert(pc.vitality      == 4, "vitality must use rolled 4, got %d" % pc.vitality)
	assert(pc.armor_defense == 7, "armor_defense must use rolled 7, got %d" % pc.armor_defense)
	print("  PASS test_build_pc_uses_rolled_stats_when_provided")

func test_build_pc_rolls_internally_when_stats_empty() -> void:
	# Back-compat path: omitting the rolled_stats param must still produce a
	# valid PC with stats in the 1–4 range (existing callers + Test New Run
	# button rely on this — Test New Run does its own randomization per member).
	var pc := CharacterCreationManager._build_pc("Tess", "Human", "wizard", "crook", "portrait_human_f")
	assert(pc.strength  >= 1 and pc.strength  <= 4, "strength out of range: %d" % pc.strength)
	assert(pc.dexterity >= 1 and pc.dexterity <= 4, "dexterity out of range: %d" % pc.dexterity)
	assert(pc.cognition >= 1 and pc.cognition <= 4, "cognition out of range: %d" % pc.cognition)
	assert(pc.willpower >= 1 and pc.willpower <= 4, "willpower out of range: %d" % pc.willpower)
	assert(pc.vitality  >= 1 and pc.vitality  <= 4, "vitality out of range: %d" % pc.vitality)
	assert(pc.armor_defense >= 4 and pc.armor_defense <= 8,
		"armor_defense out of range: %d" % pc.armor_defense)
	print("  PASS test_build_pc_rolls_internally_when_stats_empty")
