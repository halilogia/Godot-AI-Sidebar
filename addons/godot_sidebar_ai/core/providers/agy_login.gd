@tool
extends RefCounted
## AGY için Google hesabı girişi yardımcıları (SRP: yalnız giriş başlatma ve doğrulama).
##
## agy'nin `login` alt komutu yoktur: ilk interaktif çalıştırmada tarayıcıdan Google OAuth açar.
## Headless stream-json modunda giriş yoksa sessizce bekler. Bu yüzden giriş, agy'nin kendi
## konsol penceresinde başlatılır; doğrulama en küçük istekle (`--print`) yapılır.
## Kimlik bilgisi/token okunmaz, saklanmaz ve loglanmaz.

enum Result { OK, LOGIN_REQUIRED, NOT_FOUND, TIMEOUT }

const VERIFY_TIMEOUT := "30s"
const _LOGIN_HINTS := ["login", "sign in", "sign-in", "authenticate", "unauthorized", "oauth", "giriş", "google"]

## Windows'ta agy'yi kendi konsol penceresinde açan komut; diğer sistemlerde doğrudan agy.
static func login_command() -> Dictionary:
	if OS.get_name() == "Windows":
		return {"exe": "conhost.exe", "args": PackedStringArray(["agy"])}
	return {"exe": "agy", "args": PackedStringArray()}

static func verify_args() -> PackedStringArray:
	return PackedStringArray(["--print", "ok", "--print-timeout", VERIFY_TIMEOUT])

## Saf mantık: çıkış kodu ve çıktıdan sonucu belirler (test edilebilir).
static func classify(exit_code: int, output: String) -> int:
	if exit_code == -1:
		return Result.NOT_FOUND
	var text := output.to_lower()
	if exit_code == 0 and not text.strip_edges().is_empty():
		for hint: String in _LOGIN_HINTS:
			if text.begins_with(hint) or text.contains("please " + hint):
				return Result.LOGIN_REQUIRED
		return Result.OK
	if exit_code == 0:
		return Result.TIMEOUT
	for hint: String in _LOGIN_HINTS:
		if text.contains(hint):
			return Result.LOGIN_REQUIRED
	return Result.TIMEOUT

## agy'yi kendi konsol penceresinde açar (Google girişi tarayıcıda tamamlanır). Başarı: süreç id > 0.
static func start_login() -> int:
	var cmd := login_command()
	return OS.create_process(str(cmd["exe"]), cmd["args"] as PackedStringArray)

## Bloklayan doğrulama; Thread içinden çağır. Çıktıyı ve sonucu döndürür.
static func verify_blocking() -> int:
	var output: Array = []
	var code := OS.execute("agy", verify_args(), output, true)
	return classify(code, "\n".join(output))
