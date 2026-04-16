class_name QTEBar
extends CanvasLayer

## --- QTE Bar ---
## Sliding-bar quick time event with multi-beat sequencing and dynamic difficulty.
## All child nodes are built in _ready() so the .tscn stays minimal.
##
## Visual cue convention for all QTE types (this file + future QTE-2/3/4):
##   Slider QTE (this):      4-zone colored bar (gold / green / orange / red background)
##   Timer QTEs (QTE-2/3):   depleting timer bar per beat showing the input window
##   Power meter (QTE-4):    same 4-color zone scheme on the meter target zone

signal qte_resolved(multiplier: float)

const BAR_WIDTH: float    = 480.0
const CURSOR_WIDTH: float = 10.0

## Difficulty tiers — set once per start_qte() call from energy_cost:
##   Low   (1–2): 2.2 s cursor, sweet-spot half-width = 0.20 (40 % of bar)
##   Medium(3–4): 1.6 s cursor, sweet-spot half-width = 0.12 (24 % of bar)
##   High  (5+):  1.1 s cursor, sweet-spot half-width = 0.07 (14 % of bar)

var _cursor_pos: float      = 0.0
var _tween: Tween           = null
var _resolved: bool         = false
var _ss_half: float         = 0.20   ## current sweet-spot half-width (normalised)
var _cursor_duration: float = 2.2    ## current cursor travel time in seconds

var _beat_count: int            = 1    ## total beats for this QTE
var _current_beat: int          = 0    ## 0-indexed beat in progress
var _beat_results: Array[float] = []   ## per-beat multiplier results

## Node refs — assigned in _build_ui()
var _bar_bg:            ColorRect = null
var _cursor:            ColorRect = null
var _instruction_label: Label     = null
var _result_label:      Label     = null

## Zone ColorRects — children of _bar_bg; repositioned by _rebuild_zones()
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
	# Full-screen dark tint behind the bar
	var overlay := ColorRect.new()
	overlay.color    = Color(0.0, 0.0, 0.0, 0.72)
	overlay.position = Vector2.ZERO
	overlay.size     = Vector2(1280.0, 720.0)
	add_child(overlay)

	# Instruction / beat-counter text
	_instruction_label = Label.new()
	_instruction_label.position             = Vector2(370.0, 282.0)
	_instruction_label.size                 = Vector2(540.0, 32.0)
	_instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instruction_label.add_theme_font_size_override("font_size", 18)
	add_child(_instruction_label)

	# Bar background — dark red; serves as the failure-zone colour
	_bar_bg          = ColorRect.new()
	_bar_bg.color    = Color(0.35, 0.08, 0.08)
	_bar_bg.position = Vector2(400.0, 324.0)
	_bar_bg.size     = Vector2(BAR_WIDTH, 48.0)
	add_child(_bar_bg)

	# Zone ColorRects — added back-to-front so gold renders on top of orange/green.
	# Actual positions/sizes are set by _rebuild_zones().
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

	# Cursor — last child so it always renders above the zone colours
	_cursor          = ColorRect.new()
	_cursor.color    = Color(1.0, 1.0, 1.0)
	_cursor.position = Vector2.ZERO
	_cursor.size     = Vector2(CURSOR_WIDTH, 48.0)
	_bar_bg.add_child(_cursor)

	# Result / feedback text
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

	# Gold: centre 30 % of sweet spot  →  half_gold = ss_w × 0.15
	var half_gold: float  = ss_w * 0.15
	var gold_start: float = center_px - half_gold
	_zone_gold.position   = Vector2(gold_start, 0.0)
	_zone_gold.size       = Vector2(half_gold * 2.0, 48.0)

	# Green: centre 70 % of sweet spot  →  half_green = ss_w × 0.35
	# Green fills the band between half_gold and half_green from center on each side.
	var half_green: float    = ss_w * 0.35
	var green_l_start: float = center_px - half_green
	var green_l_end: float   = gold_start                  # = center_px - half_gold
	_zone_green_l.position   = Vector2(green_l_start, 0.0)
	_zone_green_l.size       = Vector2(green_l_end - green_l_start, 48.0)

	var green_r_start: float = center_px + half_gold
	var green_r_end: float   = center_px + half_green
	_zone_green_r.position   = Vector2(green_r_start, 0.0)
	_zone_green_r.size       = Vector2(green_r_end - green_r_start, 48.0)

	# Orange: outer 30 % of sweet spot (ss edge to green edge on each side)
	_zone_orange_l.position = Vector2(ss_start_px, 0.0)
	_zone_orange_l.size     = Vector2(green_l_start - ss_start_px, 48.0)

	_zone_orange_r.position = Vector2(green_r_end, 0.0)
	_zone_orange_r.size     = Vector2(ss_end_px - green_r_end, 48.0)

## --- Public API ---

## Entry point called by CombatManager3D before entering QTE_RUNNING state.
##
## effect_type is the hook for future QTE routing:
##   All types currently fall through to the slider (QTE-2/3/4 will add match arms here).
func start_qte(energy_cost: int, shape: AbilityData.TargetShape,
		effect_type: EffectData.EffectType) -> void:
	match effect_type:
		_:
			_start_slider_qte(energy_cost, shape)

func _start_slider_qte(energy_cost: int, shape: AbilityData.TargetShape) -> void:
	_set_difficulty(energy_cost)
	_beat_count   = _beat_count_for_shape(shape)
	_current_beat = 0
	_beat_results = []
	_resolved     = false
	_result_label.visible = false
	visible = true
	_start_next_beat()

## --- Difficulty ---

func _set_difficulty(energy_cost: int) -> void:
	if energy_cost <= 2:
		_cursor_duration = 2.2
		_ss_half = 0.20
	elif energy_cost <= 4:
		_cursor_duration = 1.6
		_ss_half = 0.12
	else:
		_cursor_duration = 1.1
		_ss_half = 0.07
	_rebuild_zones()

## --- Beat Count ---

func _beat_count_for_shape(shape: AbilityData.TargetShape) -> int:
	match shape:
		AbilityData.TargetShape.CONE:   return 2
		AbilityData.TargetShape.LINE:   return 3
		AbilityData.TargetShape.RADIAL: return 4
		_:                              return 1  # SELF, SINGLE, ARC

## --- Beat Flow ---

func _start_next_beat() -> void:
	_resolved          = false
	_cursor_pos        = 0.0
	_cursor.position.x = 0.0
	_result_label.visible = false

	if _beat_count > 1:
		_instruction_label.text = "Beat %d / %d  —  Press SPACE or click!" \
			% [_current_beat + 1, _beat_count]
	else:
		_instruction_label.text = "Press SPACE or click to strike!"

	_animate_cursor()

## --- Zone Result ---

## Returns the multiplier for a cursor position using the current _ss_half.
## Mirrored as _beat_result() in tests/test_qte_foundation.gd.
func _get_beat_result(pos: float) -> float:
	var dist: float = abs(pos - 0.5)
	if dist > _ss_half:
		return 0.25   # red — failure
	if dist >= _ss_half * 0.70:
		return 0.75   # orange — minor
	if dist >= _ss_half * 0.30:
		return 1.0    # green — major
	return 1.25       # gold — perfect

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
	_process_beat_result(_get_beat_result(_cursor_pos))

func _on_cursor_expired() -> void:
	if not _resolved:
		_resolved = true
		_process_beat_result(0.25)  # expired = failure zone

func _process_beat_result(result: float) -> void:
	_beat_results.append(result)
	_current_beat += 1

	if _current_beat < _beat_count:
		# More beats remain: flash result for 0.3 s then start the next slider
		_show_beat_feedback(result)
		await get_tree().create_timer(0.3).timeout
		_start_next_beat()
	else:
		# All beats done: aggregate, show final feedback, emit
		var multiplier: float = _aggregate_multiplier()
		_show_final_feedback(multiplier)
		await get_tree().create_timer(0.85).timeout
		visible = false
		qte_resolved.emit(multiplier)

## Brief between-beat label (cleared at start of the next beat).
func _show_beat_feedback(result: float) -> void:
	_result_label.visible = true
	if result >= 1.25:
		_result_label.text     = "PERFECT"
		_result_label.modulate = Color(1.0, 0.85, 0.0)
	elif result >= 1.0:
		_result_label.text     = "GOOD"
		_result_label.modulate = Color.GREEN
	elif result >= 0.75:
		_result_label.text     = "WEAK"
		_result_label.modulate = Color.ORANGE
	else:
		_result_label.text     = "MISS"
		_result_label.modulate = Color.RED

## Final result label shown after all beats complete (stays for 0.85 s).
func _show_final_feedback(multiplier: float) -> void:
	_result_label.visible = true
	if multiplier >= 1.25:
		_result_label.text     = "PERFECT!"
		_result_label.modulate = Color(1.0, 0.85, 0.0)
	elif multiplier >= 1.0:
		_result_label.text     = "GOOD HIT!"
		_result_label.modulate = Color.GREEN
	elif multiplier >= 0.75:
		_result_label.text     = "GLANCING..."
		_result_label.modulate = Color.ORANGE
	else:
		_result_label.text     = "MISS!"
		_result_label.modulate = Color.RED

## Averages _beat_results and maps to nearest tier.
## ≥1.2 → 1.25 · ≥0.9 → 1.0 · ≥0.6 → 0.75 · <0.6 → 0.25
func _aggregate_multiplier() -> float:
	if _beat_results.is_empty():
		return 0.25
	var sum: float = 0.0
	for r: float in _beat_results:
		sum += r
	var avg: float = sum / float(_beat_results.size())
	if avg >= 1.2: return 1.25
	if avg >= 0.9: return 1.0
	if avg >= 0.6: return 0.75
	return 0.25
