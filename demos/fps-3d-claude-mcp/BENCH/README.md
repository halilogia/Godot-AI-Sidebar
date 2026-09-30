# fps-3d-claude-mcp

Bu demo sidebar ajanının değil, **Claude Code'un** (claude-opus-5-5) iki MCP sunucusuyla yaptığı çalışmadır: `godot` (Godot AI Sidebar köprüsü) ve `blender` (Blender Copilot köprüsü). Başlangıç noktası araçsız tek geçişte yazılmış FPS'ti; sonra oyun çalıştırılıp ölçüldü ve üç turda düzeltildi (ölme süresi, silah boyu, sis rengi, HUD sırası), kutu ve silindirlerin yerine Blender'da modellenen `.glb` dosyaları kondu. Modeller: `assets/models/*.glb` (recenter açık, çarpışma kutusu birleşik AABB'den).

Açmak için: klasörü Godot 4.7'de aç ve eklentiyi `scripts/sync-example.ps1` ile bağla. Ana sahne `res://scenes/Main.tscn`.
