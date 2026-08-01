extends Control

const INITIAL_HAND_SIZE := 5

@onready var hand: Hand = $Hand
@onready var play_button: Button = $PlayButton
@onready var played_cards: Control = $PlayArea/PlayedCards
@onready var score_label: Label = $PlayArea/ScoreLabel
@onready var resolve_play_timer: Timer = $ResolvePlayTimer

var player_deck := PlayerDeck.new()
var pending_cards: Array[Card] = []
var is_resolving_play := false

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
	resolve_play_timer.timeout.connect(_resolve_played_cards)


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
	if is_resolving_play:
		return

	hand.play_selected_cards()


func _on_selection_changed(cards: Array[Card]) -> void:
	play_button.disabled = cards.is_empty() or is_resolving_play


func _on_cards_played(cards: Array[Card]) -> void:
	if cards.is_empty() or is_resolving_play:
		return

	is_resolving_play = true
	play_button.disabled = true

	pending_cards = cards

	_show_played_cards(cards)
	_update_score_display(cards)

	resolve_play_timer.start()
	
	
func _show_played_cards(cards: Array[Card]) -> void:
	const CARD_SPACING := 200.0

	var total_width := (cards.size() - 1) * CARD_SPACING
	var start_x := -total_width / 2.0

	for i in range(cards.size()):
		var card := cards[i]

		played_cards.add_child(card)
		card.set_interaction_enabled(false)

		card.position = Vector2(
			start_x + i * CARD_SPACING,
			0.0
		)

		card.scale = Vector2.ONE
		card.z_index = i
		
		
func _calculate_score(cards: Array[Card]) -> Dictionary:
	var protection_sum := 0
	var vulnerability_product := 1.0

	for card in cards:
		if card.data == null:
			continue

		protection_sum += card.data.protection
		vulnerability_product *= card.data.vulnerability

	var total_score := protection_sum * vulnerability_product

	return {
		"protection": protection_sum,
		"vulnerability": vulnerability_product,
		"total": total_score
	}
	

func _update_score_display(cards: Array[Card]) -> void:
	var result := _calculate_score(cards)

	score_label.text = (
		"Proteção: %d  |  Vulnerabilidade: ×%.2f  |  Pontuação: %.2f"
		% [
			result["protection"],
			result["vulnerability"],
			result["total"]
		]
	)
	
	
func _resolve_played_cards() -> void:
	if pending_cards.is_empty():
		is_resolving_play = false
		return

	var amount_played := pending_cards.size()

	for card in pending_cards:
		if card.data != null:
			player_deck.discard(str(card.data.id))

		card.queue_free()

	pending_cards.clear()

	score_label.text = "Selecione as cartas"

	_draw_cards(amount_played)

	is_resolving_play = false
	play_button.disabled = true
