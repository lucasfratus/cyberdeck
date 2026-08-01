extends Control

const INITIAL_HAND_SIZE := 5
const INITIAL_ROUND_RISK := 200.0
const RISK_INCREASE_PER_ROUND := 75.0
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
@onready var next_round_button: Button = $HUD/NextRoundButton

var player_deck := PlayerDeck.new()
var pending_cards: Array[Card] = []
var is_resolving_play := false
var current_round := 1
var current_round_risk := INITIAL_ROUND_RISK

var round_score := 0.0
var plays_remaining := MAX_PLAYS
var current_play_score := 0.0
var round_finished := false

func _ready() -> void:
	hand.position = Vector2(600, 450)

	_connect_signals()
	_setup_deck()

	play_button.disabled = true
	next_round_button.visible = false

	_start_round()


func _connect_signals() -> void:
	play_button.pressed.connect(_on_play_button_pressed)
	hand.cards_played.connect(_on_cards_played)
	hand.selection_changed.connect(_on_selection_changed)
	resolve_play_timer.timeout.connect(_resolve_played_cards)
	next_round_button.pressed.connect(_on_next_round_button_pressed)


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


func _update_play_button_state() -> void:
	var has_selected_cards := not hand.get_selected_cards().is_empty()

	play_button.disabled = (
		not has_selected_cards
		or is_resolving_play
		or round_finished
	)
	

func _on_next_round_button_pressed() -> void:
	if not round_finished:
		return

	_discard_remaining_hand()

	if round_score >= current_round_risk:
		current_round += 1
		current_round_risk += RISK_INCREASE_PER_ROUND

	_start_round()
	

func _on_selection_changed(_cards: Array[Card]) -> void:
	_update_play_button_state()


func _on_cards_played(cards: Array[Card]) -> void:
	if cards.is_empty() or is_resolving_play:
		return

	is_resolving_play = true
	_update_play_button_state()

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

	if round_score >= current_round_risk:
		_finish_round(true)
		return

	if plays_remaining <= 0:
		_finish_round(false)
		return

	score_label.text = "Selecione as cartas"

	_draw_cards(amount_played)

	is_resolving_play = false
	_update_play_button_state()


func _start_round() -> void:
	round_score = 0.0
	plays_remaining = MAX_PLAYS
	current_play_score = 0.0
	round_finished = false
	is_resolving_play = false

	result_label.text = ""
	score_label.text = "Selecione as cartas"

	next_round_button.visible = false

	hand.clear_selection()
	hand.set_interaction_enabled(true)

	_fill_hand()

	_update_round_hud()
	_update_play_button_state()
	
	
func _fill_hand() -> void:
	var current_hand_size := hand.get_cards().size()
	var missing_cards := INITIAL_HAND_SIZE - current_hand_size

	if missing_cards > 0:
		_draw_cards(missing_cards)
	
	
func _update_round_hud() -> void:
	risk_label.text = (
		"Rodada %d — Índice de Risco: %.0f"
		% [current_round, current_round_risk]
	)

	round_score_label.text = (
		"Pontuação da rodada: %.0f"
		% round_score
	)

	plays_label.text = (
		"Jogadas restantes: %d"
		% plays_remaining
	)
	
	
func _finish_round(victory: bool) -> void:
	round_finished = true
	is_resolving_play = false
	play_button.disabled = true

	hand.clear_selection()
	hand.set_interaction_enabled(false)

	if victory:
		result_label.text = "Rodada vencida!"
		next_round_button.text = "Próxima rodada"
	else:
		result_label.text = "Rodada perdida!"
		next_round_button.text = "Tentar novamente"

	score_label.text = (
		"Pontuação final: %.0f / %.0f"
		% [round_score, current_round_risk]
	)

	next_round_button.visible = true


func _discard_remaining_hand() -> void:
	var remaining_cards := hand.take_all_cards()

	for card in remaining_cards:
		if card.data != null:
			player_deck.discard(str(card.data.id))

		card.queue_free()
