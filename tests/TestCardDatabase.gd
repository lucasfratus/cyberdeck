extends Node


func _ready():

	print("===== TESTE CARD DATABASE =====")

	var card = CardDatabase.get_card(CardID.SENHA_FORTE)

	if card == null:

		push_error("Carta não encontrada!")

	else:

		print(card.title)
		print(card.description)
		print(card.protection)
		print(card.vulnerability)

	print("----------------------------")

	for c in CardDatabase.get_all_cards():

		print(c.id)
