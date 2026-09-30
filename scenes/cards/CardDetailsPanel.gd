extends PanelContainer
class_name CardDetailsPanel

@onready var title_label: Label = \
	$MarginContainer/Content/Title

#@onready var illustration: TextureRect = \
	#$MarginContainer/Content/Illustration

@onready var description_label: Label = \
	$MarginContainer/Content/Description

@onready var protection_label: Label = \
	$MarginContainer/Content/Attributes/Protection

@onready var vulnerability_label: Label = \
	$MarginContainer/Content/Attributes/Vulnerability


const PANEL_WIDTH := 420.0
const DESCRIPTION_FONT_SIZE := 15

## Largura em uso. A partida pede um painel mais largo que
## a coluna da enciclopedia comporta, com set_panel_width().
var panel_width := PANEL_WIDTH
const LOCKED_PLACEHOLDER := "?"
const LOCKED_TEXT := \
	"Carta ainda não encontrada. Ela aparece aqui depois de surgir em uma partida."


func _ready() -> void:
	custom_minimum_size.x = panel_width
	size.x = panel_width
	_fix_text_width()

	description_label.add_theme_font_size_override(
		"font_size",
		DESCRIPTION_FONT_SIZE
	)

	# Texto justificado. A ultima linha de cada paragrafo
	# continua alinhada a esquerda, pelo padrao do Label.
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_FILL

	hide()


func set_panel_width(width: float) -> void:
	panel_width = width
	custom_minimum_size.x = width
	size.x = width
	_fix_text_width()


## O painel passa a maior parte do tempo escondido, e Control
## escondido nao recebe layout. Sem largura fixa, os textos com
## quebra de linha ficavam com 1 px de largura ate o painel
## aparecer pela primeira vez: a descricao media milhares de
## pixels de altura e o painel surgia vazio e esticado por um
## instante. Com a largura definida aqui, a altura ja sai certa.
func _fix_text_width() -> void:
	if description_label == null:
		return

	var margin := $MarginContainer as MarginContainer
	var padding := (
		margin.get_theme_constant("margin_left")
		+ margin.get_theme_constant("margin_right")
	)

	var box := get_theme_stylebox("panel")

	if box != null:
		padding += box.get_margin(SIDE_LEFT) + box.get_margin(SIDE_RIGHT)

	var text_width := maxf(panel_width - padding, 0.0)
	description_label.custom_minimum_size.x = text_width
	title_label.custom_minimum_size.x = text_width


func show_card(card_data: CardData, locked := false) -> void:
	if card_data == null:
		hide_card()
		return

	custom_minimum_size.x = panel_width
	size.x = panel_width

	if locked:
		title_label.text = LOCKED_PLACEHOLDER
		description_label.text = LOCKED_TEXT
		protection_label.text = (
			"Proteção: %s" % LOCKED_PLACEHOLDER
		)
		vulnerability_label.text = (
			"Vulnerabilidade: %s" % LOCKED_PLACEHOLDER
		)
		show()
		return

	title_label.text = card_data.title

	if card_data.educational_description.is_empty():
		description_label.text = card_data.description
	else:
		description_label.text = (
			card_data.educational_description
		)

	protection_label.text = (
		"Proteção: %s"
		% card_data.protection
	)

	vulnerability_label.text = (
		"Vulnerabilidade: %s"
		% card_data.vulnerability
	)

	show()


func hide_card() -> void:
	hide()
