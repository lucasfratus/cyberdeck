extends Node

@onready var card = $Card

func _ready():
	var data = load("res://scenes/cards/data/strong_password.tres")
	card.setup(data)
