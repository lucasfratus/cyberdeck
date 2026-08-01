extends Control

const INITIAL_HAND_SIZE := 5
const ROUND_RISK := 200.0
const MAX_PLAYS := 3

@onready var hand: Hand = $Hand
@onready var play_button: Button = $PlayButton
@onready var played_cards: Control = $PlayArea/PlayedCards
@onready var score_label: Label = $PlayArea/ScoreLabel
@onready var resolve_play_timer: Timer = $ResolvePlayTimer
@onready var risk_label: Label = $HUD/RiskLabel
@onready var round_score_label: Label = $HUD/RoundScoreLabel
@onready var plays_label: Label = $HUD/PlaysLabel
@onready var result_label: Label = $HUD/ResultLabel

var player_deck := PlayerDeck.new()
var pending_cards: Array[Card] = []
var is_resolving_play := false

var round_score := 0.0
var plays_remaining := MAX_PLAYS
var current_play_score := 0.0
var round_finished := false

func _ready() -> void:
	hand.position = Vector2(600, 450)

	_connect_signals()
	_setup_deck()

	play_button.disabled = true

	_draw_cards(INITIAL_HAND_SIZE)
	_start_round()


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
	if is_resolving_play or round_finished:
		return

	hand.play_selected_cards()


func _on_selection_changed(cards: Array[Card]) -> void:
	play_button.disabled = (
		cards.is_empty()
		or is_resolving_play
		or round_finished
	)


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

	current_play_score = float(result["total"])

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

	round_score += current_play_score
	plays_remaining -= 1

	for card in pending_cards:
		if card.data != null:
			player_deck.discard(str(card.data.id))

		card.queue_free()

	pending_cards.clear()
	current_play_score = 0.0

	_update_round_hud()

	if round_score >= ROUND_RISK:
		_finish_round(true)
		return

	if plays_remaining <= 0:
		_finish_round(false)
		return

	score_label.text = "Selecione as cartas"

	_draw_cards(amount_played)

	is_resolving_play = false
	play_button.disabled = true


func _start_round() -> void:
	round_score = 0.0
	plays_remaining = MAX_PLAYS
	current_play_score = 0.0
	round_finished = false

	result_label.text = ""

	_update_round_hud()
	
	
func _update_round_hud() -> void:
	risk_label.text = "Índice de Risco: %.0f" % ROUND_RISK
	round_score_label.text = "Pontuação da rodada: %.0f" % round_score
	plays_label.text = "Jogadas restantes: %d" % plays_remaining
	
	
func _finish_round(victory: bool) -> void:
	round_finished = true
	is_resolving_play = false
	play_button.disabled = true

	if victory:
		result_label.text = "Rodada vencida!"
	else:
		result_label.text = "Rodada perdida!"

	score_label.text = (
		"Pontuação final: %.0f / %.0f"
		% [round_score, ROUND_RISK]
	)

	hand.clear_selection()
	hand.set_interaction_enabled(false)
