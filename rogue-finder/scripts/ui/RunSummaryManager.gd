class_name RunSummaryManager
extends CanvasLayer

## --- RunSummaryManager ---
## Shown after a run-ending defeat. Reads GameState.run_summary for stats,
## then offers three exits: start new run, main menu (stub), or quit.

const MAP_SCENE_PATH  := "res://scenes/map/MapScene.tscn"
const MENU_SCENE_PATH := "res://scenes/ui/MainMenuScene.tscn"

func _ready() -> void:
	layer = 10
	_build_ui()

func _build_ui() -> void:
	var summary: Dictionary = GameState.run_summary

	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.06, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var header := Label.new()
	header.text = "Run Over"
	header.add_theme_font_size_override("font_size", 56)
	header.add_theme_color_override("font_color", Color(0.85, 0.15, 0.15))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.position = Vector2(0.0, 80.0)
	add_child(header)

	var pc_name: String = summary.get("pc_name", "The RogueFinder")
	var sub := Label.new()
	sub.text = "%s has fallen." % pc_name
	sub.add_theme_font_size_override("font_size", 26)
	sub.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sub.position = Vector2(0.0, 160.0)
	add_child(sub)

	var fallen: Array = summary.get("fallen_allies", [])
	var allies_text: String = ", ".join(fallen) if not fallen.is_empty() else "None"
	var stat_lines: Array[String] = [
		"Nodes Visited:  %d" % summary.get("nodes_visited", 0),
		"Nodes Cleared:  %d" % summary.get("nodes_cleared", 0),
		"Threat Level:   %.0f%%" % (summary.get("threat_level", 0.0) * 100.0),
		"Allies Lost:    %s" % allies_text,
	]

	var stat_y := 250.0
	for line in stat_lines:
		var lbl := Label.new()
		lbl.text = line
		lbl.add_theme_font_size_override("font_size", 22)
		lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
		lbl.position = Vector2(0.0, stat_y)
		add_child(lbl)
		stat_y += 44.0

	var btn_configs: Array[Dictionary] = [
		{"text": "Start New Run", "cb": _on_new_run},
		{"text": "Main Menu",     "cb": _on_main_menu},
		{"text": "Quit Game",     "cb": _on_quit},
	]
	var btn_w  := 200.0
	var btn_h  := 55.0
	var gap    := 30.0
	var total  := btn_w * 3.0 + gap * 2.0
	var btn_x  := (1152.0 - total) / 2.0
	var btn_y  := stat_y + 60.0

	for i in range(btn_configs.size()):
		var cfg: Dictionary = btn_configs[i]
		var btn := Button.new()
		btn.text = cfg["text"]
		btn.custom_minimum_size = Vector2(btn_w, btn_h)
		btn.position = Vector2(btn_x + i * (btn_w + gap), btn_y)
		btn.add_theme_font_size_override("font_size", 20)
		btn.pressed.connect(cfg["cb"])
		add_child(btn)

func _on_new_run() -> void:
	GameState.reset()
	GameState.delete_save()
	get_tree().change_scene_to_file(MAP_SCENE_PATH)

func _on_main_menu() -> void:
	GameState.reset()
	GameState.delete_save()
	get_tree().change_scene_to_file(MENU_SCENE_PATH)

func _on_quit() -> void:
	get_tree().quit()
