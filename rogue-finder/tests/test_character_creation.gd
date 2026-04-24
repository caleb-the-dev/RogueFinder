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
