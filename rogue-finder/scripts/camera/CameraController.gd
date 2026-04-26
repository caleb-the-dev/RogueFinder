class_name CameraController
extends Node3D

## --- Camera Controller ---
## DOS2-style isometric orbiting camera.
## Parent node sits at the grid center; Camera3D child orbits around it.
## Q / E rotate in 45-degree steps. Scroll wheel zooms in/out.
## trigger_shake() fires a brief positional shake on hit.

const DEFAULT_DISTANCE: float = 16.0
const MIN_DISTANCE: float     = 8.0
const MAX_DISTANCE: float     = 28.0
const DEFAULT_ELEVATION: float = 52.0  # degrees above the horizon
const DEFAULT_YAW: float       = 225.0 # SW isometric default
const ROTATE_STEP: float       = 45.0  # degrees per Q / E press
const ZOOM_STEP: float         = 2.0
const SHAKE_DURATION: float    = 0.22
const SHAKE_MAGNITUDE: float   = 0.18

var _yaw: float        = DEFAULT_YAW
var _distance: float   = DEFAULT_DISTANCE
var _shake_timer: float    = 0.0
var _shake_offset: Vector3 = Vector3.ZERO
var _camera: Camera3D      = null

## Pivot tracking for QTE focus / restore
var _home_position: Vector3 = Vector3.ZERO
var _pivot_tween: Tween     = null

func _ready() -> void:
	_home_position = position   ## captured after CM3D sets position before add_child
	_camera = Camera3D.new()
	_camera.name = "Camera3D"
	add_child(_camera)
	_apply_transform()

## --- Public API ---

func trigger_shake() -> void:
	_shake_timer = SHAKE_DURATION

## Smoothly tween the orbit pivot to world_pos. Returns the Tween so callers can await it.
## Kills any in-progress pivot tween first so tweens never stack.
func focus_on(world_pos: Vector3) -> Tween:
	if _pivot_tween and _pivot_tween.is_running():
		_pivot_tween.kill()
	_pivot_tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_pivot_tween.tween_method(_set_pivot, position, world_pos, 0.50)
	return _pivot_tween

## Smoothly tween the orbit pivot back to the home position (grid center).
## Fire-and-forget — callers do not need to await this.
func restore() -> void:
	if _pivot_tween and _pivot_tween.is_running():
		_pivot_tween.kill()
	_pivot_tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_pivot_tween.tween_method(_set_pivot, position, _home_position, 0.45)

## Tween method: sets the pivot position and re-applies the camera transform each step.
func _set_pivot(pos: Vector3) -> void:
	position = pos
	_apply_transform()

## Returns horizontal forward vector (XZ plane only) for 8-dir sprite calculations.
func get_forward() -> Vector3:
	var yaw_rad: float = deg_to_rad(_yaw)
	return Vector3(sin(yaw_rad), 0.0, cos(yaw_rad)).normalized()

func get_camera() -> Camera3D:
	return _camera

## --- Input ---

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q:
			_yaw -= ROTATE_STEP
			_apply_transform()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_E:
			_yaw += ROTATE_STEP
			_apply_transform()
			get_viewport().set_input_as_handled()

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = clampf(_distance - ZOOM_STEP, MIN_DISTANCE, MAX_DISTANCE)
			_apply_transform()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = clampf(_distance + ZOOM_STEP, MIN_DISTANCE, MAX_DISTANCE)
			_apply_transform()
			get_viewport().set_input_as_handled()

## --- Per-frame shake update ---

func _process(delta: float) -> void:
	if _shake_timer > 0.0:
		_shake_timer -= delta
		var s: float = SHAKE_MAGNITUDE * clampf(_shake_timer / SHAKE_DURATION, 0.0, 1.0)
		_shake_offset = Vector3(
			randf_range(-s, s),
			randf_range(-s * 0.5, s * 0.5),
			randf_range(-s, s)
		)
		_apply_transform()
	elif not _shake_offset.is_zero_approx():
		_shake_offset = Vector3.ZERO
		_apply_transform()

## --- Transform ---

func _apply_transform() -> void:
	var yaw_rad: float  = deg_to_rad(_yaw)
	var elev_rad: float = deg_to_rad(DEFAULT_ELEVATION)
	var horiz: float    = _distance * cos(elev_rad)
	# Position the Camera3D in local space relative to this rig node
	_camera.position = Vector3(
		horiz * sin(yaw_rad),
		_distance * sin(elev_rad),
		horiz * cos(yaw_rad)
	) + _shake_offset
	# Look at this node's world position (the grid center pivot)
	_camera.look_at(global_position, Vector3.UP)
