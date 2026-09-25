@tool
extends RefCounted

## Kayıtlı ChatSession mesajlarından akış bileşenlerini yeniden üretir (History replay, SRP).
## Bileşenleri yalnızca üretir; akışa eklemek ChatDock'un işidir.

const AISidebarChatSession = preload("res://addons/godot_sidebar_ai/core/chat/chat_session.gd")
const AISidebarMessageBubble = preload("res://addons/godot_sidebar_ai/ui/components/message_bubble.gd")
const AISidebarActivityGroup = preload("res://addons/godot_sidebar_ai/ui/components/activity_group.gd")
const AISidebarClarificationCard = preload("res://addons/godot_sidebar_ai/ui/components/clarification_card.gd")
const AISidebarTelemetryCard = preload("res://addons/godot_sidebar_ai/ui/components/telemetry_card.gd")
const AISidebarToolPresentation = preload("res://addons/godot_sidebar_ai/ui/presenters/tool_presentation.gd")

## Oturumdaki mesajları sırasıyla bileşenlere çevirir; telemetri kartı en sona eklenir.
## on_meta: bubble ve activity gruplarının meta_clicked sinyaline bağlanır.
static func build(sess: AISidebarChatSession, on_meta: Callable) -> Array[Control]:
	var out: Array[Control] = []
	if not sess:
		return out
		
	for m in sess.messages:
		if not m is Dictionary:
			continue
		var role = str(m.get("role", ""))
		var content = m.get("content", "")
		
		if role == "user" or role == "command" or role == "slash_command":
			var txt = ""
			var vision_inputs: Array = []
			if m.has("display_text") and not str(m["display_text"]).is_empty():
				txt = str(m["display_text"])
			elif content is String:
				txt = content
			elif content is Array:
				for part in content:
					if part is Dictionary:
						if part.get("type") == "text":
							txt = str(part.get("text", ""))
						elif part.get("type") == "image_url":
							vision_inputs.append(part)
			if m.has("vision_inputs") and m["vision_inputs"] is Array:
				for vi in m["vision_inputs"]:
					if not vision_inputs.has(vi):
						vision_inputs.append(vi)
			if txt.contains("\n\n==="):
				var parts_prompt = txt.split("\n\n===")
				txt = parts_prompt[0]
			var bubble_role = role
			if bubble_role == "user" and txt.begins_with("/"):
				bubble_role = "command"
			var bubble = AISidebarMessageBubble.new(bubble_role, txt, vision_inputs)
			bubble.meta_clicked.connect(on_meta)
			out.append(bubble)
			
		elif role == "assistant":
			var txt = str(content) if content != null else ""
			# Gecmis oturumlarda kayitli ham tool-call zarflari da gosterilmez.
			txt = AISidebarMessageBubble.strip_tool_call_envelopes(txt, false).strip_edges()
			if not txt.is_empty():
				var bubble = AISidebarMessageBubble.new("assistant", txt)
				bubble.meta_clicked.connect(on_meta)
				out.append(bubble)
				
			if m.has("tool_calls") and m["tool_calls"] is Array:
				var tcs = m["tool_calls"]
				if tcs.size() > 0:
					var grp = AISidebarActivityGroup.new(false)
					grp.meta_clicked.connect(on_meta)
					for tc in tcs:
						if tc is Dictionary:
							var fn = tc.get("name", "")
							var args = tc.get("arguments", {})
							grp.add_activity("✓", AISidebarToolPresentation.human_title(fn, args), 100, JSON.stringify(args))
					grp.complete_group()
					out.append(grp)
					
		elif role == "tool":
			var fn_name = str(m.get("name", ""))
			var raw_content = m.get("content", "{}")
			var parsed = JSON.parse_string(str(raw_content))
			if fn_name == "ask_user" and parsed is Dictionary and parsed.has("data"):
				var d = parsed["data"]
				var q = str(d.get("question", ""))
				var a = str(d.get("user_answer", ""))
				var card = AISidebarClarificationCard.new(q, [])
				card.show_as_answered(a)
				out.append(card)
				
	if not sess.telemetry.is_empty():
		var tc = AISidebarTelemetryCard.new(sess.telemetry)
		out.append(tc)
	return out
