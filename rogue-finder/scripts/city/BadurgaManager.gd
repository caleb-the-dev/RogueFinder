class_name BadurgaManager
extends Node2D

## --- Constants ---

const VIEWPORT_SIZE := Vector2(1280.0, 720.0)

## Each entry: [button label, stub id printed to output when pressed]
const SECTIONS: Array = [
	["The Broken Compass  [Tavern]",         "tavern"],
	["Bulletin Board",                       "bulletin"],
	["Ironmonger's Stall  [Weapons]",        "vendor_weapon"],
	["Seamstress & Leatherworks  [Armor]",   "vendor_armor"],
	["The Curio Dealer  [Accessories]",      "vendor_accessory"],
	["Herbalist's Cart  [Consumables]",      "vendor_consumable"],
]

## --- Lifecycle ---

func _ready() -> void:
	_add_background()
	_add_title()
	_add_section_buttons()
	_add_return_button()

## --- Scene Construction ---

func _add_background() -> void:
	# Dark stone tone — deliberately distinct from the map's sand parchment
	var bg := ColorRect.new()
	bg.size = VIEWPORT_SIZE
	bg.color = Color(0.12, 0.10, 0.14)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

func _add_title() -> void:
	var title := Label.new()
	title.text = "Badurga"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(VIEWPORT_SIZE.x, 80.0)
	title.position = Vector2(0.0, 40.0)
	var s := LabelSettings.new()
	s.font_size = 48
	s.font_color = Color(0.95, 0.88, 0.65)
	title.label_settings = s
	add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Hub city at the heart of the road."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.size = Vector2(VIEWPORT_SIZE.x, 30.0)
	subtitle.position = Vector2(0.0, 110.0)
	var ss := LabelSettings.new()
	ss.font_size = 16
	ss.font_color = Color(0.70, 0.65, 0.55)
	subtitle.label_settings = ss
	add_child(subtitle)

func _add_section_buttons() -> void:
	# Stack section buttons in a centered column
	var btn_size := Vector2(480.0, 54.0)
	var spacing := 12.0
	var start_y := 180.0
	var x := (VIEWPORT_SIZE.x - btn_size.x) * 0.5

	for i in range(SECTIONS.size()):
		var entry: Array = SECTIONS[i]
		var label_text: String = entry[0]
		var stub_id: String = entry[1]

		var btn := Button.new()
		btn.text = label_text
		btn.custom_minimum_size = btn_size
		btn.size = btn_size
		btn.position = Vector2(x, start_y + i * (btn_size.y + spacing))
		btn.add_theme_font_size_override("font_size", 18)
		btn.pressed.connect(_on_section_pressed.bind(stub_id))
		add_child(btn)

func _add_return_button() -> void:
	var btn := Button.new()
	btn.text = "← Back to the Road"
	btn.custom_minimum_size = Vector2(280.0, 50.0)
	btn.size = Vector2(280.0, 50.0)
	btn.position = Vector2(
		(VIEWPORT_SIZE.x - 280.0) * 0.5,
		VIEWPORT_SIZE.y - 80.0,
	)
	btn.add_theme_font_size_override("font_size", 20)
	btn.pressed.connect(_on_return_pressed)
	add_child(btn)

## --- Callbacks ---

func _on_section_pressed(stub_id: String) -> void:
	print("[Badurga] ", stub_id, " not yet implemented")

func _on_return_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/map/MapScene.tscn")
