extends RefCounted
class_name PlayVerifier
## Проверка покупок Google Play. По умолчанию ВСЁ отклоняется.
## Чтобы включить, нужна серверная проверка через Google Play Developer API
## (purchases.products.get с сервисным аккаунтом). Здесь она намеренно не подключена:
## без неё любая выдача товара была бы подделкой.

const ENABLED := false


static func verify(_product_id: String, _purchase_token: String) -> bool:
	if not ENABLED:
		return false
	return false
