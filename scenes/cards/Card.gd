extends Control
class_name Card

@onready var title = $Content/Main/Header/Title
@onready var category_icon = $Content/Main/Header/CategoryIcon
@onready var illustration = $Content/Main/IllustrationArea/Illustration
@onready var description = $Content/Main/DescriptionArea/MarginContainer/Description
@onready var protection = $Content/Main/Attributes/ProtectionBox/Protection/ProtectionValue
@onready var vulnerability = $Content/Main/Attributes/VulnerabilityBox/Vulnerability/VulnerabilityValue

var data: CardData

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
