extends Node2D

func _ready() -> void:
	var type_name: String = GameState.pending_node_type.capitalize()
	GameState.pending_node_type = ""  # consume immediately

	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var lbl := Label.new()
	lbl.text = "[" + type_name + " Node]\nNot yet implemented."
	lbl.add_theme_font_size_override("font_size", 36)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_CENTER)
	add_child(lbl)

	var btn := Button.new()
	btn.text = "← Return to Map"
	btn.custom_minimum_size = Vector2(220.0, 50.0)
	btn.position = Vector2(512.0 - 110.0, 420.0)
	btn.add_theme_font_size_override("font_size", 20)
	btn.pressed.connect(_on_return_pressed)
	add_child(btn)

func _on_return_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/map/MapScene.tscn")
