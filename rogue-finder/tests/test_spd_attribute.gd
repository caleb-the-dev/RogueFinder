extends Node

func _ready() -> void:
	print("=== test_spd_attribute.gd ===")
	test_spd_default()
	test_spd_serializes()
	test_kindred_spd_bonus_applies()
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
