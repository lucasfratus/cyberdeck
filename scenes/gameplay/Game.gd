extends Control

const INITIAL_HAND_SIZE := 5

@onready var hand: Hand = $Hand
@onready var play_button: Button = $PlayButton

var player_deck := PlayerDeck.new()

func _ready() -> void:
	hand.position = Vector2(600, 450)

	_connect_signals()
	_setup_deck()

	play_button.disabled = true

	_draw_cards(INITIAL_HAND_SIZE)


func _connect_signals() -> void:
	play_button.pressed.connect(_on_play_button_pressed)
	hand.cards_played.connect(_on_cards_played)
	hand.selection_changed.connect(_on_selection_changed)


func _setup_deck() -> void:
	player_deck.setup([
		CardID.SENHA_FORTE,
		#CardID.FIREWALL,
		#CardID.PHISHING,
		#CardID.ANTIVIRUS,
		CardID.SENHA_FORTE,
		CardID.SENHA_FORTE,
		CardID.SENHA_FORTE,
		CardID.SENHA_FORTE,
		CardID.SENHA_FORTE,
		#CardID.FIREWALL,
		#CardID.PHISHING,
		#CardID.ANTIVIRUS
	])


func _draw_cards(amount: int) -> void:
	for _i in range(amount):
		var card_id := player_deck.draw()

		if card_id.is_empty():
			print("Não há mais cartas disponíveis para compra.")
			break

		var card := CardFactory.instantiate_card(card_id)

		if card == null:
			push_error(
				"Não foi possível instanciar a carta '%s'." % card_id
			)
			continue

		hand.add_card(card)


func _on_play_button_pressed() -> void:
	hand.play_selected_cards()


func _on_selection_changed(cards: Array[Card]) -> void:
	play_button.disabled = cards.is_empty()


func _on_cards_played(cards: Array[Card]) -> void:
	var amount_played := cards.size()

	for card in cards:
		if card.data != null:
			player_deck.discard(str(card.data.id))

		card.queue_free()

	_draw_cards(amount_played)

	print("Cartas jogadas: ", amount_played)
	print("Monte de compra: ", player_deck.draw_size())
	print("Monte de descarte: ", player_deck.discard_size())
