class_name CardCategory

## Nomes dos temas de seguranca usados para agrupar as
## cartas na enciclopedia.

static func display_name(category: int) -> String:
	match category:
		CardData.Category.AUTHENTICATION:
			return "Autenticação"
		CardData.Category.EMAIL:
			return "E-mail"
		CardData.Category.NETWORK:
			return "Rede"
		CardData.Category.WEB:
			return "Web"
		CardData.Category.BACKUP:
			return "Backup"
		CardData.Category.PRIVACY:
			return "Privacidade"
		CardData.Category.MALWARE:
			return "Programas maliciosos"
		CardData.Category.SOCIAL_ENGINEERING:
			return "Engenharia social"
		_:
			return "Outros"


## Ordem em que os temas aparecem na enciclopedia.
static func display_order() -> Array[int]:
	return [
		CardData.Category.AUTHENTICATION,
		CardData.Category.EMAIL,
		CardData.Category.WEB,
		CardData.Category.NETWORK,
		CardData.Category.MALWARE,
		CardData.Category.SOCIAL_ENGINEERING,
		CardData.Category.PRIVACY,
		CardData.Category.BACKUP
	]
