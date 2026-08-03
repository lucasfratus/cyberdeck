extends Resource
class_name SecurityBreachData

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D

@export_group("Effect")
@export var vulnerability_per_play: float = 0.0
