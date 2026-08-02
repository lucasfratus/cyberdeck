extends Resource
class_name RoundDialogueEventData

enum TriggerType {
	AFTER_PLAY
}

@export var id: String = ""
@export var trigger_type: TriggerType = TriggerType.AFTER_PLAY
@export_range(1, 10, 1) var trigger_value: int = 1
@export var dialogue: DialogueData
