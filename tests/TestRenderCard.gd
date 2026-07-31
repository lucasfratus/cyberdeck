extends Node

@onready var card := $Card

func _ready():

	card.setup(
		CardDatabase.get_card(CardID.SENHA_FORTE)
	)
