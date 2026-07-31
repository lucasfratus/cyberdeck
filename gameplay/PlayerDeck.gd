extends RefCounted
class_name PlayerDeck

var draw_pile := Deck.new()
var discard_pile := Deck.new()

func setup(cards: Array[String]) -> void:
	draw_pile.clear()
	discard_pile.clear()

	draw_pile.add_many(cards)
	draw_pile.shuffle()


func draw() -> String:

	if draw_pile.is_empty():
		reshuffle()

	if draw_pile.is_empty():
		return ""

	return draw_pile.draw()


func discard(card_id: String) -> void:
	discard_pile.add(card_id)


func reshuffle() -> void:

	if discard_pile.is_empty():
		return

	draw_pile.add_many(discard_pile.get_cards())
	draw_pile.shuffle()
	discard_pile.clear()


func draw_size() -> int:
	return draw_pile.size()


func discard_size() -> int:
	return discard_pile.size()
