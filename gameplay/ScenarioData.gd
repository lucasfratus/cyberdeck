class_name ScenarioData
extends Resource

@export var id: StringName
@export var intro_dialogue_id: StringName
@export var display_name: String
@export var intro_dialogue: DialogueData
@export var rounds: Array[RoundData]

## Chefe enfrentado depois da ultima rodada, antes do resumo
## do cenario (BossData). Vazio: sem batalha.
@export var boss: Resource

## Chamada mostrada depois do resumo do cenario, antes do
## proximo. Vazio: segue direto para o proximo cenario.
@export var ending_call: DialogueData

@export_group("Baralho")
@export var deck: Array[String] = []
