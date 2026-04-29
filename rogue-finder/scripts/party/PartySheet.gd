class_name PartySheet
extends CanvasLayer

## --- PartySheet ---

signal level_up_resolved
## Full-screen overlay: LEFT = inventory bag (drag source),
## MIDDLE = member cards (4 quadrants: name/hp | stats | equip | abilities),
## RIGHT = ability pool tabs (Abilities / Feats).
## Layer 20 — above all other UI.

const VIEWPORT_W:    float = 1280.0
const VIEWPORT_H:    float = 720.0
const HEADER_H:      float = 44.0
const SIDE_M:        float = 8.0
const COL_GAP:       float = 10.0

## Left inventory column
const LEFT_X:        float = SIDE_M
const LEFT_W:        float = 376.0

## Middle (member cards) — spans the rest of the viewport
const MID_X:         float = LEFT_X + LEFT_W + COL_GAP    ## = 394
const MID_W:         float = VIEWPORT_W - MID_X - SIDE_M  ## = 878

## Within each member card: left 4-quadrant area | right ability pool tabs
const STATS_BG_W:    float = 500.0
const ABIL_OFFSET:   float = 504.0
const ABIL_BG_W:     float = MID_W - ABIL_OFFSET  ## = 374

## Member row sizing
const MEMBER_H:      float = 215.0
const MEMBER_GAP:    float = 5.0
const CONTENT_TOP:   float = HEADER_H + SIDE_M

## Slot type sentinels
const SLOT_CONSUMABLE: int = 99

## Slot icon paths
const ICON_WEAPON:     String = "res://assets/icons/sWeaponIcon.png"
const ICON_ARMOR:      String = "res://assets/icons/sArmorIcon.png"
const ICON_ACCESSORY:  String = "res://assets/icons/sAccessoryIcon.png"
const ICON_CONSUMABLE: String = "res://assets/icons/sConsumableIcon.png"

var _content_root: Control = null

## --- Per-member sort / search / view state (index = party slot 0..2) ---
var _sort_fields:   Array[String] = ["name", "name", "name"]
var _sort_ascs:     Array[bool]   = [true, true, true]
var _search_texts:  Array[String] = ["", "", ""]
var _focus_search_mi:    int      = -1
var _active_search_edit: LineEdit = null
var _abil_views_wide:   Array[bool]   = [false, false, false]  ## false=1-per-row, true=2-per-row
var _feat_views_wide:   Array[bool]   = [false, false, false]
var _feat_sort_ascs:    Array[bool]   = [true, true, true]
var _feat_search_texts: Array[String] = ["", "", ""]
var _active_tab_indices: Array[int]  = [0, 0, 0]

## --- Inventory sort / search / view state ---
var _inv_search_text:   String   = ""
var _inv_sort_field:    String   = "name"
var _inv_sort_asc:      bool     = true
var _inv_view_wide:     bool     = false
var _focus_inv_search:  bool     = false
var _active_inv_search: LineEdit = null

## --- Drag comparison overlay (lives on the CanvasLayer, survives rebuilds) ---
var _drag_compare_panel: Control = null
var _cmp_existing: String        = ""
var _cmp_incoming: String        = ""

func _ready() -> void:
	layer = 20
	visible = false

func _process(_delta: float) -> void:
	if _drag_compare_panel != null and is_instance_valid(_drag_compare_panel) \
			and not get_viewport().gui_is_dragging():
		_clear_drag_compare()

## --- Public API ---

func show_sheet() -> void:
	_rebuild()
	visible = true

func hide_sheet() -> void:
	_clear_drag_compare()
	_focus_search_mi  = -1
	_focus_inv_search = false
	visible = false

## --- Build ---

func _rebuild() -> void:
	_active_search_edit = null
	_active_inv_search  = null
	if _content_root != null and is_instance_valid(_content_root):
		_content_root.queue_free()

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	_content_root = root

	var overlay := ColorRect.new()
	overlay.color = Color(0.05, 0.04, 0.03, 0.92)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(overlay)

	# Opaque dark tooltip background — overrides the engine's transparent default
	var tip_theme := Theme.new()
	var tip_sbox := StyleBoxFlat.new()
	tip_sbox.bg_color = Color(0.08, 0.07, 0.06, 0.97)
	tip_sbox.border_width_left = 1; tip_sbox.border_width_top = 1
	tip_sbox.border_width_right = 1; tip_sbox.border_width_bottom = 1
	tip_sbox.border_color = Color(0.44, 0.38, 0.26, 0.90)
	tip_sbox.content_margin_left = 6; tip_sbox.content_margin_right = 6
	tip_sbox.content_margin_top = 4; tip_sbox.content_margin_bottom = 4
	tip_sbox.set_corner_radius_all(3)
	tip_theme.set_stylebox("panel", "TooltipPanel", tip_sbox)
	tip_theme.set_color("font_color", "TooltipLabel", Color(0.92, 0.88, 0.78))
	root.theme = tip_theme

	_build_header(root)
	_build_inventory_column(root)

	for i in range(GameState.party.size()):
		var member: CombatantData = GameState.party[i]
		var row_y: float = CONTENT_TOP + float(i) * (MEMBER_H + MEMBER_GAP)
		_build_member_card(root, member, Vector2(MID_X, row_y), i)

	if _active_search_edit != null and is_instance_valid(_active_search_edit):
		var se: LineEdit = _active_search_edit
		se.grab_focus.call_deferred()
		(func() -> void: se.set_caret_column(se.text.length())).call_deferred()
	if _active_inv_search != null and is_instance_valid(_active_inv_search):
		var si: LineEdit = _active_inv_search
		si.grab_focus.call_deferred()
		(func() -> void: si.set_caret_column(si.text.length())).call_deferred()

## --- Header ---

func _build_header(parent: Control) -> void:
	var title := Label.new()
	title.text = "PARTY"
	title.position = Vector2(SIDE_M, 10.0)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.92, 0.86, 0.65))
	parent.add_child(title)

	var hint := Label.new()
	hint.text = "Drag bag items → equipment slots  ·  Click a filled slot to unequip  ·  Hover for details"
	hint.position = Vector2(90.0, 14.0)
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.55, 0.52, 0.46))
	parent.add_child(hint)

	var close_btn := Button.new()
	close_btn.text = "✕ Close"
	close_btn.size = Vector2(88.0, 28.0)
	close_btn.position = Vector2(VIEWPORT_W - 96.0, 8.0)
	close_btn.pressed.connect(hide_sheet)
	parent.add_child(close_btn)

	var div := ColorRect.new()
	div.color = Color(0.30, 0.26, 0.18, 0.70)
	div.size = Vector2(VIEWPORT_W, 1.0)
	div.position = Vector2(0.0, HEADER_H - 1.0)
	parent.add_child(div)

## --- Left Column: Inventory ---

func _build_inventory_column(parent: Control) -> void:
	var col_h: float = VIEWPORT_H - CONTENT_TOP - SIDE_M

	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.07, 0.06, 0.70)
	bg.position = Vector2(LEFT_X, CONTENT_TOP)
	bg.size = Vector2(LEFT_W, col_h)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)

	var margin := MarginContainer.new()
	margin.position = Vector2(LEFT_X, CONTENT_TOP)
	margin.size = Vector2(LEFT_W, col_h)
	margin.add_theme_constant_override("margin_left",   8)
	margin.add_theme_constant_override("margin_right",  6)
	margin.add_theme_constant_override("margin_top",    4)
	margin.add_theme_constant_override("margin_bottom", 4)
	parent.add_child(margin)

	var col_vbox := VBoxContainer.new()
	col_vbox.add_theme_constant_override("separation", 3)
	margin.add_child(col_vbox)

	# Header row: label + view toggle
	var hdr_row := HBoxContainer.new()
	hdr_row.add_theme_constant_override("separation", 4)
	col_vbox.add_child(hdr_row)
	var bag_lbl := Label.new()
	bag_lbl.text = "BAG"
	bag_lbl.add_theme_font_size_override("font_size", 13)
	bag_lbl.add_theme_color_override("font_color", Color(0.90, 0.82, 0.60))
	bag_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_row.add_child(bag_lbl)
	var inv_view_btn := Button.new()
	inv_view_btn.text = "2×" if not _inv_view_wide else "1×"
	inv_view_btn.flat = true
	inv_view_btn.add_theme_font_size_override("font_size", 9)
	inv_view_btn.add_theme_color_override("font_color", Color(0.65, 0.60, 0.45))
	inv_view_btn.tooltip_text = "Toggle 1 or 2 items per row"
	inv_view_btn.pressed.connect(func() -> void:
		_inv_view_wide = not _inv_view_wide
		_rebuild()
	)
	hdr_row.add_child(inv_view_btn)

	# Sort row
	var inv_sort_row := HBoxContainer.new()
	inv_sort_row.add_theme_constant_override("separation", 3)
	col_vbox.add_child(inv_sort_row)
	var inv_sort_lbl := Label.new()
	inv_sort_lbl.text = "Sort:"
	inv_sort_lbl.add_theme_font_size_override("font_size", 9)
	inv_sort_lbl.add_theme_color_override("font_color", Color(0.50, 0.48, 0.42))
	inv_sort_row.add_child(inv_sort_lbl)
	for sf: Array in [["name", "Name"], ["type", "Type"]]:
		var field: String = sf[0]; var caption: String = sf[1]
		var is_active: bool = (_inv_sort_field == field)
		var arrow: String   = (" ▲" if _inv_sort_asc else " ▼") if is_active else ""
		var sbtn := Button.new()
		sbtn.text = caption + arrow
		sbtn.flat = not is_active
		sbtn.add_theme_font_size_override("font_size", 9)
		if is_active:
			sbtn.add_theme_color_override("font_color", Color(0.95, 0.88, 0.45))
		var f: String = field
		sbtn.pressed.connect(func() -> void:
			if _inv_sort_field == f:
				_inv_sort_asc = not _inv_sort_asc
			else:
				_inv_sort_field = f
				_inv_sort_asc   = true
			_rebuild()
		)
		inv_sort_row.add_child(sbtn)

	# Search bar
	var inv_search := LineEdit.new()
	inv_search.placeholder_text = "search bag…"
	inv_search.text = _inv_search_text
	inv_search.add_theme_font_size_override("font_size", 11)
	col_vbox.add_child(inv_search)
	inv_search.text_changed.connect(func(new_text: String) -> void:
		_inv_search_text  = new_text
		_focus_inv_search = true
		_rebuild()
	)
	if _focus_inv_search:
		_active_inv_search = inv_search

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	col_vbox.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 2 if _inv_view_wide else 1
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	scroll.add_child(grid)

	if GameState.inventory.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "— empty —"
		empty_lbl.add_theme_font_size_override("font_size", 12)
		empty_lbl.add_theme_color_override("font_color", Color(0.45, 0.43, 0.40))
		grid.add_child(empty_lbl)
		return

	# Sort + filter
	var inv_sorted: Array = GameState.inventory.duplicate()
	inv_sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var cmp: int
		match _inv_sort_field:
			"type":
				var ta: int = 0 if a.get("item_type", "") == "equipment" else 1
				var tb: int = 0 if b.get("item_type", "") == "equipment" else 1
				cmp = ta - tb
				if cmp == 0: cmp = _strcmp(a.get("name", ""), b.get("name", ""))
			_:
				cmp = _strcmp(a.get("name", ""), b.get("name", ""))
		return cmp < 0 if _inv_sort_asc else cmp > 0
	)
	var inv_query: String = _inv_search_text.strip_edges().to_lower()
	if inv_query != "":
		inv_sorted = inv_sorted.filter(func(item: Dictionary) -> bool:
			return item.get("name", "").to_lower().contains(inv_query)
		)

	if inv_sorted.is_empty():
		var no_match := Label.new()
		no_match.text = "No matches."
		no_match.add_theme_font_size_override("font_size", 11)
		no_match.add_theme_color_override("font_color", Color(0.45, 0.43, 0.40))
		grid.add_child(no_match)
		return

	for item: Dictionary in inv_sorted:
		_build_draggable_item(grid, item, _inv_view_wide)

func _build_draggable_item(parent: Control, item: Dictionary, compact: bool = false) -> void:
	var is_equipment: bool = item.get("item_type", "") == "equipment"

	var row := PanelContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not compact:
		row.custom_minimum_size = Vector2(LEFT_W - 14.0, 0.0)

	var is_unseen: bool = not item.get("seen", true)
	var item_rarity: int = item.get("rarity", EquipmentData.Rarity.COMMON)
	var rarity_col: Color = EquipmentData.RARITY_COLORS.get(item_rarity, EquipmentData.RARITY_COLORS[0])

	var sbox := StyleBoxFlat.new()
	sbox.bg_color = Color(0.14, 0.12, 0.09, 0.90)
	sbox.border_width_left = 2; sbox.border_width_top = 2
	sbox.border_width_right = 2; sbox.border_width_bottom = 2
	# Unseen glow takes priority; otherwise border reflects rarity tier.
	sbox.border_color = Color(0.95, 0.80, 0.20) if is_unseen else rarity_col
	sbox.set_corner_radius_all(3)
	row.add_theme_stylebox_override("panel", sbox)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	row.add_child(hbox)

	var icon_tex: Texture2D
	if is_equipment:
		var eq: EquipmentData = EquipmentLibrary.get_equipment(item["id"])
		match eq.slot:
			EquipmentData.Slot.WEAPON:    icon_tex = load(ICON_WEAPON)    as Texture2D
			EquipmentData.Slot.ARMOR:     icon_tex = load(ICON_ARMOR)     as Texture2D
			EquipmentData.Slot.ACCESSORY: icon_tex = load(ICON_ACCESSORY) as Texture2D
	else:
		icon_tex = load(ICON_CONSUMABLE) as Texture2D

	if icon_tex != null:
		var icon_rect := TextureRect.new()
		icon_rect.texture = icon_tex
		var icon_sz: float = 16.0 if compact else 20.0
		icon_rect.custom_minimum_size = Vector2(icon_sz, icon_sz)
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(icon_rect)

	var text_vbox := VBoxContainer.new()
	text_vbox.add_theme_constant_override("separation", 1)
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(text_vbox)

	var name_lbl := Label.new()
	name_lbl.text = item.get("name", "?")
	name_lbl.add_theme_font_size_override("font_size", 10 if compact else 11)
	# Equipment name text colored by rarity; consumables use neutral color.
	var name_color: Color = rarity_col if is_equipment else Color(0.92, 0.88, 0.78)
	name_lbl.add_theme_color_override("font_color", name_color)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if compact:
		name_lbl.clip_contents = true
	text_vbox.add_child(name_lbl)

	if is_equipment and not compact:
		var eq: EquipmentData = EquipmentLibrary.get_equipment(item["id"])
		var bonus_str: String = _bonuses_str(eq.stat_bonuses)
		if bonus_str != "":
			var bonus_lbl := Label.new()
			bonus_lbl.text = bonus_str
			bonus_lbl.add_theme_font_size_override("font_size", 10)
			bonus_lbl.add_theme_color_override("font_color", Color(0.55, 0.78, 0.55))
			bonus_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			text_vbox.add_child(bonus_lbl)

	parent.add_child(row)

	if is_unseen:
		var tween := row.create_tween()
		tween.set_loops()
		tween.tween_property(row, "modulate:a", 0.7, 0.4)
		tween.tween_property(row, "modulate:a", 1.0, 0.4)
		row.mouse_entered.connect(func() -> void:
			item["seen"] = true
			_rebuild()
		)

	var tip: String
	if is_equipment:
		var eq: EquipmentData = EquipmentLibrary.get_equipment(item["id"])
		var extra_lines: PackedStringArray = []
		var ab_line: String = _granted_abilities_str(eq)
		var feat_line: String = _feat_str(eq)
		if ab_line != "": extra_lines.append(ab_line)
		if feat_line != "": extra_lines.append(feat_line)
		var extras: String = ("\n" + "\n".join(extra_lines)) if not extra_lines.is_empty() else ""
		tip = "%s  [%s]\n%s%s\n%s\n\nDrag to a matching slot to equip." % [
			item.get("name", "?"), _slot_name(eq.slot),
			_bonuses_str(eq.stat_bonuses), extras, eq.description
		]
	else:
		tip = "%s  [consumable]\n%s\n\nDrag to a CONSUMABLE slot to equip." % [
			item.get("name", "?"), item.get("description", "")
		]
	row.tooltip_text = _wrap_tooltip(tip)

	row.set_drag_forwarding(
		func(_at: Vector2) -> Variant:
			var preview := Label.new()
			preview.text = "  %s" % item.get("name", "?")
			preview.add_theme_font_size_override("font_size", 12)
			preview.add_theme_color_override("font_color", Color(0.95, 0.90, 0.70))
			row.set_drag_preview(preview)
			return {"item": item},
		Callable(),
		Callable()
	)

## --- Member Card ---

func _build_member_card(parent: Control, member: CombatantData, pos: Vector2, member_idx: int) -> void:
	var card_bg := ColorRect.new()
	card_bg.position = pos
	card_bg.size = Vector2(MID_W, MEMBER_H)
	card_bg.color = Color(0.07, 0.07, 0.07, 0.50) if member.is_dead \
		else Color(0.10, 0.09, 0.07, 0.88)
	card_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(card_bg)

	# Divider between left quadrant area and right tab panel
	var divider := ColorRect.new()
	divider.color = Color(0.28, 0.24, 0.18, 0.60)
	divider.position = pos + Vector2(ABIL_OFFSET - 2.0, 4.0)
	divider.size = Vector2(2.0, MEMBER_H - 8.0)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(divider)

	_build_stats_gear(parent, member, pos, member_idx)
	_build_ability_pool_tabs(parent, member, pos, member_idx)

## --- Stats + Gear (left portion of card) ---
## 4 quadrants separated by a full-height vertical + full-width horizontal divider:
##   TOP-LEFT:     Name (prominent) / Class / Background / HP bar
##   TOP-RIGHT:    Derived stats (BLUE) + Base attributes (YELLOW)
##   BOTTOM-LEFT:  Equipment 2×2 grid (RED)
##   BOTTOM-RIGHT: Slotted abilities 2×2 grid (GREEN)

func _build_stats_gear(parent: Control, member: CombatantData, card_pos: Vector2, member_idx: int) -> void:
	var x: float       = card_pos.x + 10.0
	var inner_w: float = STATS_BG_W - 20.0   ## = 510
	var is_dead: bool  = member.is_dead
	var half_w: float  = inner_w * 0.5        ## = 255
	var mid_y: float   = card_pos.y + 118.0   ## horizontal divider y
	var sep_color: Color = Color(0.55, 0.52, 0.44, 0.50)

	# Full-card quadrant separators
	var vsep := ColorRect.new()
	vsep.color = sep_color
	vsep.position = Vector2(x + half_w, card_pos.y + 4.0)
	vsep.size = Vector2(1.0, MEMBER_H - 8.0)
	vsep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(vsep)

	var hsep := ColorRect.new()
	hsep.color = sep_color
	hsep.position = Vector2(x, mid_y)
	hsep.size = Vector2(inner_w, 1.0)
	hsep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(hsep)

	# === TOP LEFT: Name / Class / Background / HP ===
	var tl_x: float = x + 8.0
	var tl_y: float = card_pos.y + 8.0
	var tl_w: float = half_w - 16.0   ## = 239

	var name_lbl := Label.new()
	name_lbl.text = member.character_name + (" [DEFEATED]" if is_dead else "")
	name_lbl.position = Vector2(tl_x, tl_y)
	name_lbl.add_theme_font_size_override("font_size", 17)
	name_lbl.add_theme_color_override("font_color",
		Color(0.72, 0.12, 0.08) if is_dead else Color(0.95, 0.90, 0.72))
	parent.add_child(name_lbl)
	tl_y += 24.0

	var class_lbl := Label.new()
	class_lbl.text = "Class: %s" % ClassLibrary.get_class_data(member.unit_class).display_name
	class_lbl.position = Vector2(tl_x, tl_y)
	class_lbl.add_theme_font_size_override("font_size", 13)
	class_lbl.add_theme_color_override("font_color",
		Color(0.78, 0.68, 0.44).lerp(Color(0.4, 0.4, 0.4), 0.5 if is_dead else 0.0))
	parent.add_child(class_lbl)
	tl_y += 18.0

	var bg_text: String = member.background if member.background != "" else "—"
	var bg_lbl := Label.new()
	bg_lbl.text = "Background: %s" % bg_text
	bg_lbl.position = Vector2(tl_x, tl_y)
	bg_lbl.add_theme_font_size_override("font_size", 13)
	bg_lbl.add_theme_color_override("font_color",
		Color(0.58, 0.74, 0.50).lerp(Color(0.4, 0.4, 0.4), 0.5 if is_dead else 0.0))
	parent.add_child(bg_lbl)
	tl_y += 18.0

	var kindred_text: String = member.kindred if member.kindred != "" else "Unknown"
	var kindred_lbl := Label.new()
	kindred_lbl.text = "Kindred: %s" % kindred_text
	kindred_lbl.position = Vector2(tl_x, tl_y)
	kindred_lbl.add_theme_font_size_override("font_size", 13)
	kindred_lbl.add_theme_color_override("font_color",
		Color(0.55, 0.65, 0.78).lerp(Color(0.4, 0.4, 0.4), 0.5 if is_dead else 0.0))
	parent.add_child(kindred_lbl)
	tl_y += 16.0

	var temp_data: TemperamentData = TemperamentLibrary.get_temperament(member.temperament_id)
	var temp_text: String = temp_data.temperament_name if temp_data.temperament_name != "" else "—"
	if temp_data.boosted_stat != "":
		temp_text += "  (+%s/-%s)" % [temp_data.boosted_stat.substr(0, 3).to_upper(),
			temp_data.hindered_stat.substr(0, 3).to_upper()]
	var temp_lbl := Label.new()
	temp_lbl.text = "Temp: %s" % temp_text
	temp_lbl.position = Vector2(tl_x, tl_y)
	temp_lbl.add_theme_font_size_override("font_size", 11)
	temp_lbl.add_theme_color_override("font_color",
		Color(0.72, 0.55, 0.80).lerp(Color(0.4, 0.4, 0.4), 0.5 if is_dead else 0.0))
	parent.add_child(temp_lbl)
	tl_y += 16.0

	# HP row: "HP x/x" text on the left, bar filling the remaining width
	const HP_TEXT_W: float = 60.0
	var hp_lbl := Label.new()
	hp_lbl.text = "HP %d / %d" % [member.current_hp, member.hp_max]
	hp_lbl.position = Vector2(tl_x, tl_y)
	hp_lbl.add_theme_font_size_override("font_size", 11)
	hp_lbl.add_theme_color_override("font_color",
		Color(0.70, 0.70, 0.70).lerp(Color(0.4, 0.4, 0.4), 0.5 if is_dead else 0.0))
	parent.add_child(hp_lbl)

	var bar_x: float   = tl_x + HP_TEXT_W
	var bar_w: float   = tl_w - HP_TEXT_W
	var hp_fill: float = float(member.current_hp) / float(max(member.hp_max, 1))
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.12, 0.06, 0.06)
	bar_bg.size = Vector2(bar_w, 8.0)
	bar_bg.position = Vector2(bar_x, tl_y + 4.0)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bar_bg)
	if hp_fill > 0.0:
		var fc: Color = Color(0.22, 0.68, 0.28) if hp_fill > 0.5 else Color(0.70, 0.38, 0.12)
		var bar_fill := ColorRect.new()
		bar_fill.color = fc
		bar_fill.size = Vector2(bar_w * hp_fill, 8.0)
		bar_fill.position = Vector2(bar_x, tl_y + 4.0)
		bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(bar_fill)

	# === TOP RIGHT: Derived Stats (BLUE) + Base Attributes (YELLOW) ===
	var tr_x: float = x + half_w + 8.0
	var tr_w: float = half_w - 16.0   ## = 239
	var tr_y: float = card_pos.y + 10.0

	# Derived stats — 6 columns
	var derived_defs: Array = [
		["Atk",    str(member.attack),            "Attack\nPhysical output per hit.\n= 5 + STR + gear + feats"],
		["P.Def",  str(member.physical_defense),  "Physical Defense\nReduces physical HARM.\n= physical_armor + gear + feats"],
		["M.Def",  str(member.magic_defense),     "Magic Defense\nReduces magic HARM.\n= magic_armor + gear + feats"],
		["Speed",  str(member.speed),             "Speed\nMovement cells per turn.\n= 1 + kindred bonus"],
		["EN Max", str(member.energy_max),        "Energy Max\nTotal energy pool.\n= 5 + VIT + gear + feats"],
		["Regen",  str(member.energy_regen),      "Energy Regen\nEnergy restored per turn.\n= 2 + WIL + gear + feats"],
	]
	var dcol_w: float = tr_w / float(derived_defs.size())
	for i in range(derived_defs.size()):
		var dd: Array = derived_defs[i]
		var dx: float = tr_x + float(i) * dcol_w
		var dlbl := Label.new()
		dlbl.text = dd[0]
		dlbl.position = Vector2(dx, tr_y)
		dlbl.add_theme_font_size_override("font_size", 9)
		dlbl.add_theme_color_override("font_color",
			Color(0.48, 0.62, 0.80).lerp(Color(0.35, 0.35, 0.35), 0.5 if is_dead else 0.0))
		dlbl.tooltip_text = dd[2]
		dlbl.mouse_filter = Control.MOUSE_FILTER_PASS
		parent.add_child(dlbl)
		var dval := Label.new()
		dval.text = dd[1]
		dval.position = Vector2(dx, tr_y + 11.0)
		dval.add_theme_font_size_override("font_size", 13)
		dval.add_theme_color_override("font_color",
			Color(0.68, 0.84, 1.00).lerp(Color(0.40, 0.40, 0.40), 0.5 if is_dead else 0.0))
		dval.tooltip_text = dd[2]
		dval.mouse_filter = Control.MOUSE_FILTER_PASS
		parent.add_child(dval)
	tr_y += 36.0

	# Base attributes — 5 columns. [abbr, stat_key, base_value, tooltip]
	var attr_defs: Array = [
		["STR", "strength",  member.strength,  "Strength\nDrives physical power. Used in attack formulas."],
		["DEX", "dexterity", member.dexterity, "Dexterity\nReserved for future dodge/evasion."],
		["COG", "cognition", member.cognition, "Cognition\nIntelligence. Reserved for future ability cost scaling."],
		["WIL", "willpower", member.willpower, "Willpower\nEnergy Regen = 2 + WIL energy restored each turn."],
		["VIT", "vitality",  member.vitality,  "Vitality\nHP Max = 10 + VIT×4.  Energy Max = 5 + VIT."],
	]
	var acol_w: float = tr_w / float(attr_defs.size())
	for i in range(attr_defs.size()):
		var ad: Array = attr_defs[i]
		var ax: float = tr_x + float(i) * acol_w
		# Item bonus = equipment stat_bonuses + the accessory's feat (if newly granting one).
		# Excludes background/class feats already in feat_ids — those aren't from items.
		var acc_feat_bonus: int = 0
		if member.accessory != null and member.accessory.feat_id != "" \
				and not member.feat_ids.has(member.accessory.feat_id):
			acc_feat_bonus = FeatLibrary.get_feat(member.accessory.feat_id).stat_bonuses.get(ad[1], 0)
		var item_bonus: int = member.get_equip_bonus(ad[1]) + acc_feat_bonus
		var base_val: int = ad[2]
		var attr_color: Color
		if is_dead:
			attr_color = Color(0.45, 0.45, 0.45)
		elif item_bonus > 0:
			attr_color = Color(0.35, 0.92, 0.42)  # green — item is boosting this stat
		elif item_bonus < 0:
			attr_color = Color(0.90, 0.35, 0.35)  # red — item is penalizing this stat
		else:
			attr_color = Color(0.98, 0.92, 0.52)  # normal yellow
		var tip_extra: String = (" (+%d from items)" % item_bonus) if item_bonus > 0 \
			else ((" (%d from items)" % item_bonus) if item_bonus < 0 else "")
		var full_tip: String = ad[3] + tip_extra
		var abbr := Label.new()
		abbr.text = ad[0]
		abbr.position = Vector2(ax, tr_y)
		abbr.add_theme_font_size_override("font_size", 10)
		abbr.add_theme_color_override("font_color",
			Color(0.80, 0.72, 0.34).lerp(Color(0.35, 0.35, 0.35), 0.5 if is_dead else 0.0))
		abbr.tooltip_text = full_tip
		abbr.mouse_filter = Control.MOUSE_FILTER_PASS
		parent.add_child(abbr)
		var val := Label.new()
		val.text = str(base_val + item_bonus)
		val.position = Vector2(ax, tr_y + 12.0)
		val.add_theme_font_size_override("font_size", 16)
		val.add_theme_color_override("font_color", attr_color)
		val.tooltip_text = full_tip
		val.mouse_filter = Control.MOUSE_FILTER_PASS
		parent.add_child(val)

	# Level row — centered in TR quadrant, below base attributes
	var lv_tr_y: float = tr_y + 42.0

	# Hide the label when the Level Up button is present — button replaces it
	if member.pending_level_ups == 0 or is_dead:
		var lv_tr_lbl := Label.new()
		lv_tr_lbl.text = "Lv. %d" % member.level
		lv_tr_lbl.position = Vector2(tr_x, lv_tr_y)
		lv_tr_lbl.size = Vector2(tr_w, 20.0)
		lv_tr_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lv_tr_lbl.add_theme_font_size_override("font_size", 13)
		lv_tr_lbl.add_theme_color_override("font_color",
			Color(0.55, 0.62, 0.75).lerp(Color(0.35, 0.35, 0.35), 0.5 if is_dead else 0.0))
		parent.add_child(lv_tr_lbl)

	if member.pending_level_ups > 0 and not is_dead:
		# Button centered in TR, raised slightly above the label's natural position
		const BTN_W: float = 162.0; const BTN_H: float = 22.0
		var lvlup_btn := Button.new()
		lvlup_btn.text = "Level Up! (%d)" % member.pending_level_ups
		lvlup_btn.position = Vector2(tr_x + (tr_w - BTN_W) * 0.5, lv_tr_y - 4.0)
		lvlup_btn.size = Vector2(BTN_W, BTN_H)
		lvlup_btn.add_theme_font_size_override("font_size", 11)
		lvlup_btn.pivot_offset = Vector2(BTN_W * 0.5, BTN_H * 0.5)
		var pc_cap: CombatantData = member
		lvlup_btn.pressed.connect(func(): _start_level_up(pc_cap))
		parent.add_child(lvlup_btn)
		# Rainbow color cycle
		var rainbow := lvlup_btn.create_tween().set_loops()
		for rc: Color in [
			Color(1.0, 0.0, 0.0), Color(1.0, 0.5, 0.0), Color(1.0, 1.0, 0.0),
			Color(0.0, 1.0, 0.0), Color(0.0, 0.5, 1.0), Color(0.6, 0.0, 1.0),
		]:
			rainbow.tween_property(lvlup_btn, "modulate", rc, 0.32)
		# Scale pulse
		var pulse := lvlup_btn.create_tween().set_loops()
		pulse.tween_property(lvlup_btn, "scale", Vector2(1.07, 1.07), 0.55).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(lvlup_btn, "scale", Vector2(1.0, 1.0), 0.55).set_trans(Tween.TRANS_SINE)

	# === BOTTOM LEFT: Equipment 2×2 ===
	var bl_x: float = x + 8.0
	var bl_y: float = mid_y + 7.0
	var bl_w: float = half_w - 16.0   ## = 239

	var eq_hdr := Label.new()
	eq_hdr.text = "EQUIPMENT"
	eq_hdr.position = Vector2(bl_x, bl_y)
	eq_hdr.add_theme_font_size_override("font_size", 9)
	eq_hdr.add_theme_color_override("font_color", Color(0.65, 0.40, 0.28))
	parent.add_child(eq_hdr)
	bl_y += 13.0

	var slot_defs: Array = [
		[ICON_WEAPON,    member.weapon,    "weapon",    EquipmentData.Slot.WEAPON,    "WEAPON"],
		[ICON_ARMOR,     member.armor,     "armor",     EquipmentData.Slot.ARMOR,     "ARMOR"],
		[ICON_ACCESSORY, member.accessory, "accessory", EquipmentData.Slot.ACCESSORY, "ACCESSORY"],
		[ICON_CONSUMABLE,null,             "consumable",SLOT_CONSUMABLE,              "CONSUMABLE"],
	]
	var cell_w: float   = bl_w * 0.5
	var row_h: float    = 26.0
	var row2_gap: float = 5.0
	var eq_row_y: Array = [0.0, 0.0, row_h + row2_gap, row_h + row2_gap]
	var eq_col_x: Array = [0.0, cell_w, 0.0, cell_w]

	for i in range(slot_defs.size()):
		var sd: Array          = slot_defs[i]
		var icon_path: String  = sd[0]
		var eq: EquipmentData  = sd[1]
		var slot_field: String = sd[2]
		var slot_type: int     = sd[3]
		var slot_label: String = sd[4]

		var bx: float = bl_x + eq_col_x[i]
		var by: float = bl_y + eq_row_y[i]

		var slot_btn := Button.new()
		slot_btn.flat = true
		slot_btn.position = Vector2(bx, by)
		slot_btn.size = Vector2(cell_w - 2.0, row_h)
		slot_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		slot_btn.add_theme_font_size_override("font_size", 11)

		var icon_tex: Texture2D = load(icon_path) as Texture2D
		if icon_tex != null:
			slot_btn.icon = icon_tex
		slot_btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		slot_btn.expand_icon = false

		if slot_type == SLOT_CONSUMABLE:
			if member.consumable != "":
				var cd: ConsumableData = ConsumableLibrary.get_consumable(member.consumable)
				slot_btn.text = cd.consumable_name
				slot_btn.tooltip_text = _wrap_tooltip("%s\n%s\n\nRight-click to unequip." % [cd.consumable_name, cd.description])
				slot_btn.add_theme_color_override("font_color", Color(0.85, 0.82, 0.72))
			else:
				slot_btn.text = "— none —"
				slot_btn.tooltip_text = "No consumable equipped.\nDrag a consumable from your bag to assign."
				slot_btn.add_theme_color_override("font_color", Color(0.45, 0.43, 0.40))
		elif eq != null:
			slot_btn.text = eq.equipment_name
			var bonus: String = _bonuses_str(eq.stat_bonuses)
			var slot_extra_lines: PackedStringArray = []
			var slot_ab: String = _granted_abilities_str(eq)
			var slot_feat: String = _feat_str(eq)
			if slot_ab != "": slot_extra_lines.append(slot_ab)
			if slot_feat != "": slot_extra_lines.append(slot_feat)
			var slot_extras: String = ("\n" + "\n".join(slot_extra_lines)) if not slot_extra_lines.is_empty() else ""
			slot_btn.tooltip_text = _wrap_tooltip("%s  [%s]\n%s%s\n%s\n\nRight-click to unequip." % [
				eq.equipment_name, slot_label, bonus, slot_extras, eq.description])
			slot_btn.add_theme_color_override("font_color",
				EquipmentData.RARITY_COLORS.get(eq.rarity, Color(0.85, 0.82, 0.72)))
		else:
			slot_btn.text = "— empty —"
			slot_btn.tooltip_text = "No %s equipped.\nDrag a %s from your bag to equip." % [
				slot_label.to_lower(), slot_label.to_lower()]
			slot_btn.add_theme_color_override("font_color", Color(0.42, 0.40, 0.38))

		if not is_dead:
			if slot_type == SLOT_CONSUMABLE and member.consumable != "":
				var mi: int = member_idx
				slot_btn.gui_input.connect(func(ev: InputEvent) -> void:
					if ev is InputEventMouseButton \
							and ev.button_index == MOUSE_BUTTON_RIGHT and ev.pressed:
						_unequip_consumable(mi)
				)
			elif slot_type != SLOT_CONSUMABLE and eq != null:
				var mi: int = member_idx; var sf: String = slot_field
				slot_btn.gui_input.connect(func(ev: InputEvent) -> void:
					if ev is InputEventMouseButton \
							and ev.button_index == MOUSE_BUTTON_RIGHT and ev.pressed:
						_unequip_item(mi, sf)
				)

		var st: int = slot_type; var mi: int = member_idx; var sf: String = slot_field
		var cur_eq_cap: EquipmentData = eq
		var cur_con_cap: String = member.consumable
		var sb_cap: Button = slot_btn
		slot_btn.set_drag_forwarding(
			Callable(),
			func(drop_pos: Vector2, data: Variant) -> bool:
				if _can_drop_here(data, st, is_dead):
					if data is Dictionary and data.has("item"):
						var inc: Dictionary = (data as Dictionary)["item"]
						if st == SLOT_CONSUMABLE and cur_con_cap != "":
							_show_consumable_compare(sb_cap.global_position + drop_pos,
								cur_con_cap, inc)
						elif st != SLOT_CONSUMABLE and cur_eq_cap != null:
							_show_equip_compare(sb_cap.global_position + drop_pos,
								cur_eq_cap, inc)
					return true
				_clear_drag_compare()
				return false,
			func(_p: Vector2, data: Variant) -> void:
				_clear_drag_compare()
				_drop_to_slot(data["item"], mi, sf)
		)

		if is_dead:
			slot_btn.disabled = true

		parent.add_child(slot_btn)

	# === BOTTOM RIGHT: Slotted Abilities 2×2 ===
	var br_x: float = x + half_w + 8.0
	var br_y: float = mid_y + 7.0
	var br_w: float = half_w - 16.0   ## = 239

	var ab_hdr := Label.new()
	ab_hdr.text = "ABILITIES"
	ab_hdr.position = Vector2(br_x, br_y)
	ab_hdr.add_theme_font_size_override("font_size", 9)
	ab_hdr.add_theme_color_override("font_color", Color(0.32, 0.60, 0.38))
	parent.add_child(ab_hdr)
	br_y += 13.0

	var ab_cell_w: float = br_w * 0.5 - 1.0
	var ab_offsets: Array = [
		[0.0,              0.0],
		[ab_cell_w + 2.0,  0.0],
		[0.0,              row_h + row2_gap],
		[ab_cell_w + 2.0,  row_h + row2_gap],
	]
	for j in range(member.abilities.size()):
		var ability_id: String = member.abilities[j]
		var off: Array  = ab_offsets[j]
		var abx: float  = br_x + off[0]
		var aby: float  = br_y + off[1]

		var slot_ctrl := Control.new()
		slot_ctrl.position = Vector2(abx, aby)
		slot_ctrl.size = Vector2(ab_cell_w, row_h)
		slot_ctrl.mouse_filter = Control.MOUSE_FILTER_STOP

		var slot_lbl := Label.new()
		slot_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_lbl.position = Vector2(0.0, 5.0)
		slot_lbl.custom_minimum_size = Vector2(ab_cell_w, 0.0)
		slot_lbl.clip_contents = true

		if ability_id == "":
			slot_lbl.text = "— empty —"
			slot_lbl.add_theme_font_size_override("font_size", 11)
			slot_lbl.add_theme_color_override("font_color", Color(0.35, 0.40, 0.35))
			slot_ctrl.tooltip_text = "Drag an ability from the pool panel →"
		else:
			var ab: AbilityData = AbilityLibrary.get_ability(ability_id)
			slot_lbl.text = ab.ability_name
			slot_lbl.add_theme_font_size_override("font_size", 12)
			slot_lbl.add_theme_color_override("font_color",
				Color(0.42, 0.50, 0.42) if is_dead else Color(0.58, 0.85, 0.62))
			slot_ctrl.tooltip_text = _wrap_tooltip("%s\nCost: %d Energy\nAttribute: %s\n\n%s\n\nRight-click to clear." % [
				ab.ability_name, ab.energy_cost, _attr_name(ab.attribute), ab.description
			])
		slot_ctrl.add_child(slot_lbl)

		if not is_dead:
			var mi2: int = member_idx; var sj: int = j
			var existing: String = ability_id  ## capture slot content at build time
			var sc: Control = slot_ctrl        ## capture for compare panel positioning
			if ability_id != "":
				slot_ctrl.gui_input.connect(func(ev: InputEvent) -> void:
					if ev is InputEventMouseButton \
							and ev.button_index == MOUSE_BUTTON_RIGHT and ev.pressed:
						GameState.party[mi2].abilities[sj] = ""
						_rebuild()
				)
			slot_ctrl.set_drag_forwarding(
				Callable(),
				func(drop_pos: Vector2, data: Variant) -> bool:
					if _can_drop_ability_here(data, mi2, false):
						if existing != "" and data is Dictionary and data.has("ability_id"):
							_show_drag_compare(
								sc.global_position + drop_pos,
								existing,
								(data as Dictionary)["ability_id"]
							)
						return true
					_clear_drag_compare()
					return false,
				func(_p: Vector2, data: Variant) -> void:
					_clear_drag_compare()
					_drop_ability_to_slot(data, mi2, sj)
			)
		parent.add_child(slot_ctrl)

## --- Ability Pool Tabs (right portion of card) ---
## Tab 1 "Abilities": scrollable list of all abilities in member.ability_pool.
## Tab 2 "Feats": placeholder — not yet implemented.

func _build_ability_pool_tabs(parent: Control, member: CombatantData,
		card_pos: Vector2, member_idx: int) -> void:
	var tabs := TabContainer.new()
	tabs.position = Vector2(card_pos.x + ABIL_OFFSET + 4.0, card_pos.y + 4.0)
	tabs.size = Vector2(ABIL_BG_W - 8.0, MEMBER_H - 8.0)
	if member.is_dead:
		tabs.modulate = Color(0.55, 0.55, 0.55)
	parent.add_child(tabs)
	# Save tab state on change; restore after _rebuild() recreates the container.
	var mi_tab: int = member_idx
	tabs.tab_changed.connect(func(tab: int) -> void: _active_tab_indices[mi_tab] = tab)
	# Defer the restore so children (the tab pages) exist before we switch.
	var saved_tab: int = _active_tab_indices[member_idx]
	if saved_tab > 0:
		tabs.call_deferred("set_current_tab", saved_tab)

	# --- Abilities tab: search + sort bar + draggable pool list ---
	var abil_tab := VBoxContainer.new()
	abil_tab.name = "Abilities"
	abil_tab.add_theme_constant_override("separation", 2)
	tabs.add_child(abil_tab)

	# Top bar: view toggle + drag hint, right-aligned and prominent
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 6)
	abil_tab.add_child(top_bar)
	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(top_spacer)
	var abil_view_btn := Button.new()
	abil_view_btn.text = "2×" if not _abil_views_wide[member_idx] else "1×"
	abil_view_btn.flat = false
	abil_view_btn.add_theme_font_size_override("font_size", 10)
	abil_view_btn.add_theme_color_override("font_color", Color(0.42, 0.68, 0.48))
	abil_view_btn.tooltip_text = "Toggle 1 or 2 abilities per row"
	var mi_view: int = member_idx
	abil_view_btn.pressed.connect(func() -> void:
		_abil_views_wide[mi_view] = not _abil_views_wide[mi_view]
		_rebuild()
	)
	top_bar.add_child(abil_view_btn)
	var hint_lbl := Label.new()
	hint_lbl.text = "drag to slot →"
	hint_lbl.add_theme_font_size_override("font_size", 10)
	hint_lbl.add_theme_color_override("font_color", Color(0.42, 0.60, 0.45))
	hint_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_bar.add_child(hint_lbl)

	# Sort row (left-aligned, compact)
	var sort_row := HBoxContainer.new()
	sort_row.add_theme_constant_override("separation", 3)
	abil_tab.add_child(sort_row)
	var sort_lbl := Label.new()
	sort_lbl.text = "Sort:"
	sort_lbl.add_theme_font_size_override("font_size", 9)
	sort_lbl.add_theme_color_override("font_color", Color(0.50, 0.48, 0.42))
	sort_row.add_child(sort_lbl)
	for sf: Array in [["name", "Name"], ["attribute", "Type"], ["energy", "EN"]]:
		var field: String = sf[0]; var caption: String = sf[1]
		var is_active: bool = (_sort_fields[member_idx] == field)
		var arrow: String   = (" ▲" if _sort_ascs[member_idx] else " ▼") if is_active else ""
		var sbtn := Button.new()
		sbtn.text = caption + arrow
		sbtn.flat = not is_active
		sbtn.add_theme_font_size_override("font_size", 9)
		if is_active:
			sbtn.add_theme_color_override("font_color", Color(0.95, 0.88, 0.45))
		var f: String = field; var mi_sort: int = member_idx
		sbtn.pressed.connect(func():
			if _sort_fields[mi_sort] == f:
				_sort_ascs[mi_sort] = not _sort_ascs[mi_sort]
			else:
				_sort_fields[mi_sort] = f
				_sort_ascs[mi_sort]   = true
			_rebuild()
		)
		sort_row.add_child(sbtn)

	# Search bar
	var search_edit := LineEdit.new()
	search_edit.placeholder_text = "search abilities…"
	search_edit.text = _search_texts[member_idx]
	search_edit.add_theme_font_size_override("font_size", 11)
	abil_tab.add_child(search_edit)
	var mi_search: int = member_idx
	search_edit.text_changed.connect(func(new_text: String) -> void:
		_search_texts[mi_search] = new_text
		_focus_search_mi = mi_search
		_rebuild()
	)
	if member_idx == _focus_search_mi:
		_active_search_edit = search_edit

	var abil_scroll := ScrollContainer.new()
	abil_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	abil_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	abil_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	abil_tab.add_child(abil_scroll)

	var abil_container: Control
	if _abil_views_wide[member_idx]:
		var abil_grid := GridContainer.new()
		abil_grid.columns = 2
		abil_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		abil_grid.add_theme_constant_override("h_separation", 3)
		abil_grid.add_theme_constant_override("v_separation", 3)
		abil_scroll.add_child(abil_grid)
		abil_container = abil_grid
	else:
		var abil_vbox := VBoxContainer.new()
		abil_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		abil_vbox.add_theme_constant_override("separation", 3)
		abil_scroll.add_child(abil_vbox)
		abil_container = abil_vbox

	if member.ability_pool.is_empty():
		var placeholder := Label.new()
		placeholder.text = "No abilities in pool."
		placeholder.add_theme_font_size_override("font_size", 11)
		placeholder.add_theme_color_override("font_color", Color(0.45, 0.43, 0.40))
		abil_container.add_child(placeholder)
	else:
		var sorted_pool: Array = member.ability_pool.duplicate()
		var sf_cur: String = _sort_fields[member_idx]
		var sa_cur: bool   = _sort_ascs[member_idx]
		sorted_pool.sort_custom(func(a: String, b: String) -> bool:
			var ab_a: AbilityData = AbilityLibrary.get_ability(a)
			var ab_b: AbilityData = AbilityLibrary.get_ability(b)
			var cmp: int
			match sf_cur:
				"name":      cmp = _strcmp(ab_a.ability_name, ab_b.ability_name)
				"attribute": cmp = ab_a.attribute - ab_b.attribute
				"energy":    cmp = ab_a.energy_cost - ab_b.energy_cost
				_:           cmp = _strcmp(ab_a.ability_name, ab_b.ability_name)
			return cmp < 0 if sa_cur else cmp > 0
		)
		var query: String = _search_texts[member_idx].strip_edges().to_lower()
		if query != "":
			sorted_pool = sorted_pool.filter(func(ab_id: String) -> bool:
				return AbilityLibrary.get_ability(ab_id).ability_name.to_lower().contains(query)
			)

		if sorted_pool.is_empty():
			var no_match := Label.new()
			no_match.text = "No matches."
			no_match.add_theme_font_size_override("font_size", 11)
			no_match.add_theme_color_override("font_color", Color(0.45, 0.43, 0.40))
			abil_container.add_child(no_match)

		var mi: int = member_idx
		for ab_id: String in sorted_pool:
			var ab: AbilityData  = AbilityLibrary.get_ability(ab_id)
			var slot_idx: int    = member.abilities.find(ab_id)
			var is_slotted: bool = slot_idx >= 0
			var tip: String = _wrap_tooltip("%s\nCost: %d Energy\nAttribute: %s\n\n%s%s" % [
				ab.ability_name, ab.energy_cost, _attr_name(ab.attribute), ab.description,
				("\n\nSlotted in slot %d." % (slot_idx + 1)) if is_slotted \
					else "\n\nDrag onto an ability slot to equip."
			])

			var ab_pnl := PanelContainer.new()
			var sbox := StyleBoxFlat.new()
			sbox.bg_color = Color(0.28, 0.22, 0.05, 0.70) if is_slotted \
				else Color(0.12, 0.12, 0.15, 0.80)
			sbox.border_width_bottom = 1
			sbox.border_color = Color(0.42, 0.36, 0.12, 0.70) if is_slotted \
				else Color(0.25, 0.25, 0.30, 0.60)
			sbox.set_corner_radius_all(2)
			ab_pnl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			ab_pnl.add_theme_stylebox_override("panel", sbox)
			ab_pnl.tooltip_text = tip
			abil_container.add_child(ab_pnl)

			var wide: bool = _abil_views_wide[member_idx]
			var inner := VBoxContainer.new()
			inner.add_theme_constant_override("separation", 1)
			ab_pnl.add_child(inner)

			var ab_name := Label.new()
			ab_name.text = ("● " if is_slotted else "") + ab.ability_name \
				+ ("  [s%d]" % (slot_idx + 1) if is_slotted else "")
			ab_name.add_theme_font_size_override("font_size", 11 if wide else 12)
			ab_name.add_theme_color_override("font_color",
				Color(0.95, 0.82, 0.20) if is_slotted else Color(0.90, 0.86, 0.72))
			ab_name.tooltip_text = tip
			ab_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
			inner.add_child(ab_name)

			if not wide:
				var ab_sub := Label.new()
				ab_sub.text = "%d EN  ·  %s" % [ab.energy_cost, _attr_name(ab.attribute)]
				ab_sub.add_theme_font_size_override("font_size", 10)
				ab_sub.add_theme_color_override("font_color", Color(0.55, 0.52, 0.44))
				ab_sub.tooltip_text = tip
				ab_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
				inner.add_child(ab_sub)

			if not member.is_dead:
				var ai: String = ab_id
				ab_pnl.set_drag_forwarding(
					func(_at: Vector2) -> Variant:
						var preview := Label.new()
						preview.text = "  %s" % ab.ability_name
						preview.add_theme_font_size_override("font_size", 12)
						preview.add_theme_color_override("font_color", Color(0.95, 0.90, 0.70))
						ab_pnl.set_drag_preview(preview)
						return {"ability_id": ai, "member_idx": mi},
					Callable(),
					Callable()
				)

	# --- Feats tab: mirrors the Abilities tab layout ---
	var feats_tab := VBoxContainer.new()
	feats_tab.name = "Feats"
	feats_tab.add_theme_constant_override("separation", 2)
	tabs.add_child(feats_tab)

	# Top bar: view toggle
	var feat_top_bar := HBoxContainer.new()
	feat_top_bar.add_theme_constant_override("separation", 6)
	feats_tab.add_child(feat_top_bar)
	var feat_spacer := Control.new()
	feat_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feat_top_bar.add_child(feat_spacer)
	var feat_view_btn := Button.new()
	feat_view_btn.text = "2×" if not _feat_views_wide[member_idx] else "1×"
	feat_view_btn.flat = false
	feat_view_btn.add_theme_font_size_override("font_size", 10)
	feat_view_btn.add_theme_color_override("font_color", Color(0.42, 0.68, 0.48))
	feat_view_btn.tooltip_text = "Toggle 1 or 2 feats per row"
	var mi_fv: int = member_idx
	feat_view_btn.pressed.connect(func() -> void:
		_feat_views_wide[mi_fv] = not _feat_views_wide[mi_fv]
		_rebuild()
	)
	feat_top_bar.add_child(feat_view_btn)

	# Sort row (name only — toggle asc/desc)
	var feat_sort_row := HBoxContainer.new()
	feat_sort_row.add_theme_constant_override("separation", 3)
	feats_tab.add_child(feat_sort_row)
	var feat_sort_hdr := Label.new()
	feat_sort_hdr.text = "Sort:"
	feat_sort_hdr.add_theme_font_size_override("font_size", 9)
	feat_sort_hdr.add_theme_color_override("font_color", Color(0.50, 0.48, 0.42))
	feat_sort_row.add_child(feat_sort_hdr)
	var feat_name_arrow: String = " ▲" if _feat_sort_ascs[member_idx] else " ▼"
	var feat_sort_btn := Button.new()
	feat_sort_btn.text = "Name" + feat_name_arrow
	feat_sort_btn.flat = false
	feat_sort_btn.add_theme_font_size_override("font_size", 9)
	feat_sort_btn.add_theme_color_override("font_color", Color(0.95, 0.88, 0.45))
	var mi_fs: int = member_idx
	feat_sort_btn.pressed.connect(func() -> void:
		_feat_sort_ascs[mi_fs] = not _feat_sort_ascs[mi_fs]
		_rebuild()
	)
	feat_sort_row.add_child(feat_sort_btn)

	# Search bar
	var feat_search := LineEdit.new()
	feat_search.placeholder_text = "search feats…"
	feat_search.text = _feat_search_texts[member_idx]
	feat_search.add_theme_font_size_override("font_size", 11)
	feats_tab.add_child(feat_search)
	var mi_fsrch: int = member_idx
	feat_search.text_changed.connect(func(new_text: String) -> void:
		_feat_search_texts[mi_fsrch] = new_text
		_rebuild()
	)

	# Scrollable feat list
	var feat_scroll := ScrollContainer.new()
	feat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	feat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	feat_scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_AUTO
	feats_tab.add_child(feat_scroll)

	var feat_container: Control
	if _feat_views_wide[member_idx]:
		var fg := GridContainer.new()
		fg.columns = 2
		fg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fg.add_theme_constant_override("h_separation", 3)
		fg.add_theme_constant_override("v_separation", 3)
		feat_scroll.add_child(fg)
		feat_container = fg
	else:
		var fv := VBoxContainer.new()
		fv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fv.add_theme_constant_override("separation", 3)
		feat_scroll.add_child(fv)
		feat_container = fv

	# Build + filter feat id list from unified feat_ids array
	var feat_ids: Array[String] = member.feat_ids.duplicate()
	if not _feat_sort_ascs[member_idx]:
		feat_ids.reverse()
	var fq: String = _feat_search_texts[member_idx].strip_edges().to_lower()
	if fq != "":
		feat_ids = feat_ids.filter(func(fid: String) -> bool:
			return FeatLibrary.get_feat(fid).name.to_lower().contains(fq)
		)

	if feat_ids.is_empty():
		var no_match := Label.new()
		no_match.text = "No matches." if fq != "" else "No feats."
		no_match.add_theme_font_size_override("font_size", 11)
		no_match.add_theme_color_override("font_color", Color(0.45, 0.43, 0.40))
		feat_container.add_child(no_match)
	else:
		var feat_wide: bool = _feat_views_wide[member_idx]
		for feat_id: String in feat_ids:
			var feat: FeatData = FeatLibrary.get_feat(feat_id)
			var tip: String = _wrap_tooltip("%s\n\n%s" % [feat.name, feat.description])

			var fpnl := PanelContainer.new()
			var fsbox := StyleBoxFlat.new()
			fsbox.bg_color = Color(0.12, 0.12, 0.15, 0.80)
			fsbox.border_width_bottom = 1
			fsbox.border_color = Color(0.25, 0.25, 0.30, 0.60)
			fsbox.set_corner_radius_all(2)
			fpnl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			fpnl.add_theme_stylebox_override("panel", fsbox)
			fpnl.tooltip_text = tip
			feat_container.add_child(fpnl)

			var finner := VBoxContainer.new()
			finner.add_theme_constant_override("separation", 1)
			fpnl.add_child(finner)

			var fnl := Label.new()
			fnl.text = feat.name
			fnl.add_theme_font_size_override("font_size", 11 if feat_wide else 12)
			fnl.add_theme_color_override("font_color", Color(0.80, 0.76, 0.60))
			fnl.tooltip_text = tip
			fnl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			finner.add_child(fnl)

	# Accessory-granted feat — shown after the feat_ids list if not already included.
	# Read-time only; never written to feat_ids, so it needs its own card here.
	if member.accessory != null and member.accessory.feat_id != "" \
			and not member.feat_ids.has(member.accessory.feat_id):
		var acc_feat: FeatData = FeatLibrary.get_feat(member.accessory.feat_id)
		var acc_matches_search: bool = fq == "" or acc_feat.name.to_lower().contains(fq)
		if acc_matches_search:
			var acc_tip: String = _wrap_tooltip(
				"%s\n\n%s\n\n[from %s]" % [acc_feat.name, acc_feat.description, member.accessory.equipment_name])
			var acc_pnl := PanelContainer.new()
			var acc_sbox := StyleBoxFlat.new()
			acc_sbox.bg_color = Color(0.12, 0.10, 0.18, 0.90)
			acc_sbox.border_width_bottom = 2
			acc_sbox.border_color = Color(0.62, 0.42, 0.85, 0.80)  # purple — item-sourced
			acc_sbox.set_corner_radius_all(2)
			acc_pnl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			acc_pnl.add_theme_stylebox_override("panel", acc_sbox)
			acc_pnl.tooltip_text = acc_tip
			feat_container.add_child(acc_pnl)
			var acc_inner := VBoxContainer.new()
			acc_inner.add_theme_constant_override("separation", 1)
			acc_pnl.add_child(acc_inner)
			var acc_name := Label.new()
			acc_name.text = acc_feat.name
			acc_name.add_theme_font_size_override("font_size", 12)
			acc_name.add_theme_color_override("font_color", Color(0.82, 0.68, 0.95))
			acc_name.tooltip_text = acc_tip
			acc_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
			acc_inner.add_child(acc_name)
			var acc_src := Label.new()
			acc_src.text = "from %s" % member.accessory.equipment_name
			acc_src.add_theme_font_size_override("font_size", 9)
			acc_src.add_theme_color_override("font_color", Color(0.52, 0.42, 0.65))
			acc_src.mouse_filter = Control.MOUSE_FILTER_IGNORE
			acc_inner.add_child(acc_src)

## --- Drag Compare Overlay ---
## Lives directly on the CanvasLayer so it survives _rebuild(). Cleared by _process
## when the drag ends, by _drop_ability_to_slot on a successful drop, and by hide_sheet.

func _show_drag_compare(near_pos: Vector2, existing_id: String, incoming_id: String) -> void:
	if _cmp_existing == existing_id and _cmp_incoming == incoming_id:
		return
	_clear_drag_compare()
	_cmp_existing = existing_id
	_cmp_incoming = incoming_id

	var panel := _make_compare_panel()
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	panel.add_child(hbox)

	for pair: Array in [
			["CURRENT", existing_id, Color(0.85, 0.32, 0.28)],
			["→  REPLACING", incoming_id, Color(0.38, 0.72, 0.45)]
		]:
		var ab: AbilityData = AbilityLibrary.get_ability(pair[1])
		var col := _make_compare_col(hbox, pair[0], pair[2])
		_add_cmp_label(col, ab.ability_name, 14, Color(0.92, 0.88, 0.78))
		_add_cmp_label(col, "%d EN  ·  %s" % [ab.energy_cost, _attr_name(ab.attribute)],
			10, Color(0.65, 0.62, 0.50))
		_add_cmp_desc(col, ab.description)

	var panel_w: float = 360.0; var panel_h: float = 110.0
	panel.position = Vector2(
		clampf(near_pos.x, MID_X, VIEWPORT_W - panel_w - 8.0),
		clampf(near_pos.y + 22.0, CONTENT_TOP, VIEWPORT_H - panel_h - 8.0)
	)

func _clear_drag_compare() -> void:
	if _drag_compare_panel != null and is_instance_valid(_drag_compare_panel):
		_drag_compare_panel.queue_free()
	_drag_compare_panel = null
	_cmp_existing = ""
	_cmp_incoming = ""

func _show_equip_compare(near_pos: Vector2, cur_eq: EquipmentData, incoming: Dictionary) -> void:
	var key_b: String = incoming.get("id", "")
	if _cmp_existing == cur_eq.equipment_id and _cmp_incoming == key_b:
		return
	_clear_drag_compare()
	_cmp_existing = cur_eq.equipment_id
	_cmp_incoming = key_b

	var panel := _make_compare_panel()
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	panel.add_child(hbox)

	# Left: current equipped item
	var col_a := _make_compare_col(hbox, "CURRENT", Color(0.85, 0.32, 0.28))
	_add_cmp_label(col_a, cur_eq.equipment_name, 14, Color(0.92, 0.88, 0.78))
	_add_cmp_label(col_a, "%s  %s" % [_slot_name(cur_eq.slot), _bonuses_str(cur_eq.stat_bonuses)],
		10, Color(0.65, 0.62, 0.50))
	if _granted_abilities_str(cur_eq) != "":
		_add_cmp_label(col_a, _granted_abilities_str(cur_eq), 10, Color(0.72, 0.85, 0.62))
	if _feat_str(cur_eq) != "":
		_add_cmp_label(col_a, _feat_str(cur_eq), 10, Color(0.82, 0.72, 0.95))
	_add_cmp_desc(col_a, cur_eq.description)

	# Right: incoming item from bag
	var col_b := _make_compare_col(hbox, "→  REPLACING", Color(0.38, 0.72, 0.45))
	if incoming.get("item_type", "") == "equipment":
		var in_eq: EquipmentData = EquipmentLibrary.get_equipment(incoming["id"])
		_add_cmp_label(col_b, in_eq.equipment_name, 14, Color(0.92, 0.88, 0.78))
		_add_cmp_label(col_b, "%s  %s" % [_slot_name(in_eq.slot), _bonuses_str(in_eq.stat_bonuses)],
			10, Color(0.65, 0.62, 0.50))
		if _granted_abilities_str(in_eq) != "":
			_add_cmp_label(col_b, _granted_abilities_str(in_eq), 10, Color(0.72, 0.85, 0.62))
		if _feat_str(in_eq) != "":
			_add_cmp_label(col_b, _feat_str(in_eq), 10, Color(0.82, 0.72, 0.95))
		_add_cmp_desc(col_b, in_eq.description)
	else:
		_add_cmp_label(col_b, incoming.get("name", "?"), 14, Color(0.92, 0.88, 0.78))
		_add_cmp_desc(col_b, incoming.get("description", ""))

	var panel_w: float = 360.0; var panel_h: float = 110.0
	panel.position = Vector2(
		clampf(near_pos.x, LEFT_X, VIEWPORT_W - panel_w - 8.0),
		clampf(near_pos.y + 22.0, CONTENT_TOP, VIEWPORT_H - panel_h - 8.0)
	)

func _show_consumable_compare(near_pos: Vector2, cur_id: String, incoming: Dictionary) -> void:
	var key_b: String = incoming.get("id", "")
	if _cmp_existing == cur_id and _cmp_incoming == key_b:
		return
	_clear_drag_compare()
	_cmp_existing = cur_id
	_cmp_incoming = key_b

	var panel := _make_compare_panel()
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	panel.add_child(hbox)

	var cur_cd: ConsumableData = ConsumableLibrary.get_consumable(cur_id)
	var col_a := _make_compare_col(hbox, "CURRENT", Color(0.85, 0.32, 0.28))
	_add_cmp_label(col_a, cur_cd.consumable_name, 14, Color(0.92, 0.88, 0.78))
	_add_cmp_desc(col_a, cur_cd.description)

	var col_b := _make_compare_col(hbox, "→  REPLACING", Color(0.38, 0.72, 0.45))
	_add_cmp_label(col_b, incoming.get("name", "?"), 14, Color(0.92, 0.88, 0.78))
	_add_cmp_desc(col_b, incoming.get("description", ""))

	var panel_w: float = 360.0; var panel_h: float = 110.0
	panel.position = Vector2(
		clampf(near_pos.x, LEFT_X, VIEWPORT_W - panel_w - 8.0),
		clampf(near_pos.y + 22.0, CONTENT_TOP, VIEWPORT_H - panel_h - 8.0)
	)

## Shared helpers for compare panels
func _make_compare_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.z_index = 100
	var sbox := StyleBoxFlat.new()
	sbox.bg_color = Color(0.07, 0.06, 0.10, 0.97)
	sbox.border_width_left = 2; sbox.border_width_top = 2
	sbox.border_width_right = 2; sbox.border_width_bottom = 2
	sbox.border_color = Color(0.50, 0.44, 0.70, 0.90)
	sbox.content_margin_left = 10; sbox.content_margin_right = 10
	sbox.content_margin_top = 7; sbox.content_margin_bottom = 7
	sbox.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", sbox)
	add_child(panel)
	_drag_compare_panel = panel
	return panel

func _make_compare_col(parent: Control, header: String, header_color: Color) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(160.0, 0.0)
	col.add_theme_constant_override("separation", 2)
	parent.add_child(col)
	var hdr := Label.new()
	hdr.text = header
	hdr.add_theme_font_size_override("font_size", 9)
	hdr.add_theme_color_override("font_color", header_color)
	col.add_child(hdr)
	return col

func _add_cmp_label(col: VBoxContainer, text: String, font_size: int, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	col.add_child(lbl)

func _add_cmp_desc(col: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(160.0, 0.0)
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.72, 0.70, 0.62))
	col.add_child(lbl)

## --- Drag-and-Drop Logic ---

func _can_drop_here(data: Variant, slot_type: int, is_dead: bool) -> bool:
	if is_dead:
		return false
	if not (data is Dictionary) or not data.has("item"):
		return false
	var item: Dictionary = data["item"]
	if slot_type == SLOT_CONSUMABLE:
		return item.get("item_type", "") == "consumable"
	if item.get("item_type", "") != "equipment":
		return false
	var eq: EquipmentData = EquipmentLibrary.get_equipment(item["id"])
	return eq.slot == slot_type

func _can_drop_ability_here(data: Variant, target_mi: int, is_dead: bool) -> bool:
	if is_dead: return false
	if not (data is Dictionary) or not data.has("ability_id"): return false
	return data.get("member_idx", -1) == target_mi

func _drop_ability_to_slot(data: Variant, target_mi: int, slot_idx: int) -> void:
	if not (data is Dictionary) or not data.has("ability_id"): return
	GameState.party[target_mi].abilities[slot_idx] = (data as Dictionary)["ability_id"]
	_rebuild()

func _drop_to_slot(item: Dictionary, member_idx: int, slot_field: String) -> void:
	var member: CombatantData = GameState.party[member_idx]
	if item.get("item_type", "") == "equipment":
		var eq: EquipmentData = EquipmentLibrary.get_equipment(item["id"])
		match slot_field:
			"weapon":
				if member.weapon    != null:
					member.on_unequip(member.weapon)
					_push_equipment_to_bag(member.weapon)
				member.weapon    = eq
			"armor":
				if member.armor     != null:
					member.on_unequip(member.armor)
					_push_equipment_to_bag(member.armor)
				member.armor     = eq
			"accessory":
				if member.accessory != null:
					member.on_unequip(member.accessory)
					_push_equipment_to_bag(member.accessory)
				member.accessory = eq
		member.on_equip(eq)
		GameState.remove_from_inventory(item["id"])
	elif item.get("item_type", "") == "consumable":
		if member.consumable != "": _push_consumable_to_bag(member.consumable)
		member.consumable = item["id"]
		GameState.remove_from_inventory(item["id"])
	_rebuild()

func _unequip_item(member_idx: int, slot_field: String) -> void:
	var member: CombatantData = GameState.party[member_idx]
	var eq: EquipmentData
	match slot_field:
		"weapon":    eq = member.weapon;    member.weapon    = null
		"armor":     eq = member.armor;     member.armor     = null
		"accessory": eq = member.accessory; member.accessory = null
	if eq != null:
		member.on_unequip(eq)
		_push_equipment_to_bag(eq)
	_rebuild()

func _unequip_consumable(member_idx: int) -> void:
	var member: CombatantData = GameState.party[member_idx]
	if member.consumable != "":
		_push_consumable_to_bag(member.consumable)
		member.consumable = ""
	_rebuild()

## --- Inventory Helpers ---

func _push_equipment_to_bag(eq: EquipmentData) -> void:
	GameState.add_to_inventory({
		"id": eq.equipment_id, "name": eq.equipment_name,
		"description": eq.description, "item_type": "equipment",
		"rarity": eq.rarity,
	})

func _push_consumable_to_bag(consumable_id: String) -> void:
	var cd: ConsumableData = ConsumableLibrary.get_consumable(consumable_id)
	GameState.add_to_inventory({
		"id": cd.consumable_id, "name": cd.consumable_name,
		"description": cd.description, "item_type": "consumable",
	})

## --- Level-Up Overlay (CanvasLayer layer 25) ---
## Card style mirrors EndCombatScreen's reward cards — both show 3 horizontal
## clickable cards so the two flows stay visually consistent.

func _start_level_up(pc: CombatantData) -> void:
	var pc_index: int = GameState.party.find(pc)
	if pc_index < 0:
		return

	var overlay := CanvasLayer.new()
	overlay.layer = 25
	add_child(overlay)

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.88)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(860.0, 0.0)
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.05, 0.04, 0.07, 0.97)
	pstyle.border_width_left = 2; pstyle.border_width_right = 2
	pstyle.border_width_top = 2; pstyle.border_width_bottom = 2
	pstyle.border_color = Color(0.55, 0.44, 0.80, 0.90)
	pstyle.set_corner_radius_all(6)
	pstyle.content_margin_left = 24; pstyle.content_margin_right = 24
	pstyle.content_margin_top = 20; pstyle.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", pstyle)
	center.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	panel.add_child(content)

	_fill_next_pick(content, overlay, pc, pc_index)

func _fill_ability_phase(content: VBoxContainer, overlay: CanvasLayer,
		pc: CombatantData, pc_index: int) -> void:
	for child in content.get_children():
		child.queue_free()

	var candidates: Array[String] = GameState.sample_ability_candidates(pc, 3)
	if candidates.is_empty():
		_finish_level_up(overlay, content, pc, pc_index)
		return

	var title := Label.new()
	title.text = "Level Up!  —  %s" % pc.character_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	content.add_child(title)

	var sub := Label.new()
	sub.text = "Choose an Ability"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	content.add_child(sub)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 24)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(hbox)

	for ab_id: String in candidates:
		var ab: AbilityData = AbilityLibrary.get_ability(ab_id)
		var ct: VBoxContainer = content; var ov: CanvasLayer = overlay
		var pc_ref: CombatantData = pc; var idx: int = pc_index
		var chosen_id: String = ab_id
		hbox.add_child(_build_pick_card(
			ab.ability_name,
			"%d EN  ·  %s" % [ab.energy_cost, _attr_name(ab.attribute)],
			ab.description,
			func():
				pc_ref.ability_pool.append(chosen_id)
				_finish_level_up(ov, ct, pc_ref, idx)
		))

func _fill_feat_phase(content: VBoxContainer, overlay: CanvasLayer,
		pc: CombatantData, pc_index: int) -> void:
	for child in content.get_children():
		child.queue_free()

	var candidates: Array[String] = GameState.sample_feat_candidates(pc, 3)
	if candidates.is_empty():
		_finish_level_up(overlay, content, pc, pc_index)
		return

	var title := Label.new()
	title.text = "Level Up!  —  %s" % pc.character_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	content.add_child(title)

	var sub := Label.new()
	sub.text = "Choose a Feat"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	content.add_child(sub)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 24)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(hbox)

	for feat_id: String in candidates:
		var feat: FeatData = FeatLibrary.get_feat(feat_id)
		var ct: VBoxContainer = content; var ov: CanvasLayer = overlay
		var pc_ref: CombatantData = pc; var idx: int = pc_index
		var chosen_id: String = feat_id
		hbox.add_child(_build_pick_card(
			feat.name,
			"",
			feat.description,
			func():
				GameState.grant_feat(idx, chosen_id)
				_finish_level_up(ov, ct, pc_ref, idx)
		))

## Builds one clickable pick card for the level-up overlay.
## Style mirrors EndCombatScreen reward cards — update both together.
func _build_pick_card(title: String, subtitle: String, desc: String,
		on_pick: Callable) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(240.0, 130.0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var sbox := StyleBoxFlat.new()
	sbox.bg_color = Color(0.10, 0.09, 0.07, 0.92)
	sbox.border_width_left = 2; sbox.border_width_right = 2
	sbox.border_width_top = 2; sbox.border_width_bottom = 2
	sbox.border_color = Color(0.36, 0.30, 0.20, 0.80)
	sbox.set_corner_radius_all(5)
	sbox.content_margin_left = 14; sbox.content_margin_right = 14
	sbox.content_margin_top = 14; sbox.content_margin_bottom = 14
	card.add_theme_stylebox_override("panel", sbox)

	var hover_sbox := sbox.duplicate() as StyleBoxFlat
	hover_sbox.bg_color = Color(0.18, 0.16, 0.11, 0.98)
	hover_sbox.border_color = Color(0.65, 0.52, 0.22, 0.90)

	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton \
				and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			on_pick.call()
	)
	card.mouse_entered.connect(func(): card.add_theme_stylebox_override("panel", hover_sbox))
	card.mouse_exited.connect(func(): card.add_theme_stylebox_override("panel", sbox))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = title
	name_lbl.add_theme_font_size_override("font_size", 17)
	name_lbl.add_theme_color_override("font_color", Color(0.96, 0.92, 0.78))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)

	if subtitle != "":
		var sub_lbl := Label.new()
		sub_lbl.text = subtitle
		sub_lbl.add_theme_font_size_override("font_size", 12)
		sub_lbl.add_theme_color_override("font_color", Color(0.60, 0.58, 0.48))
		sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(sub_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = desc
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.add_theme_color_override("font_color", Color(0.80, 0.78, 0.72))
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(desc_lbl)

	return card

## Routes to the correct pick phase for the current pending level-up.
## pick_level walks from the oldest un-resolved level up to the newest:
##   pick_level = pc.level - pc.pending_level_ups + 1
## even pick_level → ability, odd → feat
func _fill_next_pick(content: VBoxContainer, overlay: CanvasLayer,
		pc: CombatantData, pc_index: int) -> void:
	var pick_level: int = pc.level - pc.pending_level_ups + 1
	if pick_level % 2 == 0:
		_fill_ability_phase(content, overlay, pc, pc_index)
	else:
		_fill_feat_phase(content, overlay, pc, pc_index)

func _finish_level_up(overlay: CanvasLayer, content: VBoxContainer,
		pc: CombatantData, pc_index: int) -> void:
	pc.pending_level_ups -= 1
	GameState.save()
	if pc.pending_level_ups > 0:
		# More picks queued — refill the same overlay immediately
		_fill_next_pick(content, overlay, pc, pc_index)
	else:
		overlay.queue_free()
		_rebuild()
		level_up_resolved.emit()

## --- String Helpers ---

## Wrap tooltip text so each line stays ≤ max_line chars, preserving \n\n section breaks.
func _wrap_tooltip(text: String, max_line: int = 40) -> String:
	var sections: PackedStringArray = text.split("\n\n")
	var result_sections: PackedStringArray = []
	for section: String in sections:
		var wrapped: PackedStringArray = []
		for line: String in section.split("\n"):
			if line.length() <= max_line:
				wrapped.append(line)
				continue
			var cur: String = ""
			for w: String in line.split(" "):
				var sep: String = " " if cur != "" else ""
				if cur.length() + sep.length() + w.length() > max_line and cur != "":
					wrapped.append(cur)
					cur = w
				else:
					cur += sep + w
			if cur != "": wrapped.append(cur)
		result_sections.append("\n".join(wrapped))
	return "\n\n".join(result_sections)

func _strcmp(a: String, b: String) -> int:
	if a < b: return -1
	if a > b: return 1
	return 0

func _attr_name(attr: int) -> String:
	match attr:
		AbilityData.Attribute.STRENGTH:  return "Strength"
		AbilityData.Attribute.DEXTERITY: return "Dexterity"
		AbilityData.Attribute.COGNITION: return "Cognition"
		AbilityData.Attribute.WILLPOWER: return "Willpower"
		AbilityData.Attribute.VITALITY:  return "Vitality"
		_: return "—"

func _truncate(text: String, max_chars: int) -> String:
	return text if text.length() <= max_chars else text.substr(0, max_chars - 1) + "…"

func _slot_name(slot: int) -> String:
	match slot:
		EquipmentData.Slot.WEAPON:    return "WEAPON"
		EquipmentData.Slot.ARMOR:     return "ARMOR"
		EquipmentData.Slot.ACCESSORY: return "ACCESSORY"
		_: return "?"

func _bonuses_str(bonuses: Dictionary) -> String:
	if bonuses.is_empty(): return ""
	var parts: PackedStringArray = []
	for key: String in bonuses:
		var val: int = bonuses[key]
		parts.append("%s %s%d" % [_stat_abbr(key), "+" if val >= 0 else "", val])
	return "  ".join(parts)

## Returns a single-line feat description for tooltip use, or "" if no feat.
func _feat_str(eq: EquipmentData) -> String:
	if eq.feat_id == "":
		return ""
	var feat: FeatData = FeatLibrary.get_feat(eq.feat_id)
	var bonus: String = _bonuses_str(feat.stat_bonuses)
	if bonus != "":
		return "[Feat] %s  (%s)" % [feat.name, bonus]
	return "[Feat] %s" % feat.name

## Returns a single-line granted-ability list for tooltip use, or "" if none.
func _granted_abilities_str(eq: EquipmentData) -> String:
	if eq.granted_ability_ids.is_empty():
		return ""
	var names: PackedStringArray = []
	for aid: String in eq.granted_ability_ids:
		names.append(AbilityLibrary.get_ability(aid).ability_name)
	return "[Ability] %s" % ", ".join(names)

func _stat_abbr(stat: String) -> String:
	match stat:
		"strength":      return "STR"
		"dexterity":     return "DEX"
		"cognition":     return "COG"
		"willpower":     return "WIL"
		"vitality":      return "VIT"
		"physical_armor": return "P.DEF"
		"magic_armor":    return "M.DEF"
		_: return stat.substr(0, 3).to_upper()
