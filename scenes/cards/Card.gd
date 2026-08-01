extends Control
class_name Card

@onready var title = $Content/Main/Header/Title
@onready var category_icon = $Content/Main/Header/CategoryIcon
@onready var illustration = $Content/Main/IllustrationArea/Illustration
@onready var description = $Content/Main/DescriptionArea/MarginContainer/Description
@onready var protection = $Content/Main/Attributes/ProtectionBox/Protection/ProtectionValue
@onready var vulnerability = $Content/Main/Attributes/VulnerabilityBox/Vulnerability/VulnerabilityValue
@onready var hover_area: Control = $HoverArea

var data: CardData

var hover_tween: Tween
var original_z_index := 0

const HOVER_SCALE := 1.08
const HOVER_DURATION := 0.12

func _ready() -> void:
	# A escala ocorrerá a partir do centro da carta.
	pivot_offset = size / 2.0

	hover_area.mouse_entered.connect(_on_hover_area_mouse_entered)
	hover_area.mouse_exited.connect(_on_hover_area_mouse_exited)

func setup(card_data: CardData):
	data = card_data

	if !is_node_ready():
		await ready

	title.text = data.title
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
