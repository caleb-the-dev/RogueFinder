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
## Lives on _overlay_layer; cleared by _process when drag ends or on rebuild.
var _drag_compare_panel: Control = null
var _cmp_key: String = ""

## --- Lifecycle ---

func _ready() -> void:
	_add_background()
	_add_title()
	_add_section_buttons()
	_add_return_button()

func _process(_delta: float) -> void:
	if _drag_compare_panel != null and is_instance_valid(_drag_compare_panel) \
			and not get_viewport().gui_is_dragging():
		_clear_drag_compare()

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
	_build_overlay()

func _close_party_management() -> void:
	_clear_drag_compare()
	if _overlay_layer != null and is_instance_valid(_overlay_layer):
		_overlay_layer.queue_free()
	_overlay_layer = null

func _build_overlay() -> void:
	_clear_drag_compare()
	if _overlay_layer != null and is_instance_valid(_overlay_layer):
		_overlay_layer.queue_free()
	_drag_compare_panel = null

	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 5
	add_child(_overlay_layer)

	# Opaque backdrop — fully hides the city menu behind the overlay
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.06, 0.05, 0.07, 0.97)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay_layer.add_child(backdrop)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_overlay_layer.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 6)
	root_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(root_vbox)

	# Title row with close button
	var title_row := HBoxContainer.new()
	root_vbox.add_child(title_row)

	var title_lbl := Label.new()
	title_lbl.text = "Party Management"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.88, 0.65))
	title_row.add_child(title_lbl)

	var close_btn := Button.new()
	close_btn.text = "✕  Close"
	close_btn.custom_minimum_size = Vector2(120.0, 34.0)
	close_btn.add_theme_font_size_override("font_size", 14)
	close_btn.pressed.connect(_close_party_management)
	title_row.add_child(close_btn)

	root_vbox.add_child(_make_hsep())

	# Main 3-column area: Inventory | Party | Bench
	var col_hbox := HBoxContainer.new()
	col_hbox.add_theme_constant_override("separation", 10)
	col_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(col_hbox)

	var inv_col := _build_inventory_col()
	inv_col.custom_minimum_size = Vector2(185.0, 0.0)
	col_hbox.add_child(inv_col)

	col_hbox.add_child(_make_vsep())

	var party_col := _build_party_col()
	party_col.custom_minimum_size = Vector2(255.0, 0.0)
	col_hbox.add_child(party_col)

	col_hbox.add_child(_make_vsep())

	var bench_col := _build_bench_col()
	bench_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_hbox.add_child(bench_col)

## --- Inventory Column ---

func _build_inventory_col() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)

	var hdr := Label.new()
	hdr.text = "Bag"
	hdr.add_theme_font_size_override("font_size", 14)
	hdr.add_theme_color_override("font_color", Color(0.78, 0.72, 0.58))
	col.add_child(hdr)

	var hint := Label.new()
	hint.text = "Drag to equip →"
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.50, 0.48, 0.44))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(hint)

	col.add_child(_make_hsep())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)

	# Show only equipment — consumables don't have equipment slots to drag onto
	var items: Array = GameState.inventory.filter(
		func(i: Dictionary) -> bool: return i.get("item_type", "") == "equipment"
	)
	items.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return a.get("name", "") < b.get("name", "")
	)

	if items.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No equipment\nin bag."
		empty_lbl.add_theme_font_size_override("font_size", 11)
		empty_lbl.add_theme_color_override("font_color", Color(0.45, 0.43, 0.40))
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(empty_lbl)
	else:
		for item: Dictionary in items:
			list.add_child(_build_inventory_item(item))

	return col

func _build_inventory_item(item: Dictionary) -> Control:
	var row := PanelContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.11, 0.14)
	style.border_color = Color(0.30, 0.28, 0.38)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 6.0; style.content_margin_right = 6.0
	style.content_margin_top = 4.0;  style.content_margin_bottom = 4.0
	row.add_theme_stylebox_override("panel", style)

	var eq: EquipmentData = EquipmentLibrary.get_equipment(item.get("id", ""))
	var slot_tag: String = "W"
	match eq.slot:
		EquipmentData.Slot.ARMOR:     slot_tag = "A"
		EquipmentData.Slot.ACCESSORY: slot_tag = "X"

	var lbl := Label.new()
	lbl.text = "[%s] %s" % [slot_tag, item.get("name", "?")]
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.88, 0.84, 0.72))
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(lbl)

	var cap_row: PanelContainer = row
	var cap_item: Dictionary    = item
	row.set_drag_forwarding(
		func(_at: Vector2) -> Variant:
			var preview := Label.new()
			preview.text = "  %s" % cap_item.get("name", "?")
			preview.add_theme_font_size_override("font_size", 12)
			preview.add_theme_color_override("font_color", Color(0.95, 0.90, 0.70))
			cap_row.set_drag_preview(preview)
			return {"item": cap_item},
		Callable(),
		Callable()
	)

	return row

## --- Active Party Column ---

func _build_party_col() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var hdr := Label.new()
	hdr.text = "Active Party"
	hdr.add_theme_font_size_override("font_size", 14)
	hdr.add_theme_color_override("font_color", Color(0.78, 0.72, 0.58))
	col.add_child(hdr)

	for i in range(3):
		if i < GameState.party.size():
			col.add_child(_build_party_card(i, GameState.party[i]))
		else:
			col.add_child(_build_empty_party_slot())

	return col

func _build_party_card(party_idx: int, member: CombatantData) -> Control:
	var card := PanelContainer.new()
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0.0, 165.0)

	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(4)
	style.content_margin_left = 8.0; style.content_margin_right = 8.0
	style.content_margin_top = 7.0;  style.content_margin_bottom = 7.0
	if member.is_dead:
		style.bg_color = Color(0.10, 0.09, 0.10)
		style.border_color = Color(0.30, 0.28, 0.30)
		style.set_border_width_all(1)
	else:
		style.bg_color = Color(0.10, 0.10, 0.16)
		style.border_color = Color(0.35, 0.35, 0.55)
		style.set_border_width_all(2)
	card.add_theme_stylebox_override("panel", style)

	if member.is_dead:
		card.modulate = Color(1.0, 1.0, 1.0, 0.55)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	card.add_child(vbox)

	_add_member_identity(vbox, member)
	vbox.add_child(_make_hsep())
	_add_member_base_stats(vbox, member)
	vbox.add_child(_make_hsep())
	_add_equipment_slots(vbox, party_idx, member)

	# Capture loop-stable values for closures
	var cap_card: PanelContainer   = card
	var cap_member: CombatantData  = member
	var pi: int                    = party_idx

	card.set_drag_forwarding(
		# Drag source: lift this party member
		func(_at: Vector2) -> Variant:
			if cap_member.is_dead:
				return null
			var preview := Label.new()
			preview.text = "  %s" % cap_member.character_name
			preview.add_theme_font_size_override("font_size", 12)
			preview.add_theme_color_override("font_color", Color(0.95, 0.90, 0.70))
			cap_card.set_drag_preview(preview)
			return {"character": cap_member, "source": "party", "index": pi},
		# Accept bench characters; show stat comparison while hovering
		func(at: Vector2, data: Variant) -> bool:
			if cap_member.is_dead:
				_clear_drag_compare()
				return false
			if not (data is Dictionary) or not data.has("character"):
				_clear_drag_compare()
				return false
			if data.get("source", "") != "bench":
				_clear_drag_compare()
				return false
			_show_char_compare(cap_card.global_position + at, cap_member, data["character"])
			return true,
		# Drop: deequip outgoing party member then swap
		func(_at: Vector2, data: Variant) -> void:
			_clear_drag_compare()
			if not (data is Dictionary) or data.get("source", "") != "bench":
				return
			var bi: int = data.get("index", -1)
			if bi < 0:
				return
			_deequip_to_bag(GameState.party[pi])
			GameState.swap_active_bench(pi, bi)
			GameState.save()
			_build_overlay()
	)

	return card

func _build_empty_party_slot() -> Control:
	var card := PanelContainer.new()
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0.0, 165.0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.09)
	style.border_color = Color(0.20, 0.20, 0.24)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8.0; style.content_margin_right = 8.0
	style.content_margin_top = 7.0; style.content_margin_bottom = 7.0
	card.add_theme_stylebox_override("panel", style)

	var lbl := Label.new()
	lbl.text = "— Empty —"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.38, 0.38, 0.40))
	card.add_child(lbl)

	return card

## --- Bench Column ---

func _build_bench_col() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Header row: label + release zone
	var hdr_row := HBoxContainer.new()
	col.add_child(hdr_row)

	var hdr := Label.new()
	hdr.text = "Bench  (%d / %d)" % [GameState.bench.size(), GameState.BENCH_CAP]
	hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_theme_font_size_override("font_size", 14)
	hdr.add_theme_color_override("font_color", Color(0.78, 0.72, 0.58))
	hdr_row.add_child(hdr)

	hdr_row.add_child(_build_release_zone())

	if GameState.bench.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Your bench is empty.\nDrag a bench member into a party slot to swap."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_size_override("font_size", 13)
		empty_lbl.add_theme_color_override("font_color", Color(0.48, 0.48, 0.50))
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(empty_lbl)
	else:
		var hint := Label.new()
		hint.text = "Drag a bench card onto a party slot to swap. Drag to Release to discard."
		hint.add_theme_font_size_override("font_size", 10)
		hint.add_theme_color_override("font_color", Color(0.50, 0.48, 0.44))
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(hint)

		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		col.add_child(scroll)

		var grid := GridContainer.new()
		grid.columns = 2
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		scroll.add_child(grid)

		for i in range(GameState.bench.size()):
			grid.add_child(_build_bench_card(i, GameState.bench[i]))

	return col

func _build_release_zone() -> Control:
	var zone := PanelContainer.new()
	zone.custom_minimum_size = Vector2(110.0, 30.0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.06, 0.06)
	style.border_color = Color(0.55, 0.20, 0.18)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 6.0; style.content_margin_right = 6.0
	style.content_margin_top = 3.0; style.content_margin_bottom = 3.0
	zone.add_theme_stylebox_override("panel", style)

	var lbl := Label.new()
	lbl.text = "✗ Release"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.80, 0.38, 0.35))
	zone.add_child(lbl)

	zone.set_drag_forwarding(
		Callable(),
		func(_at: Vector2, data: Variant) -> bool:
			return (data is Dictionary) and data.get("source", "") == "bench",
		func(_at: Vector2, data: Variant) -> void:
			var bi: int = data.get("index", -1)
			if bi >= 0:
				GameState.release_from_bench(bi)
				_build_overlay()
	)

	return zone

func _build_bench_card(bench_idx: int, follower: CombatantData) -> Control:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0.0, 160.0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.10, 0.12)
	style.border_color = Color(0.28, 0.28, 0.38)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8.0; style.content_margin_right = 8.0
	style.content_margin_top = 7.0; style.content_margin_bottom = 7.0
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	card.add_child(vbox)

	_add_member_identity(vbox, follower)
	vbox.add_child(_make_hsep())
	_add_member_base_stats(vbox, follower)

	var cap_card: PanelContainer  = card
	var cap_follower: CombatantData = follower
	var bi: int                   = bench_idx

	card.set_drag_forwarding(
		func(_at: Vector2) -> Variant:
			var preview := Label.new()
			preview.text = "  %s" % cap_follower.character_name
			preview.add_theme_font_size_override("font_size", 12)
			preview.add_theme_color_override("font_color", Color(0.95, 0.90, 0.70))
			cap_card.set_drag_preview(preview)
			return {"character": cap_follower, "source": "bench", "index": bi},
		Callable(),
		Callable()
	)

	return card

## --- Card Helpers ---

func _add_member_identity(vbox: VBoxContainer, member: CombatantData) -> void:
	var name_lbl := Label.new()
	name_lbl.text = member.character_name
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.90, 0.72))
	vbox.add_child(name_lbl)

	var class_lbl := Label.new()
	class_lbl.text = "%s · %s" % [member.unit_class, member.kindred]
	class_lbl.add_theme_font_size_override("font_size", 11)
	class_lbl.add_theme_color_override("font_color", Color(0.70, 0.70, 0.85))
	vbox.add_child(class_lbl)

	if member.background != "":
		var bg_lbl := Label.new()
		bg_lbl.text = member.background
		bg_lbl.add_theme_font_size_override("font_size", 11)
		bg_lbl.add_theme_color_override("font_color", Color(0.68, 0.65, 0.60))
		vbox.add_child(bg_lbl)

	if member.temperament_id != "" and member.temperament_id != "even":
		var t: TemperamentData = TemperamentLibrary.get_temperament(member.temperament_id)
		var boost: String = _stat_abbrev(t.boosted_stat)
		var hinder: String = _stat_abbrev(t.hindered_stat)
		var temp_lbl := Label.new()
		temp_lbl.text = "%s (+%s/-%s)" % [t.temperament_name, boost, hinder]
		temp_lbl.add_theme_font_size_override("font_size", 10)
		temp_lbl.add_theme_color_override("font_color", Color(0.65, 0.58, 0.78))
		vbox.add_child(temp_lbl)

	var lv_lbl := Label.new()
	lv_lbl.text = "Lv %d" % member.level
	lv_lbl.add_theme_font_size_override("font_size", 10)
	lv_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	vbox.add_child(lv_lbl)

func _add_member_base_stats(vbox: VBoxContainer, member: CombatantData) -> void:
	# Base raw attributes — no bonus sources, for accurate comparison
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 10)
	vbox.add_child(row1)
	_add_stat_chip(row1, "STR", member.strength)
	_add_stat_chip(row1, "DEX", member.dexterity)
	_add_stat_chip(row1, "COG", member.cognition)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 10)
	vbox.add_child(row2)
	_add_stat_chip(row2, "WIL", member.willpower)
	_add_stat_chip(row2, "VIT", member.vitality)

func _add_stat_chip(parent: Control, stat_name: String, value: int) -> void:
	var lbl := Label.new()
	lbl.text = "%s %d" % [stat_name, value]
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.78, 0.80, 0.72))
	parent.add_child(lbl)

func _add_equipment_slots(vbox: VBoxContainer, party_idx: int, member: CombatantData) -> void:
	var slots: Array = [
		["weapon",    "W", member.weapon,    EquipmentData.Slot.WEAPON],
		["armor",     "A", member.armor,     EquipmentData.Slot.ARMOR],
		["accessory", "X", member.accessory, EquipmentData.Slot.ACCESSORY],
	]

	for slot_entry: Array in slots:
		var slot_field: String     = slot_entry[0]
		var slot_key: String       = slot_entry[1]
		var cur_eq: EquipmentData  = slot_entry[2]
		var slot_int: int          = slot_entry[3]

		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0.0, 20.0)
		btn.add_theme_font_size_override("font_size", 10)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		if cur_eq != null:
			btn.text = "[%s] %s" % [slot_key, cur_eq.equipment_name]
			btn.add_theme_color_override("font_color", Color(0.88, 0.84, 0.72))
		else:
			btn.text = "[%s] — empty —" % slot_key
			btn.add_theme_color_override("font_color", Color(0.42, 0.40, 0.38))

		if not member.is_dead:
			var sf: String            = slot_field
			var pi: int               = party_idx
			var cap_eq: EquipmentData = cur_eq
			var si: int               = slot_int

			if cap_eq != null:
				btn.gui_input.connect(func(ev: InputEvent) -> void:
					if ev is InputEventMouseButton \
							and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT \
							and (ev as InputEventMouseButton).pressed:
						_pm_unequip_item(pi, sf)
				)

			btn.set_drag_forwarding(
				Callable(),
				func(_at: Vector2, data: Variant) -> bool:
					return _pm_can_drop_here(data, si, member.is_dead),
				func(_at: Vector2, data: Variant) -> void:
					_pm_drop_to_slot((data as Dictionary)["item"], pi, sf)
			)
		else:
			btn.disabled = true

		vbox.add_child(btn)

## --- Drag-and-Drop Handlers ---

func _deequip_to_bag(member: CombatantData) -> void:
	if member.weapon != null:
		_pm_push_equip_to_bag(member.weapon)
		member.weapon = null
	if member.armor != null:
		_pm_push_equip_to_bag(member.armor)
		member.armor = null
	if member.accessory != null:
		_pm_push_equip_to_bag(member.accessory)
		member.accessory = null

func _pm_push_equip_to_bag(eq: EquipmentData) -> void:
	GameState.add_to_inventory({
		"id":          eq.equipment_id,
		"name":        eq.equipment_name,
		"description": eq.description,
		"item_type":   "equipment",
		"seen":        true,
	})

func _pm_can_drop_here(data: Variant, slot_int: int, is_dead: bool) -> bool:
	if is_dead:
		return false
	if not (data is Dictionary) or not data.has("item"):
		return false
	var item: Dictionary = (data as Dictionary)["item"]
	if item.get("item_type", "") != "equipment":
		return false
	var eq: EquipmentData = EquipmentLibrary.get_equipment(item.get("id", ""))
	return eq.slot == slot_int

func _pm_drop_to_slot(item: Dictionary, party_idx: int, slot_field: String) -> void:
	var member: CombatantData = GameState.party[party_idx]
	var eq: EquipmentData = EquipmentLibrary.get_equipment(item.get("id", ""))
	match slot_field:
		"weapon":
			if member.weapon != null:
				_pm_push_equip_to_bag(member.weapon)
			member.weapon = eq
		"armor":
			if member.armor != null:
				_pm_push_equip_to_bag(member.armor)
			member.armor = eq
		"accessory":
			if member.accessory != null:
				_pm_push_equip_to_bag(member.accessory)
			member.accessory = eq
	GameState.remove_from_inventory(item.get("id", ""))
	GameState.save()
	_build_overlay()

func _pm_unequip_item(party_idx: int, slot_field: String) -> void:
	var member: CombatantData = GameState.party[party_idx]
	var eq: EquipmentData
	match slot_field:
		"weapon":    eq = member.weapon;    member.weapon    = null
		"armor":     eq = member.armor;     member.armor     = null
		"accessory": eq = member.accessory; member.accessory = null
	if eq != null:
		_pm_push_equip_to_bag(eq)
	GameState.save()
	_build_overlay()

## --- Stat Comparison Panel ---

func _show_char_compare(near_pos: Vector2, existing: CombatantData, incoming: CombatantData) -> void:
	var key: String = existing.character_name + "|" + incoming.character_name
	if _cmp_key == key:
		return
	_clear_drag_compare()
	_cmp_key = key

	if _overlay_layer == null or not is_instance_valid(_overlay_layer):
		return

	var panel := PanelContainer.new()
	var sbox := StyleBoxFlat.new()
	sbox.bg_color = Color(0.08, 0.07, 0.10, 0.97)
	sbox.border_color = Color(0.50, 0.44, 0.70, 0.90)
	sbox.set_border_width_all(2)
	sbox.set_corner_radius_all(4)
	sbox.content_margin_left = 10.0; sbox.content_margin_right = 10.0
	sbox.content_margin_top = 8.0;   sbox.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", sbox)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	panel.add_child(vbox)

	var hdr := Label.new()
	hdr.text = "%s  →  %s" % [existing.character_name, incoming.character_name]
	hdr.add_theme_font_size_override("font_size", 11)
	hdr.add_theme_color_override("font_color", Color(0.85, 0.82, 0.90))
	vbox.add_child(hdr)

	vbox.add_child(_make_hsep())

	# Base stats only — raw attribute values, no bonus sources
	var pairs: Array[Array] = [
		["STR", existing.strength,  incoming.strength],
		["DEX", existing.dexterity, incoming.dexterity],
		["COG", existing.cognition, incoming.cognition],
		["WIL", existing.willpower, incoming.willpower],
		["VIT", existing.vitality,  incoming.vitality],
	]

	for pair: Array in pairs:
		var sn: String = pair[0]
		var cur: int   = pair[1]
		var inc: int   = pair[2]
		var delta: int = inc - cur

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		vbox.add_child(row)

		var lbl := Label.new()
		lbl.text = "%-3s  %d → %d" % [sn, cur, inc]
		lbl.custom_minimum_size = Vector2(120.0, 0.0)
		lbl.add_theme_font_size_override("font_size", 11)
		if delta > 0:
			lbl.add_theme_color_override("font_color", Color(0.45, 0.90, 0.45))
		elif delta < 0:
			lbl.add_theme_color_override("font_color", Color(0.90, 0.38, 0.38))
		else:
			lbl.add_theme_color_override("font_color", Color(0.68, 0.68, 0.68))
		row.add_child(lbl)

		if delta != 0:
			var dlbl := Label.new()
			dlbl.text = "(%+d)" % delta
			dlbl.add_theme_font_size_override("font_size", 11)
			dlbl.add_theme_color_override("font_color",
				Color(0.45, 0.90, 0.45) if delta > 0 else Color(0.90, 0.38, 0.38))
			row.add_child(dlbl)

	var panel_w: float = 210.0
	var panel_h: float = 155.0
	panel.position = Vector2(
		clampf(near_pos.x + 18.0, 0.0, VIEWPORT_SIZE.x - panel_w - 4.0),
		clampf(near_pos.y - 20.0, 0.0, VIEWPORT_SIZE.y - panel_h - 4.0)
	)

	_overlay_layer.add_child(panel)
	_drag_compare_panel = panel

func _clear_drag_compare() -> void:
	if _drag_compare_panel != null and is_instance_valid(_drag_compare_panel):
		_drag_compare_panel.queue_free()
	_drag_compare_panel = null
	_cmp_key = ""

## --- Utilities ---

func _make_hsep() -> HSeparator:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 2)
	return sep

func _make_vsep() -> VSeparator:
	return VSeparator.new()

func _stat_abbrev(stat: String) -> String:
	match stat:
		"strength":  return "STR"
		"dexterity": return "DEX"
		"cognition": return "COG"
		"willpower": return "WIL"
		"vitality":  return "VIT"
		_: return stat.substr(0, 3).to_upper() if stat.length() >= 3 else stat.to_upper()
