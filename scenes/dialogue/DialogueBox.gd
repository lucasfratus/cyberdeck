extends Control
class_name DialogueBox

signal finished

@onready var portrait: TextureRect = \
	$DialoguePanel/MarginContainer/HBoxContainer/PortraitFrame/Portrait

@onready var speaker_label: Label = \
	$DialoguePanel/MarginContainer/HBoxContainer/DialogueContent/SpeakerLabel

@onready var dialogue_text: Label = \
	$DialoguePanel/MarginContainer/HBoxContainer/DialogueContent/DialogueText

@onready var continue_button: Button = \
	$DialoguePanel/MarginContainer/HBoxContainer/DialogueContent/ContinueButton


var dialogue_active := false
var dialogue_sequence: Array[Dictionary] = []
var current_dialogue_index := 0


func _ready() -> void:
	continue_button.pressed.connect(_on_continue_button_pressed)
	hide()


func show_dialogue(
	speaker: String,
	text: String,
	portrait_texture: Texture2D = null
) -> void:
	show_sequence([
		{
			"speaker": speaker,
			"text": text,
			"portrait": portrait_texture
		}
	])


func show_sequence(sequence: Array[Dictionary]) -> void:
	if sequence.is_empty():
		push_warning("Tentativa de exibir uma sequência de diálogo vazia.")
		return

	dialogue_sequence = sequence
	current_dialogue_index = 0
	dialogue_active = true

	continue_button.disabled = false
	show()

	_show_current_line()
	continue_button.grab_focus()


func _show_current_line() -> void:
	if current_dialogue_index >= dialogue_sequence.size():
		close_dialogue()
		return

	var current_line: Dictionary = dialogue_sequence[current_dialogue_index]

	speaker_label.text = str(
		current_line.get("speaker", "")
	)

	dialogue_text.text = str(
		current_line.get("text", "")
	)

	var portrait_texture: Texture2D = current_line.get(
		"portrait",
		null
	)

	portrait.texture = portrait_texture
	portrait.visible = portrait_texture != null

	if current_dialogue_index == dialogue_sequence.size() - 1:
		continue_button.text = "Concluir"
	else:
		continue_button.text = "Continuar"


func advance_dialogue() -> void:
	if not dialogue_active:
		return

	current_dialogue_index += 1

	if current_dialogue_index >= dialogue_sequence.size():
		close_dialogue()
		return

	_show_current_line()


func close_dialogue() -> void:
	if not dialogue_active:
		return

	dialogue_active = false
	continue_button.disabled = true

	dialogue_sequence.clear()
	current_dialogue_index = 0

	hide()
	finished.emit()


func is_dialogue_active() -> bool:
	return dialogue_active


func _on_continue_button_pressed() -> void:
	advance_dialogue()


func _unhandled_input(event: InputEvent) -> void:
	if not dialogue_active:
		return

	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		advance_dialogue()
