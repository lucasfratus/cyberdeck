class_name ScenarioData
extends Resource

@export var id: StringName
@export var intro_dialogue_id: StringName
@export var display_name: String
@export var intro_dialogue: DialogueData
@export var rounds: Array[RoundData]

@export_group("Baralho")
@export var deck: Array[String] = []
