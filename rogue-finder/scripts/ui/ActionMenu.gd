class_name ActionMenu
extends CanvasLayer

## --- ActionMenu ---
## D-pad radial pop-up: 4 ability buttons (up/right/bottom/left) + 1 consumable (center).
## Shown when a player unit is selected; hidden on deselect or action choice.
## Layer 12: above UnitInfoBar (4) and StatPanel (8), below confirm dialog (20).
##
## open_for() positions the menu at the unit's projected screen position.
## ability_selected(ability_id) and consumable_selected() are the only outputs.

signal ability_selected(ability_id: String)
signal consumable_selected()

const BTN_SIZE:    float = 80.0
const CON_SIZE:    float = 64.0
const BTN_OFFSET:  float = 100.0  ## distance from center to ability button center
const TOOLTIP_W:   float = 240.0
const TOOLTIP_H:   float = 72.0

## Approximate viewport dimensions for clamping (matches current project setup)
const VP_W: float = 1280.0
const VP_H: float = 720.0

var _root:             Control         = null
var _ability_buttons:  Array[Button]   = []
var _consumable_btn:   Button          = null
var _tooltip_panel:    ColorRect       = null
var _tooltip_label:    Label           = null
var _current_unit:     Unit3D          = null
var _ability_ids:      Array[String]   = []

## Cardinal offsets: top, right, bottom, left
## GDScript 4 does not support typed Array constants — static var used instead.
static var _OFFSETS: Array[Vector2] = [
	Vector2(0.0,         -BTN_OFFSET),
	Vector2(BTN_OFFSET,   0.0),
	Vector2(0.0,          BTN_OFFSET),
	Vector2(-BTN_OFFSET,  0.0),
]

func _ready() -> void:
	layer = 12
	_build_ui()
	visible = false

## --- UI Construction ---

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# 4 ability buttons
	for i in range(4):
		var btn := Button.new()
		btn.size = Vector2(BTN_SIZE, BTN_SIZE)
		btn.add_theme_font_size_override("font_size", 10)
		btn.mouse_entered.connect(_on_ability_hover.bind(i))
		btn.mouse_exited.connect(_on_hover_exit)
		btn.pressed.connect(_on_ability_pressed.bind(i))
		_root.add_child(btn)
		_ability_buttons.append(btn)

	# Center consumable button (slightly smaller)
	_consumable_btn = Button.new()
	_consumable_btn.size = Vector2(CON_SIZE, CON_SIZE)
	_consumable_btn.add_theme_font_size_override("font_size", 9)
	_consumable_btn.mouse_entered.connect(_on_consumable_hover)
	_consumable_btn.mouse_exited.connect(_on_hover_exit)
	_consumable_btn.pressed.connect(_on_consumable_pressed)
	_root.add_child(_consumable_btn)

	# Tooltip: dark panel + label, rendered above everything in the menu
	_tooltip_panel = ColorRect.new()
	_tooltip_panel.color   = Color(0.04, 0.05, 0.12, 0.95)
	_tooltip_panel.size    = Vector2(TOOLTIP_W, TOOLTIP_H)
	_tooltip_panel.visible = false
	_root.add_child(_tooltip_panel)

	_tooltip_label = Label.new()
	_tooltip_label.position = Vector2(6.0, 4.0)
	_tooltip_label.size     = Vector2(TOOLTIP_W - 12.0, TOOLTIP_H - 8.0)
	_tooltip_label.add_theme_font_size_override("font_size", 10)
	_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_panel.add_child(_tooltip_label)

## --- Public API ---

## Show the menu centered on the unit's projected screen position.
## camera: pass _camera_rig.get_camera() from CombatManager3D.
func open_for(unit: Unit3D, camera: Camera3D) -> void:
	_current_unit = unit
	# CombatantData.abilities is always exactly 4 elements — see CombatantData.gd
	_ability_ids  = unit.data.abilities.duplicate()

	# Project 3D world pos to 2D screen, then clamp so menu never clips
	var raw: Vector2    = camera.unproject_position(unit.global_position)
	var half: float     = BTN_OFFSET + BTN_SIZE * 0.5
	var center: Vector2 = Vector2(
		clampf(raw.x, half, VP_W - half),
		clampf(raw.y, half, VP_H - half)
	)

	# Position ability buttons
	for i in range(4):
		var btn: Button      = _ability_buttons[i]
		var btn_offset: Vector2 = _OFFSETS[i]
		var btn_center: Vector2 = center + btn_offset
		btn.position = btn_center - Vector2(BTN_SIZE * 0.5, BTN_SIZE * 0.5)
		_refresh_ability_button(btn, i, unit)

	# Position consumable button
	_consumable_btn.position = center - Vector2(CON_SIZE * 0.5, CON_SIZE * 0.5)
	_refresh_consumable_button(unit)

	_tooltip_panel.visible = false
	visible = true

func close() -> void:
	_tooltip_panel.visible = false
	visible                = false
	_current_unit          = null

## --- Button population helpers ---

func _refresh_ability_button(btn: Button, index: int, unit: Unit3D) -> void:
	var ability_id: String = _ability_ids[index] if index < _ability_ids.size() else ""
	if ability_id == "":
		btn.text     = "—"
		btn.disabled = true
		btn.modulate = Color(0.5, 0.5, 0.5, 0.7)
		return

	var ability: AbilityData = AbilityLibrary.get_ability(ability_id)
	# Grey out if the unit has already used their action OR can't afford the cost
	var can_use: bool = (not unit.has_acted) and (unit.current_energy >= ability.energy_cost)
	btn.text     = "%s\n%dE" % [ability.ability_name, ability.energy_cost]
	btn.disabled = not can_use
	btn.modulate = Color.WHITE if can_use else Color(0.5, 0.5, 0.5, 0.7)

func _refresh_consumable_button(unit: Unit3D) -> void:
	var has_item: bool       = unit.data.consumable != ""
	_consumable_btn.text     = unit.data.consumable if has_item else "—"
	_consumable_btn.disabled = not has_item
	_consumable_btn.modulate = Color.WHITE if has_item else Color(0.5, 0.5, 0.5, 0.7)

## --- Button callbacks ---

func _on_ability_pressed(index: int) -> void:
	var ability_id: String = _ability_ids[index] if index < _ability_ids.size() else ""
	if ability_id == "":
		return
	close()
	ability_selected.emit(ability_id)

func _on_consumable_pressed() -> void:
	close()
	consumable_selected.emit()

## --- Tooltip ---

func _on_ability_hover(index: int) -> void:
	var ability_id: String = _ability_ids[index] if index < _ability_ids.size() else ""
	if ability_id == "":
		return
	var ability: AbilityData = AbilityLibrary.get_ability(ability_id)
	var tags_str: String     = ", ".join(ability.tags) if not ability.tags.is_empty() else ""
	var text: String = "%s  [%s]  %dE\n%s" % [
		ability.ability_name, tags_str, ability.energy_cost, ability.description
	]
	_show_tooltip(text, _ability_buttons[index].position + Vector2(BTN_SIZE * 0.5, -TOOLTIP_H - 6.0))

func _on_consumable_hover() -> void:
	if not _current_unit or _current_unit.data.consumable == "":
		return
	_show_tooltip(
		_current_unit.data.consumable + "\n(Consumable — use to activate effect)",
		_consumable_btn.position + Vector2(CON_SIZE * 0.5, -TOOLTIP_H - 6.0)
	)

func _on_hover_exit() -> void:
	_tooltip_panel.visible = false

func _show_tooltip(text: String, pos: Vector2) -> void:
	_tooltip_label.text    = text
	_tooltip_panel.position = Vector2(
		clampf(pos.x - TOOLTIP_W * 0.5, 0.0, VP_W - TOOLTIP_W),
		clampf(pos.y, 0.0, VP_H - TOOLTIP_H)
	)
	_tooltip_panel.visible = true
