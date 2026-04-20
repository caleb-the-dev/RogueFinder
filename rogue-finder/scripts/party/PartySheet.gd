class_name PartySheet
extends CanvasLayer

## --- PartySheet ---
## Full-screen overlay: inventory | party stats+gear | abilities.
## Drag items from the left inventory column to equipment/consumable slots
## in the middle column to equip them. Click a filled slot to unequip.
## Layer 20 — above map UI and combat UI (layer 15).

const VIEWPORT_W:   float = 1280.0
const VIEWPORT_H:   float = 720.0
const HEADER_H:     float = 46.0
const SIDE_M:       float = 8.0
const COL_GAP:      float = 10.0

## Column widths — must sum to VIEWPORT_W - 2*SIDE_M - 2*COL_GAP = 1244
const LEFT_W:       float = 240.0   # inventory
const MID_W:        float = 640.0   # party stats + gear
const RIGHT_W:      float = 364.0   # abilities

## Column x origins
const LEFT_X:       float = SIDE_M
const MID_X:        float = LEFT_X + LEFT_W + COL_GAP
const RIGHT_X:      float = MID_X + MID_W + COL_GAP

## Each party member occupies one row in the middle and right columns
const MEMBER_H:     float = 210.0
const MEMBER_GAP:   float = 5.0
const CONTENT_TOP:  float = HEADER_H + SIDE_M

## Drag-and-drop slot type constants
const SLOT_WEAPON:     int = EquipmentData.Slot.WEAPON
const SLOT_ARMOR:      int = EquipmentData.Slot.ARMOR
const SLOT_ACCESSORY:  int = EquipmentData.Slot.ACCESSORY
const SLOT_CONSUMABLE: int = 99  # sentinel for the consumable slot

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

	# Dark full-screen backdrop — blocks all map mouse input
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
		_build_member_stat_block(root, member, Vector2(MID_X, row_y), i)
		_build_member_ability_block(root, member, Vector2(RIGHT_X, row_y))

## --- Header ---

func _build_header(parent: Control) -> void:
	var title := Label.new()
	title.text = "PARTY"
	title.position = Vector2(SIDE_M, 10.0)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.92, 0.86, 0.65))
	parent.add_child(title)

	var hint := Label.new()
	hint.text = "Drag items → slots to equip  ·  Click a filled slot to unequip"
	hint.position = Vector2(90.0, 14.0)
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.62, 0.58, 0.50))
	parent.add_child(hint)

	var close_btn := Button.new()
	close_btn.text = "✕ Close"
	close_btn.size = Vector2(88.0, 30.0)
	close_btn.position = Vector2(VIEWPORT_W - 96.0, 8.0)
	close_btn.pressed.connect(hide_sheet)
	parent.add_child(close_btn)

	# Divider
	var div := ColorRect.new()
	div.color = Color(0.35, 0.30, 0.22, 0.80)
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
	parent.add_child(bg)

	var header := Label.new()
	header.text = "BAG"
	header.position = Vector2(LEFT_X + 8.0, CONTENT_TOP + 6.0)
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.90, 0.82, 0.60))
	parent.add_child(header)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(LEFT_X, CONTENT_TOP + 28.0)
	scroll.size = Vector2(LEFT_W, col_h - 28.0)
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
		empty_lbl.add_theme_color_override("font_color", Color(0.50, 0.48, 0.44))
		vbox.add_child(empty_lbl)
		return

	for item: Dictionary in GameState.inventory:
		_build_draggable_item(vbox, item)

## Builds one draggable inventory item row.
func _build_draggable_item(parent: Control, item: Dictionary) -> void:
	var is_equipment: bool = item.get("item_type", "") == "equipment"

	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(LEFT_W - 14.0, 0.0)

	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(0.14, 0.12, 0.09, 0.90)
	row_style.border_width_left   = 2
	row_style.border_width_top    = 2
	row_style.border_width_right  = 2
	row_style.border_width_bottom = 2
	row_style.border_color = Color(0.38, 0.32, 0.22, 0.80)
	row_style.set_corner_radius_all(3)
	row.add_theme_stylebox_override("panel", row_style)

	var inner_vbox := VBoxContainer.new()
	inner_vbox.add_theme_constant_override("separation", 1)
	row.add_child(inner_vbox)

	var name_lbl := Label.new()
	name_lbl.text = item.get("name", "?")
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner_vbox.add_child(name_lbl)

	var sub_lbl := Label.new()
	if is_equipment:
		var eq: EquipmentData = EquipmentLibrary.get_equipment(item["id"])
		sub_lbl.text = "[%s]  %s" % [_slot_name(eq.slot), _bonuses_str(eq.stat_bonuses)]
	else:
		sub_lbl.text = "[consumable]  %s" % item.get("description", "")
	sub_lbl.add_theme_font_size_override("font_size", 10)
	sub_lbl.add_theme_color_override("font_color", Color(0.65, 0.62, 0.54))
	sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner_vbox.add_child(sub_lbl)

	parent.add_child(row)

	# Wire drag: return item dict as drag payload; preview shows item name
	row.set_drag_forwarding(
		func(_at_pos: Vector2) -> Variant:
			var preview := Label.new()
			preview.text = "⬡ %s" % item.get("name", "?")
			preview.add_theme_font_size_override("font_size", 13)
			preview.add_theme_color_override("font_color", Color(0.95, 0.90, 0.70))
			row.set_drag_preview(preview)
			return {"item": item},
		Callable(),  # row is not a drop target
		Callable()
	)

## --- Middle Column: Member Stat + Gear Block ---

func _build_member_stat_block(parent: Control, member: CombatantData, pos: Vector2, member_idx: int) -> void:
	var is_dead: bool = member.is_dead

	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.09, 0.07, 0.88) if not is_dead else Color(0.07, 0.07, 0.07, 0.88)
	bg.position = pos
	bg.size = Vector2(MID_W, MEMBER_H)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)

	var y: float = pos.y + 8.0
	var x: float = pos.x + 8.0
	var inner_w: float = MID_W - 16.0

	# --- Name + class row ---
	var name_lbl := Label.new()
	name_lbl.text = member.character_name
	name_lbl.position = Vector2(x, y)
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color",
		Color(0.60, 0.60, 0.60) if is_dead else Color(0.95, 0.90, 0.75))
	parent.add_child(name_lbl)

	var class_lbl := Label.new()
	class_lbl.text = "  ·  %s" % member.unit_class
	class_lbl.position = Vector2(x + 140.0, y)
	class_lbl.add_theme_font_size_override("font_size", 12)
	class_lbl.add_theme_color_override("font_color",
		Color(0.50, 0.50, 0.50) if is_dead else Color(0.70, 0.65, 0.55))
	parent.add_child(class_lbl)

	if is_dead:
		var dead_lbl := Label.new()
		dead_lbl.text = "DEFEATED"
		dead_lbl.position = Vector2(pos.x + MID_W - 120.0, y)
		dead_lbl.add_theme_font_size_override("font_size", 13)
		dead_lbl.add_theme_color_override("font_color", Color(0.72, 0.12, 0.08))
		parent.add_child(dead_lbl)
	y += 20.0

	# --- HP bar ---
	var bar_w: float = inner_w
	var hp_fill: float = float(member.current_hp) / float(max(member.hp_max, 1))
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.15, 0.08, 0.08)
	bar_bg.size = Vector2(bar_w, 8.0)
	bar_bg.position = Vector2(x, y)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bar_bg)
	if hp_fill > 0.0:
		var fill_color: Color = Color(0.22, 0.68, 0.28) if hp_fill > 0.5 else Color(0.70, 0.38, 0.12)
		var bar_fill := ColorRect.new()
		bar_fill.color = fill_color
		bar_fill.size = Vector2(bar_w * hp_fill, 8.0)
		bar_fill.position = Vector2(x, y)
		bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(bar_fill)
	y += 10.0

	var hp_lbl := Label.new()
	hp_lbl.text = "HP %d/%d" % [member.current_hp, member.hp_max]
	hp_lbl.position = Vector2(x, y)
	hp_lbl.add_theme_font_size_override("font_size", 11)
	hp_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	parent.add_child(hp_lbl)
	y += 14.0

	# --- Base attributes (compact, one row) ---
	var attrs_lbl := Label.new()
	attrs_lbl.text = "STR:%d  DEX:%d  COG:%d  WIL:%d  VIT:%d" % [
		member.strength, member.dexterity, member.cognition, member.willpower, member.vitality
	]
	attrs_lbl.position = Vector2(x, y)
	attrs_lbl.add_theme_font_size_override("font_size", 11)
	attrs_lbl.add_theme_color_override("font_color", Color(0.78, 0.75, 0.68))
	parent.add_child(attrs_lbl)
	y += 14.0

	# --- Derived stats (two rows of three) ---
	var d1 := Label.new()
	d1.text = "HP Max:%d  EN Max:%d  Speed:%d" % [member.hp_max, member.energy_max, member.speed]
	d1.position = Vector2(x, y)
	d1.add_theme_font_size_override("font_size", 11)
	d1.add_theme_color_override("font_color", Color(0.70, 0.68, 0.60))
	parent.add_child(d1)
	y += 13.0

	var d2 := Label.new()
	d2.text = "Attack:%d  Defense:%d  EN Regen:%d" % [member.attack, member.defense, member.energy_regen]
	d2.position = Vector2(x, y)
	d2.add_theme_font_size_override("font_size", 11)
	d2.add_theme_color_override("font_color", Color(0.70, 0.68, 0.60))
	parent.add_child(d2)
	y += 16.0

	# --- Equipment section ---
	var equip_hdr := Label.new()
	equip_hdr.text = "EQUIPMENT"
	equip_hdr.position = Vector2(x, y)
	equip_hdr.add_theme_font_size_override("font_size", 10)
	equip_hdr.add_theme_color_override("font_color", Color(0.55, 0.50, 0.42))
	parent.add_child(equip_hdr)
	y += 14.0

	var slot_defs: Array = [
		["WEAPON",     member.weapon,     "weapon",    SLOT_WEAPON],
		["ARMOR",      member.armor,      "armor",     SLOT_ARMOR],
		["ACCESSORY",  member.accessory,  "accessory", SLOT_ACCESSORY],
		["CONSUMABLE", null,              "consumable",SLOT_CONSUMABLE],
	]
	for sd: Array in slot_defs:
		var slot_label: String  = sd[0]
		var slot_field: String  = sd[2]
		var slot_type: int      = sd[3]
		var slot_btn := Button.new()
		slot_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		slot_btn.custom_minimum_size = Vector2(inner_w, 22.0)
		slot_btn.size = Vector2(inner_w, 22.0)
		slot_btn.position = Vector2(x, y)
		slot_btn.add_theme_font_size_override("font_size", 11)

		if slot_type == SLOT_CONSUMABLE:
			if member.consumable != "":
				var cd: ConsumableData = ConsumableLibrary.get_consumable(member.consumable)
				slot_btn.text = "%s: %s  —  %s" % [slot_label, cd.consumable_name, cd.description]
			else:
				slot_btn.text = "%s: — none —" % slot_label
		else:
			var eq: EquipmentData = sd[1]
			if eq != null:
				slot_btn.text = "%s: %s  %s" % [slot_label, eq.equipment_name, _bonuses_str(eq.stat_bonuses)]
			else:
				slot_btn.text = "%s: — unequipped —" % slot_label

		# Unequip on click (only if filled and member is alive)
		if not is_dead:
			if slot_type == SLOT_CONSUMABLE and member.consumable != "":
				slot_btn.pressed.connect(func(): _unequip_consumable(member_idx))
			elif slot_type != SLOT_CONSUMABLE and sd[1] != null:
				slot_btn.pressed.connect(func(): _unequip_item(member_idx, slot_field))

		# Accept drops onto this slot
		slot_btn.set_drag_forwarding(
			Callable(),
			func(_at_pos: Vector2, data: Variant) -> bool:
				return _can_drop_here(data, slot_type, is_dead),
			func(_at_pos: Vector2, data: Variant) -> void:
				_drop_to_slot(data["item"], member_idx, slot_field)
		)

		if is_dead:
			slot_btn.disabled = true

		parent.add_child(slot_btn)
		y += 24.0

## --- Right Column: Member Ability Block ---

func _build_member_ability_block(parent: Control, member: CombatantData, pos: Vector2) -> void:
	var is_dead: bool = member.is_dead

	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.10, 0.70) if not is_dead else Color(0.06, 0.06, 0.06, 0.70)
	bg.position = pos
	bg.size = Vector2(RIGHT_W, MEMBER_H)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)

	var x: float = pos.x + 8.0
	var y: float = pos.y + 6.0
	var inner_w: float = RIGHT_W - 16.0

	var header_lbl := Label.new()
	header_lbl.text = "%s — ABILITIES" % member.character_name
	header_lbl.position = Vector2(x, y)
	header_lbl.add_theme_font_size_override("font_size", 11)
	header_lbl.add_theme_color_override("font_color",
		Color(0.55, 0.55, 0.55) if is_dead else Color(0.75, 0.70, 0.58))
	parent.add_child(header_lbl)
	y += 18.0

	for ability_id: String in member.abilities:
		var slot_bg := ColorRect.new()
		slot_bg.color = Color(0.12, 0.11, 0.09, 0.70) if ability_id != "" else Color(0.08, 0.08, 0.08, 0.50)
		slot_bg.position = Vector2(x, y)
		slot_bg.size = Vector2(inner_w, 42.0)
		slot_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(slot_bg)

		if ability_id == "":
			var empty := Label.new()
			empty.text = "— empty slot —"
			empty.position = Vector2(x + 6.0, y + 14.0)
			empty.add_theme_font_size_override("font_size", 11)
			empty.add_theme_color_override("font_color", Color(0.40, 0.38, 0.35))
			parent.add_child(empty)
		else:
			var ab: AbilityData = AbilityLibrary.get_ability(ability_id)
			var ab_name := Label.new()
			ab_name.text = ab.ability_name
			ab_name.position = Vector2(x + 6.0, y + 4.0)
			ab_name.add_theme_font_size_override("font_size", 12)
			ab_name.add_theme_color_override("font_color",
				Color(0.55, 0.55, 0.55) if is_dead else Color(0.90, 0.85, 0.72))
			parent.add_child(ab_name)

			var cost_lbl := Label.new()
			cost_lbl.text = "Cost %d  —  %s" % [ab.energy_cost, _truncate(ab.description, 52)]
			cost_lbl.position = Vector2(x + 6.0, y + 22.0)
			cost_lbl.add_theme_font_size_override("font_size", 10)
			cost_lbl.add_theme_color_override("font_color", Color(0.55, 0.52, 0.46))
			parent.add_child(cost_lbl)

		y += 46.0

## --- Drag-and-Drop Logic ---

## Returns true if the dragged payload is a valid drop for this slot type.
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

## Equips dragged item into the target member's slot, displacing any existing item to bag.
func _drop_to_slot(item: Dictionary, member_idx: int, slot_field: String) -> void:
	var member: CombatantData = GameState.party[member_idx]
	if item.get("item_type", "") == "equipment":
		var eq: EquipmentData = EquipmentLibrary.get_equipment(item["id"])
		match slot_field:
			"weapon":
				if member.weapon != null: _push_equipment_to_bag(member.weapon)
				member.weapon = eq
			"armor":
				if member.armor != null: _push_equipment_to_bag(member.armor)
				member.armor = eq
			"accessory":
				if member.accessory != null: _push_equipment_to_bag(member.accessory)
				member.accessory = eq
		GameState.remove_from_inventory(item["id"])
	elif item.get("item_type", "") == "consumable":
		if member.consumable != "":
			_push_consumable_to_bag(member.consumable)
		member.consumable = item["id"]
		GameState.remove_from_inventory(item["id"])
	_rebuild()

## Unequips an equipment slot — item returns to bag.
func _unequip_item(member_idx: int, slot_field: String) -> void:
	var member: CombatantData = GameState.party[member_idx]
	var eq: EquipmentData
	match slot_field:
		"weapon":    eq = member.weapon;    member.weapon    = null
		"armor":     eq = member.armor;     member.armor     = null
		"accessory": eq = member.accessory; member.accessory = null
	if eq != null:
		_push_equipment_to_bag(eq)
	_rebuild()

## Unequips the consumable slot — item returns to bag.
func _unequip_consumable(member_idx: int) -> void:
	var member: CombatantData = GameState.party[member_idx]
	if member.consumable != "":
		_push_consumable_to_bag(member.consumable)
		member.consumable = ""
	_rebuild()

## --- Inventory Push Helpers ---

func _push_equipment_to_bag(eq: EquipmentData) -> void:
	GameState.add_to_inventory({
		"id":          eq.equipment_id,
		"name":        eq.equipment_name,
		"description": eq.description,
		"item_type":   "equipment",
	})

func _push_consumable_to_bag(consumable_id: String) -> void:
	var cd: ConsumableData = ConsumableLibrary.get_consumable(consumable_id)
	GameState.add_to_inventory({
		"id":          cd.consumable_id,
		"name":        cd.consumable_name,
		"description": cd.description,
		"item_type":   "consumable",
	})

## --- Shared Helpers ---

func _truncate(text: String, max_chars: int) -> String:
	return text if text.length() <= max_chars else text.substr(0, max_chars - 1) + "…"

func _slot_name(slot: int) -> String:
	match slot:
		EquipmentData.Slot.WEAPON:    return "WEAPON"
		EquipmentData.Slot.ARMOR:     return "ARMOR"
		EquipmentData.Slot.ACCESSORY: return "ACCESSORY"
		_: return "?"

func _bonuses_str(bonuses: Dictionary) -> String:
	if bonuses.is_empty():
		return ""
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
