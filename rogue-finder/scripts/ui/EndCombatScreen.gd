class_name EndCombatScreen
extends CanvasLayer

## --- EndCombatScreen ---
## Full-screen overlay shown when combat ends.
## Layer 15 — above all other UI (4, 8, 10, 12).
## Build all children in code; no .tscn required.

const MAP_SCENE_PATH := "res://scenes/map/MapScene.tscn"

var _reward_cards:  Array[PanelContainer] = []
## Guards against double-selection if gui_input fires twice.
var _reward_chosen: bool = false

func _init() -> void:
	layer = 15

func _ready() -> void:
	visible = false

## --- Public API ---

func show_victory(reward_items: Array, gold_amount: int = 0) -> void:
	_reward_chosen = false
	_build_victory_layout(reward_items, gold_amount)
	visible = true

## --- Victory Layout ---

func _build_victory_layout(items: Array, gold_amount: int) -> void:
	var bg := _make_background()
	add_child(bg)

	var header := Label.new()
	header.text                   = "VICTORY"
	header.add_theme_font_size_override("font_size", 64)
	header.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	header.horizontal_alignment   = HORIZONTAL_ALIGNMENT_CENTER
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.position = Vector2(0.0, 110.0)
	bg.add_child(header)

	## Gold line — shown above item cards; uses Hire Roster gold color
	var gold_lbl := Label.new()
	gold_lbl.text = "+%d Gold  (Total: %d)" % [gold_amount, GameState.gold]
	gold_lbl.add_theme_font_size_override("font_size", 22)
	gold_lbl.add_theme_color_override("font_color", Color(0.90, 0.80, 0.30))
	gold_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	gold_lbl.position = Vector2(0.0, 195.0)
	bg.add_child(gold_lbl)

	var subtitle := Label.new()
	subtitle.text                 = "Choose your reward:"
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.set_anchors_preset(Control.PRESET_TOP_WIDE)
	subtitle.position = Vector2(0.0, 225.0)
	bg.add_child(subtitle)

	var card_w  := 270.0
	var gap     := 30.0
	var total_w := card_w * 3.0 + gap * 2.0
	var start_x := (1152.0 - total_w) / 2.0
	var card_y  := 265.0

	_reward_cards.clear()
	for i in range(items.size()):
		var item: Dictionary = items[i]
		var card := _build_reward_card(item, card_w)
		card.position = Vector2(start_x + i * (card_w + gap), card_y)
		bg.add_child(card)
		_reward_cards.append(card)


func _build_reward_card(item: Dictionary, w: float) -> PanelContainer:
	var rarity: int = item.get("rarity", EquipmentData.Rarity.COMMON)
	var rarity_col: Color = EquipmentData.RARITY_COLORS.get(rarity, EquipmentData.RARITY_COLORS[0])

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(w, 160.0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var sbox := StyleBoxFlat.new()
	sbox.bg_color            = Color(0.10, 0.09, 0.08, 0.92)
	sbox.border_width_left   = 2; sbox.border_width_top    = 2
	sbox.border_width_right  = 2; sbox.border_width_bottom = 2
	sbox.border_color        = rarity_col
	sbox.set_corner_radius_all(4)
	sbox.content_margin_left   = 10; sbox.content_margin_right  = 10
	sbox.content_margin_top    = 10; sbox.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", sbox)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	card.add_child(vbox)

	## Item name
	var name_lbl := Label.new()
	name_lbl.text = item.get("name", "?")
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", rarity_col)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)

	if item.get("item_type", "") == "equipment":
		var eq: EquipmentData = EquipmentLibrary.get_equipment(item.get("id", ""))

		## Stat bonuses row — one chip per bonus, tooltip on hover
		if not eq.stat_bonuses.is_empty():
			var stats_row := HBoxContainer.new()
			stats_row.alignment = BoxContainer.ALIGNMENT_CENTER
			stats_row.add_theme_constant_override("separation", 8)
			stats_row.mouse_filter = Control.MOUSE_FILTER_PASS
			var first := true
			for stat_name: String in eq.stat_bonuses:
				if not first:
					var dot := Label.new()
					dot.text = "·"
					dot.add_theme_font_size_override("font_size", 11)
					dot.add_theme_color_override("font_color", Color(0.42, 0.40, 0.36))
					dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
					stats_row.add_child(dot)
				first = false
				var val: int = eq.stat_bonuses[stat_name]
				var chip := Label.new()
				chip.text = "%s %s%d" % [_stat_abbrev(stat_name), "+" if val >= 0 else "", val]
				chip.add_theme_font_size_override("font_size", 12)
				chip.add_theme_color_override("font_color",
					Color(0.95, 0.82, 0.35) if val > 0 else Color(0.90, 0.42, 0.38))
				chip.tooltip_text = "%s %+d — %s" % [
					stat_name.capitalize().replace("_", " "), val, _stat_desc(stat_name)]
				chip.mouse_filter = Control.MOUSE_FILTER_PASS
				stats_row.add_child(chip)
			vbox.add_child(stats_row)

		## Granted abilities — label per ability, tooltip on hover
		if not eq.granted_ability_ids.is_empty():
			var grants_hdr := Label.new()
			grants_hdr.text = "Grants:"
			grants_hdr.add_theme_font_size_override("font_size", 10)
			grants_hdr.add_theme_color_override("font_color", Color(0.55, 0.53, 0.65))
			grants_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			grants_hdr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.add_child(grants_hdr)
			for aid: String in eq.granted_ability_ids:
				var ab: AbilityData = AbilityLibrary.get_ability(aid)
				var ab_lbl := Label.new()
				ab_lbl.text = ab.ability_name
				ab_lbl.add_theme_font_size_override("font_size", 13)
				ab_lbl.add_theme_color_override("font_color", Color(0.65, 0.82, 1.00))
				ab_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				var range_str: String = "whole map" if ab.tile_range == -1 \
					else "%d tile%s" % [ab.tile_range, "s" if ab.tile_range != 1 else ""]
				ab_lbl.tooltip_text = "%s\n%s · CD %d · %s\n\n%s" % [
					ab.ability_name, _attr_abbrev(ab.attribute),
					ab.cooldown_max, range_str, ab.description]
				ab_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
				vbox.add_child(ab_lbl)

	var sep := HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sep)

	## Flavor description
	var desc_lbl := Label.new()
	desc_lbl.text = item.get("description", "")
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.72, 0.64))
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(desc_lbl)

	## Click anywhere on card to select this reward.
	## Using gui_input on PanelContainer instead of overlay button so child
	## labels retain their MOUSE_FILTER_PASS and can show tooltips on hover.
	card.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton \
				and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT \
				and (ev as InputEventMouseButton).pressed:
			_on_reward_chosen(item, card, name_lbl, sbox)
	)

	return card


func _on_reward_chosen(item: Dictionary, card: PanelContainer,
		name_lbl: Label, sbox: StyleBoxFlat) -> void:
	if _reward_chosen:
		return
	_reward_chosen = true
	GameState.add_to_inventory(item)
	name_lbl.text = "✓ " + item.get("name", "?")
	if sbox != null:
		sbox.border_width_left   = 3; sbox.border_width_top    = 3
		sbox.border_width_right  = 3; sbox.border_width_bottom = 3
	if not GameState.current_combat_node_id.is_empty():
		if not GameState.cleared_nodes.has(GameState.current_combat_node_id):
			GameState.cleared_nodes.append(GameState.current_combat_node_id)
		if GameState.node_types.get(GameState.current_combat_node_id, "") == "BOSS":
			GameState.threat_level = 0.0
	GameState.save()
	_return_to_map()

## --- Display Helpers ---

func _stat_abbrev(stat: String) -> String:
	match stat:
		"strength":       return "STR"
		"dexterity":      return "DEX"
		"cognition":      return "COG"
		"vitality":       return "VIT"
		"willpower":      return "WIL"
		"physical_armor": return "P.ARM"
		"magic_armor":    return "M.ARM"
		_: return stat.substr(0, 3).to_upper()

func _stat_desc(stat: String) -> String:
	match stat:
		"strength":       return "drives attack damage"
		"dexterity":      return "feeds speed and dodge bonuses"
		"cognition":      return "reserved for ability cost scaling"
		"vitality":       return "drives max HP and max energy"
		"willpower":      return "drives energy regen per turn"
		"physical_armor": return "reduces incoming PHYSICAL damage"
		"magic_armor":    return "reduces incoming MAGIC damage"
		_: return ""

func _attr_abbrev(attr: int) -> String:
	match attr:
		AbilityData.Attribute.STRENGTH:  return "STR"
		AbilityData.Attribute.DEXTERITY: return "DEX"
		AbilityData.Attribute.COGNITION: return "COG"
		AbilityData.Attribute.VITALITY:  return "VIT"
		AbilityData.Attribute.WILLPOWER: return "WIL"
		_: return ""

## --- Helpers ---

func _make_background() -> ColorRect:
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.75)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	return bg

func _return_to_map() -> void:
	get_tree().change_scene_to_file(MAP_SCENE_PATH)
