extends Resource

## Chefe do fim de um cenario: uma anomalia enfrentada com
## perguntas sobre o tema. Resposta certa: o Assistente ataca e
## o chefe perde vida. Resposta errada: o chefe revida.
##
## Sem class_name de proposito, como o BossQuestionData.

@export var id: StringName
@export var display_name: String = ""
@export var sprite: Texture2D

@export_group("Vida e dano")
@export var max_hp: int = 100
@export var damage_per_correct: int = 25
@export var assistant_max_hp: int = 100
@export var damage_per_wrong: int = 34

@export_group("Perguntas")
## BossQuestionData. A batalha sorteia a ordem e, se as
## perguntas acabarem antes do fim, embaralha de novo.
@export var questions: Array[Resource] = []

@export_group("Falas")
## Antes da luta.
@export var intro_dialogue: DialogueData
## Quando o chefe chega a metade da vida (uma vez por luta).
@export var phase_dialogue: DialogueData
@export var victory_dialogue: DialogueData
## Quando o Assistente perde; a luta recomeca em seguida.
@export var defeat_dialogue: DialogueData
