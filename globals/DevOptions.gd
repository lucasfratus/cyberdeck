extends RefCounted

## Pedido de inicio vindo do menu de desenvolvedor. O menu
## principal guarda o pedido e o Game le quando comeca. Fica
## nos metadados do Engine porque a troca de cena descarta os
## nos do menu antes de a partida carregar.
##
## Sem class_name de proposito: menu e partida carregam este
## script com preload().

const META_KEY := &"cyberdeck_dev_start"

## Onde a partida comeca dentro do cenario escolhido.
const START_INTRO := "intro"
const START_ROUND := "round"
const START_BOSS := "boss"


static func request_start(
	scenario_index: int,
	start: String,
	round_index: int,
	skip_game_intro: bool,
	open_breaches: bool
) -> void:
	Engine.set_meta(META_KEY, {
		"scenario_index": scenario_index,
		"start": start,
		"round_index": round_index,
		"skip_game_intro": skip_game_intro,
		"open_breaches": open_breaches,
	})


## Devolve o pedido e o apaga, para a partida seguinte comecar
## normalmente. Vazio quando nao ha pedido.
static func take_start() -> Dictionary:
	if not Engine.has_meta(META_KEY):
		return {}

	var request: Dictionary = Engine.get_meta(META_KEY)
	Engine.remove_meta(META_KEY)
	return request
