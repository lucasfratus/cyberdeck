extends Control

## Janelas de anuncio que aparecem durante a partida enquanto a
## brecha "Navegador sequestrado" estiver aberta. Elas ficam por
## cima da mao e da area de jogo e bloqueiam o clique ate o
## jogador fechar cada uma pelo X.
##
## O botao chamativo de cada anuncio e uma armadilha: clicar nele
## abre mais uma janela, como acontece com adware de verdade.
##
## Sem class_name de proposito: o Game carrega este script com
## preload().

signal ad_clicked

const BREACH_ICON: Texture2D = preload(
	"res://assets/icons/breaches/hijacked_browser.png"
)

## Quantas janelas podem ficar abertas ao mesmo tempo. O clique
## no anuncio pode passar do limite normal ate o limite extra.
const MAX_POPUPS := 3
const MAX_POPUPS_AFTER_CLICK := 5

## Espera antes da primeira janela e intervalo entre as seguintes,
## em segundos. O intervalo so corre no turno do jogador.
const FIRST_DELAY := 1.2
const INTERVAL_MIN := 5.0
const INTERVAL_MAX := 8.0

const POPUP_WIDTH := 320.0

## Margens da area onde as janelas podem surgir. A faixa de cima
## fica livre para o HUD de risco e pontuacao.
const AREA_MARGIN_X := 40.0
const AREA_TOP := 130.0
const AREA_BOTTOM := 40.0

const WINDOW_BG := Color(0.93, 0.94, 0.95)
const WINDOW_BORDER := Color(0.04, 0.06, 0.08)
const TEXT_DARK := Color(0.12, 0.13, 0.16)
const TEXT_SOFT := Color(0.3, 0.32, 0.38)
const CLOSE_BG := Color(0.85, 0.24, 0.24)
const CLOSE_HOVER := Color(1.0, 0.36, 0.36)

## Cor da barra de titulo e do botao de cada anuncio.
const HEAD_COLORS: Array[Color] = [
	Color(0.86, 0.26, 0.74),
	Color(0.98, 0.76, 0.18),
	Color(0.22, 0.8, 0.9),
	Color(0.98, 0.52, 0.16),
]

## Endereco falso na barra de titulo, manchete, texto e botao.
const ADS: Array[Array] = [
	["promo-gratis.net", "PARABÉNS!", "Você é o visitante 1.000.000. Resgate o seu prêmio agora.", "RESGATAR"],
	["pc-turbo.com", "SEU PC ESTÁ LENTO", "3 problemas encontrados. Baixe o Acelerador PC grátis.", "LIMPAR AGORA"],
	["super-ofertas.shop", "OFERTA RELÂMPAGO", "Fones sem fio por R$ 9,90. Só hoje!", "COMPRAR"],
	["video-livre.tv", "VÍDEO BLOQUEADO", "Instale o reprodutor para continuar assistindo.", "INSTALAR"],
	["cupom-facil.net", "CUPOM LIBERADO", "Adicione a extensão de cupons e economize em tudo.", "ADICIONAR"],
	["seguranca-web.info", "ALERTA DE VÍRUS", "Seu navegador foi infectado! Clique para remover.", "REMOVER"],
]

var _active := false
var _can_spawn: Callable
var _countdown := 0.0
var _last_ad := -1
var _popups: Array[Control] = []
var _opened_at: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_PAUSABLE


## can_spawn: devolve true quando uma janela nova pode surgir,
## isto e, no turno do jogador, sem dialogo aberto.
func setup(can_spawn: Callable) -> void:
	_can_spawn = can_spawn


func set_active(active: bool) -> void:
	if active == _active:
		return

	_active = active

	if active:
		_countdown = FIRST_DELAY
	else:
		close_all()


func is_active() -> bool:
	return _active


## Fecha as janelas abertas sem desligar os anuncios. Usado no
## fim da rodada: na rodada seguinte eles voltam se a brecha
## continuar aberta.
func close_all() -> void:
	for popup in _popups.duplicate():
		_close_popup(popup, false)


func _process(delta: float) -> void:
	if not _active:
		return

	if _can_spawn.is_valid() and not bool(_can_spawn.call()):
		return

	if _popups.size() >= MAX_POPUPS:
		return

	_countdown -= delta

	if _countdown > 0.0:
		return

	_countdown = randf_range(INTERVAL_MIN, INTERVAL_MAX)
	_spawn_popup()


func _spawn_popup(near: Control = null) -> void:
	var ad_index := randi() % ADS.size()

	# Evita repetir o mesmo anuncio duas vezes seguidas.
	if ad_index == _last_ad:
		ad_index = (ad_index + 1) % ADS.size()

	_last_ad = ad_index

	var ad: Array = ADS[ad_index]
	var color: Color = HEAD_COLORS[randi() % HEAD_COLORS.size()]
	var popup := _build_popup(ad, color)

	add_child(popup)
	_popups.append(popup)
	_opened_at[popup] = Time.get_ticks_msec()

	# O tamanho final so e conhecido depois do primeiro layout.
	popup.reset_size()
	var popup_size := popup.get_combined_minimum_size()
	popup.size = popup_size
	popup.position = _pick_position(popup_size, near)
	popup.pivot_offset = popup_size / 2.0

	popup.scale = Vector2(0.6, 0.6)
	popup.modulate.a = 0.0

	var tween := popup.create_tween().set_parallel(true)
	tween.tween_property(popup, "scale", Vector2.ONE, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "modulate:a", 1.0, 0.12)

	SessionLogger.log_event("ad_popup_shown", {"ad": ad[1]})


func _pick_position(popup_size: Vector2, near: Control) -> Vector2:
	var area := size
	var max_x := maxf(area.x - popup_size.x - AREA_MARGIN_X, AREA_MARGIN_X)
	var max_y := maxf(area.y - popup_size.y - AREA_BOTTOM, AREA_TOP)

	var pos: Vector2

	if near != null:
		# A janela aberta pelo clique surge deslocada da original,
		# como uma cascata.
		pos = near.position + Vector2(
			randf_range(-60.0, 60.0),
			randf_range(30.0, 60.0)
		)
	else:
		pos = Vector2(
			randf_range(AREA_MARGIN_X, max_x),
			randf_range(AREA_TOP, max_y)
		)

	pos.x = clampf(pos.x, AREA_MARGIN_X, max_x)
	pos.y = clampf(pos.y, AREA_TOP, max_y)
	return pos


func _build_popup(ad: Array, color: Color) -> Control:
	var popup := PanelContainer.new()
	popup.custom_minimum_size = Vector2(POPUP_WIDTH, 0.0)
	popup.mouse_filter = Control.MOUSE_FILTER_STOP

	var frame := StyleBoxFlat.new()
	frame.bg_color = WINDOW_BG
	frame.border_color = WINDOW_BORDER
	frame.set_border_width_all(3)
	frame.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	frame.shadow_size = 1
	frame.shadow_offset = Vector2(6.0, 6.0)
	popup.add_theme_stylebox_override("panel", frame)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	popup.add_child(column)

	# Barra de titulo com o endereco falso e o X verdadeiro.
	var head := PanelContainer.new()
	var head_style := StyleBoxFlat.new()
	head_style.bg_color = color
	head_style.content_margin_left = 8
	head_style.content_margin_right = 4
	head_style.content_margin_top = 3
	head_style.content_margin_bottom = 3
	head.add_theme_stylebox_override("panel", head_style)
	column.add_child(head)

	var head_row := HBoxContainer.new()
	head.add_child(head_row)

	var site := Label.new()
	site.text = ad[0]
	site.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	site.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	site.add_theme_color_override("font_color", TEXT_DARK)
	site.add_theme_font_override("font", UIPalette.TEXT_FONT_BOLD)
	site.add_theme_font_size_override("font_size", 13)
	head_row.add_child(site)

	var close := Button.new()
	close.text = "X"
	close.tooltip_text = "Fechar"
	close.custom_minimum_size = Vector2(26.0, 22.0)
	close.focus_mode = Control.FOCUS_NONE
	close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_button(close, CLOSE_BG, CLOSE_HOVER, Color.WHITE, 14)
	close.pressed.connect(_close_popup.bind(popup, true))
	head_row.add_child(close)

	var separator := ColorRect.new()
	separator.color = WINDOW_BORDER
	separator.custom_minimum_size = Vector2(0.0, 3.0)
	column.add_child(separator)

	# Corpo: icone, manchete, texto e o botao-armadilha.
	var body_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		body_margin.add_theme_constant_override("margin_" + side, 12)
	column.add_child(body_margin)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body_margin.add_child(body)

	var icon := TextureRect.new()
	icon.texture = BREACH_ICON
	icon.custom_minimum_size = Vector2(48.0, 48.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	body.add_child(icon)

	var text_column := VBoxContainer.new()
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.add_theme_constant_override("separation", 6)
	body.add_child(text_column)

	var headline := Label.new()
	headline.text = ad[1]
	headline.add_theme_color_override("font_color", TEXT_DARK)
	headline.add_theme_font_override("font", UIPalette.TEXT_FONT_BOLD)
	headline.add_theme_font_size_override("font_size", 18)
	text_column.add_child(headline)

	var message := Label.new()
	message.text = ad[2]
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.custom_minimum_size = Vector2(POPUP_WIDTH - 110.0, 0.0)
	message.add_theme_color_override("font_color", TEXT_SOFT)
	message.add_theme_font_override("font", UIPalette.TEXT_FONT)
	message.add_theme_font_size_override("font_size", 13)
	text_column.add_child(message)

	var cta := Button.new()
	cta.text = ad[3]
	cta.custom_minimum_size = Vector2(0.0, 30.0)
	cta.focus_mode = Control.FOCUS_NONE
	cta.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_button(cta, color, color.lightened(0.25), TEXT_DARK, 15)
	cta.pressed.connect(_on_ad_pressed.bind(popup))
	text_column.add_child(cta)

	# Pulso lento de brilho no botao, 1 vez por segundo, sem
	# piscar: chama atencao sem virar um flash.
	var pulse := cta.create_tween().set_loops()
	pulse.tween_property(cta, "self_modulate", Color(1.15, 1.15, 1.15), 0.5)
	pulse.tween_property(cta, "self_modulate", Color.WHITE, 0.5)

	return popup


func _style_button(
	button: Button,
	bg: Color,
	hover: Color,
	font_color: Color,
	font_size: int
) -> void:
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = hover if state == "hover" else bg
		if state == "pressed":
			box.bg_color = bg.darkened(0.2)
		box.border_color = WINDOW_BORDER
		box.set_border_width_all(2)
		box.content_margin_left = 6
		box.content_margin_right = 6
		box.content_margin_top = 2
		box.content_margin_bottom = 2
		button.add_theme_stylebox_override(state, box)

	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(color_name, font_color)

	button.add_theme_font_override("font", UIPalette.TEXT_FONT_BOLD)
	button.add_theme_font_size_override("font_size", font_size)


## Clicar no anuncio nao resolve nada: abre mais uma janela.
func _on_ad_pressed(popup: Control) -> void:
	SessionLogger.log_event("ad_popup_clicked", {})
	_shake(popup)

	if _popups.size() < MAX_POPUPS_AFTER_CLICK:
		_spawn_popup(popup)

	ad_clicked.emit()


func _shake(popup: Control) -> void:
	var origin := popup.position
	var tween := popup.create_tween()

	for offset in [8.0, -7.0, 5.0, -3.0, 0.0]:
		tween.tween_property(
			popup, "position:x", origin.x + offset, 0.04
		)


func _close_popup(popup: Control, by_player: bool) -> void:
	if popup not in _popups:
		return

	_popups.erase(popup)

	if by_player:
		var opened: int = _opened_at.get(popup, Time.get_ticks_msec())
		SessionLogger.log_event("ad_popup_closed", {
			"seconds_open": snappedf(
				(Time.get_ticks_msec() - opened) / 1000.0, 0.01
			),
		})

	_opened_at.erase(popup)

	# Sem cliques durante o fechamento.
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var tween := popup.create_tween().set_parallel(true)
	tween.tween_property(popup, "scale", Vector2(0.85, 0.85), 0.12)
	tween.tween_property(popup, "modulate:a", 0.0, 0.12)
	tween.chain().tween_callback(popup.queue_free)
