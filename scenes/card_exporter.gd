extends Node

@onready var viewport: SubViewport = $SubViewport
@onready var card: Card = $SubViewport/Card

var cards_to_export := [
	CardID.SENHA_FORTE,
	CardID.AUTENTICACAO_2FA,
	CardID.REUTILIZAR_SENHA,
	CardID.LINK_SUSPEITO,
	CardID.SENHAS_EXCLUSIVAS,
	CardID.ABRIR_ANEXO,
	CardID.VERIFICAR_REMETENTE,
	CardID.ANTIVIRUS_ATUALIZADO
]

const CARD_BASE_SIZE := Vector2(180, 252)
const EXPORT_SCALE := 4.0


func _ready() -> void:
	DirAccess.make_dir_absolute("res://exports")

	# Força o SubViewport a renderizar mesmo sem estar visível.
	viewport.render_target_update_mode = (
		SubViewport.UPDATE_ALWAYS
	)

	viewport.transparent_bg = false

	# Configura a carta para ocupar o viewport.
	card.set_anchors_preset(
		Control.PRESET_TOP_LEFT
	)

	card.position = Vector2.ZERO
	card.size = CARD_BASE_SIZE
	card.scale = Vector2.ONE * EXPORT_SCALE
	card.pivot_offset = Vector2.ZERO

	# Dá tempo para o viewport inicializar.
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	for card_id in cards_to_export:
		var data := CardDatabase.get_card(card_id)

		if data == null:
			print(
				"Carta não encontrada: ",
				card_id
			)
			continue

		# IMPORTANTE: setup() é assíncrona.
		await card.setup(data)

		# Espera Containers, fontes e texturas atualizarem.
		await get_tree().process_frame
		await get_tree().process_frame

		# Espera o frame realmente ser desenhado.
		await RenderingServer.frame_post_draw

		export_card_png(
			"res://exports/%s.png"
			% card_id
		)

	print("Exportação concluída.")
	get_tree().quit()


func export_card_png(path: String) -> void:
	var texture := viewport.get_texture()

	if texture == null:
		push_error(
			"Não foi possível obter a textura do SubViewport."
		)
		return

	var image := texture.get_image()

	if image == null or image.is_empty():
		push_error(
			"Não foi possível obter a imagem do SubViewport."
		)
		return

	var error := image.save_png(path)

	if error != OK:
		push_error(
			"Erro ao salvar: %s"
			% path
		)
		return

	print(
		"Carta exportada em: ",
		path
	)
