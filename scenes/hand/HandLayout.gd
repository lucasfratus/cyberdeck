extends Node
class_name HandLayout

const CARD_WIDTH := 180.0
const CARD_GAP := 16.0
const CARD_SPACING := CARD_WIDTH + CARD_GAP
const CARD_Y := 0.0

## Folga minima entre a mao e as bordas da tela. Com mais
## cartas (a mao do Iniciante tem 6), o espaco entre elas
## diminui para a fileira caber na largura disponivel.
const SIDE_MARGIN := 16.0

## Intervalo entre uma carta comprada e a proxima.
const ENTRY_STAGGER := 0.07


## Posiciona as cartas e devolve quanto tempo as cartas
## recem-compradas levam para terminar de subir.
func update_layout(
	cards: Array[Card],
	available_width: float,
	immediate := false
) -> float:
	if cards.is_empty():
		return 0.0

	var entering_count := 0
	var entry_time := 0.0

	var spacing := CARD_SPACING

	if cards.size() > 1:
		var fit_spacing := (
			(available_width - SIDE_MARGIN * 2.0 - CARD_WIDTH)
			/ (cards.size() - 1)
		)
		spacing = minf(CARD_SPACING, fit_spacing)

	var total_width := CARD_WIDTH + spacing * (cards.size() - 1)

	var start_x := (available_width - total_width) / 2.0

	for i in range(cards.size()):
		var card := cards[i]

		var target_position := Vector2(
			start_x + i * spacing,
			CARD_Y
		)

		card.z_index = i

		if card.is_entering_hand:
			card.is_entering_hand = false

			var delay: float = entering_count * ENTRY_STAGGER
			card.play_entry_animation(target_position, delay)

			entering_count += 1
			entry_time = maxf(
				entry_time,
				delay + Card.ENTRY_DURATION
			)
			continue

		card.set_hand_position(target_position, immediate)

	return entry_time
