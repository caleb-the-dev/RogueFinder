extends Node

## --- SettingsStore ---
## Autoloaded as SettingsStore. Persists user preferences to user://settings.json,
## kept separate from run state (user://save.json) so prefs survive run deletion.

const SETTINGS_PATH := "user://settings.json"

var fullscreen:    bool  = false
var master_volume: float = 1.0
var music_volume:  float = 1.0
var sfx_volume:    float = 1.0

func _ready() -> void:
	load_settings()

func save_settings() -> void:
	var data := {
		"fullscreen":    fullscreen,
		"master_volume": master_volume,
		"music_volume":  music_volume,
		"sfx_volume":    sfx_volume,
	}
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))

func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return
	fullscreen    = bool(parsed.get("fullscreen",    false))
	master_volume = float(parsed.get("master_volume", 1.0))
	music_volume  = float(parsed.get("music_volume",  1.0))
	sfx_volume    = float(parsed.get("sfx_volume",    1.0))
	_apply_fullscreen()

func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_apply_fullscreen()
	save_settings()

func _apply_fullscreen() -> void:
	if not is_inside_tree():
		return
	# Setting root.mode is more reliable than DisplayServer.window_set_mode on Windows.
	get_tree().root.mode = Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED
