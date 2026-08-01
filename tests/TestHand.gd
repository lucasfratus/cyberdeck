extends Node2D

@onready var hand: Hand = $Hand


func _ready() -> void:
	hand.position = Vector2(600, 450)

	for _i in range(5):
		var card := CardFactory.instantiate_card(
			CardID.SENHA_FORTE
		)

		if card != null:
			hand.add_card(card)
