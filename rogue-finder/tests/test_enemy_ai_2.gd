extends Node

## --- Unit Tests: EnemyAI.choose_action — Slice 2 role-driven picker ---
## Tests role preference walk, critical-heal override, ai_override seam, and final fallback.
##
## Unit3D objects are created without add_child (no scene tree) — _ready() is never called,
## so visual fields (_mesh etc.) remain null. EnemyAI only reads non-visual fields (data,
## current_hp, current_energy, grid_pos, is_alive, ai_override), so this is safe.
##
## hp_max formula (no bonuses with empty kindred/class): 10 + vitality * 4.
## _make_unit() sets vitality=4 → hp_max=26. current_hp is set via ratio * 26.
##
## Ability reference (from abilities.csv):
##   heal_burst   — MEND / RADIAL / ALLY   / range=2 / cost=4
##   healing_draught — MEND / SELF / ANY   / range=0 / cost=3
##   acid_splash  — HARM (primary) / SINGLE / ENEMY  / range=3 / cost=3
##   strike       — HARM / SINGLE / ENEMY  / range=1 / cost=2
##   web_shot     — DEBUFF / SINGLE / ENEMY / range=3 / cost=3
##   venom_bite   — HARM (primary) / SINGLE / ENEMY  / range=1 / cost=2
##   shove        — FORCE / SINGLE / ENEMY / range=1 / cost=3

func _ready() -> void:
	print("=== test_enemy_ai_2.gd ===")
	test_critical_heal_override_fires()
	test_critical_heal_threshold_respected()
	test_attacker_prefers_harm()
	test_healer_prefers_mend()
	test_debuffer_prefers_debuff()
	test_controller_prefers_force()
	test_attacker_falls_back_to_mend_when_no_hostile_in_range()
	test_final_fallback_returns_null()
	test_ai_override_force_random()
	print("=== All EnemyAI Slice 2 tests passed ===")

## ======================================================
## --- Helpers ---
## ======================================================

## Creates a Unit3D with only the fields EnemyAI reads populated.
## hp_ratio: 0.0–1.0 fraction of the computed hp_max (vitality=4 → hp_max≈26).
func _make_unit(
		archetype_id: String,
		abilities: Array[String],
		hp_ratio: float,
		energy: int,
		grid_x: int,
		grid_y: int) -> Unit3D:
	var d := CombatantData.new()
	d.archetype_id = archetype_id
	d.vitality     = 4          # hp_max = 10 + 4*4 = 26 with no kindred/class bonuses
	d.abilities    = abilities
	var u := Unit3D.new()
	u.data           = d
	u.current_energy = energy
	u.grid_pos       = Vector2i(grid_x, grid_y)
	u.is_alive       = true
	u.current_hp     = maxi(1, roundi(float(u.data.hp_max) * hp_ratio))
	return u

func _no_units() -> Array[Unit3D]:
	return [] as Array[Unit3D]

## ======================================================
## --- Tests ---
## ======================================================

## 1. Critical-heal fires: HEALER with heal_burst (MEND/ALLY) + ally at 10% HP in range.
##    Returns MEND on the dying ally, not HARM on the hostile.
func test_critical_heal_override_fires() -> void:
	# alchemist = HEALER role
	var enemy      := _make_unit("alchemist", ["heal_burst", "acid_splash"], 1.0, 10, 0, 0)
	var dying_ally := _make_unit("grunt", [], 0.10, 10, 1, 0)   # 10% HP — below 15% threshold
	var hostile    := _make_unit("grunt", [], 1.0,  10, 1, 0)

	var allies:   Array[Unit3D] = [dying_ally]
	var hostiles: Array[Unit3D] = [hostile]

	var pick: Dictionary = EnemyAI.choose_action(enemy, allies, hostiles, null)
	assert(pick.get("ability") != null,
		"Critical-heal override should return a valid ability")
	assert(int(pick["ability"].effects[0].effect_type) == 1,   # MEND
		"Critical-heal should pick a MEND ability, got: %s" % pick["ability"].ability_id)
	assert(pick.get("target") == dying_ally,
		"Critical-heal target should be the dying ally, not the hostile")
	print("  PASS test_critical_heal_override_fires")

## 2. Threshold respected: ally at 20% HP (above 15%) → no crit-heal; role walk takes over.
##    Healer at 40% HP → healing_draught (SELF/MEND) is situationally useful (self < 70%).
func test_critical_heal_threshold_respected() -> void:
	var enemy   := _make_unit("alchemist", ["healing_draught", "acid_splash"], 0.40, 10, 0, 0)
	var ally    := _make_unit("grunt", [], 0.20, 10, 1, 0)   # 20% — above crit threshold
	var hostile := _make_unit("grunt", [], 1.0,  10, 2, 0)

	var allies:   Array[Unit3D] = [ally]
	var hostiles: Array[Unit3D] = [hostile]

	var pick: Dictionary = EnemyAI.choose_action(enemy, allies, hostiles, null)
	# No crit-heal (ally at 20% >= 15%). HEALER walks MEND first.
	# healing_draught is SELF → MEND useful only when self < 70%. Enemy at 40% < 70% → picks MEND.
	assert(pick.get("ability") != null,
		"HEALER should pick via role walk")
	assert(int(pick["ability"].effects[0].effect_type) == 1,   # MEND
		"HEALER role walk should choose MEND when self is below 70pct, got: %s" \
		% pick["ability"].ability_id)
	print("  PASS test_critical_heal_threshold_respected")

## 3. ATTACKER prefers HARM: enemy at 80% HP (MEND not useful for self), hostile adjacent.
##    strike (HARM, range=1) should win over healing_draught (MEND, SELF).
func test_attacker_prefers_harm() -> void:
	# grunt = ATTACKER role
	var enemy   := _make_unit("grunt", ["strike", "healing_draught"], 0.80, 10, 0, 0)
	var hostile := _make_unit("grunt", [], 1.0, 10, 1, 0)   # adjacent — in strike range

	var allies:   Array[Unit3D] = _no_units()
	var hostiles: Array[Unit3D] = [hostile]

	var pick: Dictionary = EnemyAI.choose_action(enemy, allies, hostiles, null)
	assert(pick.get("ability") != null,
		"ATTACKER with in-range hostile should pick an ability")
	assert(pick["ability"].ability_id == "strike",
		"ATTACKER should pick HARM (strike) over MEND, got: %s" % pick["ability"].ability_id)
	assert(pick.get("target") == hostile,
		"ATTACKER HARM target should be the hostile")
	print("  PASS test_attacker_prefers_harm")

## 4. HEALER prefers MEND: healer at 40% HP, hostile at range 2 (within acid_splash range=3).
##    healing_draught (MEND) should win over acid_splash (HARM).
func test_healer_prefers_mend() -> void:
	# alchemist = HEALER role
	var enemy   := _make_unit("alchemist", ["healing_draught", "acid_splash"], 0.40, 10, 0, 0)
	var hostile := _make_unit("grunt", [], 1.0, 10, 2, 0)   # distance=2, within acid_splash range

	var allies:   Array[Unit3D] = _no_units()
	var hostiles: Array[Unit3D] = [hostile]

	var pick: Dictionary = EnemyAI.choose_action(enemy, allies, hostiles, null)
	assert(pick.get("ability") != null,
		"HEALER should pick an ability")
	assert(int(pick["ability"].effects[0].effect_type) == 1,   # MEND
		"HEALER should prefer MEND over HARM, got: %s" % pick["ability"].ability_id)
	print("  PASS test_healer_prefers_mend")

## 5. DEBUFFER prefers DEBUFF: web_shot (DEBUFF primary, range=3) vs venom_bite (HARM primary, range=1).
##    Hostile at range=1 — both in range. DEBUFF should win.
func test_debuffer_prefers_debuff() -> void:
	# cave_spider = DEBUFFER role
	var enemy   := _make_unit("cave_spider", ["web_shot", "venom_bite"], 1.0, 10, 0, 0)
	var hostile := _make_unit("grunt", [], 1.0, 10, 1, 0)   # range=1, reachable by both

	var allies:   Array[Unit3D] = _no_units()
	var hostiles: Array[Unit3D] = [hostile]

	var pick: Dictionary = EnemyAI.choose_action(enemy, allies, hostiles, null)
	assert(pick.get("ability") != null,
		"DEBUFFER with options in range should pick an ability")
	assert(int(pick["ability"].effects[0].effect_type) == 5,   # DEBUFF
		"DEBUFFER should pick DEBUFF (web_shot) over HARM (venom_bite), got: %s" \
		% pick["ability"].ability_id)
	print("  PASS test_debuffer_prefers_debuff")

## 6. CONTROLLER FORCE disabled: shove (FORCE) vs strike (HARM), both in range.
##    FORCE is disabled pending Slice 4, so CONTROLLER falls through to HARM (strike).
func test_controller_prefers_force() -> void:
	# elite_guard = CONTROLLER role
	var enemy   := _make_unit("elite_guard", ["shove", "strike"], 1.0, 10, 0, 0)
	var hostile := _make_unit("grunt", [], 1.0, 10, 1, 0)

	var allies:   Array[Unit3D] = _no_units()
	var hostiles: Array[Unit3D] = [hostile]

	var pick: Dictionary = EnemyAI.choose_action(enemy, allies, hostiles, null)
	assert(pick.get("ability") != null,
		"CONTROLLER with HARM fallback should pick an ability")
	assert(int(pick["ability"].effects[0].effect_type) == 0,   # HARM (FORCE disabled)
		"CONTROLLER should fall through to HARM (strike) when FORCE is disabled, got: %s" \
		% pick["ability"].ability_id)
	print("  PASS test_controller_prefers_force")

## 7. Role fallback: ATTACKER with no hostile in strike range (hostile at distance=5).
##    Self at 50% HP → MEND (healing_draught, SELF) is situationally useful. Walks down to MEND.
func test_attacker_falls_back_to_mend_when_no_hostile_in_range() -> void:
	var enemy   := _make_unit("grunt", ["strike", "healing_draught"], 0.50, 10, 0, 0)
	var hostile := _make_unit("grunt", [], 1.0, 10, 5, 0)   # too far for strike (range=1)

	var allies:   Array[Unit3D] = _no_units()
	var hostiles: Array[Unit3D] = [hostile]

	var pick: Dictionary = EnemyAI.choose_action(enemy, allies, hostiles, null)
	assert(pick.get("ability") != null,
		"ATTACKER should fall back to MEND when no hostile is in range")
	assert(int(pick["ability"].effects[0].effect_type) == 1,   # MEND
		"Fallback should land on MEND (healing_draught), got: %s" \
		% pick["ability"].ability_id)
	print("  PASS test_attacker_falls_back_to_mend_when_no_hostile_in_range")

## 8. Final fallback: enemy with 0 energy → nothing affordable → {null, null}.
func test_final_fallback_returns_null() -> void:
	var enemy   := _make_unit("grunt", ["strike"], 1.0, 0, 0, 0)   # strike costs 2, energy=0
	var hostile := _make_unit("grunt", [], 1.0, 10, 1, 0)

	var allies:   Array[Unit3D] = _no_units()
	var hostiles: Array[Unit3D] = [hostile]

	var pick: Dictionary = EnemyAI.choose_action(enemy, allies, hostiles, null)
	assert(pick.get("target") == null,
		"No affordable abilities → target should be null")
	assert(pick.get("ability") == null,
		"No affordable abilities → ability should be null")
	print("  PASS test_final_fallback_returns_null")

## 9. ai_override seam: "force_random" bypasses the role walk.
##    HEALER (would normally pick MEND first) with healing_draught + strike.
##    Hostile adjacent so strike is reachable. Over 40 runs both abilities must appear.
func test_ai_override_force_random() -> void:
	var enemy   := _make_unit("alchemist", ["healing_draught", "strike"], 1.0, 10, 0, 0)
	var hostile := _make_unit("grunt", [], 1.0, 10, 1, 0)   # adjacent — strike in range
	enemy.ai_override = "force_random"

	var allies:   Array[Unit3D] = _no_units()
	var hostiles: Array[Unit3D] = [hostile]

	var seen_ids: Dictionary = {}
	for _i in range(40):
		var pick: Dictionary = EnemyAI.choose_action(enemy, allies, hostiles, null)
		assert(pick.get("ability") != null,
			"force_random should always return an ability when options exist")
		seen_ids[pick["ability"].ability_id] = true

	assert(seen_ids.has("healing_draught"),
		"force_random should eventually pick healing_draught (SELF shape, always reachable)")
	assert(seen_ids.has("strike"),
		"force_random should eventually pick strike (hostile in range)")
	print("  PASS test_ai_override_force_random")
