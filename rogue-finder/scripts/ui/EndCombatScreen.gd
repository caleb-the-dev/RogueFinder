class_name EndCombatScreen
extends CanvasLayer

## --- EndCombatScreen ---
## Full-screen overlay shown when combat ends.
## Layer 15 — above all other UI (4, 8, 10, 12).
## Build all children in code; no .tscn required.

const MAP_SCENE_PATH := "res://scenes/map/MapScene.tscn"

var _reward_cards:   Array[PanelContainer] = []
var _reward_buttons: Array[Button]         = []

func _init() -> void:
	layer = 15

func _ready() -> void:
	visible = false

## --- Public API ---

func show_victory(reward_items: Array) -> void:
	_build_victory_layout(reward_items)
	visible = true

## --- Victory Layout ---

func _build_victory_layout(items: Array) -> void:
	var bg := _make_background()
	add_child(bg)

	var header := Label.new()
	header.text                   = "VICTORY"
	header.add_theme_font_size_override("font_size", 64)
	header.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	header.horizontal_alignment   = HORIZONTAL_ALIGNMENT_CENTER
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.position = Vector2(0.0, 120.0)
	bg.add_child(header)

	var subtitle := Label.new()
	subtitle.text                 = "Choose your reward:"
	subtitle.add_theme_font_size_override("font_size", 22)
	subtitle.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.set_anchors_preset(Control.PRESET_TOP_WIDE)
	subtitle.position = Vector2(0.0, 210.0)
	bg.add_child(subtitle)

	var card_w := 260.0
	var card_h := 130.0
	var gap    := 30.0
	var total_w := card_w * 3.0 + gap * 2.0
	var start_x := (1152.0 - total_w) / 2.0
	var card_y  := 280.0

	_reward_cards.clear()
	_reward_buttons.clear()
	for i in range(items.size()):
		var item: Dictionary = items[i]
		var rarity: int = item.get("rarity", EquipmentData.Rarity.COMMON)
		var rarity_col: Color = EquipmentData.RARITY_COLORS.get(rarity, EquipmentData.RARITY_COLORS[0])

		var card := _build_reward_card(item, rarity_col, card_w, card_h)
		card.position = Vector2(start_x + i * (card_w + gap), card_y)
		bg.add_child(card)
		_reward_cards.append(card)


func _build_reward_card(item: Dictionary, rarity_col: Color, w: float, h: float) -> PanelContainer:
	var rarity: int = item.get("rarity", EquipmentData.Rarity.COMMON)
	var rarity_col2: Color = EquipmentData.RARITY_COLORS.get(rarity, EquipmentData.RARITY_COLORS[0])

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(w, h)

	var sbox := StyleBoxFlat.new()
	sbox.bg_color = Color(0.10, 0.09, 0.08, 0.92)
	sbox.border_width_left   = 2; sbox.border_width_top    = 2
	sbox.border_width_right  = 2; sbox.border_width_bottom = 2
	sbox.border_color = rarity_col2
	sbox.set_corner_radius_all(4)
	card.add_theme_stylebox_override("panel", sbox)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = item.get("name", "?")
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", rarity_col2)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = item.get("description", "")
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.add_theme_color_override("font_color", Color(0.82, 0.80, 0.74))
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_lbl)

	# Invisible button covers the card for click detection
	var btn := Button.new()
	btn.flat = true
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.pressed.connect(_on_reward_chosen.bind(item, card, name_lbl, desc_lbl))
	card.add_child(btn)
	_reward_buttons.append(btn)

	return card


func _on_reward_chosen(item: Dictionary, card: PanelContainer, name_lbl: Label, desc_lbl: Label) -> void:
	if GameState.has_method("add_to_inventory"):
		GameState.add_to_inventory(item)
	for btn in _reward_buttons:
		btn.disabled = true
	name_lbl.text = "✓ " + item.get("name", "?")
	desc_lbl.text = item.get("description", "")
	# Highlight chosen card with a brighter border
	var sbox := card.get_theme_stylebox("panel") as StyleBoxFlat
	if sbox != null:
		sbox.border_width_left   = 3; sbox.border_width_top    = 3
		sbox.border_width_right  = 3; sbox.border_width_bottom = 3
	if not GameState.current_combat_node_id.is_empty():
		if not GameState.cleared_nodes.has(GameState.current_combat_node_id):
			GameState.cleared_nodes.append(GameState.current_combat_node_id)
		if GameState.node_types.get(GameState.current_combat_node_id, "") == "BOSS":
			GameState.threat_level = 0.0
	GameState.save()
	_return_to_map()

## --- Helpers ---

func _make_background() -> ColorRect:
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.75)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	return bg

func _return_to_map() -> void:
	get_tree().change_scene_to_file(MAP_SCENE_PATH)
