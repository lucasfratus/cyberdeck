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
var _participant_code_input: LineEdit


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

	# Ferramentas da avaliacao: so em build de depuracao.
	if OS.is_debug_build():
		_participant_code_input = LineEdit.new()
		_participant_code_input.placeholder_text = (
			"Código do participante (ex.: P01)"
		)
		_participant_code_input.custom_minimum_size = Vector2(
			0.0,
			BUTTON_HEIGHT
		)
		_participant_code_input.text_submitted.connect(
			func(_text: String) -> void: _on_play_pressed()
		)
		box.add_child(_participant_code_input)

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

	if OS.is_debug_build():
		_build_sessions_corner_button()

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
	var participant_code := ""

	if _participant_code_input != null:
		participant_code = _participant_code_input.text

	SessionLogger.start_session(participant_code)
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _on_open_sessions_pressed() -> void:
	var folder: String = SessionLogger.get_sessions_folder()
	DirAccess.make_dir_recursive_absolute(folder)
	OS.shell_open(folder)


func _on_help_pressed() -> void:
	_help_screen.show()


func _on_help_closed() -> void:
	_help_screen.hide()


func _on_encyclopedia_pressed() -> void:
	_encyclopedia.refresh()
	_encyclopedia.show()


func _on_encyclopedia_closed() -> void:
	_encyclopedia.hide()


func _on_quit_pressed() -> void:
	get_tree().quit()
