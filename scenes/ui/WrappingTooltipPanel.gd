extends PanelContainer

## PanelContainer cuja dica de ferramenta quebra linha. A
## dica nativa do Godot so quebra em "\n", entao textos
## longos passavam da borda da tela.
##
## Sem class_name de proposito: quem usa carrega com
## preload(), sem depender do registro global de classes.

const TOOLTIP_WIDTH := 320.0


func _make_custom_tooltip(for_text: String) -> Object:
	var label := RichTextLabel.new()
	label.text = for_text
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(TOOLTIP_WIDTH, 0.0)
	label.add_theme_color_override("default_color", UIPalette.TEXT)

	return label
