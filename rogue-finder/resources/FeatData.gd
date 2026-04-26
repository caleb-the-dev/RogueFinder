class_name FeatData
extends Resource

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var source_type: String = ""
@export var stat_bonuses: Dictionary = {}  # stat_name → int
@export var effects: Array = []
