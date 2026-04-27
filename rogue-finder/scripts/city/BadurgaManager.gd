class_name BadurgaManager
extends Node2D

## --- Constants ---

const VIEWPORT_SIZE := Vector2(1280.0, 720.0)

## Each entry: [button label, section id]
const SECTIONS: Array = [
	["Party Management",                     "party_management"],
	["The Broken Compass  [Tavern]",         "tavern"],
	["Bulletin Board",                       "bulletin"],
	["Ironmonger's Stall  [Weapons]",        "vendor_weapon"],
	["Seamstress & Leatherworks  [Armor]",   "vendor_armor"],
	["The Curio Dealer  [Accessories]",      "vendor_accessory"],
	["Herbalist's Cart  [Consumables]",      "vendor_consumable"],
]

## --- Overlay State ---

var _overlay_layer: CanvasLayer = null
var _selected_bench_index: int = -1
var _pending_release_index: int = -1

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
	# Tighten spacing slightly to accommodate 7 buttons without crowding the return button
	var btn_size := Vector2(480.0, 54.0)
	var spacing := 8.0
	var start_y := 180.0
	var x := (VIEWPORT_SIZE.x - btn_size.x) * 0.5

	for i in range(SECTIONS.size()):
		var entry: Array = SECTIONS[i]
		var label_text: String = entry[0]
		var section_id: String = entry[1]

		var btn := Button.new()
		btn.text = label_text
		btn.custom_minimum_size = btn_size
		btn.size = btn_size
		btn.position = Vector2(x, start_y + i * (btn_size.y + spacing))
		btn.add_theme_font_size_override("font_size", 18)
		btn.pressed.connect(_on_section_pressed.bind(section_id))
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

func _on_section_pressed(section_id: String) -> void:
	if section_id == "party_management":
		_open_party_management()
		return
	print("[Badurga] ", section_id, " not yet implemented")

func _on_return_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/map/MapScene.tscn")

## --- Party Management Overlay ---

func _open_party_management() -> void:
	_selected_bench_index = -1
	_pending_release_index = -1
	_build_overlay()

func _close_party_management() -> void:
	if _overlay_layer != null and is_instance_valid(_overlay_layer):
		_overlay_layer.queue_free()
	_overlay_layer = null
	_selected_bench_index = -1
	_pending_release_index = -1

func _build_overlay() -> void:
	if _overlay_layer != null and is_instance_valid(_overlay_layer):
		_overlay_layer.queue_free()

	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 5
	add_child(_overlay_layer)

	# Semi-transparent backdrop dims the city menu behind the overlay
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.80)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay_layer.add_child(backdrop)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_overlay_layer.add_child(margin)

	# ScrollContainer handles overflow when bench fills 3 rows
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(vbox)

	# Title
	var title_lbl := Label.new()
	title_lbl.text = "Party Management"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 28)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.88, 0.65))
	vbox.add_child(title_lbl)

	vbox.add_child(_make_separator())

	# Active Party row
	var ap_lbl := Label.new()
	ap_lbl.text = "Active Party"
	ap_lbl.add_theme_font_size_override("font_size", 16)
	ap_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.80))
	vbox.add_child(ap_lbl)

	var party_row := HBoxContainer.new()
	party_row.add_theme_constant_override("separation", 14)
	vbox.add_child(party_row)

	for i in range(3):
		if i < GameState.party.size():
			party_row.add_child(_build_active_card(i, GameState.party[i]))
		else:
			party_row.add_child(_build_empty_slot_card("— Empty —"))

	vbox.add_child(_make_separator())

	# Bench section
	var bench_lbl := Label.new()
	bench_lbl.text = "Bench  (%d / %d)" % [GameState.bench.size(), GameState.BENCH_CAP]
	bench_lbl.add_theme_font_size_override("font_size", 16)
	bench_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.80))
	vbox.add_child(bench_lbl)

	if GameState.bench.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Your bench is empty."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_size_override("font_size", 15)
		empty_lbl.add_theme_color_override("font_color", Color(0.48, 0.48, 0.50))
		vbox.add_child(empty_lbl)
	else:
		var bench_grid := GridContainer.new()
		bench_grid.columns = 3
		bench_grid.add_theme_constant_override("h_separation", 14)
		bench_grid.add_theme_constant_override("v_separation", 14)
		bench_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_child(bench_grid)

		for i in range(GameState.bench.size()):
			bench_grid.add_child(_build_bench_card(i, GameState.bench[i]))

	vbox.add_child(_make_separator())

	# Close button
	var close_row := HBoxContainer.new()
	close_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(close_row)

	var close_btn := Button.new()
	close_btn.text = "✕  Close"
	close_btn.custom_minimum_size = Vector2(200.0, 42.0)
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.pressed.connect(_close_party_management)
	close_row.add_child(close_btn)

## --- Card Builders ---

func _build_active_card(party_index: int, member: CombatantData) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(200.0, 130.0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(4)
	style.content_margin_left = 10.0; style.content_margin_right = 10.0
	style.content_margin_top = 8.0;   style.content_margin_bottom = 8.0

	if member.is_dead:
		style.bg_color = Color(0.10, 0.09, 0.10)
		style.border_color = Color(0.30, 0.28, 0.30)
		style.set_border_width_all(1)
	elif _selected_bench_index >= 0:
		# Swap mode — highlight this as a valid swap target
		style.bg_color = Color(0.08, 0.14, 0.09)
		style.border_color = Color(0.30, 0.70, 0.35)
		style.set_border_width_all(2)
	else:
		style.bg_color = Color(0.10, 0.10, 0.14)
		style.border_color = Color(0.32, 0.32, 0.48)
		style.set_border_width_all(2)

	card.add_theme_stylebox_override("panel", style)

	if member.is_dead:
		card.modulate = Color(1.0, 1.0, 1.0, 0.50)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	card.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = member.character_name
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.90, 0.72))
	vbox.add_child(name_lbl)

	for pair: Array in [
		[member.unit_class,        Color(0.72, 0.72, 0.88)],
		["Lv %d" % member.level,  Color(0.68, 0.68, 0.68)],
		[member.kindred,           Color(0.62, 0.82, 0.62)],
	]:
		var lbl := Label.new()
		lbl.text = pair[0]
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", pair[1])
		vbox.add_child(lbl)

	if member.is_dead:
		var fallen_lbl := Label.new()
		fallen_lbl.text = "✗ Fallen"
		fallen_lbl.add_theme_font_size_override("font_size", 12)
		fallen_lbl.add_theme_color_override("font_color", Color(0.80, 0.30, 0.30))
		vbox.add_child(fallen_lbl)
	elif _selected_bench_index >= 0:
		var swap_in_btn := Button.new()
		swap_in_btn.text = "← Swap In"
		swap_in_btn.custom_minimum_size = Vector2(0.0, 28.0)
		swap_in_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		swap_in_btn.add_theme_font_size_override("font_size", 12)
		var pi: int = party_index
		# _selected_bench_index read at call time — holds the bench slot chosen by player
		swap_in_btn.pressed.connect(func() -> void: _do_swap(pi, _selected_bench_index))
		vbox.add_child(swap_in_btn)

	return card

func _build_empty_slot_card(slot_text: String) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(200.0, 130.0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.09)
	style.border_color = Color(0.22, 0.22, 0.26)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10.0; style.content_margin_right = 10.0
	style.content_margin_top = 8.0;   style.content_margin_bottom = 8.0
	card.add_theme_stylebox_override("panel", style)

	var lbl := Label.new()
	lbl.text = slot_text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.38, 0.38, 0.40))
	card.add_child(lbl)

	return card

func _build_bench_card(bench_index: int, follower: CombatantData) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(200.0, 150.0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var is_selected: bool = (_selected_bench_index == bench_index)
	var is_pending: bool = (_pending_release_index == bench_index)

	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(4)
	style.content_margin_left = 10.0; style.content_margin_right = 10.0
	style.content_margin_top = 8.0;   style.content_margin_bottom = 8.0

	if is_selected:
		style.bg_color = Color(0.16, 0.13, 0.05)
		style.border_color = Color(0.92, 0.78, 0.18)  # gold — selected for swap
		style.set_border_width_all(3)
	elif is_pending:
		style.bg_color = Color(0.15, 0.06, 0.05)
		style.border_color = Color(0.78, 0.22, 0.18)  # red — awaiting release confirm
		style.set_border_width_all(2)
	else:
		style.bg_color = Color(0.10, 0.10, 0.12)
		style.border_color = Color(0.28, 0.28, 0.38)
		style.set_border_width_all(2)

	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	if is_pending:
		_build_release_confirm_content(vbox, bench_index, follower)
		return card

	# Normal card view
	var name_lbl := Label.new()
	name_lbl.text = follower.character_name
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.90, 0.72))
	vbox.add_child(name_lbl)

	for pair: Array in [
		[follower.unit_class,        Color(0.72, 0.72, 0.88)],
		["Lv %d" % follower.level,  Color(0.68, 0.68, 0.68)],
		[follower.kindred,           Color(0.62, 0.82, 0.62)],
	]:
		var lbl := Label.new()
		lbl.text = pair[0]
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", pair[1])
		vbox.add_child(lbl)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 6)
	vbox.add_child(btn_row)

	var swap_btn := Button.new()
	swap_btn.text = "✕ Cancel" if is_selected else "⇄ Swap"
	swap_btn.custom_minimum_size = Vector2(0.0, 28.0)
	swap_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	swap_btn.add_theme_font_size_override("font_size", 11)
	var bi: int = bench_index
	swap_btn.pressed.connect(func() -> void: _select_bench_for_swap(bi))
	btn_row.add_child(swap_btn)

	var release_btn := Button.new()
	release_btn.text = "✗ Release"
	release_btn.custom_minimum_size = Vector2(0.0, 28.0)
	release_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	release_btn.add_theme_font_size_override("font_size", 11)
	release_btn.pressed.connect(func() -> void: _prompt_release(bi))
	btn_row.add_child(release_btn)

	return card

func _build_release_confirm_content(vbox: VBoxContainer, bench_index: int, follower: CombatantData) -> void:
	var confirm_lbl := Label.new()
	confirm_lbl.text = "Release %s?\nGear returns to bag." % follower.character_name
	confirm_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirm_lbl.add_theme_font_size_override("font_size", 12)
	confirm_lbl.add_theme_color_override("font_color", Color(0.90, 0.72, 0.60))
	vbox.add_child(confirm_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row)

	var confirm_btn := Button.new()
	confirm_btn.text = "Confirm"
	confirm_btn.custom_minimum_size = Vector2(0.0, 28.0)
	confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_btn.add_theme_font_size_override("font_size", 12)
	var bi: int = bench_index
	confirm_btn.pressed.connect(func() -> void: _do_release(bi))
	btn_row.add_child(confirm_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(0.0, 28.0)
	cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_btn.add_theme_font_size_override("font_size", 12)
	cancel_btn.pressed.connect(_cancel_release)
	btn_row.add_child(cancel_btn)

func _make_separator() -> HSeparator:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	return sep

## --- Swap / Release Interactions ---

func _select_bench_for_swap(bench_index: int) -> void:
	# Toggle: clicking the same card again deselects
	_selected_bench_index = bench_index if _selected_bench_index != bench_index else -1
	_pending_release_index = -1
	_build_overlay()

func _do_swap(party_index: int, bench_index: int) -> void:
	GameState.swap_active_bench(party_index, bench_index)
	GameState.save()
	_selected_bench_index = -1
	_pending_release_index = -1
	_build_overlay()

func _prompt_release(bench_index: int) -> void:
	_pending_release_index = bench_index
	_selected_bench_index = -1
	_build_overlay()

func _cancel_release() -> void:
	_pending_release_index = -1
	_build_overlay()

func _do_release(bench_index: int) -> void:
	# release_from_bench() auto-deequips gear to inventory and calls save() internally
	GameState.release_from_bench(bench_index)
	_pending_release_index = -1
	_selected_bench_index = -1
	_build_overlay()
