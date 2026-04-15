extends SceneTree

func _initialize() -> void:
	_test_ability_data_defaults()
	_test_known_ability()
	_test_unknown_ability_stub()
	_test_all_archetype_abilities_resolve()
	_test_archetype_library_updates()
	print("All AbilityLibrary tests PASSED.")
	quit()

func _test_ability_data_defaults() -> void:
	var ability := AbilityData.new()
	assert(ability.ability_id == "", "default ability_id should be empty")
	assert(ability.energy_cost == 0, "default energy_cost should be 0")
	assert(ability.range == 1, "default range should be 1")
	assert(ability.target_type == AbilityData.TargetType.SINGLE_ENEMY,
		"default target_type should be SINGLE_ENEMY")

func _test_known_ability() -> void:
	var a: AbilityData = AbilityLibrary.get_ability("strike")
	assert(a != null, "strike should not be null")
	assert(a.ability_id == "strike", "ID mismatch: " + a.ability_id)
	assert(a.ability_name == "Strike", "name mismatch: " + a.ability_name)
	assert(a.energy_cost == 2, "strike energy_cost should be 2, got " + str(a.energy_cost))
	assert(a.range == 1, "strike range should be 1")
	assert(a.target_type == AbilityData.TargetType.SINGLE_ENEMY, "strike should target SINGLE_ENEMY")
	assert(a.description != "", "description should not be empty")

	var b: AbilityData = AbilityLibrary.get_ability("taunt")
	assert(b.energy_cost == 1, "taunt energy_cost should be 1")
	assert(b.range == 3, "taunt range should be 3")

	var c: AbilityData = AbilityLibrary.get_ability("healing_draught")
	assert(c.target_type == AbilityData.TargetType.SELF, "healing_draught should target SELF")

func _test_unknown_ability_stub() -> void:
	var stub: AbilityData = AbilityLibrary.get_ability("nonexistent_xyz")
	assert(stub != null, "unknown ID should return stub, not null")
	assert(stub.ability_id == "unknown", "stub id should be 'unknown', got: " + stub.ability_id)
	assert(stub.energy_cost == 0, "stub energy_cost should be 0")

func _test_all_archetype_abilities_resolve() -> void:
	# Every non-empty ability ID used in ArchetypeLibrary must resolve without null
	var all_ids: Array[String] = [
		"strike", "guard", "inspire",
		"quick_shot", "disengage",
		"heavy_strike",
		"acid_splash", "smoke_bomb", "healing_draught",
		"shield_bash", "counter", "taunt",
	]
	for id in all_ids:
		var a: AbilityData = AbilityLibrary.get_ability(id)
		assert(a != null, "ability should not be null: " + id)
		assert(a.ability_id == id, "ID roundtrip failed for: " + id)

func _test_archetype_library_updates() -> void:
	var rogue: CombatantData = ArchetypeLibrary.create("RogueFinder", "Vael", true)
	assert(rogue.consumable == "Smoke Vial",
		"RogueFinder consumable should be 'Smoke Vial', got: " + rogue.consumable)
	assert(rogue.abilities[0] == "strike",
		"RogueFinder abilities[0] should be 'strike', got: " + rogue.abilities[0])

	var alch: CombatantData = ArchetypeLibrary.create("alchemist", "", false)
	assert(alch.consumable == "Healing Potion",
		"alchemist consumable should be 'Healing Potion', got: " + alch.consumable)
	assert(alch.abilities[0] == "acid_splash",
		"alchemist abilities[0] should be 'acid_splash', got: " + alch.abilities[0])

	var grunt: CombatantData = ArchetypeLibrary.create("grunt", "", false)
	assert(grunt.consumable == "",
		"grunt consumable should be empty, got: " + grunt.consumable)
	assert(grunt.abilities[0] == "heavy_strike",
		"grunt abilities[0] should be 'heavy_strike', got: " + grunt.abilities[0])
