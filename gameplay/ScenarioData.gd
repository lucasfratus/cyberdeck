class_name ScenarioData
extends Resource

@export var id: StringName
@export var intro_dialogue_id: StringName
@export var display_name: String
@export var intro_dialogue: DialogueData
@export var rounds: Array[RoundData]

## Chamada mostrada depois do resumo do cenario, antes do
## proximo. Vazio: segue direto para o proximo cenario.
@export var ending_call: DialogueData

@export_group("Baralho")
@export var deck: Array[String] = []
