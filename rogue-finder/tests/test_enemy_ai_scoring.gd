extends Node

## --- Unit Tests: EnemyAI Slice 3 — per-effect-type scoring, damage estimation, stride ---
##
## All Unit3D objects are created without add_child (no scene tree) so _ready() never fires
## and visual nodes stay null. EnemyAI only reads non-visual fields, so this is safe.
##
## Grid3D objects are created without add_child; _ready() never fires so _cell_materials is
## empty, but is_valid/is_occupied/is_hazard/get_unit_at all work on pure dictionary state.
##
## hp_max formula (no bonuses): 10 + vitality * 4. _make_unit() sets vitality=4 → hp_max=26.
##
## Ability reference (from abilities.csv):
##   strike       — HARM/SINGLE/ENEMY/STRENGTH/PHYSICAL/range=1/cost=2/base_val=5
##   heavy_strike — HARM/SINGLE/ENEMY/STRENGTH/PHYSICAL/range=1/cost=4/base_val=9
##   sweep        — HARM/ARC/ENEMY/STRENGTH/PHYSICAL/range=1/cost=3/base_val=4
##   quick_shot   — HARM/SINGLE/ENEMY/DEXTERITY/PHYSICAL/range=3/cost=2/base_val=4
##   healing_draught — MEND/SELF/ANY/range=0/cost=3/base_val=8
##   heal_burst   — MEND/RADIAL/ALLY/range=2/cost=4/base_val=10
##   bless        — BUFF/SINGLE/ALLY/WILLPOWER/range=3/cost=2 (STRENGTH buff)
##   web_shot     — DEBUFF/SINGLE/ENEMY/range=3/cost=3 (DEXTERITY debuff)
##   shove        — FORCE/SINGLE/ENEMY/STRENGTH/range=1/cost=3/base_val=1

func _ready() -> void:
	print("=== test_enemy_ai_scoring.gd ===")
	test_aoe_2plus_preference()
	test_aoe_skipped_when_only_1_hostile_hit()
	test_finishing_blow_targets_weakest()
	test_best_damage_tiebreak()
	test_mend_closest_fit()
	test_buff_redundancy_skip()
	test_debuff_redundancy_skip()
	test_debuff_stack_cap()
	test_force_off_grid_preference()
	test_force_not_useful_drops()
	test_expected_damage_accuracy()
	test_healer_stride_targets_low_hp_ally()
	test_attacker_stride_ignores_low_hp_ally()
	print("=== All EnemyAI Slice 3 scoring tests passed ===")

## ======================================================
## --- Helpers ---
## ======================================================

func _make_unit(
		archetype_id: String,
		abilities: Array[String],
		hp_ratio: float,
		energy: int,
		grid_x: int,
		grid_y: int,
		is_player: bool = false) -> Unit3D:
	var d := CombatantData.new()
	d.archetype_id    = archetype_id
	d.vitality        = 4   # hp_max = 10 + 4*4 = 26
	d.abilities       = abilities
	d.is_player_unit  = is_player
	var u := Unit3D.new()
	u.data           = d
	u.current_energy = energy
	u.grid_pos       = Vector2i(grid_x, grid_y)
	u.is_alive       = true
	u.current_hp     = maxi(1, roundi(float(u.data.hp_max) * hp_ratio))
	return u

func _no_units() -> Array[Unit3D]:
	return [] as Array[Unit3D]

## Creates a Grid3D without a scene tree. _ready() never fires so _cell_materials is empty,
## but all query methods (is_valid, is_occupied, is_hazard, get_unit_at) work fine.
func _make_grid() -> Grid3D:
	return Grid3D.new()

## ======================================================
## --- Tests ---
## ======================================================

## 1. AoE-2+ preference: ATTACKER with sweep (ARC/HARM, hits row of 3) + strike (SINGLE/HARM).
##    Two hostiles placed in the ARC cells → sweep hits 2 → AoE-2+ fires → sweep chosen.
func test_aoe_2plus_preference() -> void:
	var grid := _make_grid()
	# Enemy at (0,0), arc fires toward (1,0) → dir=(1,0), root=(1,0), perp=(0,1)
	# ARC cells: (1,-1)[invalid y<0], (1,0), (1,1) → valid cells: (1,0) and (1,1)
	var enemy    := _make_unit("grunt", ["sweep", "strike"], 1.0, 10, 0, 0)
	var hostile1 := _make_unit("grunt", [], 1.0, 10, 1, 0, true)
	var hostile2 := _make_unit("grunt", [], 1.0, 10, 1, 1, true)
	grid.set_occupied(hostile1.grid_pos, hostile1)
	grid.set_occupied(hostile2.grid_pos, hostile2)

	var hostiles: Array[Unit3D] = [hostile1, hostile2]
	var pick: Dictionary = EnemyAI.choose_action(enemy, _no_units(), hostiles, grid)
	assert(pick.get("ability") != null,
		"ATTACKER with two in-ARC hostiles should pick an ability")
	assert(pick["ability"].ability_id == "sweep",
		"AoE-2+ should pick sweep over strike, got: %s" % pick["ability"].ability_id)
	print("  PASS test_aoe_2plus_preference")

## 2. AoE skipped: same setup but only 1 hostile in ARC cells.
##    ARC hits 1 → doesn't qualify for AoE-2+ → falls to best-damage single-target.
func test_aoe_skipped_when_only_1_hostile_hit() -> void:
	var grid := _make_grid()
	var enemy   := _make_unit("grunt", ["sweep", "strike"], 1.0, 10, 0, 0)
	# Only 1 hostile — ARC at (1,0) would hit it alone
	var hostile := _make_unit("grunt", [], 1.0, 10, 1, 0, true)
	grid.set_occupied(hostile.grid_pos, hostile)

	var hostiles: Array[Unit3D] = [hostile]
	var pick: Dictionary = EnemyAI.choose_action(enemy, _no_units(), hostiles, grid)
	assert(pick.get("ability") != null,
		"ATTACKER with 1 in-ARC hostile should still pick an ability")
	assert(pick["ability"].ability_id == "strike",
		"AoE-2+ not satisfied (1 hit) — should pick strike (best single-target), got: %s" \
		% pick["ability"].ability_id)
	print("  PASS test_aoe_skipped_when_only_1_hostile_hit")

## 3. Finishing-blow: two hostiles (HP 3 vs HP 26), single HARM ability (strike).
##    ATTACKER should target the 3-HP hostile (finishing-blow priority).
func test_finishing_blow_targets_weakest() -> void:
	var enemy      := _make_unit("grunt", ["strike"], 1.0, 10, 0, 0)
	var low_hp     := _make_unit("grunt", [], 0.0, 10, 1, 0, true)  # hp_ratio 0 → hp clamped to 1
	low_hp.current_hp = 3  # override to exact value
	var high_hp    := _make_unit("grunt", [], 1.0, 10, 0, 1, true)  # full HP = 26

	var hostiles: Array[Unit3D] = [low_hp, high_hp]
	var pick: Dictionary = EnemyAI.choose_action(enemy, _no_units(), hostiles, null)
	assert(pick.get("ability") != null, "Should pick an ability with two hostiles in range")
	assert(pick.get("target") == low_hp,
		"Finishing-blow should target the 3-HP hostile, not the 26-HP one")
	print("  PASS test_finishing_blow_targets_weakest")

## 4. Best-damage tiebreak: two hostiles equal HP, ability A (strike=5 dmg) vs ability B (heavy_strike=9 dmg).
##    No stat bonuses, no armor → expected damages = 5 and 9. heavy_strike wins.
func test_best_damage_tiebreak() -> void:
	var enemy   := _make_unit("grunt", ["strike", "heavy_strike"], 1.0, 10, 0, 0)
	var h1      := _make_unit("grunt", [], 1.0, 10, 1, 0, true)  # equal HP (26)
	var h2      := _make_unit("grunt", [], 1.0, 10, 0, 1, true)  # equal HP (26)

	var hostiles: Array[Unit3D] = [h1, h2]
	var pick: Dictionary = EnemyAI.choose_action(enemy, _no_units(), hostiles, null)
	assert(pick.get("ability") != null, "Should pick an ability")
	assert(pick["ability"].ability_id == "heavy_strike",
		"Higher expected damage (heavy_strike=9 vs strike=5) should win, got: %s" \
		% pick["ability"].ability_id)
	print("  PASS test_best_damage_tiebreak")

## 5. MEND closest-fit: two MEND abilities with different targeting.
##    healing_draught (SELF/MEND/base=5) vs heal_burst (RADIAL/ALLY/base=5).
##    Part A: caster at 50% HP, no allies → only healing_draught (SELF) qualifies → picked.
##    Part B: caster at 100% HP, ally at 60% HP (below 70%) → only heal_burst reaches ally → picked.
func test_mend_closest_fit() -> void:
	# Part A: HEALER at 50% HP, no allies. SELF-MEND is only option.
	var enemy := _make_unit("alchemist", ["healing_draught", "heal_burst"], 0.5, 10, 0, 0)
	var pick: Dictionary = EnemyAI.choose_action(enemy, _no_units(), _no_units(), null)
	assert(pick.get("ability") != null, "HEALER below 70% HP with no allies should pick MEND")
	assert(int(pick["ability"].effects[0].effect_type) == 1,
		"Part A: should pick MEND (healing_draught for self), got effect type: %d" \
		% int(pick["ability"].effects[0].effect_type))
	assert(pick["ability"].ability_id == "healing_draught",
		"Part A: should pick healing_draught (SELF-MEND), got: %s" % pick["ability"].ability_id)

	# Part B: HEALER at 100% HP, ally at 60% HP (below 70% threshold).
	# healing_draught is SELF — caster at 100% doesn't qualify. heal_burst targets ALLY → fires.
	var healer := _make_unit("alchemist", ["healing_draught", "heal_burst"], 1.0, 10, 0, 0)
	var ally   := _make_unit("alchemist", [], 1.0, 10, 1, 0)
	ally.current_hp = 15  # hp_max=26, 15/26=57.7% → below 70% threshold; missing 11 HP
	var allies_arr: Array[Unit3D] = [ally]
	var pick2: Dictionary = EnemyAI.choose_action(healer, allies_arr, _no_units(), null)
	assert(pick2.get("ability") != null, "HEALER with in-range injured ally should pick MEND")
	assert(pick2["ability"].ability_id == "heal_burst",
		"Part B: should pick heal_burst (ALLY-MEND for injured ally), got: %s" \
		% pick2["ability"].ability_id)
	print("  PASS test_mend_closest_fit")

## 6. BUFF redundancy skip: ATTACKER with only bless (BUFF/ALLY ability).
##    The single ally already has "bless" in active_buff_ability_ids → redundancy skip → {null, null}.
func test_buff_redundancy_skip() -> void:
	var enemy := _make_unit("grunt", ["bless"], 1.0, 10, 0, 0)
	var ally  := _make_unit("alchemist", [], 1.0, 10, 1, 0)
	ally.active_buff_ability_ids = ["bless"]  # already buffed

	var allies_arr: Array[Unit3D] = [ally]
	var pick: Dictionary = EnemyAI.choose_action(enemy, allies_arr, _no_units(), null)
	# ATTACKER walk: HARM(no ability) → FORCE(no) → DEBUFF(no) → BUFF(bless, but redundant) →
	# MEND(no) → TRAVEL(no) → {null, null}
	assert(pick.get("ability") == null,
		"Redundant BUFF should be skipped — expected null ability, got: %s" \
		% (pick.get("ability").ability_id if pick.get("ability") else "null"))
	print("  PASS test_buff_redundancy_skip")

## 7. DEBUFF redundancy skip: DEBUFFER with web_shot, hostile already has web_shot debuff.
##    → redundancy skip → no other DEBUFF → {null, null}.
func test_debuff_redundancy_skip() -> void:
	# cave_spider = DEBUFFER role
	var enemy   := _make_unit("cave_spider", ["web_shot"], 1.0, 10, 0, 0)
	var hostile := _make_unit("grunt", [], 1.0, 10, 1, 0, true)
	hostile.active_debuff_ability_ids = ["web_shot"]  # already debuffed

	var hostiles: Array[Unit3D] = [hostile]
	var pick: Dictionary = EnemyAI.choose_action(enemy, _no_units(), hostiles, null)
	# DEBUFFER walk: DEBUFF(web_shot redundant) → HARM(no pure harm) → FORCE(no) → ... → {null, null}
	# cave_spider has venom_bite+acid_splash in its archetype pool, but our unit only has web_shot.
	assert(pick.get("ability") == null,
		"Redundant DEBUFF should be skipped — expected null ability, got: %s" \
		% (pick.get("ability").ability_id if pick.get("ability") else "null"))
	print("  PASS test_debuff_redundancy_skip")

## 8. DEBUFF stack cap: hostile has 3 stacks of DEXTERITY debuff (web_shot target stat = DEXTERITY = 1).
##    → stack cap → {null, null}.
func test_debuff_stack_cap() -> void:
	var enemy   := _make_unit("cave_spider", ["web_shot"], 1.0, 10, 0, 0)
	var hostile := _make_unit("grunt", [], 1.0, 10, 1, 0, true)
	# AbilityData.Attribute.DEXTERITY = 1
	hostile.debuff_stat_stacks = {1: 3}  # stack cap reached for DEXTERITY

	var hostiles: Array[Unit3D] = [hostile]
	var pick: Dictionary = EnemyAI.choose_action(enemy, _no_units(), hostiles, null)
	assert(pick.get("ability") == null,
		"DEBUFF stack cap should block application — expected null, got: %s" \
		% (pick.get("ability").ability_id if pick.get("ability") else "null"))
	print("  PASS test_debuff_stack_cap")

## 9. FORCE disabled: CONTROLLER with shove (FORCE-only) — FORCE is disabled pending Slice 4.
##    Enemy has no HARM/DEBUFF/BUFF/MEND fallback, so the role walk exhausts → {null, null}.
func test_force_off_grid_preference() -> void:
	var grid    := _make_grid()
	var enemy   := _make_unit("elite_guard", ["shove"], 1.0, 10, 5, 7)
	var hostile := _make_unit("grunt", [], 1.0, 10, 5, 8, true)
	grid.set_occupied(hostile.grid_pos, hostile)

	var hostiles: Array[Unit3D] = [hostile]
	var pick: Dictionary = EnemyAI.choose_action(enemy, _no_units(), hostiles, grid)
	assert(pick.get("ability") == null,
		"FORCE is disabled — FORCE-only CONTROLLER should return null (no fallback ability)")
	print("  PASS test_force_off_grid_preference")

## 10. FORCE not useful: CONTROLLER with shove, hostile mid-grid (5,4), no hazards, no isolation gain
##     (only 1 hostile, so isolation_sum=0). Score=0 → FORCE drops.
##     Enemy also has strike (HARM), so after FORCE drops, HARM fires next.
func test_force_not_useful_drops() -> void:
	var grid    := _make_grid()
	# CONTROLLER walk: FORCE → DEBUFF → HARM → ...
	var enemy   := _make_unit("elite_guard", ["shove", "strike"], 1.0, 10, 5, 3)
	var hostile := _make_unit("grunt", [], 1.0, 10, 5, 4, true)  # adjacent, mid-grid
	grid.set_occupied(hostile.grid_pos, hostile)

	var hostiles: Array[Unit3D] = [hostile]
	var pick: Dictionary = EnemyAI.choose_action(enemy, _no_units(), hostiles, grid)
	assert(pick.get("ability") != null,
		"CONTROLLER should fall back to HARM when FORCE is not useful")
	assert(pick["ability"].ability_id == "strike",
		"After FORCE drops (no meaningful push), should pick strike (HARM), got: %s" \
		% pick["ability"].ability_id)
	print("  PASS test_force_not_useful_drops")

## 11. _expected_damage accuracy: attacker strength=2, target with default physical_armor=3.
##     strike: HARM/PHYSICAL/STRENGTH/base=5. Expected: max(0, 5 + 2 - 3) = 4.
##     Note: CombatantData.physical_armor defaults to 3 (not 0), so physical_defense=3.
func test_expected_damage_accuracy() -> void:
	var ability  := AbilityLibrary.get_ability("strike")  # HARM/PHYSICAL/STRENGTH/base=5
	var attacker := _make_unit("grunt", [], 1.0, 10, 0, 0)
	attacker.data.strength = 2
	var target   := _make_unit("grunt", [], 1.0, 10, 1, 0, true)
	# physical_armor defaults to 3 → physical_defense = 3. No other bonuses.
	# Expected: max(0, 5 base + 2 str - 3 armor) = 4.
	var expected: int = 4
	var result: int   = EnemyAI._expected_damage(ability, attacker, target)
	assert(result == expected,
		"_expected_damage should return %d (5 base + 2 str - 3 default armor), got: %d" \
		% [expected, result])
	print("  PASS test_expected_damage_accuracy")

## 12. HEALER stride target: HEALER with one ally below 70% HP → pick_stride_target returns the ally.
func test_healer_stride_targets_low_hp_ally() -> void:
	var healer  := _make_unit("alchemist", [], 1.0, 10, 0, 0)
	var ally    := _make_unit("alchemist", [], 0.5, 10, 1, 0)   # 50% HP → below 70% threshold
	var hostile := _make_unit("grunt",    [], 1.0, 10, 5, 0, true)

	var allies:   Array[Unit3D] = [ally]
	var hostiles: Array[Unit3D] = [hostile]
	var target: Unit3D = EnemyAI.pick_stride_target(healer, allies, hostiles)
	assert(target == ally,
		"HEALER should stride toward low-HP ally, not hostile")
	print("  PASS test_healer_stride_targets_low_hp_ally")

## 13. ATTACKER stride target: even with a low-HP ally, ATTACKER strides toward nearest hostile.
func test_attacker_stride_ignores_low_hp_ally() -> void:
	var attacker := _make_unit("grunt", [], 1.0, 10, 0, 0)
	var ally     := _make_unit("alchemist", [], 0.5, 10, 1, 0)  # 50% HP — below threshold
	var hostile  := _make_unit("grunt",    [], 1.0, 10, 2, 0, true)

	var allies:   Array[Unit3D] = [ally]
	var hostiles: Array[Unit3D] = [hostile]
	var target: Unit3D = EnemyAI.pick_stride_target(attacker, allies, hostiles)
	assert(target == hostile,
		"ATTACKER should stride toward nearest hostile regardless of ally HP, got: %s" \
		% (target.data.archetype_id if target != null else "null"))
	print("  PASS test_attacker_stride_ignores_low_hp_ally")
