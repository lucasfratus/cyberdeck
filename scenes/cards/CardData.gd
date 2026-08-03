extends Resource
class_name CardData

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC
}

enum Category {
	AUTHENTICATION,
	EMAIL,
	NETWORK,
	WEB,
	BACKUP,
	PRIVACY,
	MALWARE,
	SOCIAL_ENGINEERING
}

@export var id: StringName
@export var title: String = ""
@export_multiline var description: String = ""
@export_multiline var educational_description: String = ""

@export var illustration: Texture2D
@export var category_icon: Texture2D

@export var category: Category

@export var rarity: Rarity = Rarity.COMMON

@export var protection: int = 0
@export var vulnerability: float = 1.0

@export_group("Security Breach")
@export var opens_breach: SecurityBreachData
