extends Control

## Cena inicial do jogo. Da acesso a partida e a
## enciclopedia, que aqui e aberta como sobreposicao.

const GAME_SCENE_PATH := "res://scenes/gameplay/Game.tscn"

const ENCYCLOPEDIA_SCENE := preload(
	"res://scenes/encyclopedia/Encyclopedia.tscn"
)

## Sem class_name, por isso carregado como script.
const HELP_SCREEN_SCRIPT := preload(
	"res://scenes/menus/HelpScreen.gd"
)
const OPTIONS_SCREEN_SCRIPT := preload(
	"res://scenes/menus/OptionsScreen.gd"
)

## Logo com o titulo do jogo, no topo do menu.
const TITLE_LOGO: Texture2D = preload("res://assets/logo/logo_completa.png")
const TITLE_LOGO_WIDTH := 560.0

## A logo flutua devagar, subindo e descendo alguns pixels.
const TITLE_BOB_HEIGHT := 4.0
const TITLE_BOB_DURATION := 1.4

## Botao de icone no canto inferior direito (so depuracao).
const CORNER_BUTTON_SIZE := Vector2(44.0, 44.0)
const CORNER_MARGIN := 16.0

const PANEL_WIDTH := 320.0
const BUTTON_HEIGHT := 44.0

## Janela do nome, aberta ao apertar Jogar (so depuracao).
const NAME_PROMPT_WIDTH := 460.0
const NAME_MAX_LENGTH := 40
const NAME_HELP_TEXT := (
	"O nome identifica o registro desta partida na avaliação do "
	+ "TCC. O registro fica salvo apenas neste computador, com as "
	+ "suas jogadas e respostas, e não aparece durante o jogo."
)

## Menu de desenvolvedor: atalhos para comecar em qualquer
## ponto de qualquer cenario (so depuracao).
const DEV_OPTIONS := preload("res://globals/DevOptions.gd")

## Escolha de dificuldade, depois do nome e antes da partida.
const DIFFICULTY := preload("res://globals/Difficulty.gd")
const DIFFICULTY_PANEL_WIDTH := 600.0
const DIFFICULTY_OPTION_HEIGHT := 52.0
const DIFFICULTY_INFO_HEIGHT := 192.0

## Largura do texto dentro da area de descricao: a janela
## menos as margens do painel (24 de cada lado) e da area
## (14 de cada lado, mais a borda).
const DIFFICULTY_INFO_TEXT_WIDTH := (
	DIFFICULTY_PANEL_WIDTH - 24.0 * 2.0 - 15.0 * 2.0
)
const DEV_SESSION_CODE := "dev"
const OVERLAY_DIM := Color(0.0, 0.0, 0.0, 0.7)

## Invasao da E.V.E: de tempos em tempos a logo falha e vira
## "INVADIDO POR E.V.E", e o menu inteiro fica vermelho.
## O fundo muda de cor devagar, sem piscar, para nao incomodar
## quem e sensivel a luz piscando. So a logo tremula rapido.
const INVASION_ENABLED := true
const INVADED_LOGO: Texture2D = preload("res://assets/logo/logo_invadida.png")
const LOGO_GLITCH_SHADER := preload("res://assets/shaders/logo_glitch.gdshader")
const INVASION_STATIC: AudioStream = preload("res://assets/audio/codec_static.wav")
const INVASION_FIRST_DELAY := 2.5
const INVASION_INTERVAL_MIN := 7.0
const INVASION_INTERVAL_MAX := 13.0
const INVASION_HOLD := 1.1
const INVASION_COLOR_FADE := 0.3
const INVASION_STATIC_VOLUME_DB := -20.0
const INVADED_SUBTITLE := "Você está sendo observado."
const INVADED_BASE := Color(0.06, 0.01, 0.015)

var _encyclopedia: Encyclopedia
var _background_material: ShaderMaterial
var _logo_material: ShaderMaterial
var _column: VBoxContainer
var _subtitle_label: Label
var _subtitle_text := ""
var _invaded_theme: Theme
var _invasion_timer: Timer
var _invasion_player: AudioStreamPlayer
var _corner_button: Button

## Botoes com caixas proprias (os que tem icone): o tema nao
## chega neles, entao as versoes vermelhas sao trocadas uma a
## uma. Cada item: [botao, estado, caixa normal, caixa vermelha].
var _override_swaps: Array = []
var _help_screen: Control
var _options_screen: Control
var _participant_code_input: LineEdit
var _name_prompt: Control
var _difficulty_menu: Control
var _difficulty_options: Array[Button] = []
var _difficulty_info_title: Label
var _difficulty_info_text: Label
var _difficulty_info_rules: Label
var _difficulty_start: Button
var _selected_difficulty: DifficultyData
var _dev_difficulty: OptionButton

## Nome digitado, guardado enquanto a dificuldade e escolhida.
var _pending_name := ""
var _dev_menu: Control
var _dev_button: Button
var _dev_skip_intro: CheckBox
var _dev_open_breaches: CheckBox


func _ready() -> void:
	_build_interface()

	if INVASION_ENABLED:
		_setup_invasion()


func _build_interface() -> void:
	var background := ColorRect.new()
	add_child(background)
	background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	background.color = UIPalette.BACKGROUND
	_background_material = UIPalette.make_background_material()
	background.material = _background_material

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	# Coluna externa: a logo, mais larga, fica aqui. A
	# coluna dos botoes vem dentro dela com a largura dela.
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	center.add_child(column)
	_column = column

	var logo_size := Vector2(
		TITLE_LOGO_WIDTH,
		TITLE_LOGO_WIDTH * TITLE_LOGO.get_height() / TITLE_LOGO.get_width()
	)

	# A moldura ocupa o espaco no layout; a logo se move
	# dentro dela, entao a animacao nao mexe nos botoes.
	var logo_frame := Control.new()
	logo_frame.custom_minimum_size = logo_size
	logo_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	logo_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(logo_frame)

	var title_logo := TextureRect.new()
	title_logo.texture = TITLE_LOGO
	title_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title_logo.size = logo_size
	title_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo_material = ShaderMaterial.new()
	_logo_material.shader = LOGO_GLITCH_SHADER
	_logo_material.set_shader_parameter("alt_texture", INVADED_LOGO)
	title_logo.material = _logo_material
	logo_frame.add_child(title_logo)

	_start_logo_bob(title_logo)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_theme_constant_override("separation", 16)
	column.add_child(box)

	var subtitle_label := Label.new()
	subtitle_label.text = (
		"Um jogo sobre decisões de segurança digital"
	)
	subtitle_label.add_theme_font_size_override("font_size", 16)
	subtitle_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(subtitle_label)
	_subtitle_label = subtitle_label
	_subtitle_text = subtitle_label.text

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 16.0)
	box.add_child(spacer)

	box.add_child(_build_button("Jogar", _on_play_pressed))

	box.add_child(
		_build_button(
			"Como jogar",
			_on_help_pressed,
			UIPalette.ICON_HELP
		)
	)

	box.add_child(
		_build_button(
			"Enciclopédia",
			_on_encyclopedia_pressed,
			UIPalette.ICON_ENCYCLOPEDIA
		)
	)

	box.add_child(
		_build_button(
			"Opções",
			_on_options_pressed,
			UIPalette.ICON_OPTIONS
		)
	)

	# Ferramentas da avaliacao: so em build de depuracao.
	if OS.is_debug_build():
		_build_sessions_corner_button()
		_build_dev_corner_button()

	# No navegador nao existe "sair", a aba e que fecha.
	if not OS.has_feature("web"):
		box.add_child(_build_button("Sair", _on_quit_pressed))

	_encyclopedia = (
		ENCYCLOPEDIA_SCENE.instantiate()
		as Encyclopedia
	)
	add_child(_encyclopedia)
	_encyclopedia.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	_encyclopedia.closed.connect(_on_encyclopedia_closed)
	_encyclopedia.hide()

	_help_screen = HELP_SCREEN_SCRIPT.new()
	add_child(_help_screen)
	_help_screen.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	_help_screen.closed.connect(_on_help_closed)

	_options_screen = OPTIONS_SCREEN_SCRIPT.new()
	add_child(_options_screen)
	_options_screen.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	_options_screen.closed.connect(_options_screen.hide)

	_difficulty_menu = _build_difficulty_menu()
	add_child(_difficulty_menu)

	if OS.is_debug_build():
		_name_prompt = _build_name_prompt()
		add_child(_name_prompt)
		_dev_menu = _build_dev_menu()
		add_child(_dev_menu)


# --- Invasao da E.V.E ----------------------------------------

func _setup_invasion() -> void:
	_invaded_theme = _build_invaded_theme()

	for node in _column.find_children("*", "Button", true, false):
		var button := node as Button
		for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			if button.has_theme_stylebox_override(state):
				var original := button.get_theme_stylebox(state)
				var red := _recolor(original, state)
				if red != null:
					_override_swaps.append([button, state, original, red])

	# Valores iniciais explicitos: o tween precisa de um valor
	# de partida, e o shader so devolve os que foram definidos.
	_background_material.set_shader_parameter("glow_color", UIPalette.PRIMARY)
	_background_material.set_shader_parameter("base_color", UIPalette.BACKGROUND)
	_logo_material.set_shader_parameter("glitch", 0.0)
	_logo_material.set_shader_parameter("invaded", 0.0)

	_invasion_player = AudioStreamPlayer.new()
	_invasion_player.stream = INVASION_STATIC
	_invasion_player.volume_db = INVASION_STATIC_VOLUME_DB
	add_child(_invasion_player)

	_invasion_timer = Timer.new()
	_invasion_timer.one_shot = true
	_invasion_timer.timeout.connect(_play_invasion)
	add_child(_invasion_timer)
	_invasion_timer.start(INVASION_FIRST_DELAY)

	# O subtitulo normal ocupa duas linhas e o da invasao uma.
	# Fixar a altura evita que os botoes pulem na troca.
	await get_tree().process_frame
	_subtitle_label.custom_minimum_size.y = _subtitle_label.size.y


## Uma falha: a logo treme, vira a invadida, o menu fica
## vermelho por um instante e tudo volta ao normal.
func _play_invasion() -> void:
	# Com a enciclopedia ou a ajuda abertas, espera a proxima.
	if _encyclopedia.visible or _help_screen.visible:
		_schedule_next_invasion()
		return

	_invasion_player.play()

	var logo := _logo_material
	var background := _background_material
	var tween := create_tween()

	# Entrada: a logo falha e a invadida toma o lugar.
	tween.tween_property(logo, "shader_parameter/glitch", 1.0, 0.12)
	tween.tween_callback(_set_invaded.bind(true))
	tween.tween_property(logo, "shader_parameter/glitch", 0.35, 0.2)
	tween.parallel().tween_property(
		background, "shader_parameter/glow_color", UIPalette.DANGER, INVASION_COLOR_FADE
	)
	tween.parallel().tween_property(
		background, "shader_parameter/base_color", INVADED_BASE, INVASION_COLOR_FADE
	)

	# Um soluco no meio, para lembrar que e uma falha.
	tween.tween_interval(INVASION_HOLD * 0.5)
	tween.tween_property(logo, "shader_parameter/glitch", 0.9, 0.08)
	tween.tween_property(logo, "shader_parameter/glitch", 0.3, 0.12)
	tween.tween_interval(INVASION_HOLD * 0.5)

	# Saida: volta a logo normal e as cores de terminal.
	tween.tween_property(logo, "shader_parameter/glitch", 1.0, 0.1)
	tween.tween_callback(_set_invaded.bind(false))
	tween.tween_property(logo, "shader_parameter/glitch", 0.0, 0.25)
	tween.parallel().tween_property(
		background, "shader_parameter/glow_color", UIPalette.PRIMARY, INVASION_COLOR_FADE
	)
	tween.parallel().tween_property(
		background, "shader_parameter/base_color", UIPalette.BACKGROUND, INVASION_COLOR_FADE
	)
	tween.tween_callback(_schedule_next_invasion)


func _schedule_next_invasion() -> void:
	_invasion_timer.start(randf_range(INVASION_INTERVAL_MIN, INVASION_INTERVAL_MAX))


func _set_invaded(on: bool) -> void:
	_logo_material.set_shader_parameter("invaded", 1.0 if on else 0.0)
	_column.theme = _invaded_theme if on else null

	if _corner_button != null:
		_corner_button.theme = _invaded_theme if on else null

	if _dev_button != null:
		_dev_button.theme = _invaded_theme if on else null

	for swap: Array in _override_swaps:
		var button: Button = swap[0]
		button.add_theme_stylebox_override(swap[1], swap[3] if on else swap[2])
	_subtitle_label.text = INVADED_SUBTITLE if on else _subtitle_text


## Tema vermelho para os botoes, o campo de texto e os textos
## do menu durante a invasao. Copia as caixas do tema atual e
## troca so as cores, para nada mudar de tamanho.
func _build_invaded_theme() -> Theme:
	var theme := Theme.new()
	var sample_button := Button.new()
	var sample_field := LineEdit.new()
	add_child(sample_button)
	add_child(sample_field)

	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := _recolor(sample_button.get_theme_stylebox(state, "Button"), state)
		if box != null:
			theme.set_stylebox(state, "Button", box)

	for state: String in ["normal", "focus"]:
		var box := _recolor(sample_field.get_theme_stylebox(state, "LineEdit"), state)
		if box != null:
			theme.set_stylebox(state, "LineEdit", box)

	sample_button.queue_free()
	sample_field.queue_free()

	for color_name: String in [
		"font_color", "font_hover_color", "font_pressed_color", "font_focus_color"
	]:
		theme.set_color(color_name, "Button", UIPalette.DANGER)
	theme.set_color("font_color", "LineEdit", UIPalette.DANGER)
	theme.set_color("font_placeholder_color", "LineEdit", UIPalette.DANGER_DIM)
	theme.set_color("font_color", "Label", UIPalette.DANGER)

	return theme


func _recolor(source: StyleBox, state: String) -> StyleBox:
	if not source is StyleBoxFlat:
		return null

	var box := source.duplicate() as StyleBoxFlat
	var strong := state == "hover" or state == "pressed" or state == "focus"
	box.border_color = UIPalette.DANGER if strong else UIPalette.DANGER_DIM

	if box.draw_center:
		var tint := 0.2 if state == "pressed" else (0.14 if state == "hover" else 0.08)
		box.bg_color = Color(tint, tint * 0.15, tint * 0.2, box.bg_color.a)

	return box


## Sobe e desce em loop, com curva senoidal.
func _start_logo_bob(logo: Control) -> void:
	var tween := logo.create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(
		logo,
		"position:y",
		-TITLE_BOB_HEIGHT,
		TITLE_BOB_DURATION
	)
	tween.tween_property(
		logo,
		"position:y",
		0.0,
		TITLE_BOB_DURATION
	)


## Atalho para a pasta dos registros das sessoes. Fica no
## canto, fora da coluna principal, porque so serve para
## quem aplica a avaliacao.
func _build_sessions_corner_button() -> void:
	var button := Button.new()
	_corner_button = button
	button.icon = UIPalette.ICON_FOLDER
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.tooltip_text = "Abrir pasta das sessões"
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_on_open_sessions_pressed)
	add_child(button)

	button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	button.offset_left = -CORNER_MARGIN - CORNER_BUTTON_SIZE.x
	button.offset_top = -CORNER_MARGIN - CORNER_BUTTON_SIZE.y
	button.offset_right = -CORNER_MARGIN
	button.offset_bottom = -CORNER_MARGIN

	# Se o tema deixar o botao maior que CORNER_BUTTON_SIZE,
	# ele cresce para dentro da tela e a margem se mantem.
	button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	button.grow_vertical = Control.GROW_DIRECTION_BEGIN


func _build_button(
	text: String,
	handler: Callable,
	icon: Texture2D = null
) -> Button:
	var button := Button.new()
	button.text = text

	if icon != null:
		UIPalette.set_button_icon(button, icon)

	button.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	button.pressed.connect(handler)

	return button


func _on_play_pressed() -> void:
	# Na build final nao ha registro de participante: Jogar
	# vai direto para a dificuldade.
	if _name_prompt == null:
		_pending_name = ""
		_open_difficulty_menu()
		return

	_participant_code_input.clear()
	_name_prompt.show()
	_participant_code_input.grab_focus()


func _on_name_confirmed() -> void:
	_pending_name = _participant_code_input.text
	_name_prompt.hide()
	_open_difficulty_menu()


func _start_game(participant_code: String) -> void:
	SessionLogger.start_session(participant_code)
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


## Esc fecha a janela aberta por cima do menu.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return

	if _difficulty_menu.visible:
		_on_difficulty_back()
		get_viewport().set_input_as_handled()
		return

	for overlay: Control in [_name_prompt, _dev_menu]:
		if overlay != null and overlay.visible:
			overlay.hide()
			get_viewport().set_input_as_handled()
			return


# --- Dificuldade ----------------------------------------------

func _build_difficulty_menu() -> Control:
	var parts := _build_overlay(DIFFICULTY_PANEL_WIDTH)
	var overlay: Control = parts[0]
	var content: VBoxContainer = parts[1]

	content.add_child(_make_overlay_title("Escolha a dificuldade"))

	# Um botao por nivel, com o icone de patente na frente. O
	# grupo deixa so um marcado por vez.
	var group := ButtonGroup.new()
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	content.add_child(list)

	for option: DifficultyData in DIFFICULTY.OPTIONS:
		var button := Button.new()
		button.text = option.display_name
		button.toggle_mode = true
		button.button_group = group
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0.0, DIFFICULTY_OPTION_HEIGHT)
		button.add_theme_font_size_override("font_size", 18)
		button.set_meta("difficulty", option)

		_style_difficulty_button(button)

		if option.icon != null:
			UIPalette.set_button_icon(button, option.icon)
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT

		# Com o mouse em cima do nivel marcado, mantem a caixa
		# marcada (ja com a folga do icone).
		button.add_theme_stylebox_override(
			"hover_pressed", button.get_theme_stylebox("pressed")
		)

		button.pressed.connect(_on_difficulty_chosen.bind(option))
		button.mouse_entered.connect(_show_difficulty_info.bind(option))
		button.focus_entered.connect(_show_difficulty_info.bind(option))
		button.mouse_exited.connect(_show_difficulty_info.bind(null))
		list.add_child(button)
		_difficulty_options.append(button)

	# Area de descricao, embaixo da lista. A altura e fixa para
	# a janela nao mudar de tamanho de um nivel para outro.
	var info_panel := PanelContainer.new()
	info_panel.custom_minimum_size = Vector2(0.0, DIFFICULTY_INFO_HEIGHT)
	var info_style := StyleBoxFlat.new()
	info_style.bg_color = UIPalette.BACKGROUND
	info_style.border_color = UIPalette.DIM
	info_style.set_border_width_all(1)
	info_style.set_content_margin_all(14)
	info_panel.add_theme_stylebox_override("panel", info_style)
	content.add_child(info_panel)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 6)
	info_panel.add_child(info)

	_difficulty_info_title = Label.new()
	_difficulty_info_title.add_theme_font_override("font", UIPalette.TEXT_FONT_BOLD)
	_difficulty_info_title.add_theme_font_size_override("font_size", 17)
	_difficulty_info_title.add_theme_color_override("font_color", UIPalette.PRIMARY)
	info.add_child(_difficulty_info_title)

	# Texto com quebra de linha precisa de largura fixa. Sem ela,
	# no primeiro frame depois de trocar o texto o Label calcula
	# a altura com largura quase zero, fica altissimo e estica
	# a janela por um instante.
	_difficulty_info_text = Label.new()
	_difficulty_info_text.custom_minimum_size.x = DIFFICULTY_INFO_TEXT_WIDTH
	_difficulty_info_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_difficulty_info_text.add_theme_font_size_override("font_size", 15)
	_difficulty_info_text.add_theme_color_override("font_color", UIPalette.TEXT)
	info.add_child(_difficulty_info_text)

	_difficulty_info_rules = Label.new()
	_difficulty_info_rules.custom_minimum_size.x = DIFFICULTY_INFO_TEXT_WIDTH
	_difficulty_info_rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_difficulty_info_rules.add_theme_font_size_override("font_size", 13)
	_difficulty_info_rules.add_theme_color_override(
		"font_color", UIPalette.TEXT.darkened(0.3)
	)
	info.add_child(_difficulty_info_rules)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	content.add_child(buttons)

	var back := _build_button("Voltar", _on_difficulty_back)
	back.custom_minimum_size.x = 120.0
	buttons.add_child(back)

	_difficulty_start = _build_button("Começar", _on_difficulty_confirmed)
	_difficulty_start.custom_minimum_size.x = 140.0
	buttons.add_child(_difficulty_start)

	return overlay


## O tema pinta o botao marcado de verde cheio, e o icone
## verde do Iniciante sumiria nele. O marcado fica com fundo
## escuro destacado e borda cheia, e os icones mantem a cor.
func _style_difficulty_button(button: Button) -> void:
	button.add_theme_constant_override("h_separation", 14)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = UIPalette.HOVER
	pressed.border_color = UIPalette.PRIMARY
	pressed.set_border_width_all(2)
	pressed.content_margin_left = 16
	pressed.content_margin_right = 16
	button.add_theme_stylebox_override("pressed", pressed)

	for state in ["normal", "hover", "focus"]:
		var box := button.get_theme_stylebox(state).duplicate()
		box.content_margin_left = 16
		box.content_margin_right = 16
		button.add_theme_stylebox_override(state, box)

	button.add_theme_color_override("font_pressed_color", UIPalette.PRIMARY)
	button.add_theme_color_override("font_hover_pressed_color", UIPalette.PRIMARY)

	for color_name in [
		"icon_normal_color", "icon_hover_color", "icon_pressed_color",
		"icon_hover_pressed_color", "icon_focus_color",
	]:
		button.add_theme_color_override(color_name, Color.WHITE)


func _open_difficulty_menu() -> void:
	_selected_difficulty = null
	_difficulty_start.disabled = true

	for button in _difficulty_options:
		button.set_pressed_no_signal(false)

	_show_difficulty_info(null)

	# Nenhum nivel comeca marcado nem com foco, para a escolha
	# nao ser puxada para o primeiro da lista.
	_difficulty_menu.show()


func _on_difficulty_chosen(option: DifficultyData) -> void:
	_selected_difficulty = option
	_difficulty_start.disabled = false
	_show_difficulty_info(option)


## Mostra a descricao do nivel sob o mouse. Sem nenhum sob o
## mouse, volta para o nivel marcado, ou para a instrucao.
func _show_difficulty_info(option: DifficultyData) -> void:
	if option == null:
		option = _selected_difficulty

	_difficulty_info_title.visible = option != null

	if option == null:
		_difficulty_info_title.text = ""
		_difficulty_info_text.text = (
			"Passe o mouse sobre uma dificuldade para ver para "
			+ "quem ela é recomendada."
		)
		_difficulty_info_rules.text = ""
		return

	_difficulty_info_title.text = option.display_name
	_difficulty_info_text.text = option.description
	_difficulty_info_rules.text = option.rules_text


func _on_difficulty_back() -> void:
	_difficulty_menu.hide()

	# Volta para o nome, que continua preenchido.
	if _name_prompt != null:
		_name_prompt.show()
		_participant_code_input.grab_focus()


func _on_difficulty_confirmed() -> void:
	if _selected_difficulty == null:
		return

	DIFFICULTY.select(_selected_difficulty)
	_start_game(_pending_name)


# --- Janelas por cima do menu ---------------------------------

## Fundo escurecido que bloqueia o menu, com um painel no meio.
## Devolve [camada, conteudo do painel].
func _build_overlay(panel_width: float) -> Array:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.hide()

	var dim := ColorRect.new()
	dim.color = OVERLAY_DIM
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(panel_width, 0.0)
	var style := StyleBoxFlat.new()
	style.bg_color = UIPalette.PANEL
	style.border_color = UIPalette.DIM
	style.set_border_width_all(2)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)

	return [overlay, content]


func _make_overlay_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", UIPalette.PRIMARY)
	return label


func _make_overlay_note(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", UIPalette.TEXT.darkened(0.15))
	return label


## O tema pinta a caixa marcada de verde cheio, e o texto
## claro some em cima dela. Aqui so o quadradinho muda.
func _style_checkbox(box: CheckBox) -> void:
	for state in ["normal", "pressed", "hover", "hover_pressed", "focus"]:
		box.add_theme_stylebox_override(state, StyleBoxEmpty.new())

	box.add_theme_color_override("font_color", UIPalette.TEXT)
	box.add_theme_color_override("font_pressed_color", UIPalette.TEXT)
	box.add_theme_color_override("font_hover_color", UIPalette.PRIMARY)
	box.add_theme_color_override("font_hover_pressed_color", UIPalette.PRIMARY)
	box.focus_mode = Control.FOCUS_NONE


func _build_name_prompt() -> Control:
	var parts := _build_overlay(NAME_PROMPT_WIDTH)
	var overlay: Control = parts[0]
	var content: VBoxContainer = parts[1]

	content.add_child(_make_overlay_title("Antes de começar"))

	var field_label := Label.new()
	field_label.text = "Nome"
	content.add_child(field_label)

	_participant_code_input = LineEdit.new()
	_participant_code_input.placeholder_text = "Digite o seu nome"
	_participant_code_input.max_length = NAME_MAX_LENGTH
	_participant_code_input.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	_participant_code_input.text_submitted.connect(
		func(_text: String) -> void: _on_name_confirmed()
	)
	content.add_child(_participant_code_input)

	# Explicacao logo abaixo do campo.
	content.add_child(_make_overlay_note(NAME_HELP_TEXT))

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	content.add_child(buttons)

	var back := _build_button("Voltar", overlay.hide)
	back.custom_minimum_size.x = 120.0
	buttons.add_child(back)

	var start := _build_button("Começar", _on_name_confirmed)
	start.custom_minimum_size.x = 140.0
	buttons.add_child(start)

	return overlay


func _build_dev_corner_button() -> void:
	var button := Button.new()
	_dev_button = button
	button.icon = UIPalette.ICON_DEV
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.tooltip_text = "Menu de desenvolvedor"
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: _dev_menu.show())
	add_child(button)

	button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	button.offset_left = CORNER_MARGIN
	button.offset_top = -CORNER_MARGIN - CORNER_BUTTON_SIZE.y
	button.offset_right = CORNER_MARGIN + CORNER_BUTTON_SIZE.x
	button.offset_bottom = -CORNER_MARGIN
	button.grow_vertical = Control.GROW_DIRECTION_BEGIN


func _build_dev_menu() -> Control:
	var parts := _build_overlay(0.0)
	var overlay: Control = parts[0]
	var content: VBoxContainer = parts[1]

	content.add_child(_make_overlay_title("Menu de desenvolvedor"))
	content.add_child(_make_overlay_note(
		"Começa a partida direto no ponto escolhido. As partidas "
		+ "abertas aqui ficam registradas com o nome \"%s\"."
		% DEV_SESSION_CODE
	))

	# A lista vem do Game, para o menu acompanhar cenarios novos.
	var scenario_list: Array = load(
		"res://scenes/gameplay/Game.gd"
	).SCENARIO_LIST

	var grid := GridContainer.new()
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	content.add_child(grid)

	var max_rounds := 0

	for scenario: ScenarioData in scenario_list:
		max_rounds = maxi(max_rounds, scenario.rounds.size())

	# Colunas: nome, introducao, uma por rodada e o chefe.
	grid.columns = max_rounds + 3

	for i in range(scenario_list.size()):
		var scenario: ScenarioData = scenario_list[i]

		var name_label := Label.new()
		name_label.text = "%d. %s" % [i + 1, scenario.display_name]
		name_label.custom_minimum_size.x = 200.0
		grid.add_child(name_label)

		grid.add_child(_build_dev_button(
			"Introdução", i, DEV_OPTIONS.START_INTRO, 0
		))

		for r in range(max_rounds):
			if r < scenario.rounds.size():
				grid.add_child(_build_dev_button(
					"Rodada %d" % (r + 1), i, DEV_OPTIONS.START_ROUND, r
				))
			else:
				grid.add_child(Control.new())

		var boss_button := _build_dev_button(
			"Chefe", i, DEV_OPTIONS.START_BOSS, 0
		)
		boss_button.disabled = scenario.boss == null
		grid.add_child(boss_button)

	_dev_skip_intro = CheckBox.new()
	_dev_skip_intro.text = "Pular a apresentação do Assistente"
	_dev_skip_intro.button_pressed = true
	_style_checkbox(_dev_skip_intro)
	content.add_child(_dev_skip_intro)

	_dev_open_breaches = CheckBox.new()
	_dev_open_breaches.text = (
		"Começar com as brechas do cenário abertas"
	)
	_style_checkbox(_dev_open_breaches)
	content.add_child(_dev_open_breaches)

	var difficulty_row := HBoxContainer.new()
	difficulty_row.add_theme_constant_override("separation", 12)
	content.add_child(difficulty_row)

	var difficulty_label := Label.new()
	difficulty_label.text = "Dificuldade"
	difficulty_row.add_child(difficulty_label)

	_dev_difficulty = OptionButton.new()
	_dev_difficulty.focus_mode = Control.FOCUS_NONE

	for option: DifficultyData in DIFFICULTY.OPTIONS:
		_dev_difficulty.add_item(option.display_name)

	_dev_difficulty.select(DIFFICULTY.OPTIONS.find(DIFFICULTY.DEFAULT))
	difficulty_row.add_child(_dev_difficulty)

	var close_row := HBoxContainer.new()
	close_row.alignment = BoxContainer.ALIGNMENT_END
	content.add_child(close_row)

	var close := _build_button("Fechar", overlay.hide)
	close.custom_minimum_size.x = 120.0
	close_row.add_child(close)

	return overlay


func _build_dev_button(
	text: String,
	scenario_index: int,
	start: String,
	round_index: int
) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 36.0)
	button.pressed.connect(
		_on_dev_start_pressed.bind(scenario_index, start, round_index)
	)
	return button


func _on_dev_start_pressed(
	scenario_index: int,
	start: String,
	round_index: int
) -> void:
	DIFFICULTY.select(DIFFICULTY.OPTIONS[_dev_difficulty.selected])

	DEV_OPTIONS.request_start(
		scenario_index,
		start,
		round_index,
		_dev_skip_intro.button_pressed,
		_dev_open_breaches.button_pressed
	)
	_start_game(DEV_SESSION_CODE)


func _on_open_sessions_pressed() -> void:
	var folder: String = SessionLogger.get_sessions_folder()
	DirAccess.make_dir_recursive_absolute(folder)
	OS.shell_open(folder)


func _on_help_pressed() -> void:
	_help_screen.show()


func _on_options_pressed() -> void:
	_options_screen.refresh()
	_options_screen.show()


func _on_help_closed() -> void:
	_help_screen.hide()


func _on_encyclopedia_pressed() -> void:
	_encyclopedia.refresh()
	_encyclopedia.show()


func _on_encyclopedia_closed() -> void:
	_encyclopedia.hide()


func _on_quit_pressed() -> void:
	get_tree().quit()
