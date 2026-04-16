extends SceneTree

## --- Unit Tests: Power Meter QTE (TRAVEL) ---
## Tests pure logic mirrored from QTEBar and CombatManager3D.
## No scene nodes are instantiated.

func _initialize() -> void:
	_test_pm_difficulty_tiers()
	_test_pm_result_low_tier()
	_test_pm_result_medium_tier()
	_test_pm_result_high_tier()
	_test_travel_destination_entered()
	_test_travel_destination_skipped()
	print("All QTE travel tests PASSED.")
	quit()

## --- Mirrors QTEBar._set_pm_difficulty() → returns [zone_center, zone_half] ---
func _pm_difficulty(energy_cost: int) -> Array[float]:
	var result: Array[float] = []
	if energy_cost <= 2:
		result.append(0.65)
		result.append(0.18)
	elif energy_cost <= 4:
		result.append(0.72)
		result.append(0.12)
	else:
		result.append(0.78)
		result.append(0.07)
	return result

## --- Mirrors QTEBar._get_pm_result() ---
## Same 4-zone thresholds as the slider, measured from zone_center.
func _pm_result(fill: float, zone_center: float, zone_half: float) -> float:
	var dist: float = abs(fill - zone_center)
	if dist > zone_half:
		return 0.25
	if dist >= zone_half * 0.70:
		return 0.75
	if dist >= zone_half * 0.30:
		return 1.0
	return 1.25

## --- Mirrors CombatManager3D._on_qte_resolved() TRAVEL guard ---
## Returns true when the unit should enter TRAVEL_DESTINATION mode.
func _travel_destination_entered(multiplier: float) -> bool:
	return multiplier > 0.25

## ============================================================
## Difficulty tier — zone centre and half-width
## ============================================================

func _test_pm_difficulty_tiers() -> void:
	var low:    Array[float] = _pm_difficulty(1)
	var low2:   Array[float] = _pm_difficulty(2)
	var med:    Array[float] = _pm_difficulty(3)
	var med2:   Array[float] = _pm_difficulty(4)
	var high:   Array[float] = _pm_difficulty(5)
	var high2:  Array[float] = _pm_difficulty(6)

	assert(low[0]   == 0.65, "energy 1 → zone_center 0.65")
	assert(low[1]   == 0.18, "energy 1 → zone_half 0.18")
	assert(low2[0]  == 0.65, "energy 2 → zone_center 0.65")
	assert(low2[1]  == 0.18, "energy 2 → zone_half 0.18")

	assert(med[0]   == 0.72, "energy 3 → zone_center 0.72")
	assert(med[1]   == 0.12, "energy 3 → zone_half 0.12")
	assert(med2[0]  == 0.72, "energy 4 → zone_center 0.72")
	assert(med2[1]  == 0.12, "energy 4 → zone_half 0.12")

	assert(high[0]  == 0.78, "energy 5 → zone_center 0.78")
	assert(high[1]  == 0.07, "energy 5 → zone_half 0.07")
	assert(high2[0] == 0.78, "energy 6 → zone_center 0.78")
	assert(high2[1] == 0.07, "energy 6 → zone_half 0.07")

## ============================================================
## Power meter release → multiplier — Low tier
##   zone_center = 0.65, zone_half = 0.18
##   gold boundary:   zone_half × 0.30 = 0.054  → fill in (0.596, 0.704)
##   green boundary:  zone_half × 0.70 = 0.126  → fill in (0.524, 0.776)
##   orange boundary: zone_half         = 0.18   → fill in (0.470, 0.830]
##   red: outside [0.470, 0.830]
## ============================================================

func _test_pm_result_low_tier() -> void:
	var zc: float = 0.65
	var zh: float = 0.18

	# Gold zone
	assert(_pm_result(0.65,  zc, zh) == 1.25, "Low: fill=zone_center → gold")
	assert(_pm_result(0.703, zc, zh) == 1.25, "Low: dist=0.053 < 0.054 → gold")
	assert(_pm_result(0.597, zc, zh) == 1.25, "Low: dist=0.053 below centre → gold")

	# Gold/green boundary (dist == zone_half × 0.30 = 0.054 → green)
	assert(_pm_result(0.704, zc, zh) == 1.0,  "Low: dist=0.054 ≥ 0.054 → green")
	assert(_pm_result(0.596, zc, zh) == 1.0,  "Low: dist=0.054 below centre → green")

	# Green zone interior
	assert(_pm_result(0.720, zc, zh) == 1.0,  "Low: dist=0.07 in green band → green")

	# Green/orange boundary (dist == zone_half × 0.70 = 0.126 → orange)
	assert(_pm_result(0.776, zc, zh) == 0.75, "Low: dist=0.126 ≥ 0.126 → orange")
	assert(_pm_result(0.524, zc, zh) == 0.75, "Low: dist=0.126 below centre → orange")

	# Green/orange just inside (dist < 0.126 → green)
	assert(_pm_result(0.775, zc, zh) == 1.0,  "Low: dist=0.125 < 0.126 → green")

	# Orange zone interior
	assert(_pm_result(0.800, zc, zh) == 0.75, "Low: dist=0.15 in orange band → orange")

	# Orange/red boundary: dist == zone_half (0.18) is NOT > zone_half → still orange
	assert(_pm_result(0.830, zc, zh) == 0.75, "Low: dist=0.18 not > 0.18 → orange")

	# Red zone (dist > zone_half)
	assert(_pm_result(0.831, zc, zh) == 0.25, "Low: dist=0.181 > 0.18 → red")
	assert(_pm_result(1.000, zc, zh) == 0.25, "Low: fill=1.0 → red")
	assert(_pm_result(0.000, zc, zh) == 0.25, "Low: fill=0.0 → red")

## ============================================================
## Power meter release → multiplier — Medium tier
##   zone_center = 0.72, zone_half = 0.12
##   gold boundary:   0.12 × 0.30 = 0.036
##   green boundary:  0.12 × 0.70 = 0.084
##   orange boundary: 0.12
## ============================================================

func _test_pm_result_medium_tier() -> void:
	var zc: float = 0.72
	var zh: float = 0.12

	# Gold
	assert(_pm_result(0.72,  zc, zh) == 1.25, "Med: fill=zone_center → gold")
	assert(_pm_result(0.755, zc, zh) == 1.25, "Med: dist=0.035 < 0.036 → gold")

	# Gold/green boundary
	assert(_pm_result(0.756, zc, zh) == 1.0,  "Med: dist=0.036 ≥ 0.036 → green")

	# Green zone
	assert(_pm_result(0.783, zc, zh) == 1.0,  "Med: dist=0.063 in green → green")

	# Green/orange boundary
	assert(_pm_result(0.804, zc, zh) == 0.75, "Med: dist=0.084 ≥ 0.084 → orange")
	assert(_pm_result(0.803, zc, zh) == 1.0,  "Med: dist=0.083 < 0.084 → green")

	# Orange/red boundary
	assert(_pm_result(0.840, zc, zh) == 0.75, "Med: dist=0.12 not > 0.12 → orange")
	assert(_pm_result(0.841, zc, zh) == 0.25, "Med: dist=0.121 > 0.12 → red")
	assert(_pm_result(0.600, zc, zh) == 0.25, "Med: fill=0.60 far below → red")

## ============================================================
## Power meter release → multiplier — High tier
##   zone_center = 0.78, zone_half = 0.07
##   gold boundary:   0.07 × 0.30 = 0.021
##   green boundary:  0.07 × 0.70 = 0.049
##   orange boundary: 0.07
## ============================================================

func _test_pm_result_high_tier() -> void:
	var zc: float = 0.78
	var zh: float = 0.07

	# Gold
	assert(_pm_result(0.78,  zc, zh) == 1.25, "High: fill=zone_center → gold")
	assert(_pm_result(0.800, zc, zh) == 1.25, "High: dist=0.020 < 0.021 → gold")

	# Gold/green boundary
	assert(_pm_result(0.801, zc, zh) == 1.0,  "High: dist=0.021 ≥ 0.021 → green")

	# Green zone
	assert(_pm_result(0.818, zc, zh) == 1.0,  "High: dist=0.038 in green → green")

	# Green/orange boundary
	assert(_pm_result(0.829, zc, zh) == 0.75, "High: dist=0.049 ≥ 0.049 → orange")
	assert(_pm_result(0.828, zc, zh) == 1.0,  "High: dist=0.048 < 0.049 → green")

	# Orange/red boundary
	assert(_pm_result(0.850, zc, zh) == 0.75, "High: dist=0.07 not > 0.07 → orange")
	assert(_pm_result(0.851, zc, zh) == 0.25, "High: dist=0.071 > 0.07 → red")
	assert(_pm_result(0.000, zc, zh) == 0.25, "High: fill=0.0 far below → red")
	assert(_pm_result(1.000, zc, zh) == 0.25, "High: fill=1.0 far above → red")

## ============================================================
## TRAVEL_DESTINATION guard — entered when multiplier > 0.25
## ============================================================

func _test_travel_destination_entered() -> void:
	assert(_travel_destination_entered(1.25) == true,
		"multiplier=1.25 (gold)   → TRAVEL_DESTINATION entered")
	assert(_travel_destination_entered(1.0)  == true,
		"multiplier=1.0  (green)  → TRAVEL_DESTINATION entered")
	assert(_travel_destination_entered(0.75) == true,
		"multiplier=0.75 (orange) → TRAVEL_DESTINATION entered")

## ============================================================
## TRAVEL_DESTINATION guard — skipped when multiplier == 0.25
## ============================================================

func _test_travel_destination_skipped() -> void:
	assert(_travel_destination_entered(0.25) == false,
		"multiplier=0.25 (red/miss) → TRAVEL_DESTINATION skipped")
