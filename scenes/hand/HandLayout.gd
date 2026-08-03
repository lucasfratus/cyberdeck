extends Node
class_name HandLayout

const CARD_WIDTH := 180.0
const CARD_GAP := 16.0
const CARD_SPACING := CARD_WIDTH + CARD_GAP
const CARD_Y := 0.0


func update_layout(
	cards: Array[Card],
	available_width: float,
	immediate := false
) -> void:
	if cards.is_empty():
		return

	var total_width := (
		CARD_WIDTH * cards.size()
		+ CARD_GAP * (cards.size() - 1)
	)

	var start_x := (available_width - total_width) / 2.0

	for i in range(cards.size()):
		var card := cards[i]

		var target_position := Vector2(
			start_x + i * CARD_SPACING,
			CARD_Y
		)

		card.z_index = i
		card.set_hand_position(target_position, immediate)
