class_name QTEBar
extends CanvasLayer

## --- QTE Bar ---
## Sliding-bar quick time event with multi-beat sequencing and dynamic difficulty.
## Also hosts the directional-sequence QTE for BUFF / DEBUFF effects.
## All child nodes are built in _ready() so the .tscn stays minimal.
##
## Visual cue convention for all QTE types:
##   Slider QTE (HARM / MEND / FORCE / TRAVEL): 4-zone colored bar (gold / green / orange / red)
##   Directional QTE (BUFF / DEBUFF):            arrow sequence + shrinking timing bar per beat
##   Timer QTEs (QTE-2/3):   depleting timer bar per beat showing the input window
##   Power meter (QTE-4):    same 4-color zone scheme on the meter target zone

signal qte_resolved(multiplier: float)

const BAR_WIDTH: float        = 480.0
const CURSOR_WIDTH: float     = 10.0
const TIMING_BAR_WIDTH: float = 400.0   ## width of the directional timing bar

## Power meter bar dimensions — vertical bar centred on screen
const PM_BAR_WIDTH:  float = 60.0
const PM_BAR_HEIGHT: float = 400.0
const PM_BAR_X:      float = 610.0   ## (1280 / 2) − 30 = horizontal centre
const PM_BAR_Y:      float = 160.0   ## (720  / 2) − 200 = vertical centre

## Difficulty tiers — set once per start_qte() call from energy_cost:
##   Low   (1–2): 2.2 s cursor / 2.0 s dir window, sweet-spot half-width = 0.20
##   Medium(3–4): 1.6 s cursor / 1.5 s dir window, sweet-spot half-width = 0.12
##   High  (5+):  1.1 s cursor / 1.0 s dir window, sweet-spot half-width = 0.07

## --- Slider state ---

var _cursor_pos: float      = 0.0
var _tween: Tween           = null
var _resolved: bool         = false
var _ss_half: float         = 0.20
var _cursor_duration: float = 2.2

## --- Multi-beat state (shared) ---

var _beat_count: int            = 1
var _current_beat: int          = 0
var _beat_results: Array[float] = []

## --- Directional-sequence state ---

var _directional_mode: bool      = false
var _dir_sequence: Array[String] = []
var _dir_resolved: bool          = false
var _dir_shrink_tween: Tween     = null
var _dir_input_window: float     = 1.5   ## seconds per directional beat; set by _set_difficulty

## --- Power meter state ---

var _pm_mode:        bool  = false   ## true while power meter QTE is active
var _pm_active:      bool  = false   ## true while player can still release to score
var _pm_fill_pos:    float = 0.0     ## normalized fill level [0, 1]
var _pm_dir:         int   = 1       ## 1 = filling; −1 = draining (reverses at 100 %)
var _pm_held:        bool  = false   ## true while Space or LMB is held
var _pm_zone_center: float = 0.65    ## normalized zone centre; set by _set_pm_difficulty()
var _pm_zone_half:   float = 0.18    ## zone half-width; set by _set_pm_difficulty()
var _pm_fill_rate:   float = 0.5     ## fill units per second; derived from _cursor_duration

## --- Node refs — assigned in _build_ui() ---

## Slider nodes
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

## Directional nodes
var _arrow_label:  Label     = null   ## large centred arrow character
var _timing_bg:    ColorRect = null   ## full-width timing bar background
var _timing_fill:  ColorRect = null   ## fill that shrinks to zero as the window expires

## Power meter nodes
var _pm_bar_bg:        ColorRect = null   ## vertical bar background (failure-zone dark red)
var _pm_cursor:        ColorRect = null   ## horizontal white cursor line
var _pm_zone_orange_t: ColorRect = null   ## orange band — upper
var _pm_zone_orange_b: ColorRect = null   ## orange band — lower
var _pm_zone_green_t:  ColorRect = null   ## green band  — upper
var _pm_zone_green_b:  ColorRect = null   ## green band  — lower
var _pm_zone_gold_pm:  ColorRect = null   ## gold  band  — centre

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

	# --- Power meter QTE nodes (added before labels so bar renders behind text) ---

	# Vertical bar background — dark red (failure-zone colour)
	_pm_bar_bg          = ColorRect.new()
	_pm_bar_bg.color    = Color(0.35, 0.08, 0.08)
	_pm_bar_bg.position = Vector2(PM_BAR_X, PM_BAR_Y)
	_pm_bar_bg.size     = Vector2(PM_BAR_WIDTH, PM_BAR_HEIGHT)
	_pm_bar_bg.visible  = false
	add_child(_pm_bar_bg)

	# Zone bands — children of _pm_bar_bg; repositioned by _rebuild_pm_zones()
	_pm_zone_orange_t       = ColorRect.new()
	_pm_zone_orange_t.color = Color(0.90, 0.50, 0.10, 0.80)
	_pm_bar_bg.add_child(_pm_zone_orange_t)

	_pm_zone_orange_b       = ColorRect.new()
	_pm_zone_orange_b.color = Color(0.90, 0.50, 0.10, 0.80)
	_pm_bar_bg.add_child(_pm_zone_orange_b)

	_pm_zone_green_t        = ColorRect.new()
	_pm_zone_green_t.color  = Color(0.18, 0.75, 0.22, 0.80)
	_pm_bar_bg.add_child(_pm_zone_green_t)

	_pm_zone_green_b        = ColorRect.new()
	_pm_zone_green_b.color  = Color(0.18, 0.75, 0.22, 0.80)
	_pm_bar_bg.add_child(_pm_zone_green_b)

	_pm_zone_gold_pm        = ColorRect.new()
	_pm_zone_gold_pm.color  = Color(1.0, 0.85, 0.0, 0.90)
	_pm_bar_bg.add_child(_pm_zone_gold_pm)

	# Cursor — white horizontal line rendered on top of zone colours
	_pm_cursor          = ColorRect.new()
	_pm_cursor.color    = Color(1.0, 1.0, 1.0)
	_pm_cursor.position = Vector2(0.0, PM_BAR_HEIGHT - 4.0)   # starts at bottom
	_pm_cursor.size     = Vector2(PM_BAR_WIDTH, 4.0)
	_pm_bar_bg.add_child(_pm_cursor)

	# Instruction / beat-counter text (shared by both QTE types)
	_instruction_label = Label.new()
	_instruction_label.position             = Vector2(370.0, 282.0)
	_instruction_label.size                 = Vector2(540.0, 32.0)
	_instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instruction_label.add_theme_font_size_override("font_size", 18)
	add_child(_instruction_label)

	# Bar background — dark red; serves as the failure-zone colour (slider only)
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

	# Result / feedback text (shared — appears below bar or below timing bar)
	_result_label                          = Label.new()
	_result_label.position                 = Vector2(370.0, 386.0)
	_result_label.size                     = Vector2(540.0, 44.0)
	_result_label.horizontal_alignment     = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", 26)
	_result_label.visible                  = false
	add_child(_result_label)

	# --- Directional QTE nodes ---

	# Large arrow character centred on screen above the timing bar
	_arrow_label = Label.new()
	_arrow_label.position             = Vector2(490.0, 240.0)
	_arrow_label.size                 = Vector2(300.0, 120.0)
	_arrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_arrow_label.add_theme_font_size_override("font_size", 96)
	_arrow_label.visible              = false
	add_child(_arrow_label)

	# Timing bar — thin depleting bar showing how long the player has to input
	_timing_bg          = ColorRect.new()
	_timing_bg.color    = Color(0.25, 0.25, 0.25)
	_timing_bg.position = Vector2(440.0, 370.0)
	_timing_bg.size     = Vector2(TIMING_BAR_WIDTH, 16.0)
	_timing_bg.visible  = false
	add_child(_timing_bg)

	_timing_fill         = ColorRect.new()
	_timing_fill.color   = Color(0.20, 0.70, 1.0)   # bright blue fill
	_timing_fill.position = Vector2.ZERO
	_timing_fill.size    = Vector2(TIMING_BAR_WIDTH, 16.0)
	_timing_bg.add_child(_timing_fill)

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
	var half_green: float    = ss_w * 0.35
	var green_l_start: float = center_px - half_green
	var green_l_end: float   = gold_start
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
## effect_type routes to the appropriate QTE style:
##   BUFF / DEBUFF → directional arrow sequence
##   all others    → 4-zone sliding bar
func start_qte(energy_cost: int, shape: AbilityData.TargetShape,
		effect_type: EffectData.EffectType) -> void:
	match effect_type:
		EffectData.EffectType.BUFF, EffectData.EffectType.DEBUFF:
			_start_directional_qte(energy_cost, shape)
		EffectData.EffectType.TRAVEL:
			_start_power_meter_qte(energy_cost)
		_:
			_start_slider_qte(energy_cost, shape)

## --- Slider QTE ---

func _start_slider_qte(energy_cost: int, shape: AbilityData.TargetShape) -> void:
	_directional_mode  = false
	_bar_bg.visible    = true   # restore after any prior directional run
	_set_difficulty(energy_cost)
	_beat_count   = _beat_count_for_shape(shape)
	_current_beat = 0
	_beat_results = []
	_resolved     = false
	_result_label.visible = false
	visible = true
	_start_next_beat()

## --- Power Meter QTE ---

## Entry point for TRAVEL effect type.
## Hold Space / LMB to raise the meter; it drains back after hitting 100 %.
## Release inside the coloured zone to score; outside = miss (0.25).
## Always 1 beat — TRAVEL is always SELF shape.
func _start_power_meter_qte(energy_cost: int) -> void:
	_pm_mode      = true
	_pm_active    = true
	_pm_fill_pos  = 0.0
	_pm_dir       = 1
	_pm_held      = false
	_beat_count   = 1
	_current_beat = 0
	_beat_results = []
	_resolved     = false

	# Cursor duration doubles as the fill time (seconds to go 0→1)
	_set_difficulty(energy_cost)
	_pm_fill_rate = 1.0 / _cursor_duration

	_set_pm_difficulty(energy_cost)
	_rebuild_pm_zones()

	# Hide horizontal slider; show vertical bar
	_bar_bg.visible            = false
	_result_label.visible      = false
	_pm_bar_bg.visible         = true
	_pm_cursor.position.y      = PM_BAR_HEIGHT - 4.0   # cursor starts at bottom

	_instruction_label.text = "Hold SPACE or click — release in the zone!"
	visible = true

## Sets the zone centre and half-width based on energy cost difficulty tier.
##   Low   (1–2): wide zone,   centre 65 %, half-width 18 %
##   Medium(3–4): medium zone, centre 72 %, half-width 12 %
##   High  (5+):  narrow zone, centre 78 %, half-width  7 %
func _set_pm_difficulty(energy_cost: int) -> void:
	if energy_cost <= 2:
		_pm_zone_center = 0.65
		_pm_zone_half   = 0.18
	elif energy_cost <= 4:
		_pm_zone_center = 0.72
		_pm_zone_half   = 0.12
	else:
		_pm_zone_center = 0.78
		_pm_zone_half   = 0.07

## Repositions the five zone ColorRects on the vertical bar.
## Fill position 0 = bottom of bar, 1 = top.
## In screen space y increases downward, so value v → y = (1 − v) × PM_BAR_HEIGHT.
func _rebuild_pm_zones() -> void:
	var h: float       = PM_BAR_HEIGHT
	var w: float       = PM_BAR_WIDTH
	# centre_y: y pixels from bar top where zone centre sits
	var centre_y: float = (1.0 - _pm_zone_center) * h
	var half_px:  float = _pm_zone_half * h

	var zone_top: float = centre_y - half_px
	var zone_bot: float = centre_y + half_px

	# Gold — centre 30 % of zone half
	var gold_half: float = half_px * 0.30
	var gold_top: float  = centre_y - gold_half
	var gold_bot: float  = centre_y + gold_half
	_pm_zone_gold_pm.position = Vector2(0.0, gold_top)
	_pm_zone_gold_pm.size     = Vector2(w, gold_bot - gold_top)

	# Green — 30 %–70 % of zone half (flanking gold on each side)
	var green_half: float = half_px * 0.70
	var green_top: float  = centre_y - green_half
	var green_bot: float  = centre_y + green_half
	_pm_zone_green_t.position = Vector2(0.0, green_top)
	_pm_zone_green_t.size     = Vector2(w, gold_top - green_top)
	_pm_zone_green_b.position = Vector2(0.0, gold_bot)
	_pm_zone_green_b.size     = Vector2(w, green_bot - gold_bot)

	# Orange — outer 30 % of zone (zone edge to green edge on each side)
	_pm_zone_orange_t.position = Vector2(0.0, zone_top)
	_pm_zone_orange_t.size     = Vector2(w, green_top - zone_top)
	_pm_zone_orange_b.position = Vector2(0.0, green_bot)
	_pm_zone_orange_b.size     = Vector2(w, zone_bot - green_bot)

## Returns the multiplier for a power meter release at the given fill level [0, 1].
## Same 4-zone thresholds as the slider, measured from _pm_zone_center.
func _get_pm_result(fill: float) -> float:
	var dist: float = abs(fill - _pm_zone_center)
	if dist > _pm_zone_half:
		return 0.25   # red   — outside zone
	if dist >= _pm_zone_half * 0.70:
		return 0.75   # orange — outer rim
	if dist >= _pm_zone_half * 0.30:
		return 1.0    # green  — inner rim
	return 1.25       # gold   — centre

## --- Directional Sequence QTE ---

func _start_directional_qte(energy_cost: int, shape: AbilityData.TargetShape) -> void:
	_set_difficulty(energy_cost)
	_beat_count   = _beat_count_for_shape(shape)
	_current_beat = 0
	_beat_results = []
	_resolved     = false     # not used by directional, but keep clean
	_directional_mode = true

	_dir_sequence = _generate_dir_sequence(_beat_count)

	# Hide the slider bar; show the directional arrow overlay
	_bar_bg.visible       = false
	_result_label.visible = false
	visible = true
	_start_dir_beat()

## Generates a randomised direction sequence of length `count` from
## [UP, DOWN, LEFT, RIGHT] with no two consecutive identical directions.
func _generate_dir_sequence(count: int) -> Array[String]:
	var dirs := ["UP", "DOWN", "LEFT", "RIGHT"]
	var seq: Array[String] = []
	var last: String = ""
	for _i: int in range(count):
		# Retry until we pick a direction that differs from the previous one.
		# With 4 choices and only 1 excluded, expected retries ≈ 1.33.
		var pick: String = last
		while pick == last:
			pick = dirs[randi() % dirs.size()]
		seq.append(pick)
		last = pick
	return seq

## Starts a single directional beat: shows the arrow, starts the timing bar.
func _start_dir_beat() -> void:
	_dir_resolved          = false
	_result_label.visible  = false
	_arrow_label.modulate  = Color.WHITE   # clear flash tint from previous beat

	var dir: String = _dir_sequence[_current_beat]
	_arrow_label.text    = _dir_arrow_char(dir)
	_arrow_label.visible = true

	var beat_prefix: String = ""
	if _beat_count > 1:
		beat_prefix = "Beat %d / %d  —  " % [_current_beat + 1, _beat_count]
	_instruction_label.text = beat_prefix + "Press ↑ ↓ ← → or WASD!"

	# Reset timing bar to full width and animate depletion
	_timing_fill.size.x = TIMING_BAR_WIDTH
	_timing_bg.visible  = true
	_dir_shrink_tween   = create_tween()
	_dir_shrink_tween.tween_property(_timing_fill, "size:x", 0.0, _dir_input_window)
	_dir_shrink_tween.tween_callback(_on_dir_input_expired)

## --- Difficulty ---

func _set_difficulty(energy_cost: int) -> void:
	if energy_cost <= 2:
		_cursor_duration  = 2.2
		_ss_half          = 0.20
		_dir_input_window = 2.0
	elif energy_cost <= 4:
		_cursor_duration  = 1.6
		_ss_half          = 0.12
		_dir_input_window = 1.5
	else:
		_cursor_duration  = 1.1
		_ss_half          = 0.07
		_dir_input_window = 1.0
	_rebuild_zones()

## --- Beat Count ---

func _beat_count_for_shape(shape: AbilityData.TargetShape) -> int:
	match shape:
		AbilityData.TargetShape.CONE:   return 2
		AbilityData.TargetShape.LINE:   return 3
		AbilityData.TargetShape.RADIAL: return 4
		_:                              return 1  # SELF, SINGLE, ARC

## --- Slider Beat Flow ---

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

## --- Zone Result (slider) ---

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

## --- Slider Animation ---

func _animate_cursor() -> void:
	_tween = create_tween()
	_tween.tween_method(_set_cursor, 0.0, 1.0, _cursor_duration)
	_tween.tween_callback(_on_cursor_expired)

func _set_cursor(value: float) -> void:
	_cursor_pos        = value
	_cursor.position.x = value * (BAR_WIDTH - CURSOR_WIDTH)

## --- Input ---

func _input(event: InputEvent) -> void:
	if not visible:
		return
	# Route to directional handler before SPACE / click check so arrow keys
	# don't accidentally fall through when the directional QTE is active.
	if _directional_mode:
		_handle_dir_input(event)
		return
	# Route to power meter handler; _pm_active gates input after release.
	if _pm_mode:
		if _pm_active:
			_handle_pm_input(event)
		return
	if _resolved:
		return
	var pressed: bool = false
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		pressed = true
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = true
	if pressed:
		get_viewport().set_input_as_handled()
		_register_hit()

## Handles a key press during a directional beat.
## Only arrow keys and WASD are valid — other keys are silently ignored.
func _handle_dir_input(event: InputEvent) -> void:
	if _dir_resolved:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var dir: String = _keycode_to_dir(event.keycode)
	if dir == "":
		return   # irrelevant key — do not consume or resolve
	get_viewport().set_input_as_handled()
	_dir_resolved = true
	if _dir_shrink_tween:
		_dir_shrink_tween.kill()
	var expected: String = _dir_sequence[_current_beat]
	var correct: bool = dir == expected
	_flash_arrow_feedback(correct)
	_process_beat_result(1.25 if correct else 0.25)

## Maps arrow keys and WASD to direction strings. Returns "" for unrecognised keys.
func _keycode_to_dir(keycode: Key) -> String:
	match keycode:
		KEY_UP,    KEY_W: return "UP"
		KEY_DOWN,  KEY_S: return "DOWN"
		KEY_LEFT,  KEY_A: return "LEFT"
		KEY_RIGHT, KEY_D: return "RIGHT"
	return ""

## Called when the input window expires before the player pressed anything.
func _on_dir_input_expired() -> void:
	if not _dir_resolved:
		_dir_resolved = true
		_flash_arrow_feedback(false)
		_process_beat_result(0.25)

## Tints the arrow label green (hit) or red (miss/timeout) for visual feedback.
func _flash_arrow_feedback(correct: bool) -> void:
	_arrow_label.modulate = Color.GREEN if correct else Color.RED

## Handles hold / release events for the power meter QTE.
## Pressing Space or LMB starts filling; releasing scores and resolves the beat.
func _handle_pm_input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		if event.keycode == KEY_SPACE:
			get_viewport().set_input_as_handled()
			if event.pressed:
				_pm_held = true
			else:
				_pm_held   = false
				_pm_active = false
				_process_beat_result(_get_pm_result(_pm_fill_pos))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		if event.pressed:
			_pm_held = true
		else:
			_pm_held   = false
			_pm_active = false
			_process_beat_result(_get_pm_result(_pm_fill_pos))

## Advances the power meter fill each frame while the player holds the input.
## Reverses direction when fill hits 100 % and clamps at 0 % if fully drained.
func _process(delta: float) -> void:
	if not _pm_mode or not _pm_active or not _pm_held:
		return
	_pm_fill_pos += _pm_fill_rate * float(_pm_dir) * delta
	if _pm_dir == 1 and _pm_fill_pos >= 1.0:
		_pm_fill_pos = 1.0
		_pm_dir      = -1   # start draining
	elif _pm_dir == -1 and _pm_fill_pos <= 0.0:
		_pm_fill_pos = 0.0  # clamp at bottom; player gets a miss on release

	# Move cursor: value 0 = bottom (y ≈ PM_BAR_HEIGHT), value 1 = top (y ≈ 0)
	var cursor_y: float = (1.0 - _pm_fill_pos) * PM_BAR_HEIGHT - 2.0
	_pm_cursor.position.y = clampf(cursor_y, 0.0, PM_BAR_HEIGHT - 4.0)

## Returns the Unicode arrow character for a direction string.
func _dir_arrow_char(dir: String) -> String:
	match dir:
		"UP":    return "↑"
		"DOWN":  return "↓"
		"LEFT":  return "←"
		"RIGHT": return "→"
	return "?"

## --- Slider Resolution ---

func _register_hit() -> void:
	_resolved = true
	if _tween:
		_tween.kill()
	_process_beat_result(_get_beat_result(_cursor_pos))

func _on_cursor_expired() -> void:
	if not _resolved:
		_resolved = true
		_process_beat_result(0.25)  # expired = failure zone

## --- Shared Beat Resolution ---

func _process_beat_result(result: float) -> void:
	_beat_results.append(result)
	_current_beat += 1

	if _current_beat < _beat_count:
		# More beats remain: flash result for 0.3 s then start the next beat
		_show_beat_feedback(result)
		await get_tree().create_timer(0.3).timeout
		if _directional_mode:
			_start_dir_beat()
		else:
			_start_next_beat()
	else:
		# All beats done: aggregate, show final feedback, emit
		var multiplier: float = _aggregate_multiplier()
		_show_final_feedback(multiplier)
		await get_tree().create_timer(0.85).timeout
		visible = false
		# Restore slider-safe state for the next QTE call
		if _directional_mode:
			_directional_mode    = false
			_bar_bg.visible      = true
			_arrow_label.visible = false
			_timing_bg.visible   = false
		elif _pm_mode:
			_pm_mode           = false
			_pm_active         = false
			_pm_bar_bg.visible = false
			_bar_bg.visible    = true
		qte_resolved.emit(multiplier)

## Brief between-beat label (cleared at start of the next beat).
func _show_beat_feedback(result: float) -> void:
	_result_label.visible = true
	if _directional_mode:
		# Directional is binary — either you hit the right key or you didn't.
		if result >= 1.0:
			_result_label.text     = "HIT!"
			_result_label.modulate = Color.GREEN
		else:
			_result_label.text     = "MISS"
			_result_label.modulate = Color.RED
		return
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
	# Hide input elements so only the verdict text is visible
	if _directional_mode:
		_arrow_label.visible = false
		_timing_bg.visible   = false
	elif _pm_mode:
		_pm_bar_bg.visible = false   # remove meter; show only verdict label
	_result_label.visible = true
	if _directional_mode:
		if multiplier >= 1.25:
			_result_label.text     = "ALL CORRECT!"
			_result_label.modulate = Color(1.0, 0.85, 0.0)
		elif multiplier >= 1.0:
			_result_label.text     = "MOSTLY RIGHT"
			_result_label.modulate = Color.GREEN
		elif multiplier >= 0.75:
			_result_label.text     = "CLOSE..."
			_result_label.modulate = Color.ORANGE
		else:
			_result_label.text     = "MISS!"
			_result_label.modulate = Color.RED
		return
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
