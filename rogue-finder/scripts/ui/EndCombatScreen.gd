class_name EndCombatScreen
extends CanvasLayer

## --- EndCombatScreen ---
## Full-screen overlay shown when combat ends.
## Layer 15 — above all other UI (4, 8, 10, 12).
## Build all children in code; no .tscn required.

const SCENE_PATH := "res://scenes/combat/CombatScene3D.tscn"

var _reward_buttons: Array[Button] = []

func _init() -> void:
	layer = 15

func _ready() -> void:
	visible = false

## --- Public API ---

func show_victory(reward_items: Array) -> void:
	_build_victory_layout(reward_items)
	visible = true

func show_defeat() -> void:
	_build_defeat_layout()
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

	# 3 reward buttons centered horizontally
	var button_w := 260.0
	var button_h := 130.0
	var gap      := 30.0
	var total_w  := button_w * 3.0 + gap * 2.0
	var start_x  := (1152.0 - total_w) / 2.0  # approximate 1152 reference width
	var btn_y    := 280.0

	_reward_buttons.clear()
	for i in range(items.size()):
		var item: Dictionary = items[i]
		var btn := Button.new()
		btn.text        = item["name"] + "\n" + item["description"]
		btn.custom_minimum_size = Vector2(button_w, button_h)
		btn.position    = Vector2(start_x + i * (button_w + gap), btn_y)
		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(_on_reward_chosen.bind(item, i))
		bg.add_child(btn)
		_reward_buttons.append(btn)


func _on_reward_chosen(item: Dictionary, _chosen_index: int) -> void:
	print("Reward chosen: ", item["name"])
	if GameState.has_method("add_to_inventory"):
		GameState.add_to_inventory(item)
	_reload_combat()

## --- Defeat Layout ---

func _build_defeat_layout() -> void:
	var bg := _make_background()
	add_child(bg)

	var header := Label.new()
	header.text                   = "DEFEAT"
	header.add_theme_font_size_override("font_size", 64)
	header.add_theme_color_override("font_color", Color(0.9, 0.1, 0.1))
	header.horizontal_alignment   = HORIZONTAL_ALIGNMENT_CENTER
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.position = Vector2(0.0, 120.0)
	bg.add_child(header)

	var subtitle := Label.new()
	subtitle.text                 = "Your run has ended."
	subtitle.add_theme_font_size_override("font_size", 22)
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.set_anchors_preset(Control.PRESET_TOP_WIDE)
	subtitle.position = Vector2(0.0, 210.0)
	bg.add_child(subtitle)

	var retry_btn := Button.new()
	retry_btn.text              = "Try Again"
	retry_btn.custom_minimum_size = Vector2(200.0, 50.0)
	retry_btn.position          = Vector2((1152.0 - 200.0) / 2.0, 300.0)
	retry_btn.add_theme_font_size_override("font_size", 20)
	retry_btn.pressed.connect(_reload_combat)
	bg.add_child(retry_btn)

## --- Helpers ---

func _make_background() -> ColorRect:
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.75)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	return bg

func _reload_combat() -> void:
	get_tree().change_scene_to_file(SCENE_PATH)
