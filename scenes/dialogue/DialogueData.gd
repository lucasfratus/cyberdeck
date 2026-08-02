extends Resource
class_name DialogueData

enum Position {
	TOP,
	BOTTOM
}

@export var id: String = ""
@export var position: Position = Position.BOTTOM
@export var lines: Array[DialogueLineData] = []
