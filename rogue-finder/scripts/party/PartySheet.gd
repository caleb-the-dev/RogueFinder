class_name PartySheet
extends CanvasLayer

## --- PartySheet ---
## Full-screen overlay: LEFT = inventory bag (drag source),
## MIDDLE = member cards each split stats+gear LEFT / abilities RIGHT.
## Drag items from bag to slots. Click a filled slot to unequip.
## Hover any stat, ability, or item for a tooltip description.
## Layer 20 — above all other UI.

const VIEWPORT_W:    float = 1280.0
const VIEWPORT_H:    float = 720.0
const HEADER_H:      float = 44.0
const SIDE_M:        float = 8.0
const COL_GAP:       float = 10.0

## Left inventory column
const LEFT_X:        float = SIDE_M
const LEFT_W:        float = 240.0

## Middle (member cards) — spans the rest of the viewport
const MID_X:         float = LEFT_X + LEFT_W + COL_GAP    ## = 258
const MID_W:         float = VIEWPORT_W - MID_X - SIDE_M  ## = 1014

## Within each member card: stats+gear left portion, abilities right portion
const STATS_BG_W:    float = 530.0
const ABIL_OFFSET:   float = 534.0   ## x offset within card for ability bg
const ABIL_BG_W:     float = MID_W - ABIL_OFFSET  ## = 480

## Member row sizing
const MEMBER_H:      float = 210.0
const MEMBER_GAP:    float = 5.0
const CONTENT_TOP:   float = HEADER_H + SIDE_M

## Slot type sentinels (equipment uses EquipmentData.Slot values 0/1/2)
const SLOT_CONSUMABLE: int = 99

## Slot icon paths
const ICON_WEAPON:     String = "res://assets/icons/sWeaponIcon.png"
const ICON_ARMOR:      String = "res://assets/icons/sArmorIcon.png"
const ICON_ACCESSORY:  String = "res://assets/icons/sAccessoryIcon.png"
const ICON_CONSUMABLE: String = "res://assets/icons/sConsumableIcon.png"

var _content_root: Control = null

func _ready() -> void:
	layer = 20
	visible = false

## --- Public API ---

func show_sheet() -> void:
	_rebuild()
	visible = true

func hide_sheet() -> void:
	visible = false

## --- Build ---

func _rebuild() -> void:
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

	_build_header(root)
	_build_inventory_column(root)

	for i in range(GameState.party.size()):
		var member: CombatantData = GameState.party[i]
		var row_y: float = CONTENT_TOP + float(i) * (MEMBER_H + MEMBER_GAP)
		_build_member_card(root, member, Vector2(MID_X, row_y), i)

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

	var header := Label.new()
	header.text = "BAG"
	header.position = Vector2(LEFT_X + 8.0, CONTENT_TOP + 6.0)
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", Color(0.90, 0.82, 0.60))
	parent.add_child(header)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(LEFT_X, CONTENT_TOP + 26.0)
	scroll.size = Vector2(LEFT_W, col_h - 26.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	parent.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.custom_minimum_size = Vector2(LEFT_W - 12.0, 0.0)
	vbox.add_theme_constant_override("separation", 3)
	scroll.add_child(vbox)

	if GameState.inventory.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "— empty —"
		empty_lbl.add_theme_font_size_override("font_size", 12)
		empty_lbl.add_theme_color_override("font_color", Color(0.45, 0.43, 0.40))
		vbox.add_child(empty_lbl)
		return

	for item: Dictionary in GameState.inventory:
		_build_draggable_item(vbox, item)

func _build_draggable_item(parent: Control, item: Dictionary) -> void:
	var is_equipment: bool = item.get("item_type", "") == "equipment"

	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(LEFT_W - 14.0, 0.0)

	var sbox := StyleBoxFlat.new()
	sbox.bg_color = Color(0.14, 0.12, 0.09, 0.90)
	sbox.border_width_left = 2; sbox.border_width_top = 2
	sbox.border_width_right = 2; sbox.border_width_bottom = 2
	sbox.border_color = Color(0.36, 0.30, 0.20, 0.80)
	sbox.set_corner_radius_all(3)
	row.add_theme_stylebox_override("panel", sbox)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	row.add_child(hbox)

	# Type icon
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
		icon_rect.custom_minimum_size = Vector2(20.0, 20.0)
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(icon_rect)

	var text_vbox := VBoxContainer.new()
	text_vbox.add_theme_constant_override("separation", 1)
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(text_vbox)

	var name_lbl := Label.new()
	name_lbl.text = item.get("name", "?")
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_vbox.add_child(name_lbl)

	if is_equipment:
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

	# Tooltip: full item details
	var tip: String
	if is_equipment:
		var eq: EquipmentData = EquipmentLibrary.get_equipment(item["id"])
		tip = "%s  [%s]\n%s\n%s\n\nDrag to a matching slot to equip." % [
			item.get("name", "?"), _slot_name(eq.slot),
			_bonuses_str(eq.stat_bonuses), eq.description
		]
	else:
		tip = "%s  [consumable]\n%s\n\nDrag to a CONSUMABLE slot to equip." % [
			item.get("name", "?"), item.get("description", "")
		]
	row.tooltip_text = tip

	# Drag forwarding — returns item dict as payload
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
	# Card background
	var card_bg := ColorRect.new()
	card_bg.position = pos
	card_bg.size = Vector2(MID_W, MEMBER_H)
	card_bg.color = Color(0.07, 0.07, 0.07, 0.50) if member.is_dead \
		else Color(0.10, 0.09, 0.07, 0.88)
	card_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(card_bg)

	# Vertical divider between stats and abilities sections
	var divider := ColorRect.new()
	divider.color = Color(0.28, 0.24, 0.18, 0.60)
	divider.position = pos + Vector2(ABIL_OFFSET - 2.0, 4.0)
	divider.size = Vector2(2.0, MEMBER_H - 8.0)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(divider)

	_build_stats_gear(parent, member, pos, member_idx)
	_build_abilities_section(parent, member, pos)

## --- Stats + Gear (left portion of card) ---

func _build_stats_gear(parent: Control, member: CombatantData, card_pos: Vector2, member_idx: int) -> void:
	var x: float = card_pos.x + 10.0
	var inner_w: float = STATS_BG_W - 20.0   ## = 510
	var y: float = card_pos.y + 5.0
	var is_dead: bool = member.is_dead
	var dim: Color = Color(0.55, 0.55, 0.55) if is_dead else Color(1.0, 1.0, 1.0)

	# --- Name ---
	var name_lbl := Label.new()
	name_lbl.text = member.character_name + (" [DEFEATED]" if is_dead else "")
	name_lbl.position = Vector2(x, y)
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color",
		Color(0.72, 0.12, 0.08) if is_dead else Color(0.95, 0.90, 0.72))
	parent.add_child(name_lbl)
	y += 19.0

	# --- Class + Background ---
	var bg_text: String = member.background if member.background != "" else "—"
	var meta_lbl := Label.new()
	meta_lbl.text = "Class: %s   Background: %s" % [member.unit_class, bg_text]
	meta_lbl.position = Vector2(x, y)
	meta_lbl.add_theme_font_size_override("font_size", 11)
	meta_lbl.add_theme_color_override("font_color", Color(0.65, 0.62, 0.54).lerp(Color(0.4, 0.4, 0.4), 0.5 if is_dead else 0.0))
	parent.add_child(meta_lbl)
	y += 15.0

	# --- HP Bar (shorter — 180px) + HP text ---
	var bar_w: float  = 180.0
	var hp_fill: float = float(member.current_hp) / float(max(member.hp_max, 1))
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.12, 0.06, 0.06)
	bar_bg.size = Vector2(bar_w, 8.0)
	bar_bg.position = Vector2(x, y)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bar_bg)
	if hp_fill > 0.0:
		var fc: Color = Color(0.22, 0.68, 0.28) if hp_fill > 0.5 else Color(0.70, 0.38, 0.12)
		var bar_fill := ColorRect.new()
		bar_fill.color = fc
		bar_fill.size = Vector2(bar_w * hp_fill, 8.0)
		bar_fill.position = Vector2(x, y)
		bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(bar_fill)
	var hp_lbl := Label.new()
	hp_lbl.text = "HP %d / %d" % [member.current_hp, member.hp_max]
	hp_lbl.position = Vector2(x + bar_w + 8.0, y - 1.0)
	hp_lbl.add_theme_font_size_override("font_size", 11)
	hp_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75).lerp(Color(0.4,0.4,0.4), 0.5 if is_dead else 0.0))
	parent.add_child(hp_lbl)
	y += 14.0

	# --- Base Attributes (5 columns, spread out) ---
	var attr_defs: Array = [
		["STR", member.strength,  "Strength\nDrives physical power. Used in attack formulas."],
		["DEX", member.dexterity, "Dexterity\nSpeed = 2 + DEX cells of movement per turn."],
		["COG", member.cognition, "Cognition\nIntelligence. Reserved for future ability cost scaling."],
		["WIL", member.willpower, "Willpower\nEnergy Regen = 2 + WIL energy restored each turn."],
		["VIT", member.vitality,  "Vitality\nHP Max = 10 × VIT.  Energy Max = 5 + VIT."],
	]
	var col_w: float = inner_w / float(attr_defs.size())
	for i in range(attr_defs.size()):
		var ad: Array = attr_defs[i]
		var ax: float = x + float(i) * col_w
		var abbr := Label.new()
		abbr.text = ad[0]
		abbr.position = Vector2(ax, y + 2.0)
		abbr.add_theme_font_size_override("font_size", 10)
		abbr.add_theme_color_override("font_color", Color(0.60, 0.58, 0.50).lerp(Color(0.35,0.35,0.35), 0.5 if is_dead else 0.0))
		abbr.tooltip_text = ad[2]
		abbr.mouse_filter = Control.MOUSE_FILTER_PASS
		parent.add_child(abbr)
		var val := Label.new()
		val.text = str(ad[1])
		val.position = Vector2(ax, y + 13.0)
		val.add_theme_font_size_override("font_size", 17)
		val.add_theme_color_override("font_color", Color(0.92, 0.88, 0.75).lerp(Color(0.45,0.45,0.45), 0.5 if is_dead else 0.0))
		val.tooltip_text = ad[2]
		val.mouse_filter = Control.MOUSE_FILTER_PASS
		parent.add_child(val)
	y += 33.0

	# --- Derived Stats (4 cols — no HP Max, no Attack) ---
	var derived_defs: Array = [
		["Speed",    str(member.speed),       "Speed\nMovement cells per turn.\n= 2 + DEX + gear bonuses"],
		["Defense",  str(member.defense),     "Defense\nDamage reduction.\n= armor_defense + gear bonuses"],
		["EN Max",   str(member.energy_max),  "Energy Max\nTotal energy pool.\n= 5 + VIT + gear bonuses"],
		["EN Regen", str(member.energy_regen),"Energy Regen\nEnergy restored at turn start.\n= 2 + WIL + gear bonuses"],
	]
	var dcol_w: float = inner_w / float(derived_defs.size())
	for i in range(derived_defs.size()):
		var dd: Array = derived_defs[i]
		var dx: float = x + float(i) * dcol_w
		var dlbl := Label.new()
		dlbl.text = dd[0]
		dlbl.position = Vector2(dx, y + 2.0)
		dlbl.add_theme_font_size_override("font_size", 9)
		dlbl.add_theme_color_override("font_color", Color(0.55, 0.52, 0.44).lerp(Color(0.35,0.35,0.35), 0.5 if is_dead else 0.0))
		dlbl.tooltip_text = dd[2]
		dlbl.mouse_filter = Control.MOUSE_FILTER_PASS
		parent.add_child(dlbl)
		var dval := Label.new()
		dval.text = dd[1]
		dval.position = Vector2(dx, y + 12.0)
		dval.add_theme_font_size_override("font_size", 15)
		dval.add_theme_color_override("font_color", Color(0.80, 0.78, 0.68).lerp(Color(0.40,0.40,0.40), 0.5 if is_dead else 0.0))
		dval.tooltip_text = dd[2]
		dval.mouse_filter = Control.MOUSE_FILTER_PASS
		parent.add_child(dval)
	y += 30.0

	# --- Equipment section header ---
	var eq_hdr := Label.new()
	eq_hdr.text = "EQUIPMENT"
	eq_hdr.position = Vector2(x, y)
	eq_hdr.add_theme_font_size_override("font_size", 9)
	eq_hdr.add_theme_color_override("font_color", Color(0.48, 0.44, 0.36))
	parent.add_child(eq_hdr)
	y += 12.0

	# --- Equipment 2×2 grid (icon + name, no description) ---
	var slot_defs: Array = [
		[ICON_WEAPON,    member.weapon,    "weapon",    EquipmentData.Slot.WEAPON,    "WEAPON",    0],
		[ICON_ARMOR,     member.armor,     "armor",     EquipmentData.Slot.ARMOR,     "ARMOR",     1],
		[ICON_ACCESSORY, member.accessory, "accessory", EquipmentData.Slot.ACCESSORY, "ACCESSORY", 0],
		[ICON_CONSUMABLE,null,             "consumable",SLOT_CONSUMABLE,              "CONSUMABLE",1],
	]
	var cell_w: float = inner_w * 0.5   ## two columns
	var row_h: float  = 24.0
	var row_y_offsets: Array = [0.0, 0.0, row_h + 3.0, row_h + 3.0]
	var row_x_offsets: Array = [0.0, cell_w, 0.0, cell_w]

	for i in range(slot_defs.size()):
		var sd: Array     = slot_defs[i]
		var icon_path: String = sd[0]
		var eq: EquipmentData = sd[1]
		var slot_field: String = sd[2]
		var slot_type: int = sd[3]
		var slot_label: String = sd[4]

		var bx: float = x + row_x_offsets[i]
		var by: float = y + row_y_offsets[i]

		var slot_btn := Button.new()
		slot_btn.flat = true
		slot_btn.position = Vector2(bx, by)
		slot_btn.size = Vector2(cell_w - 4.0, row_h)
		slot_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		slot_btn.add_theme_font_size_override("font_size", 11)

		# Icon
		var icon_tex: Texture2D = load(icon_path) as Texture2D
		if icon_tex != null:
			slot_btn.icon = icon_tex
		slot_btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		slot_btn.expand_icon = false

		# Text + tooltip
		if slot_type == SLOT_CONSUMABLE:
			if member.consumable != "":
				var cd: ConsumableData = ConsumableLibrary.get_consumable(member.consumable)
				slot_btn.text = cd.consumable_name
				slot_btn.tooltip_text = "%s\n%s\n\nClick to unequip." % [cd.consumable_name, cd.description]
				slot_btn.add_theme_color_override("font_color", Color(0.85, 0.82, 0.72))
			else:
				slot_btn.text = "— none —"
				slot_btn.tooltip_text = "No consumable equipped.\nDrag a consumable from your bag to assign."
				slot_btn.add_theme_color_override("font_color", Color(0.45, 0.43, 0.40))
		elif eq != null:
			slot_btn.text = eq.equipment_name
			var bonus: String = _bonuses_str(eq.stat_bonuses)
			slot_btn.tooltip_text = "%s  [%s]\n%s\n%s\n\nClick to unequip." % [
				eq.equipment_name, slot_label, bonus, eq.description]
			slot_btn.add_theme_color_override("font_color", Color(0.85, 0.82, 0.72))
		else:
			slot_btn.text = "— empty —"
			slot_btn.tooltip_text = "No %s equipped.\nDrag a %s from your bag to equip." % [
				slot_label.to_lower(), slot_label.to_lower()]
			slot_btn.add_theme_color_override("font_color", Color(0.42, 0.40, 0.38))

		# Click to unequip
		if not is_dead:
			if slot_type == SLOT_CONSUMABLE and member.consumable != "":
				var mi: int = member_idx
				slot_btn.pressed.connect(func(): _unequip_consumable(mi))
			elif slot_type != SLOT_CONSUMABLE and eq != null:
				var mi: int = member_idx; var sf: String = slot_field
				slot_btn.pressed.connect(func(): _unequip_item(mi, sf))

		# Drop target
		var st: int = slot_type; var mi: int = member_idx; var sf: String = slot_field
		slot_btn.set_drag_forwarding(
			Callable(),
			func(_p: Vector2, data: Variant) -> bool:
				return _can_drop_here(data, st, is_dead),
			func(_p: Vector2, data: Variant) -> void:
				_drop_to_slot(data["item"], mi, sf)
		)

		if is_dead:
			slot_btn.disabled = true

		parent.add_child(slot_btn)

## --- Abilities Section (right portion of card) ---

func _build_abilities_section(parent: Control, member: CombatantData, card_pos: Vector2) -> void:
	var ax: float = card_pos.x + ABIL_OFFSET + 8.0
	var aw: float = ABIL_BG_W - 16.0   ## inner width
	var y: float  = card_pos.y + 5.0
	var is_dead: bool = member.is_dead

	var hdr := Label.new()
	hdr.text = "ABILITIES"
	hdr.position = Vector2(ax, y)
	hdr.add_theme_font_size_override("font_size", 9)
	hdr.add_theme_color_override("font_color", Color(0.48, 0.44, 0.36))
	parent.add_child(hdr)
	y += 14.0

	var slot_h: float = 43.0
	var gap: float = 4.0

	for ability_id: String in member.abilities:
		var slot_bg := ColorRect.new()
		slot_bg.position = Vector2(ax, y)
		slot_bg.size = Vector2(aw, slot_h)
		slot_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_bg.color = Color(0.10, 0.10, 0.12) if ability_id != "" else Color(0.07, 0.07, 0.07)
		parent.add_child(slot_bg)

		if ability_id == "":
			var empty := Label.new()
			empty.text = "— empty slot —"
			empty.position = Vector2(ax + 8.0, y + 15.0)
			empty.add_theme_font_size_override("font_size", 11)
			empty.add_theme_color_override("font_color", Color(0.35, 0.34, 0.32))
			parent.add_child(empty)
		else:
			var ab: AbilityData = AbilityLibrary.get_ability(ability_id)
			var tip: String = "%s\nCost: %d Energy\nAttribute: %s\n\n%s" % [
				ab.ability_name, ab.energy_cost,
				_attr_name(ab.attribute), ab.description
			]

			var ab_name := Label.new()
			ab_name.text = ab.ability_name
			ab_name.position = Vector2(ax + 8.0, y + 5.0)
			ab_name.add_theme_font_size_override("font_size", 13)
			ab_name.add_theme_color_override("font_color",
				Color(0.50, 0.50, 0.50) if is_dead else Color(0.90, 0.85, 0.70))
			ab_name.tooltip_text = tip
			ab_name.mouse_filter = Control.MOUSE_FILTER_PASS
			parent.add_child(ab_name)

			var cost_lbl := Label.new()
			cost_lbl.text = "Cost %d EN  ·  %s" % [ab.energy_cost, _truncate(ab.description, 58)]
			cost_lbl.position = Vector2(ax + 8.0, y + 25.0)
			cost_lbl.add_theme_font_size_override("font_size", 10)
			cost_lbl.add_theme_color_override("font_color",
				Color(0.40, 0.40, 0.40) if is_dead else Color(0.58, 0.55, 0.48))
			cost_lbl.tooltip_text = tip
			cost_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
			parent.add_child(cost_lbl)

		y += slot_h + gap

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

func _drop_to_slot(item: Dictionary, member_idx: int, slot_field: String) -> void:
	var member: CombatantData = GameState.party[member_idx]
	if item.get("item_type", "") == "equipment":
		var eq: EquipmentData = EquipmentLibrary.get_equipment(item["id"])
		match slot_field:
			"weapon":
				if member.weapon    != null: _push_equipment_to_bag(member.weapon)
				member.weapon    = eq
			"armor":
				if member.armor     != null: _push_equipment_to_bag(member.armor)
				member.armor     = eq
			"accessory":
				if member.accessory != null: _push_equipment_to_bag(member.accessory)
				member.accessory = eq
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
	if eq != null: _push_equipment_to_bag(eq)
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
	})

func _push_consumable_to_bag(consumable_id: String) -> void:
	var cd: ConsumableData = ConsumableLibrary.get_consumable(consumable_id)
	GameState.add_to_inventory({
		"id": cd.consumable_id, "name": cd.consumable_name,
		"description": cd.description, "item_type": "consumable",
	})

## --- String Helpers ---

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

func _stat_abbr(stat: String) -> String:
	match stat:
		"strength":      return "STR"
		"dexterity":     return "DEX"
		"cognition":     return "COG"
		"willpower":     return "WIL"
		"vitality":      return "VIT"
		"armor_defense": return "DEF"
		_: return stat.substr(0, 3).to_upper()
