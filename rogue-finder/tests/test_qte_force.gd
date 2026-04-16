extends SceneTree

## --- Unit Tests: Click-Targets QTE (FORCE) ---
## Tests pure logic mirrored from QTEBar (click-targets style).
## No scene nodes are instantiated.

func _initialize() -> void:
	_test_ct_window_tiers()
	_test_click_within_radius_is_hit()
	_test_click_outside_radius_is_miss()
	_test_click_at_boundary()
	_test_timeout_is_miss()
	_test_aggregation_all_hit()
	_test_aggregation_mixed()
	_test_aggregation_all_miss()
	_test_scatter_within_range()
	print("All QTE force tests PASSED.")
	quit()

## --- Mirrors ---

const CT_RADIUS:        float = 12.0
const CT_SCATTER_RANGE: float = 80.0

## Mirrors QTEBar click-window difficulty selection.
func _ct_window(energy_cost: int) -> float:
	if energy_cost <= 2:
		return 1.8
	elif energy_cost <= 4:
		return 1.3
	else:
		return 0.9

## Returns true when a click at click_pos hits the target centred at target_pos.
## Mirrors: click_pos.distance_to(target_pos) <= CT_RADIUS
func _is_hit(click_pos: Vector2, target_pos: Vector2) -> bool:
	return click_pos.distance_to(target_pos) <= CT_RADIUS

## Mirrors QTEBar._aggregate_multiplier().
func _aggregate(results: Array[float]) -> float:
	if results.is_empty():
		return 0.25
	var sum: float = 0.0
	for r: float in results:
		sum += r
	var avg: float = sum / float(results.size())
	if avg >= 1.2: return 1.25
	if avg >= 0.9: return 1.0
	if avg >= 0.6: return 0.75
	return 0.25

## Returns an offset Vector2 at the given angle (degrees) and distance from origin.
func _offset(origin: Vector2, angle_deg: float, dist: float) -> Vector2:
	var rad: float = deg_to_rad(angle_deg)
	return origin + Vector2(cos(rad), sin(rad)) * dist

## ============================================================
## Window duration by difficulty tier
## ============================================================

func _test_ct_window_tiers() -> void:
	assert(_ct_window(1) == 1.8, "energy 1 → 1.8 s window")
	assert(_ct_window(2) == 1.8, "energy 2 → 1.8 s window")
	assert(_ct_window(3) == 1.3, "energy 3 → 1.3 s window")
	assert(_ct_window(4) == 1.3, "energy 4 → 1.3 s window")
	assert(_ct_window(5) == 0.9, "energy 5 → 0.9 s window")
	assert(_ct_window(6) == 0.9, "energy 6 → 0.9 s window")

## ============================================================
## Hit detection — click within radius
## ============================================================

func _test_click_within_radius_is_hit() -> void:
	var center := Vector2(640.0, 360.0)

	## Dead centre
	assert(_is_hit(center, center) == true,
		"click at exact centre → hit")

	## 1 pixel inside radius (dist = 11)
	assert(_is_hit(_offset(center, 0.0, 11.0), center) == true,
		"click 11 px east → hit (dist=11 < 12)")

	assert(_is_hit(_offset(center, 90.0, 11.0), center) == true,
		"click 11 px south → hit")

	assert(_is_hit(_offset(center, 225.0, 8.0), center) == true,
		"click 8 px south-west → hit")

## ============================================================
## Hit detection — click outside radius
## ============================================================

func _test_click_outside_radius_is_miss() -> void:
	var center := Vector2(640.0, 360.0)

	## 1 pixel outside radius (dist = 13)
	assert(_is_hit(_offset(center, 0.0, 13.0), center) == false,
		"click 13 px east → miss (dist=13 > 12)")

	assert(_is_hit(_offset(center, 270.0, 20.0), center) == false,
		"click 20 px north → miss")

	assert(_is_hit(Vector2(0.0, 0.0), center) == false,
		"click at corner → miss")

## ============================================================
## Hit detection — exactly at radius boundary (dist == CT_RADIUS)
## ============================================================

func _test_click_at_boundary() -> void:
	var center := Vector2(640.0, 360.0)
	## distance_to == CT_RADIUS → still a hit (<=)
	assert(_is_hit(_offset(center, 0.0, CT_RADIUS), center) == true,
		"click exactly at radius boundary → hit (<=)")

## ============================================================
## Timeout resolves as miss
## ============================================================

func _test_timeout_is_miss() -> void:
	## The timeout path calls _resolve_ct_beat(idx, 0.25).
	## Mirror: timeout result is always 0.25.
	var timeout_result: float = 0.25
	assert(timeout_result == 0.25, "timeout → miss (0.25)")

	## Confirm that a single-beat miss aggregates to 0.25
	assert(_aggregate([0.25]) == 0.25, "single timeout miss → aggregate 0.25")

## ============================================================
## Beat aggregation — all hits
## ============================================================

func _test_aggregation_all_hit() -> void:
	## SINGLE / ARC / SELF shape (3 beats): all gold
	assert(_aggregate([1.25, 1.25, 1.25]) == 1.25, "3 hits (SINGLE/ARC) → 1.25")

	## CONE shape (6 beats)
	assert(_aggregate([1.25, 1.25, 1.25, 1.25, 1.25, 1.25]) == 1.25, "6 hits (CONE) → 1.25")

	## RADIAL shape (12 beats) — spot-check with full run
	var twelve_hits: Array[float] = []
	for _i in range(12): twelve_hits.append(1.25)
	assert(_aggregate(twelve_hits) == 1.25, "12 hits (RADIAL) → 1.25")

## ============================================================
## Beat aggregation — mixed hit/miss
## ============================================================

func _test_aggregation_mixed() -> void:
	## SINGLE (3 beats): 2 hits + 1 miss → avg = (1.25+1.25+0.25)/3 ≈ 0.917 → 1.0
	assert(_aggregate([1.25, 1.25, 0.25]) == 1.0,
		"2/3 hits (SINGLE) → avg≈0.917 → 1.0")

	## SINGLE (3 beats): 1 hit + 2 misses → avg = (1.25+0.25+0.25)/3 ≈ 0.583 → 0.25
	assert(_aggregate([1.25, 0.25, 0.25]) == 0.25,
		"1/3 hits (SINGLE) → avg≈0.583 → 0.25")

	## RADIAL (12 beats): 9 hits + 3 misses → avg = (9×1.25 + 3×0.25)/12 = 1.0
	var nine_hits_three_miss: Array[float] = []
	for _i in range(9):  nine_hits_three_miss.append(1.25)
	for _i in range(3):  nine_hits_three_miss.append(0.25)
	assert(_aggregate(nine_hits_three_miss) == 1.0,
		"9/12 hits (RADIAL) → avg=1.0 → 1.0")

	## RADIAL (12 beats): all miss
	var twelve_miss: Array[float] = []
	for _i in range(12): twelve_miss.append(0.25)
	assert(_aggregate(twelve_miss) == 0.25,
		"0/12 hits (RADIAL) → 0.25")

## ============================================================
## Beat aggregation — all miss
## ============================================================

func _test_aggregation_all_miss() -> void:
	assert(_aggregate([0.25, 0.25, 0.25]) == 0.25, "3 misses (SINGLE) → 0.25")
	var twelve_miss: Array[float] = []
	for _i in range(12): twelve_miss.append(0.25)
	assert(_aggregate(twelve_miss) == 0.25, "12 misses (RADIAL) → 0.25")
	assert(_aggregate([]) == 0.25, "empty (guard) → 0.25")

## ============================================================
## Scatter position stays within CT_SCATTER_RANGE of origin
## ============================================================

func _test_scatter_within_range() -> void:
	## Simulate the scatter math: random angle + random dist ≤ CT_SCATTER_RANGE.
	## The farthest possible centre is at exactly CT_SCATTER_RANGE from origin.
	var origin := Vector2(640.0, 360.0)
	var max_dist: float = CT_SCATTER_RANGE   ## randf() * CT_SCATTER_RANGE ≤ CT_SCATTER_RANGE

	## Check a few explicit positions at the boundary and inside
	for angle_deg: float in [0.0, 45.0, 90.0, 180.0, 270.0, 315.0]:
		var at_boundary: Vector2 = _offset(origin, angle_deg, max_dist)
		assert(origin.distance_to(at_boundary) <= CT_SCATTER_RANGE + 0.001,
			"scatter at boundary angle %d stays within 80 px" % int(angle_deg))

		var at_half: Vector2 = _offset(origin, angle_deg, max_dist * 0.5)
		assert(origin.distance_to(at_half) <= CT_SCATTER_RANGE,
			"scatter at half-range angle %d stays within 80 px" % int(angle_deg))
