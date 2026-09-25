extends Control
class_name Encyclopedia

## Tela de consulta das cartas, agrupadas por tema de
## seguranca. Cartas que o jogador ainda nao encontrou
## aparecem com os campos preenchidos por "?".

signal closed

const CARD_DETAILS_PANEL_SCENE := preload(
	"res://scenes/cards/CardDetailsPanel.tscn"
)

const COLUMNS := 3
const CARD_SEPARATION := 16
const SECTION_SEPARATION := 24
const OUTER_MARGIN := 24
const DETAILS_COLUMN_WIDTH := 420.0

## Folga para a carta crescer no hover sem ser recortada
## pelo ScrollContainer. A carta tem 180x252 e cresce
## 8%, ou seja 7px na horizontal e 11px na vertical.
const HOVER_MARGIN_HORIZONTAL := 12
const HOVER_MARGIN_VERTICAL := 16

var _sections: VBoxContainer
var _details_panel: CardDetailsPanel
var _counter_label: Label


func _ready() -> void:
	_build_interface()
	refresh()


## Remonta a lista. Chamar ao reabrir a tela, para
## refletir cartas encontradas depois da ultima abertura.
func refresh() -> void:
	if _sections == null:
		return

	for child in _sections.get_children():
		child.queue_free()

	if _details_panel != null:
		_details_panel.hide_card()

	_populate_sections()


func _build_interface() -> void:
	var background := ColorRect.new()
	add_child(background)
	background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	background.color = Color(0.04, 0.05, 0.08)
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
	left_column.add_theme_constant_override("separation", 16)
	columns_box.add_child(left_column)

	left_column.add_child(_build_header())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
	)
	left_column.add_child(scroll)

	# O ScrollContainer recorta o que passa do retangulo
	# visivel. Esta margem da folga para a carta crescer
	# no hover sem ter os cantos cortados.
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

	_sections = VBoxContainer.new()
	_sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sections.add_theme_constant_override(
		"separation",
		SECTION_SEPARATION
	)
	scroll_margin.add_child(_sections)

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


func _build_header() -> Control:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)

	var title_label := Label.new()
	title_label.text = "Enciclopédia"
	title_label.add_theme_font_size_override("font_size", 32)
	header.add_child(title_label)

	_counter_label = Label.new()
	_counter_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_counter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(_counter_label)

	# So existe em build de depuracao: no editor e em
	# exportacoes com "Export With Debug". Serve para zerar
	# a colecao entre um participante e outro nos testes.
	if OS.is_debug_build():
		var reset_dialog := ConfirmationDialog.new()
		reset_dialog.title = "Limpar coleção"
		reset_dialog.dialog_text = (
			"Apagar o registro de cartas encontradas?\n"
			+ "Todas as cartas voltam a aparecer bloqueadas."
		)
		reset_dialog.ok_button_text = "Limpar"
		reset_dialog.cancel_button_text = "Cancelar"
		reset_dialog.confirmed.connect(_on_reset_confirmed)
		add_child(reset_dialog)

		var reset_button := Button.new()
		reset_button.text = "Limpar coleção"
		reset_button.pressed.connect(
			func() -> void: reset_dialog.popup_centered()
		)
		header.add_child(reset_button)

	var close_button := Button.new()
	close_button.text = "Fechar"
	close_button.pressed.connect(_on_close_pressed)
	header.add_child(close_button)

	return header


func _on_reset_confirmed() -> void:
	CardCollection.clear_collection()
	refresh()


func _populate_sections() -> void:
	var all_cards: Array[CardData] = CardDatabase.get_all_cards()
	var unlocked_amount := 0

	for card_data: CardData in all_cards:
		if CardCollection.is_unlocked(str(card_data.id)):
			unlocked_amount += 1

	if _counter_label != null:
		_counter_label.text = (
			"%d de %d cartas encontradas"
			% [unlocked_amount, all_cards.size()]
		)

	for category: int in CardCategory.display_order():
		var cards_in_category: Array[CardData] = []

		for card_data: CardData in all_cards:
			if card_data.category == category:
				cards_in_category.append(card_data)

		if cards_in_category.is_empty():
			continue

		cards_in_category.sort_custom(_compare_by_title)

		_sections.add_child(
			_build_section_title(
				category,
				cards_in_category.size()
			)
		)

		var grid := GridContainer.new()
		grid.columns = COLUMNS
		grid.add_theme_constant_override(
			"h_separation",
			CARD_SEPARATION
		)
		grid.add_theme_constant_override(
			"v_separation",
			CARD_SEPARATION
		)
		_sections.add_child(grid)

		for card_data: CardData in cards_in_category:
			var locked: bool = not CardCollection.is_unlocked(
				str(card_data.id)
			)

			var card: Card = CardFactory.instantiate_card(
				str(card_data.id),
				locked
			)

			if card == null:
				continue

			card.details_requested.connect(
				_on_card_details_requested.bind(locked)
			)

			card.details_hidden.connect(
				_on_card_details_hidden
			)

			grid.add_child(card)

			# Deixa a roda do mouse chegar no ScrollContainer.
			card.set_mouse_passthrough(true)


func _build_section_title(
	category: int,
	amount: int
) -> Control:
	var label := Label.new()

	label.text = "%s (%d)" % [
		CardCategory.display_name(category),
		amount
	]

	label.add_theme_font_size_override("font_size", 22)

	return label


func _compare_by_title(a: CardData, b: CardData) -> bool:
	return a.title.naturalnocasecmp_to(b.title) < 0


func _on_card_details_requested(
	card: Card,
	locked: bool
) -> void:
	if card == null or card.data == null:
		return

	_details_panel.show_card(card.data, locked)


func _on_card_details_hidden(_card: Card) -> void:
	_details_panel.hide_card()


func _on_close_pressed() -> void:
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return

	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()
