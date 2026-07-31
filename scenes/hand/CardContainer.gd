extends Control
class_name CardContainer


func get_cards() -> Array[Card]:

	var result: Array[Card] = []

	for child in get_children():

		if child is Card:
			result.append(child)

	return result
