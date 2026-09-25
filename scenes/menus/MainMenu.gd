extends Control

## Cena inicial do jogo. Da acesso a partida e a
## enciclopedia, que aqui e aberta como sobreposicao.

const GAME_SCENE_PATH := "res://scenes/gameplay/Game.tscn"

const ENCYCLOPEDIA_SCENE := preload(
	"res://scenes/encyclopedia/Encyclopedia.tscn"
)

const PANEL_WIDTH := 320.0
const BUTTON_HEIGHT := 44.0

var _encyclopedia: Encyclopedia


func _ready() -> void:
	_build_interface()


func _build_interface() -> void:
	var background := ColorRect.new()
	add_child(background)
	background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	background.color = Color(0.04, 0.05, 0.08)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)

	var title_label := Label.new()
	title_label.text = "Cyberdeck"
	title_label.add_theme_font_size_override("font_size", 48)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title_label)

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

	box.add_child(_build_button("Jogar", _on_play_pressed))

	box.add_child(
		_build_button("Enciclopédia", _on_encyclopedia_pressed)
	)

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


func _build_button(
	text: String,
	handler: Callable
) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	button.pressed.connect(handler)

	return button


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _on_encyclopedia_pressed() -> void:
	_encyclopedia.refresh()
	_encyclopedia.show()


func _on_encyclopedia_closed() -> void:
	_encyclopedia.hide()


func _on_quit_pressed() -> void:
	get_tree().quit()
