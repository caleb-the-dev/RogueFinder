class_name RecruitBar
extends CanvasLayer

## --- RecruitBar ---
## Hold-and-release vertical QTE for the Recruit combat action.
## Player holds SPACE (or LMB) to push the fill faster; releases inside the gold
## window for a better result. Layer 11 — between QTEBar (10) and CombatActionPanel (12).
##
## API: start_recruit_qte(base_chance, target) → await recruit_resolved(result)
## Result buckets: 1.25 / 1.0 / 0.75 / 0.25 (mirrored from QTEBar tiers)

signal recruit_resolved(result: float)

const BAR_WIDTH:       float = 40.0
const BAR_HEIGHT:      float = 220.0
const WINDOW_CENTER:   float = 0.65   # success zone centre, measured from bottom [0=bottom,1=top]
const BASE_FILL_SPEED: float = 0.15   # bar units per second without holding
const HOLD_FILL_SPEED: float = 0.45   # bar units per second while SPACE is held

var _target:      Node3D  = null
var _fill_pos:    float   = 0.0     # 0 = empty (bottom), 1 = full (top)
var _window_half: float   = 0.08   # half-height of gold window, updated per call
var _resolved:    bool    = false

## --- Node refs — built in _build_ui() ---

var _bar_bg:            ColorRect = null
var _fill_rect:         ColorRect = null
var _window_rect:       ColorRect = null
var _instruction_label: Label     = null
var _result_label:      Label     = null

func _ready() -> void:
	layer = 11
	_build_ui()
	visible = false

## --- UI Construction ---

func _build_ui() -> void:
	_instruction_label = Label.new()
	_instruction_label.add_theme_font_size_override("font_size", 13)
	_instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instruction_label.size = Vector2(120.0, 24.0)
	add_child(_instruction_label)

	_bar_bg       = ColorRect.new()
	_bar_bg.color = Color(0.12, 0.12, 0.18)
	_bar_bg.size  = Vector2(BAR_WIDTH, BAR_HEIGHT)
	add_child(_bar_bg)

	# Gold window — success zone; resized each call via _rebuild_window()
	_window_rect       = ColorRect.new()
	_window_rect.color = Color(1.0, 0.85, 0.0, 0.70)
	_bar_bg.add_child(_window_rect)

	# Fill rect — rises from bottom; colour changes on release based on result
	_fill_rect       = ColorRect.new()
	_fill_rect.color = Color(0.22, 0.55, 1.0)
	_fill_rect.size  = Vector2(BAR_WIDTH, 0.0)
	_bar_bg.add_child(_fill_rect)

	_result_label                          = Label.new()
	_result_label.add_theme_font_size_override("font_size", 22)
	_result_label.horizontal_alignment     = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.size                     = Vector2(120.0, 32.0)
	_result_label.visible                  = false
	add_child(_result_label)

## --- Public API ---

func start_recruit_qte(base_chance: float, target: Node3D) -> void:
	_target       = target
	_fill_pos     = 0.0
	_resolved     = false
	_window_half  = lerpf(0.04, 0.16, base_chance)
	_fill_rect.color         = Color(0.22, 0.55, 1.0)
	_result_label.visible    = false
	_instruction_label.text  = "Hold SPACE!"
	_rebuild_window()
	_update_fill_display()
	_reposition_to_target()
	visible = true

## --- Window & Fill Helpers ---

func _rebuild_window() -> void:
	var half_px: float       = _window_half * BAR_HEIGHT
	# Screen y = 0 is at top; window centre is WINDOW_CENTER from bottom
	var centre_y_px: float   = (1.0 - WINDOW_CENTER) * BAR_HEIGHT
	_window_rect.position    = Vector2(0.0, centre_y_px - half_px)
	_window_rect.size        = Vector2(BAR_WIDTH, half_px * 2.0)

func _update_fill_display() -> void:
	var fill_h: float      = _fill_pos * BAR_HEIGHT
	_fill_rect.size        = Vector2(BAR_WIDTH, fill_h)
	_fill_rect.position    = Vector2(0.0, BAR_HEIGHT - fill_h)

## --- World-space Positioning ---

func _reposition_to_target() -> void:
	if not is_instance_valid(_target):
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if not camera:
		return
	var screen_pos: Vector2 = camera.unproject_position(
		_target.global_position + Vector3(0, 2.5, 0))
	_bar_bg.position            = Vector2(screen_pos.x - BAR_WIDTH * 0.5, screen_pos.y - BAR_HEIGHT)
	_instruction_label.position = Vector2(screen_pos.x - 60.0, screen_pos.y - BAR_HEIGHT - 28.0)
	_result_label.position      = Vector2(screen_pos.x - 60.0, screen_pos.y + 4.0)

## --- Frame Update ---

func _process(delta: float) -> void:
	if not visible or _resolved:
		return
	# Target death guard — nearly impossible mid-recruit but ensures no orphaned bar
	if not is_instance_valid(_target) or _target.get("is_alive") == false:
		_resolved = true
		visible   = false
		_target   = null
		recruit_resolved.emit(0.25)
		return
	_reposition_to_target()

	var speed: float = HOLD_FILL_SPEED if Input.is_action_pressed("ui_accept") else BASE_FILL_SPEED
	_fill_pos = minf(_fill_pos + speed * delta, 1.0)
	_update_fill_display()

	if _fill_pos >= 1.0:
		# Bar reached the top — treat as miss
		_resolved = true
		_process_result(0.25)

## --- Input ---

func _input(event: InputEvent) -> void:
	if not visible or _resolved:
		return
	var released: bool = false
	if event is InputEventKey and not event.pressed and not event.echo \
			and event.keycode == KEY_SPACE:
		released = true
	if event is InputEventMouseButton and not event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		released = true
	if released:
		get_viewport().set_input_as_handled()
		_resolved = true
		_process_result(_get_release_result(_fill_pos))

## --- Result Calculation ---

func _get_release_result(fill_pos: float) -> float:
	var dist: float = absf(fill_pos - WINDOW_CENTER)
	if dist > _window_half * 1.10:
		return 0.25   # miss — outside window + margin
	if dist > _window_half:
		return 0.75   # close — just outside window
	if dist <= _window_half * 0.30:
		return 1.25   # perfect — centre 30% of window
	return 1.0        # great — inside window

## --- Result Presentation ---

func _process_result(result: float) -> void:
	_show_feedback(result)
	if result >= 1.0:
		_fill_rect.color = Color(0.18, 0.88, 0.30)   # green — in window
	elif result >= 0.75:
		_fill_rect.color = Color(1.0, 0.55, 0.10)    # orange — near miss
	else:
		_fill_rect.color = Color(0.95, 0.22, 0.18)   # red — miss
	await get_tree().create_timer(0.85).timeout
	visible  = false
	_target  = null
	recruit_resolved.emit(result)

func _show_feedback(result: float) -> void:
	_result_label.visible = true
	if result >= 1.25:
		_result_label.text     = "PERFECT!"
		_result_label.modulate = Color(1.0, 0.85, 0.0)
	elif result >= 1.0:
		_result_label.text     = "GREAT!"
		_result_label.modulate = Color.GREEN
	elif result >= 0.75:
		_result_label.text     = "CLOSE..."
		_result_label.modulate = Color.ORANGE
	else:
		_result_label.text     = "MISSED."
		_result_label.modulate = Color.RED
