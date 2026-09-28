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

## Id do DialogueData em exibicao, para o registro da sessao.
var current_dialogue_id := ""

## Botao para rever a fala anterior. Criado em codigo, ao
## lado do Continuar.
var back_button: Button

const PANEL_SIDE_MARGIN := 70.0
const PANEL_EDGE_MARGIN := 40.0
const PANEL_HEIGHT := 180.0

## Cores do texto das falas. Mais claras que o verde padrao
## da interface, que fica apagado em textos longos.
const DIALOGUE_TEXT_COLOR := Color(0.9, 1.0, 0.93)
const SPEAKER_COLOR := Color(0.78, 0.7, 1.0)

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

## Ilustracao ao lado do personagem, em um quadro.
const ILLUSTRATION_SIZE := Vector2(160.0, 160.0)
const ILLUSTRATION_GAP := 32.0
const ILLUSTRATION_POP_DURATION := 0.25
const ILLUSTRATION_SLIDE_DURATION := 0.3

## Fundo da Rede atras dos dialogos de tela cheia. Fica por
## cima do Blocker, que continua preto por baixo.
var backdrop: ColorRect

var illustration_panel: PanelContainer
var illustration_rect: TextureRect
var illustration_tween: Tween

## Voz do Assistente: um som curto tocado enquanto o texto e
## digitado. Pode ser trocado pelo inspetor.
@export var voice_sound: AudioStream = preload(
	"res://assets/audio/dialogue_blip.wav"
)

## Intervalo minimo entre dois sons, em milissegundos. Sem
## ele, a 55 caracteres por segundo, os sons se atropelam.
const VOICE_MIN_INTERVAL_MS := 60
const VOICE_VOLUME_DB := -10.0

## Variacao aleatoria do tom a cada som, para a voz nao
## soar como um bipe repetido.
const VOICE_PITCH_MIN := 0.92
const VOICE_PITCH_MAX := 1.08

## Coloque false para desligar a voz.
const VOICE_ENABLED := true

var voice_player: AudioStreamPlayer
var voice_base_pitch := 1.0
var last_voiced_character := 0
var last_voice_msec := 0

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

	_improve_contrast()

	_build_character()
	_build_illustration()

	# Depois do personagem: o fundo e colocado logo acima do
	# Blocker e empurra o personagem para cima dele.
	_build_backdrop()
	_build_back_button()
	_build_voice()

	hide()


## Texto mais claro e uma borda na caixa, para a fala se
## destacar do fundo em qualquer tela.
func _improve_contrast() -> void:
	dialogue_text.add_theme_color_override("font_color", DIALOGUE_TEXT_COLOR)
	speaker_label.add_theme_color_override("font_color", SPEAKER_COLOR)

	var box := dialogue_panel.get_theme_stylebox("panel")
	if box is StyleBoxFlat:
		box = box.duplicate()
		box.bg_color = Color(0.0, 0.0, 0.0, 0.97)
		box.border_color = UIPalette.DIM
		box.set_border_width_all(2)
		dialogue_panel.add_theme_stylebox_override("panel", box)


func show_dialogue(
	speaker: String,
	text: String,
	portrait_texture: Texture2D = null
) -> void:
	_set_dialogue_position(DialogueData.Position.BOTTOM)
	_hide_character()
	current_dialogue_id = ""

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
			"highlight_target": line.highlight_target,
			"illustration": line.illustration,
			"voice": line.voice,
			"voice_pitch": line.voice_pitch,
		})

	if sequence.is_empty():
		push_warning(
			"O diálogo '%s' não possui falas válidas."
			% dialogue_data.id
		)
		return

	_set_dialogue_position(dialogue_data.position)
	current_dialogue_id = dialogue_data.id

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


## skip_typing mostra a fala inteira de uma vez. Usado ao
## voltar para uma fala que o jogador ja leu.
func _show_current_line(skip_typing := false) -> void:
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

	if skip_typing:
		_complete_typing()
	else:
		_start_typing()

	_show_line_illustration(current_line.get("illustration", null))

	# Voz da fala: a da linha, se tiver, ou a padrao.
	if voice_player != null:
		var line_voice: AudioStream = current_line.get("voice", null)
		voice_player.stream = line_voice if line_voice != null else voice_sound
		voice_base_pitch = float(current_line.get("voice_pitch", 1.0))

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

	# Na primeira fala nao ha para onde voltar.
	if back_button != null:
		back_button.disabled = current_dialogue_index == 0


## Volta para a fala anterior da mesma sequencia.
func go_back() -> void:
	if not dialogue_active or current_dialogue_index <= 0:
		return

	current_dialogue_index -= 1
	_show_current_line(true)
	continue_button.grab_focus()

	SessionLogger.log_event("dialogue_back", {
		"dialogue": current_dialogue_id,
		"line": current_dialogue_index,
	})


func _build_back_button() -> void:
	# O Continuar esta sozinho no fim do VBox. Uma linha nova
	# no lugar dele guarda os dois botoes, Voltar a esquerda.
	var content := continue_button.get_parent()
	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_END
	button_row.add_theme_constant_override("separation", 8)
	button_row.size_flags_vertical = continue_button.size_flags_vertical
	content.add_child(button_row)
	content.move_child(button_row, continue_button.get_index())

	back_button = Button.new()
	back_button.text = "Voltar"
	back_button.custom_minimum_size = continue_button.custom_minimum_size
	back_button.tooltip_text = "Rever a fala anterior (seta para a esquerda)"

	# Sem foco: o Enter continua indo para o Continuar.
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.pressed.connect(go_back)
	button_row.add_child(back_button)

	continue_button.reparent(button_row, false)


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
	last_voiced_character = 0

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


## A seta para a esquerda e tratada em _input, antes da
## interface: senao o Godot a usaria para mover o foco entre
## botoes e ela nunca chegaria ate aqui.
func _input(event: InputEvent) -> void:
	if not dialogue_active:
		return

	if event.is_action_pressed("ui_left"):
		get_viewport().set_input_as_handled()
		go_back()


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


func _build_backdrop() -> void:
	backdrop = ColorRect.new()
	backdrop.color = Color.BLACK
	backdrop.material = UIPalette.make_network_background_material()
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	move_child(backdrop, blocker.get_index() + 1)
	backdrop.hide()


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

	# A imagem do Assistente tem 512 px e aparece com 256: a
	# reducao pela metade com filtro linear mistura cada 2x2
	# pixels e deixa as bordas suaves. Com NEAREST, metade dos
	# pixels seria descartada e o contorno ficaria serrilhado.
	character_sprite.texture_filter = (
		CanvasItem.TEXTURE_FILTER_LINEAR
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
	backdrop.show()
	_start_character_bob()


func _hide_character() -> void:
	_stop_character_bob()

	if character_holder != null:
		character_holder.hide()

	if backdrop != null:
		backdrop.hide()

	if illustration_tween != null and illustration_tween.is_valid():
		illustration_tween.kill()

	if illustration_panel != null:
		illustration_panel.hide()


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


# --- Ilustracao ao lado do Assistente -------------------------

func _build_illustration() -> void:
	var character_frame := character_sprite.get_parent() as Control

	# Filho do quadro do personagem, fora do layout: aparece
	# a direita dele sem tirar o personagem do centro.
	illustration_panel = PanelContainer.new()
	illustration_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var box := StyleBoxFlat.new()
	box.bg_color = UIPalette.PANEL
	box.border_color = UIPalette.PRIMARY
	box.set_border_width_all(2)
	# 160 - 2 x 16 = 128 px de imagem: os icones de 16 e 32 px
	# ficam ampliados em multiplos inteiros (8x e 4x).
	box.set_content_margin_all(16.0)
	illustration_panel.add_theme_stylebox_override("panel", box)

	character_frame.add_child(illustration_panel)
	illustration_panel.custom_minimum_size = ILLUSTRATION_SIZE
	illustration_panel.size = ILLUSTRATION_SIZE
	illustration_panel.position = Vector2(
		CHARACTER_SIZE.x + ILLUSTRATION_GAP,
		(CHARACTER_SIZE.y - ILLUSTRATION_SIZE.y) / 2.0
	)
	illustration_panel.pivot_offset = ILLUSTRATION_SIZE / 2.0

	illustration_rect = TextureRect.new()
	illustration_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	illustration_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	illustration_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	illustration_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	illustration_panel.add_child(illustration_rect)

	illustration_panel.hide()


## Troca a ilustracao da fala. Sem ilustracao, ou fora dos
## dialogos de tela cheia, o quadro some.
##
## Com ilustracao, o personagem desliza para a esquerda e o
## par (personagem e quadro) fica centralizado. Sem ela, o
## personagem volta sozinho para o centro.
func _show_line_illustration(texture: Texture2D) -> void:
	if illustration_panel == null:
		return

	var wanted := texture != null and character_holder.visible

	# A mesma imagem da fala anterior continua parada.
	if wanted and illustration_panel.visible and illustration_rect.texture == texture:
		return

	if illustration_tween != null and illustration_tween.is_valid():
		illustration_tween.kill()

	if not wanted:
		if illustration_panel.visible:
			illustration_tween = create_tween()
			illustration_tween.tween_property(
				illustration_panel,
				"modulate:a",
				0.0,
				ILLUSTRATION_POP_DURATION * 0.5
			)
			illustration_tween.parallel().tween_property(
				character_sprite,
				"position:x",
				0.0,
				ILLUSTRATION_SLIDE_DURATION
			).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			illustration_tween.tween_callback(illustration_panel.hide)
		else:
			character_sprite.position.x = 0.0
		return

	illustration_rect.texture = texture

	# Pixel art pequena amplia sem filtro; imagens grandes
	# reduzidas ficam melhores com o filtro linear.
	if texture.get_width() <= 128:
		illustration_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	else:
		illustration_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	# Metade do espaco extra (vao + quadro) vai para cada lado.
	var shift := -(ILLUSTRATION_GAP + ILLUSTRATION_SIZE.x) / 2.0

	illustration_panel.position.x = (
		CHARACTER_SIZE.x + ILLUSTRATION_GAP + shift
	)
	illustration_panel.scale = Vector2.ONE * 0.6
	illustration_panel.modulate.a = 0.0
	illustration_panel.show()

	illustration_tween = create_tween()
	illustration_tween.tween_property(
		character_sprite,
		"position:x",
		shift,
		ILLUSTRATION_SLIDE_DURATION
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	illustration_tween.parallel().tween_property(
		illustration_panel,
		"scale",
		Vector2.ONE,
		ILLUSTRATION_POP_DURATION
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	illustration_tween.parallel().tween_property(
		illustration_panel,
		"modulate:a",
		1.0,
		ILLUSTRATION_POP_DURATION * 0.6
	)


# --- Voz ------------------------------------------------------

func _build_voice() -> void:
	voice_player = AudioStreamPlayer.new()
	voice_player.stream = voice_sound
	voice_player.volume_db = VOICE_VOLUME_DB
	add_child(voice_player)


## Toca a voz conforme as letras aparecem. Espacos e
## pontuacao ficam em silencio, o que da o ritmo das pausas.
func _process(_delta: float) -> void:
	if not VOICE_ENABLED or voice_player == null or voice_sound == null:
		return

	if not is_typing():
		return

	var shown: int = dialogue_text.visible_characters

	if shown <= last_voiced_character:
		return

	last_voiced_character = shown

	var now := Time.get_ticks_msec()

	if now - last_voice_msec < VOICE_MIN_INTERVAL_MS:
		return

	var character := dialogue_text.text.substr(shown - 1, 1)

	if character.strip_edges().is_empty() or character in ".,;:!?…":
		return

	last_voice_msec = now
	voice_player.pitch_scale = voice_base_pitch * randf_range(VOICE_PITCH_MIN, VOICE_PITCH_MAX)
	voice_player.play()
