class_name MainMenuManager
extends CanvasLayer

## --- MainMenuManager ---
## Title screen. Two paths: continue an existing save or wipe and start fresh.
## "Continue" is disabled when no save file exists.

const MAP_SCENE_PATH      := "res://scenes/map/MapScene.tscn"
const CREATION_SCENE_PATH := "res://scenes/ui/CharacterCreationScene.tscn"
const SAVE_PATH           := "user://save.json"

var _continue_btn: Button = null

func _ready() -> void:
	layer = 0
	_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := Label.new()
	title.text = "RogueFinder"
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.position = Vector2(0.0, 120.0)
	add_child(title)

	var sub := Label.new()
	sub.text = "a tactical roguelite"
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sub.position = Vector2(0.0, 210.0)
	add_child(sub)

	var btn_w  := 280.0
	var btn_h  := 60.0
	var center := 640.0  # half of 1280 viewport width
	var top_y  := 340.0
	var gap    := 24.0

	_continue_btn = _make_button("Continue", center - btn_w * 0.5, top_y, btn_w, btn_h, _on_continue)
	_continue_btn.disabled = not FileAccess.file_exists(SAVE_PATH)
	add_child(_continue_btn)

	var new_btn := _make_button("Start New Run", center - btn_w * 0.5, top_y + btn_h + gap, btn_w, btn_h, _on_new_run)
	add_child(new_btn)

	# Dev-only shortcut: skips character creation and fills the party with 3
	# randomized PCs so the main game loop can be exercised quickly.
	var test_btn := _make_button("Test New Run", center - btn_w * 0.5, top_y + (btn_h + gap) * 2.0, btn_w, btn_h, _on_test_new_run)
	test_btn.add_theme_color_override("font_color", Color(0.75, 0.6, 0.95))
	add_child(test_btn)

	var quit_btn := _make_button("Quit", center - btn_w * 0.5, top_y + (btn_h + gap) * 3.0, btn_w, btn_h, _on_quit)
	quit_btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	add_child(quit_btn)

func _make_button(label: String, x: float, y: float, w: float, h: float, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.position = Vector2(x, y)
	btn.custom_minimum_size = Vector2(w, h)
	btn.add_theme_font_size_override("font_size", 26)
	btn.pressed.connect(cb)
	return btn

func _on_continue() -> void:
	GameState.load_save()
	get_tree().change_scene_to_file(MAP_SCENE_PATH)

func _on_new_run() -> void:
	GameState.delete_save()
	GameState.reset()
	get_tree().change_scene_to_file(CREATION_SCENE_PATH)

## Dev shortcut — skip character creation and seed `GameState.party` with 3
## fully-randomized PCs (random kindred / class / background / portrait / name).
## Delegates row-level construction to `CharacterCreationManager._build_pc()`
## (static), so any future changes to how a PC is built stay in one place.
func _on_test_new_run() -> void:
	GameState.delete_save()
	GameState.reset()

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var kindred_ids: Array[String] = []
	for k in KindredLibrary.all_kindreds():
		kindred_ids.append(k.kindred_id)
	var class_ids: Array[String] = []
	for c in ClassLibrary.all_classes():
		class_ids.append(c.class_id)
	var bg_ids: Array[String] = []
	for b in BackgroundLibrary.all_backgrounds():
		bg_ids.append(b.background_id)
	var portrait_ids: Array[String] = []
	for p in PortraitLibrary.all_portraits():
		portrait_ids.append(p.portrait_id)

	for i in 3:
		var k_id: String = kindred_ids[rng.randi() % kindred_ids.size()] if not kindred_ids.is_empty() else ""
		var c_id: String = class_ids[rng.randi() % class_ids.size()]       if not class_ids.is_empty()   else ""
		var b_id: String = bg_ids[rng.randi() % bg_ids.size()]             if not bg_ids.is_empty()      else ""
		var p_id: String = portrait_ids[rng.randi() % portrait_ids.size()] if not portrait_ids.is_empty() else ""
		var pool: Array[String] = KindredLibrary.get_name_pool(k_id)
		var member_name: String = pool[rng.randi() % pool.size()] if not pool.is_empty() else "Test%d" % (i + 1)
		GameState.party.append(CharacterCreationManager._build_pc(member_name, k_id, c_id, b_id, p_id))

	get_tree().change_scene_to_file(MAP_SCENE_PATH)

func _on_quit() -> void:
	get_tree().quit()
