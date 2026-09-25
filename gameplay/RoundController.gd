class_name RoundController
extends RefCounted

var data: RoundData
var active_breaches: Array[SecurityBreachData] = []
var exploited_breaches: Array[SecurityBreachData] = []
var effective_risk := 0.0

var score := 0.0
var plays_remaining := 0
var finished := false
var last_play_base_score := 0.0
var last_breach_penalty := 0.0
var last_play_final_score := 0.0

func start(round_data: RoundData) -> void:
	data = round_data
	score = 0.0
	plays_remaining = data.base_max_plays
	finished = false
	
	last_play_base_score = 0.0
	last_breach_penalty = 0.0
	last_play_final_score = 0.0
	
	exploited_breaches.clear()
	effective_risk = data.base_risk

	for breach in active_breaches:
		if breach == null:
			continue

		if breach.id not in data.exploited_breach_ids:
			continue

		exploited_breaches.append(breach)

	effective_risk += (
		data.risk_increase_per_exploited_breach
		* exploited_breaches.size()
	)
	
	print(
	"[ATAQUE] Brechas exploradas: ",
	exploited_breaches.size()
	)

	print(
		"[ATAQUE] Risco base: ",
		data.base_risk,
		" | Risco efetivo: ",
		effective_risk
	)


func register_play(
		play_score: float,
		breach_penalty: float = 0.0
	) -> void:
	if finished:
		return

	last_play_base_score = play_score
	last_breach_penalty = maxf(breach_penalty, 0.0)

	last_play_final_score = maxf(
		last_play_base_score - last_breach_penalty,
		0.0
	)

	score += last_play_final_score
	plays_remaining -= 1

	if has_won() or has_lost():
		finished = true


func has_won() -> bool:
	# Compara com o risco efetivo, que inclui o aumento
	# causado pelas brechas exploradas nesta rodada.
	return data != null and score >= get_risk()


func has_lost() -> bool:
	return (
		data != null
		and plays_remaining <= 0
		and not has_won()
	)


func get_risk() -> float:
	if data == null:
		return 0.0

	return effective_risk


func open_breach(breach: SecurityBreachData) -> bool:
	if breach == null:
		return false

	for active_breach in active_breaches:
		if active_breach.id == breach.id:
			return false

	active_breaches.append(breach)
	return true
	

func get_active_breaches() -> Array[SecurityBreachData]:
	return active_breaches.duplicate()
	
	
func get_breach_penalty_ratio() -> float:
	var total := 0.0

	for breach in active_breaches:
		total += breach.score_penalty_ratio

	return clampf(total, 0.0, 1.0)


func close_breach_by_id(
	breach_id: String
) -> SecurityBreachData:
	if breach_id.is_empty():
		return null

	for i in range(active_breaches.size()):
		var breach := active_breaches[i]

		if breach.id != breach_id:
			continue

		active_breaches.remove_at(i)
		return breach

	return null
	
	
func restore_active_breaches(
	snapshot: Array[SecurityBreachData]
) -> void:
	active_breaches.clear()

	for breach in snapshot:
		if breach == null:
			continue

		active_breaches.append(breach)
		

func get_exploited_breaches() -> Array[SecurityBreachData]:
	return exploited_breaches.duplicate()
	

func get_breach_exploitation_risk_increase() -> float:
	if data == null:
		return 0.0

	return (
		data.risk_increase_per_exploited_breach
		* exploited_breaches.size()
	)
