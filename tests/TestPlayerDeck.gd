extends Node

func _ready():

	var deck := PlayerDeck.new()

	deck.setup([
		CardID.SENHA_FORTE,
		CardID.SENHA_FORTE,
		CardID.SENHA_FORTE
	])

	print("Compra:", deck.draw_size())

	print(deck.draw())
	print(deck.draw())
	print(deck.draw())

	print("Compra:", deck.draw_size())

	deck.discard(CardID.SENHA_FORTE)
	deck.discard(CardID.SENHA_FORTE)

	print("Descarte:", deck.discard_size())

	print("Comprando novamente...")

	print(deck.draw())

	print("Compra:", deck.draw_size())
	print("Descarte:", deck.discard_size())
