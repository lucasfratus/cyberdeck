extends Node

var _cards: Dictionary = {}

func _ready():
	load_cards()


func load_cards():
	_cards.clear()
	var dir := DirAccess.open("res://scenes/cards/data")
	if dir == null:
		push_error("Erro ao abrir cards/data")
		return
		
	dir.list_dir_begin()
	while true:
		var file := dir.get_next()
		if file == "":
			break
		if file.ends_with(".tres"):
			var card: CardData = load("res://scenes/cards/data/" + file)
			if card != null:
				if _cards.has(card.id):
					push_warning("ID duplicado: %s" % card.id)
				_cards[card.id] = card
				
	dir.list_dir_end()


func get_card(id: String) -> CardData:
	return _cards.get(id)


func get_all_cards() -> Array[CardData]:
	var result: Array[CardData]
	for card in _cards.values():
		result.append(card)

	return result
