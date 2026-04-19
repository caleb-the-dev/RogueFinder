class_name PartySheet
extends CanvasLayer

## --- PartySheet ---
## Full-screen read-only overlay showing party cards + inventory bag.
## Opened from the "Party" button in MapManager UI chrome.
## Layer 20 — above map UI and combat UI (layer 15).

const VIEWPORT_W: float  = 1280.0
const VIEWPORT_H: float  = 720.0
const CARD_W: float      = 360.0
const CARD_H: float      = 230.0
const PORTRAIT_SZ: float = 72.0
const CARD_GAP: float    = 20.0

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

	# Party cards — top half, 3 side-by-side
	var total_w: float = 3.0 * CARD_W + 2.0 * CARD_GAP
	var cards_left: float = (VIEWPORT_W - total_w) * 0.5
	var cards_top: float  = 55.0
	for i in range(3):
		var member: CombatantData = GameState.party[i] if i < GameState.party.size() else null
		var card_pos := Vector2(cards_left + float(i) * (CARD_W + CARD_GAP), cards_top)
		_build_party_card(root, member, card_pos)

	# Inventory — bottom half
	var inv_top: float = cards_top + CARD_H + 18.0
	_build_inventory(root, Vector2(60.0, inv_top),
			Vector2(VIEWPORT_W - 120.0, VIEWPORT_H - inv_top - 16.0))

## --- Party Card ---

func _build_party_card(parent: Control, member: CombatantData, pos: Vector2) -> void:
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

	# Portrait — fall back to Godot icon (CombatantData.portrait is null on all current archetypes)
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

	# HP bar track
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

	# Dead state — grey card, add DEFEATED stamp to parent so it isn't greyed
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

## --- Inventory ---

func _build_inventory(parent: Control, pos: Vector2, size: Vector2) -> void:
	var header := Label.new()
	header.text = "BAG"
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
		var row := Label.new()
		row.add_theme_font_size_override("font_size", 13)
		row.add_theme_color_override("font_color", Color(0.88, 0.85, 0.78))
		if item.get("item_type", "") == "equipment":
			var eq: EquipmentData = EquipmentLibrary.get_equipment(item["id"])
			row.text = "%s  %s  %s" % [item["name"], _slot_name(eq.slot), _bonuses_str(eq.stat_bonuses)]
		else:
			row.text = "%s  consumable  %s" % [item["name"], item.get("description", "")]
		vbox.add_child(row)

## --- Helpers ---

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
