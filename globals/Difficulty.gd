extends RefCounted

## Dificuldade escolhida no menu. Fica nos metadados do
## Engine, como o pedido do menu de desenvolvedor, porque a
## troca de cena descarta o menu antes de a partida carregar.
##
## Sem class_name de proposito: menu e partida carregam este
## script com preload().

const META_KEY := &"cyberdeck_difficulty"

const BEGINNER: DifficultyData = preload("res://gameplay/difficulties/easy.tres")
const INTERMEDIATE: DifficultyData = preload("res://gameplay/difficulties/normal.tres")
const PROFESSIONAL: DifficultyData = preload("res://gameplay/difficulties/hard.tres")

## Ordem em que aparecem na tela de escolha.
const OPTIONS: Array[DifficultyData] = [BEGINNER, INTERMEDIATE, PROFESSIONAL]

## Usada quando nada foi escolhido, como ao abrir o Game.tscn
## direto no editor.
const DEFAULT: DifficultyData = INTERMEDIATE


static func select(difficulty: DifficultyData) -> void:
	if difficulty != null:
		Engine.set_meta(META_KEY, difficulty.id)


static func get_selected() -> DifficultyData:
	var id: StringName = Engine.get_meta(META_KEY, DEFAULT.id)

	for option in OPTIONS:
		if option.id == id:
			return option

	return DEFAULT
