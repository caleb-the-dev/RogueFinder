extends SceneTree

func _initialize() -> void:
	_test_defaults()
	_test_enum_values()
	print("All EffectData tests PASSED.")
	quit()

func _test_defaults() -> void:
	var e := EffectData.new()
	assert(e.effect_type == EffectData.EffectType.HARM,
		"default effect_type should be HARM")
	assert(e.base_value == 0,
		"default base_value should be 0")
	assert(e.target_pool == EffectData.PoolType.HP,
		"default target_pool should be HP")
	assert(e.target_stat == 0,
		"default target_stat should be 0")
	assert(e.movement_type == EffectData.MoveType.FREE,
		"default movement_type should be FREE")

func _test_enum_values() -> void:
	# Verify all expected EffectType enum variants exist and have correct values
	assert(EffectData.EffectType.HARM   == 0, "HARM should be 0")
	assert(EffectData.EffectType.MEND   == 1, "MEND should be 1")
	assert(EffectData.EffectType.FORCE  == 2, "FORCE should be 2")
	assert(EffectData.EffectType.TRAVEL == 3, "TRAVEL should be 3")
	assert(EffectData.EffectType.BUFF   == 4, "BUFF should be 4")
	assert(EffectData.EffectType.DEBUFF == 5, "DEBUFF should be 5")

	# Verify all expected PoolType enum variants exist and have correct values
	assert(EffectData.PoolType.HP     == 0, "HP should be 0")
	assert(EffectData.PoolType.ENERGY == 1, "ENERGY should be 1")

	# Verify all expected MoveType enum variants exist and have correct values
	assert(EffectData.MoveType.FREE == 0, "FREE should be 0")
	assert(EffectData.MoveType.LINE == 1, "LINE should be 1")
