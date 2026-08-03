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
@onready var attack_label: Label = $HUD/AttackLabel
@onready var risk_label: Label = $HUD/RiskLabel
@onready var round_score_label: Label = $HUD/RoundScoreLabel
@onready var plays_label: Label = $HUD/PlaysLabel
@onready var result_label: Label = $HUD/ResultLabel
@onready var next_round_button: Button = $HUD/NextRoundButton
@onready var dialogue_box: DialogueBox = $DialogueLayer/DialogueBox
@onready var hand_container: Control = $Hand/CardContainer
@onready var highlight_frame: Panel = \
	$TutorialHighlightLayer/HighlightFrame




var player_deck := PlayerDeck.new()
var pending_cards: Array[Card] = []
var is_resolving_play := false
var current_play_score := 0.0
var plays_made_in_round := 0
var triggered_mid_dialogues: Dictionary = {}
var highlighted_control: Control
var current_highlight_target: DialogueLineData.HighlightTarget = \
	DialogueLineData.HighlightTarget.NONE

const PHISHING_SCENARIO: ScenarioData = preload(
	"res://data/scenarios/phishing_scenario.tres"
)

const PASSWORD_SCENARIO: ScenarioData = preload(
	"res://data/scenarios/password_scenario.tres"
)

var scenarios: Array[ScenarioData] = [
	PHISHING_SCENARIO,
	PASSWORD_SCENARIO
]

var current_scenario_index := 0
var current_round_index := 0

var current_scenario_data: ScenarioData
var current_round_data: RoundData

var round_controller := RoundController.new()

func _ready() -> void:
	_connect_signals()
	_setup_deck()
	_start_game()


func _start_game() -> void:
	if scenarios.is_empty():
		push_error("Nenhum cenário foi configurado.")
		return

	current_scenario_index = 0
	current_round_index = 0

	current_scenario_data = scenarios[current_scenario_index]

	if current_scenario_data.rounds.is_empty():
		push_error(
			"O cenário '%s' não possui rodadas."
			% current_scenario_data.id
		)
		return

	current_round_data = current_scenario_data.rounds[current_round_index]

	_start_scenario()
	
	
func _start_scenario() -> void:
	print(
		"Iniciando cenário: ",
		current_scenario_data.display_name
	)

	await _show_scenario_intro()

	await _start_round()


func _connect_signals() -> void:
	play_button.pressed.connect(_on_play_button_pressed)
	hand.cards_played.connect(_on_cards_played)
	hand.selection_changed.connect(_on_selection_changed)
	resolve_play_timer.timeout.connect(_resolve_played_cards)
	next_round_button.pressed.connect(_on_next_round_button_pressed)
	dialogue_box.line_changed.connect(
	_on_dialogue_highlight_changed
	)
	hand.layout_updated.connect(_on_hand_layout_updated)


func _setup_deck() -> void:
	player_deck.setup([
		CardID.SENHA_FORTE,
		CardID.SENHA_FORTE,
		CardID.AUTENTICACAO_2FA,
		CardID.AUTENTICACAO_2FA,
		CardID.REUTILIZAR_SENHA,
		CardID.REUTILIZAR_SENHA,
		CardID.LINK_SUSPEITO,
		CardID.LINK_SUSPEITO
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
	if is_resolving_play or round_controller.finished:
		return

	hand.play_selected_cards()


func _update_play_button_state() -> void:
	var has_selected_cards := not hand.get_selected_cards().is_empty()

	play_button.disabled = (
		not has_selected_cards
		or is_resolving_play
		or round_controller.finished
	)
	

func _on_next_round_button_pressed() -> void:
	if not round_controller.finished:
		return

	var victory := round_controller.has_won()

	_discard_remaining_hand()

	if victory:
		await _advance_progression()
	else:
		await _start_round()
	

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


func _update_score_display(cards: Array[Card]) -> void:
	var result := ScoreCalculator.calculate(cards)

	current_play_score = float(result["total"])

	score_label.text = (
		"Proteção: %d  |  Vulnerabilidade: ×%.2f  |  Pontuação: %.2f"
		% [
			int(result["protection"]),
			float(result["vulnerability"]),
			float(result["total"])
		]
	)
	
	
func _resolve_played_cards() -> void:
	if pending_cards.is_empty():
		is_resolving_play = false
		return

	var amount_played: int = pending_cards.size()
	var played_card_ids: Array[String] = []

	# Guarda os IDs antes de remover as cartas.
	for card in pending_cards:
		if card.data == null:
			continue

		played_card_ids.append(str(card.data.id))

	round_controller.register_play(current_play_score)
	plays_made_in_round += 1

	# Descarta e remove todas as cartas utilizadas.
	for card in pending_cards:
		if card.data != null:
			player_deck.discard(str(card.data.id))

		card.queue_free()

	pending_cards.clear()
	current_play_score = 0.0

	_update_round_hud()

	await _show_triggered_mid_dialogues(played_card_ids)

	if round_controller.has_won():
		_finish_round(true)
		return

	if round_controller.has_lost():
		_finish_round(false)
		return

	score_label.text = "Selecione as cartas"

	_draw_cards(amount_played)

	is_resolving_play = false
	hand.set_interaction_enabled(true)
	_update_play_button_state()


func _start_round() -> void:
	current_play_score = 0.0
	is_resolving_play = false
	
	plays_made_in_round = 0
	triggered_mid_dialogues.clear()

	round_controller.start(current_round_data)

	result_label.text = ""
	score_label.text = "Selecione as cartas"

	next_round_button.visible = false

	hand.clear_selection()
	hand.set_interaction_enabled(false)
	play_button.disabled = true

	_fill_hand()
	_update_round_hud()

	await _show_round_start_dialogue()

	hand.set_interaction_enabled(true)
	_update_play_button_state()
	
	
func _fill_hand() -> void:
	var current_hand_size := hand.get_cards().size()
	var missing_cards := INITIAL_HAND_SIZE - current_hand_size

	if missing_cards > 0:
		_draw_cards(missing_cards)
	
	
func _update_round_hud() -> void:
	attack_label.text = (
		"%s — Rodada %d/%d — Ataque: %s"
		% [
			current_scenario_data.display_name,
			current_round_index + 1,
			current_scenario_data.rounds.size(),
			current_round_data.attack_name
		]
	)

	risk_label.text = (
		"Índice de Risco: %.0f"
		% round_controller.get_risk()
	)

	round_score_label.text = (
		"Pontuação da rodada: %.0f"
		% round_controller.score
	)

	plays_label.text = (
		"Jogadas restantes: %d"
		% round_controller.plays_remaining
	)
	
	
func _advance_progression() -> void:
	current_round_index += 1

	# Ainda existem rodadas no cenário atual.
	if current_round_index < current_scenario_data.rounds.size():
		current_round_data = (
			current_scenario_data.rounds[current_round_index]
		)

		await _start_round()
		return

	# O cenário atual terminou.
	current_scenario_index += 1

	# Não existem mais cenários.
	if current_scenario_index >= scenarios.size():
		_finish_game()
		return

	# Carrega o próximo cenário.
	current_scenario_data = scenarios[current_scenario_index]
	current_round_index = 0

	if current_scenario_data.rounds.is_empty():
		push_error(
			"O cenário '%s' não possui rodadas."
			% current_scenario_data.id
		)
		return

	current_round_data = (
		current_scenario_data.rounds[current_round_index]
	)

	await _start_scenario()
	
	
	
func _finish_round(victory: bool) -> void:
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
		% [
			round_controller.score,
			round_controller.get_risk()
		]
	)

	next_round_button.visible = true


func _discard_remaining_hand() -> void:
	var remaining_cards := hand.take_all_cards()

	for card in remaining_cards:
		if card.data != null:
			player_deck.discard(str(card.data.id))

		card.queue_free()
		
		
func _finish_game() -> void:
	hand.clear_selection()
	hand.set_interaction_enabled(false)

	play_button.disabled = true
	next_round_button.visible = false

	result_label.text = "Você concluiu todos os cenários!"
	score_label.text = "Fim da partida"
	
	
func _show_scenario_intro() -> void:
	hand.set_interaction_enabled(false)
	play_button.disabled = true

	var intro_dialogue := current_scenario_data.intro_dialogue

	if intro_dialogue == null:
		push_warning(
			"O cenário '%s' não possui diálogo introdutório."
			% current_scenario_data.id
		)
		return

	dialogue_box.show_dialogue_data(intro_dialogue)

	await dialogue_box.finished
	
	
func _show_round_start_dialogue() -> void:
	var round_dialogue := current_round_data.start_dialogue

	if round_dialogue == null:
		return

	hand.set_interaction_enabled(false)
	play_button.disabled = true

	dialogue_box.show_dialogue_data(round_dialogue)

	await dialogue_box.finished
	

func _is_mid_dialogue_triggered(
	dialogue_event: RoundDialogueEventData,
	played_card_ids: Array[String]
) -> bool:
	match dialogue_event.trigger_type:
		RoundDialogueEventData.TriggerType.AFTER_PLAY:
			return (
				plays_made_in_round
				>= dialogue_event.trigger_value
			)

		RoundDialogueEventData.TriggerType.PLAYS_REMAINING:
			return (
				round_controller.plays_remaining
				<= dialogue_event.trigger_value
			)

		RoundDialogueEventData.TriggerType.CARD_PLAYED:
			if dialogue_event.required_card_id.is_empty():
				return false

			return (
				dialogue_event.required_card_id
				in played_card_ids
			)

		_:
			return false
			

func _show_triggered_mid_dialogues(
	played_card_ids: Array[String]
) -> void:
	if current_round_data == null:
		return

	for dialogue_event in current_round_data.mid_dialogues:
		if dialogue_event == null:
			continue

		if dialogue_event.dialogue == null:
			continue

		if triggered_mid_dialogues.has(dialogue_event.id):
			continue

		if not _is_mid_dialogue_triggered(
			dialogue_event,
			played_card_ids
		):
			continue

		triggered_mid_dialogues[dialogue_event.id] = true

		hand.set_interaction_enabled(false)
		play_button.disabled = true

		dialogue_box.show_dialogue_data(
			dialogue_event.dialogue
		)

		await dialogue_box.finished


func _on_dialogue_highlight_changed(
	target: DialogueLineData.HighlightTarget
) -> void:
	current_highlight_target = target
	_clear_interface_highlight()

	match target:
		DialogueLineData.HighlightTarget.ATTACK:
			_highlight_control(attack_label)

		DialogueLineData.HighlightTarget.RISK:
			_highlight_control(risk_label)

		DialogueLineData.HighlightTarget.ROUND_SCORE:
			_highlight_control(round_score_label)

		DialogueLineData.HighlightTarget.PLAYS:
			_highlight_control(plays_label)

		DialogueLineData.HighlightTarget.PLAY_BUTTON:
			_highlight_control(play_button)

		DialogueLineData.HighlightTarget.HAND:
			call_deferred("_highlight_hand_cards")

		DialogueLineData.HighlightTarget.PLAY_AREA:
			_highlight_control(played_cards)


func _highlight_control(control: Control) -> void:
	if control == null:
		return

	highlighted_control = control
	_update_highlight_frame()
	highlight_frame.show()
	

func _update_highlight_frame() -> void:
	if highlighted_control == null:
		return

	var padding := 8.0
	var target_rect := highlighted_control.get_global_rect()

	highlight_frame.global_position = (
		target_rect.position
		- Vector2.ONE * padding
	)

	highlight_frame.size = (
		target_rect.size
		+ Vector2.ONE * padding * 2.0
	)
	

func _clear_interface_highlight() -> void:
	highlighted_control = null
	highlight_frame.hide()
	
	
func _highlight_hand_cards() -> void:
	var cards: Array[Card] = hand.get_cards()

	if cards.is_empty():
		_clear_interface_highlight()
		return

	var combined_rect: Rect2 = cards[0].get_global_rect()

	for i in range(1, cards.size()):
		combined_rect = combined_rect.merge(
			cards[i].get_global_rect()
		)

	_highlight_global_rect(combined_rect)
	

func _highlight_global_rect(target_rect: Rect2) -> void:
	const PADDING := 8.0

	highlighted_control = null

	highlight_frame.global_position = (
		target_rect.position
		- Vector2(PADDING, PADDING)
	)

	highlight_frame.size = (
		target_rect.size
		+ Vector2(PADDING * 2.0, PADDING * 2.0)
	)

	highlight_frame.show()


func _on_hand_layout_updated() -> void:
	if (
		current_highlight_target
		!= DialogueLineData.HighlightTarget.HAND
	):
		return

	call_deferred("_highlight_hand_cards")
