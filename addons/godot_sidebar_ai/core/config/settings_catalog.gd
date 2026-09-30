@tool
extends RefCounted
class_name AISidebarSettingsCatalog

## Ayarların arayüz kataloğu (kural: AGENTS.md §3.8 "Ayarlar güncel kalır"). config.json'daki her
## kullanıcı ayarının arayüzde nerede düzenlendiği burada yazılıdır; yalnız sistemin tuttuğu
## anahtarlar INTERNAL_KEYS'tedir. tests/test_settings_coverage.gd: varsayılanlardaki ve kodun
## config'e yazdığı her anahtar bu iki listeden birinde olmalı, UI_KEYS'teki her anahtar da gerçekten
## bir ui/ dosyasında geçmelidir. Yeni ayar = aynı işte arayüz denetimi + buraya bir satır.

const UI_KEYS := {
	"provider_profiles": "Settings > Provider > Provider profiles (add, rename, delete; the shown profile is used on save)",
	"active_provider_id": "Settings > Provider > Provider profiles; provider picker in the model bar (2+ profiles)",
	"provider_type": "Settings > Provider",
	"base_url": "Settings > Provider",
	"api_key": "Settings > Provider",
	"stream": "Settings > Provider > Advanced",
	"vision_capable": "Settings > Provider > Advanced",
	"reasoning_effort": "Settings > Provider > Advanced (reasoning effort of thinking models: auto, low, medium, high)",
	"report_usage": "Settings > Provider > Advanced (ask the endpoint for token usage)",
	"context_window": "Settings > Model & Parameters > Context window",
	"selected_model": "Model bar (dock header)",
	"temperature": "Settings > Model & Parameters",
	"goal_max_rounds": "Settings > Model & Parameters > Goal mode (/goal)",
	"planning_mode": "Settings > General > Planning (plan first for every request; otherwise /plan)",
	"system_prompt": "Settings > Rules > Built-in rules (system prompt)",
	"language": "Settings > General",
	"ui_animations": "Settings > General > Appearance",
	"notifications": "Settings > General > Appearance (taskbar alert when the agent needs you or finishes)",
	"notification_sound": "Settings > General > Appearance (short sound with the alert)",
	"auto_approve_mode": "Settings > General; approval mode button in the model bar",
	"require_delete_approval": "Settings > General",
	"require_overwrite_approval": "Settings > General",
	"skills_enabled": "Settings > Skills; Skills button in the dock header",
	"mcp_bridge_enabled": "Settings > External Agent (MCP); /mcp on | off",
	"mcp_bridge_port": "Settings > External Agent (MCP)",
	"mcp_bridge_token": "Settings > External Agent (MCP) (generated; shown masked, copied in the connect command)",
	"blender_bridge_enabled": "Settings > Blender",
	"blender_bridge_url": "Settings > Blender",
	"blender_bridge_token": "Settings > Blender (copied from the Blender add-on panel; shown masked)",
}

## Kullanıcının düzenlemediği, sistemin tuttuğu anahtarlar.
const INTERNAL_KEYS := {
	"cached_models": "last model list fetched from the provider (Refresh in the model bar)",
	"config_version": "format version of config.json; migrate() upgrades older files",
}
