class_name VendorOverlay
extends CanvasLayer

## --- VendorOverlay ---
## Modal vendor shop (layer 20). Call show_vendor(instance_key) to open.
## instance_key: vendor_id for CITY vendors, node_id for WORLD vendors.
## Wired to map VENDOR nodes + Badurga stalls by Slice 6.

signal closed

const GOLD_COLOR := Color(0.90, 0.80, 0.30)

## --- State ---

var _stock: Array = []
var _name_lbl: Label
var _flavor_lbl: Label
var _gold_lbl: Label
var _scroll_vbox: VBoxContainer

## --- Lifecycle ---

func _ready() -> void:
	layer = 20
	visible = false
	add_to_group("blocks_pause")
	_build_ui()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_on_close()
		get_viewport().set_input_as_handled()

## --- Public API ---

func show_vendor(instance_key: String) -> void:
	_stock = GameState.vendor_stocks.get(instance_key, [])
	var vendor_id: String = _stock[0].get("vendor_id", "") if not _stock.is_empty() else ""
	var vendor: VendorData = VendorLibrary.get_vendor(vendor_id)
	_name_lbl.text = vendor.display_name
	_flavor_lbl.text = vendor.flavor
	_refresh_gold()
	_rebuild_stock_rows()
	visible = true

## Attempts to purchase a stock entry. Modifies GameState directly.
## Returns true on success; false if insufficient gold or already sold.
## Static so tests can call VendorOverlay.try_buy(entry) without instantiating the scene.
static func try_buy(entry: Dictionary) -> bool:
	if entry.get("sold", false):
		return false
	var price: int = entry.get("price", 0)
	if GameState.gold < price:
		return false
	GameState.gold -= price
	entry["sold"] = true
	GameState.add_to_inventory(entry["item"].duplicate())
	GameState.save()
	return true

## --- UI Construction ---

func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.06, 0.05, 0.07, 0.97)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 6)
	root_vbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(root_vbox)

	## --- Header row ---
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	root_vbox.add_child(header)

	_name_lbl = Label.new()
	_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_lbl.add_theme_font_size_override("font_size", 22)
	_name_lbl.add_theme_color_override("font_color", Color(0.95, 0.88, 0.65))
	header.add_child(_name_lbl)

	_flavor_lbl = Label.new()
	_flavor_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_flavor_lbl.add_theme_font_size_override("font_size", 13)
	_flavor_lbl.add_theme_color_override("font_color", Color(0.65, 0.60, 0.50))
	_flavor_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_flavor_lbl)

	_gold_lbl = Label.new()
	_gold_lbl.add_theme_font_size_override("font_size", 18)
	_gold_lbl.add_theme_color_override("font_color", GOLD_COLOR)
	_gold_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_gold_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_gold_lbl.custom_minimum_size = Vector2(120.0, 0.0)
	header.add_child(_gold_lbl)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(44.0, 34.0)
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.pressed.connect(_on_close)
	header.add_child(close_btn)

	root_vbox.add_child(_make_hsep())

	## --- Scrollable stock list ---
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(scroll)

	_scroll_vbox = VBoxContainer.new()
	_scroll_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(_scroll_vbox)

func _make_hsep() -> HSeparator:
	return HSeparator.new()

## --- Stock Row Management ---

func _refresh_gold() -> void:
	_gold_lbl.text = "Gold: %d" % GameState.gold

func _rebuild_stock_rows() -> void:
	for child in _scroll_vbox.get_children():
		child.queue_free()

	if _stock.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No stock available."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_color_override("font_color", Color(0.50, 0.48, 0.45))
		_scroll_vbox.add_child(empty_lbl)
		return

	for i in range(_stock.size()):
		_scroll_vbox.add_child(_build_stock_row(_stock[i], i))

func _build_stock_row(entry: Dictionary, idx: int) -> HBoxContainer:
	var item: Dictionary = entry.get("item", {})
	var price: int = entry.get("price", 0)
	var sold: bool = entry.get("sold", false)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size = Vector2(0.0, 40.0)

	## Item name — rarity-colored, or grey when sold
	var name_lbl := Label.new()
	name_lbl.text = item.get("name", "Unknown")
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color",
		Color(0.40, 0.38, 0.35) if sold else _rarity_color(item))
	row.add_child(name_lbl)

	## Stat summary
	var stat_lbl := Label.new()
	stat_lbl.text = _format_stats(item)
	stat_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stat_lbl.add_theme_font_size_override("font_size", 12)
	stat_lbl.add_theme_color_override("font_color",
		Color(0.45, 0.43, 0.40) if sold else Color(0.72, 0.68, 0.55))
	row.add_child(stat_lbl)

	## Price
	var price_lbl := Label.new()
	price_lbl.text = "%d g" % price
	price_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price_lbl.add_theme_font_size_override("font_size", 15)
	price_lbl.add_theme_color_override("font_color",
		Color(0.40, 0.38, 0.35) if sold else GOLD_COLOR)
	price_lbl.custom_minimum_size = Vector2(64.0, 0.0)
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(price_lbl)

	## Buy / SOLD
	if sold:
		var sold_lbl := Label.new()
		sold_lbl.text = "SOLD"
		sold_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		sold_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sold_lbl.add_theme_font_size_override("font_size", 13)
		sold_lbl.add_theme_color_override("font_color", Color(0.45, 0.43, 0.40))
		sold_lbl.custom_minimum_size = Vector2(84.0, 32.0)
		row.add_child(sold_lbl)
	else:
		var buy_btn := Button.new()
		buy_btn.text = "Buy"
		buy_btn.custom_minimum_size = Vector2(84.0, 32.0)
		buy_btn.add_theme_font_size_override("font_size", 13)
		buy_btn.disabled = GameState.gold < price
		buy_btn.pressed.connect(_on_buy_pressed.bind(idx))
		row.add_child(buy_btn)

	return row

func _on_buy_pressed(idx: int) -> void:
	if idx < 0 or idx >= _stock.size():
		return
	if not try_buy(_stock[idx]):
		return
	_refresh_gold()
	_rebuild_stock_rows()

func _on_close() -> void:
	visible = false
	closed.emit()
	queue_free()

## --- Helpers ---

func _rarity_color(item: Dictionary) -> Color:
	var rarity: int = item.get("rarity", EquipmentData.Rarity.COMMON)
	return EquipmentData.RARITY_COLORS.get(rarity, EquipmentData.RARITY_COLORS[EquipmentData.Rarity.COMMON])

## One-line stat summary for display in the stock row.
## Equipment → stat_bonuses formatted as "STR +1  VIT +2"; fallback to description.
## Consumable → short description text.
func _format_stats(item: Dictionary) -> String:
	if item.get("item_type", "") == "equipment":
		var eq: EquipmentData = EquipmentLibrary.get_equipment(item.get("id", ""))
		if eq.stat_bonuses.is_empty():
			return eq.description
		var parts: PackedStringArray = []
		for key: String in eq.stat_bonuses:
			var val: int = eq.stat_bonuses[key]
			parts.append("%s %s%d" % [_stat_abbr(key), "+" if val >= 0 else "", val])
		return "  ".join(parts)
	return item.get("description", "")

func _stat_abbr(stat: String) -> String:
	match stat:
		"strength":       return "STR"
		"dexterity":      return "DEX"
		"cognition":      return "COG"
		"willpower":      return "WIL"
		"vitality":       return "VIT"
		"physical_armor": return "P.DEF"
		"magic_armor":    return "M.DEF"
		_: return stat.substr(0, 3).to_upper()
