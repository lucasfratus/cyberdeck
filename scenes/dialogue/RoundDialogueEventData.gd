extends Resource
class_name RoundDialogueEventData

enum TriggerType {
	AFTER_PLAY,
	PLAYS_REMAINING,
	CARD_PLAYED
}

@export var id: String = ""
@export var trigger_type: TriggerType = TriggerType.AFTER_PLAY

@export_group("Numeric Trigger")
@export_range(0, 10, 1) var trigger_value: int = 1

@export_group("Card Played")
@export var required_card_id: String = ""

@export_group("Dialogue")
@export var dialogue: DialogueData
