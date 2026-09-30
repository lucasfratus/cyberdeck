class_name UIPalette

## Paleta da interface em estilo terminal. As mesmas cores
## estao no terminal_theme.tres; ao trocar uma, troque as duas.

const BACKGROUND := Color(0.02, 0.05, 0.03, 1.0)
const PANEL := Color(0.03, 0.09, 0.05, 1.0)
const PRIMARY := Color(0.2, 1.0, 0.45, 1.0)
const TEXT := Color(0.72, 0.98, 0.8, 1.0)
const DIM := Color(0.12, 0.45, 0.25, 1.0)
const DISABLED := Color(0.25, 0.45, 0.32, 1.0)
const HOVER := Color(0.07, 0.25, 0.13, 1.0)

## Tudo que envolve brechas de seguranca usa vermelho.
const DANGER := Color(1.0, 0.36, 0.36, 1.0)
const DANGER_DIM := Color(0.6, 0.14, 0.14, 1.0)
const DANGER_BACKGROUND := Color(0.1, 0.02, 0.02, 1.0)

const BACKGROUND_SHADER := preload(
	"res://assets/shaders/terminal_background.gdshader"
)
const CRT_OVERLAY_SHADER := preload(
	"res://assets/shaders/crt_overlay.gdshader"
)
const NETWORK_BACKGROUND_SHADER := preload(
	"res://assets/shaders/network_background.gdshader"
)


## Material do fundo animado. Aplicar em um ColorRect que
## cubra a tela, atras do resto da interface.
static func make_background_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = BACKGROUND_SHADER
	return material


## Fundo azul da "Rede", usado nos dialogos fora da partida
## e na tela de abertura do cenario.
static func make_network_background_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = NETWORK_BACKGROUND_SHADER
	return material


## Material da camada de CRT, para um ColorRect por cima.
static func make_crt_overlay_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = CRT_OVERLAY_SHADER
	return material

const TEXT_FONT := preload(
	"res://assets/fonts/AtkinsonHyperlegibleMono-Regular.ttf"
)
const TEXT_FONT_BOLD := preload(
	"res://assets/fonts/AtkinsonHyperlegibleMono-Bold.ttf"
)


## Prepara um RichTextLabel para texto corrido da interface:
## cor do tema, fonte monoespacada com negrito de verdade para
## o [b] do BBCode, quebra por palavra e altura pelo conteudo.
## Deixa a roda do mouse passar, para a rolagem funcionar
## com o cursor sobre o texto.
static func style_rich_text(label: RichTextLabel, font_size: int) -> void:
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	label.add_theme_color_override("default_color", TEXT)
	label.add_theme_font_override("normal_font", TEXT_FONT)
	label.add_theme_font_override("bold_font", TEXT_FONT_BOLD)
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.add_theme_font_size_override("bold_font_size", font_size)


## Icones em pixel art. Foram desenhados em 16x16 e salvos
## em 32x32 (cada pixel virou um bloco 2x2). Exibir em 16 ou
## 32 px mantem todos os pixels do mesmo tamanho.
const ICON_ENCYCLOPEDIA: Texture2D = preload("res://assets/icons/ui/encyclopedia.png")
const ICON_HELP: Texture2D = preload("res://assets/icons/ui/help.png")
const ICON_RISK: Texture2D = preload("res://assets/icons/ui/risk.png")
const ICON_SCORE: Texture2D = preload("res://assets/icons/ui/score.png")
const ICON_PLAYS: Texture2D = preload("res://assets/icons/ui/plays.png")
const ICON_SKULL: Texture2D = preload("res://assets/icons/ui/skull.png")
const ICON_FOLDER: Texture2D = preload("res://assets/icons/ui/folder.png")
const ICON_DEV: Texture2D = preload("res://assets/icons/ui/dev.png")
const ICON_OPTIONS: Texture2D = preload("res://assets/icons/ui/options.png")
const ICON_CLOCK: Texture2D = preload("res://assets/icons/ui/clock.png")
const ICON_LOCK_CLOSED: Texture2D = preload("res://assets/icons/ui/lock_closed.png")

## Usado quando a brecha nao tem icone proprio no .tres.
const ICON_BREACH: Texture2D = preload("res://assets/icons/breaches/breach.png")


## TextureRect para um icone em pixel art. O filtro nearest
## amplia sem borrar: cada pixel vira um bloco nitido.
static func make_pixel_icon(
	texture: Texture2D,
	icon_size: float
) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


## Coloca o icone na borda esquerda do botao sem tirar o
## texto do centro. O Godot centraliza o texto no espaco que
## sobra ao lado do icone; uma margem igual do lado direito
## devolve o texto ao centro do botao.
static func set_button_icon(button: Button, icon: Texture2D) -> void:
	button.icon = icon
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT

	var extra: float = (
		icon.get_width()
		+ button.get_theme_constant("h_separation")
	)

	for state: String in [
		"normal", "hover", "pressed", "disabled", "focus"
	]:
		var box := button.get_theme_stylebox(state)

		if box == null:
			continue

		box = box.duplicate()
		box.content_margin_right = (
			max(box.content_margin_right, 0.0) + extra
		)
		button.add_theme_stylebox_override(state, box)
