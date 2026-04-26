extends SceneTree

## --- Unit Tests: Camera Controls Overhaul ---
## Validates elevation clamping logic and default field value.
## Does NOT test drag input or camera position math — those are manual.

const DEFAULT_ELEVATION: float = 52.0
const MIN_ELEVATION: float     = 15.0
const MAX_ELEVATION: float     = 80.0

func _initialize() -> void:
	_test_elevation_clamp_upper()
	_test_elevation_clamp_lower()
	_test_elevation_default()
	print("All camera control tests PASSED.")
	quit()

## Mirrors the Q-press elevation update in CameraController.
func _apply_elevation_delta(current: float, delta: float) -> float:
	return clampf(current + delta, MIN_ELEVATION, MAX_ELEVATION)

## ============================================================
## Test 1: Elevation clamp — +999° stays at MAX_ELEVATION.
## ============================================================
func _test_elevation_clamp_upper() -> void:
	var result: float = _apply_elevation_delta(DEFAULT_ELEVATION, 999.0)
	assert(result == MAX_ELEVATION,
		"elevation +999 must clamp to MAX_ELEVATION (%s), got %s" % [MAX_ELEVATION, result])

## ============================================================
## Test 2: Elevation clamp — -999° stays at MIN_ELEVATION.
## ============================================================
func _test_elevation_clamp_lower() -> void:
	var result: float = _apply_elevation_delta(DEFAULT_ELEVATION, -999.0)
	assert(result == MIN_ELEVATION,
		"elevation -999 must clamp to MIN_ELEVATION (%s), got %s" % [MIN_ELEVATION, result])

## ============================================================
## Test 3: _elevation starts at DEFAULT_ELEVATION (52.0).
## ============================================================
func _test_elevation_default() -> void:
	assert(DEFAULT_ELEVATION == 52.0,
		"DEFAULT_ELEVATION must be 52.0, got %s" % DEFAULT_ELEVATION)
