extends Control
class_name ScenarioSummary

## Tela exibida ao concluir um cenario. Abre com os parabens
## e os numeros do cenario: pontuacao, brechas abertas e
## corrigidas e tempo. Um botao leva a lista das praticas que
## apareceram no cenario, com as cartas novas marcadas.

signal continue_requested

const CARD_DETAILS_PANEL_SCENE := preload(
	"res://scenes/cards/CardDetailsPanel.tscn"
)

const COLUMNS := 3
const CARD_SEPARATION := 16
const OUTER_MARGIN := 24
const DETAILS_COLUMN_WIDTH := 420.0

## Mesma folga da enciclopedia, para a carta crescer no
## hover sem ser recortada pelo ScrollContainer.
const HOVER_MARGIN_HORIZONTAL := 12
const HOVER_MARGIN_VERTICAL := 16

const NEW_BADGE_TEXT := "Nova"
const NEW_BADGE_COLOR := Color(0.92, 0.8, 0.0)
const NEW_BADGE_HEIGHT := 22.0

## Quadros de numeros da tela de parabens.
const STAT_TILE_WIDTH := 190.0
const STAT_ICON_SIZE := 32.0
const STAT_VALUE_SIZE := 34
const STAT_COUNT_DURATION := 0.7
const STAT_TILE_STAGGER := 0.15
const TITLE_POP_DURATION := 0.35

var _stats_view: Control
var _cards_view: Control

var _stats_subtitle: Label
var _stats_details: Label
var _stats_title: Label
var _stat_tiles: Array[Control] = []
var _score_value: Label
var _opened_value: Label
var _closed_value: Label
var _time_value: Label
var _opened_tile_style: StyleBoxFlat
var _cards_button: Button
var _stats_continue_button: Button

var _title_label: Label
var _subtitle_label: Label
var _grid: GridContainer
var _details_panel: CardDetailsPanel
var _continue_button: Button
var _stats_tween: Tween


func _ready() -> void:
	_build_interface()
	hide()


## Preenche e exibe a tela. seen_ids segue a ordem em que
## as cartas apareceram; new_ids contem as que foram
## desbloqueadas pela primeira vez neste cenario. stats vem
## do Game (_build_scenario_stats).
func show_summary(
	scenario_name: String,
	seen_ids: Array[String],
	new_ids: Array[String],
	stats: Dictionary = {}
) -> void:
	var new_amount := 0

	for card_id: String in seen_ids:
		if card_id in new_ids:
			new_amount += 1

	_fill_stats(scenario_name, stats, new_amount)
	_fill_cards(scenario_name, seen_ids, new_ids, new_amount)

	_cards_button.disabled = seen_ids.is_empty()

	_show_stats_view()
	show()
	_animate_stats(stats)
	_stats_continue_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return

	# Na lista de cartas, ESC volta para os numeros.
	if _cards_view.visible:
		_show_stats_view()
		get_viewport().set_input_as_handled()


# --- Tela de parabens -----------------------------------------

func _fill_stats(
	scenario_name: String,
	stats: Dictionary,
	new_amount: int
) -> void:
	_stats_subtitle.text = (
		"Você concluiu o cenário %s." % scenario_name
	)

	# Brechas abertas ganham borda vermelha quando houve alguma.
	var opened := int(stats.get("breaches_opened", 0))
	_opened_tile_style.border_color = (
		UIPalette.DANGER_DIM if opened > 0 else UIPalette.DIM
	)
	_opened_value.add_theme_color_override(
		"font_color",
		UIPalette.DANGER if opened > 0 else UIPalette.PRIMARY
	)

	# Cada informacao extra vira uma frase curta, uma por linha.
	var details: Array[String] = []

	if bool(stats.get("has_boss", false)):
		details.append(_boss_sentence(
			int(stats.get("boss_correct", 0)),
			int(stats.get("boss_wrong", 0))
		))

	var retries := int(stats.get("retries", 0))

	if retries == 1:
		details.append("Uma rodada precisou ser refeita.")
	elif retries > 1:
		details.append("%d rodadas precisaram ser refeitas." % retries)

	if new_amount == 1:
		details.append("Uma carta nova entrou na Enciclopédia.")
	elif new_amount > 1:
		details.append(
			"%d cartas novas entraram na Enciclopédia." % new_amount
		)

	_stats_details.text = "\n".join(details)
	_stats_details.visible = not details.is_empty()


func _boss_sentence(correct: int, wrong: int) -> String:
	var hits := _plural(correct, "pergunta", "perguntas")

	if wrong == 0:
		return "Contra o chefe, você acertou %s sem nenhum erro." % hits

	return "Contra o chefe, você acertou %s e errou %d." % [hits, wrong]


## Os numeros sobem de zero, um quadro depois do outro.
func _animate_stats(stats: Dictionary) -> void:
	if _stats_tween != null and _stats_tween.is_valid():
		_stats_tween.kill()

	_score_value.text = "0"
	_opened_value.text = "0"
	_closed_value.text = "0"
	_time_value.text = _format_time(0.0)

	_stats_title.scale = Vector2.ONE * 0.7
	_stats_title.modulate.a = 0.0

	for tile in _stat_tiles:
		tile.modulate.a = 0.0

	_stats_tween = create_tween()
	_stats_tween.tween_property(
		_stats_title, "modulate:a", 1.0, TITLE_POP_DURATION
	)
	_stats_tween.parallel().tween_property(
		_stats_title, "scale", Vector2.ONE, TITLE_POP_DURATION
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var targets := [
		[_score_value, float(stats.get("score", 0.0)), false],
		[_opened_value, float(stats.get("breaches_opened", 0)), false],
		[_closed_value, float(stats.get("breaches_closed", 0)), false],
		[_time_value, float(stats.get("seconds", 0.0)), true],
	]

	for i in range(_stat_tiles.size()):
		var tile := _stat_tiles[i]
		var label: Label = targets[i][0]
		var target: float = targets[i][1]
		var is_time: bool = targets[i][2]

		_stats_tween.tween_property(
			tile, "modulate:a", 1.0, STAT_TILE_STAGGER
		)
		_stats_tween.parallel().tween_method(
			_set_stat_text.bind(label, is_time),
			0.0,
			target,
			STAT_COUNT_DURATION
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


func _set_stat_text(value: float, label: Label, is_time: bool) -> void:
	if is_time:
		label.text = _format_time(value)
	else:
		label.text = "%d" % roundi(value)


func _format_time(seconds: float) -> String:
	var total := int(seconds)
	var hours := total / 3600
	var minutes := (total % 3600) / 60
	var secs := total % 60

	if hours > 0:
		return "%d:%02d:%02d" % [hours, minutes, secs]

	return "%d:%02d" % [minutes, secs]


func _plural(amount: int, singular: String, plural: String) -> String:
	return "%d %s" % [amount, singular if amount == 1 else plural]


func _show_stats_view() -> void:
	_cards_view.hide()
	_details_panel.hide_card()
	_stats_view.show()
	_stats_continue_button.grab_focus()


func _show_cards_view() -> void:
	_stats_view.hide()
	_cards_view.show()
	_continue_button.grab_focus()


# --- Lista de cartas ------------------------------------------

func _fill_cards(
	scenario_name: String,
	seen_ids: Array[String],
	new_ids: Array[String],
	new_amount: int
) -> void:
	_title_label.text = "Cartas do cenário: %s" % scenario_name

	if new_amount == 0:
		_subtitle_label.text = (
			"Práticas que apareceram neste cenário."
		)
	elif new_amount == 1:
		_subtitle_label.text = (
			"Práticas deste cenário. 1 carta nova foi "
			+ "adicionada à enciclopédia."
		)
	else:
		_subtitle_label.text = (
			"Práticas deste cenário. %d cartas novas foram "
			+ "adicionadas à enciclopédia."
		) % new_amount

	for child in _grid.get_children():
		child.queue_free()

	_details_panel.hide_card()

	for card_id: String in seen_ids:
		_add_card_cell(card_id, card_id in new_ids)


# --- Montagem -------------------------------------------------

func _build_interface() -> void:
	var background := ColorRect.new()
	add_child(background)
	background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	background.color = UIPalette.BACKGROUND
	background.material = UIPalette.make_background_material()
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_stats_view = _build_stats_view()
	add_child(_stats_view)
	_stats_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_cards_view = _build_cards_view()
	add_child(_cards_view)
	_cards_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cards_view.hide()


func _build_stats_view() -> Control:
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	center.add_child(column)

	var caption := _make_centered_label("CENÁRIO CONCLUÍDO", 16)
	caption.add_theme_color_override("font_color", UIPalette.DIM.lightened(0.3))
	column.add_child(caption)

	_stats_title = _make_centered_label("Parabéns!", 48)
	_stats_title.add_theme_color_override("font_color", UIPalette.PRIMARY)
	# A animacao de entrada cresce a partir do centro.
	_stats_title.resized.connect(
		func() -> void: _stats_title.pivot_offset = _stats_title.size / 2.0
	)
	column.add_child(_stats_title)

	_stats_subtitle = _make_centered_label("", 18)
	column.add_child(_stats_subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 8.0)
	column.add_child(spacer)

	var tiles := HBoxContainer.new()
	tiles.alignment = BoxContainer.ALIGNMENT_CENTER
	tiles.add_theme_constant_override("separation", 16)
	column.add_child(tiles)

	_score_value = _add_stat_tile(
		tiles, UIPalette.ICON_SCORE, "Pontuação total"
	)
	_opened_value = _add_stat_tile(
		tiles, UIPalette.ICON_BREACH, "Brechas abertas"
	)
	# O quadro das brechas abertas muda de cor; guarda a caixa.
	_opened_tile_style = (
		_stat_tiles[1].get_theme_stylebox("panel") as StyleBoxFlat
	)
	_closed_value = _add_stat_tile(
		tiles, UIPalette.ICON_LOCK_CLOSED, "Brechas corrigidas"
	)
	_time_value = _add_stat_tile(
		tiles, UIPalette.ICON_CLOCK, "Tempo no cenário"
	)

	_stats_details = _make_centered_label("", 15)
	_stats_details.add_theme_constant_override("line_spacing", 6)
	_stats_details.add_theme_color_override(
		"font_color", UIPalette.TEXT.darkened(0.1)
	)
	column.add_child(_stats_details)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	column.add_child(buttons)

	_cards_button = Button.new()
	_cards_button.text = "Ver cartas do cenário"
	_cards_button.custom_minimum_size = Vector2(260.0, 44.0)
	UIPalette.set_button_icon(_cards_button, UIPalette.ICON_ENCYCLOPEDIA)
	_cards_button.pressed.connect(_show_cards_view)
	buttons.add_child(_cards_button)

	_stats_continue_button = Button.new()
	_stats_continue_button.text = "Continuar"
	_stats_continue_button.custom_minimum_size = Vector2(160.0, 44.0)
	_stats_continue_button.pressed.connect(_on_continue_pressed)
	buttons.add_child(_stats_continue_button)

	return center


func _make_centered_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	return label


## Cria um quadro com icone, numero e legenda. Devolve o
## Label do numero, que a animacao preenche.
func _add_stat_tile(
	parent: Container,
	icon: Texture2D,
	caption: String
) -> Label:
	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(STAT_TILE_WIDTH, 0.0)

	var style := StyleBoxFlat.new()
	style.bg_color = UIPalette.PANEL
	style.border_color = UIPalette.DIM
	style.set_border_width_all(2)
	style.set_content_margin_all(14)
	tile.add_theme_stylebox_override("panel", style)
	parent.add_child(tile)
	_stat_tiles.append(tile)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 6)
	tile.add_child(column)

	var pixel_icon := UIPalette.make_pixel_icon(icon, STAT_ICON_SIZE)
	pixel_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(pixel_icon)

	var value := _make_centered_label("0", STAT_VALUE_SIZE)
	value.add_theme_color_override("font_color", UIPalette.PRIMARY)
	value.add_theme_font_override("font", UIPalette.TEXT_FONT_BOLD)
	column.add_child(value)

	var label := _make_centered_label(caption, 14)
	column.add_child(label)

	return value


func _build_cards_view() -> Control:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", OUTER_MARGIN)
	margin.add_theme_constant_override("margin_top", OUTER_MARGIN)
	margin.add_theme_constant_override("margin_right", OUTER_MARGIN)
	margin.add_theme_constant_override("margin_bottom", OUTER_MARGIN)

	var columns_box := HBoxContainer.new()
	columns_box.add_theme_constant_override("separation", OUTER_MARGIN)
	margin.add_child(columns_box)

	var left_column := VBoxContainer.new()
	left_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_column.add_theme_constant_override("separation", 12)
	columns_box.add_child(left_column)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 30)
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left_column.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.add_theme_font_size_override("font_size", 16)
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left_column.add_child(_subtitle_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
	)
	left_column.add_child(scroll)

	var scroll_margin := MarginContainer.new()
	scroll_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_margin.add_theme_constant_override(
		"margin_left",
		HOVER_MARGIN_HORIZONTAL
	)
	scroll_margin.add_theme_constant_override(
		"margin_right",
		HOVER_MARGIN_HORIZONTAL
	)
	scroll_margin.add_theme_constant_override(
		"margin_top",
		HOVER_MARGIN_VERTICAL
	)
	scroll_margin.add_theme_constant_override(
		"margin_bottom",
		HOVER_MARGIN_VERTICAL
	)
	scroll.add_child(scroll_margin)

	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", CARD_SEPARATION)
	_grid.add_theme_constant_override("v_separation", CARD_SEPARATION)
	scroll_margin.add_child(_grid)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	left_column.add_child(footer)

	var back_button := Button.new()
	back_button.text = "Voltar ao resumo"
	back_button.custom_minimum_size = Vector2(200.0, 44.0)
	back_button.pressed.connect(_show_stats_view)
	footer.add_child(back_button)

	var footer_spacer := Control.new()
	footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(footer_spacer)

	_continue_button = Button.new()
	_continue_button.text = "Continuar"
	_continue_button.custom_minimum_size = Vector2(160.0, 44.0)
	_continue_button.pressed.connect(_on_continue_pressed)
	footer.add_child(_continue_button)

	var details_column := Control.new()
	details_column.custom_minimum_size = Vector2(
		DETAILS_COLUMN_WIDTH,
		0.0
	)
	details_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns_box.add_child(details_column)

	_details_panel = (
		CARD_DETAILS_PANEL_SCENE.instantiate()
		as CardDetailsPanel
	)
	details_column.add_child(_details_panel)

	return margin


func _add_card_cell(card_id: String, is_new: bool) -> void:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 4)
	_grid.add_child(cell)

	# A etiqueta existe mesmo vazia, para as cartas da
	# mesma linha ficarem alinhadas.
	var badge := Label.new()
	badge.custom_minimum_size = Vector2(0.0, NEW_BADGE_HEIGHT)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 16)
	badge.add_theme_color_override("font_color", NEW_BADGE_COLOR)

	if is_new:
		badge.text = NEW_BADGE_TEXT

	cell.add_child(badge)

	var card: Card = CardFactory.instantiate_card(card_id)

	if card == null:
		return

	card.details_requested.connect(_on_card_details_requested)
	card.details_hidden.connect(_on_card_details_hidden)
	cell.add_child(card)

	# Deixa a roda do mouse chegar no ScrollContainer.
	card.set_mouse_passthrough(true)


func _on_card_details_requested(card: Card) -> void:
	if card == null or card.data == null:
		return

	_details_panel.show_card(card.data)


func _on_card_details_hidden(_card: Card) -> void:
	_details_panel.hide_card()


func _on_continue_pressed() -> void:
	if _stats_tween != null and _stats_tween.is_valid():
		_stats_tween.kill()

	continue_requested.emit()
