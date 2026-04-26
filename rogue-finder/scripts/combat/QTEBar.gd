class_name QTEBar
extends CanvasLayer

## --- QTE Bar (Defender-Driven Slide) ---
## Single-beat sliding-bar quick time event played by the DEFENDER when a HARM effect
## targets them. Emits qte_resolved(multiplier) with one of {0.25, 0.75, 1.0, 1.25}.
## Higher multiplier = better dodge. CombatManager maps this to a damage multiplier
## (1.25→0.5, 1.0→0.75, 0.75→1.0, 0.25→1.25).
##
## Non-HARM effects (MEND, BUFF, DEBUFF, FORCE, TRAVEL) never invoke this bar.

signal qte_resolved(multiplier: float)

const BAR_WIDTH: float    = 480.0
const CURSOR_WIDTH: float = 10.0

## Difficulty tiers — set once per start_qte() call from energy_cost:
##   Low   (1–2): 2.2 s cursor, sweet-spot half-width = 0.20
##   Medium(3–4): 1.6 s cursor, sweet-spot half-width = 0.12
##   High  (5+):  1.1 s cursor, sweet-spot half-width = 0.07

## --- Slider state ---

var _cursor_pos: float      = 0.0
var _tween: Tween           = null
var _resolved: bool         = false
var _ss_half: float         = 0.20
var _cursor_duration: float = 2.2

## --- Node refs — assigned in _build_ui() ---

var _bar_bg:            ColorRect = null
var _cursor:            ColorRect = null
var _instruction_label: Label     = null
var _result_label:      Label     = null

var _zone_orange_l: ColorRect = null
var _zone_orange_r: ColorRect = null
var _zone_green_l:  ColorRect = null
var _zone_green_r:  ColorRect = null
var _zone_gold:     ColorRect = null

func _ready() -> void:
	_build_ui()
	visible = false

## --- UI Construction ---

func _build_ui() -> void:
	var overlay := ColorRect.new()
	overlay.color    = Color(0.0, 0.0, 0.0, 0.72)
	overlay.position = Vector2.ZERO
	overlay.size     = Vector2(1280.0, 720.0)
	add_child(overlay)

	_instruction_label = Label.new()
	_instruction_label.position             = Vector2(370.0, 200.0)
	_instruction_label.size                 = Vector2(540.0, 32.0)
	_instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instruction_label.add_theme_font_size_override("font_size", 18)
	add_child(_instruction_label)

	_bar_bg          = ColorRect.new()
	_bar_bg.color    = Color(0.35, 0.08, 0.08)
	_bar_bg.position = Vector2(400.0, 324.0)
	_bar_bg.size     = Vector2(BAR_WIDTH, 48.0)
	add_child(_bar_bg)

	_zone_orange_l       = ColorRect.new()
	_zone_orange_l.color = Color(0.90, 0.50, 0.10, 0.80)
	_bar_bg.add_child(_zone_orange_l)

	_zone_orange_r       = ColorRect.new()
	_zone_orange_r.color = Color(0.90, 0.50, 0.10, 0.80)
	_bar_bg.add_child(_zone_orange_r)

	_zone_green_l        = ColorRect.new()
	_zone_green_l.color  = Color(0.18, 0.75, 0.22, 0.80)
	_bar_bg.add_child(_zone_green_l)

	_zone_green_r        = ColorRect.new()
	_zone_green_r.color  = Color(0.18, 0.75, 0.22, 0.80)
	_bar_bg.add_child(_zone_green_r)

	_zone_gold           = ColorRect.new()
	_zone_gold.color     = Color(1.0, 0.85, 0.0, 0.90)
	_bar_bg.add_child(_zone_gold)

	_cursor          = ColorRect.new()
	_cursor.color    = Color(1.0, 1.0, 1.0)
	_cursor.position = Vector2.ZERO
	_cursor.size     = Vector2(CURSOR_WIDTH, 48.0)
	_bar_bg.add_child(_cursor)

	_result_label                          = Label.new()
	_result_label.position                 = Vector2(370.0, 386.0)
	_result_label.size                     = Vector2(540.0, 44.0)
	_result_label.horizontal_alignment     = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", 26)
	_result_label.visible                  = false
	add_child(_result_label)

	_rebuild_zones()

## Resizes the five zone ColorRects to match the current _ss_half.
## Called once from _build_ui() and again each time difficulty changes.
func _rebuild_zones() -> void:
	var w: float         = BAR_WIDTH
	var center_px: float = w * 0.5
	var half: float      = _ss_half

	var ss_start_px: float = (0.5 - half) * w
	var ss_end_px: float   = (0.5 + half) * w
	var ss_w: float        = ss_end_px - ss_start_px

	var half_gold: float  = ss_w * 0.15
	var gold_start: float = center_px - half_gold
	_zone_gold.position   = Vector2(gold_start, 0.0)
	_zone_gold.size       = Vector2(half_gold * 2.0, 48.0)

	var half_green: float    = ss_w * 0.35
	var green_l_start: float = center_px - half_green
	var green_l_end: float   = gold_start
	_zone_green_l.position   = Vector2(green_l_start, 0.0)
	_zone_green_l.size       = Vector2(green_l_end - green_l_start, 48.0)

	var green_r_start: float = center_px + half_gold
	var green_r_end: float   = center_px + half_green
	_zone_green_r.position   = Vector2(green_r_start, 0.0)
	_zone_green_r.size       = Vector2(green_r_end - green_r_start, 48.0)

	_zone_orange_l.position = Vector2(ss_start_px, 0.0)
	_zone_orange_l.size     = Vector2(green_l_start - ss_start_px, 48.0)

	_zone_orange_r.position = Vector2(green_r_end, 0.0)
	_zone_orange_r.size     = Vector2(ss_end_px - green_r_end, 48.0)

## --- Public API ---

## Called by CombatManager3D when a HARM effect targets a player-controlled defender.
## Difficulty is scaled from the attacking ability's energy_cost.
func start_qte(energy_cost: int) -> void:
	_set_difficulty(energy_cost)
	_resolved          = false
	_cursor_pos        = 0.0
	_cursor.position.x = 0.0
	_result_label.visible = false
	_instruction_label.text = "Press SPACE or click to dodge!"
	visible = true
	_animate_cursor()

## --- Difficulty ---

func _set_difficulty(energy_cost: int) -> void:
	if energy_cost <= 2:
		_cursor_duration = 2.2
		_ss_half         = 0.20
	elif energy_cost <= 4:
		_cursor_duration = 1.6
		_ss_half         = 0.12
	else:
		_cursor_duration = 1.1
		_ss_half         = 0.07
	_rebuild_zones()

## --- Zone Result ---

## Returns the dodge multiplier for a given cursor position.
## dist = |cursor_pos - 0.5|; zones are symmetric around bar centre.
func _get_beat_result(pos: float) -> float:
	var dist: float = abs(pos - 0.5)
	if dist > _ss_half:
		return 0.25   # red   — failed to dodge
	if dist >= _ss_half * 0.70:
		return 0.75   # orange — weak dodge
	if dist >= _ss_half * 0.30:
		return 1.0    # green  — good dodge
	return 1.25       # gold   — perfect dodge

## --- Animation ---

func _animate_cursor() -> void:
	_tween = create_tween()
	_tween.tween_method(_set_cursor, 0.0, 1.0, _cursor_duration)
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
	_process_result(_get_beat_result(_cursor_pos))

func _on_cursor_expired() -> void:
	if not _resolved:
		_resolved = true
		_process_result(0.25)

func _process_result(result: float) -> void:
	_show_feedback(result)
	await get_tree().create_timer(0.85).timeout
	visible = false
	qte_resolved.emit(result)

## --- Feedback ---

func _show_feedback(multiplier: float) -> void:
	_result_label.visible = true
	if multiplier >= 1.25:
		_result_label.text     = "PERFECT DODGE!"
		_result_label.modulate = Color(1.0, 0.85, 0.0)
	elif multiplier >= 1.0:
		_result_label.text     = "GOOD DODGE!"
		_result_label.modulate = Color.GREEN
	elif multiplier >= 0.75:
		_result_label.text     = "WEAK DODGE..."
		_result_label.modulate = Color.ORANGE
	else:
		_result_label.text     = "HIT!"
		_result_label.modulate = Color.RED
