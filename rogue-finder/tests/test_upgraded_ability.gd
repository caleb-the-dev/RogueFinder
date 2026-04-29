extends Node

## --- Unit Tests: Upgraded Ability System ---
## Tests: upgraded_id field default, get_upgraded() stub path, round-trip sanity,
## CSV load regression (54 abilities), never-null guarantee.

func _ready() -> void:
	print("=== test_upgraded_ability.gd ===")
	test_ability_data_upgraded_id_default()
	test_get_upgraded_no_upgrade_returns_stub()
	test_get_upgraded_manual_round_trip()
	test_get_upgraded_csv_row_no_upgraded_id()
	test_all_abilities_still_54()
	test_get_upgraded_never_null()
	print("=== All upgraded ability tests passed ===")

## upgraded_id field defaults to empty string on a fresh AbilityData.
func test_ability_data_upgraded_id_default() -> void:
	var a := AbilityData.new()
	assert(a.upgraded_id == "",
		"upgraded_id default should be empty string, got: '%s'" % a.upgraded_id)
	print("  PASS test_ability_data_upgraded_id_default")

## get_upgraded() returns a stub (ability_id == "") when upgraded_id is unset.
func test_get_upgraded_no_upgrade_returns_stub() -> void:
	var result: AbilityData = AbilityLibrary.get_upgraded("strike")
	assert(result != null, "get_upgraded should never return null")
	# strike has no upgraded_id in CSV, so we get the blank stub
	assert(result.ability_id == "",
		"stub ability_id should be empty, got: '%s'" % result.ability_id)
	print("  PASS test_get_upgraded_no_upgrade_returns_stub")

## Manually wire upgraded_id on a constructed AbilityData and confirm the round-trip
## reaches a real ability (verifies get_upgraded follows the link correctly).
func test_get_upgraded_manual_round_trip() -> void:
	var base := AbilityData.new()
	base.ability_id = "test_base"
	base.upgraded_id = "heavy_strike"
	# Inject into cache so get_ability("test_base") returns our instance.
	AbilityLibrary._ensure_loaded()
	AbilityLibrary._cache["test_base"] = base

	var upgraded: AbilityData = AbilityLibrary.get_upgraded("test_base")
	assert(upgraded != null, "upgraded result must not be null")
	assert(upgraded.ability_id == "heavy_strike",
		"upgraded should be heavy_strike, got: '%s'" % upgraded.ability_id)
	assert(upgraded.ability_name == "Heavy Strike",
		"upgraded name mismatch: '%s'" % upgraded.ability_name)

	# Clean up injected entry so it doesn't affect other tests.
	AbilityLibrary._cache.erase("test_base")
	print("  PASS test_get_upgraded_manual_round_trip")

## Every real CSV row currently has no upgraded_id → get_upgraded returns stub.
func test_get_upgraded_csv_row_no_upgraded_id() -> void:
	var result: AbilityData = AbilityLibrary.get_upgraded("arcane_bolt")
	assert(result != null, "must not be null")
	assert(result.ability_id == "",
		"arcane_bolt has no upgrade; stub expected, got: '%s'" % result.ability_id)
	print("  PASS test_get_upgraded_csv_row_no_upgraded_id")

## 54 original + 6 weapon abilities (blade_strike, heavy_blade_strike, quick_draw,
## aimed_draw, staff_bolt, empowered_bolt) added in Slice 3.
func test_all_abilities_still_54() -> void:
	var all: Array[AbilityData] = AbilityLibrary.all_abilities()
	assert(all.size() == 60,
		"expected 60 abilities (54 + 6 weapon), got %d" % all.size())
	print("  PASS test_all_abilities_still_54")

## get_upgraded() must return non-null for any existing ability ID.
func test_get_upgraded_never_null() -> void:
	for a: AbilityData in AbilityLibrary.all_abilities():
		var result: AbilityData = AbilityLibrary.get_upgraded(a.ability_id)
		assert(result != null,
			"get_upgraded('%s') returned null" % a.ability_id)
	print("  PASS test_get_upgraded_never_null")
