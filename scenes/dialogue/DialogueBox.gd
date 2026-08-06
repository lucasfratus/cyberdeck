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

@onready var dialogue_panel: PanelContainer = $DialoguePanel
@onready var blocker: ColorRect = $Blocker

var dialogue_active := false
var dialogue_sequence: Array[Dictionary] = []
var current_dialogue_index := 0

const PANEL_SIDE_MARGIN := 70.0
const PANEL_EDGE_MARGIN := 40.0
const PANEL_HEIGHT := 180.0

signal line_changed(highlight_target: DialogueLineData.HighlightTarget)

func _ready() -> void:
	continue_button.pressed.connect(_on_continue_button_pressed)
	hide()


func show_dialogue(
	speaker: String,
	text: String,
	portrait_texture: Texture2D = null
) -> void:
	_set_dialogue_position(DialogueData.Position.BOTTOM)

	show_sequence([
		{
			"speaker": speaker,
			"text": text,
			"portrait": portrait_texture
		}
	])


func show_dialogue_data(dialogue_data: DialogueData, blocker_alpha := 0.15) -> void:
	set_blocker_alpha(blocker_alpha)
	if dialogue_data == null:
		push_warning("Tentativa de exibir um diálogo nulo.")
		return

	if dialogue_data.lines.is_empty():
		push_warning(
			"O diálogo '%s' não possui falas."
			% dialogue_data.id
		)
		return

	var sequence: Array[Dictionary] = []

	for line in dialogue_data.lines:
		if line == null:
			continue

		sequence.append({
			"speaker": line.speaker,
			"text": line.text,
			"portrait": line.portrait,
			"highlight_target": line.highlight_target
		})

	if sequence.is_empty():
		push_warning(
			"O diálogo '%s' não possui falas válidas."
			% dialogue_data.id
		)
		return

	_set_dialogue_position(dialogue_data.position)
	show_sequence(sequence)
	

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
	
	line_changed.emit(
	current_line.get(
		"highlight_target",
		DialogueLineData.HighlightTarget.NONE
		)
	)
	
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
	line_changed.emit(
	DialogueLineData.HighlightTarget.NONE
	)
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


func _set_dialogue_position(
	dialogue_position: DialogueData.Position
) -> void:
	match dialogue_position:
		DialogueData.Position.TOP:
			dialogue_panel.set_anchors_preset(
				Control.PRESET_TOP_WIDE
			)

			dialogue_panel.offset_left = PANEL_SIDE_MARGIN
			dialogue_panel.offset_top = PANEL_EDGE_MARGIN
			dialogue_panel.offset_right = -PANEL_SIDE_MARGIN
			dialogue_panel.offset_bottom = (
				PANEL_EDGE_MARGIN + PANEL_HEIGHT
			)

		DialogueData.Position.BOTTOM:
			dialogue_panel.set_anchors_preset(
				Control.PRESET_BOTTOM_WIDE
			)

			dialogue_panel.offset_left = PANEL_SIDE_MARGIN
			dialogue_panel.offset_top = (
				-PANEL_EDGE_MARGIN - PANEL_HEIGHT
			)
			dialogue_panel.offset_right = -PANEL_SIDE_MARGIN
			dialogue_panel.offset_bottom = -PANEL_EDGE_MARGIN
			
	
func set_blocker_alpha(alpha: float) -> void:
	var color := blocker.color
	color.a = alpha
	blocker.color = color
