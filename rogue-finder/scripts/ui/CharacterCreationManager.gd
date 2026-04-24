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
	return CombatantData.new()  # stub — tests will fail here; implement in Task 3
