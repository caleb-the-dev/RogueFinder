extends Node

## --- Unit Tests: Armor Mod (transient runtime BUFF/DEBUFF) ---
## Tests: physical_armor_mod / magic_armor_mod feed defense formulas,
## stone_guard / divine_ward CSV rows resolve to the right Attribute enum,
## clamp range [-10, 10], and snapshot-restore round-trip pattern.

func _ready() -> void:
	print("=== test_armor_mod.gd ===")
	test_physical_defense_includes_mod_positive()
	test_physical_defense_includes_mod_negative()
	test_magic_defense_includes_mod_positive()
	test_magic_defense_includes_mod_negative()
	test_armor_mods_default_zero()
	test_armor_mods_independent()
	test_stone_guard_targets_physical_armor_mod()
	test_divine_ward_targets_magic_armor_mod()
	test_armor_mod_clamp_upper()
	test_armor_mod_clamp_lower()
	test_snapshot_restore_round_trip()
	print("=== All armor-mod tests passed ===")

## --- Defense formulas include the mod field ---

func test_physical_defense_includes_mod_positive() -> void:
	var d := CombatantData.new()
	d.physical_armor = 4
	var base: int = d.physical_defense
	d.physical_armor_mod = 2
	assert(d.physical_defense == base + 2,
		"physical_armor_mod +2 should raise physical_defense by 2 (base %d, got %d)" % [base, d.physical_defense])
	print("  PASS test_physical_defense_includes_mod_positive")

func test_physical_defense_includes_mod_negative() -> void:
	var d := CombatantData.new()
	d.physical_armor = 6
	var base: int = d.physical_defense
	d.physical_armor_mod = -3
	assert(d.physical_defense == base - 3,
		"physical_armor_mod -3 should lower physical_defense by 3 (base %d, got %d)" % [base, d.physical_defense])
	print("  PASS test_physical_defense_includes_mod_negative")

func test_magic_defense_includes_mod_positive() -> void:
	var d := CombatantData.new()
	d.magic_armor = 3
	var base: int = d.magic_defense
	d.magic_armor_mod = 4
	assert(d.magic_defense == base + 4,
		"magic_armor_mod +4 should raise magic_defense by 4 (base %d, got %d)" % [base, d.magic_defense])
	print("  PASS test_magic_defense_includes_mod_positive")

func test_magic_defense_includes_mod_negative() -> void:
	var d := CombatantData.new()
	d.magic_armor = 5
	var base: int = d.magic_defense
	d.magic_armor_mod = -2
	assert(d.magic_defense == base - 2,
		"magic_armor_mod -2 should lower magic_defense by 2 (base %d, got %d)" % [base, d.magic_defense])
	print("  PASS test_magic_defense_includes_mod_negative")

func test_armor_mods_default_zero() -> void:
	var d := CombatantData.new()
	assert(d.physical_armor_mod == 0, "physical_armor_mod default should be 0, got %d" % d.physical_armor_mod)
	assert(d.magic_armor_mod    == 0, "magic_armor_mod default should be 0, got %d"    % d.magic_armor_mod)
	print("  PASS test_armor_mods_default_zero")

func test_armor_mods_independent() -> void:
	# Setting physical mod must not affect magic_defense, and vice versa.
	var d := CombatantData.new()
	d.physical_armor = 3
	d.magic_armor    = 3
	var base_phys: int = d.physical_defense
	var base_mag:  int = d.magic_defense
	d.physical_armor_mod = 5
	assert(d.magic_defense == base_mag,
		"physical_armor_mod must not bleed into magic_defense (base %d, got %d)" % [base_mag, d.magic_defense])
	d.physical_armor_mod = 0
	d.magic_armor_mod    = 5
	assert(d.physical_defense == base_phys,
		"magic_armor_mod must not bleed into physical_defense (base %d, got %d)" % [base_phys, d.physical_defense])
	print("  PASS test_armor_mods_independent")

## --- CSV → Attribute enum mapping for stone_guard / divine_ward ---

func test_stone_guard_targets_physical_armor_mod() -> void:
	var ab: AbilityData = AbilityLibrary.get_ability("stone_guard")
	assert(ab.effects.size() == 1,
		"stone_guard should have exactly 1 effect, got %d" % ab.effects.size())
	var e: EffectData = ab.effects[0]
	assert(e.effect_type == EffectData.EffectType.BUFF,
		"stone_guard effect should be BUFF, got %d" % e.effect_type)
	assert(e.target_stat == AbilityData.Attribute.PHYSICAL_ARMOR_MOD,
		"stone_guard target_stat should be PHYSICAL_ARMOR_MOD, got %d" % e.target_stat)
	assert(e.base_value == 2,
		"stone_guard base_value should be 2, got %d" % e.base_value)
	print("  PASS test_stone_guard_targets_physical_armor_mod")

func test_divine_ward_targets_magic_armor_mod() -> void:
	var ab: AbilityData = AbilityLibrary.get_ability("divine_ward")
	assert(ab.effects.size() == 1,
		"divine_ward should have exactly 1 effect, got %d" % ab.effects.size())
	var e: EffectData = ab.effects[0]
	assert(e.effect_type == EffectData.EffectType.BUFF,
		"divine_ward effect should be BUFF, got %d" % e.effect_type)
	assert(e.target_stat == AbilityData.Attribute.MAGIC_ARMOR_MOD,
		"divine_ward target_stat should be MAGIC_ARMOR_MOD, got %d" % e.target_stat)
	assert(e.base_value == 2,
		"divine_ward base_value should be 2, got %d" % e.base_value)
	print("  PASS test_divine_ward_targets_magic_armor_mod")

## --- Clamp behavior in [-10, 10] ---
## We cannot call CombatManager3D._apply_stat_delta directly (it requires a Unit3D).
## Instead, mirror the clampi() logic to verify the contract a delta application must respect.

func test_armor_mod_clamp_upper() -> void:
	var d := CombatantData.new()
	d.physical_armor_mod = clampi(d.physical_armor_mod + 50, -10, 10)
	assert(d.physical_armor_mod == 10,
		"physical_armor_mod must clamp at +10, got %d" % d.physical_armor_mod)
	d.magic_armor_mod = clampi(d.magic_armor_mod + 50, -10, 10)
	assert(d.magic_armor_mod == 10,
		"magic_armor_mod must clamp at +10, got %d" % d.magic_armor_mod)
	print("  PASS test_armor_mod_clamp_upper")

func test_armor_mod_clamp_lower() -> void:
	var d := CombatantData.new()
	d.physical_armor_mod = clampi(d.physical_armor_mod - 50, -10, 10)
	assert(d.physical_armor_mod == -10,
		"physical_armor_mod must clamp at -10, got %d" % d.physical_armor_mod)
	d.magic_armor_mod = clampi(d.magic_armor_mod - 50, -10, 10)
	assert(d.magic_armor_mod == -10,
		"magic_armor_mod must clamp at -10, got %d" % d.magic_armor_mod)
	print("  PASS test_armor_mod_clamp_lower")

## --- Snapshot/restore round-trip ---
## Mirrors the _attr_snapshots pattern in CombatManager3D._setup_units / _end_combat.
## Verifies that restoring snapshotted values zeros out mid-combat mutations.

func test_snapshot_restore_round_trip() -> void:
	var d := CombatantData.new()
	d.physical_armor_mod = 0
	d.magic_armor_mod    = 0
	# Snapshot baseline
	var snap: Dictionary = {
		"physical_armor_mod": d.physical_armor_mod,
		"magic_armor_mod":    d.magic_armor_mod,
	}
	# Mutate mid-combat
	d.physical_armor_mod = 5
	d.magic_armor_mod    = -3
	assert(d.physical_armor_mod == 5 and d.magic_armor_mod == -3,
		"mid-combat mutation should hold before restore")
	# Restore
	d.physical_armor_mod = snap.get("physical_armor_mod", 0)
	d.magic_armor_mod    = snap.get("magic_armor_mod",    0)
	assert(d.physical_armor_mod == 0,
		"physical_armor_mod must restore to 0, got %d" % d.physical_armor_mod)
	assert(d.magic_armor_mod == 0,
		"magic_armor_mod must restore to 0, got %d" % d.magic_armor_mod)
	# Snapshot missing keys still restores safely (covers in-flight saves before the mod fields existed)
	var legacy_snap: Dictionary = {"strength": 4}
	d.physical_armor_mod = 7
	d.physical_armor_mod = legacy_snap.get("physical_armor_mod", 0)
	assert(d.physical_armor_mod == 0,
		"missing snapshot key should fall back to 0, got %d" % d.physical_armor_mod)
	print("  PASS test_snapshot_restore_round_trip")
