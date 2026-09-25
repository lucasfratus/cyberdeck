extends Resource
class_name SecurityBreachData

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D

@export_group("Effect")
## Fracao da pontuacao base da jogada perdida
## enquanto a brecha permanecer aberta.
@export_range(0.0, 1.0, 0.05) var score_penalty_ratio: float = 0.0
