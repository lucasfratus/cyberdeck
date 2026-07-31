extends RefCounted
class_name Deck

var _cards: Array[String] = []


func add(card_id: String) -> void:
	_cards.append(card_id)


func add_many(card_ids: Array[String]) -> void:
	_cards.append_array(card_ids)


func shuffle() -> void:
	_cards.shuffle()


func draw() -> String:
	if _cards.is_empty():
		return ""

	return _cards.pop_front()


func peek() -> String:
	if _cards.is_empty():
		return ""

	return _cards.front()


func is_empty() -> bool:
	return _cards.is_empty()


func size() -> int:
	return _cards.size()


func clear() -> void:
	_cards.clear()


func contains(card_id: String) -> bool:
	return _cards.has(card_id)


func remove(card_id: String) -> bool:
	var index := _cards.find(card_id)

	if index == -1:
		return false

	_cards.remove_at(index)
	return true


func get_cards() -> Array[String]:
	return _cards.duplicate()
