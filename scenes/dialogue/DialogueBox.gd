extends Control
class_name DialogueBox

signal finished

@onready var portrait: TextureRect = \
	$DialoguePanel/MarginContainer/HBoxContainer/PortraitFrame/Portrait

@onready var speaker_label: Label = \
	$DialoguePanel/MarginContainer/HBoxContainer/DialogueContent/SpeakerLabel

@onready var dialogue_text: Label = \
	$DialoguePanel/MarginContainer/HBoxContainer/DialogueContent/DialogueText

@onready var continue_button: Button = \
	$DialoguePanel/MarginContainer/HBoxContainer/DialogueContent/ContinueButton

@onready var dialogue_panel: PanelContainer = $DialoguePanel
@onready var blocker: ColorRect = $Blocker

var dialogue_active := false
var dialogue_sequence: Array[Dictionary] = []
var current_dialogue_index := 0

const PANEL_SIDE_MARGIN := 70.0
const PANEL_EDGE_MARGIN := 40.0
const PANEL_HEIGHT := 180.0

## Velocidade da digitacao das falas, em caracteres por
## segundo. Uma fala de 200 caracteres leva cerca de 3,6 s.
const CHARACTERS_PER_SECOND := 55.0

var typing_tween: Tween

## Personagem exibido acima da caixa nos dialogos de tela
## cheia (abertura do jogo e dos cenarios). A textura pode
## ser trocada pelo inspetor do DialogueBox.tscn quando o
## visual definitivo do Assistente ficar pronto.
@export var character_texture: Texture2D = preload(
	"res://assets/dialogue/assistant_sprite_placeholder.png"
)

const CHARACTER_SIZE := Vector2(256.0, 256.0)

## Quanto o personagem sobe no movimento de flutuar, em
## pixels, e quanto tempo leva cada subida ou descida.
const CHARACTER_BOB_HEIGHT := 6.0
const CHARACTER_BOB_DURATION := 0.8

var character_holder: CenterContainer
var character_sprite: TextureRect
var character_tween: Tween

signal line_changed(highlight_target: DialogueLineData.HighlightTarget)

func _ready() -> void:
	continue_button.pressed.connect(_on_continue_button_pressed)

	# A quebra de linha e calculada com o texto inteiro e as
	# letras so vao sendo reveladas. No comportamento padrao,
	# as palavras pulariam de linha durante a digitacao.
	dialogue_text.visible_characters_behavior = (
		TextServer.VC_CHARS_AFTER_SHAPING
	)

	# Clicar em qualquer parte da caixa tambem avanca.
	dialogue_panel.gui_input.connect(_on_dialogue_panel_gui_input)

	_build_character()

	hide()


func show_dialogue(
	speaker: String,
	text: String,
	portrait_texture: Texture2D = null
) -> void:
	_set_dialogue_position(DialogueData.Position.BOTTOM)
	_hide_character()

	show_sequence([
		{
			"speaker": speaker,
			"text": text,
			"portrait": portrait_texture
		}
	])


## show_character exibe o Assistente flutuando acima da
## caixa. Usado nos dialogos fora da partida, com o fundo
## escuro (blocker_alpha 1.0).
func show_dialogue_data(
	dialogue_data: DialogueData,
	blocker_alpha := 0.15,
	show_character := false
) -> void:
	set_blocker_alpha(blocker_alpha)
	if dialogue_data == null:
		push_warning("Tentativa de exibir um diálogo nulo.")
		return

	if dialogue_data.lines.is_empty():
		push_warning(
			"O diálogo '%s' não possui falas."
			% dialogue_data.id
		)
		return

	var sequence: Array[Dictionary] = []

	for line in dialogue_data.lines:
		if line == null:
			continue

		sequence.append({
			"speaker": line.speaker,
			"text": line.text,
			"portrait": line.portrait,
			"highlight_target": line.highlight_target
		})

	if sequence.is_empty():
		push_warning(
			"O diálogo '%s' não possui falas válidas."
			% dialogue_data.id
		)
		return

	_set_dialogue_position(dialogue_data.position)

	if show_character:
		_show_character(dialogue_data.position)
	else:
		_hide_character()

	show_sequence(sequence)
	

func show_sequence(sequence: Array[Dictionary]) -> void:
	if sequence.is_empty():
		push_warning("Tentativa de exibir uma sequência de diálogo vazia.")
		return

	dialogue_sequence = sequence
	current_dialogue_index = 0
	dialogue_active = true

	continue_button.disabled = false
	show()

	_show_current_line()
	continue_button.grab_focus()


func _show_current_line() -> void:
	if current_dialogue_index >= dialogue_sequence.size():
		close_dialogue()
		return

	var current_line: Dictionary = dialogue_sequence[current_dialogue_index]

	speaker_label.text = str(
		current_line.get("speaker", "")
	)

	dialogue_text.text = str(
		current_line.get("text", "")
	)
	_start_typing()

	var portrait_texture: Texture2D = current_line.get(
		"portrait",
		null
	)

	portrait.texture = portrait_texture
	
	line_changed.emit(
	current_line.get(
		"highlight_target",
		DialogueLineData.HighlightTarget.NONE
		)
	)
	
	portrait.visible = portrait_texture != null

	if current_dialogue_index == dialogue_sequence.size() - 1:
		continue_button.text = "Concluir"
	else:
		continue_button.text = "Continuar"


func advance_dialogue() -> void:
	if not dialogue_active:
		return

	# O primeiro toque completa a fala que ainda esta sendo
	# digitada. So o seguinte passa para a proxima.
	if is_typing():
		_complete_typing()
		return

	current_dialogue_index += 1

	if current_dialogue_index >= dialogue_sequence.size():
		close_dialogue()
		return

	_show_current_line()


func close_dialogue() -> void:
	if not dialogue_active:
		return

	dialogue_active = false
	continue_button.disabled = true
	_complete_typing()

	dialogue_sequence.clear()
	current_dialogue_index = 0

	_hide_character()
	hide()
	line_changed.emit(
	DialogueLineData.HighlightTarget.NONE
	)
	finished.emit()


func is_dialogue_active() -> bool:
	return dialogue_active


func _on_continue_button_pressed() -> void:
	advance_dialogue()


func _on_dialogue_panel_gui_input(event: InputEvent) -> void:
	if not dialogue_active:
		return

	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		dialogue_panel.accept_event()
		advance_dialogue()


func is_typing() -> bool:
	return typing_tween != null and typing_tween.is_running()


func _start_typing() -> void:
	_kill_typing_tween()

	var total: int = dialogue_text.text.length()

	if total <= 0:
		dialogue_text.visible_characters = -1
		return

	dialogue_text.visible_characters = 0

	typing_tween = create_tween()
	typing_tween.tween_property(
		dialogue_text,
		"visible_characters",
		total,
		total / CHARACTERS_PER_SECOND
	)
	typing_tween.tween_callback(_on_typing_finished)


func _on_typing_finished() -> void:
	dialogue_text.visible_characters = -1


## Mostra a fala inteira. -1 significa "todos os caracteres".
func _complete_typing() -> void:
	_kill_typing_tween()
	dialogue_text.visible_characters = -1


func _kill_typing_tween() -> void:
	if typing_tween != null and typing_tween.is_valid():
		typing_tween.kill()


func _unhandled_input(event: InputEvent) -> void:
	if not dialogue_active:
		return

	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		advance_dialogue()


func _set_dialogue_position(
	dialogue_position: DialogueData.Position
) -> void:
	match dialogue_position:
		DialogueData.Position.TOP:
			dialogue_panel.set_anchors_preset(
				Control.PRESET_TOP_WIDE
			)

			dialogue_panel.offset_left = PANEL_SIDE_MARGIN
			dialogue_panel.offset_top = PANEL_EDGE_MARGIN
			dialogue_panel.offset_right = -PANEL_SIDE_MARGIN
			dialogue_panel.offset_bottom = (
				PANEL_EDGE_MARGIN + PANEL_HEIGHT
			)

		DialogueData.Position.BOTTOM:
			dialogue_panel.set_anchors_preset(
				Control.PRESET_BOTTOM_WIDE
			)

			dialogue_panel.offset_left = PANEL_SIDE_MARGIN
			dialogue_panel.offset_top = (
				-PANEL_EDGE_MARGIN - PANEL_HEIGHT
			)
			dialogue_panel.offset_right = -PANEL_SIDE_MARGIN
			dialogue_panel.offset_bottom = -PANEL_EDGE_MARGIN
			
	
func set_blocker_alpha(alpha: float) -> void:
	var color := blocker.color
	color.a = alpha
	blocker.color = color


func _build_character() -> void:
	# O holder ocupa o espaco livre fora da caixa de dialogo
	# e centraliza o frame nas duas direcoes. O sprite se
	# move dentro do frame, que nao e um container, entao o
	# redimensionamento da janela nao atrapalha a animacao.
	character_holder = CenterContainer.new()
	character_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(character_holder)

	var character_frame := Control.new()
	character_frame.custom_minimum_size = CHARACTER_SIZE
	character_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	character_holder.add_child(character_frame)

	# Logo acima do Blocker, para nao ficar escondido pelo
	# fundo escuro e nem por cima da caixa de dialogo.
	move_child(character_holder, blocker.get_index() + 1)

	character_sprite = TextureRect.new()
	character_sprite.texture = character_texture
	character_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	character_sprite.stretch_mode = (
		TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	)
	character_sprite.size = CHARACTER_SIZE
	character_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# O placeholder e pixel art: sem filtro, os pixels ficam
	# nitidos ao ampliar. Para uma arte desenhada, trocar
	# por TEXTURE_FILTER_LINEAR.
	character_sprite.texture_filter = (
		CanvasItem.TEXTURE_FILTER_NEAREST
	)

	character_frame.add_child(character_sprite)
	character_holder.hide()


## Centraliza o personagem no espaco que sobra fora da
## caixa de dialogo e inicia a animacao.
func _show_character(
	dialogue_position: DialogueData.Position
) -> void:
	if character_holder == null or character_texture == null:
		return

	var panel_space := PANEL_EDGE_MARGIN + PANEL_HEIGHT

	# Primeiro as ancoras, depois os offsets. O
	# set_anchors_and_offsets_preset zera os offsets. So o
	# set_anchors_preset recalcularia os offsets para manter
	# a posicao antiga, o que deixava o sprite no canto
	# esquerdo.
	character_holder.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	match dialogue_position:
		DialogueData.Position.TOP:
			character_holder.offset_top = panel_space

		DialogueData.Position.BOTTOM:
			character_holder.offset_bottom = -panel_space

	character_holder.show()
	_start_character_bob()


func _hide_character() -> void:
	_stop_character_bob()

	if character_holder != null:
		character_holder.hide()


## Sobe e desce em loop. TRANS_SINE deixa o movimento mais
## lento perto dos extremos, como uma flutuacao.
func _start_character_bob() -> void:
	_stop_character_bob()

	character_sprite.position = Vector2.ZERO

	character_tween = create_tween()
	character_tween.set_loops()
	character_tween.set_trans(Tween.TRANS_SINE)
	character_tween.set_ease(Tween.EASE_IN_OUT)
	character_tween.tween_property(
		character_sprite,
		"position:y",
		-CHARACTER_BOB_HEIGHT,
		CHARACTER_BOB_DURATION
	)
	character_tween.tween_property(
		character_sprite,
		"position:y",
		0.0,
		CHARACTER_BOB_DURATION
	)


func _stop_character_bob() -> void:
	if character_tween != null and character_tween.is_valid():
		character_tween.kill()

	if character_sprite != null:
		character_sprite.position = Vector2.ZERO
