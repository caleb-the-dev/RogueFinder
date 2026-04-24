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
