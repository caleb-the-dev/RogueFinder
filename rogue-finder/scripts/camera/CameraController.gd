class_name CameraController
extends Node3D

## --- Camera Controller ---
## DOS2-style isometric orbiting camera.
## Parent node sits at the grid center; Camera3D child orbits around it.
## Q / E adjust elevation (pitch) smoothly. Right-click drag rotates horizontally. Scroll zooms.
## WASD / arrow keys pan the pivot in yaw-relative XZ space.
## trigger_shake() fires a brief positional shake on hit.

const DEFAULT_DISTANCE: float  = 16.0
const MIN_DISTANCE: float      = 8.0
const MAX_DISTANCE: float      = 28.0
const QTE_DISTANCE: float      = 10.0  # zoom-in distance during QTE focus
const DEFAULT_ELEVATION: float = 52.0  # degrees above the horizon
const MIN_ELEVATION: float     = 15.0  # lowest allowed pitch (near-horizon)
const MAX_ELEVATION: float     = 80.0  # highest allowed pitch (near-top-down)
const DEFAULT_YAW: float       = 225.0 # SW isometric default
const ELEVATION_SPEED: float   = 45.0  # degrees per second while Q / E held
const ZOOM_STEP: float         = 2.0
const DRAG_SENSITIVITY: float  = 0.2   # yaw degrees per pixel of horizontal drag
const SHAKE_DURATION: float    = 0.22
const SHAKE_MAGNITUDE: float   = 0.18
const PAN_SPEED: float         = 10.0  # pivot units per second (WASD / arrow keys)
const PAN_MIN: float           = -5.0  # world-space clamp on X and Z
const PAN_MAX: float           = 25.0

var _yaw: float        = DEFAULT_YAW
var _elevation: float  = DEFAULT_ELEVATION
var _distance: float   = DEFAULT_DISTANCE
var _dragging: bool    = false
var _shake_timer: float    = 0.0
var _shake_offset: Vector3 = Vector3.ZERO
var _camera: Camera3D      = null

## Pivot tracking for QTE focus / restore
var _home_position: Vector3    = Vector3.ZERO
var _pivot_tween: Tween        = null
var _pre_qte_distance: float   = DEFAULT_DISTANCE  # saved so restore() zooms back out

func _ready() -> void:
	_home_position = position   ## captured after CM3D sets position before add_child
	_camera = Camera3D.new()
	_camera.name = "Camera3D"
	add_child(_camera)
	_apply_transform()

## --- Public API ---

func trigger_shake() -> void:
	_shake_timer = SHAKE_DURATION

## Smoothly tween the orbit pivot to world_pos and zoom in to QTE_DISTANCE.
## Returns the Tween so callers can await it. Kills any in-progress pivot tween first.
func focus_on(world_pos: Vector3) -> Tween:
	if _pivot_tween and _pivot_tween.is_running():
		_pivot_tween.kill()
	_pre_qte_distance = _distance
	_pivot_tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE).set_parallel(true)
	_pivot_tween.tween_method(_set_pivot, position, world_pos, 0.50)
	_pivot_tween.tween_method(_set_distance, _distance, QTE_DISTANCE, 0.50)
	return _pivot_tween

## Smoothly tween the orbit pivot back to grid center and zoom out to pre-QTE distance.
## Fire-and-forget — callers do not need to await this.
func restore() -> void:
	if _pivot_tween and _pivot_tween.is_running():
		_pivot_tween.kill()
	_pivot_tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE).set_parallel(true)
	_pivot_tween.tween_method(_set_pivot, position, _home_position, 0.45)
	_pivot_tween.tween_method(_set_distance, _distance, _pre_qte_distance, 0.45)

## Tween method: sets the pivot position and re-applies the camera transform each step.
func _set_pivot(pos: Vector3) -> void:
	position = pos
	_apply_transform()

## Tween method: sets the orbit distance and re-applies the camera transform each step.
func _set_distance(d: float) -> void:
	_distance = d
	_apply_transform()

## Returns horizontal forward vector (XZ plane only) for 8-dir sprite calculations.
func get_forward() -> Vector3:
	var yaw_rad: float = deg_to_rad(_yaw)
	return Vector3(sin(yaw_rad), 0.0, cos(yaw_rad)).normalized()

func get_camera() -> Camera3D:
	return _camera

## --- Input ---

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = event.pressed
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if _dragging else Input.MOUSE_MODE_VISIBLE)
			get_viewport().set_input_as_handled()
		elif event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_distance = clampf(_distance - ZOOM_STEP, MIN_DISTANCE, MAX_DISTANCE)
				_apply_transform()
				get_viewport().set_input_as_handled()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_distance = clampf(_distance + ZOOM_STEP, MIN_DISTANCE, MAX_DISTANCE)
				_apply_transform()
				get_viewport().set_input_as_handled()

	if event is InputEventMouseMotion and _dragging:
		_yaw += event.relative.x * DRAG_SENSITIVITY
		_apply_transform()
		get_viewport().set_input_as_handled()

## --- Per-frame update: shake + elevation + WASD pan ---

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

	_process_elevation(delta)

	# Skip panning while a QTE tween is animating to avoid fighting it
	if _pivot_tween == null or not _pivot_tween.is_running():
		_process_pan(delta)

## Polls Q / E and smoothly adjusts camera elevation (pitch) each frame.
func _process_elevation(delta: float) -> void:
	var changed: bool = false
	if Input.is_key_pressed(KEY_Q):
		_elevation = clampf(_elevation + ELEVATION_SPEED * delta, MIN_ELEVATION, MAX_ELEVATION)
		changed = true
	if Input.is_key_pressed(KEY_E):
		_elevation = clampf(_elevation - ELEVATION_SPEED * delta, MIN_ELEVATION, MAX_ELEVATION)
		changed = true
	if changed:
		_apply_transform()

## Polls WASD / arrow keys and slides the orbit pivot in yaw-relative XZ space.
## W/S are aligned to the direction opposite the camera's position vector (NE at default yaw).
func _process_pan(delta: float) -> void:
	var move: Vector2 = Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move.x += 1.0

	if move.is_zero_approx():
		return

	var yaw_rad: float   = deg_to_rad(_yaw)
	var forward: Vector3 = Vector3(sin(yaw_rad), 0.0, cos(yaw_rad))
	var right: Vector3   = Vector3(cos(yaw_rad), 0.0, -sin(yaw_rad))

	var pan_delta: Vector3 = (forward * move.y + right * move.x) * PAN_SPEED * delta
	var new_pos: Vector3 = position + pan_delta
	new_pos.x = clampf(new_pos.x, PAN_MIN, PAN_MAX)
	new_pos.z = clampf(new_pos.z, PAN_MIN, PAN_MAX)
	position = new_pos
	_apply_transform()

## --- Transform ---

func _apply_transform() -> void:
	var yaw_rad: float  = deg_to_rad(_yaw)
	var elev_rad: float = deg_to_rad(_elevation)
	var horiz: float    = _distance * cos(elev_rad)
	# Position the Camera3D in local space relative to this rig node
	_camera.position = Vector3(
		horiz * sin(yaw_rad),
		_distance * sin(elev_rad),
		horiz * cos(yaw_rad)
	) + _shake_offset
	# Look at this node's world position (the grid center pivot)
	_camera.look_at(global_position, Vector3.UP)
