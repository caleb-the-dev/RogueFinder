class_name TemperamentData
extends Resource

## --- TemperamentData ---
## One row from temperaments.csv. boosted_stat and hindered_stat are attribute
## key strings ("strength", "dexterity", etc.) or "" for the neutral temperament.

@export var temperament_id:   String = ""
@export var temperament_name: String = ""
## Attribute key that gets +1. Empty string = neutral (no boost).
@export var boosted_stat:     String = ""
## Attribute key that gets -1. Empty string = neutral (no penalty).
@export var hindered_stat:    String = ""
