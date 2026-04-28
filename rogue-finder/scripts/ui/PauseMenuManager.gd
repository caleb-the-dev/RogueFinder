class_name PauseMenuManager
extends CanvasLayer

## --- PauseMenuManager ---
## Global pause overlay. ESC or ☰ button opens from gameplay scenes.
## process_mode = ALWAYS so input is received in both paused and unpaused states.

signal menu_opened
signal menu_closed
signal settings_changed
signal archetype_log_opened

const PANEL_W: float = 440.0
const PANEL_H: float = 560.0
const VP_W:    float = 1280.0
const VP_H:    float = 720.0

enum _Panel { MAIN, SETTINGS, GUIDE, LOG, CONFIRM }
enum _ArchStatus { UNKNOWN = 0, ENCOUNTERED = 1, FOLLOWER = 2, PLAYER = 3 }

var _is_open:      bool   = false
var _active_panel: _Panel = _Panel.MAIN

var _backdrop:      ColorRect      = null
var _container:     PanelContainer = null
var _title:         Label          = null
var _menu_btn:      Button         = null

var _main_panel:    VBoxContainer  = null
var _settings_panel: VBoxContainer = null
var _guide_panel:   VBoxContainer  = null
var _log_panel:     VBoxContainer  = null
var _confirm_panel: VBoxContainer  = null

var _fs_check:      CheckBox      = null
var _master_slider: HSlider       = null
var _music_slider:  HSlider       = null
var _sfx_slider:    HSlider       = null
var _log_list:      VBoxContainer = null
var _confirm_label: Label         = null
var _confirm_action: Callable     = Callable()

## --- Lifecycle ---

func _ready() -> void:
	layer = 26
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_backdrop.visible  = false
	_container.visible = false

func _process(_delta: float) -> void:
	if _menu_btn != null:
		_menu_btn.visible = not _is_open and _is_pauseable_scene()

## --- Input ---

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key: InputEventKey = event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode != KEY_ESCAPE:
		return
	if not _is_open:
		if _is_pauseable_scene():
			open_menu()
			get_viewport().set_input_as_handled()
		return
	if _active_panel != _Panel.MAIN:
		_show_main()
	else:
		close_menu()
	get_viewport().set_input_as_handled()

func _on_menu_btn_pressed() -> void:
	if _is_open:
		return
	if _is_pauseable_scene():
		open_menu()

## --- Scene Gate ---

func _is_pauseable_scene() -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return false
	return _scene_name_is_pauseable(scene.scene_file_path)

static func _scene_name_is_pauseable(path: String) -> bool:
	if path.ends_with("main.tscn"):
		return false
	if path.ends_with("MainMenuScene.tscn"):
		return false
	if path.ends_with("RunSummaryScene.tscn"):
		return false
	return true

## --- Public API ---

func open_menu() -> void:
	_is_open = true
	_backdrop.visible  = true
	_container.visible = true
	_show_main()
	get_tree().paused = true
	emit_signal("menu_opened")

func close_menu() -> void:
	_is_open = false
	_backdrop.visible  = false
	_container.visible = false
	get_tree().paused = false
	emit_signal("menu_closed")

## --- Panel Switching ---

func _show_main() -> void:
	_active_panel = _Panel.MAIN
	_title.text = "PAUSED"
	_main_panel.visible     = true
	_settings_panel.visible = false
	_guide_panel.visible    = false
	_log_panel.visible      = false
	_confirm_panel.visible  = false

func _show_settings() -> void:
	_active_panel = _Panel.SETTINGS
	_title.text = "Settings"
	_main_panel.visible     = false
	_settings_panel.visible = true
	_guide_panel.visible    = false
	_log_panel.visible      = false
	_confirm_panel.visible  = false
	# set_pressed_no_signal avoids re-firing the toggle handler on panel open.
	_fs_check.set_pressed_no_signal(SettingsStore.fullscreen)
	_master_slider.value = SettingsStore.master_volume
	_music_slider.value  = SettingsStore.music_volume
	_sfx_slider.value    = SettingsStore.sfx_volume

func _show_guide() -> void:
	_active_panel = _Panel.GUIDE
	_title.text = "Guide"
	_main_panel.visible     = false
	_settings_panel.visible = false
	_guide_panel.visible    = true
	_log_panel.visible      = false
	_confirm_panel.visible  = false

func _show_log() -> void:
	_active_panel = _Panel.LOG
	_title.text = "Archetypes Log"
	_main_panel.visible     = false
	_settings_panel.visible = false
	_guide_panel.visible    = false
	_log_panel.visible      = true
	_confirm_panel.visible  = false
	_rebuild_log_list()
	emit_signal("archetype_log_opened")

func _show_confirm(msg: String, action: Callable) -> void:
	_active_panel = _Panel.CONFIRM
	_title.text = "Are you sure?"
	_main_panel.visible     = false
	_settings_panel.visible = false
	_guide_panel.visible    = false
	_log_panel.visible      = false
	_confirm_panel.visible  = true
	_confirm_label.text = msg
	_confirm_action = action

## --- UI Construction ---

func _build_ui() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color    = Color(0.0, 0.0, 0.0, 0.6)
	_backdrop.size     = Vector2(VP_W, VP_H)
	_backdrop.position = Vector2.ZERO
	add_child(_backdrop)

	_menu_btn = Button.new()
	_menu_btn.text = "☰"
	_menu_btn.custom_minimum_size = Vector2(40.0, 28.0)
	_menu_btn.position = Vector2(VP_W - 48.0, 8.0)
	_menu_btn.pressed.connect(_on_menu_btn_pressed)
	add_child(_menu_btn)

	_container = PanelContainer.new()
	_container.custom_minimum_size = Vector2(PANEL_W, PANEL_H)
	_container.position = Vector2((VP_W - PANEL_W) * 0.5, (VP_H - PANEL_H) * 0.5)
	add_child(_container)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top",    16)
	margin.add_theme_constant_override("margin_bottom", 16)
	margin.add_theme_constant_override("margin_left",   24)
	margin.add_theme_constant_override("margin_right",  24)
	_container.add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	margin.add_child(outer)

	_title = Label.new()
	_title.text = "PAUSED"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 28)
	outer.add_child(_title)

	outer.add_child(HSeparator.new())

	_main_panel = VBoxContainer.new()
	_main_panel.add_theme_constant_override("separation", 8)
	_build_main_panel(_main_panel)
	outer.add_child(_main_panel)

	_settings_panel = VBoxContainer.new()
	_settings_panel.add_theme_constant_override("separation", 10)
	_build_settings_panel(_settings_panel)
	outer.add_child(_settings_panel)

	_guide_panel = VBoxContainer.new()
	_guide_panel.add_theme_constant_override("separation", 12)
	_build_guide_panel(_guide_panel)
	outer.add_child(_guide_panel)

	_log_panel = VBoxContainer.new()
	_log_panel.add_theme_constant_override("separation", 8)
	_build_log_panel(_log_panel)
	outer.add_child(_log_panel)

	_confirm_panel = VBoxContainer.new()
	_confirm_panel.add_theme_constant_override("separation", 20)
	_build_confirm_panel(_confirm_panel)
	outer.add_child(_confirm_panel)


func _build_main_panel(vbox: VBoxContainer) -> void:
	var defs: Array[Array] = [
		["Resume",         Callable(self, "_on_resume_pressed")],
		["Settings",       Callable(self, "_on_settings_pressed")],
		["Guide",          Callable(self, "_on_guide_pressed")],
		["Archetypes Log", Callable(self, "_on_log_pressed")],
		["Main Menu",      Callable(self, "_on_main_menu_pressed")],
		["Exit Game",      Callable(self, "_on_exit_pressed")],
	]
	for def: Array in defs:
		var btn := Button.new()
		btn.text = def[0] as String
		btn.pressed.connect(def[1] as Callable)
		vbox.add_child(btn)


func _build_settings_panel(vbox: VBoxContainer) -> void:
	var back := Button.new()
	back.text = "← Back"
	back.pressed.connect(_show_main)
	vbox.add_child(back)

	vbox.add_child(HSeparator.new())

	var fs_row := HBoxContainer.new()
	var fs_lbl := Label.new()
	fs_lbl.text = "Fullscreen"
	fs_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fs_row.add_child(fs_lbl)
	_fs_check = CheckBox.new()
	_fs_check.set_pressed_no_signal(SettingsStore.fullscreen)
	_fs_check.toggled.connect(_on_fullscreen_toggled)
	fs_row.add_child(_fs_check)
	vbox.add_child(fs_row)

	# Volume sliders — values persist but audio bus is not wired yet.
	_master_slider = _add_volume_row(vbox, "Master Volume  (placeholder)",
		SettingsStore.master_volume, _on_master_changed)
	_music_slider  = _add_volume_row(vbox, "Music Volume  (placeholder)",
		SettingsStore.music_volume,  _on_music_changed)
	_sfx_slider    = _add_volume_row(vbox, "SFX Volume  (placeholder)",
		SettingsStore.sfx_volume,    _on_sfx_changed)


func _add_volume_row(parent: VBoxContainer, label_text: String,
		initial: float, cb: Callable) -> HSlider:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 13)
	row.add_child(lbl)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step      = 0.01
	slider.value     = initial
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(cb)
	row.add_child(slider)
	parent.add_child(row)
	return slider


func _build_guide_panel(vbox: VBoxContainer) -> void:
	var back := Button.new()
	back.text = "← Back"
	back.pressed.connect(_show_main)
	vbox.add_child(back)

	var lbl := Label.new()
	lbl.text = "Guide coming soon."
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(lbl)


func _build_log_panel(vbox: VBoxContainer) -> void:
	var back := Button.new()
	back.text = "← Back"
	back.pressed.connect(_show_main)
	vbox.add_child(back)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, 380.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_log_list = VBoxContainer.new()
	_log_list.add_theme_constant_override("separation", 8)
	_log_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_log_list)


func _build_confirm_panel(vbox: VBoxContainer) -> void:
	_confirm_label = Label.new()
	_confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_label.add_theme_font_size_override("font_size", 15)
	vbox.add_child(_confirm_label)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(hbox)

	var yes_btn := Button.new()
	yes_btn.text = "Yes"
	yes_btn.custom_minimum_size = Vector2(110.0, 36.0)
	yes_btn.pressed.connect(_on_confirm_yes)
	hbox.add_child(yes_btn)

	var no_btn := Button.new()
	no_btn.text = "No"
	no_btn.custom_minimum_size = Vector2(110.0, 36.0)
	no_btn.pressed.connect(_show_main)
	hbox.add_child(no_btn)


## --- Archetypes Log (Pokédex) ---

func _get_arch_status(id: String) -> _ArchStatus:
	if id == "RogueFinder":
		return _ArchStatus.PLAYER
	# recruited_archetypes persists across bench releases
	if id in GameState.recruited_archetypes:
		return _ArchStatus.FOLLOWER
	# Fallback: check active bench + party for saves that predate recruited_archetypes
	for f: CombatantData in GameState.bench:
		if f.archetype_id == id:
			return _ArchStatus.FOLLOWER
	for m: CombatantData in GameState.party:
		if m.archetype_id == id and m.archetype_id != "RogueFinder":
			return _ArchStatus.FOLLOWER
	if id in GameState.encountered_archetypes:
		return _ArchStatus.ENCOUNTERED
	return _ArchStatus.UNKNOWN


func _rebuild_log_list() -> void:
	for child in _log_list.get_children():
		child.queue_free()

	var all_archs: Array[ArchetypeData] = ArchetypeLibrary.all_archetypes()
	# Descending by status: PLAYER(3) → FOLLOWER(2) → ENCOUNTERED(1) → UNKNOWN(0)
	all_archs.sort_custom(
		func(a: ArchetypeData, b: ArchetypeData) -> bool:
			return _get_arch_status(a.archetype_id) > _get_arch_status(b.archetype_id)
	)

	for arch: ArchetypeData in all_archs:
		_log_list.add_child(_build_archetype_card(arch))


func _build_archetype_card(arch: ArchetypeData) -> Control:
	var status: _ArchStatus = _get_arch_status(arch.archetype_id)

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if status == _ArchStatus.UNKNOWN:
		card.modulate = Color(0.35, 0.35, 0.35)

	var inner := MarginContainer.new()
	inner.add_theme_constant_override("margin_top",    6)
	inner.add_theme_constant_override("margin_bottom", 6)
	inner.add_theme_constant_override("margin_left",   8)
	inner.add_theme_constant_override("margin_right",  8)
	card.add_child(inner)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	inner.add_child(vbox)

	if status == _ArchStatus.UNKNOWN:
		var unk_name := Label.new()
		unk_name.text = "???"
		unk_name.add_theme_font_size_override("font_size", 16)
		vbox.add_child(unk_name)
		var unk_sub := Label.new()
		unk_sub.text = "Not yet encountered in the field."
		unk_sub.add_theme_font_size_override("font_size", 11)
		unk_sub.modulate = Color(0.7, 0.7, 0.7)
		unk_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(unk_sub)
		return card

	# Known entry — top row with name and status badge side by side
	var top_row := HBoxContainer.new()
	vbox.add_child(top_row)

	var name_lbl := Label.new()
	name_lbl.text = "The Pathfinder" if status == _ArchStatus.PLAYER \
		else arch.archetype_id.replace("_", " ").capitalize()
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(name_lbl)

	var badge := Label.new()
	badge.add_theme_font_size_override("font_size", 11)
	match status:
		_ArchStatus.PLAYER:
			badge.text = "[ You ]"
			badge.modulate = Color(1.0, 0.85, 0.1)
		_ArchStatus.FOLLOWER:
			badge.text = "[ Follower ]"
			badge.modulate = Color(0.3, 0.9, 0.3)
		_ArchStatus.ENCOUNTERED:
			badge.text = "[ Encountered ]"
			badge.modulate = Color(0.6, 0.8, 1.0)
	top_row.add_child(badge)

	var info_lbl := Label.new()
	info_lbl.text = "%s · %s" % [arch.kindred, arch.unit_class.capitalize()]
	info_lbl.add_theme_font_size_override("font_size", 12)
	info_lbl.modulate = Color(0.8, 0.8, 0.8)
	vbox.add_child(info_lbl)

	if arch.notes != "":
		var notes_lbl := Label.new()
		notes_lbl.text = arch.notes
		notes_lbl.add_theme_font_size_override("font_size", 11)
		notes_lbl.modulate = Color(0.7, 0.9, 0.7)
		notes_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(notes_lbl)

	return card

## --- Button Handlers ---

func _on_resume_pressed() -> void:
	close_menu()

func _on_settings_pressed() -> void:
	_show_settings()

func _on_guide_pressed() -> void:
	_show_guide()

func _on_log_pressed() -> void:
	_show_log()

func _on_main_menu_pressed() -> void:
	_show_confirm(
		"Return to main menu?\nYour run progress is saved.",
		func() -> void:
			close_menu()
			get_tree().call_deferred("change_scene_to_file", "res://scenes/ui/MainMenuScene.tscn")
	)

func _on_exit_pressed() -> void:
	_show_confirm(
		"Exit the game?",
		func() -> void: get_tree().quit()
	)

func _on_confirm_yes() -> void:
	if _confirm_action.is_valid():
		_confirm_action.call()

## --- Settings Handlers ---

func _on_fullscreen_toggled(pressed: bool) -> void:
	SettingsStore.set_fullscreen(pressed)
	emit_signal("settings_changed")

func _on_master_changed(value: float) -> void:
	SettingsStore.master_volume = value
	SettingsStore.save_settings()
	emit_signal("settings_changed")

func _on_music_changed(value: float) -> void:
	SettingsStore.music_volume = value
	SettingsStore.save_settings()
	emit_signal("settings_changed")

func _on_sfx_changed(value: float) -> void:
	SettingsStore.sfx_volume = value
	SettingsStore.save_settings()
	emit_signal("settings_changed")
