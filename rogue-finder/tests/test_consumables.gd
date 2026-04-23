extends SceneTree

func _initialize() -> void:
	_test_consumable_data_defaults()
	_test_healing_potion()
	_test_power_tonic()
	_test_unknown_stub()
	_test_all_archetype_consumables_resolve()
	_test_mend_base_value()
	_test_buff_target_stat()
	print("All ConsumableLibrary tests PASSED.")
	quit()

func _test_consumable_data_defaults() -> void:
	var c := ConsumableData.new()
	assert(c.consumable_id == "", "default consumable_id should be empty")
	assert(c.consumable_name == "", "default consumable_name should be empty")
	assert(c.effect_type == EffectData.EffectType.MEND, "default effect_type should be MEND")
	assert(c.base_value == 0, "default base_value should be 0")
	assert(c.target_stat == 0, "default target_stat should be 0")
	assert(c.description == "", "default description should be empty")

func _test_healing_potion() -> void:
	var c: ConsumableData = ConsumableLibrary.get_consumable("healing_potion")
	assert(c != null, "healing_potion should not be null")
	assert(c.consumable_id == "healing_potion", "ID mismatch: " + c.consumable_id)
	assert(c.consumable_name == "Healing Potion", "name mismatch: " + c.consumable_name)
	assert(c.effect_type == EffectData.EffectType.MEND,
		"healing_potion should be MEND, got " + str(c.effect_type))
	assert(c.base_value == 15, "healing_potion base_value should be 15, got " + str(c.base_value))
	assert(c.description != "", "healing_potion should have a description")

func _test_power_tonic() -> void:
	var c: ConsumableData = ConsumableLibrary.get_consumable("power_tonic")
	assert(c != null, "power_tonic should not be null")
	assert(c.consumable_id == "power_tonic", "ID mismatch: " + c.consumable_id)
	assert(c.consumable_name == "Power Tonic", "name mismatch: " + c.consumable_name)
	assert(c.effect_type == EffectData.EffectType.BUFF,
		"power_tonic should be BUFF, got " + str(c.effect_type))
	assert(c.base_value == 2, "power_tonic base_value should be 2, got " + str(c.base_value))
	assert(c.target_stat == AbilityData.Attribute.STRENGTH,
		"power_tonic target_stat should be STRENGTH, got " + str(c.target_stat))

func _test_unknown_stub() -> void:
	var c: ConsumableData = ConsumableLibrary.get_consumable("does_not_exist")
	assert(c != null, "unknown consumable should return a stub, not null")
	assert(c.consumable_id == "unknown", "stub ID should be 'unknown'")

func _test_all_archetype_consumables_resolve() -> void:
	# Every non-empty consumable assigned in ArchetypeLibrary must exist in ConsumableLibrary.
	for arch_id in ArchetypeLibrary.ARCHETYPES:
		var con_id: String = ArchetypeLibrary.ARCHETYPES[arch_id].get("consumable", "")
		if con_id == "":
			continue
		var c: ConsumableData = ConsumableLibrary.get_consumable(con_id)
		assert(c.consumable_id != "unknown",
			"Archetype '%s' consumable '%s' not found in ConsumableLibrary" % [arch_id, con_id])

func _test_mend_base_value() -> void:
	# MEND consumables must have a positive base_value.
	for c in ConsumableLibrary.all_consumables():
		if c.effect_type == EffectData.EffectType.MEND:
			assert(c.base_value > 0,
				"MEND consumable '%s' base_value must be > 0" % c.consumable_id)

func _test_buff_target_stat() -> void:
	# BUFF and DEBUFF consumables must declare a non-zero target_stat.
	for c in ConsumableLibrary.all_consumables():
		if c.effect_type == EffectData.EffectType.BUFF or c.effect_type == EffectData.EffectType.DEBUFF:
			assert(c.target_stat != 0,
				"BUFF/DEBUFF consumable '%s' must declare a non-zero target_stat" % c.consumable_id)
