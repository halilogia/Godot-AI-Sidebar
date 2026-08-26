@tool
extends SceneTree

var http: HTTPRequest
var start_t: int = 0

func _init() -> void:
	http = HTTPRequest.new()
	root.add_child.call_deferred(http)
	start_t = Time.get_ticks_msec()
	
	http.request_completed.connect(func(result, response_code, headers, body):
		var elapsed = (Time.get_ticks_msec() - start_t) / 1000.0
		print("--- HTTP NON-STREAMING RESULT ---")
		print("Elapsed: ", elapsed, "s | Response Code: ", response_code)
		print("Body text: ", body.get_string_from_utf8().left(100))
		quit(0)
	)
	
	# Wait one frame for node to enter tree
	await process_frame
	
	var body = JSON.stringify({
		"model": "all",
		"messages": [{"role": "user", "content": "Sadece 'ok' yaz."}],
		"stream": false
	})
	
	var err = http.request("http://localhost:20128/v1/chat/completions", ["Content-Type: application/json", "Connection: close"], HTTPClient.METHOD_POST, body)
	print("Request started err: ", err)
