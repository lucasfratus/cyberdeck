extends Node

func _ready():

	var card = CardFactory.instantiate_card(CardID.SENHA_FORTE)

	add_child(card)

	card.position = Vector2(300, 150)
