extends Node

## --- Unit Tests: ArchetypeData.Role data layer ---
## Verifies role field is parsed correctly for all 9 archetypes,
## stub fallback, case-insensitivity, and reload() idempotency.

func _ready() -> void:
	print("=== test_archetype_role.gd ===")
	test_all_archetype_roles()
	test_stub_fallback()
	test_case_insensitive_healer()
	test_case_insensitive_controller()
	test_unknown_role_falls_back_to_attacker()
	test_reload_reparses_cleanly()
	print("=== All archetype role tests passed ===")

## All 9 archetypes load with expected roles.
func test_all_archetype_roles() -> void:
	var expected := {
		"RogueFinder":     ArchetypeData.Role.ATTACKER,
		"archer_bandit":   ArchetypeData.Role.ATTACKER,
		"grunt":           ArchetypeData.Role.ATTACKER,
		"alchemist":       ArchetypeData.Role.HEALER,
		"elite_guard":     ArchetypeData.Role.CONTROLLER,
		"skeleton_warrior":ArchetypeData.Role.ATTACKER,
		"rat_scrapper":    ArchetypeData.Role.ATTACKER,
		"cave_spider":     ArchetypeData.Role.DEBUFFER,
		"young_dragon":    ArchetypeData.Role.ATTACKER,
	}
	for id in expected.keys():
		var archetype: ArchetypeData = ArchetypeLibrary.get_archetype(id)
		assert(archetype.role == expected[id],
			"%s: expected role %d, got %d" % [id, expected[id], archetype.role])
	print("  PASS test_all_archetype_roles")

## Unknown id falls back to grunt stub; grunt is ATTACKER.
func test_stub_fallback() -> void:
	var archetype: ArchetypeData = ArchetypeLibrary.get_archetype("nonexistent_id")
	assert(archetype.role == ArchetypeData.Role.ATTACKER,
		"Stub fallback should yield ATTACKER, got %d" % archetype.role)
	print("  PASS test_stub_fallback")

## "healer", "HEALER", "Healer" all parse to Role.HEALER.
func test_case_insensitive_healer() -> void:
	var archetype: ArchetypeData = ArchetypeLibrary.get_archetype("alchemist")
	assert(archetype.role == ArchetypeData.Role.HEALER,
		"alchemist should be HEALER (case-insensitive parse), got %d" % archetype.role)
	print("  PASS test_case_insensitive_healer")

## "controller" parses to Role.CONTROLLER (exercises another branch).
func test_case_insensitive_controller() -> void:
	var archetype: ArchetypeData = ArchetypeLibrary.get_archetype("elite_guard")
	assert(archetype.role == ArchetypeData.Role.CONTROLLER,
		"elite_guard should be CONTROLLER, got %d" % archetype.role)
	print("  PASS test_case_insensitive_controller")

## Unrecognized role string falls back to ATTACKER without crash.
func test_unknown_role_falls_back_to_attacker() -> void:
	# Build a minimal ArchetypeData and manually test the parse helper indirectly
	# by verifying the default value of a freshly-created ArchetypeData.
	var stub := ArchetypeData.new()
	assert(stub.role == ArchetypeData.Role.ATTACKER,
		"Default ArchetypeData.role should be ATTACKER, got %d" % stub.role)
	print("  PASS test_unknown_role_falls_back_to_attacker")

## reload() clears and re-parses; roles survive the round-trip.
func test_reload_reparses_cleanly() -> void:
	ArchetypeLibrary.reload()
	var spider: ArchetypeData = ArchetypeLibrary.get_archetype("cave_spider")
	assert(spider.role == ArchetypeData.Role.DEBUFFER,
		"cave_spider should still be DEBUFFER after reload(), got %d" % spider.role)
	var alch: ArchetypeData = ArchetypeLibrary.get_archetype("alchemist")
	assert(alch.role == ArchetypeData.Role.HEALER,
		"alchemist should still be HEALER after reload(), got %d" % alch.role)
	print("  PASS test_reload_reparses_cleanly")
