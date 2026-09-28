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


## Material do fundo animado. Aplicar em um ColorRect que
## cubra a tela, atras do resto da interface.
static func make_background_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = BACKGROUND_SHADER
	return material


## Material da camada de CRT, para um ColorRect por cima.
static func make_crt_overlay_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = CRT_OVERLAY_SHADER
	return material
