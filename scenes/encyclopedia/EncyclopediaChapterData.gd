extends Resource

## Capitulo da enciclopedia: uma ameaca, o texto que explica
## como ela funciona, links de referencia e as cartas ligadas
## a ela.
##
## Sem class_name de proposito: a enciclopedia carrega este
## script com preload(), sem depender do registro global de
## classes do editor.

@export var id: StringName

## Cenario do jogo que corresponde a este capitulo. A
## enciclopedia aberta durante esse cenario ja comeca aqui.
@export var scenario_id: StringName

## Nome curto, usado na aba.
@export var tab_title: String = ""

@export var title: String = ""
@export var subtitle: String = ""

## Aceita BBCode: [b]negrito[/b] para os subtitulos.
@export_multiline var description: String = ""

## Cartas mostradas no capitulo, na ordem desta lista.
@export var card_ids: Array[String] = []

## Um link por item, no formato "Titulo do link | https://...".
@export var links: Array[String] = []
