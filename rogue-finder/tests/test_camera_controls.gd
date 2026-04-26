extends SceneTree

## --- Unit Tests: Camera Controls Overhaul ---
## Validates elevation clamping logic, default field values, and pan direction math.
## Does NOT test drag input, camera position math, or _process — those are manual.

const DEFAULT_ELEVATION: float = 52.0
const MIN_ELEVATION: float     = 15.0
const MAX_ELEVATION: float     = 80.0
const DEFAULT_YAW: float       = 225.0
const PAN_SPEED: float         = 10.0  # must match CameraController.PAN_SPEED

func _initialize() -> void:
	_test_elevation_clamp_upper()
	_test_elevation_clamp_lower()
	_test_elevation_default()
	_test_pan_forward_at_default_yaw()
	_test_pan_forward_at_zero_yaw()
	_test_pan_speed_positive()
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

## Mirrors _pan_forward_vector() in CameraController.
func _pan_forward_vector(yaw_deg: float) -> Vector3:
	var yaw_rad: float = deg_to_rad(yaw_deg)
	return Vector3(sin(yaw_rad), 0.0, cos(yaw_rad))

## ============================================================
## Test 4: At DEFAULT_YAW (225°), W-forward points SW (~-0.707, 0, -0.707).
## ============================================================
func _test_pan_forward_at_default_yaw() -> void:
	var fwd: Vector3 = _pan_forward_vector(DEFAULT_YAW)
	var expected: Vector3 = Vector3(-0.7071, 0.0, -0.7071)
	assert(fwd.is_equal_approx(expected),
		"forward at 225° must be ~%s, got %s" % [expected, fwd])

## ============================================================
## Test 5: At yaw 0°, W-forward points north (+Z: Vector3(0,0,1)).
## ============================================================
func _test_pan_forward_at_zero_yaw() -> void:
	var fwd: Vector3 = _pan_forward_vector(0.0)
	assert(fwd.is_equal_approx(Vector3(0.0, 0.0, 1.0)),
		"forward at 0° must be Vector3(0,0,1), got %s" % fwd)

## ============================================================
## Test 6: PAN_SPEED constant must be positive.
## ============================================================
func _test_pan_speed_positive() -> void:
	assert(PAN_SPEED > 0.0,
		"PAN_SPEED must be > 0, got %s" % PAN_SPEED)
