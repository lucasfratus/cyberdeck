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
@onready var card_details_panel: CardDetailsPanel = \
	$CardDetailsLayer/CardDetailsPanel
@onready var breaches_panel: PanelContainer = \
	$HUD/BreachesPanel
@onready var breach_list: BoxContainer = \
	$HUD/BreachesPanel/MarginContainer/Content/BreachList
@onready var breach_feedback: PanelContainer = \
	$BreachFeedbackLayer/BreachFeedback
@onready var breach_feedback_label: Label = \
	$BreachFeedbackLayer/BreachFeedback/MarginContainer/Message

var player_deck := PlayerDeck.new()
var pending_cards: Array[Card] = []
var is_resolving_play := false
var current_play_score := 0.0
var plays_made_in_round := 0
var triggered_mid_dialogues: Dictionary = {}
var highlighted_control: Control
var breaches_at_round_start: Array[SecurityBreachData] = []

var current_highlight_target: DialogueLineData.HighlightTarget = \
	DialogueLineData.HighlightTarget.NONE

const GAME_INTRO_DIALOGUE: DialogueData = preload(
	"res://data/dialogue/game_intro.tres"
)

const PHISHING_SCENARIO: ScenarioData = preload(
	"res://data/scenarios/phishing_scenario.tres"
)

const PASSWORD_SCENARIO: ScenarioData = preload(
	"res://data/scenarios/password_scenario.tres"
)

const ADWARE_SCENARIO: ScenarioData = preload(
	"res://data/scenarios/adware_scenario.tres"
)

const FIRST_BREACH_DIALOGUE: DialogueData = preload(
	"res://data/dialogue/events/tutorial/tutorial_first_breach.tres"
)

const PAUSE_MENU_SCENE := preload(
	"res://scenes/menus/PauseMenu.tscn"
)

const ENCYCLOPEDIA_SCENE := preload(
	"res://scenes/encyclopedia/Encyclopedia.tscn"
)

## Sem class_name, por isso carregado como script.
const HELP_SCREEN_SCRIPT := preload(
	"res://scenes/menus/HelpScreen.gd"
)

const MAIN_MENU_SCENE_PATH := "res://scenes/menus/MainMenu.tscn"

var menu_layer: CanvasLayer
var pause_menu: PauseMenu
var encyclopedia: Encyclopedia
var help_screen: Control

## Se a enciclopedia ou a ajuda foi aberta pelo menu de
## pausa (true) ou pelos botoes do HUD (false).
var overlay_returns_to_pause := true

## Botoes de atalho no canto superior direito do HUD.
var hud_shortcuts: HBoxContainer

const SCENARIO_SUMMARY_SCENE := preload(
	"res://scenes/menus/ScenarioSummary.tscn"
)

var scenario_summary: ScenarioSummary

## Cartas que apareceram no cenario atual, na ordem em
## que surgiram, e quais delas foram desbloqueadas nele.
var scenario_seen_card_ids: Array[String] = []
var scenario_new_card_ids: Array[String] = []

## Numeros do cenario atual, mostrados na tela de conclusao.
## A pontuacao soma so as rodadas vencidas; as tentativas
## perdidas contam em scenario_retries.
var scenario_score := 0.0
var scenario_breaches_opened := 0
var scenario_breaches_closed := 0
var scenario_retries := 0

## Tempo de jogo no cenario, em segundos. Conta em _process,
## que para com a arvore pausada, entao a pausa nao entra.
var scenario_elapsed := 0.0
var scenario_timer_running := false

## Controle de tentativas da mesma rodada, para as
## metricas distinguirem a primeira vez de um retry.
var round_attempt := 0
var attempt_round_key := ""

## Carta cujo painel educativo esta aberto e desde quando,
## para medir o tempo de leitura.
var details_view_card_id := ""

## Animacao da pontuacao. Guardada para poder interromper
## e para a resolucao esperar o fim dela.
var score_tween: Tween

## Tempo ate a ultima carta jogada pousar na mesa. A conta
## da jogada so comeca depois disso.
var played_cards_landing_time := 0.0

const PLAY_CARD_MOVE_DURATION := 0.3
const PLAY_CARD_STAGGER := 0.06

## Sons das cartas (CC0, ver assets/audio/cards/CREDITOS.txt).
const SFX_CARD_DRAW: AudioStream = preload("res://assets/audio/cards/card_draw.wav")
const SFX_CARD_PLAY: AudioStream = preload("res://assets/audio/cards/card_play.wav")
const SFX_PRACTICE_GOOD: AudioStream = preload("res://assets/audio/cards/practice_good.wav")
const SFX_PRACTICE_BAD: AudioStream = preload("res://assets/audio/cards/practice_bad.wav")
const SFX_ROUND_SCORE: AudioStream = preload("res://assets/audio/cards/round_score.wav")

## Volume de cada som. A compra e o som mais frequente, entao
## fica mais baixa; a soma da rodada fecha a jogada, mais alta.
const SFX_CARD_DRAW_DB := -9.0
const SFX_CARD_PLAY_DB := -7.0
const SFX_PRACTICE_DB := -6.0
const SFX_ROUND_SCORE_DB := -5.0

## Variacao aleatoria de tom nas cartas, para varias compras ou
## jogadas seguidas nao soarem identicas.
const SFX_CARD_PITCH_VARIATION := 0.08

## Varios sons podem tocar ao mesmo tempo (cinco cartas
## entrando na mao, por exemplo). Cada um usa um player livre.
const SFX_PLAYER_COUNT := 6

## Mesmo intervalo usado pela mao para a entrada das cartas
## (HandLayout.ENTRY_STAGGER), para o som acompanhar cada uma.
const SFX_DRAW_STAGGER := 0.07

var sfx_players: Array[AudioStreamPlayer] = []
var sfx_next_player := 0

## Indicadores de brecha no HUD, por id da brecha. Mantidos
## entre atualizacoes para animar so o que abriu ou fechou.
var breach_indicators: Dictionary = {}

## Indicador com dica de ferramenta que quebra linha, para a
## descricao da brecha nao passar da borda da tela.
const WRAPPING_TOOLTIP_PANEL := preload(
	"res://scenes/ui/WrappingTooltipPanel.gd"
)

const BREACH_FLASH_COLOR := Color(1.8, 0.45, 0.45)
const BREACH_FLASH_STEP := 0.12
const BREACH_FLASH_LOOPS := 3
const BREACH_FADE_DURATION := 0.35
const RISK_PULSE_SCALE := 1.25
const RISK_PULSE_STEP := 0.15
const RISK_PULSE_LOOPS := 2

## Numero grande no centro da tela que mostra a conta da
## jogada e depois voa ate a pontuacao da rodada.
var score_popup: Label

## Container da tela inteira que mantem o numero centralizado.
## O voo e a escala sao aplicados nele, nao no numero.
var score_popup_root: CenterContainer

## Multiplicador ou porcentagem de penalidade, desenhado a
## direita do numero para nao desloca-lo do centro.
var score_popup_modifier: Label

const SCORE_POPUP_FONT_SIZE := 56
const SCORE_POPUP_OUTLINE_SIZE := 10
const SCORE_POPUP_COLOR := Color(0.92, 0.8, 0.0)
const SCORE_POPUP_FLY_SCALE := 0.35

## Acima das cartas jogadas, que recebem z_index 0, 1, 2...
## Os dialogos ficam por cima mesmo assim, porque estao em
## CanvasLayers proprios.
const SCORE_POPUP_Z_INDEX := 200

const SCORE_MODIFIER_FONT_SIZE := 40
const SCORE_MODIFIER_GAP := 16.0
const SCORE_MULTIPLIER_COLOR := Color(0.55, 0.85, 1.0)
const SCORE_PENALTY_COLOR := Color(1.0, 0.4, 0.4)

## Largura reservada ao texto acima das cartas. Larga o
## bastante para a mensagem mais longa, para o texto nao
## precisar crescer e sair do centro.
const SCORE_LABEL_WIDTH := 900.0

## Duracao de cada etapa, em segundos. As etapas ate o
## pulso (primeira fase) precisam caber no ResolvePlayTimer,
## que espera 1,5 s.
const SCORE_APPEAR_DURATION := 0.15
const SCORE_MULTIPLIER_DURATION := 0.3
const SCORE_TOTAL_DURATION := 0.45
const SCORE_PULSE_DURATION := 0.2
const SCORE_PENALTY_HOLD := 0.35
const SCORE_PENALTY_DURATION := 0.4
const SCORE_FLY_DURATION := 0.45
const SCORE_FADE_DURATION := 0.1

## Contagem carta a carta. Cada carta treme, brilha em verde
## (boa pratica) ou vermelho (pratica insegura) e solta um
## icone que sobe com a Protecao que ela somou.
const SCORE_CARD_COUNT_DURATION := 0.25
const SCORE_CARD_GAP := 0.12

## Inclinacao maxima do tremor, em graus. A pratica insegura
## treme mais forte.
const CARD_SHAKE_ANGLE := 4.0
const CARD_SHAKE_ANGLE_INSECURE := 8.0
const CARD_POP_SCALE := 1.06

## Brilho em volta da carta: aneis por fora dela, do mais
## forte (colado na carta) ao mais fraco.
const CARD_GLOW_RINGS: Array[float] = [0.95, 0.55, 0.3, 0.12]
const CARD_GLOW_RING_WIDTH := 3
const CARD_GLOW_HOLD := 0.45
const CARD_GLOW_FADE := 0.35

## Faixa de transicao no meio da tela: anuncia a rodada que
## comeca e o resultado da que terminou.
const ROUND_BANNER_HEIGHT := 128.0
const ROUND_BANNER_Z_INDEX := 150
const ROUND_BANNER_OPEN_DURATION := 0.2
const ROUND_BANNER_TYPE_SPEED := 40.0
const ROUND_BANNER_HOLD := 0.9
const ROUND_BANNER_CLOSE_DURATION := 0.18
const ROUND_BANNER_TITLE_SIZE := 44

## Cartas que sobraram na mao descem e somem ao fim da
## rodada, uma depois da outra.
const DISCARD_DROP := 260.0
const DISCARD_DURATION := 0.3
const DISCARD_STAGGER := 0.05

## Tela preta com o nome do cenario, entre a fala do
## Assistente e a introducao do cenario. Fica abaixo dos
## dialogos (camada 10) e acima do resto da partida.
const SCENARIO_CARD_LAYER := 9
const SCENARIO_CARD_TITLE_SIZE := 52
const SCENARIO_CARD_TYPE_SPEED := 30.0
const SCENARIO_CARD_HOLD := 1.3
const SCENARIO_CARD_FADE := 0.3
const SCENARIO_CARD_LINE_WIDTH := 360.0

## Depois da introducao do cenario, a partida surge do preto.
const FADE_FROM_BLACK_DURATION := 0.45

## Chamada entre os antagonistas, entre um cenario e outro.
## Acima dos dialogos (10) e abaixo dos menus (100).
const CODEC_CALL_SCRIPT := preload("res://scenes/cutscenes/CodecCall.gd")
const CODEC_CALL_LAYER := 20
var codec_call: Control

## Batalha contra o chefe do cenario. Abaixo da tela do
## cenario (9) e dos dialogos (10), que aparecem por cima dela.
const BOSS_BATTLE_SCRIPT := preload("res://scenes/boss/BossBattle.gd")
const BOSS_BATTLE_LAYER := 8
var boss_battle: Control

## Janelas de anuncio enquanto o navegador estiver sequestrado.
## Acima da partida e abaixo dos detalhes da carta (5) e do
## aviso de brechas (6), que continuam legiveis por cima delas.
const AD_POPUPS_SCRIPT := preload("res://scenes/gameplay/AdPopups.gd")
const AD_POPUPS_LAYER := 4
const AD_POPUPS_BREACH_ID := "navegador_sequestrado"
const AD_POPUPS_TUTORIAL: DialogueData = preload(
	"res://data/dialogue/events/tutorial/tutorial_ad_popups.tres"
)
var ad_popups: Control
var ad_popups_tutorial_shown := false

var scenario_card: ColorRect
var pending_fade_from_black := false
var scenario_card_content: VBoxContainer
var scenario_card_counter: Label
var scenario_card_title: Label
var scenario_card_line: ColorRect
var scenario_card_subtitle: Label

var round_banner: Control
var round_banner_band: PanelContainer
var round_banner_title: Label
var round_banner_subtitle: Label
var round_banner_style: StyleBoxFlat

## Depois de contabilizada, a carta escurece e fica assim
## ate sair da mesa. O escurecimento comeca enquanto o
## brilho some.
const COUNTED_CARD_COLOR := Color(0.35, 0.4, 0.37)
const COUNTED_CARD_DIM_DURATION := 0.3

const PRACTICE_FLOAT_RISE := 56.0
const PRACTICE_FLOAT_DURATION := 0.8
const PRACTICE_FLOAT_FADE := 0.35
const PRACTICE_FLOAT_FONT_SIZE := 28
const PRACTICE_FLOAT_Z_INDEX := 100
const ROUND_SCORE_DURATION := 0.5
var details_view_started_msec := 0


## Ordem dos cenarios. O menu de desenvolvedor le esta lista
## para montar os atalhos.
const SCENARIO_LIST: Array[ScenarioData] = [
	PHISHING_SCENARIO,
	PASSWORD_SCENARIO,
	ADWARE_SCENARIO
]

const DEV_OPTIONS := preload("res://globals/DevOptions.gd")
const DIFFICULTY := preload("res://globals/Difficulty.gd")

## Nivel escolhido no menu antes da partida.
var difficulty: DifficultyData

var scenarios: Array[ScenarioData] = SCENARIO_LIST.duplicate()

var current_scenario_index := 0
var current_round_index := 0

var current_scenario_data: ScenarioData
var current_round_data: RoundData

var round_controller := RoundController.new()
var detailed_card: Card = null
var details_hide_request_id: int = 0
var breach_feedback_tween: Tween
var first_breach_tutorial_shown := false

const CARD_DETAILS_GAP := 20.0

## Na partida o painel pode ser mais largo que na coluna da
## enciclopedia. Com a fonte monoespacada, mais largura
## significa menos linhas, e o painel cabe acima das cartas.
const GAME_DETAILS_PANEL_WIDTH := 520.0

## Coluna do HUD no canto superior esquerdo: um painel com
## risco, pontuacao, barra de progresso e jogadas, e o painel
## de brechas logo abaixo.
## Camada de CRT por cima da partida. Passa por cima das
## cartas; se atrapalhar a leitura, desligue aqui.
const CRT_OVERLAY_ENABLED := true

## Acima da partida e da batalha, abaixo dos dialogos (10).
## Por cima deles, o escurecimento das bordas deixava o texto
## da caixa de dialogo, que fica perto da borda de baixo,
## mais apagado.
const CRT_OVERLAY_LAYER := 9

const HUD_MARGIN := 10.0

## Layout vertical da partida, de cima para baixo: linha de
## status, faixa da conta da jogada, mesa e mao. A mao fica
## ancorada na borda inferior pelo proprio Game.tscn.
const HUD_COLUMN_TOP := 48.0
const SCORE_BAND_TOP := 52.0
const SCORE_BAND_HEIGHT := 100.0
const TABLE_TOP := 170.0
const TABLE_CARD_HALF_WIDTH := 90.0
const TABLE_CARD_HEIGHT := 252.0
const ACTION_BUTTON_SIZE := Vector2(170.0, 44.0)
const ACTION_BUTTON_MARGIN := 20.0
const HUD_COLUMN_WIDTH := 300.0

## Icones do HUD: 32 px e o tamanho em que os icones foram
## salvos, entao cada pixel da arte aparece como bloco 2x2.
const HUD_ICON_SIZE := 32.0
const HUD_ICON_SEPARATION := 8
const HUD_SHORTCUT_SIZE := Vector2(44.0, 44.0)
const SCORE_BAR_LENGTH := 20

var hud_column: VBoxContainer
var stats_panel: PanelContainer
var score_bar_label: Label

## Linha de status no topo, no estilo de prompt de terminal,
## com um cursor piscando no fim.
const STATUS_CURSOR_BLINK := 0.5
var attack_status_text := ""
var status_cursor_on := true
var status_cursor_timer: Timer
const CARD_DETAILS_SCREEN_MARGIN := 12.0

func _ready() -> void:
	_connect_signals()
	_setup_menus()
	_setup_score_popup()
	_setup_round_banner()
	_setup_scenario_card()
	_setup_codec_call()
	_setup_boss_battle()
	_setup_ad_popups()
	_setup_sfx()
	_setup_hud()
	_setup_background()

	# Rodando Game.tscn direto (F6), sem o menu principal.
	if not SessionLogger.is_active():
		SessionLogger.start_session("")

	difficulty = DIFFICULTY.get_selected()
	round_controller.difficulty = difficulty
	boss_battle.wrong_damage_multiplier = difficulty.boss_damage_multiplier
	SessionLogger.set_session_info("difficulty", str(difficulty.id))

	await _start_game()


func _setup_menus() -> void:
	menu_layer = CanvasLayer.new()
	menu_layer.layer = 100
	add_child(menu_layer)

	scenario_summary = (
		SCENARIO_SUMMARY_SCENE.instantiate()
		as ScenarioSummary
	)
	menu_layer.add_child(scenario_summary)

	pause_menu = PAUSE_MENU_SCENE.instantiate() as PauseMenu
	menu_layer.add_child(pause_menu)

	# Precisam continuar respondendo com a arvore pausada.
	pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS

	pause_menu.resume_requested.connect(
		_on_resume_requested
	)
	pause_menu.encyclopedia_requested.connect(
		_on_encyclopedia_requested
	)
	pause_menu.help_requested.connect(
		_on_help_requested
	)
	pause_menu.main_menu_requested.connect(
		_on_main_menu_requested
	)

	encyclopedia = (
		ENCYCLOPEDIA_SCENE.instantiate()
		as Encyclopedia
	)
	menu_layer.add_child(encyclopedia)
	encyclopedia.process_mode = Node.PROCESS_MODE_ALWAYS
	encyclopedia.closed.connect(_on_encyclopedia_closed)
	encyclopedia.hide()

	help_screen = HELP_SCREEN_SCRIPT.new()
	menu_layer.add_child(help_screen)
	help_screen.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	help_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	help_screen.closed.connect(_on_help_closed)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return

	if pause_menu == null:
		return

	if scenario_summary != null and scenario_summary.visible:
		return

	# A enciclopedia, a ajuda e o menu de pausa tratam o
	# ESC deles.
	if encyclopedia != null and encyclopedia.visible:
		return

	if help_screen != null and help_screen.visible:
		return

	if pause_menu.visible:
		return

	get_viewport().set_input_as_handled()
	_open_pause_menu()


func _open_pause_menu() -> void:
	SessionLogger.log_event("pause_opened", {})
	_hide_card_details()
	pause_menu.show()
	get_tree().paused = true


func _close_pause_menu() -> void:
	pause_menu.hide()
	get_tree().paused = false


func _on_resume_requested() -> void:
	_close_pause_menu()


func _on_encyclopedia_requested() -> void:
	SessionLogger.log_event("encyclopedia_opened", {
		"from": "pause",
	})
	overlay_returns_to_pause = true
	pause_menu.hide()
	_show_encyclopedia()


func _on_hud_encyclopedia_pressed() -> void:
	if get_tree().paused:
		return

	SessionLogger.log_event("encyclopedia_opened", {
		"from": "hud",
	})
	_pause_for_overlay()
	_show_encyclopedia()


func _show_encyclopedia() -> void:
	# Abre no capitulo do cenario em andamento.
	if current_scenario_data != null:
		encyclopedia.select_chapter_for_scenario(
			current_scenario_data.id
		)

	encyclopedia.refresh()
	encyclopedia.show()


func _on_encyclopedia_closed() -> void:
	encyclopedia.hide()
	_return_from_overlay()


func _on_help_requested() -> void:
	SessionLogger.log_event("help_opened", {
		"from": "pause",
	})
	overlay_returns_to_pause = true
	pause_menu.hide()
	help_screen.show()


func _on_hud_help_pressed() -> void:
	if get_tree().paused:
		return

	SessionLogger.log_event("help_opened", {
		"from": "hud",
	})
	_pause_for_overlay()
	help_screen.show()


func _on_help_closed() -> void:
	help_screen.hide()
	_return_from_overlay()


## Pausa a partida para abrir a enciclopedia ou a ajuda
## pelos botoes do HUD, sem passar pelo menu de pausa.
func _pause_for_overlay() -> void:
	overlay_returns_to_pause = false
	_hide_card_details()
	get_tree().paused = true


## Ao fechar a enciclopedia ou a ajuda, volta para onde o
## jogador estava: o menu de pausa ou direto a partida.
func _return_from_overlay() -> void:
	if overlay_returns_to_pause:
		pause_menu.show()
	else:
		get_tree().paused = false


func _on_main_menu_requested() -> void:
	SessionLogger.end_session("returned_to_menu")
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)


func _show_game_intro() -> void:
	if GAME_INTRO_DIALOGUE == null:
		return

	_hide_card_details()

	hand.set_interaction_enabled(false)
	play_button.disabled = true
	
	dialogue_box.show_dialogue_data(
		GAME_INTRO_DIALOGUE, 1.0, true
	)

	await dialogue_box.finished
	

func _start_game() -> void:
	if scenarios.is_empty():
		push_error("Nenhum cenário foi configurado.")
		return

	# Atalho do menu de desenvolvedor: so em build de depuracao.
	if OS.is_debug_build():
		var dev_start: Dictionary = DEV_OPTIONS.take_start()

		if not dev_start.is_empty():
			await _start_game_from_dev_menu(dev_start)
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
	first_breach_tutorial_shown = false
	ad_popups_tutorial_shown = false
	
	await _show_game_intro()
	await _start_scenario()
	
	
## Comeca a partida no ponto escolhido no menu de
## desenvolvedor: introducao do cenario, uma rodada ou o chefe.
func _start_game_from_dev_menu(request: Dictionary) -> void:
	current_scenario_index = clampi(
		int(request.get("scenario_index", 0)), 0, scenarios.size() - 1
	)
	current_scenario_data = scenarios[current_scenario_index]

	var rounds := current_scenario_data.rounds

	if rounds.is_empty():
		push_error(
			"O cenário '%s' não possui rodadas."
			% current_scenario_data.id
		)
		return

	first_breach_tutorial_shown = false
	ad_popups_tutorial_shown = false

	SessionLogger.log_event("dev_start", request)

	if not bool(request.get("skip_game_intro", true)):
		await _show_game_intro()

	# Abre as brechas que as cartas do cenario podem abrir,
	# para testar a ultima rodada e os anuncios sem jogar as
	# rodadas anteriores.
	if bool(request.get("open_breaches", false)):
		for card_id in current_scenario_data.deck:
			var card: CardData = CardDatabase.get_card(card_id)

			if card != null and card.opens_breach != null:
				round_controller.open_breach(card.opens_breach)

	var start: String = str(request.get("start", DEV_OPTIONS.START_INTRO))

	match start:
		DEV_OPTIONS.START_ROUND:
			_reset_scenario_stats()
			current_round_index = clampi(
				int(request.get("round_index", 0)), 0, rounds.size() - 1
			)
			current_round_data = rounds[current_round_index]

			SessionLogger.log_event("scenario_start", {
				"scenario_id": str(current_scenario_data.id),
			})

			_cover_with_black()
			pending_fade_from_black = true
			await _start_round()

		DEV_OPTIONS.START_BOSS:
			_reset_scenario_stats()
			# Posiciona na ultima rodada: avancar a progressao a
			# partir dela leva ao chefe, ao resumo e a ligacao.
			current_round_index = rounds.size() - 1
			current_round_data = rounds[current_round_index]

			SessionLogger.log_event("scenario_start", {
				"scenario_id": str(current_scenario_data.id),
			})

			await _advance_progression()

		_:
			current_round_index = 0
			current_round_data = rounds[0]
			await _start_scenario()


func _start_scenario() -> void:
	_reset_scenario_stats()

	print(
		"Iniciando cenário: ",
		current_scenario_data.display_name
	)

	SessionLogger.log_event("scenario_start", {
		"scenario_id": str(current_scenario_data.id),
	})

	await _show_scenario_card()
	await _show_scenario_intro()

	# A tela fica preta ate a primeira rodada montar o HUD.
	# Senao o fade mostraria os valores da rodada anterior.
	_cover_with_black()
	pending_fade_from_black = true

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
	hand.card_details_requested.connect(
		_on_card_details_requested
	)

	hand.card_details_hidden.connect(
		_on_card_details_hidden
	)

	card_details_panel.set_panel_width(GAME_DETAILS_PANEL_WIDTH)

	# O texto com quebra automatica pode mudar de altura depois
	# do primeiro posicionamento. Reposiciona a cada mudanca.
	card_details_panel.resized.connect(_on_card_details_panel_resized)


func _on_card_details_requested(card: Card) -> void:
	if card == null:
		return

	if not is_instance_valid(card):
		return

	if card.data == null:
		return

	details_hide_request_id += 1
	var request_id := details_hide_request_id

	detailed_card = card
	_begin_details_view(card)

	# O painel fica visivel mas transparente enquanto o
	# conteudo e o tamanho sao recalculados. Escondido (visible
	# = false) os Containers nao refazem o layout, e o painel
	# aparecia um frame com os textos no tamanho antigo.
	card_details_panel.show_card(card.data)
	card_details_panel.modulate.a = 0.0

	# Aguarda os Labels e Containers recalcularem
	# seus tamanhos mínimos.
	await get_tree().process_frame

	card_details_panel.reset_size()

	await get_tree().process_frame

	# Cancela esta exibição caso o mouse já tenha
	# saído da carta ou entrado em outra.
	if request_id != details_hide_request_id:
		return

	if card != detailed_card:
		return

	if not is_instance_valid(card):
		return

	_position_card_details_panel(card)

	card_details_panel.modulate.a = 1.0


func _position_card_details_panel(card: Card) -> void:
	if not is_instance_valid(card):
		return

	if card != detailed_card:
		return

	var viewport_rect := get_viewport().get_visible_rect()
	var card_rect := card.get_global_rect()

	var panel_size := card_details_panel.size

	var maximum_height := (
		viewport_rect.size.y
		- CARD_DETAILS_SCREEN_MARGIN * 2.0
	)

	# Limita a altura somente depois de o layout
	# interno ter sido calculado.
	if panel_size.y > maximum_height:
		panel_size.y = maximum_height
		card_details_panel.size = panel_size

	var target_x := (
		card_rect.get_center().x
		- panel_size.x / 2.0
	)

	var target_y := (
		card_rect.position.y
		- panel_size.y
		- CARD_DETAILS_GAP
	)

	target_x = clampf(
		target_x,
		viewport_rect.position.x
			+ CARD_DETAILS_SCREEN_MARGIN,
		viewport_rect.end.x
			- panel_size.x
			- CARD_DETAILS_SCREEN_MARGIN
	)

	# Caso não caiba acima da carta, coloca abaixo.
	if target_y < (
		viewport_rect.position.y
		+ CARD_DETAILS_SCREEN_MARGIN
	):
		target_y = (
			card_rect.end.y
			+ CARD_DETAILS_GAP
		)

	target_y = clampf(
		target_y,
		viewport_rect.position.y
			+ CARD_DETAILS_SCREEN_MARGIN,
		viewport_rect.end.y
			- panel_size.y
			- CARD_DETAILS_SCREEN_MARGIN
	)

	card_details_panel.global_position = Vector2(
		target_x,
		target_y
	)


func _on_card_details_panel_resized() -> void:
	if not card_details_panel.visible:
		return

	if detailed_card == null or not is_instance_valid(detailed_card):
		return

	_position_card_details_panel(detailed_card)


func _on_card_details_hidden(card: Card) -> void:
	if card != detailed_card:
		return

	# Invalida qualquer exibição que ainda esteja
	# aguardando os frames de atualização do layout.
	details_hide_request_id += 1

	_end_details_view()
	detailed_card = null
	card_details_panel.hide_card()


func _setup_deck() -> void:
	# O baralho da rodada, quando existe, substitui
	# o do cenario.
	if (
		current_round_data != null
		and not current_round_data.deck.is_empty()
	):
		player_deck.setup(current_round_data.deck)
		return

	if current_scenario_data == null:
		push_error("Nenhum cenario carregado para montar o baralho.")
		return

	if current_scenario_data.deck.is_empty():
		push_warning(
			"O cenario '%s' nao possui baralho configurado."
			% current_scenario_data.id
		)
		return

	player_deck.setup(current_scenario_data.deck)


func _draw_cards(amount: int) -> void:
	var drawn := 0

	for _i in range(amount):
		var card_id := player_deck.draw()

		if card_id.is_empty():
			print("Não há mais cartas disponíveis para compra.")
			break

		var is_new_card: bool = CardCollection.unlock(card_id)
		_register_scenario_card(card_id, is_new_card)

		var card := CardFactory.instantiate_card(card_id)

		if card == null:
			push_error(
				"Não foi possível instanciar a carta '%s'." % card_id
			)
			continue

		hand.add_card(card)

		_play_sfx_later(
			drawn * SFX_DRAW_STAGGER,
			SFX_CARD_DRAW,
			SFX_CARD_DRAW_DB,
			_random_card_pitch()
		)
		drawn += 1


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

	# Some na hora: evita um segundo clique durante a
	# transicao para a proxima rodada.
	next_round_button.visible = false

	await _discard_remaining_hand()

	if victory:
		await _advance_progression()
	else:
		round_controller.restore_active_breaches(
			breaches_at_round_start
		)

		_update_breaches_hud()

		await _start_round(true)
	

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

	played_cards_landing_time = 0.0

	for i in range(cards.size()):
		var card := cards[i]

		played_cards.add_child(card)

		# Tambem interrompe o tween de posicao da mao, que
		# senao continuaria puxando a carta no novo pai.
		card.set_interaction_enabled(false)

		card.scale = Vector2.ONE
		card.z_index = i

		var target_position := Vector2(
			start_x + i * CARD_SPACING,
			0.0
		)

		if not card.has_play_origin:
			card.position = target_position
			continue

		card.global_position = card.play_origin_global
		card.has_play_origin = false

		# As cartas saem uma depois da outra, da esquerda
		# para a direita.
		var delay: float = i * PLAY_CARD_STAGGER
		var tween := card.create_tween()

		tween.tween_interval(delay)
		tween.tween_property(
			card,
			"position",
			target_position,
			PLAY_CARD_MOVE_DURATION
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

		played_cards_landing_time = maxf(
			played_cards_landing_time,
			delay + PLAY_CARD_MOVE_DURATION
		)

		# O som toca quando a carta chega na mesa. A curva de
		# saida rapida faz a carta chegar perto do destino antes
		# do fim do movimento.
		_play_sfx_later(
			delay + PLAY_CARD_MOVE_DURATION * 0.6,
			SFX_CARD_PLAY,
			SFX_CARD_PLAY_DB,
			_random_card_pitch()
		)


func _hide_card_details() -> void:
	details_hide_request_id += 1
	_end_details_view()
	detailed_card = null
	card_details_panel.hide_card()


func _update_score_display(cards: Array[Card]) -> void:
	var result := ScoreCalculator.calculate(cards)

	current_play_score = float(result["total"])

	_animate_play_score(
		int(result["protection"]),
		float(result["vulnerability"]),
		float(result["total"]),
		cards
	)
	
	
func _resolve_played_cards() -> void:
	if pending_cards.is_empty():
		is_resolving_play = false
		return

	var amount_played: int = pending_cards.size()
	var played_card_ids: Array[String] = []

	var breaches_to_open: Array[SecurityBreachData] = []
	var breach_ids_to_close: Array[String] = []

	var newly_opened_breaches: Array[SecurityBreachData] = []
	var closed_breaches: Array[SecurityBreachData] = []

	# Registra os efeitos das cartas antes de removê-las.
	for card in pending_cards:
		if card.data == null:
			continue

		played_card_ids.append(str(card.data.id))

		if card.data.opens_breach != null:
			breaches_to_open.append(
				card.data.opens_breach
			)

		for breach_id in card.data.closes_breach_ids:
			if breach_id.is_empty():
				continue

			if breach_id not in breach_ids_to_close:
				breach_ids_to_close.append(breach_id)

	# Fecha brechas antes de calcular a penalidade.
	for breach_id in breach_ids_to_close:
		var closed_breach := (
			round_controller.close_breach_by_id(
				breach_id
			)
		)

		if closed_breach != null:
			closed_breaches.append(closed_breach)
			scenario_breaches_closed += 1

	# Apenas as brechas que permaneceram abertas
	# penalizam esta jogada.
	var breach_penalty: float = (
		current_play_score
		* round_controller.get_breach_penalty_ratio()
	)

	# A contagem da jogada termina antes de a penalidade
	# e o placar da rodada entrarem na tela.
	await _wait_score_tween()

	var round_score_before: float = round_controller.score

	round_controller.register_play(
		current_play_score,
		breach_penalty
	)

	plays_made_in_round += 1

	# O numero sofre a penalidade no centro e voa ate o
	# placar da rodada antes dos avisos de brecha aberta.
	_show_round_score_step(round_score_before)
	_animate_play_resolution(round_score_before, round_controller.score)
	await _wait_score_tween()

	# As brechas criadas nesta jogada passam a valer
	# nas jogadas seguintes.
	for breach in breaches_to_open:
		var was_opened := round_controller.open_breach(
			breach
		)

		if was_opened:
			newly_opened_breaches.append(breach)
			scenario_breaches_opened += 1

	_log_play(newly_opened_breaches, closed_breaches)

	var breach_feedback_messages: Array[String] = []

	for breach in closed_breaches:
		breach_feedback_messages.append(
			"Brecha corrigida: %s"
			% breach.display_name
		)

	for breach in newly_opened_breaches:
		breach_feedback_messages.append(
			"Brecha aberta: %s"
			% breach.display_name
		)
		
	if (not closed_breaches.is_empty()
		or not newly_opened_breaches.is_empty()):
		_update_breaches_hud()
	
	if not newly_opened_breaches.is_empty():
		await _show_first_breach_tutorial()
		await _show_ad_popups_tutorial(newly_opened_breaches)

	if not breach_feedback_messages.is_empty():
		_show_breach_feedback(
			"\n".join(breach_feedback_messages)
		)
	if (
		not closed_breaches.is_empty()
		or not newly_opened_breaches.is_empty()
	):
		_update_breaches_hud()

	print(
		"[BRECHAS] Penalidade aplicada: ",
		round_controller.last_breach_penalty
	)

	print(
		"[BRECHAS] Brechas ativas após a jogada: ",
		round_controller
			.get_active_breaches()
			.size()
	)
		
	if detailed_card in pending_cards:
		detailed_card = null
		card_details_panel.hide_card()
		
	# Descarta e remove todas as cartas utilizadas.
	for card in pending_cards:
		if card.data != null:
			player_deck.discard(str(card.data.id))

		card.queue_free()

	pending_cards.clear()
	current_play_score = 0.0

	_update_round_hud()
	_update_resolved_play_display()

	await _show_triggered_mid_dialogues(played_card_ids)

	if round_controller.has_won():
		await _finish_round(true)
		return

	if round_controller.has_lost():
		await _finish_round(false)
		return

	_draw_cards(amount_played)

	is_resolving_play = false
	hand.set_interaction_enabled(true)
	_update_play_button_state()


func _start_round(is_retry := false) -> void:
	# Uma contagem da rodada anterior nao pode sobrescrever
	# o placar zerado da nova rodada.
	_kill_score_tween()

	if score_popup_root != null:
		score_popup_root.hide()

	current_play_score = 0.0
	is_resolving_play = false
	
	plays_made_in_round = 0
	triggered_mid_dialogues.clear()

	breaches_at_round_start = (round_controller.get_active_breaches())
	round_controller.start(current_round_data)
	_update_breaches_hud()
	_log_round_start()

	result_label.text = ""
	result_label.visible = false
	score_label.text = "Selecione as cartas"

	next_round_button.visible = false
	play_button.visible = true

	hand.clear_selection()
	hand.set_interaction_enabled(false)
	play_button.disabled = true

	_setup_deck()
	_update_round_hud()

	if pending_fade_from_black:
		pending_fade_from_black = false
		await _fade_from_black()

	await _show_round_start_banner(is_retry)

	# A mao so e distribuida depois da faixa da rodada.
	_fill_hand()

	await _show_round_start_dialogue()

	_show_exploited_breaches_feedback()

	hand.set_interaction_enabled(true)
	_update_play_button_state()
	
	
func _hand_size() -> int:
	var modifier := difficulty.hand_size_modifier if difficulty != null else 0
	return maxi(1, INITIAL_HAND_SIZE + modifier)


func _fill_hand() -> void:
	var current_hand_size := hand.get_cards().size()
	var missing_cards := _hand_size() - current_hand_size

	if missing_cards > 0:
		_draw_cards(missing_cards)
	
	
func _update_round_hud() -> void:
	attack_status_text = (
		"> SETOR: %s   RODADA %d/%d   AMEAÇA: %s"
		% [
			current_scenario_data.display_name.to_upper(),
			current_round_index + 1,
			current_scenario_data.rounds.size(),
			current_round_data.attack_name.to_upper()
		]
	)
	_refresh_attack_label()

	risk_label.text = (
		"Índice de Risco: %.0f"
		% round_controller.get_risk()
	)
	
	var exploited_breaches := (
	round_controller.get_exploited_breaches()
)

	if exploited_breaches.is_empty():
		risk_label.tooltip_text = (
			"Índice de Risco necessário para superar a ameaça."
		)
	else:
		var breach_names: Array[String] = []

		for breach in exploited_breaches:
			if breach == null:
				continue

			breach_names.append(
				breach.display_name
			)

		var risk_increase := (
			round_controller
			.get_breach_exploitation_risk_increase()
		)

		risk_label.tooltip_text = (
			"Risco base: %.0f\n"
			+ "Aumento por brechas exploradas: +%.0f\n"
			+ "Brechas exploradas: %s"
		) % [
			current_round_data.base_risk,
			risk_increase,
			", ".join(breach_names)
		]

	round_score_label.text = (
		"Pontuação da rodada: %.0f"
		% round_controller.score
	)

	_update_score_bar(round_controller.score)

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
	var boss: Resource = current_scenario_data.boss

	if boss != null:
		await _play_boss_battle(boss)

	scenario_timer_running = false
	var stats := _build_scenario_stats(boss != null)

	SessionLogger.log_event("scenario_end", {
		"scenario_id": str(current_scenario_data.id),
		"cards_seen": scenario_seen_card_ids.duplicate(),
		"new_cards": scenario_new_card_ids.duplicate(),
		"score": stats["score"],
		"breaches_opened": stats["breaches_opened"],
		"breaches_closed": stats["breaches_closed"],
		"retries": stats["retries"],
		"seconds": snappedf(stats["seconds"], 0.1),
	})

	await _show_scenario_summary(stats)


	# O resumo cobria a batalha; ela sai agora.
	if boss_battle.visible:
		boss_battle.hide()

	var ending_call: DialogueData = current_scenario_data.ending_call

	if ending_call != null:
		await _play_codec_call(ending_call)

	current_scenario_index += 1

	# Não existem mais cenários.
	if current_scenario_index >= scenarios.size():
		if ending_call != null:
			await _fade_from_black()
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
	_log_round_end(victory)

	if victory:
		scenario_score += round_controller.score
	else:
		scenario_retries += 1

	# Os anuncios somem entre as rodadas. Se a brecha continuar
	# aberta, eles voltam na rodada seguinte.
	ad_popups.close_all()

	is_resolving_play = false
	play_button.disabled = true

	hand.clear_selection()
	hand.set_interaction_enabled(false)

	# Se a ultima jogada abriu ou corrigiu uma brecha, o aviso
	# termina antes da faixa de resultado, para um nao cobrir
	# o outro.
	await _wait_for_breach_feedback()

	await _show_round_result_banner(victory)
	await _show_round_result_dialogue(victory)
	
	if victory:
		result_label.text = "Rodada vencida!  %.0f / %.0f" % [
			round_controller.score,
			round_controller.get_risk()
		]
		result_label.visible = true
		next_round_button.text = "Próxima rodada"
	else:
		result_label.text = "Rodada perdida!  %.0f / %.0f" % [
			round_controller.score,
			round_controller.get_risk()
		]
		result_label.visible = true
		next_round_button.text = "Tentar novamente"

	score_label.text = (
		"Pontuação final: %.0f / %.0f"
		% [
			round_controller.score,
			round_controller.get_risk()
		]
	)

	next_round_button.visible = true
	# Os dois botoes ocupam o mesmo lugar. Um botao
	# desabilitado ainda recebe o clique, entao o Jogar
	# precisa sumir para o Proxima rodada ser clicavel.
	play_button.visible = false


func _discard_remaining_hand() -> void:
	_hide_card_details()

	# Guarda onde cada carta estava antes de sair da mao.
	var positions: Array[Vector2] = []

	for card in hand.get_cards():
		positions.append(card.global_position)

	var remaining_cards := hand.take_all_cards()
	var total_time := 0.0

	for i in range(remaining_cards.size()):
		var card := remaining_cards[i]

		if card.data != null:
			player_deck.discard(str(card.data.id))

		# Fora da mao, a carta vai para a raiz so para a
		# animacao de saida.
		add_child(card)
		card.set_interaction_enabled(false)
		card.scale = Vector2.ONE

		if i < positions.size():
			card.global_position = positions[i]

		var delay := i * DISCARD_STAGGER
		var tween := card.create_tween()
		tween.tween_interval(delay)
		tween.tween_property(
			card,
			"position:y",
			card.position.y + DISCARD_DROP,
			DISCARD_DURATION
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(
			card,
			"modulate:a",
			0.0,
			DISCARD_DURATION
		)
		tween.tween_callback(card.queue_free)

		total_time = maxf(total_time, delay + DISCARD_DURATION)

	if total_time > 0.0:
		await get_tree().create_timer(total_time).timeout
		
		
func _finish_game() -> void:
	hand.clear_selection()
	hand.set_interaction_enabled(false)

	play_button.disabled = true
	next_round_button.visible = false
	# Fim da partida: nenhum dos dois botoes tem funcao.
	play_button.visible = false

	SessionLogger.end_session("completed")

	result_label.text = "Você concluiu todos os cenários!"
	result_label.visible = true
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
		
	_hide_card_details()
	dialogue_box.show_dialogue_data(intro_dialogue, 1.0, true)

	# O dialogo tambem tem fundo preto: trocar um pelo outro
	# no mesmo quadro nao deixa a partida aparecer no meio.
	scenario_card.hide()

	await dialogue_box.finished
	
	
func _show_round_start_dialogue() -> void:
	if current_round_data == null:
		return

	var dialogues_to_show: Array[DialogueData] = []

	# Usa a sequência nova, caso ela tenha sido configurada.
	for dialogue_data in current_round_data.start_dialogues:
		if dialogue_data != null:
			dialogues_to_show.append(dialogue_data)

	# Compatibilidade com as rodadas antigas.
	if (
		dialogues_to_show.is_empty()
		and current_round_data.start_dialogue != null
	):
		dialogues_to_show.append(
			current_round_data.start_dialogue
		)

	if dialogues_to_show.is_empty():
		return

	_hide_card_details()

	hand.set_interaction_enabled(false)
	play_button.disabled = true

	for dialogue_data in dialogues_to_show:
		_clear_interface_highlight()

		dialogue_box.show_dialogue_data(
			dialogue_data
		)

		await dialogue_box.finished

		# Dá ao DialogueBox um frame para concluir
		# o fechamento antes de abrir o próximo.
		await get_tree().process_frame

	_clear_interface_highlight()
	

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

		_hide_card_details()
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

		# As linhas do HUD incluem o icone: destaca a linha
		# inteira, que e o pai do rotulo.
		DialogueLineData.HighlightTarget.RISK:
			_highlight_control(risk_label.get_parent() as Control)

		DialogueLineData.HighlightTarget.ROUND_SCORE:
			_highlight_control(round_score_label.get_parent() as Control)

		DialogueLineData.HighlightTarget.PLAYS:
			_highlight_control(plays_label.get_parent() as Control)

		DialogueLineData.HighlightTarget.PLAY_BUTTON:
			_highlight_control(play_button)

		DialogueLineData.HighlightTarget.HAND:
			call_deferred("_highlight_hand_cards")

		DialogueLineData.HighlightTarget.PLAY_AREA:
			_highlight_control(played_cards)

		DialogueLineData.HighlightTarget.BREACHES:
			_highlight_control(breaches_panel)


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


func _show_round_result_dialogue(won: bool) -> void:
	if current_round_data == null:
		return

	var result_dialogue: DialogueData = null

	if won:
		result_dialogue = current_round_data.victory_dialogue
	else:
		result_dialogue = current_round_data.defeat_dialogue

	if result_dialogue == null:
		return

	_hide_card_details()

	hand.set_interaction_enabled(false)
	play_button.disabled = true

	dialogue_box.show_dialogue_data(result_dialogue)
	await dialogue_box.finished


func _update_breaches_hud() -> void:
	var active_ids: Array[String] = []

	# Brechas novas: cria o indicador e faz piscar.
	for breach in round_controller.get_active_breaches():
		if breach == null:
			continue

		active_ids.append(breach.id)

		if breach_indicators.has(breach.id):
			continue

		var indicator := _create_breach_indicator(breach)
		breach_list.add_child(indicator)
		breach_indicators[breach.id] = indicator
		_flash_control(indicator)

	# Brechas corrigidas: o indicador some com fade.
	for key: Variant in breach_indicators.keys():
		var breach_id: String = key

		if breach_id in active_ids:
			continue

		var closed_indicator: Control = breach_indicators[breach_id]
		breach_indicators.erase(breach_id)
		_fade_out_breach_indicator(closed_indicator)

	# Sem brechas ativas, o painel so some depois do fade,
	# em _hide_breaches_panel_if_empty().
	if not active_ids.is_empty():
		breaches_panel.visible = true
	elif breach_list.get_child_count() == 0:
		breaches_panel.visible = false

	ad_popups.set_active(AD_POPUPS_BREACH_ID in active_ids)


func _create_breach_indicator(
	breach: SecurityBreachData
) -> PanelContainer:
	var breach_indicator := (
		WRAPPING_TOOLTIP_PANEL.new() as PanelContainer
	)
	var breach_label := Label.new()

	breach_indicator.custom_minimum_size = Vector2(
		0.0,
		30.0
	)

	breach_indicator.mouse_filter = (
		Control.MOUSE_FILTER_STOP
	)

	breach_indicator.tooltip_text = (
		"%s\n\n%s\n\nPenalidade: -%.0f%% por jogada"
		% [
			breach.display_name,
			breach.description,
			breach.score_penalty_ratio * 100.0
		]
	)

	breach_label.text = breach.display_name
	breach_label.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	var breach_icon: Texture2D = breach.icon

	if breach_icon == null:
		breach_icon = UIPalette.ICON_BREACH

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(UIPalette.make_pixel_icon(breach_icon, HUD_ICON_SIZE))
	breach_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(breach_label)

	breach_indicator.add_child(row)

	return breach_indicator


## Pisca em vermelho algumas vezes e volta a cor normal.
func _flash_control(control: Control) -> void:
	if control == null:
		return

	control.modulate = Color.WHITE

	var tween := create_tween()
	tween.set_loops(BREACH_FLASH_LOOPS)

	tween.tween_property(
		control,
		"modulate",
		BREACH_FLASH_COLOR,
		BREACH_FLASH_STEP
	)
	tween.tween_property(
		control,
		"modulate",
		Color.WHITE,
		BREACH_FLASH_STEP
	)


func _fade_out_breach_indicator(indicator: Control) -> void:
	if indicator == null:
		return

	var tween := create_tween()

	tween.tween_property(
		indicator,
		"modulate:a",
		0.0,
		BREACH_FADE_DURATION
	)
	tween.tween_callback(indicator.queue_free)
	tween.tween_callback(_hide_breaches_panel_if_empty)


func _hide_breaches_panel_if_empty() -> void:
	if breach_indicators.is_empty():
		breaches_panel.visible = false


## Chamado quando uma ameaca explora brechas no inicio da
## rodada: o Indice de Risco pulsa em vermelho.
func _pulse_risk_label() -> void:
	risk_label.pivot_offset = risk_label.size / 2.0

	var tween := create_tween()
	tween.set_loops(RISK_PULSE_LOOPS)

	tween.tween_property(
		risk_label,
		"scale",
		Vector2.ONE * RISK_PULSE_SCALE,
		RISK_PULSE_STEP
	)
	tween.parallel().tween_property(
		risk_label,
		"modulate",
		BREACH_FLASH_COLOR,
		RISK_PULSE_STEP
	)

	tween.tween_property(
		risk_label,
		"scale",
		Vector2.ONE,
		RISK_PULSE_STEP
	)
	tween.parallel().tween_property(
		risk_label,
		"modulate",
		Color.WHITE,
		RISK_PULSE_STEP
	)


func _update_resolved_play_display() -> void:
	var base_score := round_controller.last_play_base_score
	var penalty: float = round_controller.last_breach_penalty
	var final_score := round_controller.last_play_final_score

	if penalty <= 0.0:
		score_label.text = "Última jogada: +%.2f" % final_score
		return

	score_label.text = (
		"Última jogada: +%.2f  "
		+ "(base %.2f, penalidade das brechas -%.2f)"
	) % [final_score, base_score, penalty]


func _show_breach_feedback(message: String) -> void:
	if message.is_empty():
		return

	if (
		breach_feedback_tween != null
		and breach_feedback_tween.is_valid()
	):
		breach_feedback_tween.kill()

	breach_feedback_label.text = message

	breach_feedback.modulate.a = 0.0
	breach_feedback.show()

	breach_feedback_tween = create_tween()

	breach_feedback_tween.tween_property(
		breach_feedback,
		"modulate:a",
		1.0,
		0.15
	)

	breach_feedback_tween.tween_interval(1.5)

	breach_feedback_tween.tween_property(
		breach_feedback,
		"modulate:a",
		0.0,
		0.25
	)

	breach_feedback_tween.tween_callback(
		breach_feedback.hide
	)


func _wait_for_breach_feedback() -> void:
	if (
		breach_feedback_tween != null
		and breach_feedback_tween.is_valid()
		and breach_feedback_tween.is_running()
	):
		await breach_feedback_tween.finished


func _show_first_breach_tutorial() -> void:
	if first_breach_tutorial_shown:
		return

	if FIRST_BREACH_DIALOGUE == null:
		return

	first_breach_tutorial_shown = true

	_hide_card_details()

	hand.set_interaction_enabled(false)
	play_button.disabled = true

	dialogue_box.show_dialogue_data(
		FIRST_BREACH_DIALOGUE
	)

	await dialogue_box.finished

	if not round_controller.finished:
		hand.set_interaction_enabled(true)
		_update_play_button_state()


func _show_exploited_breaches_feedback() -> void:
	var exploited_breaches := (
		round_controller.get_exploited_breaches()
	)

	if exploited_breaches.is_empty():
		return

	var breach_names: Array[String] = []

	for breach in exploited_breaches:
		if breach == null:
			continue

		breach_names.append(
			breach.display_name
		)

	var risk_increase := (
		round_controller
		.get_breach_exploitation_risk_increase()
	)

	_pulse_risk_label()

	for breach in exploited_breaches:
		if breach != null and breach_indicators.has(breach.id):
			_flash_control(breach_indicators[breach.id])

	_show_breach_feedback(
		"Ameaça explorou: %s\nÍndice de Risco +%.0f"
		% [
			", ".join(breach_names),
			risk_increase
		]
	)


func _register_scenario_card(
	card_id: String,
	is_new: bool
) -> void:
	if card_id not in scenario_seen_card_ids:
		scenario_seen_card_ids.append(card_id)

	if is_new and card_id not in scenario_new_card_ids:
		scenario_new_card_ids.append(card_id)


func _reset_scenario_stats() -> void:
	scenario_seen_card_ids.clear()
	scenario_new_card_ids.clear()
	scenario_score = 0.0
	scenario_breaches_opened = 0
	scenario_breaches_closed = 0
	scenario_retries = 0
	scenario_elapsed = 0.0
	scenario_timer_running = true


func _process(delta: float) -> void:
	if scenario_timer_running:
		scenario_elapsed += delta


func _build_scenario_stats(had_boss: bool) -> Dictionary:
	var stats := {
		"score": scenario_score,
		"breaches_opened": scenario_breaches_opened,
		"breaches_closed": scenario_breaches_closed,
		"retries": scenario_retries,
		"seconds": scenario_elapsed,
		"has_boss": had_boss,
		"boss_correct": 0,
		"boss_wrong": 0,
	}

	if had_boss:
		stats["boss_correct"] = boss_battle.correct_answers
		stats["boss_wrong"] = boss_battle.wrong_answers

	return stats


func _show_scenario_summary(stats: Dictionary) -> void:
	if scenario_summary == null:
		return

	if current_scenario_data == null:
		return

	_hide_card_details()

	hand.set_interaction_enabled(false)
	play_button.disabled = true
	next_round_button.visible = false
	play_button.visible = true

	scenario_summary.show_summary(
		current_scenario_data.display_name,
		scenario_seen_card_ids,
		scenario_new_card_ids,
		stats
	)

	await scenario_summary.continue_requested

	scenario_summary.hide()


# --- Metricas da avaliacao experimental ---------------------

func _log_round_start() -> void:
	var round_key := "%s/%s" % [
		current_scenario_data.id,
		current_round_data.id
	]

	if round_key == attempt_round_key:
		round_attempt += 1
	else:
		attempt_round_key = round_key
		round_attempt = 1

	SessionLogger.log_event("round_start", {
		"scenario_id": str(current_scenario_data.id),
		"round_id": str(current_round_data.id),
		"attempt": round_attempt,
		"base_risk": current_round_data.base_risk,
		"effective_risk": round_controller.get_risk(),
		"exploited_breaches": _breach_ids(
			round_controller.get_exploited_breaches()
		),
		"active_breaches": _breach_ids(
			round_controller.get_active_breaches()
		),
	})


func _log_play(
	opened: Array[SecurityBreachData],
	closed: Array[SecurityBreachData]
) -> void:
	var score_parts: Dictionary = ScoreCalculator.calculate(
		pending_cards
	)

	var cards_log: Array[Dictionary] = []
	var insecure_cards := 0

	for card in pending_cards:
		if card == null or card.data == null:
			continue

		# Nesta versao, toda pratica insegura abre uma brecha.
		var opens_breach: bool = card.data.opens_breach != null

		if opens_breach:
			insecure_cards += 1

		cards_log.append({
			"id": str(card.data.id),
			"opens_breach": opens_breach,
			"closes_breach": not card.data.closes_breach_ids.is_empty(),
		})

	SessionLogger.log_event("play", {
		"scenario_id": str(current_scenario_data.id),
		"round_id": str(current_round_data.id),
		"attempt": round_attempt,
		"play_number": plays_made_in_round,
		"cards": cards_log,
		"insecure_cards": insecure_cards,
		"protection": int(score_parts["protection"]),
		"multiplier": float(score_parts["vulnerability"]),
		"base_score": round_controller.last_play_base_score,
		"breach_penalty": round_controller.last_breach_penalty,
		"final_score": round_controller.last_play_final_score,
		"round_score": round_controller.score,
		"breaches_opened": _breach_ids(opened),
		"breaches_closed": _breach_ids(closed),
		"active_breaches": _breach_ids(
			round_controller.get_active_breaches()
		),
	})


func _log_round_end(victory: bool) -> void:
	SessionLogger.log_event("round_end", {
		"scenario_id": str(current_scenario_data.id),
		"round_id": str(current_round_data.id),
		"attempt": round_attempt,
		"won": victory,
		"score": round_controller.score,
		"risk": round_controller.get_risk(),
		"plays_used": plays_made_in_round,
		"active_breaches": _breach_ids(
			round_controller.get_active_breaches()
		),
	})


func _begin_details_view(card: Card) -> void:
	_end_details_view()

	if card == null or card.data == null:
		return

	details_view_card_id = str(card.data.id)
	details_view_started_msec = Time.get_ticks_msec()


func _end_details_view() -> void:
	if details_view_card_id.is_empty():
		return

	var seconds: float = (
		(Time.get_ticks_msec() - details_view_started_msec)
		/ 1000.0
	)

	SessionLogger.note_details_view(details_view_card_id, seconds)
	details_view_card_id = ""


func _breach_ids(
	breaches: Array[SecurityBreachData]
) -> Array[String]:
	var ids: Array[String] = []

	for breach in breaches:
		if breach != null:
			ids.append(breach.id)

	return ids


# --- Animacoes de pontuacao ---------------------------------

# --- Batalha contra o chefe -----------------------------------

func _setup_boss_battle() -> void:
	var layer := CanvasLayer.new()
	layer.layer = BOSS_BATTLE_LAYER
	add_child(layer)

	boss_battle = BOSS_BATTLE_SCRIPT.new()
	layer.add_child(boss_battle)
	boss_battle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _play_boss_battle(boss: Resource) -> void:
	_hide_card_details()
	hand.set_interaction_enabled(false)
	play_button.disabled = true

	# Sem consulta durante a luta: o botao da pausa fica
	# desativado, e os atalhos do HUD ficam atras da batalha.
	pause_menu.set_encyclopedia_locked(true)
	ad_popups.set_active(false)
	await boss_battle.play(boss, dialogue_box)
	pause_menu.set_encyclopedia_locked(false)


# --- Sons das cartas --------------------------------------------

func _setup_sfx() -> void:
	for i in range(SFX_PLAYER_COUNT):
		var player := AudioStreamPlayer.new()
		add_child(player)
		sfx_players.append(player)


func _play_sfx(stream: AudioStream, volume_db := 0.0, pitch := 1.0) -> void:
	if stream == null or sfx_players.is_empty():
		return

	# Procura um player parado. Se todos estiverem tocando, usa
	# o mais antigo da fila.
	var player: AudioStreamPlayer = null

	for i in range(sfx_players.size()):
		var candidate := sfx_players[(sfx_next_player + i) % sfx_players.size()]

		if not candidate.playing:
			player = candidate
			break

	if player == null:
		player = sfx_players[sfx_next_player]

	sfx_next_player = (sfx_next_player + 1) % sfx_players.size()

	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()


## Toca depois de um atraso. O timer respeita a pausa.
func _play_sfx_later(
	delay: float,
	stream: AudioStream,
	volume_db := 0.0,
	pitch := 1.0
) -> void:
	if delay <= 0.0:
		_play_sfx(stream, volume_db, pitch)
		return

	get_tree().create_timer(delay, false).timeout.connect(
		_play_sfx.bind(stream, volume_db, pitch)
	)


func _random_card_pitch() -> float:
	return 1.0 + randf_range(
		-SFX_CARD_PITCH_VARIATION,
		SFX_CARD_PITCH_VARIATION
	)


# --- Anuncios do navegador sequestrado --------------------------

func _setup_ad_popups() -> void:
	var layer := CanvasLayer.new()
	layer.layer = AD_POPUPS_LAYER
	add_child(layer)

	ad_popups = AD_POPUPS_SCRIPT.new()
	layer.add_child(ad_popups)
	ad_popups.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ad_popups.setup(_can_show_ad_popups)
	ad_popups.ad_clicked.connect(_on_ad_popup_clicked)


## Janelas novas so surgem no turno do jogador: sem dialogo,
## sem pausa e com a mao liberada para jogar.
func _can_show_ad_popups() -> bool:
	if get_tree().paused:
		return false

	if is_resolving_play or round_controller.finished:
		return false

	if dialogue_box.is_dialogue_active():
		return false

	var cards := hand.get_cards()

	if cards.is_empty():
		return false

	return cards[0].is_interaction_enabled()


func _on_ad_popup_clicked() -> void:
	_show_breach_feedback(
		"Clicar no anúncio abriu mais uma janela. Feche pelo X."
	)


## Na primeira vez que o navegador e sequestrado, o Assistente
## explica as janelas antes de elas aparecerem.
func _show_ad_popups_tutorial(
	opened: Array[SecurityBreachData]
) -> void:
	if ad_popups_tutorial_shown:
		return

	var hijacked := false

	for breach in opened:
		if breach != null and breach.id == AD_POPUPS_BREACH_ID:
			hijacked = true

	if not hijacked:
		return

	ad_popups_tutorial_shown = true

	_hide_card_details()
	hand.set_interaction_enabled(false)
	play_button.disabled = true

	dialogue_box.show_dialogue_data(AD_POPUPS_TUTORIAL)
	await dialogue_box.finished


# --- Chamada entre os antagonistas -----------------------------

func _setup_codec_call() -> void:
	var layer := CanvasLayer.new()
	layer.layer = CODEC_CALL_LAYER
	add_child(layer)

	codec_call = CODEC_CALL_SCRIPT.new()
	layer.add_child(codec_call)
	codec_call.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _play_codec_call(dialogue: DialogueData) -> void:
	_hide_card_details()
	hand.set_interaction_enabled(false)
	play_button.disabled = true

	await codec_call.play(dialogue)

	# A chamada termina com a tela preta. A tela do cenario
	# cobre a partida antes de a chamada sumir.
	_cover_with_black()
	codec_call.hide()


# --- Tela de abertura do cenario ------------------------------

func _setup_scenario_card() -> void:
	var layer := CanvasLayer.new()
	layer.layer = SCENARIO_CARD_LAYER
	add_child(layer)

	scenario_card = ColorRect.new()
	scenario_card.color = Color.BLACK
	scenario_card.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(scenario_card)
	scenario_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# O mesmo fundo da Rede dos dialogos de tela cheia. O
	# shader usa o TIME global, entao a troca entre a tela e o
	# dialogo nao da salto na animacao.
	var backdrop := ColorRect.new()
	backdrop.material = UIPalette.make_network_background_material()
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scenario_card.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scenario_card.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	scenario_card_content = VBoxContainer.new()
	scenario_card_content.add_theme_constant_override("separation", 12)
	scenario_card_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(scenario_card_content)

	scenario_card_counter = Label.new()
	scenario_card_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scenario_card_counter.add_theme_color_override("font_color", UIPalette.TEXT)
	scenario_card_content.add_child(scenario_card_counter)

	scenario_card_title = Label.new()
	scenario_card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scenario_card_title.add_theme_font_size_override(
		"font_size",
		SCENARIO_CARD_TITLE_SIZE
	)
	scenario_card_title.add_theme_color_override("font_color", UIPalette.PRIMARY)
	scenario_card_title.visible_characters_behavior = (
		TextServer.VC_CHARS_AFTER_SHAPING
	)
	scenario_card_content.add_child(scenario_card_title)

	# Linha que cresce a partir do centro, embaixo do titulo.
	var line_holder := CenterContainer.new()
	line_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scenario_card_content.add_child(line_holder)

	scenario_card_line = ColorRect.new()
	scenario_card_line.color = UIPalette.PRIMARY
	scenario_card_line.custom_minimum_size = Vector2(SCENARIO_CARD_LINE_WIDTH, 2.0)
	scenario_card_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line_holder.add_child(scenario_card_line)

	scenario_card_subtitle = Label.new()
	scenario_card_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scenario_card_subtitle.add_theme_color_override("font_color", UIPalette.TEXT)
	scenario_card_content.add_child(scenario_card_subtitle)

	scenario_card.hide()


## Mostra "CENARIO 1 DE 2" e o nome do cenario sobre o preto.
## A tela preta continua visivel no fim: a introducao do
## cenario, que tambem tem fundo preto, entra no lugar dela.
## Sem introducao, o _fade_from_black() seguinte a remove.
func _show_scenario_card() -> void:
	_hide_card_details()
	hand.set_interaction_enabled(false)
	play_button.disabled = true

	var title := current_scenario_data.display_name.to_upper()
	var subtitle := ""

	if not current_scenario_data.rounds.is_empty():
		subtitle = "Ameaça: %s   |   %d rodadas" % [
			current_scenario_data.rounds[0].attack_name.to_upper(),
			current_scenario_data.rounds.size(),
		]

	scenario_card_counter.text = "CENÁRIO %d DE %d" % [
		current_scenario_index + 1,
		scenarios.size(),
	]
	scenario_card_title.text = title
	scenario_card_title.visible_characters = 0
	scenario_card_subtitle.text = subtitle

	scenario_card.modulate.a = 1.0
	scenario_card_content.modulate.a = 1.0
	scenario_card_counter.modulate.a = 0.0
	scenario_card_subtitle.modulate.a = 0.0
	# O CenterContainer reseta a escala dos filhos ao montar
	# o layout, entao a linha cresce pela largura minima.
	scenario_card_line.custom_minimum_size.x = 0.0
	scenario_card.show()

	var tween := create_tween()
	tween.tween_property(scenario_card_counter, "modulate:a", 1.0, 0.25)
	tween.tween_property(
		scenario_card_title,
		"visible_characters",
		title.length(),
		title.length() / SCENARIO_CARD_TYPE_SPEED
	)
	tween.tween_property(
		scenario_card_line,
		"custom_minimum_size:x",
		SCENARIO_CARD_LINE_WIDTH,
		0.3
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(scenario_card_subtitle, "modulate:a", 1.0, 0.3)
	tween.tween_interval(SCENARIO_CARD_HOLD)
	tween.tween_property(
		scenario_card_content,
		"modulate:a",
		0.0,
		SCENARIO_CARD_FADE
	)

	await tween.finished


## Cobre a partida com preto, sem texto.
func _cover_with_black() -> void:
	scenario_card_content.modulate.a = 0.0
	scenario_card.modulate.a = 1.0
	scenario_card.show()


## A partida aparece a partir do preto, depois de um dialogo
## de tela cheia.
func _fade_from_black() -> void:
	if not scenario_card.visible:
		_cover_with_black()

	var tween := create_tween()
	# modulate apaga a tela inteira, fundo da Rede incluido.
	tween.tween_property(
		scenario_card,
		"modulate:a",
		0.0,
		FADE_FROM_BLACK_DURATION
	)
	tween.tween_callback(scenario_card.hide)

	await tween.finished


# --- Faixa de transicao das rodadas --------------------------

func _setup_round_banner() -> void:
	round_banner = Control.new()
	round_banner.z_index = ROUND_BANNER_Z_INDEX
	round_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(round_banner)
	round_banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	round_banner_style = StyleBoxFlat.new()
	round_banner_style.bg_color = Color(UIPalette.PANEL, 0.96)
	round_banner_style.border_width_top = 2
	round_banner_style.border_width_bottom = 2
	round_banner_style.border_color = UIPalette.PRIMARY

	round_banner_band = PanelContainer.new()
	round_banner_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	round_banner_band.add_theme_stylebox_override("panel", round_banner_style)
	round_banner.add_child(round_banner_band)
	round_banner_band.set_anchors_and_offsets_preset(Control.PRESET_HCENTER_WIDE)
	round_banner_band.offset_top = -ROUND_BANNER_HEIGHT / 2.0
	round_banner_band.offset_bottom = ROUND_BANNER_HEIGHT / 2.0

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 6)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	round_banner_band.add_child(content)

	round_banner_title = Label.new()
	round_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_banner_title.add_theme_font_size_override(
		"font_size",
		ROUND_BANNER_TITLE_SIZE
	)
	round_banner_title.visible_characters_behavior = (
		TextServer.VC_CHARS_AFTER_SHAPING
	)
	content.add_child(round_banner_title)

	round_banner_subtitle = Label.new()
	round_banner_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_banner_subtitle.add_theme_color_override("font_color", UIPalette.TEXT)
	content.add_child(round_banner_subtitle)

	round_banner.hide()


## Abre a faixa, digita o titulo, espera e fecha. Aguardar
## esta funcao segura o fluxo da rodada ate a faixa sumir.
func _play_round_banner(
	title: String,
	subtitle: String,
	color: Color
) -> void:
	_hide_card_details()

	round_banner_style.border_color = color
	round_banner_title.add_theme_color_override("font_color", color)
	round_banner_title.text = title
	round_banner_title.visible_characters = 0
	round_banner_subtitle.text = subtitle
	round_banner_subtitle.modulate.a = 0.0

	round_banner_band.pivot_offset = round_banner_band.size / 2.0
	round_banner_band.scale = Vector2(1.0, 0.0)
	round_banner.modulate.a = 1.0
	round_banner.show()

	var type_duration := title.length() / ROUND_BANNER_TYPE_SPEED

	var tween := create_tween()
	tween.tween_property(
		round_banner_band,
		"scale:y",
		1.0,
		ROUND_BANNER_OPEN_DURATION
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		round_banner_title,
		"visible_characters",
		title.length(),
		type_duration
	)
	tween.tween_property(
		round_banner_subtitle,
		"modulate:a",
		1.0,
		0.2
	)
	tween.tween_interval(ROUND_BANNER_HOLD)
	tween.tween_property(
		round_banner_band,
		"scale:y",
		0.0,
		ROUND_BANNER_CLOSE_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(
		round_banner,
		"modulate:a",
		0.0,
		ROUND_BANNER_CLOSE_DURATION
	)
	tween.tween_callback(round_banner.hide)

	await tween.finished


func _show_round_start_banner(is_retry: bool) -> void:
	var title := "RODADA %d/%d" % [
		current_round_index + 1,
		current_scenario_data.rounds.size(),
	]

	var subtitle := "Ameaça: %s   |   Índice de Risco: %.0f" % [
		current_round_data.attack_name.to_upper(),
		round_controller.get_risk(),
	]

	if is_retry:
		subtitle = "Nova tentativa   |   " + subtitle

	await _play_round_banner(title, subtitle, UIPalette.PRIMARY)


func _show_round_result_banner(victory: bool) -> void:
	var subtitle := "Pontuação %.0f   |   Índice de Risco %.0f" % [
		round_controller.score,
		round_controller.get_risk(),
	]

	if victory:
		await _play_round_banner(
			"AMEAÇA CONTIDA",
			subtitle,
			UIPalette.PRIMARY
		)
	else:
		await _play_round_banner(
			"AMEAÇA NÃO CONTIDA",
			subtitle,
			UIPalette.DANGER
		)


func _setup_score_popup() -> void:
	score_popup_root = CenterContainer.new()
	score_popup_root.z_index = SCORE_POPUP_Z_INDEX
	score_popup_root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Ultimo filho da raiz: desenha por cima das cartas e
	# do HUD, mas abaixo dos dialogos, que ficam em
	# CanvasLayers proprios.
	add_child(score_popup_root)
	score_popup_root.hide()

	score_popup = Label.new()
	score_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	score_popup.add_theme_font_size_override(
		"font_size",
		SCORE_POPUP_FONT_SIZE
	)
	score_popup.add_theme_color_override(
		"font_color",
		SCORE_POPUP_COLOR
	)
	score_popup.add_theme_color_override(
		"font_outline_color",
		Color.BLACK
	)
	score_popup.add_theme_constant_override(
		"outline_size",
		SCORE_POPUP_OUTLINE_SIZE
	)
	score_popup_root.add_child(score_popup)

	score_popup_modifier = Label.new()
	score_popup_modifier.mouse_filter = Control.MOUSE_FILTER_IGNORE
	score_popup_modifier.add_theme_font_size_override(
		"font_size",
		SCORE_MODIFIER_FONT_SIZE
	)
	score_popup_modifier.add_theme_color_override(
		"font_outline_color",
		Color.BLACK
	)
	score_popup_modifier.add_theme_constant_override(
		"outline_size",
		SCORE_POPUP_OUTLINE_SIZE
	)

	# Filho do numero, fora do layout do container: fica
	# colado a direita dele sem empurra-lo do centro.
	score_popup.add_child(score_popup_modifier)
	score_popup_modifier.hide()


## Recoloca o container na faixa da conta, sem escala.
## Precisa rodar antes de cada jogada, porque o voo da
## jogada anterior o deixou movido e encolhido.
func _reset_score_popup() -> void:
	score_popup_root.set_anchors_and_offsets_preset(
		Control.PRESET_TOP_WIDE
	)
	score_popup_root.offset_top = SCORE_BAND_TOP
	score_popup_root.offset_bottom = SCORE_BAND_TOP + SCORE_BAND_HEIGHT
	score_popup_root.pivot_offset = score_popup_root.size / 2.0
	score_popup_root.scale = Vector2.ONE
	score_popup_root.modulate.a = 1.0
	score_popup_modifier.hide()


## Primeira fase, ao jogar as cartas: no centro da tela a
## protecao soma, o multiplicador aparece e o resultado
## e calculado.
func _animate_play_score(
	protection: int,
	multiplier: float,
	total: float,
	cards: Array[Card]
) -> void:
	_kill_score_tween()

	score_label.text = ""

	_reset_score_popup()
	score_popup_root.scale = Vector2.ONE * 0.8
	score_popup_root.modulate.a = 0.0
	score_popup.text = "0"
	score_popup_root.show()

	score_tween = create_tween()

	if played_cards_landing_time > 0.0:
		score_tween.tween_interval(played_cards_landing_time)

	score_tween.tween_property(
		score_popup_root,
		"modulate:a",
		1.0,
		SCORE_APPEAR_DURATION
	)
	score_tween.parallel().tween_property(
		score_popup_root,
		"scale",
		Vector2.ONE,
		SCORE_APPEAR_DURATION
	)

	# A Protecao entra carta a carta, da esquerda para a
	# direita, com o sinal de boa pratica ou pratica insegura.
	var running_protection := 0.0

	for card in cards:
		if card == null or card.data == null:
			continue

		var card_protection := float(card.data.protection)

		score_tween.tween_callback(_signal_card_practice.bind(card))
		score_tween.tween_method(
			_show_popup_protection,
			running_protection,
			running_protection + card_protection,
			SCORE_CARD_COUNT_DURATION
		)
		score_tween.tween_interval(SCORE_CARD_GAP)

		running_protection += card_protection

	# Garante o valor exato mesmo se alguma carta foi pulada.
	score_tween.tween_callback(
		_show_popup_protection.bind(float(protection))
	)

	score_tween.tween_method(
		_show_popup_multiplier.bind(protection),
		1.0,
		multiplier,
		SCORE_MULTIPLIER_DURATION
	)

	score_tween.tween_method(
		_show_popup_total,
		float(protection),
		total,
		SCORE_TOTAL_DURATION
	)

	score_tween.tween_property(
		score_popup_root,
		"scale",
		Vector2.ONE * 1.2,
		SCORE_PULSE_DURATION / 2.0
	)
	score_tween.tween_property(
		score_popup_root,
		"scale",
		Vector2.ONE,
		SCORE_PULSE_DURATION / 2.0
	)


## Segunda fase, depois que a jogada e registrada: aplica a
## penalidade das brechas no centro, voa ate a pontuacao da
## rodada e so entao o placar da rodada sobe.
func _animate_play_resolution(
	round_score_before: float,
	round_score_after: float
) -> void:
	var base_score: float = round_controller.last_play_base_score
	var penalty: float = round_controller.last_breach_penalty
	var final_score: float = round_controller.last_play_final_score

	_kill_score_tween()
	score_tween = create_tween()

	if penalty > 0.0 and base_score > 0.0:
		var percent: int = roundi(penalty / base_score * 100.0)

		# Mostra a porcentagem parada antes de descontar.
		score_tween.tween_method(
			_show_popup_penalty.bind(percent),
			base_score,
			base_score,
			SCORE_PENALTY_HOLD
		)
		score_tween.tween_method(
			_show_popup_penalty.bind(percent),
			base_score,
			final_score,
			SCORE_PENALTY_DURATION
		)
		score_tween.tween_callback(
			_show_popup_total.bind(final_score)
		)

	# O centro do container e o centro do numero. Basta levar
	# o centro do container ao centro do placar da rodada.
	var target_center: Vector2 = (
		get_global_transform().affine_inverse()
		* round_score_label.get_global_rect().get_center()
	)

	score_tween.tween_property(
		score_popup_root,
		"position",
		target_center - score_popup_root.size / 2.0,
		SCORE_FLY_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	score_tween.parallel().tween_property(
		score_popup_root,
		"scale",
		Vector2.ONE * SCORE_POPUP_FLY_SCALE,
		SCORE_FLY_DURATION
	)

	score_tween.tween_property(
		score_popup_root,
		"modulate:a",
		0.0,
		SCORE_FADE_DURATION
	)
	score_tween.tween_callback(score_popup_root.hide)

	# Som da soma: os pontos da jogada entram no placar da rodada.
	if round_score_after > round_score_before:
		score_tween.tween_callback(
			_play_sfx.bind(SFX_ROUND_SCORE, SFX_ROUND_SCORE_DB)
		)

	score_tween.tween_method(
		_show_round_score_step,
		round_score_before,
		round_score_after,
		ROUND_SCORE_DURATION
	)


## Sinal visual de cada carta na contagem: tremor, brilho e
## icone subindo. Caveira vermelha para pratica insegura
## (a carta abre brecha), escudo verde para boa pratica.
func _signal_card_practice(card: Card) -> void:
	if not is_instance_valid(card) or card.data == null:
		return

	var insecure: bool = card.data.opens_breach != null
	var color: Color = UIPalette.PRIMARY

	if insecure:
		color = UIPalette.DANGER

	_play_sfx(
		SFX_PRACTICE_BAD if insecure else SFX_PRACTICE_GOOD,
		SFX_PRACTICE_DB
	)

	_shake_card(card, insecure)
	_flash_card_glow(card, color)
	_spawn_practice_float(card, insecure, color)
	_dim_counted_card(card)


func _dim_counted_card(card: Card) -> void:
	var dim := card.create_tween()
	dim.tween_interval(CARD_GLOW_HOLD)
	dim.tween_property(
		card,
		"modulate",
		COUNTED_CARD_COLOR,
		COUNTED_CARD_DIM_DURATION
	)


func _shake_card(card: Card, insecure: bool) -> void:
	var angle := CARD_SHAKE_ANGLE

	if insecure:
		angle = CARD_SHAKE_ANGLE_INSECURE

	card.pivot_offset = card.size / 2.0

	var shake := card.create_tween()
	shake.tween_property(card, "rotation_degrees", -angle, 0.05)
	shake.tween_property(card, "rotation_degrees", angle, 0.08)
	shake.tween_property(card, "rotation_degrees", -angle * 0.5, 0.07)
	shake.tween_property(card, "rotation_degrees", 0.0, 0.06)

	var pop := card.create_tween()
	pop.tween_property(card, "scale", Vector2.ONE * CARD_POP_SCALE, 0.08)
	pop.tween_property(card, "scale", Vector2.ONE, 0.18)


func _flash_card_glow(card: Card, color: Color) -> void:
	# Aneis concentricos por fora da carta, cada um mais
	# transparente que o anterior: um brilho em degraus, no
	# estilo pixel art. Sem preenchimento, entao nada cobre
	# a carta, nem as areas transparentes da ilustracao.
	var glow := Control.new()
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(glow)
	glow.position = Vector2.ZERO
	glow.size = card.size

	for i in range(CARD_GLOW_RINGS.size()):
		var box := StyleBoxFlat.new()
		box.draw_center = false
		box.border_color = Color(color, CARD_GLOW_RINGS[i])
		box.set_border_width_all(CARD_GLOW_RING_WIDTH)
		box.set_expand_margin_all(
			float(CARD_GLOW_RING_WIDTH * (i + 1))
		)
		box.set_corner_radius_all(4 + CARD_GLOW_RING_WIDTH * i)

		var ring := Panel.new()
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.add_theme_stylebox_override("panel", box)
		glow.add_child(ring)
		ring.position = Vector2.ZERO
		ring.size = card.size

	glow.modulate.a = 0.0

	var tween := glow.create_tween()
	tween.tween_property(glow, "modulate:a", 1.0, 0.08)
	tween.tween_interval(CARD_GLOW_HOLD)
	tween.tween_property(glow, "modulate:a", 0.0, CARD_GLOW_FADE)
	tween.tween_callback(glow.queue_free)


## Icone e valor que sobem a partir do meio da carta. Ficam
## dentro da area da carta para nao cobrir a conta no topo.
func _spawn_practice_float(
	card: Card,
	insecure: bool,
	color: Color
) -> void:
	var icon_texture: Texture2D = UIPalette.ICON_SCORE

	if insecure:
		icon_texture = UIPalette.ICON_SKULL

	var float_box := HBoxContainer.new()
	float_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	float_box.add_theme_constant_override("separation", 4)
	float_box.z_index = PRACTICE_FLOAT_Z_INDEX
	float_box.add_child(UIPalette.make_pixel_icon(icon_texture, 32.0))

	var value_label := Label.new()
	value_label.text = "+%d" % card.data.protection
	value_label.add_theme_font_size_override(
		"font_size",
		PRACTICE_FLOAT_FONT_SIZE
	)
	value_label.add_theme_color_override("font_color", color)
	value_label.add_theme_color_override("font_outline_color", Color.BLACK)
	value_label.add_theme_constant_override("outline_size", 8)
	float_box.add_child(value_label)

	played_cards.add_child(float_box)
	float_box.size = float_box.get_combined_minimum_size()

	var start := card.position + Vector2(
		(card.size.x - float_box.size.x) / 2.0,
		card.size.y * 0.35
	)

	float_box.position = start

	var rise := float_box.create_tween()
	rise.tween_property(
		float_box,
		"position:y",
		start.y - PRACTICE_FLOAT_RISE,
		PRACTICE_FLOAT_DURATION
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	var fade := float_box.create_tween()
	fade.tween_interval(PRACTICE_FLOAT_DURATION - PRACTICE_FLOAT_FADE)
	fade.tween_property(float_box, "modulate:a", 0.0, PRACTICE_FLOAT_FADE)
	fade.tween_callback(float_box.queue_free)


func _show_popup_modifier(text: String, color: Color) -> void:
	score_popup_modifier.text = text
	score_popup_modifier.add_theme_color_override("font_color", color)

	var modifier_size: Vector2 = score_popup_modifier.get_minimum_size()
	score_popup_modifier.size = modifier_size

	# O tamanho minimo do numero ja reflete o texto novo,
	# mesmo antes de o container reposiciona-lo.
	var number_size: Vector2 = score_popup.get_minimum_size()

	score_popup_modifier.position = Vector2(
		number_size.x + SCORE_MODIFIER_GAP,
		(number_size.y - modifier_size.y) / 2.0
	)

	score_popup_modifier.show()


# Cada etapa recebe primeiro o valor interpolado pelo
# tween e depois os argumentos fixos passados com bind().

func _show_popup_protection(value: float) -> void:
	score_popup.text = "%d" % roundi(value)
	score_popup_modifier.hide()


func _show_popup_multiplier(value: float, protection: int) -> void:
	score_popup.text = "%d" % protection
	_show_popup_modifier("× %.2f" % value, SCORE_MULTIPLIER_COLOR)


func _show_popup_total(value: float) -> void:
	score_popup.text = "%.2f" % value
	score_popup_modifier.hide()


func _show_popup_penalty(value: float, percent: int) -> void:
	score_popup.text = "%.2f" % value
	_show_popup_modifier("-%d%%" % percent, SCORE_PENALTY_COLOR)


func _show_round_score_step(value: float) -> void:
	round_score_label.text = "Pontuação da rodada: %.0f" % value
	_update_score_bar(value)


func _kill_score_tween() -> void:
	if score_tween != null and score_tween.is_valid():
		score_tween.kill()


func _wait_score_tween() -> void:
	if score_tween != null and score_tween.is_running():
		await score_tween.finished


# --- HUD -----------------------------------------------------

## Monta a coluna do HUD em codigo e move para ela os
## rotulos que ja existem na cena. As referencias @onready
## continuam validas, entao o resto do codigo e os destaques
## do tutorial seguem funcionando sem mudanca.
func _setup_hud() -> void:
	var hud: Control = risk_label.get_parent()

	hud_column = VBoxContainer.new()
	hud_column.position = Vector2(HUD_MARGIN, HUD_COLUMN_TOP)
	hud_column.custom_minimum_size = Vector2(HUD_COLUMN_WIDTH, 0.0)
	hud_column.add_theme_constant_override("separation", 8)
	hud_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hud_column)

	stats_panel = PanelContainer.new()
	stats_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	hud_column.add_child(stats_panel)

	var stats := VBoxContainer.new()
	stats.add_theme_constant_override("separation", 4)
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_panel.add_child(stats)

	_add_hud_row(stats, risk_label, UIPalette.ICON_RISK)
	_add_hud_row(stats, round_score_label, UIPalette.ICON_SCORE)

	score_bar_label = Label.new()
	score_bar_label.add_theme_color_override(
		"font_color",
		UIPalette.PRIMARY
	)

	# Sem icone, mas com o mesmo recuo das outras linhas.
	_add_hud_row(stats, score_bar_label, null)

	_add_hud_row(stats, plays_label, UIPalette.ICON_PLAYS)

	# So aparece no fim da rodada, com o resultado.
	result_label.reparent(stats, false)
	result_label.visible = false

	breaches_panel.reparent(hud_column, false)

	# Uma brecha por linha: com icone, duas lado a lado
	# alargavam o painel ate a mesa. O HBoxContainer da cena
	# nao pode mudar de orientacao, entao e trocado aqui.
	var stacked_list := VBoxContainer.new()
	stacked_list.name = breach_list.name
	stacked_list.add_theme_constant_override("separation", 8)
	stacked_list.mouse_filter = breach_list.mouse_filter
	breach_list.replace_by(stacked_list)
	breach_list.queue_free()
	breach_list = stacked_list

	# Painel de brechas e avisos de brecha em vermelho. Os
	# indicadores e as dicas deles herdam o tema do painel.
	var danger_theme := _build_danger_theme()
	breaches_panel.theme = danger_theme
	breach_feedback.theme = danger_theme

	_update_score_bar(0.0)

	_build_hud_shortcuts(hud)

	# A conta da jogada aparece no centro da tela e o
	# resultado da rodada no painel do HUD. O texto do topo
	# central ficou redundante.
	score_label.visible = false

	attack_label.add_theme_color_override(
		"font_color",
		UIPalette.PRIMARY
	)
	play_button.custom_minimum_size = ACTION_BUTTON_SIZE
	next_round_button.custom_minimum_size = ACTION_BUTTON_SIZE

	resized.connect(_layout_game_ui)
	call_deferred("_layout_game_ui")

	status_cursor_timer = Timer.new()
	status_cursor_timer.wait_time = STATUS_CURSOR_BLINK
	status_cursor_timer.autostart = true
	status_cursor_timer.timeout.connect(_on_status_cursor_timeout)
	add_child(status_cursor_timer)


## Barra de texto da pontuacao ate o Indice de Risco, no
## formato [#####···············]  25%.
func _update_score_bar(score: float) -> void:
	if score_bar_label == null:
		return

	var risk: float = round_controller.get_risk()
	var ratio := 0.0

	if risk > 0.0:
		ratio = clampf(score / risk, 0.0, 1.0)

	var filled: int = roundi(ratio * SCORE_BAR_LENGTH)

	score_bar_label.text = "[%s%s] %3d%%" % [
		"#".repeat(filled),
		"·".repeat(SCORE_BAR_LENGTH - filled),
		roundi(ratio * 100.0)
	]



func _refresh_attack_label() -> void:
	# "_" e " " tem a mesma largura na fonte monoespacada,
	# entao piscar o cursor nao desloca o texto.
	var cursor := "_" if status_cursor_on else " "
	attack_label.text = attack_status_text + cursor
	attack_label.size = attack_label.get_minimum_size()


## Reposiciona os elementos que dependem da largura da
## janela. Roda no inicio e a cada redimensionamento.
## Coloca o rotulo em uma linha com o icone a esquerda.
## Sem icone, deixa um espaco vazio do mesmo tamanho, para
## o texto ficar alinhado com as outras linhas.
func _add_hud_row(
	parent: Container,
	label: Label,
	icon: Texture2D
) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(
		"separation",
		HUD_ICON_SEPARATION
	)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)

	if icon != null:
		row.add_child(UIPalette.make_pixel_icon(icon, HUD_ICON_SIZE))
	else:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(HUD_ICON_SIZE, 0.0)
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(spacer)

	if label.get_parent() == null:
		row.add_child(label)
	else:
		label.reparent(row, false)

	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER


## Botoes de icone para abrir a enciclopedia e a ajuda sem
## precisar saber do Esc.
func _build_hud_shortcuts(hud: Control) -> void:
	hud_shortcuts = HBoxContainer.new()
	hud_shortcuts.add_theme_constant_override("separation", 8)
	hud.add_child(hud_shortcuts)

	hud_shortcuts.add_child(
		_build_hud_shortcut(
			UIPalette.ICON_HELP,
			"Como jogar",
			_on_hud_help_pressed
		)
	)
	hud_shortcuts.add_child(
		_build_hud_shortcut(
			UIPalette.ICON_ENCYCLOPEDIA,
			"Enciclopédia",
			_on_hud_encyclopedia_pressed
		)
	)


func _build_hud_shortcut(
	icon: Texture2D,
	tooltip: String,
	handler: Callable
) -> Button:
	var button := Button.new()
	button.icon = icon
	button.tooltip_text = tooltip
	button.custom_minimum_size = HUD_SHORTCUT_SIZE
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Sem foco: senao o Enter usado para avancar os
	# dialogos acionaria o ultimo botao clicado.
	button.focus_mode = Control.FOCUS_NONE

	button.pressed.connect(handler)
	return button


func _layout_game_ui() -> void:
	# Linha de status alinhada com a coluna do HUD.
	attack_label.position = Vector2(HUD_MARGIN, HUD_MARGIN)
	attack_label.size = attack_label.get_minimum_size()

	# Mesa centralizada na largura real da janela. As cartas
	# sao distribuidas em torno deste ponto.
	played_cards.global_position = Vector2(
		size.x / 2.0 - TABLE_CARD_HALF_WIDTH,
		TABLE_TOP
	)

	# Jogar e Proxima rodada no mesmo lugar, a direita da
	# mesa: um aparece durante a rodada, o outro no fim.
	var action_position := Vector2(
		size.x - ACTION_BUTTON_MARGIN - ACTION_BUTTON_SIZE.x,
		TABLE_TOP
			+ TABLE_CARD_HEIGHT / 2.0
			- ACTION_BUTTON_SIZE.y / 2.0
	)

	for button: Button in [play_button, next_round_button]:
		button.size = ACTION_BUTTON_SIZE
		button.global_position = action_position

	# Atalhos no canto superior direito.
	if hud_shortcuts != null:
		hud_shortcuts.size = hud_shortcuts.get_combined_minimum_size()
		hud_shortcuts.position = Vector2(
			size.x - HUD_MARGIN - hud_shortcuts.size.x,
			HUD_MARGIN
		)


func _on_status_cursor_timeout() -> void:
	status_cursor_on = not status_cursor_on
	_refresh_attack_label()


## Tema vermelho para o que envolve brechas. So redefine
## painel, texto e dica de ferramenta; fonte e o resto vem
## do tema global.
func _build_danger_theme() -> Theme:
	var danger := Theme.new()

	danger.set_stylebox(
		"panel",
		"PanelContainer",
		_make_danger_box(UIPalette.DANGER_BACKGROUND, UIPalette.DANGER_DIM, 8.0)
	)
	danger.set_stylebox(
		"panel",
		"TooltipPanel",
		_make_danger_box(UIPalette.BACKGROUND, UIPalette.DANGER, 10.0)
	)
	danger.set_color("font_color", "Label", UIPalette.DANGER)
	danger.set_color("font_color", "TooltipLabel", UIPalette.DANGER)

	return danger


func _make_danger_box(
	background: Color,
	border: Color,
	margin: float
) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(1)
	box.set_content_margin_all(margin)

	return box


# --- Fundo -------------------------------------------------

func _setup_background() -> void:
	var background := get_node_or_null("ColorRect") as ColorRect

	if background != null:
		# Na cena o ColorRect tem tamanho fixo de 1152x648.
		# Ancorado na tela toda, acompanha o redimensionamento.
		background.set_anchors_and_offsets_preset(
			Control.PRESET_FULL_RECT
		)
		background.color = UIPalette.BACKGROUND
		background.material = UIPalette.make_background_material()

	if not CRT_OVERLAY_ENABLED:
		return

	var overlay_layer := CanvasLayer.new()
	overlay_layer.layer = CRT_OVERLAY_LAYER
	add_child(overlay_layer)

	var overlay := ColorRect.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.material = UIPalette.make_crt_overlay_material()
	overlay_layer.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
