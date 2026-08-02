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


func _ready() -> void:
	continue_button.pressed.connect(_on_continue_button_pressed)
	#hide()


func show_dialogue(speaker: String, text: String,
	portrait_texture: Texture2D) -> void:
		
	speaker_label.text = speaker
	dialogue_text.text = text
	portrait.texture = portrait_texture

	dialogue_active = true
	continue_button.disabled = false

	show()
	continue_button.grab_focus()


func close_dialogue() -> void:
	if not dialogue_active:
		return

	dialogue_active = false
	continue_button.disabled = true

	hide()
	finished.emit()


func is_dialogue_active() -> bool:
	return dialogue_active


func _on_continue_button_pressed() -> void:
	close_dialogue()


func _unhandled_input(event: InputEvent) -> void:
	if not dialogue_active:
		return

	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		close_dialogue()
