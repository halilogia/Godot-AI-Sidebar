@tool
extends RefCounted
class_name AISidebarSettingsCatalog

## Ayarların arayüz kataloğu (kural: AGENTS.md §3.8 "Ayarlar güncel kalır"). config.json'daki her
## kullanıcı ayarının arayüzde nerede düzenlendiği burada yazılıdır; yalnız sistemin tuttuğu
## anahtarlar INTERNAL_KEYS'tedir. tests/test_settings_coverage.gd: varsayılanlardaki ve kodun
## config'e yazdığı her anahtar bu iki listeden birinde olmalı, UI_KEYS'teki her anahtar da gerçekten
## bir ui/ dosyasında geçmelidir. Yeni ayar = aynı işte arayüz denetimi + buraya bir satır.

const UI_KEYS := {
	"provider_type": "Settings > Provider",
	"base_url": "Settings > Provider",
	"api_key": "Settings > Provider",
	"stream": "Settings > Provider > Advanced",
	"vision_capable": "Settings > Provider > Advanced",
	"selected_model": "Model bar (dock header)",
	"temperature": "Settings > Model & Parameters",
	"max_agent_steps": "Settings > Model & Parameters",
	"max_iterations": "Settings > Model & Parameters (same control as max_agent_steps)",
	"system_prompt": "Settings > System Prompt",
	"language": "Settings > Appearance & Language",
	"auto_approve_mode": "Settings > Appearance & Language; approval mode button in the model bar",
	"require_delete_approval": "Settings > Appearance & Language > Approvals",
	"require_overwrite_approval": "Settings > Appearance & Language > Approvals",
	"skills_enabled": "Settings > Skills; Skills button in the dock header",
	"mcp_bridge_enabled": "Settings > External Agent (MCP); /mcp on | off",
	"mcp_bridge_port": "Settings > External Agent (MCP)",
	"mcp_bridge_token": "Settings > External Agent (MCP) (generated; shown masked, copied in the connect command)",
}

## Kullanıcının düzenlemediği, sistemin tuttuğu anahtarlar.
const INTERNAL_KEYS := {
	"cached_models": "last model list fetched from the provider (Refresh in the model bar)",
}
