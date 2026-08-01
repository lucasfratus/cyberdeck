class_name ScoreCalculator
extends RefCounted


static func calculate(cards: Array[Card]) -> Dictionary:
	var protection_sum := 0
	var vulnerability_product := 1.0
	var valid_cards := 0

	for card in cards:
		if card == null or card.data == null:
			continue

		protection_sum += card.data.protection
		vulnerability_product *= card.data.vulnerability
		valid_cards += 1

	if valid_cards == 0:
		vulnerability_product = 0.0

	var total_score := protection_sum * vulnerability_product

	return {
		"protection": protection_sum,
		"vulnerability": vulnerability_product,
		"total": total_score
	}
