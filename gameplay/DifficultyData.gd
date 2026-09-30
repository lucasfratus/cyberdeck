class_name DifficultyData
extends Resource

## Nivel de dificuldade escolhido antes da partida. Os valores
## padrao (1.0 e 0) sao o jogo como foi balanceado; cada nivel
## muda so o que precisa.

@export var id: StringName
@export var display_name: String

## Icone mostrado ao lado do nome na tela de escolha.
@export var icon: Texture2D

## Recomendacao para quem escolhe: para que tipo de jogador
## o nivel foi pensado.
@export_multiline var description: String = ""

## Resumo curto do que muda nas regras.
@export_multiline var rules_text: String = ""

@export_group("Rodadas")
## Multiplica o Indice de Risco de cada rodada.
@export var risk_multiplier: float = 1.0
## Jogadas a mais (ou a menos) por rodada.
@export var extra_plays: int = 0
## Cartas a mais (ou a menos) na mao.
@export var hand_size_modifier: int = 0

@export_group("Brechas")
## Multiplica a penalidade que as brechas abertas aplicam na
## pontuacao de cada jogada.
@export var breach_penalty_multiplier: float = 1.0
## Multiplica o aumento de risco quando uma rodada explora
## brechas que ficaram abertas.
@export var exploited_risk_multiplier: float = 1.0

@export_group("Chefe")
## Multiplica o dano que o Assistente sofre a cada erro.
@export var boss_damage_multiplier: float = 1.0
