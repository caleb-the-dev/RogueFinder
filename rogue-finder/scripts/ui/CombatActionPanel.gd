class_name CombatActionPanel
extends CanvasLayer

## --- CombatActionPanel ---
## Right-side slide-in panel shown when a player unit is selected.
## Replaces the radial ActionMenu with a fixed panel that auto-fits its content.
## Layer 12: above UnitInfoBar (4) and StatPanel (8), below confirm dialog (20).

signal ability_selected(ability_id: String)
signal consumable_selected()

const PANEL_WIDTH:   float = 220.0
const SLIDE_TIME:    float = 0.15
const PORTRAIT_SIZE: float = 64.0

var _panel:          PanelContainer = null
var _vbox:           VBoxContainer  = null
var _name_label:     Label          = null
var _portrait:       TextureRect    = null
var _abilities_box:  VBoxContainer  = null
var _consumable_btn: Button         = null
var _current_unit:   Unit3D         = null
var _ability_ids:    Array[String]  = []
var _ability_btns:   Array[Button]  = []

## Screen width — used for slide-in positioning.
const VP_W: float = 1280.0
const VP_H: float = 720.0

func _ready() -> void:
	layer = 12
	_build_ui()
	visible = false

## --- UI Construction ---

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	_panel.size_flags_vertical   = Control.SIZE_SHRINK_BEGIN
	# Start fully off-screen to the right
	_panel.position = Vector2(VP_W, 40.0)
	add_child(_panel)

	_vbox = VBoxContainer.new()
	_vbox.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	_vbox.add_theme_constant_override("separation", 6)
	_panel.add_child(_vbox)

	# Portrait row
	var portrait_row := HBoxContainer.new()
	portrait_row.add_theme_constant_override("separation", 8)
	_vbox.add_child(portrait_row)

	_portrait = TextureRect.new()
	_portrait.texture = load("res://icon.svg")
	_portrait.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_row.add_child(_portrait)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 15)
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.size_flags_vertical = Control.SIZE_FILL
	portrait_row.add_child(_name_label)

	# Divider
	var sep := HSeparator.new()
	_vbox.add_child(sep)

	# Abilities section
	var abilities_label := Label.new()
	abilities_label.text = "Abilities"
	abilities_label.add_theme_font_size_override("font_size", 11)
	abilities_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_vbox.add_child(abilities_label)

	_abilities_box = VBoxContainer.new()
	_abilities_box.add_theme_constant_override("separation", 4)
	_vbox.add_child(_abilities_box)

	# Consumable section
	var con_sep := HSeparator.new()
	_vbox.add_child(con_sep)

	_consumable_btn = Button.new()
	_consumable_btn.add_theme_font_size_override("font_size", 12)
	_consumable_btn.pressed.connect(_on_consumable_pressed)
	_consumable_btn.visible = false
	_vbox.add_child(_consumable_btn)

	# Stride hint
	var stride_label := Label.new()
	stride_label.text = "Click anywhere to stride"
	stride_label.add_theme_font_size_override("font_size", 10)
	stride_label.add_theme_color_override("font_color", Color(0.55, 0.75, 0.55))
	stride_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stride_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_vbox.add_child(stride_label)

	# Dialogue stub — reserved for future combat banter
	var dialogue_sep := HSeparator.new()
	_vbox.add_child(dialogue_sep)

	var dialogue_bg := PanelContainer.new()
	dialogue_bg.custom_minimum_size = Vector2(0.0, 48.0)
	_vbox.add_child(dialogue_bg)

	var dialogue_label := Label.new()
	dialogue_label.text = "..."
	dialogue_label.add_theme_font_size_override("font_size", 11)
	dialogue_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialogue_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	dialogue_label.size_flags_horizontal = Control.SIZE_FILL
	dialogue_label.size_flags_vertical   = Control.SIZE_FILL
	dialogue_bg.add_child(dialogue_label)

## --- Public API ---

func open_for(unit: Unit3D, _camera: Camera3D) -> void:
	_current_unit = unit
	_ability_ids  = unit.data.abilities.duplicate()

	_name_label.text = unit.data.character_name if unit.data.character_name != "" \
		else unit.data.archetype_id

	_rebuild_ability_buttons(unit)
	_refresh_consumable(unit)

	visible = true
	_slide_in()

func close() -> void:
	_slide_out()

## --- Slide Animations ---

func _slide_in() -> void:
	var target_x: float = VP_W - PANEL_WIDTH - 8.0
	var tw: Tween = create_tween()
	tw.tween_property(_panel, "position:x", target_x, SLIDE_TIME) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func _slide_out() -> void:
	var tw: Tween = create_tween()
	tw.tween_property(_panel, "position:x", VP_W, SLIDE_TIME) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tw.finished.connect(func() -> void: visible = false)
	_current_unit = null

## --- Population Helpers ---

func _rebuild_ability_buttons(unit: Unit3D) -> void:
	for btn: Button in _ability_btns:
		btn.queue_free()
	_ability_btns.clear()

	for i in range(_ability_ids.size()):
		var ability_id: String = _ability_ids[i]
		if ability_id == "":
			continue
		var ability: AbilityData = AbilityLibrary.get_ability(ability_id)
		var can_use: bool = (not unit.has_acted) and (unit.current_energy >= ability.energy_cost)

		var btn := Button.new()
		btn.text     = "%s  [%dE]" % [ability.ability_name, ability.energy_cost]
		btn.disabled = not can_use
		btn.modulate = Color.WHITE if can_use else Color(0.5, 0.5, 0.5, 0.8)
		btn.custom_minimum_size = Vector2(0.0, 36.0)
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(_on_ability_pressed.bind(i))
		_abilities_box.add_child(btn)
		_ability_btns.append(btn)

func _refresh_consumable(unit: Unit3D) -> void:
	var has_item: bool = unit.data.consumable != ""
	if not has_item:
		_consumable_btn.visible = false
		return
	var con: ConsumableData = ConsumableLibrary.get_consumable(unit.data.consumable)
	_consumable_btn.text    = "Use: %s" % con.consumable_name
	_consumable_btn.visible = true
	_consumable_btn.disabled = unit.has_acted
	_consumable_btn.modulate = Color.WHITE if not unit.has_acted else Color(0.5, 0.5, 0.5, 0.8)

## --- Button Callbacks ---

func _on_ability_pressed(index: int) -> void:
	var ability_id: String = _ability_ids[index] if index < _ability_ids.size() else ""
	if ability_id == "":
		return
	close()
	ability_selected.emit(ability_id)

func _on_consumable_pressed() -> void:
	close()
	consumable_selected.emit()
