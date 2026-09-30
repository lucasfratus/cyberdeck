extends Control

## Tela de encerramento, depois do ultimo cenario: agradece,
## avisa que todos os cenarios disponiveis foram concluidos e
## leva de volta ao menu principal.
##
## Sem class_name de proposito: o Game carrega com preload()
## e cria com new(), como a tela "Como jogar".

signal main_menu_requested

const FADE_DURATION := 0.6
const SPRITE_SIZE := 200.0
const BOB_HEIGHT := 6.0
const BOB_DURATION := 1.4

var _sprite: TextureRect
var _content: VBoxContainer
var _button: Button


func _ready() -> void:
	_build_interface()
	hide()


## Mostra a tela com o Assistente (a mesma arte dos dialogos).
func show_screen(assistant_texture: Texture2D) -> void:
	_sprite.texture = assistant_texture
	_sprite.visible = assistant_texture != null

	modulate.a = 0.0
	show()
	_button.grab_focus()

	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 1.0, FADE_DURATION)

	_start_bob()


func _build_interface() -> void:
	# Mesmo fundo da Rede dos dialogos fora da partida.
	var background := ColorRect.new()
	background.color = UIPalette.BACKGROUND
	background.material = UIPalette.make_network_background_material()
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 14)
	center.add_child(_content)

	# A moldura ocupa o espaco no layout; o sprite flutua
	# dentro dela sem empurrar os textos.
	var sprite_frame := Control.new()
	sprite_frame.custom_minimum_size = Vector2(SPRITE_SIZE, SPRITE_SIZE)
	sprite_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_content.add_child(sprite_frame)

	_sprite = TextureRect.new()
	_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sprite.size = Vector2(SPRITE_SIZE, SPRITE_SIZE)
	sprite_frame.add_child(_sprite)

	# Fundo escuro atras dos textos: as linhas da Rede passam
	# por baixo sem atrapalhar a leitura.
	var text_panel := PanelContainer.new()
	var text_style := StyleBoxFlat.new()
	text_style.bg_color = Color(UIPalette.BACKGROUND, 0.8)
	text_style.set_content_margin_all(24)
	text_style.set_corner_radius_all(2)
	text_panel.add_theme_stylebox_override("panel", text_style)
	_content.add_child(text_panel)

	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 14)
	text_panel.add_child(texts)

	var title := _make_label("Obrigado por jogar!", 44)
	title.add_theme_color_override("font_color", UIPalette.PRIMARY)
	texts.add_child(title)

	var message := _make_label(
		"Você concluiu todos os cenários disponíveis até o momento.",
		19
	)
	texts.add_child(message)

	var note := _make_label(
		"As cartas que você encontrou continuam na Enciclopédia.",
		15
	)
	note.add_theme_color_override("font_color", UIPalette.TEXT.darkened(0.15))
	texts.add_child(note)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 10.0)
	texts.add_child(spacer)

	_button = Button.new()
	_button.text = "Voltar ao menu principal"
	_button.custom_minimum_size = Vector2(300.0, 48.0)
	_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_button.pressed.connect(func() -> void: main_menu_requested.emit())
	texts.add_child(_button)


func _make_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	return label


## Sobe e desce devagar, como nos dialogos.
func _start_bob() -> void:
	_sprite.position.y = 0.0

	var bob := _sprite.create_tween().set_loops()
	bob.tween_property(_sprite, "position:y", -BOB_HEIGHT, BOB_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(_sprite, "position:y", 0.0, BOB_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
