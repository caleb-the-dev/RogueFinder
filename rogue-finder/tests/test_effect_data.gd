extends Node

## --- Unit Tests: EffectData ---
## Run via Project > Run This Scene (F6) with this script attached to a Node.
## Tests cover enum values and default field initialization.
## No scene nodes, timers, or signals required.

func _ready() -> void:
	print("=== test_effect_data.gd ===")
	test_defaults()
	test_enum_values()
	print("=== All EffectData tests passed ===")

## --- Default Field Tests ---

func test_defaults() -> void:
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
	print("  PASS test_defaults")

## --- Enum Value Tests ---

func test_enum_values() -> void:
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
	print("  PASS test_enum_values")
