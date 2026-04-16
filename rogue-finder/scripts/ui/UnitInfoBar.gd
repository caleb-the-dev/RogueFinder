class_name UnitInfoBar
extends CanvasLayer

## --- UnitInfoBar ---
## Condensed unit info strip at the bottom-center of the screen.
## Shown on single-click of any unit (player or enemy). Hidden on deselect.
## Displays: portrait, name/class, HP bar, energy bar.
## Layer 4: above world, below StatPanel (layer 8) and QTE (layer 10).

const PANEL_W: float     = 460.0
const PANEL_H: float     = 96.0   # extended to fit status row
const PORTRAIT_SZ: float = 56.0
const BAR_W: float       = 280.0
const BAR_H: float       = 9.0

var _panel: ColorRect        = null
var _portrait: TextureRect   = null
var _name_lbl: Label         = null
var _class_lbl: Label        = null
var _hp_bg: ColorRect        = null
var _hp_fill: ColorRect      = null
var _hp_text: Label          = null
var _en_bg: ColorRect        = null
var _en_fill: ColorRect      = null
var _en_text: Label          = null
var _status_rtl: RichTextLabel = null

func _ready() -> void:
	layer = 4
	_build_ui()
	visible = false

## --- UI Construction ---

func _build_ui() -> void:
	# Center horizontally at bottom of a 1280×720 viewport
	_panel = ColorRect.new()
	_panel.color    = Color(0.05, 0.06, 0.12, 0.92)
	_panel.position = Vector2((1280.0 - PANEL_W) * 0.5, 720.0 - PANEL_H - 4.0)
	_panel.size     = Vector2(PANEL_W, PANEL_H)
	add_child(_panel)

	# Portrait (left side) — fixed y so it doesn't shift when PANEL_H changes
	_portrait = TextureRect.new()
	_portrait.position     = Vector2(8.0, 10.0)
	_portrait.size         = Vector2(PORTRAIT_SZ, PORTRAIT_SZ)
	_portrait.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_panel.add_child(_portrait)

	var text_x: float = PORTRAIT_SZ + 16.0   # 80px

	# Name label
	_name_lbl = Label.new()
	_name_lbl.position = Vector2(text_x, 8.0)
	_name_lbl.size     = Vector2(200.0, 18.0)
	_name_lbl.add_theme_font_size_override("font_size", 13)
	_panel.add_child(_name_lbl)

	# Class · team label (muted)
	_class_lbl = Label.new()
	_class_lbl.position  = Vector2(text_x, 27.0)
	_class_lbl.size      = Vector2(200.0, 14.0)
	_class_lbl.modulate  = Color(0.72, 0.72, 0.72)
	_class_lbl.add_theme_font_size_override("font_size", 10)
	_panel.add_child(_class_lbl)

	var bar_x: float = text_x         # bars start under name
	var num_x: float = bar_x + BAR_W + 4.0

	# HP row
	var hp_prefix := _make_prefix("HP", bar_x, 46.0)
	_panel.add_child(hp_prefix)
	_hp_bg   = _make_bar_bg(bar_x + 22.0, 47.0)
	_hp_fill = _make_bar_fill(bar_x + 22.0, 47.0, Color(0.22, 0.85, 0.32))
	_hp_text = _make_bar_text(num_x + 22.0, 45.0)

	# Energy row
	var en_prefix := _make_prefix("EN", bar_x, 59.0)
	_panel.add_child(en_prefix)
	_en_bg   = _make_bar_bg(bar_x + 22.0, 60.0)
	_en_fill = _make_bar_fill(bar_x + 22.0, 60.0, Color(0.22, 0.55, 1.0))
	_en_text = _make_bar_text(num_x + 22.0, 58.0)

	# Status effects row — BBCode colored chips below the bars
	_status_rtl = RichTextLabel.new()
	_status_rtl.bbcode_enabled           = true
	_status_rtl.fit_content              = true
	_status_rtl.scroll_active            = false
	_status_rtl.position                 = Vector2(bar_x, 76.0)
	_status_rtl.custom_minimum_size      = Vector2(PANEL_W - bar_x - 8.0, 14.0)
	_status_rtl.size                     = Vector2(PANEL_W - bar_x - 8.0, 14.0)
	_status_rtl.add_theme_font_size_override("normal_font_size", 10)
	_panel.add_child(_status_rtl)

## --- Helper builders ---

func _make_prefix(text: String, x: float, y: float) -> Label:
	var lbl := Label.new()
	lbl.text     = text
	lbl.position = Vector2(x, y)
	lbl.size     = Vector2(22.0, 11.0)
	lbl.modulate = Color(0.75, 0.75, 0.75)
	lbl.add_theme_font_size_override("font_size", 9)
	return lbl

func _make_bar_bg(x: float, y: float) -> ColorRect:
	var bg := ColorRect.new()
	bg.position = Vector2(x, y)
	bg.size     = Vector2(BAR_W, BAR_H)
	bg.color    = Color(0.18, 0.18, 0.22)
	_panel.add_child(bg)
	return bg

func _make_bar_fill(x: float, y: float, color: Color) -> ColorRect:
	var fill := ColorRect.new()
	fill.position = Vector2(x, y)
	fill.size     = Vector2(BAR_W, BAR_H)
	fill.color    = color
	_panel.add_child(fill)
	return fill

func _make_bar_text(x: float, y: float) -> Label:
	var lbl := Label.new()
	lbl.position = Vector2(x, y)
	lbl.size     = Vector2(64.0, 12.0)
	lbl.add_theme_font_size_override("font_size", 9)
	_panel.add_child(lbl)
	return lbl

## --- Public API ---

func show_for(unit: Unit3D) -> void:
	if not unit or not unit.data:
		hide_bar()
		return
	var d: CombatantData = unit.data

	_portrait.texture = d.portrait if d.portrait \
		else (load("res://icon.svg") as Texture2D)

	_name_lbl.text = d.character_name if d.character_name != "" \
		else d.archetype_id.replace("_", " ").capitalize()
	_class_lbl.text = "%s  ·  %s" % [d.unit_class, ("Player" if d.is_player_unit else "Enemy")]

	_refresh_bars(unit)
	visible = true

## Call after any HP/energy change to keep bars current without re-running show_for.
func refresh(unit: Unit3D) -> void:
	if visible and is_instance_valid(unit):
		_refresh_bars(unit)

func hide_bar() -> void:
	visible = false

## --- Internal ---

func _refresh_bars(unit: Unit3D) -> void:
	var d: CombatantData = unit.data
	var hp_ratio: float = float(unit.current_hp) / float(d.hp_max) if d.hp_max > 0 else 0.0
	var en_ratio: float = float(unit.current_energy) / float(d.energy_max) if d.energy_max > 0 else 0.0

	_hp_fill.size = Vector2(BAR_W * clampf(hp_ratio, 0.0, 1.0), BAR_H)
	_en_fill.size = Vector2(BAR_W * clampf(en_ratio, 0.0, 1.0), BAR_H)

	_hp_text.text = "%d/%d" % [unit.current_hp, d.hp_max]
	_en_text.text = "%d/%d" % [unit.current_energy, d.energy_max]

	# HP bar color shifts green → yellow → red as HP falls
	if hp_ratio > 0.66:
		_hp_fill.color = Color(0.22, 0.85, 0.32)
	elif hp_ratio > 0.33:
		_hp_fill.color = Color(1.0, 0.80, 0.12)
	else:
		_hp_fill.color = Color(0.95, 0.22, 0.18)

	_refresh_status(unit)

func _refresh_status(unit: Unit3D) -> void:
	if not _status_rtl:
		return
	if unit.stat_effects.is_empty():
		_status_rtl.text = ""
		return
	var parts: PackedStringArray = []
	for e: Dictionary in unit.stat_effects:
		if e["delta"] > 0:
			parts.append("[color=#44ee66]▲ %s[/color]" % e["display_name"])
		else:
			parts.append("[color=#ff5533]▼ %s[/color]" % e["display_name"])
	_status_rtl.text = "  ".join(parts)
