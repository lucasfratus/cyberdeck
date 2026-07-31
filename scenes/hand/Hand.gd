extends Control
class_name Hand

@onready var card_container: CardContainer = $CardContainer
@onready var layout: HandLayout = $HandLayout


func add_card(card: Card) -> void:
	card_container.add_child(card)

	layout.update_layout(card_container)


func remove_card(card: Card) -> void:
	if card.get_parent() == card_container:
		card_container.remove_child(card)

	layout.update_layout(card_container)


func clear() -> void:
	for card in card_container.get_cards():
		card.queue_free()


func get_cards() -> Array[Card]:
	return card_container.get_cards()
