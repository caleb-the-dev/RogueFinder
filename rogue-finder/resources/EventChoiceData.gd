class_name EventChoiceData
extends Resource

## --- EventChoiceData ---
## One choice within a non-combat event. Conditions gate visibility (disables
## button if unmet); effects are applied on selection. Empty effects = valid
## no-op (walk-away flavor options). Condition strings and effect dicts are
## stored opaque — the evaluator/dispatcher lives in the overlay scene.

@export var label: String = ""
@export var conditions: Array[String] = []
@export var effects: Array[Dictionary] = []
@export var result_text: String = ""
