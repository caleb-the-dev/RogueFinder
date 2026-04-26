extends SceneTree

## --- Unit Tests: QTE Slice 1 foundation ---
## Tests pure logic helpers mirrored from QTEBar and CombatManager3D.
## No scene nodes are instantiated — all helpers are duplicated here.

func _initialize() -> void:
	_test_difficulty_tiers()
	_test_beat_result_low_tier()
	_test_beat_result_medium_tier()
	_test_beat_result_high_tier()
	print("All QTE foundation tests PASSED.")
	quit()

## --- Mirrors QTEBar._set_difficulty() → returns ss_half ---
func _ss_half_for_cost(energy_cost: int) -> float:
	if energy_cost <= 2:
		return 0.20
	elif energy_cost <= 4:
		return 0.12
	return 0.07

## --- Mirrors QTEBar._get_beat_result() ---
func _beat_result(pos: float, ss_half: float) -> float:
	var dist: float = abs(pos - 0.5)
	if dist > ss_half:
		return 0.25
	if dist >= ss_half * 0.70:
		return 0.75
	if dist >= ss_half * 0.30:
		return 1.0
	return 1.25


## ============================================================
## Difficulty tier assignment
## ============================================================

func _test_difficulty_tiers() -> void:
	assert(_ss_half_for_cost(1) == 0.20, "energy 1 → Low ss_half=0.20")
	assert(_ss_half_for_cost(2) == 0.20, "energy 2 → Low ss_half=0.20")
	assert(_ss_half_for_cost(3) == 0.12, "energy 3 → Medium ss_half=0.12")
	assert(_ss_half_for_cost(4) == 0.12, "energy 4 → Medium ss_half=0.12")
	assert(_ss_half_for_cost(5) == 0.07, "energy 5 → High ss_half=0.07")
	assert(_ss_half_for_cost(6) == 0.07, "energy 6 → High ss_half=0.07")

## ============================================================
## Beat result — Low tier (ss_half = 0.20)
## gold boundary: 0.20 × 0.30 = 0.06  → gold [0.44, 0.56]
## green boundary: 0.20 × 0.70 = 0.14 → green [0.36, 0.44) ∪ (0.56, 0.64]
## orange boundary: ss edge 0.20       → orange [0.30, 0.36) ∪ (0.64, 0.70]
## red: outside [0.30, 0.70]
## ============================================================

func _test_beat_result_low_tier() -> void:
	var h: float = 0.20
	assert(_beat_result(0.50, h) == 1.25, "Low: center → gold")
	assert(_beat_result(0.55, h) == 1.25, "Low: pos=0.55 dist=0.05 < 0.06 → gold")
	assert(_beat_result(0.56, h) == 1.0,  "Low: pos=0.56 dist=0.06 ≥ 0.06 → green")
	assert(_beat_result(0.63, h) == 1.0,  "Low: pos=0.63 dist=0.13 < 0.14 → green")
	assert(_beat_result(0.64, h) == 0.75, "Low: pos=0.64 dist=0.14 ≥ 0.14 → orange")
	assert(_beat_result(0.67, h) == 0.75, "Low: pos=0.67 dist=0.17 < 0.20 → orange")
	assert(_beat_result(0.75, h) == 0.25, "Low: pos=0.75 dist=0.25 > 0.20 → red")
	assert(_beat_result(0.10, h) == 0.25, "Low: far left → red")
	assert(_beat_result(0.00, h) == 0.25, "Low: pos=0.0 → red")

## ============================================================
## Beat result — Medium tier (ss_half = 0.12)
## gold boundary: 0.12 × 0.30 = 0.036
## green boundary: 0.12 × 0.70 = 0.084
## ============================================================

func _test_beat_result_medium_tier() -> void:
	var h: float = 0.12
	assert(_beat_result(0.50,  h) == 1.25, "Med: center → gold")
	assert(_beat_result(0.534, h) == 1.25, "Med: pos=0.534 dist=0.034 < 0.036 → gold")
	assert(_beat_result(0.536, h) == 1.0,  "Med: pos=0.536 dist=0.036 ≥ 0.036 → green")
	assert(_beat_result(0.583, h) == 1.0,  "Med: pos=0.583 dist=0.083 < 0.084 → green")
	assert(_beat_result(0.590, h) == 0.75, "Med: pos=0.590 dist=0.090 > 0.084 → orange")
	assert(_beat_result(0.615, h) == 0.75, "Med: pos=0.615 dist=0.115 < 0.12 → orange")
	assert(_beat_result(0.625, h) == 0.25, "Med: pos=0.625 dist=0.125 > 0.12 → red")
	assert(_beat_result(0.30,  h) == 0.25, "Med: far left → red")

## ============================================================
## Beat result — High tier (ss_half = 0.07)
## gold boundary: 0.07 × 0.30 = 0.021
## green boundary: 0.07 × 0.70 = 0.049
## ============================================================

func _test_beat_result_high_tier() -> void:
	var h: float = 0.07
	assert(_beat_result(0.50,  h) == 1.25, "High: center → gold")
	assert(_beat_result(0.520, h) == 1.25, "High: pos=0.520 dist=0.020 < 0.021 → gold")
	assert(_beat_result(0.521, h) == 1.0,  "High: pos=0.521 dist=0.021 ≥ 0.021 → green")
	assert(_beat_result(0.548, h) == 1.0,  "High: pos=0.548 dist=0.048 < 0.049 → green")
	assert(_beat_result(0.549, h) == 0.75, "High: pos=0.549 dist=0.049 ≥ 0.049 → orange")
	assert(_beat_result(0.569, h) == 0.75, "High: pos=0.569 dist=0.069 < 0.07 → orange")
	assert(_beat_result(0.580, h) == 0.25, "High: pos=0.580 dist=0.080 > 0.07 → red")
	assert(_beat_result(1.00,  h) == 0.25, "High: pos=1.0 → red")

