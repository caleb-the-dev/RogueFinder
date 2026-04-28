class_name BenchSwapPanel
extends RefCounted

## Builds a bench-swap comparison panel as a plain Control tree.
## Caller adds the returned Control to a CanvasLayer.
##
## on_swap(bench_idx: int) — player chose to release bench[bench_idx]
## on_cancel()             — player declined; do not swap

static func build_panel(new_recruit: CombatantData, cancel_label: String,
		on_swap: Callable, on_cancel: Callable) -> Control:

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var centering := CenterContainer.new()
	centering.set_anchors_preset(Control.PRESET_FULL_RECT)
	centering.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(centering)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(900.0, 540.0)
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color            = Color(0.06, 0.05, 0.04, 0.97)
	pstyle.border_width_left   = 2;  pstyle.border_width_right  = 2
	pstyle.border_width_top    = 2;  pstyle.border_width_bottom = 2
	pstyle.border_color        = Color(0.50, 0.38, 0.22)
	pstyle.set_corner_radius_all(6)
	pstyle.content_margin_left = 16.0; pstyle.content_margin_right  = 16.0
	pstyle.content_margin_top  = 14.0; pstyle.content_margin_bottom = 14.0
	panel.add_theme_stylebox_override("panel", pstyle)
	centering.add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	panel.add_child(outer)

	# Header
	var hdr := Label.new()
	hdr.text = "Bench is full — swap someone out for the new recruit?"
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.add_theme_font_size_override("font_size", 16)
	hdr.add_theme_color_override("font_color", Color(0.90, 0.80, 0.55))
	outer.add_child(hdr)

	# Column headers
	var col_hdr := HBoxContainer.new()
	col_hdr.add_theme_constant_override("separation", 12)
	outer.add_child(col_hdr)

	var new_col_lbl := Label.new()
	new_col_lbl.text = "NEW RECRUIT"
	new_col_lbl.custom_minimum_size = Vector2(240.0, 0.0)
	new_col_lbl.add_theme_font_size_override("font_size", 10)
	new_col_lbl.add_theme_color_override("font_color", Color(0.40, 0.75, 0.32))
	col_hdr.add_child(new_col_lbl)

	var bench_col_lbl := Label.new()
	bench_col_lbl.text = "YOUR BENCH   (Δ = new recruit − bench member  ·  green: new recruit is higher  ·  red: bench member is higher)"
	bench_col_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bench_col_lbl.add_theme_font_size_override("font_size", 10)
	bench_col_lbl.add_theme_color_override("font_color", Color(0.52, 0.50, 0.40))
	col_hdr.add_child(bench_col_lbl)

	# Main content row
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(content)

	content.add_child(_recruit_card(new_recruit))

	var vsep := VSeparator.new()
	content.add_child(vsep)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)

	var bench_list := VBoxContainer.new()
	bench_list.size_flags_horizontal = Control.SIZE_FILL
	bench_list.add_theme_constant_override("separation", 5)
	scroll.add_child(bench_list)

	for i in GameState.bench.size():
		bench_list.add_child(_bench_card(GameState.bench[i], new_recruit, i, on_swap))

	# Cancel / lose-recruit button
	var cancel_row := HBoxContainer.new()
	cancel_row.alignment = BoxContainer.ALIGNMENT_CENTER
	outer.add_child(cancel_row)

	var cancel_btn := Button.new()
	cancel_btn.text = cancel_label
	cancel_btn.custom_minimum_size = Vector2(200.0, 36.0)
	cancel_btn.add_theme_font_size_override("font_size", 14)
	cancel_btn.pressed.connect(on_cancel)
	cancel_row.add_child(cancel_btn)

	return root


## Left card: portrait + identity + 10-stat grid.
static func _recruit_card(recruit: CombatantData) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(240.0, 0.0)
	var sbox := StyleBoxFlat.new()
	sbox.bg_color          = Color(0.08, 0.12, 0.07, 1.0)
	sbox.border_width_left = 1; sbox.border_width_right = 1
	sbox.border_width_top  = 1; sbox.border_width_bottom = 1
	sbox.border_color      = Color(0.32, 0.58, 0.26)
	sbox.set_corner_radius_all(4)
	sbox.content_margin_left = 10.0; sbox.content_margin_right  = 10.0
	sbox.content_margin_top  = 8.0;  sbox.content_margin_bottom = 8.0
	card.add_theme_stylebox_override("panel", sbox)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	# Portrait + identity row
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	vbox.add_child(top_row)

	var portrait := _portrait_rect(Vector2(64.0, 64.0), recruit)
	top_row.add_child(portrait)

	var id_vbox := VBoxContainer.new()
	id_vbox.add_theme_constant_override("separation", 2)
	id_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_row.add_child(id_vbox)

	_lbl(id_vbox, recruit.character_name, 15, Color(0.95, 0.90, 0.70))
	_lbl(id_vbox, recruit.archetype_id.replace("_", " "), 11, Color(0.62, 0.58, 0.48))
	if recruit.background != "":
		_lbl(id_vbox, "Bg: %s" % recruit.background, 11, Color(0.52, 0.50, 0.40))
	_lbl(id_vbox, "Level %d" % recruit.level, 11, Color(0.65, 0.62, 0.52))

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 2)
	vbox.add_child(grid)

	for pair in _stat_list(recruit):
		_lbl(grid, pair[0], 12, Color(0.55, 0.52, 0.44))
		_lbl(grid, str(pair[1]), 12, Color(0.90, 0.87, 0.78))

	return card


## Right-side card: small portrait + identity + 10-stat grid (6-col, 5 rows) + Swap button.
static func _bench_card(member: CombatantData, recruit: CombatantData,
		bench_idx: int, on_swap: Callable) -> Control:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_FILL
	var sbox := StyleBoxFlat.new()
	sbox.bg_color          = Color(0.09, 0.08, 0.07, 1.0)
	sbox.border_width_left = 1; sbox.border_width_right = 1
	sbox.border_width_top  = 1; sbox.border_width_bottom = 1
	sbox.border_color      = Color(0.30, 0.27, 0.22)
	sbox.set_corner_radius_all(4)
	sbox.content_margin_left = 8.0; sbox.content_margin_right  = 8.0
	sbox.content_margin_top  = 6.0; sbox.content_margin_bottom = 6.0
	card.add_theme_stylebox_override("panel", sbox)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	card.add_child(hbox)

	# Identity: portrait + text
	var id_hbox := HBoxContainer.new()
	id_hbox.custom_minimum_size = Vector2(155.0, 0.0)
	id_hbox.add_theme_constant_override("separation", 6)
	id_hbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(id_hbox)

	var portrait := _portrait_rect(Vector2(36.0, 36.0), member)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	id_hbox.add_child(portrait)

	var id_vbox := VBoxContainer.new()
	id_vbox.add_theme_constant_override("separation", 2)
	id_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	id_hbox.add_child(id_vbox)

	_lbl(id_vbox, member.character_name, 13, Color(0.88, 0.84, 0.68))
	_lbl(id_vbox, member.archetype_id.replace("_", " "), 11, Color(0.56, 0.52, 0.43))
	_lbl(id_vbox, "Lv %d" % member.level, 11, Color(0.56, 0.52, 0.43))

	# Stats grid: (label, value, Δ) × 2 per row → 6 columns, 5 rows
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 2)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	hbox.add_child(grid)

	var m_stats := _stat_list(member)
	var r_stats := _stat_list(recruit)
	for i in m_stats.size():
		_lbl(grid, m_stats[i][0], 11, Color(0.50, 0.48, 0.40))
		_lbl(grid, str(m_stats[i][1]), 11, Color(0.82, 0.80, 0.72))
		_delta_lbl(grid, r_stats[i][1] - m_stats[i][1])

	# Swap button
	var swap_btn := Button.new()
	swap_btn.text = "Swap →"
	swap_btn.custom_minimum_size = Vector2(74.0, 0.0)
	swap_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swap_btn.add_theme_font_size_override("font_size", 13)
	var idx := bench_idx
	swap_btn.pressed.connect(func() -> void: on_swap.call(idx))
	hbox.add_child(swap_btn)

	return card


## Returns [ [label, value], ... ] for the 10 tracked stats in display order.
static func _stat_list(c: CombatantData) -> Array:
	return [
		["HP",     c.hp_max],
		["Energy", c.energy_max],
		["STR",    c.strength],
		["DEX",    c.dexterity],
		["COG",    c.cognition],
		["WIL",    c.willpower],
		["VIT",    c.vitality],
		["Spd",    c.speed],
		["P.Arm",  c.physical_armor],
		["M.Arm",  c.magic_armor],
	]


## Portrait TextureRect using artwork_idle if set, otherwise the placeholder icon.
static func _portrait_rect(size: Vector2, c: CombatantData) -> TextureRect:
	var tr := TextureRect.new()
	var arch: ArchetypeData = ArchetypeLibrary.get_archetype(c.archetype_id)
	if arch.artwork_idle != "":
		tr.texture = load(arch.artwork_idle)
	else:
		tr.texture = load("res://icon.svg")
	tr.custom_minimum_size = size
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	return tr


static func _lbl(parent: Control, text: String, font_size: int, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	parent.add_child(lbl)


static func _delta_lbl(parent: Control, delta: int) -> void:
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", 11)
	if delta > 0:
		lbl.text = "+%d" % delta
		lbl.add_theme_color_override("font_color", Color(0.30, 0.80, 0.30))
	elif delta < 0:
		lbl.text = str(delta)
		lbl.add_theme_color_override("font_color", Color(0.82, 0.32, 0.32))
	else:
		lbl.text = "="
		lbl.add_theme_color_override("font_color", Color(0.48, 0.46, 0.38))
	parent.add_child(lbl)
