extends Control

## Cena de chamada entre dois personagens, com os retratos
## lado a lado e as falas legendadas embaixo. Usada nas
## conversas entre os antagonistas, entre um cenario e outro.
##
## Recebe um DialogueData comum: o primeiro personagem que fala
## fica a esquerda e o outro a direita. O retrato de cada lado
## vem da primeira fala daquele personagem.
##
## Sem class_name de proposito: quem usa carrega com preload()
## e cria com new().

signal finished

const PORTRAIT_SHADER := preload("res://assets/shaders/codec_portrait.gdshader")
const EYE_SHADER := preload("res://assets/shaders/eye_transition.gdshader")

const RING_SOUND: AudioStream = preload("res://assets/audio/codec_ring.wav")
const STATIC_SOUND: AudioStream = preload("res://assets/audio/codec_static.wav")
const LEFT_VOICE: AudioStream = preload("res://assets/audio/voice_grunt.wav")
const RIGHT_VOICE: AudioStream = preload("res://assets/audio/voice_eve.wav")

## Cores da chamada. A interface dos antagonistas usa vermelho,
## para contrastar com o verde do Assistente. Cada retrato tem
## a sua cor.
const CALL_COLOR := Color(1.0, 0.36, 0.36)
const CALL_COLOR_DIM := Color(0.45, 0.12, 0.12)
const LEFT_TINT := Color(1.0, 0.74, 0.3)
const RIGHT_TINT := Color(1.0, 0.38, 0.72)

const CHANNEL_TEXT := "07.31"

const PORTRAIT_SIZE := Vector2(250.0, 250.0)
const CENTER_COLUMN_WIDTH := 300.0
const SUBTITLE_WIDTH := 1000.0
const SUBTITLE_HEIGHT := 150.0
const METER_BARS := 12

const CHARACTERS_PER_SECOND := 45.0
const LISTENER_BRIGHTNESS := 0.45

## Transicao do olho: abrir, olhar em volta, mergulhar na
## pupila. Na saida, o inverso e o olho fecha.
const EYE_OPEN_DURATION := 0.55
const EYE_GLANCE_DURATION := 0.18
const EYE_DIVE_DURATION := 0.5
const EYE_CLOSE_DURATION := 0.3
const EYE_DIVE_ZOOM := 70.0

const RING_DURATION := 1.3
const POWER_DURATION := 0.22
const END_HOLD := 0.9

## Voz: mesmas regras do DialogueBox.
const VOICE_MIN_INTERVAL_MS := 60
const VOICE_VOLUME_DB := -8.0
const VOICE_PITCH_MIN := 0.94
const VOICE_PITCH_MAX := 1.06

var _dialogue_id := ""
var _lines: Array[DialogueLineData] = []
var _index := 0
var _active := false
var _left_speaker := ""
var _start_msec := 0

var _status_label: Label
var _channel_label: Label
var _meter_bars: Array[ColorRect] = []
var _left_arrow: Label
var _right_arrow: Label

var _screens: Dictionary = {}     # "left"/"right" -> Control
var _portraits: Dictionary = {}   # "left"/"right" -> TextureRect
var _materials: Dictionary = {}   # "left"/"right" -> ShaderMaterial
var _name_labels: Dictionary = {} # "left"/"right" -> Label

var _subtitle_panel: PanelContainer
var _speaker_label: Label
var _text_label: Label
var _back_button: Button
var _continue_button: Button
var _skip_button: Button

var _eye: ColorRect
var _eye_material: ShaderMaterial

var _typing_tween: Tween
var _voice_player: AudioStreamPlayer
var _fx_player: AudioStreamPlayer
var _last_voiced := 0
var _last_voice_msec := 0
var _meter_time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_background_gui_input)
	_build_interface()
	hide()


## Toca a chamada inteira. Aguardar esta funcao segura o jogo
## ate a chamada terminar.
func play(dialogue: DialogueData) -> void:
	if dialogue == null or dialogue.lines.is_empty():
		return

	_dialogue_id = dialogue.id
	_lines.clear()

	for line in dialogue.lines:
		if line != null:
			_lines.append(line)

	if _lines.is_empty():
		return

	_setup_participants()
	_index = 0
	_start_msec = Time.get_ticks_msec()

	SessionLogger.log_event("cutscene_start", {"id": _dialogue_id})

	modulate.a = 1.0
	_subtitle_panel.modulate.a = 0.0
	_speaker_label.text = ""
	_text_label.text = ""
	for side in ["left", "right"]:
		_screens[side].scale = Vector2(1.0, 0.0)
		_name_labels[side].modulate.a = 0.0
	_status_label.text = ""
	show()

	await _eye_enter()
	await _ring()
	await _power_screens(true)

	var tween := create_tween()
	tween.tween_property(_subtitle_panel, "modulate:a", 1.0, 0.2)
	await tween.finished

	_active = true
	_continue_button.grab_focus()
	await _show_line()

	await finished


# --- Montagem -------------------------------------------------

func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = Color(0.02, 0.0, 0.01)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 28)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(column)

	var top_row := HBoxContainer.new()
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_row.add_theme_constant_override("separation", 24)
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(top_row)

	top_row.add_child(_build_portrait_slot("left", LEFT_TINT))
	top_row.add_child(_build_center_column())
	top_row.add_child(_build_portrait_slot("right", RIGHT_TINT))

	column.add_child(_build_subtitle_panel())

	_skip_button = Button.new()
	_skip_button.text = "Pular chamada"
	_skip_button.focus_mode = Control.FOCUS_NONE
	_skip_button.pressed.connect(_on_skip_pressed)
	add_child(_skip_button)
	_skip_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_skip_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_skip_button.offset_right = -16.0
	_skip_button.offset_top = 16.0

	# Olho por cima de tudo, para as transicoes.
	_eye_material = ShaderMaterial.new()
	_eye_material.shader = EYE_SHADER
	_eye = ColorRect.new()
	_eye.material = _eye_material
	_eye.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_eye)
	_eye.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_eye.hide()

	_voice_player = AudioStreamPlayer.new()
	_voice_player.volume_db = VOICE_VOLUME_DB
	add_child(_voice_player)

	_fx_player = AudioStreamPlayer.new()
	_fx_player.volume_db = -6.0
	add_child(_fx_player)


## Espaco fixo no layout com uma "tela" dentro. A tela liga e
## desliga pela escala, sem o container interferir.
func _build_portrait_slot(side: String, tint: Color) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var slot := Control.new()
	slot.custom_minimum_size = PORTRAIT_SIZE
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(slot)

	var screen := Panel.new()
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color.BLACK
	frame.border_color = CALL_COLOR_DIM
	frame.set_border_width_all(3)
	screen.add_theme_stylebox_override("panel", frame)
	slot.add_child(screen)
	screen.size = PORTRAIT_SIZE
	screen.pivot_offset = PORTRAIT_SIZE / 2.0

	var portrait := TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = PORTRAIT_SHADER
	material.set_shader_parameter("tint", tint)
	portrait.material = material
	screen.add_child(portrait)
	portrait.position = Vector2(3.0, 3.0)
	portrait.size = PORTRAIT_SIZE - Vector2(6.0, 6.0)

	var name_label := Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", tint)
	name_label.add_theme_font_size_override("font_size", 20)
	box.add_child(name_label)

	_screens[side] = screen
	_portraits[side] = portrait
	_materials[side] = material
	_name_labels[side] = name_label

	return box


func _build_center_column() -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(CENTER_COLUMN_WIDTH, 0.0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_color_override("font_color", CALL_COLOR)
	box.add_child(_status_label)

	_channel_label = Label.new()
	_channel_label.text = CHANNEL_TEXT
	_channel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_channel_label.add_theme_font_size_override("font_size", 56)
	_channel_label.add_theme_color_override("font_color", CALL_COLOR)
	box.add_child(_channel_label)

	# Medidor de sinal, com setas indicando quem transmite.
	var meter_row := HBoxContainer.new()
	meter_row.alignment = BoxContainer.ALIGNMENT_CENTER
	meter_row.add_theme_constant_override("separation", 8)
	meter_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(meter_row)

	_left_arrow = Label.new()
	_left_arrow.text = "<"
	_left_arrow.add_theme_font_size_override("font_size", 28)
	_left_arrow.add_theme_color_override("font_color", CALL_COLOR)
	meter_row.add_child(_left_arrow)

	var bars := HBoxContainer.new()
	bars.add_theme_constant_override("separation", 3)
	bars.alignment = BoxContainer.ALIGNMENT_CENTER
	bars.custom_minimum_size = Vector2(0.0, 40.0)
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter_row.add_child(bars)

	for i in range(METER_BARS):
		var bar := ColorRect.new()
		bar.color = CALL_COLOR_DIM
		bar.custom_minimum_size = Vector2(8.0, 6.0)
		bar.size_flags_vertical = Control.SIZE_SHRINK_END
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bars.add_child(bar)
		_meter_bars.append(bar)

	_right_arrow = Label.new()
	_right_arrow.text = ">"
	_right_arrow.add_theme_font_size_override("font_size", 28)
	_right_arrow.add_theme_color_override("font_color", CALL_COLOR)
	meter_row.add_child(_right_arrow)

	var caption := Label.new()
	caption.text = "CANAL PRIVADO"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_color_override("font_color", CALL_COLOR_DIM)
	box.add_child(caption)

	return box


func _build_subtitle_panel() -> Control:
	_subtitle_panel = PanelContainer.new()
	_subtitle_panel.custom_minimum_size = Vector2(SUBTITLE_WIDTH, SUBTITLE_HEIGHT)
	var box_style := StyleBoxFlat.new()
	box_style.bg_color = Color(0.0, 0.0, 0.0, 0.95)
	box_style.border_color = CALL_COLOR_DIM
	box_style.set_border_width_all(2)
	box_style.set_content_margin_all(18.0)
	_subtitle_panel.add_theme_stylebox_override("panel", box_style)
	_subtitle_panel.gui_input.connect(_on_subtitle_gui_input)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle_panel.add_child(content)

	_speaker_label = Label.new()
	_speaker_label.add_theme_font_size_override("font_size", 20)
	content.add_child(_speaker_label)

	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_text_label)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 8)
	content.add_child(buttons)

	_back_button = Button.new()
	_back_button.text = "Voltar"
	_back_button.custom_minimum_size = Vector2(120.0, 36.0)
	_back_button.focus_mode = Control.FOCUS_NONE
	_back_button.pressed.connect(_go_back)
	buttons.add_child(_back_button)

	_continue_button = Button.new()
	_continue_button.text = "Continuar"
	_continue_button.custom_minimum_size = Vector2(120.0, 36.0)
	_continue_button.pressed.connect(_advance)
	buttons.add_child(_continue_button)

	return _subtitle_panel


func _setup_participants() -> void:
	_left_speaker = _lines[0].speaker
	var right_speaker := ""

	_portraits["left"].texture = _lines[0].portrait
	_portraits["right"].texture = null

	for line in _lines:
		if line.speaker != _left_speaker:
			right_speaker = line.speaker
			_portraits["right"].texture = line.portrait
			break

	_name_labels["left"].text = _left_speaker.to_upper()
	_name_labels["right"].text = right_speaker.to_upper()


# --- Abertura e encerramento ----------------------------------

func _ring() -> void:
	_status_label.text = "CHAMADA RECEBIDA"
	_play_fx(RING_SOUND)

	# O aviso e o canal piscam enquanto o toque soa.
	var blink := create_tween()
	blink.set_loops(int(RING_DURATION / 0.3))
	blink.tween_property(_status_label, "modulate:a", 0.2, 0.15)
	blink.tween_property(_status_label, "modulate:a", 1.0, 0.15)
	await get_tree().create_timer(RING_DURATION, false).timeout
	if blink.is_valid():
		blink.kill()
	_status_label.modulate.a = 1.0
	_status_label.text = "CONECTADO"


func _set_eye(open: float, zoom: float, reveal: float, glitch: float) -> void:
	_eye_material.set_shader_parameter("open", open)
	_eye_material.set_shader_parameter("zoom", zoom)
	_eye_material.set_shader_parameter("reveal", reveal)
	_eye_material.set_shader_parameter("glitch", glitch)
	_eye_material.set_shader_parameter("look", Vector2.ZERO)


## O olho abre na tela escura, olha para os lados e a imagem
## mergulha na pupila, que revela a chamada por tras.
func _eye_enter() -> void:
	_set_eye(0.0, 1.0, 0.0, 1.0)
	_eye.show()
	_play_fx(STATIC_SOUND)

	var m := _eye_material
	var tween := create_tween()
	tween.tween_interval(0.25)
	tween.tween_property(m, "shader_parameter/open", 1.0, EYE_OPEN_DURATION) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(m, "shader_parameter/glitch", 0.25, EYE_OPEN_DURATION)
	tween.tween_property(m, "shader_parameter/look", Vector2(-0.05, 0.0), EYE_GLANCE_DURATION)
	tween.tween_property(m, "shader_parameter/look", Vector2(0.05, 0.01), EYE_GLANCE_DURATION * 1.4)
	tween.tween_property(m, "shader_parameter/look", Vector2.ZERO, EYE_GLANCE_DURATION)
	tween.tween_interval(0.2)
	tween.tween_callback(func() -> void: m.set_shader_parameter("reveal", 1.0))
	tween.tween_property(m, "shader_parameter/zoom", EYE_DIVE_ZOOM, EYE_DIVE_DURATION) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(m, "shader_parameter/glitch", 1.0, EYE_DIVE_DURATION)
	await tween.finished

	_eye.hide()


## Sai da pupila, a imagem se afasta ate o olho inteiro
## aparecer, e o olho fecha. A tela termina escura.
func _eye_exit() -> void:
	_set_eye(1.0, EYE_DIVE_ZOOM, 1.0, 1.0)
	_eye.show()
	_play_fx(STATIC_SOUND)

	var m := _eye_material
	var tween := create_tween()
	tween.tween_property(m, "shader_parameter/zoom", 1.0, EYE_DIVE_DURATION) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(m, "shader_parameter/glitch", 0.25, EYE_DIVE_DURATION)
	tween.tween_callback(func() -> void: m.set_shader_parameter("reveal", 0.0))
	tween.tween_interval(0.35)
	tween.tween_property(m, "shader_parameter/open", 0.0, EYE_CLOSE_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(m, "shader_parameter/glitch", 0.0, EYE_CLOSE_DURATION)
	tween.tween_interval(0.25)
	await tween.finished


## Liga (ou desliga) as duas telas: uma linha fina que abre
## na vertical, como um monitor antigo.
func _power_screens(on: bool) -> void:
	_play_fx(STATIC_SOUND)

	var tween := create_tween()
	tween.set_parallel(true)

	for side in ["left", "right"]:
		var screen: Control = _screens[side]
		if on:
			screen.scale = Vector2(1.0, 0.02)
		tween.tween_property(
			screen,
			"scale:y",
			1.0 if on else 0.0,
			POWER_DURATION
		).set_trans(Tween.TRANS_QUAD).set_ease(
			Tween.EASE_OUT if on else Tween.EASE_IN
		)
		tween.tween_property(
			_name_labels[side],
			"modulate:a",
			1.0 if on else 0.0,
			POWER_DURATION
		)

	await tween.finished


func _end_call(skipped: bool) -> void:
	if not _active:
		return

	_active = false
	_kill_typing()
	_set_meter_idle()

	SessionLogger.log_event("cutscene_end", {
		"id": _dialogue_id,
		"seconds": snappedf((Time.get_ticks_msec() - _start_msec) / 1000.0, 0.01),
		"skipped": skipped,
	})

	var fade_subtitle := create_tween()
	fade_subtitle.tween_property(_subtitle_panel, "modulate:a", 0.0, 0.15)

	await _power_screens(false)

	_status_label.text = "CONEXÃO ENCERRADA"
	await get_tree().create_timer(END_HOLD, false).timeout
	await _eye_exit()

	# A tela continua preta: quem chamou decide o que entra
	# no lugar e esconde a chamada.
	finished.emit()


# --- Falas ----------------------------------------------------

func _show_line(skip_typing := false) -> void:
	var line: DialogueLineData = _lines[_index]
	var side := "left" if line.speaker == _left_speaker else "right"
	var tint: Color = LEFT_TINT if side == "left" else RIGHT_TINT

	_speaker_label.text = line.speaker.to_upper()
	_speaker_label.add_theme_color_override("font_color", tint)
	_text_label.text = line.text
	_back_button.disabled = _index == 0
	_continue_button.text = "Encerrar" if _index == _lines.size() - 1 else "Continuar"

	# Quem fala acende; quem ouve fica apagado.
	for s in ["left", "right"]:
		var speaking: bool = s == side
		_materials[s].set_shader_parameter(
			"brightness",
			1.0 if speaking else LISTENER_BRIGHTNESS
		)
		var frame: StyleBoxFlat = _screens[s].get_theme_stylebox("panel")
		frame.border_color = (LEFT_TINT if s == "left" else RIGHT_TINT) if speaking else CALL_COLOR_DIM

	_left_arrow.modulate.a = 1.0 if side == "left" else 0.15
	_right_arrow.modulate.a = 1.0 if side == "right" else 0.15

	_voice_player.stream = line.voice if line.voice != null else (
		LEFT_VOICE if side == "left" else RIGHT_VOICE
	)
	_voice_player.pitch_scale = line.voice_pitch

	if skip_typing:
		_kill_typing()
		_text_label.visible_characters = -1
		return

	_text_label.visible_characters = 0

	# Som de abertura da fala, como um grito, antes do texto.
	if line.intro_sound != null:
		_play_fx(line.intro_sound)
		await get_tree().create_timer(
			line.intro_sound.get_length(),
			false
		).timeout

		# O jogador pode ter avancado ou completado a fala
		# durante o som.
		if (
			not _active
			or _lines[_index] != line
			or _text_label.visible_characters != 0
		):
			return

	_start_typing()


func _start_typing() -> void:
	_kill_typing()
	_last_voiced = 0
	var total := _text_label.text.length()
	_typing_tween = create_tween()
	_typing_tween.tween_property(
		_text_label,
		"visible_characters",
		total,
		total / CHARACTERS_PER_SECOND
	)
	_typing_tween.tween_callback(func() -> void: _text_label.visible_characters = -1)


func _is_typing() -> bool:
	return _typing_tween != null and _typing_tween.is_running()


func _kill_typing() -> void:
	if _typing_tween != null and _typing_tween.is_valid():
		_typing_tween.kill()


func _advance() -> void:
	if not _active:
		return

	# Primeiro toque completa a fala; o seguinte avanca.
	if _is_typing() or _text_label.visible_characters != -1:
		_kill_typing()
		_text_label.visible_characters = -1
		return

	if _index >= _lines.size() - 1:
		_end_call(false)
		return

	_index += 1
	_show_line()


func _go_back() -> void:
	if not _active or _index <= 0:
		return

	_index -= 1
	_show_line(true)
	_continue_button.grab_focus()

	SessionLogger.log_event("dialogue_back", {
		"dialogue": _dialogue_id,
		"line": _index,
	})


func _on_skip_pressed() -> void:
	_end_call(true)


func _on_background_gui_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		accept_event()
		_advance()


func _on_subtitle_gui_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		_subtitle_panel.accept_event()
		_advance()


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return

	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_advance()


func _input(event: InputEvent) -> void:
	if not _active:
		return

	if event.is_action_pressed("ui_left"):
		get_viewport().set_input_as_handled()
		_go_back()


# --- Som e medidor --------------------------------------------

func _play_fx(stream: AudioStream) -> void:
	if stream == null:
		return
	_fx_player.stream = stream
	_fx_player.play()


func _process(delta: float) -> void:
	if not visible:
		return

	_meter_time += delta

	if _is_typing():
		_animate_meter()
		_voice_tick()
	else:
		_set_meter_idle()


## Barras sobem e descem enquanto alguem fala.
func _animate_meter() -> void:
	for i in range(_meter_bars.size()):
		var wave := 0.5 + 0.5 * sin(_meter_time * 18.0 + i * 0.9)
		var height := 6.0 + 34.0 * wave * randf_range(0.5, 1.0)
		_meter_bars[i].custom_minimum_size.y = height
		_meter_bars[i].color = CALL_COLOR if height > 14.0 else CALL_COLOR_DIM


func _set_meter_idle() -> void:
	for bar in _meter_bars:
		bar.custom_minimum_size.y = 6.0
		bar.color = CALL_COLOR_DIM


func _voice_tick() -> void:
	var shown := _text_label.visible_characters

	if shown <= _last_voiced:
		return

	_last_voiced = shown
	var now := Time.get_ticks_msec()

	if now - _last_voice_msec < VOICE_MIN_INTERVAL_MS:
		return

	var character := _text_label.text.substr(shown - 1, 1)

	if character.strip_edges().is_empty() or character in ".,;:!?…":
		return

	_last_voice_msec = now
	var base_pitch: float = _lines[_index].voice_pitch
	_voice_player.pitch_scale = base_pitch * randf_range(VOICE_PITCH_MIN, VOICE_PITCH_MAX)
	_voice_player.play()
