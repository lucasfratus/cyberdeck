extends Control

## Tela "Como jogar": objetivo, pontuacao, brechas,
## enciclopedia e controles. Aberta pelo menu principal e
## pelo menu de pausa.
##
## Sem class_name de proposito: quem usa carrega com
## preload() e cria com new(), sem depender do registro
## global de classes nem de uma cena .tscn.

signal closed

const OUTER_MARGIN := 24
const CONTENT_MAX_WIDTH := 820.0
const BODY_FONT_SIZE := 17

const HELP_TEXT := """[b]Objetivo[/b]
Cada rodada apresenta uma ameaça com um Índice de Risco. Você tem 3 jogadas para alcançar esse valor em pontos. Em cada jogada, escolha até 3 cartas da mão e pressione Jogar.

[b]Pontuação[/b]
A Proteção das cartas soma. A Vulnerabilidade multiplica.

    pontuação = soma da Proteção × produto da Vulnerabilidade

Exemplo: Senha Forte (Proteção 35, ×1.0) jogada com Verificar o Remetente (Proteção 30, ×1.5) vale (35 + 30) × 1.0 × 1.5 = 97.5 pontos.

[b]Práticas inseguras e brechas[/b]
Cartas de prática insegura têm Vulnerabilidade alta e parecem vantajosas, porque multiplicam a jogada inteira. Mas elas abrem uma brecha de segurança.
• Enquanto a brecha estiver aberta, cada jogada seguinte perde uma parte da pontuação.
• A brecha continua aberta nas rodadas seguintes, até ser corrigida.
• Ameaças futuras podem explorar a brecha e aumentar o Índice de Risco.
• Cartas específicas de boa prática fecham a brecha.
As brechas abertas aparecem em vermelho no canto esquerdo da tela. Passe o mouse sobre elas para ver o efeito.

[b]Enciclopédia[/b]
Reúne, para cada ameaça, uma explicação de como ela funciona, links para materiais de referência e as cartas que você já encontrou, indicando quais são boas práticas e quais abrem brechas.

[b]Controles[/b]
• Mouse: selecionar e jogar cartas.
• Mouse sobre uma carta: ver a explicação da prática.
• Clique ou Enter: avançar os diálogos.
• Esc: pausar o jogo e abrir a Enciclopédia e estas regras.
• Ícones no canto superior direito: abrir estas regras e a Enciclopédia sem passar pela pausa.

[b]Créditos[/b]
Desenvolvido por Lucas de Oliveira Fratus, com orientação do Prof. Dr. Alisson Renan Svaigen (Departamento de Informática, UEM).
• Parte das ilustrações e os personagens foram gerados pelo autor com IA (Google Gemini). As demais imagens em pixel art e os sons sintetizados foram feitos por código, com auxílio de IA (Claude, da Anthropic).
• Sons das cartas: UI SFX, de Romain Simon (CC0).
• Correção para daltonismo: shader de Vildravn (CC0).
• Fontes: Atkinson Hyperlegible, do Braille Institute (SIL OFL 1.1).
• Leituras complementares: Cartilha de Segurança para Internet, do CERT.br.
A lista completa está no arquivo CREDITOS.md do projeto."""


func _ready() -> void:
	_build_interface()
	hide()


func _build_interface() -> void:
	var background := ColorRect.new()
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = UIPalette.BACKGROUND
	background.material = UIPalette.make_background_material()

	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", OUTER_MARGIN)
	margin.add_theme_constant_override("margin_top", OUTER_MARGIN)
	margin.add_theme_constant_override("margin_right", OUTER_MARGIN)
	margin.add_theme_constant_override("margin_bottom", OUTER_MARGIN)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)

	header.add_theme_constant_override("separation", 16)
	header.add_child(
		UIPalette.make_pixel_icon(UIPalette.ICON_HELP, 32.0)
	)

	var title_label := Label.new()
	title_label.text = "Como jogar"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 32)
	header.add_child(title_label)

	var close_button := Button.new()
	close_button.text = "Fechar"
	close_button.pressed.connect(_on_close_pressed)
	header.add_child(close_button)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	# Linhas muito longas cansam a leitura. O texto fica
	# numa coluna central de largura limitada.
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)

	var body := RichTextLabel.new()
	UIPalette.style_rich_text(body, BODY_FONT_SIZE)
	body.custom_minimum_size = Vector2(CONTENT_MAX_WIDTH, 0.0)
	body.text = HELP_TEXT
	center.add_child(body)


func _on_close_pressed() -> void:
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return

	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()
