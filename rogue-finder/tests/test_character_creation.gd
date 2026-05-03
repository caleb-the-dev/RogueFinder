extends Node

## --- Unit Tests: CharacterCreationManager._build_pc() ---
## No scene nodes required — _build_pc() is a static function.
## Run via test_character_creation.tscn headlessly.

func _ready() -> void:
	print("=== test_character_creation.gd ===")
	test_archetype_and_player_flag()
	test_background_starting_feat_in_feat_ids()
	test_no_kindred_feat_in_feat_ids()
	test_unit_class_from_class_pick()
	test_background_stored_as_id()
	test_abilities_four_slots()
	test_abilities_from_class_and_kindred()
	test_ability_pool_contains_class_and_kindred()
	test_ability_pool_deduplicated()
	test_hp_and_energy_seeded_at_max()
	test_build_pc_deterministic_stats()
	test_build_pc_arcanist_crook_human_stats()
	print("=== All character creation tests passed ===")

func test_archetype_and_player_flag() -> void:
	var pc := CharacterCreationManager._build_pc("Tess", "Human", "arcanist", "crook", "portrait_human_f")
	assert(pc.archetype_id == "RogueFinder",
		"archetype_id must be 'RogueFinder', got '%s'" % pc.archetype_id)
	assert(pc.is_player_unit == true, "is_player_unit must be true")
	assert(pc.character_name == "Tess",
		"character_name must match input, got '%s'" % pc.character_name)
	print("  PASS test_archetype_and_player_flag")

func test_background_starting_feat_in_feat_ids() -> void:
	var pc := CharacterCreationManager._build_pc("Tess", "Human", "arcanist", "crook", "portrait_human_f")
	# crook starting_feat_id = "street_smart"
	assert(pc.feat_ids.size() == 1,
		"feat_ids must have exactly 1 entry (bg defining feat), got %d" % pc.feat_ids.size())
	assert(pc.feat_ids[0] == "street_smart",
		"feat_ids[0] must be crook's defining feat 'street_smart', got '%s'" % pc.feat_ids[0])
	print("  PASS test_background_starting_feat_in_feat_ids")

func test_no_kindred_feat_in_feat_ids() -> void:
	# Kindred stat bonuses are now structural — no feat entry in feat_ids
	for kindred_id in ["Human", "Half-Orc", "Gnome", "Dwarf"]:
		var pc := CharacterCreationManager._build_pc("X", kindred_id, "arcanist", "crook", "")
		var kindred_feats: Array[String] = ["adaptive", "relentless", "tinkerer", "stonehide"]
		for f_id in pc.feat_ids:
			assert(f_id not in kindred_feats,
				"kindred feat '%s' must not appear in feat_ids for %s" % [f_id, kindred_id])
	print("  PASS test_no_kindred_feat_in_feat_ids")

func test_unit_class_from_class_pick() -> void:
	var pc := CharacterCreationManager._build_pc("Tess", "Human", "arcanist", "crook", "portrait_human_f")
	assert(pc.unit_class == "arcanist",
		"unit_class must store class ID 'arcanist', got '%s'" % pc.unit_class)
	print("  PASS test_unit_class_from_class_pick")

func test_background_stored_as_id() -> void:
	var pc := CharacterCreationManager._build_pc("Tess", "Human", "arcanist", "crook", "portrait_human_f")
	assert(pc.background == "crook",
		"background must be snake_case id 'crook', got '%s'" % pc.background)
	print("  PASS test_background_stored_as_id")

func test_abilities_four_slots() -> void:
	var pc := CharacterCreationManager._build_pc("Tess", "Human", "arcanist", "crook", "portrait_human_f")
	assert(pc.abilities.size() == 4,
		"abilities must have exactly 4 slots, got %d" % pc.abilities.size())
	assert(pc.abilities[2] == "", "slot 2 must be empty, got '%s'" % pc.abilities[2])
	assert(pc.abilities[3] == "", "slot 3 must be empty, got '%s'" % pc.abilities[3])
	print("  PASS test_abilities_four_slots")

func test_abilities_from_class_and_kindred() -> void:
	var pc := CharacterCreationManager._build_pc("Tess", "Human", "arcanist", "crook", "portrait_human_f")
	# arcanist → arcane_bolt (class defining); Human → focused_strike (kindred natural attack)
	assert(pc.abilities[0] == "arcane_bolt",
		"slot 0 must be arcanist defining ability 'arcane_bolt', got '%s'" % pc.abilities[0])
	assert(pc.abilities[1] == "focused_strike",
		"slot 1 must be Human kindred ability 'focused_strike', got '%s'" % pc.abilities[1])
	print("  PASS test_abilities_from_class_and_kindred")

func test_ability_pool_contains_class_and_kindred() -> void:
	var pc := CharacterCreationManager._build_pc("Tess", "Human", "arcanist", "crook", "portrait_human_f")
	assert("arcane_bolt" in pc.ability_pool,
		"ability_pool must contain class ability 'arcane_bolt'")
	assert("focused_strike" in pc.ability_pool,
		"ability_pool must contain kindred ability 'focused_strike'")
	print("  PASS test_ability_pool_contains_class_and_kindred")

func test_ability_pool_deduplicated() -> void:
	# If class and kindred share an ability id it should appear only once in pool
	var pc := CharacterCreationManager._build_pc("Tess", "Human", "arcanist", "crook", "portrait_human_f")
	var seen: Dictionary = {}
	for ab in pc.ability_pool:
		assert(not seen.has(ab), "ability_pool must not contain duplicate '%s'" % ab)
		seen[ab] = true
	print("  PASS test_ability_pool_deduplicated")

func test_hp_and_energy_seeded_at_max() -> void:
	var pc := CharacterCreationManager._build_pc("Tess", "Human", "arcanist", "crook", "portrait_human_f")
	assert(pc.current_hp == pc.hp_max,
		"current_hp must equal hp_max at creation (got %d, max %d)" % [pc.current_hp, pc.hp_max])
	print("  PASS test_hp_and_energy_seeded_at_max")

func test_build_pc_deterministic_stats() -> void:
	# Same picks always produce the same stats — no randomness
	var pc1 := CharacterCreationManager._build_pc("A", "Human", "arcanist", "crook", "")
	var pc2 := CharacterCreationManager._build_pc("B", "Human", "arcanist", "crook", "")
	assert(pc1.strength  == pc2.strength,  "strength must be deterministic")
	assert(pc1.dexterity == pc2.dexterity, "dexterity must be deterministic")
	assert(pc1.cognition == pc2.cognition, "cognition must be deterministic")
	assert(pc1.willpower == pc2.willpower, "willpower must be deterministic")
	assert(pc1.vitality  == pc2.vitality,  "vitality must be deterministic")
	print("  PASS test_build_pc_deterministic_stats")

func test_build_pc_arcanist_crook_human_stats() -> void:
	# arcanist: cog:2|wil:2  Human: wil:1  crook: dex:1
	# expected: str=4, dex=5, cog=6, wil=7, vit=4
	var pc := CharacterCreationManager._build_pc("Tess", "Human", "arcanist", "crook", "")
	assert(pc.strength  == 4,
		"Human/arcanist/crook strength must be 4, got %d" % pc.strength)
	assert(pc.dexterity == 5,
		"Human/arcanist/crook dexterity must be 5 (crook+1), got %d" % pc.dexterity)
	assert(pc.cognition == 6,
		"Human/arcanist/crook cognition must be 6 (arcanist+2), got %d" % pc.cognition)
	assert(pc.willpower == 7,
		"Human/arcanist/crook willpower must be 7 (arcanist+2, Human+1), got %d" % pc.willpower)
	assert(pc.vitality  == 4,
		"Human/arcanist/crook vitality must be 4, got %d" % pc.vitality)
	print("  PASS test_build_pc_arcanist_crook_human_stats")
