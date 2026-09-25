extends Node

## Registra as metricas de desempenho de uma sessao de jogo
## para a avaliacao experimental. Cada sessao vira um JSON
## em user://sessions/. O arquivo e regravado a cada evento,
## para nada se perder se o jogo for fechado no meio.

const SESSIONS_DIR := "user://sessions"
const LOG_FORMAT_VERSION := 1

## Passadas rapidas do mouse sobre a carta nao contam como
## leitura do painel educativo.
const MIN_DETAILS_SECONDS := 0.5

var _active := false
var _session: Dictionary = {}
var _events: Array[Dictionary] = []
var _details_views: Dictionary = {}
var _start_ticks_msec := 0
var _file_path := ""


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _active:
		end_session("closed")


func is_active() -> bool:
	return _active


func get_sessions_folder() -> String:
	return ProjectSettings.globalize_path(SESSIONS_DIR)


func start_session(participant_code: String) -> void:
	if _active:
		end_session("replaced")

	var code: String = participant_code.strip_edges()

	if code.is_empty():
		code = "sem-codigo"

	code = code.validate_filename()

	var stamp: String = (
		Time.get_datetime_string_from_system(false, false)
		.replace(":", "-")
	)

	_session = {
		"format_version": LOG_FORMAT_VERSION,
		"participant_code": code,
		"started_at": Time.get_datetime_string_from_system(false, true),
		"ended_at": "",
		"end_reason": "",
	}

	_events.clear()
	_details_views.clear()
	_start_ticks_msec = Time.get_ticks_msec()
	_file_path = "%s/%s_%s.json" % [SESSIONS_DIR, code, stamp]
	_active = true

	DirAccess.make_dir_recursive_absolute(get_sessions_folder())

	log_event("session_start", {})


func log_event(type: String, data: Dictionary) -> void:
	if not _active:
		return

	var entry: Dictionary = {
		"t": _elapsed_seconds(),
		"type": type,
	}

	entry.merge(data)
	_events.append(entry)
	_save()


## Acumula o tempo que o jogador passou lendo o painel
## educativo de uma carta durante a partida.
func note_details_view(card_id: String, seconds: float) -> void:
	if not _active or card_id.is_empty():
		return

	if seconds < MIN_DETAILS_SECONDS:
		return

	var entry: Dictionary = _details_views.get(
		card_id,
		{"views": 0, "seconds": 0.0}
	)

	entry["views"] = int(entry["views"]) + 1
	entry["seconds"] = snappedf(
		float(entry["seconds"]) + seconds,
		0.01
	)

	_details_views[card_id] = entry
	_save()


func end_session(reason: String) -> void:
	if not _active:
		return

	log_event("session_end", {"reason": reason})

	_session["ended_at"] = Time.get_datetime_string_from_system(
		false,
		true
	)
	_session["end_reason"] = reason
	_save()

	_active = false


func _elapsed_seconds() -> float:
	return snappedf(
		(Time.get_ticks_msec() - _start_ticks_msec) / 1000.0,
		0.01
	)


func _save() -> void:
	if _file_path.is_empty():
		return

	var payload: Dictionary = _session.duplicate()
	payload["duration_seconds"] = _elapsed_seconds()
	payload["summary"] = _build_summary()
	payload["card_details_views"] = _details_views
	payload["events"] = _events

	var file := FileAccess.open(_file_path, FileAccess.WRITE)

	if file == null:
		push_warning(
			"Nao foi possivel gravar o registro da sessao em %s."
			% _file_path
		)
		return

	file.store_string(JSON.stringify(payload, "\t"))
	file.close()


func _build_summary() -> Dictionary:
	var rounds_won := 0
	var rounds_lost := 0
	var plays := 0
	var insecure_cards := 0
	var breaches_opened := 0
	var breaches_closed := 0
	var scenarios_completed := 0
	var pauses := 0
	var encyclopedia_opens := 0

	for event: Dictionary in _events:
		var event_type: String = str(event.get("type", ""))

		match event_type:
			"round_end":
				if bool(event.get("won", false)):
					rounds_won += 1
				else:
					rounds_lost += 1

			"play":
				plays += 1
				insecure_cards += int(event.get("insecure_cards", 0))

				var opened: Array = event.get("breaches_opened", [])
				var closed: Array = event.get("breaches_closed", [])

				breaches_opened += opened.size()
				breaches_closed += closed.size()

			"scenario_end":
				scenarios_completed += 1

			"pause_opened":
				pauses += 1

			"encyclopedia_opened":
				encyclopedia_opens += 1

	var details_views := 0
	var details_seconds := 0.0

	for value: Variant in _details_views.values():
		var view: Dictionary = value
		details_views += int(view["views"])
		details_seconds += float(view["seconds"])

	return {
		"scenarios_completed": scenarios_completed,
		"rounds_won": rounds_won,
		"rounds_lost": rounds_lost,
		"plays": plays,
		"insecure_cards_played": insecure_cards,
		"breaches_opened": breaches_opened,
		"breaches_closed": breaches_closed,
		"pauses": pauses,
		"encyclopedia_opens": encyclopedia_opens,
		"card_details_views": details_views,
		"card_details_seconds": snappedf(details_seconds, 0.01),
	}
