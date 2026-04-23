class_name CombatActionPanel
extends CanvasLayer

## --- CombatActionPanel ---
## Right-side slide-in panel shown when a unit is selected in combat.
## Player units: interactive abilities + consumable + stride hint.
## Enemy units: read-only HP/EN/abilities (hoverable for tooltips).
## Layer 12: above UnitInfoBar (4) and StatPanel (8), below confirm dialog (20).

signal ability_selected(ability_id: String)
signal consumable_selected()

const PANEL_WIDTH:   float = 240.0
const SLIDE_TIME:    float = 0.15
const PORTRAIT_SIZE: float = 72.0
const TOOLTIP_W:     float = 220.0
const VP_W:          float = 1280.0
const VP_H:          float = 720.0

var _panel:          PanelContainer  = null
var _vbox:           VBoxContainer   = null
var _name_label:     Label           = null
var _kindred_label:  Label           = null
var _portrait:       TextureRect     = null
var _hp_bar_fill:    ColorRect       = null
var _hp_text:        Label           = null
var _en_bar_fill:    ColorRect       = null
var _en_text:        Label           = null
var _status_rtl:     RichTextLabel   = null
var _ability_grid:   GridContainer   = null
var _ability_btns:   Array[Button]   = []
var _consumable_wrap: Control        = null
var _consumable_btn: Button          = null
var _stride_label:   Label           = null
var _tooltip_panel:  PanelContainer  = null
var _tooltip_rtl:    RichTextLabel   = null
var _current_unit:   Unit3D          = null
var _ability_ids:    Array[String]   = []
var _tween:          Tween           = null

var current_unit: Unit3D:
	get: return _current_unit

func _ready() -> void:
	layer = 12
	_build_ui()
	visible = false

## --- UI Construction ---

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	_panel.position = Vector2(VP_W, 40.0)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   10)
	margin.add_theme_constant_override("margin_right",  10)
	margin.add_theme_constant_override("margin_top",    10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_panel.add_child(margin)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 5)
	margin.add_child(_vbox)

	# Name — centered, prominent
	_name_label = Label.new()
	_name_label.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.add_theme_font_size_override("font_size", 15)
	_vbox.add_child(_name_label)

	# Kindred — centered, small, muted
	_kindred_label = Label.new()
	_kindred_label.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	_kindred_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_kindred_label.add_theme_font_size_override("font_size", 10)
	_kindred_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	_vbox.add_child(_kindred_label)

	# Portrait — centered
	var portrait_center := CenterContainer.new()
	_vbox.add_child(portrait_center)
	_portrait = TextureRect.new()
	_portrait.texture             = load("res://icon.svg")
	_portrait.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	_portrait.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_center.add_child(_portrait)

	# HP bar row
	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 4)
	_vbox.add_child(hp_row)

	var hp_pfx := Label.new()
	hp_pfx.text = "HP"
	hp_pfx.custom_minimum_size = Vector2(24, 12)
	hp_pfx.add_theme_font_size_override("font_size", 9)
	hp_pfx.add_theme_color_override("font_color", Color(0.72, 0.72, 0.72))
	hp_pfx.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_row.add_child(hp_pfx)

	var hp_wrap := Control.new()
	hp_wrap.custom_minimum_size     = Vector2(100, 10)
	hp_wrap.size_flags_horizontal   = Control.SIZE_EXPAND_FILL
	hp_row.add_child(hp_wrap)

	var hp_bg := ColorRect.new()
	hp_bg.color = Color(0.15, 0.15, 0.20)
	hp_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp_wrap.add_child(hp_bg)

	_hp_bar_fill = ColorRect.new()
	_hp_bar_fill.color         = Color(0.22, 0.85, 0.32)
	_hp_bar_fill.anchor_top    = 0.0
	_hp_bar_fill.anchor_bottom = 1.0
	_hp_bar_fill.anchor_left   = 0.0
	_hp_bar_fill.anchor_right  = 1.0
	hp_wrap.add_child(_hp_bar_fill)

	_hp_text = Label.new()
	_hp_text.custom_minimum_size     = Vector2(52, 0)
	_hp_text.add_theme_font_size_override("font_size", 9)
	_hp_text.horizontal_alignment    = HORIZONTAL_ALIGNMENT_RIGHT
	_hp_text.vertical_alignment      = VERTICAL_ALIGNMENT_CENTER
	hp_row.add_child(_hp_text)

	# EN bar row
	var en_row := HBoxContainer.new()
	en_row.add_theme_constant_override("separation", 4)
	_vbox.add_child(en_row)

	var en_pfx := Label.new()
	en_pfx.text = "EN"
	en_pfx.custom_minimum_size = Vector2(24, 12)
	en_pfx.add_theme_font_size_override("font_size", 9)
	en_pfx.add_theme_color_override("font_color", Color(0.72, 0.72, 0.72))
	en_pfx.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	en_row.add_child(en_pfx)

	var en_wrap := Control.new()
	en_wrap.custom_minimum_size   = Vector2(100, 10)
	en_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	en_row.add_child(en_wrap)

	var en_bg := ColorRect.new()
	en_bg.color = Color(0.15, 0.15, 0.20)
	en_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	en_wrap.add_child(en_bg)

	_en_bar_fill = ColorRect.new()
	_en_bar_fill.color         = Color(0.22, 0.55, 1.0)
	_en_bar_fill.anchor_top    = 0.0
	_en_bar_fill.anchor_bottom = 1.0
	_en_bar_fill.anchor_left   = 0.0
	_en_bar_fill.anchor_right  = 1.0
	en_wrap.add_child(_en_bar_fill)

	_en_text = Label.new()
	_en_text.custom_minimum_size     = Vector2(52, 0)
	_en_text.add_theme_font_size_override("font_size", 9)
	_en_text.horizontal_alignment    = HORIZONTAL_ALIGNMENT_RIGHT
	_en_text.vertical_alignment      = VERTICAL_ALIGNMENT_CENTER
	en_row.add_child(_en_text)

	# Status effects
	_status_rtl = RichTextLabel.new()
	_status_rtl.bbcode_enabled  = true
	_status_rtl.fit_content     = true
	_status_rtl.scroll_active   = false
	_status_rtl.add_theme_font_size_override("normal_font_size", 10)
	_vbox.add_child(_status_rtl)

	# Abilities
	_vbox.add_child(HSeparator.new())

	var ab_lbl := Label.new()
	ab_lbl.text = "Abilities"
	ab_lbl.add_theme_font_size_override("font_size", 10)
	ab_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_vbox.add_child(ab_lbl)

	_ability_grid = GridContainer.new()
	_ability_grid.columns = 2
	_ability_grid.add_theme_constant_override("h_separation", 4)
	_ability_grid.add_theme_constant_override("v_separation", 4)
	_vbox.add_child(_ability_grid)

	# Consumable — hidden for enemies
	_vbox.add_child(HSeparator.new())

	_consumable_wrap = Control.new()
	_consumable_wrap.custom_minimum_size   = Vector2(0, 36)
	_consumable_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.add_child(_consumable_wrap)

	_consumable_btn = Button.new()
	_consumable_btn.add_theme_font_size_override("font_size", 11)
	_consumable_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_consumable_btn.pressed.connect(_on_consumable_pressed)
	_consumable_btn.mouse_entered.connect(_on_consumable_hover)
	_consumable_btn.mouse_exited.connect(_hide_tooltip)
	_consumable_wrap.add_child(_consumable_btn)

	# Stride hint — hidden for enemies
	_stride_label = Label.new()
	_stride_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stride_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stride_label.add_theme_font_size_override("font_size", 10)
	_stride_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_vbox.add_child(_stride_label)

	# Dialogue stub — reserved for future combat banter
	_vbox.add_child(HSeparator.new())

	var dlg_bg := PanelContainer.new()
	dlg_bg.custom_minimum_size = Vector2(0, 44)
	_vbox.add_child(dlg_bg)

	var dlg_lbl := Label.new()
	dlg_lbl.text = "..."
	dlg_lbl.add_theme_font_size_override("font_size", 11)
	dlg_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45))
	dlg_lbl.horizontal_alignment    = HORIZONTAL_ALIGNMENT_CENTER
	dlg_lbl.vertical_alignment      = VERTICAL_ALIGNMENT_CENTER
	dlg_lbl.size_flags_horizontal   = Control.SIZE_EXPAND_FILL
	dlg_lbl.size_flags_vertical     = Control.SIZE_EXPAND_FILL
	dlg_bg.add_child(dlg_lbl)

	# Tooltip — direct child of CanvasLayer so it can float freely
	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.custom_minimum_size = Vector2(TOOLTIP_W, 0)
	_tooltip_panel.visible = false
	add_child(_tooltip_panel)

	var tooltip_margin := MarginContainer.new()
	tooltip_margin.add_theme_constant_override("margin_left",   6)
	tooltip_margin.add_theme_constant_override("margin_right",  6)
	tooltip_margin.add_theme_constant_override("margin_top",    4)
	tooltip_margin.add_theme_constant_override("margin_bottom", 4)
	_tooltip_panel.add_child(tooltip_margin)

	_tooltip_rtl = RichTextLabel.new()
	_tooltip_rtl.bbcode_enabled  = true
	_tooltip_rtl.fit_content     = true
	_tooltip_rtl.scroll_active   = false
	_tooltip_rtl.add_theme_font_size_override("normal_font_size", 11)
	_tooltip_rtl.custom_minimum_size = Vector2(TOOLTIP_W - 16, 0)
	tooltip_margin.add_child(_tooltip_rtl)

## --- Public API ---

func open_for(unit: Unit3D, _camera: Camera3D) -> void:
	var was_open: bool = visible
	_current_unit  = unit
	_ability_ids   = unit.data.abilities.duplicate()
	_populate(unit)
	if was_open:
		_slide_in()   # kill any pending close tween; stay/return to visible position
	else:
		_panel.position.x = VP_W
		visible = true
		_slide_in()

func close() -> void:
	if not visible:
		return
	_slide_out()

func refresh(unit: Unit3D) -> void:
	if visible and is_instance_valid(unit) and _current_unit == unit:
		_refresh_bars(unit)
		_refresh_status(unit)
		_refresh_consumable(unit)
		_refresh_stride(unit)

## --- Population ---

func _populate(unit: Unit3D) -> void:
	_name_label.text = unit.data.character_name if unit.data.character_name != "" \
		else unit.data.archetype_id.replace("_", " ").capitalize()
	_kindred_label.text = unit.data.kindred if unit.data.kindred != "" else "Unknown"

	_portrait.texture = (unit.data.portrait as Texture2D) if unit.data.portrait \
		else (load("res://icon.svg") as Texture2D)

	_refresh_bars(unit)
	_refresh_status(unit)
	_rebuild_ability_grid(unit)
	_refresh_consumable(unit)
	_refresh_stride(unit)

func _refresh_bars(unit: Unit3D) -> void:
	var d: CombatantData = unit.data
	var hp_ratio: float = float(unit.current_hp) / float(d.hp_max)      if d.hp_max      > 0 else 0.0
	var en_ratio: float = float(unit.current_energy) / float(d.energy_max) if d.energy_max > 0 else 0.0

	_hp_bar_fill.anchor_right = clampf(hp_ratio, 0.0, 1.0)
	_en_bar_fill.anchor_right = clampf(en_ratio, 0.0, 1.0)

	_hp_text.text = "%d/%d" % [unit.current_hp,     d.hp_max]
	_en_text.text = "%d/%d" % [unit.current_energy, d.energy_max]

	if hp_ratio > 0.66:
		_hp_bar_fill.color = Color(0.22, 0.85, 0.32)
	elif hp_ratio > 0.33:
		_hp_bar_fill.color = Color(1.0, 0.80, 0.12)
	else:
		_hp_bar_fill.color = Color(0.95, 0.22, 0.18)

func _refresh_status(unit: Unit3D) -> void:
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

func _rebuild_ability_grid(unit: Unit3D) -> void:
	for btn: Button in _ability_btns:
		btn.queue_free()
	_ability_btns.clear()

	var is_player: bool = unit.data.is_player_unit

	for i in range(_ability_ids.size()):
		var ability_id: String = _ability_ids[i]
		var btn := Button.new()
		btn.custom_minimum_size   = Vector2(0, 46)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 10)

		if ability_id == "":
			btn.text     = "—"
			btn.disabled = true
			btn.modulate = Color(0.4, 0.4, 0.4, 0.6)
		else:
			var ability: AbilityData = AbilityLibrary.get_ability(ability_id)
			var can_use: bool = is_player and (not unit.has_acted) \
				and (unit.current_energy >= ability.energy_cost)
			btn.text     = "%s\n%dE · %s" % [ability.ability_name, ability.energy_cost, _shape_abbr(ability)]
			btn.disabled = not can_use or not is_player
			btn.modulate = Color.WHITE if can_use else Color(0.5, 0.5, 0.5, 0.8)
			btn.mouse_entered.connect(_on_ability_hover.bind(i))
			btn.mouse_exited.connect(_hide_tooltip)
			if is_player:
				btn.pressed.connect(_on_ability_pressed.bind(i))

		_ability_grid.add_child(btn)
		_ability_btns.append(btn)

func _refresh_consumable(unit: Unit3D) -> void:
	if not unit.data.is_player_unit:
		_consumable_wrap.visible = false
		return
	var has_item: bool = unit.data.consumable != ""
	_consumable_wrap.visible = has_item
	if has_item:
		var con: ConsumableData = ConsumableLibrary.get_consumable(unit.data.consumable)
		_consumable_btn.text     = "Use: %s" % con.consumable_name
		_consumable_btn.disabled = unit.has_acted
		_consumable_btn.modulate = Color.WHITE if not unit.has_acted else Color(0.5, 0.5, 0.5, 0.8)

func _refresh_stride(unit: Unit3D) -> void:
	if not unit.data.is_player_unit:
		_stride_label.visible = false
		return
	_stride_label.visible = true
	if unit.remaining_move > 0:
		_stride_label.text = "Click to stride · %d tile%s left" % [
			unit.remaining_move,
			"s" if unit.remaining_move != 1 else ""
		]
		_stride_label.add_theme_color_override("font_color", Color(0.55, 0.75, 0.55))
	else:
		_stride_label.text = "No movement remaining"
		_stride_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))

## --- Animations ---

func _slide_in() -> void:
	if _tween:
		_tween.kill()
	var target_x: float = VP_W - PANEL_WIDTH - 8.0
	_tween = create_tween()
	_tween.tween_property(_panel, "position:x", target_x, SLIDE_TIME) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func _slide_out() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_panel, "position:x", VP_W, SLIDE_TIME) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_tween.finished.connect(func() -> void: visible = false)
	_current_unit = null

## --- Tooltip ---

func _on_ability_hover(index: int) -> void:
	if index >= _ability_ids.size() or index >= _ability_btns.size():
		return
	var ability_id: String = _ability_ids[index]
	if ability_id == "":
		return
	var ability: AbilityData = AbilityLibrary.get_ability(ability_id)
	var range_str: String = "%d tiles" % ability.tile_range if ability.tile_range != -1 else "Unlimited"
	var text: String = "[b]%s[/b]  [%dE]  ·  %s  ·  %s\n%s" % [
		ability.ability_name, ability.energy_cost,
		_shape_abbr(ability), range_str,
		ability.description
	]
	_show_tooltip(text, _ability_btns[index])

func _on_consumable_hover() -> void:
	if not _current_unit or _current_unit.data.consumable == "":
		return
	var con: ConsumableData = ConsumableLibrary.get_consumable(_current_unit.data.consumable)
	_show_tooltip("[b]%s[/b]\n%s" % [con.consumable_name, con.description], _consumable_btn)

func _show_tooltip(text: String, near_btn: Control) -> void:
	_tooltip_rtl.text = text
	var btn_rect: Rect2 = near_btn.get_global_rect()
	var tx: float = btn_rect.position.x - TOOLTIP_W - 8.0
	var ty: float = btn_rect.position.y
	_tooltip_panel.position = Vector2(
		clampf(tx, 0.0, VP_W - TOOLTIP_W),
		clampf(ty, 0.0, VP_H - 100.0)
	)
	_tooltip_panel.visible = true

func _hide_tooltip() -> void:
	_tooltip_panel.visible = false

## --- Button Callbacks ---

func _on_ability_pressed(index: int) -> void:
	var ability_id: String = _ability_ids[index] if index < _ability_ids.size() else ""
	if ability_id == "":
		return
	close()
	ability_selected.emit(ability_id)

func _on_consumable_pressed() -> void:
	# Don't close — CombatManager3D calls open_for() after applying the effect to refresh
	consumable_selected.emit()

## --- Helpers ---

func _shape_abbr(ability: AbilityData) -> String:
	match ability.target_shape:
		AbilityData.TargetShape.SELF:   return "Self"
		AbilityData.TargetShape.SINGLE: return "Single"
		AbilityData.TargetShape.CONE:   return "Cone"
		AbilityData.TargetShape.LINE:   return "Line"
		AbilityData.TargetShape.RADIAL: return "Radial"
		AbilityData.TargetShape.ARC:    return "Arc"
		_: return "?"
