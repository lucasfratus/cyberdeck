extends Resource

## Uma pergunta da batalha contra o chefe do cenario.
##
## Sem class_name de proposito: a batalha carrega este script
## com preload(), sem depender do registro global de classes.

@export var id: StringName

@export_multiline var prompt: String = ""

## Alternativas na ordem em que aparecem. A batalha embaralha a
## ordem na tela; correct_index sempre se refere a esta lista.
@export var options: Array[String] = []
@export var correct_index: int = 0

## Mostrada depois da resposta, certa ou errada: o porque da
## alternativa correta.
@export_multiline var explanation: String = ""
