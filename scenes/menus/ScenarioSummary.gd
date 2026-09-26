extends Control
class_name ScenarioSummary

## Tela exibida ao concluir um cenario. Reune as praticas
## que apareceram nele e marca como "Nova" as cartas que
## entraram na enciclopedia durante este cenario.

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

var _title_label: Label
var _subtitle_label: Label
var _grid: GridContainer
var _details_panel: CardDetailsPanel
var _continue_button: Button


func _ready() -> void:
	_build_interface()
	hide()


## Preenche e exibe a tela. seen_ids segue a ordem em que
## as cartas apareceram; new_ids contem as que foram
## desbloqueadas pela primeira vez neste cenario.
func show_summary(
	scenario_name: String,
	seen_ids: Array[String],
	new_ids: Array[String]
) -> void:
	_title_label.text = "Cenário concluído: %s" % scenario_name

	var new_amount := 0

	for card_id: String in seen_ids:
		if card_id in new_ids:
			new_amount += 1

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

	show()
	_continue_button.grab_focus()


func _build_interface() -> void:
	var background := ColorRect.new()
	add_child(background)
	background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	background.color = UIPalette.BACKGROUND
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
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
	left_column.add_child(footer)

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
	continue_requested.emit()
