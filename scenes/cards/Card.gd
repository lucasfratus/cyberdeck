extends Control
class_name Card

@onready var title = $Content/Main/Header/Title
@onready var category_icon = $Content/Main/Header/CategoryIcon
@onready var illustration = $Content/Main/IllustrationArea/Illustration
@onready var description = $Content/Main/DescriptionArea/MarginContainer/Description
@onready var protection = $Content/Main/Attributes/ProtectionBox/Protection/ProtectionValue
@onready var vulnerability = $Content/Main/Attributes/VulnerabilityBox/Vulnerability/VulnerabilityValue
@onready var hover_area: Control = $HoverArea
@onready var selection_outline: Panel = $SelectionOutline

signal selection_requested(card: Card)
signal details_requested(card: Card)
signal details_hidden(card: Card)

var data: CardData
var is_selected := false
var hover_tween: Tween
var original_z_index := 0
var interaction_enabled := true

const HOVER_SCALE := 1.08
const HOVER_DURATION := 0.12

var hand_position := Vector2.ZERO
var position_tween: Tween

const SELECTED_OFFSET := Vector2(0, -20)
const SELECTION_MOVE_DURATION := 0.12


func _ready() -> void:
	# A escala ocorrerá a partir do centro da carta.
	pivot_offset = size / 2.0
	
	hover_area.mouse_entered.connect(
		_on_details_mouse_entered
	)

	hover_area.mouse_exited.connect(
		_on_details_mouse_exited
	)
	
	hover_area.mouse_entered.connect(_on_hover_area_mouse_entered)
	hover_area.mouse_exited.connect(_on_hover_area_mouse_exited)
	hover_area.gui_input.connect(_on_hover_area_gui_input)


func _on_details_mouse_entered() -> void:
	details_requested.emit(self)


func _on_details_mouse_exited() -> void:
	details_hidden.emit(self)

func setup(card_data: CardData):
	data = card_data

	if !is_node_ready():
		await ready

	title.text = data.title
	await _fit_title_font()
	
	description.text = data.description
	illustration.texture = data.illustration
	category_icon.texture = data.category_icon
	protection.text = str(data.protection)
	vulnerability.text = "×%.1f" % data.vulnerability
	
func _on_hover_area_mouse_entered() -> void:
	original_z_index = z_index
	z_index = 100

	_animate_scale(Vector2.ONE * HOVER_SCALE)


func _on_hover_area_mouse_exited() -> void:
	z_index = original_z_index

	_animate_scale(Vector2.ONE)


func _on_hover_area_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			selection_requested.emit(self)
			accept_event()


func set_selected(value: bool) -> void:
	is_selected = value
	selection_outline.visible = value
	_update_selection_position()


func _animate_scale(target_scale: Vector2) -> void:
	if hover_tween != null and hover_tween.is_valid():
		hover_tween.kill()

	hover_tween = create_tween()
	hover_tween.set_trans(Tween.TRANS_QUAD)
	hover_tween.set_ease(Tween.EASE_OUT)
	hover_tween.tween_property(
		self,
		"scale",
		target_scale,
		HOVER_DURATION
	)


func set_hand_position(new_position: Vector2, immediate := false) -> void:
	hand_position = new_position

	var target_position := _get_target_position()

	if immediate:
		if position_tween != null and position_tween.is_valid():
			position_tween.kill()

		position = target_position
	else:
		_animate_position(target_position)


func _update_selection_position() -> void:
	_animate_position(_get_target_position())


func _get_target_position() -> Vector2:
	if is_selected:
		return hand_position + SELECTED_OFFSET

	return hand_position


func _animate_position(target_position: Vector2) -> void:
	if position_tween != null and position_tween.is_valid():
		position_tween.kill()

	position_tween = create_tween()
	position_tween.set_trans(Tween.TRANS_QUAD)
	position_tween.set_ease(Tween.EASE_OUT)
	position_tween.tween_property(
		self,
		"position",
		target_position,
		SELECTION_MOVE_DURATION
	)


func set_interaction_enabled(enabled: bool) -> void:
	interaction_enabled = enabled

	if enabled:
		hover_area.mouse_filter = Control.MOUSE_FILTER_STOP
		return

	hover_area.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if hover_tween != null and hover_tween.is_valid():
		hover_tween.kill()

	if position_tween != null and position_tween.is_valid():
		position_tween.kill()

	scale = Vector2.ONE
	z_index = 0
	

func is_interaction_enabled() -> bool:
	return interaction_enabled


const TITLE_FONT_SIZE := 16
const TITLE_MIN_FONT_SIZE := 9


func _fit_title_font() -> void:
	# Espera os Containers definirem a largura real do Label.
	await get_tree().process_frame

	var available_width: float = title.size.x

	if available_width <= 0.0:
		return

	var font: Font = title.get_theme_font("font")
	var font_size := TITLE_FONT_SIZE

	while font_size > TITLE_MIN_FONT_SIZE:
		var text_width := font.get_string_size(
			title.text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size
		).x

		if text_width <= available_width:
			break

		font_size -= 1

	title.add_theme_font_size_override("font_size", font_size)
