extends RefCounted
class_name Accounts
## Учётные записи. Пароль хранится только как PBKDF2-HMAC-SHA256 с солью.

const FILE := "user://accounts.json"
const ITER := 20000
const MIN_PASS := 8


static func create(user: String, pw: String) -> bool:
	var key := user.to_lower()
	var data := _load()
	if data.has(key) or pw.length() < MIN_PASS:
		return false
	var salt := Crypto.new().generate_random_bytes(16)
	var h := _derive(pw.to_utf8_buffer(), salt, ITER)
	data[key] = {
		"salt": Marshalls.raw_to_base64(salt),
		"hash": Marshalls.raw_to_base64(h),
		"iter": ITER,
	}
	_save(data)
	return true


static func check(user: String, pw: String) -> bool:
	var rec = _load().get(user.to_lower())
	if typeof(rec) != TYPE_DICTIONARY:
		return false
	var salt := Marshalls.base64_to_raw(rec["salt"])
	var want := Marshalls.base64_to_raw(rec["hash"])
	var got := _derive(pw.to_utf8_buffer(), salt, int(rec["iter"]))
	return _ct_eq(got, want)


static func _load() -> Dictionary:
	if not FileAccess.file_exists(FILE):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


static func _save(data: Dictionary) -> void:
	var f := FileAccess.open(FILE, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))


static func _derive(pw: PackedByteArray, salt: PackedByteArray, iters: int) -> PackedByteArray:
	var c := Crypto.new()
	var u := c.hmac_digest(HashingContext.HASH_SHA256, pw, salt + PackedByteArray([0, 0, 0, 1]))
	var t := u.duplicate()
	for _i in range(1, iters):
		u = c.hmac_digest(HashingContext.HASH_SHA256, pw, u)
		for j in t.size():
			t[j] ^= u[j]
	return t


static func _ct_eq(a: PackedByteArray, b: PackedByteArray) -> bool:
	if a.size() != b.size():
		return false
	var d := 0
	for i in a.size():
		d |= a[i] ^ b[i]
	return d == 0
