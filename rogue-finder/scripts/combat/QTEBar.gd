class_name QTEBar
extends CanvasLayer

## --- QTE Bar ---
## Sliding-bar quick time event (Gears of War reload style).
## A cursor slides left→right across a bar; player presses Space or left-clicks to register.
## Accuracy is calculated from how close the cursor is to the center of the sweet spot.
## The action always fires — accuracy only affects how effectively it resolves.

## --- Signal ---
## Emitted when the QTE completes (via player input or timeout).
signal qte_resolved(accuracy: float)

## --- Bar Layout Constants ---
const BAR_WIDTH: float   = 480.0
const BAR_HEIGHT: float  = 48.0
const CURSOR_WIDTH: float = 10.0
## Sweet spot: middle 30% of bar (0.35 → 0.65)
const SWEET_SPOT_START: float = 0.35
const SWEET_SPOT_END: float   = 0.65
## Seconds for cursor to cross the full bar
const CURSOR_DURATION: float = 1.8

## --- State ---
var _cursor_pos: float = 0.0   # 0.0 = far left, 1.0 = far right
var _tween: Tween = null
var _resolved: bool = false    # Guard against double-resolve on same QTE

## --- Node References ---
@onready var overlay: ColorRect       = $Overlay
@onready var bar_bg: ColorRect        = $BarBG
@onready var sweet_spot_rect: ColorRect = $BarBG/SweetSpot
@onready var cursor_rect: ColorRect   = $BarBG/Cursor
@onready var instruction_label: Label = $InstructionLabel
@onready var result_label: Label      = $ResultLabel

func _ready() -> void:
	visible = false

## --- Public API ---

## Starts the QTE animation. CombatManager calls this when the player uses an Active Action.
func start_qte() -> void:
	_resolved = false
	_cursor_pos = 0.0
	result_label.visible = false
	instruction_label.text = "Press SPACE or click to strike!"
	visible = true
	_animate_cursor()

## --- Animation ---

func _animate_cursor() -> void:
	_tween = create_tween()
	# tween_method fires every frame, passing the interpolated value to _set_cursor
	_tween.tween_method(_set_cursor, 0.0, 1.0, CURSOR_DURATION)
	_tween.tween_callback(_on_cursor_expired)

func _set_cursor(value: float) -> void:
	_cursor_pos = value
	# Cursor position within bar_bg (0 → BAR_WIDTH - CURSOR_WIDTH)
	cursor_rect.position.x = value * (BAR_WIDTH - CURSOR_WIDTH)

## --- Input ---

func _input(event: InputEvent) -> void:
	if not visible or _resolved:
		return
	var pressed: bool = false
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_SPACE:
		pressed = true
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = true
	if pressed:
		# Consume input so the grid doesn't also receive this click
		get_viewport().set_input_as_handled()
		_register_hit()

## --- Resolution ---

func _register_hit() -> void:
	_resolved = true
	if _tween:
		_tween.kill()
	var accuracy: float = _calculate_accuracy(_cursor_pos)
	await _show_result_and_close(accuracy)

func _on_cursor_expired() -> void:
	if not _resolved:
		_resolved = true
		# Cursor ran out — minimum effectiveness, but action still fires
		await _show_result_and_close(0.1)

## Shows feedback text briefly, then hides the overlay and emits the result.
func _show_result_and_close(accuracy: float) -> void:
	_show_feedback(accuracy)
	await get_tree().create_timer(0.85).timeout
	visible = false
	qte_resolved.emit(accuracy)

## Accuracy: 1.0 at sweet spot center, 0.5 at sweet spot edges, 0.2 outside.
func _calculate_accuracy(pos: float) -> float:
	if pos < SWEET_SPOT_START or pos > SWEET_SPOT_END:
		return 0.2  # Missed the sweet spot — low but non-zero (action always fires)
	var center: float = (SWEET_SPOT_START + SWEET_SPOT_END) / 2.0
	var half_width: float = (SWEET_SPOT_END - SWEET_SPOT_START) / 2.0
	# Linear falloff from 1.0 at center to 0.5 at edge
	return lerp(1.0, 0.5, abs(pos - center) / half_width)

func _show_feedback(accuracy: float) -> void:
	result_label.visible = true
	if accuracy >= 0.9:
		result_label.text    = "PERFECT!"
		result_label.modulate = Color.GREEN
	elif accuracy >= 0.65:
		result_label.text    = "GOOD HIT!"
		result_label.modulate = Color.YELLOW
	elif accuracy >= 0.35:
		result_label.text    = "GLANCING..."
		result_label.modulate = Color.ORANGE
	else:
		result_label.text    = "MISS!"
		result_label.modulate = Color.RED
