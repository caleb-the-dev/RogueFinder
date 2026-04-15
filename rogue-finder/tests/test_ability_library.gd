extends SceneTree

func _initialize() -> void:
	_test_ability_data_defaults()
	_test_known_ability()
	_test_unknown_ability_stub()
	_test_all_archetype_abilities_resolve()
	_test_archetype_library_updates()
	_test_multi_effect_ability()
	_test_applicable_to()
	print("All AbilityLibrary tests PASSED.")
	quit()

func _test_ability_data_defaults() -> void:
	var ability := AbilityData.new()
	assert(ability.ability_id == "", "default ability_id should be empty")
	assert(ability.energy_cost == 0, "default energy_cost should be 0")
	assert(ability.tile_range == 1, "default range should be 1")
	assert(ability.target_shape == AbilityData.TargetShape.SINGLE,
		"default target_shape should be SINGLE")
	assert(ability.applicable_to == AbilityData.ApplicableTo.ENEMY,
		"default applicable_to should be ENEMY")
	assert(ability.attribute == AbilityData.Attribute.NONE,
		"default attribute should be NONE")
	assert(ability.effects.is_empty(), "default effects should be empty")
	assert(ability.passthrough == false, "default passthrough should be false")

func _test_known_ability() -> void:
	var a: AbilityData = AbilityLibrary.get_ability("strike")
	assert(a != null, "strike should not be null")
	assert(a.ability_id == "strike", "ID mismatch: " + a.ability_id)
	assert(a.ability_name == "Strike", "name mismatch: " + a.ability_name)
	assert(a.energy_cost == 2, "strike energy_cost should be 2, got " + str(a.energy_cost))
	assert(a.tile_range == 1, "strike range should be 1")
	assert(a.target_shape == AbilityData.TargetShape.SINGLE,
		"strike target_shape should be SINGLE")
	assert(a.applicable_to == AbilityData.ApplicableTo.ENEMY,
		"strike applicable_to should be ENEMY")
	assert(a.attribute == AbilityData.Attribute.STRENGTH,
		"strike attribute should be STRENGTH")
	assert(a.description != "", "description should not be empty")
	assert(a.effects.size() == 1, "strike should have 1 effect, got " + str(a.effects.size()))
	assert(a.effects[0].effect_type == EffectData.EffectType.HARM,
		"strike effect[0] should be HARM")
	assert(a.effects[0].base_value == 5,
		"strike HARM base_value should be 5, got " + str(a.effects[0].base_value))

	var b: AbilityData = AbilityLibrary.get_ability("taunt")
	assert(b.energy_cost == 1, "taunt energy_cost should be 1")
	assert(b.tile_range == 3, "taunt range should be 3")

	var c: AbilityData = AbilityLibrary.get_ability("healing_draught")
	assert(c.target_shape == AbilityData.TargetShape.SELF,
		"healing_draught target_shape should be SELF")

func _test_unknown_ability_stub() -> void:
	var stub: AbilityData = AbilityLibrary.get_ability("nonexistent_xyz")
	assert(stub != null, "unknown ID should return stub, not null")
	assert(stub.ability_id == "unknown", "stub id should be 'unknown', got: " + stub.ability_id)
	assert(stub.energy_cost == 0, "stub energy_cost should be 0")

func _test_all_archetype_abilities_resolve() -> void:
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
		assert(a.effects.size() > 0,
			"every ability must have at least one effect, missing for: " + id)

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

func _test_multi_effect_ability() -> void:
	var a: AbilityData = AbilityLibrary.get_ability("acid_splash")
	assert(a.effects.size() == 2,
		"acid_splash should have 2 effects, got " + str(a.effects.size()))
	assert(a.effects[0].effect_type == EffectData.EffectType.HARM,
		"acid_splash effect[0] should be HARM")
	assert(a.effects[0].base_value == 3,
		"acid_splash HARM base_value should be 3, got " + str(a.effects[0].base_value))
	assert(a.effects[1].effect_type == EffectData.EffectType.DEBUFF,
		"acid_splash effect[1] should be DEBUFF")
	assert(a.effects[1].base_value == 1,
		"acid_splash DEBUFF base_value should be 1, got " + str(a.effects[1].base_value))
	assert(a.effects[1].target_stat == AbilityData.Attribute.DEXTERITY,
		"acid_splash DEBUFF should target DEXTERITY, got " + str(a.effects[1].target_stat))

func _test_applicable_to() -> void:
	var inspire: AbilityData = AbilityLibrary.get_ability("inspire")
	assert(inspire.applicable_to == AbilityData.ApplicableTo.ALLY,
		"inspire applicable_to should be ALLY")
	assert(inspire.target_shape == AbilityData.TargetShape.SINGLE,
		"inspire target_shape should be SINGLE")

	var smoke: AbilityData = AbilityLibrary.get_ability("smoke_bomb")
	assert(smoke.target_shape == AbilityData.TargetShape.RADIAL,
		"smoke_bomb target_shape should be RADIAL")
