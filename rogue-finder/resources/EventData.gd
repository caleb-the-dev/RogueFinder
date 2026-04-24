class_name EventData
extends Resource

## --- EventData ---
## One non-combat event. ring_eligibility controls which map rings can draw
## this event. choices are attached by EventLibrary after the join on
## event_choices.csv, sorted by their authored order.

@export var id: String = ""
@export var title: String = ""
@export var body: String = ""
@export var ring_eligibility: Array[String] = []
@export var choices: Array[EventChoiceData] = []
