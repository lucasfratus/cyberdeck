extends Control
class_name PauseMenu

## Sobreposicao de pausa da partida. Nao pausa a arvore
## por conta propria: quem abre e fecha decide isso, para
## o menu continuar respondendo enquanto o jogo esta parado.

signal resume_requested
signal encyclopedia_requested
signal help_requested
signal options_requested
signal main_menu_requested

var _encyclopedia_button: Button

const PANEL_WIDTH := 320.0
const BUTTON_HEIGHT := 40.0
const INNER_MARGIN := 24


func _ready() -> void:
	_build_interface()
	hide()


func _build_interface() -> void:
	var shade := ColorRect.new()
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.0, 0.0, 0.6)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	center.add_child(panel)

	var margin := MarginContainer.new()
	panel.add_child(margin)
	margin.add_theme_constant_override("margin_left", INNER_MARGIN)
	margin.add_theme_constant_override("margin_top", INNER_MARGIN)
	margin.add_theme_constant_override("margin_right", INNER_MARGIN)
	margin.add_theme_constant_override("margin_bottom", INNER_MARGIN)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	var title_label := Label.new()
	title_label.text = "Pausa"
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title_label)

	box.add_child(
		_build_button("Continuar", _on_resume_pressed)
	)

	box.add_child(
		_build_button(
			"Como jogar",
			_on_help_pressed,
			UIPalette.ICON_HELP
		)
	)

	_encyclopedia_button = _build_button(
		"Enciclopédia",
		_on_encyclopedia_pressed,
		UIPalette.ICON_ENCYCLOPEDIA
	)
	box.add_child(_encyclopedia_button)

	box.add_child(
		_build_button(
			"Opções",
			func() -> void: options_requested.emit(),
			UIPalette.ICON_OPTIONS
		)
	)

	box.add_child(
		_build_button("Menu principal", _on_main_menu_pressed)
	)


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


func _on_resume_pressed() -> void:
	resume_requested.emit()


func _on_help_pressed() -> void:
	help_requested.emit()


## Durante a batalha contra o chefe a enciclopedia fica
## bloqueada: o botao continua visivel, mas desativado.
func set_encyclopedia_locked(locked: bool) -> void:
	if _encyclopedia_button == null:
		return

	_encyclopedia_button.disabled = locked
	_encyclopedia_button.text = (
		"Enciclopédia (bloqueada)" if locked else "Enciclopédia"
	)
	_encyclopedia_button.tooltip_text = (
		"Indisponível durante o confronto." if locked else ""
	)


func _on_encyclopedia_pressed() -> void:
	encyclopedia_requested.emit()


func _on_main_menu_pressed() -> void:
	main_menu_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return

	if event.is_action_pressed("ui_cancel"):
		resume_requested.emit()
		get_viewport().set_input_as_handled()
