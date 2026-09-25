extends Node

## Registro persistente das cartas que o jogador ja encontrou.
## Alimenta a enciclopedia: carta nao registrada aparece
## bloqueada, com os campos preenchidos por "?".

const SAVE_PATH := "user://card_collection.json"

var _unlocked: Dictionary = {}


func _ready() -> void:
	load_collection()


## Registra a carta. Devolve true apenas na primeira vez,
## para quem quiser mostrar um aviso de desbloqueio.
func unlock(card_id: String) -> bool:
	if card_id.is_empty():
		return false

	if _unlocked.has(card_id):
		return false

	_unlocked[card_id] = true
	save_collection()

	return true


func is_unlocked(card_id: String) -> bool:
	if card_id.is_empty():
		return false

	return _unlocked.has(card_id)


func unlocked_count() -> int:
	return _unlocked.size()


func get_unlocked_ids() -> Array[String]:
	var result: Array[String] = []

	for key: Variant in _unlocked.keys():
		if key is String:
			result.append(key)

	return result


func clear_collection() -> void:
	_unlocked.clear()
	save_collection()


func save_collection() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)

	if file == null:
		push_warning(
			"Nao foi possivel gravar a colecao de cartas."
		)
		return

	file.store_string(JSON.stringify(_unlocked.keys()))
	file.close()


func load_collection() -> void:
	_unlocked.clear()

	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)

	if file == null:
		return

	var content: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(content)

	if typeof(parsed) != TYPE_ARRAY:
		push_warning(
			"Arquivo da colecao invalido. Recomecando vazio."
		)
		return

	var entries: Array = parsed

	for entry: Variant in entries:
		if entry is String:
			_unlocked[entry] = true
