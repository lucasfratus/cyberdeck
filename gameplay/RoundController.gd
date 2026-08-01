class_name RoundController
extends RefCounted

var data: RoundData

var score := 0.0
var plays_remaining := 0
var finished := false


func start(round_data: RoundData) -> void:
	data = round_data
	score = 0.0
	plays_remaining = data.base_max_plays
	finished = false


func register_play(play_score: float) -> void:
	if finished:
		return

	score += play_score
	plays_remaining -= 1

	if has_won() or has_lost():
		finished = true


func has_won() -> bool:
	return data != null and score >= data.base_risk


func has_lost() -> bool:
	return (
		data != null
		and plays_remaining <= 0
		and not has_won()
	)


func get_risk() -> float:
	if data == null:
		return 0.0

	return data.base_risk
