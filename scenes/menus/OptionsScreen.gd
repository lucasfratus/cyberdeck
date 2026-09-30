extends Control

## Tela de opcoes: audio e acessibilidade. Aberta pelo menu
## principal e pelo menu de pausa. As mudancas valem na hora
## e ficam salvas pelo autoload GameSettings.
##
## Sem class_name de proposito: quem usa carrega com preload()
## e cria com new(), como a tela "Como jogar".

signal closed

const OUTER_MARGIN := 24
const CONTENT_WIDTH := 640.0
const LABEL_WIDTH := 240.0
const SECTION_FONT_SIZE := 22
const NOTE_FONT_SIZE := 14

## Amostras de cor para conferir a correcao: as cores que o
## jogo usa para pratica segura, pratica insegura e destaque.
const SWATCHES := [
	["Prática segura", UIPalette.PRIMARY],
	["Prática insegura", UIPalette.DANGER],
	["Pontuação", Color(0.92, 0.8, 0.0)],
	["Multiplicador", Color(0.55, 0.85, 1.0)],
]

var _volume_slider: HSlider
var _volume_value: Label
var _colorblind_option: OptionButton
var _intensity_slider: HSlider
var _intensity_value: Label


func _ready() -> void:
	_build_interface()
	hide()


## Atualiza os controles com os valores salvos. Chamar antes
## de mostrar a tela.
func refresh() -> void:
	_volume_slider.set_value_no_signal(GameSettings.master_volume * 100.0)
	_colorblind_option.select(GameSettings.colorblind_mode)
	_intensity_slider.set_value_no_signal(GameSettings.colorblind_intensity * 100.0)
	_update_labels()


func _build_interface() -> void:
	var background := ColorRect.new()
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = UIPalette.BACKGROUND
	background.material = UIPalette.make_background_material()

	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, OUTER_MARGIN)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	column.add_child(header)

	header.add_child(UIPalette.make_pixel_icon(UIPalette.ICON_OPTIONS, 32.0))

	var title := Label.new()
	title.text = "Opções"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 32)
	header.add_child(title)

	var close_button := Button.new()
	close_button.text = "Fechar"
	close_button.pressed.connect(_on_close_pressed)
	header.add_child(close_button)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)

	var body := VBoxContainer.new()
	body.custom_minimum_size = Vector2(CONTENT_WIDTH, 0.0)
	body.add_theme_constant_override("separation", 14)
	center.add_child(body)

	_build_audio_section(body)
	_build_accessibility_section(body)


# --- Audio ----------------------------------------------------

func _build_audio_section(body: VBoxContainer) -> void:
	body.add_child(_make_section_title("Áudio"))

	var volume_row := _make_row(body, "Volume geral")
	_volume_slider = _make_slider(volume_row)
	_volume_slider.value_changed.connect(_on_volume_changed)
	_volume_value = _make_value_label(volume_row)

	# A musica ainda nao existe no jogo: a linha fica visivel e
	# desativada, para o lugar ja estar reservado.
	var music_row := _make_row(body, "Música")
	var music_slider := _make_slider(music_row)
	music_slider.editable = false
	music_slider.value = 100.0
	var music_note := _make_value_label(music_row)
	music_note.text = "em breve"


func _on_volume_changed(value: float) -> void:
	GameSettings.set_master_volume(value / 100.0)
	_update_labels()


# --- Acessibilidade -------------------------------------------

func _build_accessibility_section(body: VBoxContainer) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 8.0)
	body.add_child(spacer)

	body.add_child(_make_section_title("Acessibilidade"))

	var mode_row := _make_row(body, "Modo para daltonismo")
	_colorblind_option = OptionButton.new()
	_colorblind_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	for mode_name: String in GameSettings.COLORBLIND_MODES:
		_colorblind_option.add_item(mode_name)

	_colorblind_option.item_selected.connect(_on_colorblind_mode_selected)
	mode_row.add_child(_colorblind_option)

	var intensity_row := _make_row(body, "Intensidade da correção")
	_intensity_slider = _make_slider(intensity_row)
	_intensity_slider.value_changed.connect(_on_intensity_changed)
	_intensity_value = _make_value_label(intensity_row)

	body.add_child(_make_note(
		"A correção reforça a diferença entre as cores que se "
		+ "confundem no tipo de daltonismo escolhido. Ela vale para "
		+ "todas as telas. As amostras abaixo mostram as cores "
		+ "usadas no jogo."
	))

	var swatches := HBoxContainer.new()
	swatches.add_theme_constant_override("separation", 12)
	body.add_child(swatches)

	for swatch: Array in SWATCHES:
		swatches.add_child(_make_swatch(swatch[0], swatch[1]))


func _on_colorblind_mode_selected(index: int) -> void:
	GameSettings.set_colorblind_mode(index)
	_update_labels()


func _on_intensity_changed(value: float) -> void:
	GameSettings.set_colorblind_intensity(value / 100.0)
	_update_labels()


func _update_labels() -> void:
	_volume_value.text = "%d%%" % roundi(_volume_slider.value)
	_intensity_value.text = "%d%%" % roundi(_intensity_slider.value)

	# Sem modo escolhido, a intensidade nao tem efeito.
	var mode_on := _colorblind_option.selected > 0
	_intensity_slider.editable = mode_on
	_intensity_slider.modulate.a = 1.0 if mode_on else 0.5


# --- Pecas da interface ---------------------------------------

func _make_section_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", SECTION_FONT_SIZE)
	label.add_theme_color_override("font_color", UIPalette.PRIMARY)
	return label


func _make_row(body: VBoxContainer, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	body.add_child(row)

	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(LABEL_WIDTH, 0.0)
	row.add_child(label)

	return row


func _make_slider(row: HBoxContainer) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 5.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	return slider


func _make_value_label(row: HBoxContainer) -> Label:
	var label := Label.new()
	label.custom_minimum_size = Vector2(80.0, 0.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(label)
	return label


func _make_note(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(CONTENT_WIDTH, 0.0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", NOTE_FONT_SIZE)
	label.add_theme_color_override("font_color", UIPalette.TEXT.darkened(0.15))
	return label


func _make_swatch(text: String, color: Color) -> Control:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)

	var sample := ColorRect.new()
	sample.color = color
	sample.custom_minimum_size = Vector2(0.0, 36.0)
	box.add_child(sample)

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", NOTE_FONT_SIZE)
	box.add_child(label)

	return box


func _on_close_pressed() -> void:
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return

	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()
