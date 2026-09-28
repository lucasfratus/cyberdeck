extends Resource
class_name DialogueLineData

enum HighlightTarget {
	NONE,
	ATTACK,
	RISK,
	ROUND_SCORE,
	PLAYS,
	PLAY_BUTTON,
	HAND,
	PLAY_AREA
}


@export var speaker: String = ""
@export_multiline var text: String = ""
@export var portrait: Texture2D
@export var highlight_target: HighlightTarget = HighlightTarget.NONE

## Imagem mostrada ao lado do Assistente enquanto esta fala
## estiver na tela. So aparece nos dialogos de tela cheia,
## em que o personagem e exibido.
@export var illustration: Texture2D

@export_group("Som")
## Som da voz desta fala. Vazio usa a voz padrao da cena.
@export var voice: AudioStream
## Tom da voz: 1.0 e o original, valores maiores deixam agudo.
@export var voice_pitch: float = 1.0
## Som tocado antes de o texto comecar, como um grito.
@export var intro_sound: AudioStream
