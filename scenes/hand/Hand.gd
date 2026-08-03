extends Control
class_name Hand

@onready var card_container: CardContainer = $CardContainer
@onready var layout: HandLayout = $HandLayout

signal selection_changed(selected_cards: Array[Card])
signal cards_played(cards: Array[Card])
signal layout_updated

@export var max_selected_cards := 5

var selected_cards: Array[Card] = []


func _ready() -> void:
	card_container.resized.connect(_on_card_container_resized)
	call_deferred("_update_layout")


func add_card(card: Card) -> void:
	card_container.add_child(card)

	card.selection_requested.connect(
		_on_card_selection_requested
	)

	call_deferred("_update_layout")


func remove_card(card: Card) -> void:
	if card in selected_cards:
		selected_cards.erase(card)
		card.set_selected(false)

	if card.get_parent() == card_container:
		card_container.remove_child(card)

	_update_layout()
	selection_changed.emit(selected_cards.duplicate())


func clear() -> void:
	clear_selection()

	for card in card_container.get_cards():
		card.queue_free()


func get_cards() -> Array[Card]:
	return card_container.get_cards()
	

func _select_card(card: Card) -> void:
	if selected_cards.size() >= max_selected_cards:
		return

	selected_cards.append(card)
	card.set_selected(true)


func _deselect_card(card: Card) -> void:
	selected_cards.erase(card)
	card.set_selected(false)
	
	
func clear_selection() -> void:
	for card in selected_cards:
		card.set_selected(false)

	selected_cards.clear()
	selection_changed.emit(selected_cards.duplicate())


func get_selected_cards() -> Array[Card]:
	return selected_cards.duplicate()
	

func play_selected_cards() -> void:
	if selected_cards.is_empty():
		return

	var cards_to_play: Array[Card] = selected_cards.duplicate()

	for card in cards_to_play:
		selected_cards.erase(card)

		if card.get_parent() == card_container:
			card_container.remove_child(card)

		card.set_selected(false)

	_update_layout()
	
	selection_changed.emit(selected_cards.duplicate())
	cards_played.emit(cards_to_play)
	

func set_interaction_enabled(enabled: bool) -> void:
	for card in card_container.get_cards():
		card.set_interaction_enabled(enabled)
		

func _on_card_selection_requested(card: Card) -> void:
	if not card.is_interaction_enabled():
		return

	if card.is_selected:
		_deselect_card(card)
	else:
		_select_card(card)

	selection_changed.emit(selected_cards.duplicate())


func take_all_cards() -> Array[Card]:
	var cards := card_container.get_cards()

	clear_selection()

	for card in cards:
		card_container.remove_child(card)

	_update_layout()

	return cards


func _update_layout() -> void:
	if not is_instance_valid(card_container):
		return

	if card_container.size.x <= 0.0:
		call_deferred("_update_layout")
		return

	layout.update_layout(
		card_container.get_cards(),
		card_container.size.x,
		true
	)
	
	layout_updated.emit()

func _on_card_container_resized() -> void:
	_update_layout()
