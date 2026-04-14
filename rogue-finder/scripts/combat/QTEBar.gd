class_name QTEBar
extends CanvasLayer

## --- QTE Bar ---
## Sliding-bar quick time event (Gears of War reload style).
## All child nodes are built in _ready() so the .tscn stays minimal.
## A cursor slides left to right; player presses Space or clicks to register.

signal qte_resolved(accuracy: float)

const BAR_WIDTH: float       = 480.0
const CURSOR_WIDTH: float    = 10.0
const SWEET_SPOT_START: float = 0.35   # 35% of bar width
const SWEET_SPOT_END: float   = 0.65   # 65% of bar width
const CURSOR_DURATION: float = 1.8     # Seconds for cursor to cross the bar

var _cursor_pos: float = 0.0
var _tween: Tween      = null
var _resolved: bool    = false

# Held as instance vars so animation and input callbacks can reach them
var _cursor: ColorRect  = null
var _instruction_label: Label = null
var _result_label: Label      = null

func _ready() -> void:
	_build_ui()
	visible = false

## --- UI Construction ---

func _build_ui() -> void:
	# Full-screen dark tint behind the bar
	var overlay := ColorRect.new()
	overlay.color    = Color(0.0, 0.0, 0.0, 0.72)
	overlay.position = Vector2.ZERO
	overlay.size     = Vector2(1280.0, 720.0)
	add_child(overlay)

	# "Press SPACE…" instruction text
	_instruction_label = Label.new()
	_instruction_label.position             = Vector2(370.0, 282.0)
	_instruction_label.size                 = Vector2(540.0, 32.0)
	_instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instruction_label.add_theme_font_size_override("font_size", 18)
	add_child(_instruction_label)

	# Gray bar background
	var bar_bg := ColorRect.new()
	bar_bg.color    = Color(0.28, 0.28, 0.30)
	bar_bg.position = Vector2(400.0, 324.0)
	bar_bg.size     = Vector2(BAR_WIDTH, 48.0)
	add_child(bar_bg)

	# Green sweet-spot zone — child of bar_bg so its x is relative to the bar
	var sweet_spot := ColorRect.new()
	sweet_spot.color    = Color(0.18, 0.75, 0.22, 0.60)
	sweet_spot.position = Vector2(BAR_WIDTH * SWEET_SPOT_START, 0.0)
	sweet_spot.size     = Vector2(BAR_WIDTH * (SWEET_SPOT_END - SWEET_SPOT_START), 48.0)
	bar_bg.add_child(sweet_spot)

	# White cursor — child of bar_bg; _set_cursor moves its x each frame
	_cursor          = ColorRect.new()
	_cursor.color    = Color(1.0, 1.0, 1.0)
	_cursor.position = Vector2.ZERO
	_cursor.size     = Vector2(CURSOR_WIDTH, 48.0)
	bar_bg.add_child(_cursor)

	# Result feedback text (hidden until a hit is registered)
	_result_label                          = Label.new()
	_result_label.position                 = Vector2(370.0, 386.0)
	_result_label.size                     = Vector2(540.0, 44.0)
	_result_label.horizontal_alignment     = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", 26)
	_result_label.visible                  = false
	add_child(_result_label)

## --- Public API ---

func start_qte() -> void:
	_resolved              = false
	_cursor_pos            = 0.0
	_result_label.visible  = false
	_instruction_label.text = "Press SPACE or click to strike!"
	visible                = true
	_animate_cursor()

## --- Animation ---

func _animate_cursor() -> void:
	_tween = create_tween()
	_tween.tween_method(_set_cursor, 0.0, 1.0, CURSOR_DURATION)
	_tween.tween_callback(_on_cursor_expired)

func _set_cursor(value: float) -> void:
	_cursor_pos        = value
	_cursor.position.x = value * (BAR_WIDTH - CURSOR_WIDTH)

## --- Input ---

func _input(event: InputEvent) -> void:
	if not visible or _resolved:
		return
	var pressed: bool = false
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		pressed = true
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = true
	if pressed:
		get_viewport().set_input_as_handled()
		_register_hit()

## --- Resolution ---

func _register_hit() -> void:
	_resolved = true
	if _tween:
		_tween.kill()
	var accuracy: float = _calculate_accuracy(_cursor_pos)
	await _finish_qte(accuracy)

func _on_cursor_expired() -> void:
	if not _resolved:
		_resolved = true
		await _finish_qte(0.1)

func _finish_qte(accuracy: float) -> void:
	_show_feedback(accuracy)
	await get_tree().create_timer(0.85).timeout
	visible = false
	qte_resolved.emit(accuracy)

## Accuracy: 1.0 at dead center, 0.5 at sweet-spot edges, 0.2 outside.
func _calculate_accuracy(pos: float) -> float:
	if pos < SWEET_SPOT_START or pos > SWEET_SPOT_END:
		return 0.2
	var center: float     = (SWEET_SPOT_START + SWEET_SPOT_END) * 0.5
	var half_width: float = (SWEET_SPOT_END - SWEET_SPOT_START) * 0.5
	return lerp(1.0, 0.5, abs(pos - center) / half_width)

func _show_feedback(accuracy: float) -> void:
	_result_label.visible = true
	if accuracy >= 0.9:
		_result_label.text     = "PERFECT!"
		_result_label.modulate = Color.GREEN
	elif accuracy >= 0.65:
		_result_label.text     = "GOOD HIT!"
		_result_label.modulate = Color.YELLOW
	elif accuracy >= 0.35:
		_result_label.text     = "GLANCING..."
		_result_label.modulate = Color.ORANGE
	else:
		_result_label.text     = "MISS!"
		_result_label.modulate = Color.RED
