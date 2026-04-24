class_name CharacterCreationManager
extends CanvasLayer

## --- CharacterCreationManager ---
## Single-screen character creation. Player picks name, kindred, class,
## background, and portrait. Builds CombatantData and hands off to MapScene.
## B2: OptionButton controls. B3 will replace with Dial widgets.

const MAP_SCENE_PATH := "res://scenes/map/MapScene.tscn"

## Parallel arrays: index N in _xxx_ids matches item N in its OptionButton.
var _kindred_ids:      Array[String] = []
var _class_ids:        Array[String] = []
var _class_display:    Array[String] = []
var _bg_ids:           Array[String] = []
var _bg_display:       Array[String] = []
var _portrait_ids:     Array[String] = []
var _portrait_display: Array[String] = []

var _name_field:   LineEdit     = null
var _kindred_opt:  OptionButton = null
var _class_opt:    OptionButton = null
var _bg_opt:       OptionButton = null
var _portrait_opt: OptionButton = null

func _ready() -> void:
	_load_data()
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
		_portrait_display.append(p.portrait_name)

func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	add_child(vbox)

	_name_field = LineEdit.new()
	_name_field.placeholder_text = "Character name"
	vbox.add_child(_name_field)

	var dice_name := Button.new()
	dice_name.text = "🎲 Name"
	dice_name.pressed.connect(_on_dice_name)
	vbox.add_child(dice_name)

	_kindred_opt = OptionButton.new()
	for k in KindredLibrary.all_kindreds():
		_kindred_opt.add_item(k.kindred_id)
	_kindred_opt.item_selected.connect(func(_i): _on_pick_changed())
	vbox.add_child(_kindred_opt)

	_class_opt = OptionButton.new()
	for i in range(_class_ids.size()):
		_class_opt.add_item(_class_display[i])
	_class_opt.item_selected.connect(func(_i): _on_pick_changed())
	vbox.add_child(_class_opt)

	_bg_opt = OptionButton.new()
	for i in range(_bg_ids.size()):
		_bg_opt.add_item(_bg_display[i])
	_bg_opt.item_selected.connect(func(_i): _on_pick_changed())
	vbox.add_child(_bg_opt)

	_portrait_opt = OptionButton.new()
	for i in range(_portrait_ids.size()):
		_portrait_opt.add_item(_portrait_display[i])
	_portrait_opt.item_selected.connect(func(_i): _on_pick_changed())
	vbox.add_child(_portrait_opt)

	var confirm := Button.new()
	confirm.text = "Begin Run"
	confirm.pressed.connect(_on_confirm)
	vbox.add_child(confirm)

func _on_pick_changed() -> void:
	_calc_preview()

func _on_dice_name() -> void:
	var kindred_id: String = _kindred_ids[_kindred_opt.selected] if not _kindred_ids.is_empty() else ""
	var pool: Array[String] = KindredLibrary.get_name_pool(kindred_id)
	if pool.is_empty():
		_name_field.text = "Unit"
		return
	_name_field.text = pool[randi() % pool.size()]

func _on_confirm() -> void:
	var kindred_id: String  = _kindred_ids[_kindred_opt.selected]  if not _kindred_ids.is_empty()  else ""
	var class_id: String    = _class_ids[_class_opt.selected]      if not _class_ids.is_empty()    else ""
	var bg_id: String       = _bg_ids[_bg_opt.selected]            if not _bg_ids.is_empty()       else ""
	var portrait_id: String = _portrait_ids[_portrait_opt.selected] if not _portrait_ids.is_empty() else ""
	var pc := _build_pc(_name_field.text, kindred_id, class_id, bg_id, portrait_id)
	GameState.party.append(pc)
	get_tree().change_scene_to_file(MAP_SCENE_PATH)

func _calc_preview() -> Dictionary:
	return {}

## Builds a CombatantData for the PC from the given picks.
## Static so unit tests can call it without a live scene.
static func _build_pc(char_name: String, kindred_id: String, class_id: String,
		bg_id: String, _portrait_id: String) -> CombatantData:
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
	d.strength       = rng.randi_range(1, 4)
	d.dexterity      = rng.randi_range(1, 4)
	d.cognition      = rng.randi_range(1, 4)
	d.willpower      = rng.randi_range(1, 4)
	d.vitality       = rng.randi_range(1, 4)
	d.armor_defense  = rng.randi_range(4, 8)
	d.qte_resolution = 0.5
	d.current_hp     = d.hp_max
	d.current_energy = d.energy_max
	return d
