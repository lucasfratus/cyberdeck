extends Node
class_name HandLayout

const CARD_OVERLAP := 60.0
const CARD_Y := 0.0


func update_layout(container: CardContainer) -> void:
	var cards := container.get_cards()

	if cards.is_empty():
		return

	var total_width := (cards.size() - 1) * CARD_OVERLAP
	var start_x := -total_width / 2.0

	for i in range(cards.size()):
		var card := cards[i]
		var target := Vector2(
			start_x + i * CARD_OVERLAP,
			CARD_Y
		)

		card.set_hand_position(target, true)
		card.z_index = i
