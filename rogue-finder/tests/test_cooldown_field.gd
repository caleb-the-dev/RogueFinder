extends Node

func _ready() -> void:
	print("=== test_cooldown_field.gd ===")
	test_cooldown_default()
	test_cooldown_set()
	test_cooldown_loaded_from_csv()
	print("=== All cooldown field tests passed ===")

func test_cooldown_default() -> void:
	var a := AbilityData.new()
	assert(a.cooldown_max == 0, "cooldown_max should default to 0")
	print("  PASS test_cooldown_default")

func test_cooldown_set() -> void:
	var a := AbilityData.new()
	a.cooldown_max = 3
	assert(a.cooldown_max == 3, "cooldown_max should hold the assigned value")
	print("  PASS test_cooldown_set")

func test_cooldown_loaded_from_csv() -> void:
	# strike has energy_cost 2 → cooldown_max 2 per migration table
	var a := AbilityLibrary.get_ability("strike")
	assert(a.cooldown_max == 2, "strike cooldown_max should be 2, got %d" % a.cooldown_max)
	# heavy_strike has energy_cost 4 → cooldown_max 3
	var hs := AbilityLibrary.get_ability("heavy_strike")
	assert(hs.cooldown_max == 3, "heavy_strike cooldown_max should be 3, got %d" % hs.cooldown_max)
	print("  PASS test_cooldown_loaded_from_csv")
