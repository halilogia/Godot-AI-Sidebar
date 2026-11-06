@tool
extends RefCounted

const AgyLogin = preload("res://addons/godot_sidebar_ai/core/providers/agy_login.gd")

static func run() -> Dictionary:
	var passed := 0
	var failed := 0
	var errors: Array = []
	var cases := [
		["çalışan agy çıktısı", AgyLogin.classify(0, "ok"), AgyLogin.Result.OK],
		["agy bulunamadı", AgyLogin.classify(-1, ""), AgyLogin.Result.NOT_FOUND],
		["boş çıktı (zaman aşımı)", AgyLogin.classify(0, ""), AgyLogin.Result.TIMEOUT],
		["giriş gerekli (hata çıkışı)", AgyLogin.classify(1, "Please sign in with Google"), AgyLogin.Result.LOGIN_REQUIRED],
		["giriş gerekli (yanıt metni)", AgyLogin.classify(0, "Please login to continue"), AgyLogin.Result.LOGIN_REQUIRED],
		["bilinmeyen hata", AgyLogin.classify(2, "boom"), AgyLogin.Result.TIMEOUT],
	]
	for c: Array in cases:
		if c[1] == c[2]:
			passed += 1
		else:
			failed += 1
			errors.append("agy_login.classify '%s': beklenen %s, gelen %s" % [c[0], c[2], c[1]])
	var args := AgyLogin.verify_args()
	if args.has("--print") and args.has("--print-timeout"):
		passed += 1
	else:
		failed += 1
		errors.append("agy_login.verify_args --print ve --print-timeout içermeli: " + str(args))
	var cmd := AgyLogin.login_command()
	if str(cmd["exe"]) != "" and cmd["args"] is PackedStringArray:
		passed += 1
	else:
		failed += 1
		errors.append("agy_login.login_command geçerli exe/args dönmeli: " + str(cmd))
	return {"name": "AgyLoginTests", "passed": passed, "failed": failed, "errors": errors}
