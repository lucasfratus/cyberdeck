extends Node

## Opcoes do jogador: volume e acessibilidade. Ficam salvas em
## user://settings.cfg e valem para todas as cenas, por isso
## este script e um autoload (GameSettings).

signal changed

const SETTINGS_PATH := "user://settings.cfg"

## Acima de tudo, inclusive dos menus (camada 100), para a
## correcao de cor valer para a tela inteira.
const COLORBLIND_LAYER := 128

const COLORBLIND_SHADER := preload(
	"res://assets/shaders/colorblind_correction.gdshader"
)

## Indice 0 desliga. Os outros seguem o "mode" do shader + 1.
const COLORBLIND_MODES: Array[String] = [
	"Desligado",
	"Protanopia (dificuldade com vermelho)",
	"Deuteranopia (dificuldade com verde)",
	"Tritanopia (dificuldade com azul)",
]

## Nomes curtos para o registro da sessao.
const COLORBLIND_IDS: Array[String] = [
	"off", "protanopia", "deuteranopia", "tritanopia",
]

var master_volume := 1.0
var colorblind_mode := 0
var colorblind_intensity := 1.0

var _filter_layer: CanvasLayer
var _filter_rect: ColorRect
var _filter_material: ShaderMaterial


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_filter()
	_load()
	_apply()


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply()
	_save()


func set_colorblind_mode(mode: int) -> void:
	colorblind_mode = clampi(mode, 0, COLORBLIND_MODES.size() - 1)
	_apply()
	_save()


func set_colorblind_intensity(value: float) -> void:
	colorblind_intensity = clampf(value, 0.0, 1.0)
	_apply()
	_save()


func get_colorblind_id() -> String:
	return COLORBLIND_IDS[colorblind_mode]


# --- Aplicacao ------------------------------------------------

## Um ColorRect de tela cheia numa camada propria le a imagem
## ja desenhada (hint_screen_texture) e devolve a versao
## corrigida por cima. Fica escondido com o modo desligado.
func _build_filter() -> void:
	_filter_layer = CanvasLayer.new()
	_filter_layer.layer = COLORBLIND_LAYER
	add_child(_filter_layer)

	_filter_material = ShaderMaterial.new()
	_filter_material.shader = COLORBLIND_SHADER

	_filter_rect = ColorRect.new()
	_filter_rect.material = _filter_material
	_filter_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_filter_layer.add_child(_filter_rect)
	_filter_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _apply() -> void:
	var master := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master, linear_to_db(maxf(master_volume, 0.0001)))
	AudioServer.set_bus_mute(master, master_volume <= 0.0)

	var enabled := colorblind_mode > 0 and colorblind_intensity > 0.0
	_filter_rect.visible = enabled

	if enabled:
		_filter_material.set_shader_parameter("mode", colorblind_mode - 1)
		_filter_material.set_shader_parameter("intensity", colorblind_intensity)

	changed.emit()


# --- Arquivo --------------------------------------------------

func _load() -> void:
	var config := ConfigFile.new()

	if config.load(SETTINGS_PATH) != OK:
		return

	master_volume = clampf(
		float(config.get_value("audio", "master_volume", 1.0)), 0.0, 1.0
	)
	colorblind_mode = clampi(
		int(config.get_value("accessibility", "colorblind_mode", 0)),
		0,
		COLORBLIND_MODES.size() - 1
	)
	colorblind_intensity = clampf(
		float(config.get_value("accessibility", "colorblind_intensity", 1.0)),
		0.0,
		1.0
	)


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("accessibility", "colorblind_mode", colorblind_mode)
	config.set_value("accessibility", "colorblind_intensity", colorblind_intensity)

	if config.save(SETTINGS_PATH) != OK:
		push_warning("Nao foi possivel salvar as opcoes em %s." % SETTINGS_PATH)
