class_name CardFactory

const CARD_SCENE := preload("res://scenes/cards/Card.tscn")

static func instantiate_card(card_id: String) -> Card:
	var data := CardDatabase.get_card(card_id)

	if data == null:
		push_error("Carta '%s' não encontrada." % card_id)
		return null

	var card := CARD_SCENE.instantiate() as Card
	card.setup(data)

	return card
