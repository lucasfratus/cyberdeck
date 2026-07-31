extends Node2D

@onready var hand: Hand = $Hand


func _ready():

	hand.position = Vector2(600, 450)

	for i in range(5):

		var card = CardFactory.instantiate_card(
			CardID.SENHA_FORTE
		)

		hand.add_card(card)
