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

var _encyclopedia: Encyclopedia
var _help_screen: Control
var _participant_code_input: LineEdit


func _ready() -> void:
	_build_interface()


func _build_interface() -> void:
	var background := ColorRect.new()
	add_child(background)
	background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	background.color = UIPalette.BACKGROUND
	background.material = UIPalette.make_background_material()

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
