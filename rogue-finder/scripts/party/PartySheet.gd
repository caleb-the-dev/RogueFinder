class_name PartySheet
extends CanvasLayer

## --- PartySheet ---
## Full-screen overlay showing party cards + inventory bag.
## Opened from the "Party" button in MapManager UI chrome.
## Layer 20 — above map UI and combat UI (layer 15).
## S21: cards are clickable; opens a detail pane with equip/unequip actions.

const VIEWPORT_W: float  = 1280.0
const VIEWPORT_H: float  = 720.0
const CARD_W: float      = 360.0
const CARD_H: float      = 230.0
const DETAIL_H: float    = 400.0
const PORTRAIT_SZ: float = 72.0
const CARD_GAP: float    = 20.0

var _content_root: Control = null
## Index of the party member whose detail pane is open; -1 = none.
var _detail_open: int = -1

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

	# Full-screen dark overlay — eats all mouse input to block map interaction
	var overlay := ColorRect.new()
	overlay.color = Color(0.05, 0.04, 0.03, 0.92)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(overlay)

	# Close button — top-right
	var close_btn := Button.new()
	close_btn.text = "✕ Close"
	close_btn.size = Vector2(100.0, 34.0)
	close_btn.position = Vector2(VIEWPORT_W - 112.0, 10.0)
	close_btn.pressed.connect(hide_sheet)
	root.add_child(close_btn)

	# Party cards — 3 side-by-side; one may expand to a detail pane
	var total_w: float = 3.0 * CARD_W + 2.0 * CARD_GAP
	var cards_left: float = (VIEWPORT_W - total_w) * 0.5
	var cards_top: float  = 55.0
	var section_h: float  = CARD_H

	for i in range(3):
		var member: CombatantData = GameState.party[i] if i < GameState.party.size() else null
		var card_pos := Vector2(cards_left + float(i) * (CARD_W + CARD_GAP), cards_top)
		if i == _detail_open:
			_build_detail_pane(root, member, card_pos, i)
			section_h = DETAIL_H
		else:
			_build_party_card(root, member, card_pos, i)

	# Inventory — below the tallest section (card or detail pane)
	var inv_top: float = cards_top + section_h + 18.0
	# can_equip: inventory items act as equip buttons only for a living, open member
	var can_equip: bool = _detail_open >= 0 \
		and _detail_open < GameState.party.size() \
		and not GameState.party[_detail_open].is_dead
	_build_inventory(root, Vector2(60.0, inv_top),
			Vector2(VIEWPORT_W - 120.0, VIEWPORT_H - inv_top - 16.0), can_equip)

## --- Party Card (overview) ---

func _build_party_card(parent: Control, member: CombatantData, pos: Vector2, idx: int) -> void:
	var card := ColorRect.new()
	card.color = Color(0.10, 0.08, 0.06, 0.90)
	card.size = Vector2(CARD_W, CARD_H)
	card.position = pos
	parent.add_child(card)

	if member == null:
		var empty_lbl := Label.new()
		empty_lbl.text = "(empty slot)"
		empty_lbl.set_anchors_preset(Control.PRESET_CENTER)
		empty_lbl.add_theme_color_override("font_color", Color(0.55, 0.52, 0.48))
		card.add_child(empty_lbl)
		return

	var y: float = 10.0

	# Portrait — fall back to Godot icon
	var portrait := TextureRect.new()
	portrait.texture = member.portrait if member.portrait != null \
			else (load("res://icon.svg") as Texture2D)
	portrait.position = Vector2((CARD_W - PORTRAIT_SZ) * 0.5, y)
	portrait.size = Vector2(PORTRAIT_SZ, PORTRAIT_SZ)
	portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card.add_child(portrait)
	y += PORTRAIT_SZ + 8.0

	# Name
	var name_lbl := Label.new()
	name_lbl.text = member.character_name
	name_lbl.position = Vector2(0.0, y)
	name_lbl.size = Vector2(CARD_W, 22.0)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.90, 0.75))
	card.add_child(name_lbl)
	y += 24.0

	# Class
	var class_lbl := Label.new()
	class_lbl.text = member.unit_class
	class_lbl.position = Vector2(0.0, y)
	class_lbl.size = Vector2(CARD_W, 18.0)
	class_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	class_lbl.add_theme_font_size_override("font_size", 12)
	class_lbl.add_theme_color_override("font_color", Color(0.70, 0.65, 0.55))
	card.add_child(class_lbl)
	y += 22.0

	# HP bar
	var bar_w: float   = CARD_W - 40.0
	var bar_h: float   = 12.0
	var bar_x: float   = 20.0
	var hp_max_val: int = member.hp_max
	var hp_fill: float  = float(member.current_hp) / float(max(hp_max_val, 1))

	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.15, 0.08, 0.08)
	bar_bg.size = Vector2(bar_w, bar_h)
	bar_bg.position = Vector2(bar_x, y)
	card.add_child(bar_bg)

	if hp_fill > 0.0:
		var fill_color: Color = Color(0.22, 0.68, 0.28) if hp_fill > 0.5 else Color(0.70, 0.38, 0.12)
		var bar_fill := ColorRect.new()
		bar_fill.color = fill_color
		bar_fill.size = Vector2(bar_w * hp_fill, bar_h)
		bar_fill.position = Vector2(bar_x, y)
		card.add_child(bar_fill)
	y += bar_h + 4.0

	# HP text
	var hp_lbl := Label.new()
	hp_lbl.text = "HP: %d / %d" % [member.current_hp, hp_max_val]
	hp_lbl.position = Vector2(bar_x, y)
	hp_lbl.add_theme_font_size_override("font_size", 11)
	hp_lbl.add_theme_color_override("font_color", Color(0.82, 0.82, 0.82))
	card.add_child(hp_lbl)
	y += 18.0

	# Attributes row
	var attrs_lbl := Label.new()
	attrs_lbl.text = "STR %d  DEX %d  COG %d  WIL %d  VIT %d" % [
		member.strength, member.dexterity, member.cognition,
		member.willpower, member.vitality
	]
	attrs_lbl.position = Vector2(0.0, y)
	attrs_lbl.size = Vector2(CARD_W, 18.0)
	attrs_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	attrs_lbl.add_theme_font_size_override("font_size", 11)
	attrs_lbl.add_theme_color_override("font_color", Color(0.80, 0.78, 0.72))
	card.add_child(attrs_lbl)

	# Dead state — grey card, DEFEATED stamp above the card
	if member.is_dead:
		card.modulate = Color(0.5, 0.5, 0.5, 1.0)
		var stamp := Label.new()
		stamp.text = "DEFEATED"
		stamp.size = Vector2(CARD_W, 32.0)
		stamp.position = pos + Vector2(0.0, (CARD_H - 32.0) * 0.5)
		stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stamp.add_theme_font_size_override("font_size", 24)
		stamp.add_theme_color_override("font_color", Color(0.72, 0.12, 0.08))
		parent.add_child(stamp)

	# Transparent click-catcher — on top of all card content, opens detail pane
	var click_btn := Button.new()
	click_btn.flat = true
	click_btn.size = Vector2(CARD_W, CARD_H)
	click_btn.position = Vector2.ZERO
	click_btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	click_btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	click_btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	click_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	click_btn.pressed.connect(func(): _toggle_detail(idx))
	card.add_child(click_btn)

## --- Detail Pane (expanded card) ---

func _build_detail_pane(parent: Control, member: CombatantData, pos: Vector2, idx: int) -> void:
	var pane := ColorRect.new()
	pane.color = Color(0.08, 0.10, 0.14, 0.95)
	pane.size = Vector2(CARD_W, DETAIL_H)
	pane.position = pos
	parent.add_child(pane)

	var is_dead: bool = member != null and member.is_dead

	if is_dead:
		pane.modulate = Color(0.5, 0.5, 0.5, 1.0)

	# Scrollable content
	var scroll := ScrollContainer.new()
	scroll.size = Vector2(CARD_W, DETAIL_H)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	pane.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 6px narrower than pane to leave room for the scrollbar
	vbox.custom_minimum_size = Vector2(CARD_W - 6.0, 0.0)
	scroll.add_child(vbox)

	# Header — click to collapse
	var header_btn := Button.new()
	header_btn.text = "%s  ·  %s  ▲" % [member.character_name, member.unit_class]
	header_btn.flat = true
	header_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header_btn.custom_minimum_size = Vector2(CARD_W - 6.0, 28.0)
	header_btn.add_theme_font_size_override("font_size", 14)
	header_btn.add_theme_color_override("font_color", Color(0.95, 0.90, 0.75))
	header_btn.pressed.connect(func(): _toggle_detail(idx))
	vbox.add_child(header_btn)

	# --- Base Attributes ---
	_detail_section(vbox, "ATTRIBUTES")
	_detail_row(vbox, "STR", str(member.strength))
	_detail_row(vbox, "DEX", str(member.dexterity))
	_detail_row(vbox, "COG", str(member.cognition))
	_detail_row(vbox, "WIL", str(member.willpower))
	_detail_row(vbox, "VIT", str(member.vitality))

	# --- Derived Stats ---
	_detail_section(vbox, "DERIVED STATS")
	_detail_row(vbox, "HP Max",      str(member.hp_max))
	_detail_row(vbox, "Energy Max",  str(member.energy_max))
	_detail_row(vbox, "Speed",       str(member.speed))
	_detail_row(vbox, "Attack",      str(member.attack))
	_detail_row(vbox, "Defense",     str(member.defense))
	_detail_row(vbox, "Enrg Regen",  str(member.energy_regen))

	# --- Abilities ---
	_detail_section(vbox, "ABILITIES")
	for ability_id: String in member.abilities:
		if ability_id == "":
			_detail_row(vbox, "—", "empty —")
		else:
			var ab: AbilityData = AbilityLibrary.get_ability(ability_id)
			_detail_row(vbox, ab.ability_name, ab.description)

	# --- Equipment slots ---
	_detail_section(vbox, "EQUIPMENT")
	var equip_defs: Array = [
		["WEAPON",    member.weapon,     "weapon"],
		["ARMOR",     member.armor,      "armor"],
		["ACCESSORY", member.accessory,  "accessory"],
	]
	for slot_def: Array in equip_defs:
		var slot_label: String     = slot_def[0]
		var eq: EquipmentData      = slot_def[1]
		var slot_field: String     = slot_def[2]
		var slot_btn := Button.new()
		if eq != null:
			slot_btn.text = "%s: %s  %s" % [slot_label, eq.equipment_name, _bonuses_str(eq.stat_bonuses)]
		else:
			slot_btn.text = "%s: — unequipped —" % slot_label
		slot_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		slot_btn.custom_minimum_size = Vector2(CARD_W - 16.0, 26.0)
		slot_btn.add_theme_font_size_override("font_size", 12)
		if is_dead or eq == null:
			slot_btn.disabled = true
		else:
			slot_btn.pressed.connect(func(): _unequip_item(idx, slot_field))
		vbox.add_child(slot_btn)

	# --- Consumable slot ---
	_detail_section(vbox, "CONSUMABLE")
	var cons_btn := Button.new()
	if member.consumable != "":
		var cd: ConsumableData = ConsumableLibrary.get_consumable(member.consumable)
		cons_btn.text = "%s  —  %s" % [cd.consumable_name, cd.description]
	else:
		cons_btn.text = "— none —"
	cons_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	cons_btn.custom_minimum_size = Vector2(CARD_W - 16.0, 26.0)
	cons_btn.add_theme_font_size_override("font_size", 12)
	if is_dead or member.consumable == "":
		cons_btn.disabled = true
	else:
		cons_btn.pressed.connect(func(): _unequip_consumable(idx))
	vbox.add_child(cons_btn)

	# DEFEATED stamp — added to parent so it renders above the greyed pane
	if is_dead:
		var stamp := Label.new()
		stamp.text = "DEFEATED"
		stamp.size = Vector2(CARD_W, 32.0)
		stamp.position = pos + Vector2(0.0, (DETAIL_H - 32.0) * 0.5)
		stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stamp.add_theme_font_size_override("font_size", 24)
		stamp.add_theme_color_override("font_color", Color(0.72, 0.12, 0.08))
		parent.add_child(stamp)

## --- Inventory ---

func _build_inventory(parent: Control, pos: Vector2, size: Vector2, can_equip: bool) -> void:
	var header := Label.new()
	header.text = "BAG" if not can_equip else "BAG  (click an item to equip it)"
	header.position = pos
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(0.90, 0.82, 0.60))
	parent.add_child(header)

	var scroll := ScrollContainer.new()
	scroll.position = pos + Vector2(0.0, 26.0)
	scroll.size = size - Vector2(0.0, 26.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	parent.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.custom_minimum_size = Vector2(size.x - 20.0, 0.0)
	scroll.add_child(vbox)

	var inventory: Array = GameState.inventory

	if inventory.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "— empty —"
		empty_lbl.add_theme_font_size_override("font_size", 13)
		empty_lbl.add_theme_color_override("font_color", Color(0.50, 0.48, 0.44))
		vbox.add_child(empty_lbl)
		return

	for item: Dictionary in inventory:
		var item_text: String
		if item.get("item_type", "") == "equipment":
			var eq: EquipmentData = EquipmentLibrary.get_equipment(item["id"])
			item_text = "%s  [%s]  %s" % [item["name"], _slot_name(eq.slot), _bonuses_str(eq.stat_bonuses)]
		else:
			item_text = "%s  [consumable]  %s" % [item["name"], item.get("description", "")]

		if can_equip:
			var btn := Button.new()
			btn.text = item_text
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.add_theme_font_size_override("font_size", 13)
			# Capture item by value for the closure
			var captured: Dictionary = item
			btn.pressed.connect(func(): _equip_from_inventory(captured))
			vbox.add_child(btn)
		else:
			var row := Label.new()
			row.text = item_text
			row.add_theme_font_size_override("font_size", 13)
			row.add_theme_color_override("font_color", Color(0.88, 0.85, 0.78))
			vbox.add_child(row)

## --- Equip / Unequip Actions ---

func _toggle_detail(idx: int) -> void:
	_detail_open = -1 if _detail_open == idx else idx
	_rebuild()

func _equip_from_inventory(item: Dictionary) -> void:
	if _detail_open < 0 or _detail_open >= GameState.party.size():
		return
	var member: CombatantData = GameState.party[_detail_open]
	if member.is_dead:
		return

	if item.get("item_type", "") == "equipment":
		var eq: EquipmentData = EquipmentLibrary.get_equipment(item["id"])
		# Displace whatever is in the target slot back to the bag
		match eq.slot:
			EquipmentData.Slot.WEAPON:
				if member.weapon != null:
					_push_equipment_to_bag(member.weapon)
				member.weapon = eq
			EquipmentData.Slot.ARMOR:
				if member.armor != null:
					_push_equipment_to_bag(member.armor)
				member.armor = eq
			EquipmentData.Slot.ACCESSORY:
				if member.accessory != null:
					_push_equipment_to_bag(member.accessory)
				member.accessory = eq
		GameState.remove_from_inventory(item["id"])

	elif item.get("item_type", "") == "consumable":
		# Return existing consumable to bag before replacing
		if member.consumable != "":
			_push_consumable_to_bag(member.consumable)
		member.consumable = item["id"]
		GameState.remove_from_inventory(item["id"])

	_rebuild()

func _unequip_item(member_idx: int, slot_field: String) -> void:
	var member: CombatantData = GameState.party[member_idx]
	var eq: EquipmentData
	match slot_field:
		"weapon":
			eq = member.weapon
			member.weapon = null
		"armor":
			eq = member.armor
			member.armor = null
		"accessory":
			eq = member.accessory
			member.accessory = null
	if eq != null:
		_push_equipment_to_bag(eq)
	_rebuild()

func _unequip_consumable(member_idx: int) -> void:
	var member: CombatantData = GameState.party[member_idx]
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

## --- Detail Pane Layout Helpers ---

func _detail_section(vbox: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.65, 0.60, 0.50))
	vbox.add_child(lbl)

func _detail_row(vbox: VBoxContainer, label: String, value: String) -> void:
	var lbl := Label.new()
	lbl.text = "  %s: %s" % [label, value]
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75))
	vbox.add_child(lbl)

## --- Shared Helpers ---

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
