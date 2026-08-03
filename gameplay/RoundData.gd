class_name RoundData
extends Resource

@export var id: StringName
@export var attack_name: String
@export var base_risk: float = 100.0
@export var base_max_plays: int = 3

@export_group("Dialogues")
@export var start_dialogue: DialogueData
@export var victory_dialogue: DialogueData
@export var defeat_dialogue: DialogueData
@export var mid_dialogues: Array[RoundDialogueEventData] = []
