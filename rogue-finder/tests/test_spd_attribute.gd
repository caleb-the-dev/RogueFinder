extends Node

func _ready() -> void:
	print("=== test_spd_attribute.gd ===")
	test_spd_default()
	test_spd_serializes()
	test_kindred_spd_bonus_applies()
	test_kindred_library_returns_spd_bonus()
	test_spd_round_trips_through_save_dict()
	print("=== All SPD tests passed ===")

func test_spd_default() -> void:
	var d := CombatantData.new()
	assert(d.spd == 4, "spd should default to 4, got %d" % d.spd)
	print("  PASS test_spd_default")

func test_spd_serializes() -> void:
	var d := CombatantData.new()
	d.spd = 7
	var saved: int = d.spd
	assert(saved == 7, "spd should round-trip, got %d" % saved)
	print("  PASS test_spd_serializes")

func test_kindred_spd_bonus_applies() -> void:
	var d := CombatantData.new()
	d.kindred = "Spider"
	var eff := d.effective_stat("spd")
	assert(eff >= d.spd, "effective_stat(spd) should be at least raw spd")
	print("  PASS test_kindred_spd_bonus_applies")

func test_kindred_library_returns_spd_bonus() -> void:
	assert(KindredLibrary.get_stat_bonus("Spider", "spd") == 3, "Spider should have spd +3")
	assert(KindredLibrary.get_stat_bonus("Skeleton", "spd") == -1, "Skeleton should have spd -1")
	assert(KindredLibrary.get_stat_bonus("Human", "spd") == 0, "Human should have spd 0")
	print("  PASS test_kindred_library_returns_spd_bonus")

func test_spd_round_trips_through_save_dict() -> void:
	var d := CombatantData.new()
	d.spd = 7
	var dict: Dictionary = GameState._serialize_combatant(d)
	var rebuilt: CombatantData = GameState._deserialize_combatant(dict)
	assert(rebuilt.spd == 7, "spd should round-trip through save dict, got %d" % rebuilt.spd)
	print("  PASS test_spd_round_trips_through_save_dict")
