extends Control

## Batalha contra o chefe no fim de um cenario. O Assistente
## enfrenta uma anomalia respondendo perguntas sobre o tema:
## resposta certa, o Assistente ataca; resposta errada, o chefe
## revida. Se o Assistente perder, a luta recomeca.
##
## As falas (antes da luta, na metade, vitoria e derrota) usam
## o DialogueBox da partida. Durante as perguntas nao ha falas.
##
## Sem class_name de proposito: o Game carrega com preload().

signal finished

signal _answer_chosen(option_index: int)
signal _continue_pressed

const NETWORK_SHADER := preload("res://assets/shaders/network_background.gdshader")
const YAW_SHADER := preload("res://assets/shaders/sprite_yaw.gdshader")
const MATERIALIZE_SHADER := preload("res://assets/shaders/glitch_materialize.gdshader")
const ALARM_SOUND: AudioStream = preload("res://assets/audio/boss_alarm.wav")
const IMPACT_SOUND: AudioStream = preload("res://assets/audio/boss_impact.wav")

## Entrada do chefe: alerta piscando, materializacao com
## defeitos de imagem, impacto com tremor e a barra de vida
## enchendo. So depois vem a conversa.
const ENTRANCE_ALERT_BLINKS := 3
const ENTRANCE_MATERIALIZE := 1.0
const ENTRANCE_BAR_FILL := 0.6

## O Assistente olha para a anomalia: virado para a direita e
## levemente inclinado para frente.
const ASSISTANT_YAW := 0.28
const ASSISTANT_TILT_DEGREES := 6.0
const HIT_SOUND: AudioStream = preload("res://assets/audio/codec_static.wav")

## Palco no tamanho base da janela, sempre centralizado.
const STAGE_SIZE := Vector2(1152.0, 648.0)

const BOSS_SPRITE_SIZE := 224.0
const ASSISTANT_SPRITE_SIZE := 192.0
const HP_BAR_SIZE := Vector2(460.0, 18.0)
const OPTION_HEIGHT := 38.0

## Painel da pergunta: preso a borda de baixo, com a altura do
## conteudo. PANEL_TOP e o ponto mais alto que ele pode alcancar.
const PANEL_TOP := 300.0
const PANEL_BOTTOM_MARGIN := 12.0

const BOSS_COLOR := Color(1.0, 0.36, 0.36)
const ASSISTANT_COLOR := Color(0.2, 1.0, 0.45)

const PROJECTILE_DURATION := 0.28
const HP_TWEEN_DURATION := 0.4
const ANSWER_PAUSE := 0.9


var _boss: Resource
var _dialogue_box: DialogueBox

var _boss_hp := 0
var _assistant_hp := 0
var _question_queue: Array = []
var _phase_dialogue_shown := false
var _attempt := 0
var _awaiting_answer := false
var _option_order: Array[int] = []
var _current_question: Resource

var _stage: Control
var _boss_sprite: TextureRect
var _assistant_sprite: TextureRect
var _boss_name_label: Label
var _boss_bar: Control
var _assistant_bar: Control

var _question_panel: PanelContainer
var _question_label: Label
var _option_buttons: Array[Button] = []
var _result_label: Label
var _explanation_label: Label
var _continue_button: Button

var _hit_player: AudioStreamPlayer
var _fx_player: AudioStreamPlayer

var _boss_material: ShaderMaterial
var _entrance_band: PanelContainer
var _entrance_caption: Label
var _entrance_name: Label
var _flash: ColorRect



func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_interface()
	hide()


## Roda a batalha inteira, com as tentativas que forem
## necessarias. Termina com o chefe derrotado.
func play(boss: Resource, dialogue_box: DialogueBox) -> void:
	_boss = boss
	_dialogue_box = dialogue_box
	_attempt = 0

	_boss_name_label.text = str(boss.display_name).to_upper()
	_boss_sprite.texture = boss.sprite
	_assistant_sprite.texture = dialogue_box.character_texture

	_reset_fight()
	modulate.a = 0.0
	show()

	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 1.0, 0.4)
	await fade.finished

	SessionLogger.log_event("boss_start", {"boss": str(boss.id)})

	await _boss_entrance()

	if boss.intro_dialogue != null:
		await _run_dialogue(boss.intro_dialogue)

	while true:
		_attempt += 1
		var won: bool = await _fight()

		if won:
			break

		SessionLogger.log_event("boss_defeat", {
			"boss": str(boss.id),
			"attempt": _attempt,
		})

		if boss.defeat_dialogue != null:
			await _run_dialogue(boss.defeat_dialogue)

		_reset_fight()

	SessionLogger.log_event("boss_victory", {
		"boss": str(boss.id),
		"attempts": _attempt,
	})

	# Sai o painel da pergunta; fica so a cena da vitoria.
	_question_panel.hide()

	await _dissolve_boss()

	if boss.victory_dialogue != null:
		await _run_dialogue(boss.victory_dialogue)

	finished.emit()


# --- Montagem -------------------------------------------------

func _build_interface() -> void:
	var background := ColorRect.new()
	var material := ShaderMaterial.new()
	material.shader = NETWORK_SHADER
	# A Rede corrompida: a mesma trama do fundo dos dialogos,
	# em vermelho.
	material.set_shader_parameter("top_color", Color(0.07, 0.0, 0.02))
	material.set_shader_parameter("bottom_color", Color(0.1, 0.01, 0.04))
	material.set_shader_parameter("node_color", Color(1.0, 0.3, 0.4))
	material.set_shader_parameter("link_color", Color(0.75, 0.15, 0.4))
	background.material = material
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_stage = Control.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_stage.set_anchors_preset(Control.PRESET_CENTER)
	_stage.offset_left = -STAGE_SIZE.x / 2.0
	_stage.offset_top = -STAGE_SIZE.y / 2.0
	_stage.offset_right = STAGE_SIZE.x / 2.0
	_stage.offset_bottom = STAGE_SIZE.y / 2.0

	# Assistente: canto esquerdo.
	var assistant_name := _make_label("ASSISTENTE", 20, ASSISTANT_COLOR)
	_stage.add_child(assistant_name)
	assistant_name.position = Vector2(40.0, 20.0)
	_assistant_bar = _make_hp_bar(ASSISTANT_COLOR)
	_stage.add_child(_assistant_bar)
	_assistant_bar.position = Vector2(40.0, 52.0)

	_assistant_sprite = _make_sprite(ASSISTANT_SPRITE_SIZE)
	_assistant_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var yaw_material := ShaderMaterial.new()
	yaw_material.shader = YAW_SHADER
	yaw_material.set_shader_parameter("yaw", ASSISTANT_YAW)
	_assistant_sprite.material = yaw_material
	_assistant_sprite.rotation_degrees = ASSISTANT_TILT_DEGREES
	_stage.add_child(_assistant_sprite.get_parent())
	_assistant_sprite.get_parent().position = Vector2(90.0, 92.0)

	# Chefe: canto direito.
	_boss_name_label = _make_label("", 20, BOSS_COLOR)
	_boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_boss_name_label.size = Vector2(HP_BAR_SIZE.x, 28.0)
	_stage.add_child(_boss_name_label)
	_boss_name_label.position = Vector2(STAGE_SIZE.x - 40.0 - HP_BAR_SIZE.x, 20.0)
	_boss_bar = _make_hp_bar(BOSS_COLOR)
	_stage.add_child(_boss_bar)
	_boss_bar.position = Vector2(STAGE_SIZE.x - 40.0 - HP_BAR_SIZE.x, 52.0)

	_boss_sprite = _make_sprite(BOSS_SPRITE_SIZE)
	_boss_material = ShaderMaterial.new()
	_boss_material.shader = MATERIALIZE_SHADER
	_boss_material.set_shader_parameter("amount", 0.0)
	_boss_sprite.material = _boss_material
	_stage.add_child(_boss_sprite.get_parent())
	_boss_sprite.get_parent().position = Vector2(STAGE_SIZE.x - 70.0 - BOSS_SPRITE_SIZE, 72.0)

	_stage.add_child(_build_question_panel())

	_start_bob(_assistant_sprite, 0.0)
	_start_bob(_boss_sprite, 0.45)

	_build_entrance_overlay()

	_fx_player = AudioStreamPlayer.new()
	_fx_player.volume_db = -6.0
	add_child(_fx_player)

	_hit_player = AudioStreamPlayer.new()
	_hit_player.stream = HIT_SOUND
	_hit_player.volume_db = -12.0
	add_child(_hit_player)


## Faixa do alerta no meio da tela e o clarao vermelho do
## impacto. Ficam por cima do palco.
func _build_entrance_overlay() -> void:
	_flash = ColorRect.new()
	_flash.color = Color(BOSS_COLOR, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_entrance_band = PanelContainer.new()
	_entrance_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.0, 0.01, 0.92)
	style.border_color = BOSS_COLOR
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.set_content_margin_all(14.0)
	_entrance_band.add_theme_stylebox_override("panel", style)
	add_child(_entrance_band)
	_entrance_band.set_anchors_and_offsets_preset(Control.PRESET_HCENTER_WIDE)
	# Abaixo do centro, para nao cobrir o chefe se formando.
	_entrance_band.offset_top = 30.0
	_entrance_band.offset_bottom = 170.0

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_entrance_band.add_child(content)

	_entrance_caption = _make_label("", 22, BOSS_COLOR)
	_entrance_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_entrance_caption)

	_entrance_name = _make_label("", 52, Color.WHITE)
	_entrance_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_entrance_name.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	content.add_child(_entrance_name)

	_entrance_band.hide()


## Alerta, materializacao, impacto e barra de vida enchendo.
func _boss_entrance() -> void:
	var boss_name := str(_boss.display_name).to_upper()

	_boss_sprite.modulate.a = 0.0
	_boss_name_label.modulate.a = 0.0
	_boss_bar.modulate.a = 0.0
	_set_bar(_boss_bar, 0, int(_boss.max_hp), false)
	_boss_material.set_shader_parameter("amount", 1.0)

	# 1. Alerta piscando. So a faixa pisca, e devagar (cerca de
	# 3 vezes por segundo), para nao incomodar quem e sensivel
	# a luz piscando.
	_entrance_caption.text = "!  ANOMALIA DETECTADA  !"
	_entrance_name.text = ""
	_entrance_band.modulate.a = 1.0
	_entrance_band.show()
	_play_fx(ALARM_SOUND)

	var blink := create_tween()
	for i in range(ENTRANCE_ALERT_BLINKS):
		blink.tween_property(_entrance_caption, "modulate:a", 0.25, 0.15)
		blink.tween_property(_entrance_caption, "modulate:a", 1.0, 0.15)
	await blink.finished

	# 2. O nome e digitado enquanto o chefe se materializa.
	_entrance_name.text = boss_name
	_entrance_name.visible_characters = 0
	_hit_player.play()

	var appear := create_tween()
	appear.tween_property(
		_entrance_name, "visible_characters", boss_name.length(), 0.5
	)
	appear.parallel().tween_property(_boss_sprite, "modulate:a", 1.0, 0.25)
	appear.parallel().tween_property(
		_boss_material, "shader_parameter/amount", 0.0, ENTRANCE_MATERIALIZE
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_shake_stage(ENTRANCE_MATERIALIZE, 4.0)
	await appear.finished

	# 3. Impacto: o chefe "aterrissa", a tela treme e da um
	# unico clarao vermelho.
	_play_fx(IMPACT_SOUND)
	_boss_sprite.scale = Vector2.ONE * 1.25
	var impact := create_tween()
	impact.tween_property(_boss_sprite, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_flash.color.a = 0.35
	impact.parallel().tween_property(_flash, "color:a", 0.0, 0.4)
	_shake_stage(0.35, 12.0)

	# 4. Nome e barra de vida do chefe aparecem; a barra enche.
	impact.tween_property(_boss_name_label, "modulate:a", 1.0, 0.2)
	impact.parallel().tween_property(_boss_bar, "modulate:a", 1.0, 0.2)
	await impact.finished

	var fill: ColorRect = _boss_bar.get_node("Fill")
	var value_label: Label = _boss_bar.get_node("Value")
	var bar := create_tween()
	bar.tween_property(fill, "size:x", HP_BAR_SIZE.x, ENTRANCE_BAR_FILL) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	bar.parallel().tween_method(
		func(v: float) -> void: value_label.text = "%d / %d" % [roundi(v), int(_boss.max_hp)],
		0.0, float(_boss.max_hp), ENTRANCE_BAR_FILL
	)
	bar.tween_interval(0.4)
	bar.tween_property(_entrance_band, "modulate:a", 0.0, 0.3)
	await bar.finished

	_entrance_band.hide()


## Treme o palco por alguns instantes e volta ao lugar.
func _shake_stage(duration: float, strength: float) -> void:
	var origin := _stage.position
	var shake := _stage.create_tween()
	var steps := maxi(2, int(duration / 0.04))

	for i in range(steps):
		var falloff := 1.0 - float(i) / steps
		var offset := Vector2(
			randf_range(-strength, strength),
			randf_range(-strength, strength)
		) * falloff
		shake.tween_property(_stage, "position", origin + offset, 0.04)

	shake.tween_property(_stage, "position", origin, 0.04)


func _play_fx(stream: AudioStream) -> void:
	_fx_player.stream = stream
	_fx_player.play()


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Moldura fixa com o sprite dentro. O sprite flutua e treme
## dentro dela sem mexer no resto da tela.
func _make_sprite(sprite_size: float) -> TextureRect:
	var frame := Control.new()
	frame.size = Vector2(sprite_size, sprite_size)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sprite := TextureRect.new()
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.size = frame.size
	sprite.pivot_offset = frame.size / 2.0
	frame.add_child(sprite)

	return sprite


## Flutuacao continua. So pode comecar com o sprite na arvore.
func _start_bob(sprite: TextureRect, delay: float) -> void:
	var bob := sprite.create_tween().set_loops()
	bob.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_interval(delay)
	bob.tween_property(sprite, "position:y", -6.0, 0.9)
	bob.tween_property(sprite, "position:y", 0.0, 0.9)


## Barra de vida: fundo, preenchimento e o numero ao lado.
func _make_hp_bar(color: Color) -> Control:
	var bar := Control.new()
	bar.size = HP_BAR_SIZE
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var back := ColorRect.new()
	back.color = Color(color, 0.18)
	back.size = HP_BAR_SIZE
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(back)

	var fill := ColorRect.new()
	fill.name = "Fill"
	fill.color = color
	fill.size = HP_BAR_SIZE
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(fill)

	var value := _make_label("", 14, color)
	value.name = "Value"
	value.position = Vector2(0.0, HP_BAR_SIZE.y + 2.0)
	bar.add_child(value)

	return bar



func _build_question_panel() -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.92)
	style.border_color = BOSS_COLOR
	style.set_border_width_all(2)
	style.set_content_margin_all(16.0)
	panel.add_theme_stylebox_override("panel", style)
	_question_panel = panel
	panel.position = Vector2(60.0, PANEL_TOP)
	panel.size = Vector2(STAGE_SIZE.x - 120.0, 0.0)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	panel.add_child(content)

	_question_label = _make_label("", 18, UIPalette.TEXT)
	_question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_question_label)

	for i in range(4):
		var button := Button.new()
		button.custom_minimum_size = Vector2(0.0, OPTION_HEIGHT)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		# Sem quebra de linha: com ela, o Button calcula a altura
		# minima antes de saber a largura e o painel estica.
		# As alternativas cabem em uma linha.
		button.clip_text = true
		button.pressed.connect(_on_option_pressed.bind(i))
		content.add_child(button)
		_option_buttons.append(button)

	_explanation_label = _make_label("", 16, UIPalette.TEXT)
	_explanation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_explanation_label)

	# Resultado e botao na mesma linha, para caber tudo no painel.
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	content.add_child(footer)

	_result_label = _make_label("", 18, UIPalette.TEXT)
	_result_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(_result_label)

	_continue_button = Button.new()
	_continue_button.text = "Continuar"
	_continue_button.custom_minimum_size = Vector2(140.0, 36.0)
	_continue_button.pressed.connect(func() -> void: _continue_pressed.emit())
	footer.add_child(_continue_button)

	return panel


# --- Luta -----------------------------------------------------

func _reset_fight() -> void:
	_boss_hp = int(_boss.max_hp)
	_assistant_hp = int(_boss.assistant_max_hp)
	_phase_dialogue_shown = false
	_question_queue.clear()

	_boss_sprite.modulate = Color.WHITE
	_boss_sprite.scale = Vector2.ONE
	_boss_material.set_shader_parameter("amount", 0.0)
	_assistant_sprite.modulate = Color.WHITE

	_set_bar(_boss_bar, _boss_hp, int(_boss.max_hp), false)
	_set_bar(_assistant_bar, _assistant_hp, int(_boss.assistant_max_hp), false)
	# O painel so aparece com a primeira pergunta, depois das
	# falas de abertura.
	_question_panel.hide()
	_question_label.text = ""
	_clear_question()


## Pergunta atras de pergunta ate alguem ficar sem vida.
## Devolve true se o chefe foi derrotado.
func _fight() -> bool:
	while true:
		await _ask_question()

		if _boss_hp <= 0:
			return true

		if _assistant_hp <= 0:
			return false

		var half := int(_boss.max_hp) / 2.0
		if (
			not _phase_dialogue_shown
			and _boss_hp <= half
			and _boss.phase_dialogue != null
		):
			_phase_dialogue_shown = true
			await _run_dialogue(_boss.phase_dialogue)

	return false


func _next_question() -> Resource:
	if _question_queue.is_empty():
		_question_queue = _boss.questions.duplicate()
		_question_queue.shuffle()

	return _question_queue.pop_back()


func _ask_question() -> void:
	var question: Resource = _next_question()

	if question == null:
		push_warning("Chefe '%s' sem perguntas." % _boss.id)
		_boss_hp = 0
		return

	_current_question = question
	_clear_question()
	_question_label.text = question.prompt
	_show_question_panel()

	# Embaralha a ordem na tela. _option_order[i] guarda o indice
	# original da alternativa mostrada no botao i.
	_option_order.clear()
	for i in range(question.options.size()):
		_option_order.append(i)
	_option_order.shuffle()

	for i in range(_option_buttons.size()):
		var button := _option_buttons[i]
		if i < _option_order.size():
			button.text = "%d)  %s" % [i + 1, question.options[_option_order[i]]]
			button.show()
			button.disabled = false
		else:
			button.hide()

	_fit_question_panel.call_deferred()
	_awaiting_answer = true
	_option_buttons[0].grab_focus()

	var chosen_button: int = await _answer_chosen
	_awaiting_answer = false

	var chosen: int = _option_order[chosen_button]
	var correct: bool = chosen == int(question.correct_index)

	SessionLogger.log_event("boss_answer", {
		"boss": str(_boss.id),
		"question": str(question.id),
		"correct": correct,
		"attempt": _attempt,
	})

	_show_answer_marks(chosen_button, question)

	if correct:
		await _assistant_attacks()
	else:
		await _boss_attacks()

	await get_tree().create_timer(ANSWER_PAUSE * 0.4, false).timeout

	if correct:
		_result_label.text = "Correto!"
		_result_label.add_theme_color_override("font_color", ASSISTANT_COLOR)
	else:
		# A alternativa certa ja aparece marcada em verde.
		_result_label.text = "Incorreto. A resposta certa está marcada em verde."
		_result_label.add_theme_color_override("font_color", BOSS_COLOR)

	_result_label.show()
	_explanation_label.text = question.explanation
	_explanation_label.show()
	_continue_button.show()
	_fit_question_panel.call_deferred()
	_continue_button.grab_focus()

	await _continue_pressed


## Ajusta a altura do painel ao conteudo e o mantem colado na
## borda de baixo: com as quatro alternativas ou com a
## explicacao, nao sobra espaco vazio embaixo.
func _fit_question_panel() -> void:
	var height: float = _question_panel.get_combined_minimum_size().y
	height = minf(height, STAGE_SIZE.y - PANEL_BOTTOM_MARGIN - PANEL_TOP)
	_question_panel.size = Vector2(_question_panel.size.x, height)
	_question_panel.position.y = STAGE_SIZE.y - PANEL_BOTTOM_MARGIN - height


func _clear_question() -> void:
	for button in _option_buttons:
		button.remove_theme_stylebox_override("normal")
		button.remove_theme_stylebox_override("disabled")
		button.remove_theme_color_override("font_disabled_color")
		button.show()
		button.disabled = true
	_result_label.hide()
	_explanation_label.hide()
	_continue_button.hide()


## Depois da resposta ficam so a escolhida e a correta, em
## vermelho e verde. As outras somem para dar espaco a
## explicacao.
func _show_answer_marks(chosen_button: int, question: Resource) -> void:
	for i in range(_option_buttons.size()):
		var button := _option_buttons[i]
		button.disabled = true

		if i >= _option_order.size():
			continue

		var is_correct: bool = _option_order[i] == int(question.correct_index)
		var is_chosen: bool = i == chosen_button

		if is_correct:
			_paint_option(button, ASSISTANT_COLOR)
		elif is_chosen:
			_paint_option(button, BOSS_COLOR)
		else:
			button.hide()

	_fit_question_panel.call_deferred()


func _paint_option(button: Button, color: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(color, 0.15)
	box.border_color = color
	box.set_border_width_all(2)
	box.set_content_margin_all(8.0)
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("disabled", box)
	button.add_theme_color_override("font_disabled_color", color)


func _on_option_pressed(button_index: int) -> void:
	if _awaiting_answer:
		_answer_chosen.emit(button_index)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not _awaiting_answer:
		return

	# Teclas 1 a 4 escolhem a alternativa.
	if event is InputEventKey and event.pressed and not event.echo:
		var number: int = event.keycode - KEY_1
		if number >= 0 and number < _option_order.size():
			get_viewport().set_input_as_handled()
			_answer_chosen.emit(number)


# --- Ataques --------------------------------------------------

func _assistant_attacks() -> void:
	await _shoot(_assistant_sprite, _boss_sprite, ASSISTANT_COLOR)
	_boss_hp = maxi(0, _boss_hp - int(_boss.damage_per_correct))
	_hurt(_boss_sprite, int(_boss.damage_per_correct))
	_set_bar(_boss_bar, _boss_hp, int(_boss.max_hp), true)


func _boss_attacks() -> void:
	await _shoot(_boss_sprite, _assistant_sprite, BOSS_COLOR)
	_assistant_hp = maxi(0, _assistant_hp - int(_boss.damage_per_wrong))
	_hurt(_assistant_sprite, int(_boss.damage_per_wrong))
	_set_bar(_assistant_bar, _assistant_hp, int(_boss.assistant_max_hp), true)


## Um bloco de pixels voa de um sprite ate o outro.
func _shoot(from: Control, to: Control, color: Color) -> void:
	var start: Vector2 = from.get_global_rect().get_center() - _stage.global_position
	var end: Vector2 = to.get_global_rect().get_center() - _stage.global_position

	for k in range(3):
		var bolt := ColorRect.new()
		bolt.color = color
		bolt.size = Vector2(14.0, 14.0) * (1.0 - k * 0.25)
		bolt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bolt.modulate.a = 1.0 - k * 0.3
		_stage.add_child(bolt)
		bolt.position = start - bolt.size / 2.0

		var tween := bolt.create_tween()
		tween.tween_interval(k * 0.04)
		tween.tween_property(bolt, "position", end - bolt.size / 2.0, PROJECTILE_DURATION) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(bolt.queue_free)

	await get_tree().create_timer(PROJECTILE_DURATION + 0.08, false).timeout


## Tremor, lampejo vermelho e o numero do dano subindo.
func _hurt(target: TextureRect, amount: int) -> void:
	_hit_player.play()

	var shake := target.create_tween()
	for offset in [12.0, -10.0, 7.0, -4.0, 0.0]:
		shake.tween_property(target, "position:x", offset, 0.04)

	target.modulate = Color(1.0, 0.25, 0.25)
	var flash := target.create_tween()
	flash.tween_property(target, "modulate", Color.WHITE, 0.35)

	var number := _make_label("-%d" % amount, 32, Color(1.0, 0.9, 0.3))
	number.add_theme_color_override("font_outline_color", Color.BLACK)
	number.add_theme_constant_override("outline_size", 8)
	_stage.add_child(number)
	var center: Vector2 = target.get_global_rect().get_center() - _stage.global_position
	number.position = center + Vector2(-20.0, -40.0)

	var rise := number.create_tween()
	rise.tween_property(number, "position:y", number.position.y - 50.0, 0.8) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	rise.parallel().tween_property(number, "modulate:a", 0.0, 0.8).set_delay(0.3)
	rise.tween_callback(number.queue_free)


func _set_bar(bar: Control, value: int, maximum: int, animate: bool) -> void:
	var fill: ColorRect = bar.get_node("Fill")
	var width: float = HP_BAR_SIZE.x * clampf(float(value) / maxf(1.0, maximum), 0.0, 1.0)
	var value_label: Label = bar.get_node("Value")
	value_label.text = "%d / %d" % [value, maximum]

	if animate:
		var tween := fill.create_tween()
		tween.tween_property(fill, "size:x", width, HP_TWEEN_DURATION) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		fill.size.x = width


## O chefe derrotado pisca, se desfaz na horizontal e some.
func _dissolve_boss() -> void:
	_hit_player.play()

	var tween := _boss_sprite.create_tween()
	# O mesmo efeito da entrada, ao contrario: o chefe se
	# desfaz em blocos vermelhos.
	tween.tween_property(_boss_material, "shader_parameter/amount", 1.0, 0.6)
	for i in range(3):
		tween.parallel().tween_property(_boss_sprite, "modulate:a", 0.4, 0.1).set_delay(i * 0.2)
	tween.tween_property(_boss_sprite, "scale", Vector2(1.6, 0.0), 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tween.finished
	await get_tree().create_timer(0.3, false).timeout


# --- Falas ----------------------------------------------------

## Mostra o painel com um fade curto, se estiver escondido.
func _show_question_panel() -> void:
	if _question_panel.visible:
		return

	_question_panel.modulate.a = 0.0
	_question_panel.show()
	var fade := _question_panel.create_tween()
	fade.tween_property(_question_panel, "modulate:a", 1.0, 0.2)


## Durante as falas o painel sai de cena; a proxima pergunta
## o traz de volta.
func _run_dialogue(dialogue: DialogueData) -> void:
	_question_panel.hide()
	_dialogue_box.show_dialogue_data(dialogue, 0.45)
	await _dialogue_box.finished
