extends Node

## --- Unit Tests: Recruit Math ---
## Tests CombatManager3D._compute_recruit_base_chance formula and
## _recruit_odds_label bucket thresholds without requiring a scene.
## Mirrors the formulas directly — same approach as test_armor_mod.gd.

func _ready() -> void:
	print("=== test_recruit_math.gd ===")
	test_hp_component_near_death()
	test_hp_component_full_hp()
	test_hp_component_half_hp()
	test_wil_delta_bonus()
	test_wil_delta_penalty()
	test_chance_ceiling()
	test_chance_floor()
	test_odds_label_very_low()
	test_odds_label_low()
	test_odds_label_moderate()
	test_odds_label_high()
	test_odds_label_very_high()
	test_odds_label_boundaries()
	print("=== All recruit-math tests passed ===")
	get_tree().quit()

## --- Base Chance Formula ---
## Formula: clampf(hp_component * 0.80 + wil_delta * 0.20, 0.05, 0.95)
## hp_component = 1.0 - (current_hp / hp_max)
## wil_delta    = (party_wil_sum - enemy_wil_sum) / 20.0

func test_hp_component_near_death() -> void:
	# Target at 1 HP of 20: hp_pct ≈ 0.05, hp_component ≈ 0.95, wil_delta 0
	var hp_pct: float = 0.05
	var chance: float = _base_chance(hp_pct, 0.0)
	var expected: float = clampf((1.0 - hp_pct) * 0.80, 0.05, 0.95)
	assert(absf(chance - expected) < 0.001,
		"Near-death target: expected %f got %f" % [expected, chance])
	print("  PASS test_hp_component_near_death")

func test_hp_component_full_hp() -> void:
	# Full HP → hp_component = 0.0, chance hits floor 0.05
	var chance: float = _base_chance(1.0, 0.0)
	assert(chance == 0.05, "Full-HP target should yield 0.05 (floor), got %f" % chance)
	print("  PASS test_hp_component_full_hp")

func test_hp_component_half_hp() -> void:
	# Half HP, no WIL delta → chance = 0.5 * 0.80 = 0.40
	var chance: float = _base_chance(0.5, 0.0)
	assert(absf(chance - 0.40) < 0.001, "Half-HP, no WIL: expected 0.40 got %f" % chance)
	print("  PASS test_hp_component_half_hp")

func test_wil_delta_bonus() -> void:
	# Half HP + party has +20 WIL over enemies → wil_delta = 1.0 → 0.20 bonus capped
	# Raw = 0.40 + 0.20 = 0.60
	var party_wil_sum: int = 30
	var enemy_wil_sum: int = 10
	var wil_delta: float   = float(party_wil_sum - enemy_wil_sum) / 20.0
	var chance: float      = _base_chance(0.5, wil_delta)
	assert(absf(chance - 0.60) < 0.001, "WIL bonus: expected 0.60 got %f" % chance)
	print("  PASS test_wil_delta_bonus")

func test_wil_delta_penalty() -> void:
	# Half HP + enemies outclass party by 20 WIL → wil_delta = -1.0 → -0.20 penalty
	# Raw = 0.40 - 0.20 = 0.20
	var wil_delta: float = -1.0
	var chance: float    = _base_chance(0.5, wil_delta)
	assert(absf(chance - 0.20) < 0.001, "WIL penalty: expected 0.20 got %f" % chance)
	print("  PASS test_wil_delta_penalty")

func test_chance_ceiling() -> void:
	# Even with absurd WIL advantage + near-dead target, must cap at 0.95
	var chance: float = _base_chance(0.0, 10.0)
	assert(chance == 0.95, "Ceiling must be 0.95, got %f" % chance)
	print("  PASS test_chance_ceiling")

func test_chance_floor() -> void:
	# Full HP + severe WIL deficit must not go below 0.05
	var chance: float = _base_chance(1.0, -10.0)
	assert(chance == 0.05, "Floor must be 0.05, got %f" % chance)
	print("  PASS test_chance_floor")

## --- Odds Label Buckets ---
## < 0.20 → "Very Low"
## < 0.40 → "Low"
## < 0.60 → "Moderate"
## < 0.80 → "High"
## else   → "Very High"

func test_odds_label_very_low() -> void:
	assert(_odds_label(0.0)  == "Very Low", "0.0 should be Very Low")
	assert(_odds_label(0.05) == "Very Low", "0.05 should be Very Low")
	assert(_odds_label(0.19) == "Very Low", "0.19 should be Very Low")
	print("  PASS test_odds_label_very_low")

func test_odds_label_low() -> void:
	assert(_odds_label(0.20) == "Low", "0.20 should be Low")
	assert(_odds_label(0.30) == "Low", "0.30 should be Low")
	assert(_odds_label(0.39) == "Low", "0.39 should be Low")
	print("  PASS test_odds_label_low")

func test_odds_label_moderate() -> void:
	assert(_odds_label(0.40) == "Moderate", "0.40 should be Moderate")
	assert(_odds_label(0.50) == "Moderate", "0.50 should be Moderate")
	assert(_odds_label(0.59) == "Moderate", "0.59 should be Moderate")
	print("  PASS test_odds_label_moderate")

func test_odds_label_high() -> void:
	assert(_odds_label(0.60) == "High", "0.60 should be High")
	assert(_odds_label(0.70) == "High", "0.70 should be High")
	assert(_odds_label(0.79) == "High", "0.79 should be High")
	print("  PASS test_odds_label_high")

func test_odds_label_very_high() -> void:
	assert(_odds_label(0.80) == "Very High", "0.80 should be Very High")
	assert(_odds_label(0.95) == "Very High", "0.95 should be Very High")
	print("  PASS test_odds_label_very_high")

func test_odds_label_boundaries() -> void:
	# Verify each threshold transitions correctly
	assert(_odds_label(0.199) == "Very Low",  "0.199 should still be Very Low")
	assert(_odds_label(0.200) == "Low",       "0.200 flips to Low")
	assert(_odds_label(0.399) == "Low",       "0.399 still Low")
	assert(_odds_label(0.400) == "Moderate",  "0.400 flips to Moderate")
	assert(_odds_label(0.599) == "Moderate",  "0.599 still Moderate")
	assert(_odds_label(0.600) == "High",      "0.600 flips to High")
	assert(_odds_label(0.799) == "High",      "0.799 still High")
	assert(_odds_label(0.800) == "Very High", "0.800 flips to Very High")
	print("  PASS test_odds_label_boundaries")

## --- Helpers (mirrors of CombatManager3D logic) ---

func _base_chance(hp_pct: float, wil_delta: float) -> float:
	var hp_component: float = 1.0 - hp_pct
	return clampf(hp_component * 0.80 + wil_delta * 0.20, 0.05, 0.95)

func _odds_label(chance: float) -> String:
	if chance < 0.20: return "Very Low"
	if chance < 0.40: return "Low"
	if chance < 0.60: return "Moderate"
	if chance < 0.80: return "High"
	return "Very High"
