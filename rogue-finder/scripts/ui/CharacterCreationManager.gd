class_name CharacterCreationManager
extends CanvasLayer

## --- CharacterCreationManager ---
## Single-screen character creation. Player picks name, kindred, class,
## background, and portrait. Builds CombatantData and hands off to MapScene.
## B2: inline slot-wheel columns. B3 will extract these into a reusable Dial component.

const MAP_SCENE_PATH       := "res://scenes/map/MapScene.tscn"
const MAIN_MENU_SCENE_PATH := "res://scenes/ui/MainMenuScene.tscn"

var _kindred_ids:   Array[String] = []
var _class_ids:     Array[String] = []
var _class_display: Array[String] = []
var _bg_ids:        Array[String] = []
var _bg_display:    Array[String] = []
var _portrait_ids:  Array[String] = []

var _name_field:  LineEdit = null
var _kindred_idx: int = 0
var _class_idx:   int = 0
var _bg_idx:      int = 0

## Rolled attributes — seeded once in `_ready()`, re-seeded by the Reroll Stats
## button, and handed to `_build_pc()` at confirm time so the stats the player
## saw are the stats that persist. Keys: str / dex / cog / wil / vit / armor.
var _rolled_stats: Dictionary = {}

# Preview panel label refs — populated in _build_preview_panel(), pushed by _calc_preview().
var _preview_hp_lbl:        Label = null
var _preview_speed_lbl:     Label = null
var _preview_str_lbl:       Label = null
var _preview_dex_lbl:       Label = null
var _preview_cog_lbl:       Label = null
var _preview_wil_lbl:       Label = null
var _preview_vit_lbl:       Label = null
var _preview_class_name:    Label = null
var _preview_class_desc:    Label = null
var _preview_bg_name:       Label = null
var _preview_bg_desc:       Label = null
var _preview_feat_lbl:      Label = null
var _preview_feat_desc:     Label = null

func _ready() -> void:
	_load_data()
	_roll_stats()
	_build_ui()

func _load_data() -> void:
	for k in KindredLibrary.all_kindreds():
		_kindred_ids.append(k.kindred_id)
	for c in ClassLibrary.all_classes():
		_class_ids.append(c.class_id)
		_class_display.append(c.display_name)
	for b in BackgroundLibrary.all_backgrounds():
		_bg_ids.append(b.background_id)
		_bg_display.append(b.background_name)
	for p in PortraitLibrary.all_portraits():
		_portrait_ids.append(p.portrait_id)

func _build_ui() -> void:
	var full := MarginContainer.new()
	full.set_anchors_preset(Control.PRESET_FULL_RECT)
	full.add_theme_constant_override("margin_left",   40)
	full.add_theme_constant_override("margin_right",  40)
	full.add_theme_constant_override("margin_top",    40)
	full.add_theme_constant_override("margin_bottom", 40)
	add_child(full)

	# Two-column body: left = name + dials + Begin Run · right = live preview panel.
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	full.add_child(body)

	var left_col := VBoxContainer.new()
	left_col.add_theme_constant_override("separation", 12)
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.size_flags_stretch_ratio = 3.0
	body.add_child(left_col)

	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	right_col.size_flags_stretch_ratio = 2.0
	body.add_child(right_col)

	# --- Left column: back · name row · dials · Begin Run ---
	var back_btn := Button.new()
	back_btn.text = "← Back to Main Menu"
	back_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	back_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back_btn.pressed.connect(_on_back)
	left_col.add_child(back_btn)

	var name_row := HBoxContainer.new()
	left_col.add_child(name_row)
	_name_field = LineEdit.new()
	_name_field.placeholder_text = "Character name"
	_name_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_name_field)
	var dice_btn := Button.new()
	dice_btn.text = "🎲"
	dice_btn.pressed.connect(_on_dice_name)
	name_row.add_child(dice_btn)

	var dials := HBoxContainer.new()
	dials.add_theme_constant_override("separation", 8)
	left_col.add_child(dials)

	dials.add_child(_build_text_dial("Kindred", _kindred_ids, _kindred_ids,
		func(i: int): _kindred_idx = i))
	dials.add_child(_build_text_dial("Class", _class_ids, _class_display,
		func(i: int): _class_idx = i))
	dials.add_child(_build_text_dial("Background", _bg_ids, _bg_display,
		func(i: int): _bg_idx = i))
	dials.add_child(_build_portrait_dial())

	var confirm := Button.new()
	confirm.text = "Begin Run"
	confirm.pressed.connect(_on_confirm)
	left_col.add_child(confirm)

	# --- Right column: live preview ---
	var preview := _build_preview_panel()
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_col.add_child(preview)
	_calc_preview()

func _build_text_dial(header: String, ids: Array[String], display: Array[String],
		on_select: Callable) -> PanelContainer:
	# Array used as a mutable int ref — GDScript 4 closures capture locals by value,
	# so a plain int would reset to 0 on every press.
	var idx: Array[int] = [0]
	var n: int = ids.size()

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(140, 0)
	_apply_drum_style(panel)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 4)
	panel.add_child(col)

	var header_lbl := Label.new()
	header_lbl.text = header
	header_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(header_lbl)

	var up_btn := Button.new()
	up_btn.text = "▲"
	up_btn.disabled = n <= 1
	col.add_child(up_btn)

	var prev_lbl := Label.new()
	prev_lbl.text = display[(n - 1) % n] if n > 1 else ""
	prev_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prev_lbl.modulate = Color(1.0, 1.0, 1.0, 0.25)
	prev_lbl.add_theme_font_size_override("font_size", 12)
	col.add_child(prev_lbl)

	var highlight := PanelContainer.new()
	var hl_style := StyleBoxFlat.new()
	hl_style.bg_color = Color(0.32, 0.32, 0.38, 1.0)
	hl_style.set_corner_radius_all(3)
	hl_style.content_margin_left   = 8.0
	hl_style.content_margin_right  = 8.0
	hl_style.content_margin_top    = 6.0
	hl_style.content_margin_bottom = 6.0
	highlight.add_theme_stylebox_override("panel", hl_style)
	col.add_child(highlight)

	var item_lbl := Label.new()
	item_lbl.text = display[0] if n > 0 else ""
	item_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	item_lbl.custom_minimum_size = Vector2(0, 36)
	item_lbl.add_theme_font_size_override("font_size", 20)
	highlight.add_child(item_lbl)

	var next_lbl := Label.new()
	next_lbl.text = display[1 % n] if n > 1 else ""
	next_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_lbl.modulate = Color(1.0, 1.0, 1.0, 0.25)
	next_lbl.add_theme_font_size_override("font_size", 12)
	col.add_child(next_lbl)

	var down_btn := Button.new()
	down_btn.text = "▼"
	down_btn.disabled = n <= 1
	col.add_child(down_btn)

	up_btn.pressed.connect(func():
		idx[0] = (idx[0] - 1 + n) % n
		prev_lbl.text = display[(idx[0] - 1 + n) % n] if n > 1 else ""
		item_lbl.text = display[idx[0]]
		next_lbl.text = display[(idx[0] + 1) % n] if n > 1 else ""
		on_select.call(idx[0])
		_on_pick_changed()
	)
	down_btn.pressed.connect(func():
		idx[0] = (idx[0] + 1) % n
		prev_lbl.text = display[(idx[0] - 1 + n) % n] if n > 1 else ""
		item_lbl.text = display[idx[0]]
		next_lbl.text = display[(idx[0] + 1) % n] if n > 1 else ""
		on_select.call(idx[0])
		_on_pick_changed()
	)

	return panel

func _build_portrait_dial() -> PanelContainer:
	var portrait_tex: Texture2D = load("res://icon.svg")

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(140, 0)
	_apply_drum_style(panel)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 4)
	panel.add_child(col)

	var header_lbl := Label.new()
	header_lbl.text = "Portrait"
	header_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(header_lbl)

	var up_btn := Button.new()
	up_btn.text = "▲"
	up_btn.disabled = true
	col.add_child(up_btn)

	var prev_icon := TextureRect.new()
	prev_icon.texture = portrait_tex
	prev_icon.custom_minimum_size = Vector2(40, 40)
	prev_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	prev_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	prev_icon.modulate = Color(1.0, 1.0, 1.0, 0.25)
	col.add_child(prev_icon)

	var portrait_highlight := PanelContainer.new()
	var ph_style := StyleBoxFlat.new()
	ph_style.bg_color = Color(0.32, 0.32, 0.38, 1.0)
	ph_style.set_corner_radius_all(3)
	ph_style.content_margin_left   = 8.0
	ph_style.content_margin_right  = 8.0
	ph_style.content_margin_top    = 6.0
	ph_style.content_margin_bottom = 6.0
	portrait_highlight.add_theme_stylebox_override("panel", ph_style)
	portrait_highlight.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(portrait_highlight)

	var icon := TextureRect.new()
	icon.texture = portrait_tex
	icon.custom_minimum_size = Vector2(64, 64)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_highlight.add_child(icon)

	var next_icon := TextureRect.new()
	next_icon.texture = portrait_tex
	next_icon.custom_minimum_size = Vector2(40, 40)
	next_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	next_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	next_icon.modulate = Color(1.0, 1.0, 1.0, 0.25)
	col.add_child(next_icon)

	var down_btn := Button.new()
	down_btn.text = "▼"
	down_btn.disabled = true
	col.add_child(down_btn)

	return panel

func _apply_drum_style(panel: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.14, 1.0)
	style.set_border_width_all(2)
	style.border_color = Color(0.45, 0.45, 0.5, 1.0)
	style.set_corner_radius_all(4)
	style.content_margin_left   = 8.0
	style.content_margin_right  = 8.0
	style.content_margin_top    = 6.0
	style.content_margin_bottom = 6.0
	panel.add_theme_stylebox_override("panel", style)

func _build_preview_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	_apply_drum_style(panel)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	panel.add_child(col)

	var header_lbl := Label.new()
	header_lbl.text = "Preview"
	header_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_lbl.add_theme_font_size_override("font_size", 16)
	col.add_child(header_lbl)

	# Top strip: HP · Speed (both concrete since stats are rolled at _ready())
	var stats_row := HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 16)
	stats_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(stats_row)

	_preview_hp_lbl    = _make_stat_label("HP: —")
	_preview_speed_lbl = _make_stat_label("Speed: —")
	stats_row.add_child(_preview_hp_lbl)
	stats_row.add_child(_preview_speed_lbl)

	# Reroll button — re-rolls _rolled_stats and pushes new values into labels.
	var reroll_btn := Button.new()
	reroll_btn.text = "🎲 Reroll Stats"
	reroll_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reroll_btn.pressed.connect(_on_reroll_stats)
	col.add_child(reroll_btn)

	# Attributes row — concrete values from _rolled_stats (seeded in _ready()).
	var attr_row := HBoxContainer.new()
	attr_row.add_theme_constant_override("separation", 10)
	attr_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(attr_row)

	_preview_str_lbl = _make_stat_label("STR: —")
	_preview_dex_lbl = _make_stat_label("DEX: —")
	_preview_cog_lbl = _make_stat_label("COG: —")
	_preview_wil_lbl = _make_stat_label("WIL: —")
	_preview_vit_lbl = _make_stat_label("VIT: —")
	attr_row.add_child(_preview_str_lbl)
	attr_row.add_child(_preview_dex_lbl)
	attr_row.add_child(_preview_cog_lbl)
	attr_row.add_child(_preview_wil_lbl)
	attr_row.add_child(_preview_vit_lbl)

	col.add_child(HSeparator.new())

	# Class ability name + description
	_preview_class_name = Label.new()
	_preview_class_name.add_theme_font_size_override("font_size", 14)
	col.add_child(_preview_class_name)

	_preview_class_desc = Label.new()
	_preview_class_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_class_desc.modulate = Color(1.0, 1.0, 1.0, 0.75)
	col.add_child(_preview_class_desc)

	col.add_child(HSeparator.new())

	# Background ability name + description
	_preview_bg_name = Label.new()
	_preview_bg_name.add_theme_font_size_override("font_size", 14)
	col.add_child(_preview_bg_name)

	_preview_bg_desc = Label.new()
	_preview_bg_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_bg_desc.modulate = Color(1.0, 1.0, 1.0, 0.75)
	col.add_child(_preview_bg_desc)

	col.add_child(HSeparator.new())

	# Kindred feat name + description
	_preview_feat_lbl = Label.new()
	_preview_feat_lbl.add_theme_font_size_override("font_size", 14)
	col.add_child(_preview_feat_lbl)

	_preview_feat_desc = Label.new()
	_preview_feat_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_feat_desc.modulate = Color(1.0, 1.0, 1.0, 0.75)
	col.add_child(_preview_feat_desc)

	return panel

func _make_stat_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	return lbl

func _on_pick_changed() -> void:
	_calc_preview()

## Fills `_rolled_stats` with fresh 1–4 attribute rolls and a 4–8 armor roll.
## Called from `_ready()` (initial seed) and from the Reroll button.
func _roll_stats() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_rolled_stats = {
		"str":   rng.randi_range(1, 4),
		"dex":   rng.randi_range(1, 4),
		"cog":   rng.randi_range(1, 4),
		"wil":   rng.randi_range(1, 4),
		"vit":   rng.randi_range(1, 4),
		"armor": rng.randi_range(4, 8),
	}

func _on_reroll_stats() -> void:
	_roll_stats()
	_calc_preview()

func _on_back() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)

func _on_dice_name() -> void:
	var kindred_id: String = _kindred_ids[_kindred_idx] if not _kindred_ids.is_empty() else ""
	var pool: Array[String] = KindredLibrary.get_name_pool(kindred_id)
	if pool.is_empty():
		_name_field.text = "Unit"
		return
	_name_field.text = pool[randi() % pool.size()]

## Commit point — this is where the old save is nuked and a fresh run begins.
## MainMenuManager._on_new_run() intentionally leaves save state alone so the
## player can hit Back without losing an existing run.
func _on_confirm() -> void:
	var kindred_id: String  = _kindred_ids[_kindred_idx] if not _kindred_ids.is_empty() else ""
	var class_id: String    = _class_ids[_class_idx]     if not _class_ids.is_empty()   else ""
	var bg_id: String       = _bg_ids[_bg_idx]           if not _bg_ids.is_empty()      else ""
	var portrait_id: String = _portrait_ids[0]           if not _portrait_ids.is_empty() else ""

	GameState.delete_save()
	GameState.reset()
	var pc := _build_pc(_name_field.text, kindred_id, class_id, bg_id, portrait_id, _rolled_stats)
	GameState.party.append(pc)
	get_tree().change_scene_to_file(MAP_SCENE_PATH)

## Computes the live preview values for the current dial selections + the
## currently-rolled stats, and pushes them into the preview panel labels.
## Returns the same data as a Dictionary so a future CharacterCreationPreview
## component can consume it without a live UI.
func _calc_preview() -> Dictionary:
	var kindred_id: String = _kindred_ids[_kindred_idx] if not _kindred_ids.is_empty() else ""
	var class_id: String   = _class_ids[_class_idx]     if not _class_ids.is_empty()   else ""
	var bg_id: String      = _bg_ids[_bg_idx]           if not _bg_ids.is_empty()      else ""

	var hp_bonus: int    = KindredLibrary.get_hp_bonus(kindred_id)
	var speed_bonus: int = KindredLibrary.get_speed_bonus(kindred_id)
	var vit: int = int(_rolled_stats.get("vit", 1))
	# hp_max = 10 + kindred_hp_bonus + VIT × 6 (see CombatantData).
	var hp: int    = 10 + hp_bonus + vit * 6
	var speed: int = 1 + speed_bonus

	var class_ab_id: String = ClassLibrary.get_class_data(class_id).starting_ability_id
	var bg_ab_id: String    = BackgroundLibrary.get_background(bg_id).starting_ability_id
	var class_ab := AbilityLibrary.get_ability(class_ab_id)
	var bg_ab    := AbilityLibrary.get_ability(bg_ab_id)
	var feat_data: FeatData = FeatLibrary.get_feat(KindredLibrary.get_feat_id(kindred_id))

	var data := {
		"hp": hp,
		"speed": speed,
		"stats": _rolled_stats.duplicate(),
		"class_ability_name": class_ab.ability_name,
		"class_ability_desc": class_ab.description,
		"bg_ability_name":    bg_ab.ability_name,
		"bg_ability_desc":    bg_ab.description,
		"feat_name":          feat_data.name,
		"feat_desc":          feat_data.description,
	}

	if _preview_hp_lbl != null:
		_preview_hp_lbl.text    = "HP: %d" % hp
		_preview_speed_lbl.text = "Speed: %d" % speed
		_preview_str_lbl.text   = "STR: %d" % int(_rolled_stats.get("str",   1))
		_preview_dex_lbl.text   = "DEX: %d" % int(_rolled_stats.get("dex",   1))
		_preview_cog_lbl.text   = "COG: %d" % int(_rolled_stats.get("cog",   1))
		_preview_wil_lbl.text   = "WIL: %d" % int(_rolled_stats.get("wil",   1))
		_preview_vit_lbl.text   = "VIT: %d" % vit
		_preview_class_name.text = "Class Ability — %s" % class_ab.ability_name
		_preview_class_desc.text = class_ab.description
		_preview_bg_name.text    = "Background Ability — %s" % bg_ab.ability_name
		_preview_bg_desc.text    = bg_ab.description
		_preview_feat_lbl.text   = "Kindred Feat — %s" % feat_data.name
		_preview_feat_desc.text  = feat_data.description

	return data

## Builds a CombatantData for the PC from the given picks.
## Static so unit tests can call it without a live scene.
## `rolled_stats` (optional) — dict with keys str/dex/cog/wil/vit/armor. When
## empty, rolls fresh internally (tests rely on this path). When populated,
## uses the provided values verbatim so the manager's pre-rolled + shown
## stats become the persisted stats.
static func _build_pc(char_name: String, kindred_id: String, class_id: String,
		bg_id: String, _portrait_id: String,
		rolled_stats: Dictionary = {}) -> CombatantData:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var d := CombatantData.new()
	d.archetype_id    = "RogueFinder"
	d.is_player_unit  = true
	d.character_name  = char_name if char_name != "" else "Unit"
	d.kindred         = kindred_id
	d.kindred_feat_id = KindredLibrary.get_feat_id(kindred_id)
	d.unit_class      = ClassLibrary.get_class_data(class_id).display_name
	d.background      = bg_id
	var class_ab: String = ClassLibrary.get_class_data(class_id).starting_ability_id
	var bg_ab: String    = BackgroundLibrary.get_background(bg_id).starting_ability_id
	d.abilities = [class_ab, bg_ab, "", ""]
	d.ability_pool = []
	if class_ab != "":
		d.ability_pool.append(class_ab)
	if bg_ab != "" and not d.ability_pool.has(bg_ab):
		d.ability_pool.append(bg_ab)
	if rolled_stats.is_empty():
		d.strength       = rng.randi_range(1, 4)
		d.dexterity      = rng.randi_range(1, 4)
		d.cognition      = rng.randi_range(1, 4)
		d.willpower      = rng.randi_range(1, 4)
		d.vitality       = rng.randi_range(1, 4)
		d.armor_defense  = rng.randi_range(4, 8)
	else:
		d.strength       = int(rolled_stats.get("str",   1))
		d.dexterity      = int(rolled_stats.get("dex",   1))
		d.cognition      = int(rolled_stats.get("cog",   1))
		d.willpower      = int(rolled_stats.get("wil",   1))
		d.vitality       = int(rolled_stats.get("vit",   1))
		d.armor_defense  = int(rolled_stats.get("armor", 4))
	d.qte_resolution = 0.5
	d.current_hp     = d.hp_max
	d.current_energy = d.energy_max
	return d
