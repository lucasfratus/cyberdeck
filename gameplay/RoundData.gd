class_name RoundData
extends Resource

@export var id: StringName
@export var attack_name: String
@export var base_risk: float = 100.0
@export var base_max_plays: int = 3

@export_group("Dialogues")
@export var start_dialogue: DialogueData
@export var start_dialogues: Array[DialogueData] = []
@export var victory_dialogue: DialogueData
@export var defeat_dialogue: DialogueData
@export var mid_dialogues: Array[RoundDialogueEventData] = []

@export_group("Baralho")
## Baralho especifico desta rodada. Quando preenchido,
## substitui o baralho do cenario. Repita o mesmo ID
## para incluir varias copias da carta.
@export var deck: Array[String] = []

@export_group("Breach Exploitation")
@export var exploited_breach_ids: Array[String] = []
@export var risk_increase_per_exploited_breach: float = 0.0
