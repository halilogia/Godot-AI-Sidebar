#!/usr/bin/env bash
# Çalışan bir demo benchmark'ının canlı olaylarını izler (<proje>/_bench/live.jsonl, demo_bench.gd yazar).
# Dosyayı açık tutmaz (Windows'ta yazanı kilitlemesin): her 5 sn yeni satırları okur ve yalnız önemli
# olayları basar: araç çağrıları, başarısız sonuçlar, hatalar, motor hataları, model metni, bitiş.
#
#   bash tools/demo_watch.sh "<proje klasörü>"      (boşsa en son benchmark projesi)

root="${HOME}/Documents/ai_sidebar_bench"
proj="${1:-$(ls -d "$root"/*/ 2>/dev/null | sort | tail -1)}"
f="${proj%/}/_bench/live.jsonl"
n=0
while true; do
  if [ -f "$f" ]; then
    total=$(wc -l < "$f")
    if [ "$total" -gt "$n" ]; then
      sed -n "$((n + 1)),${total}p" "$f" | grep -E '"kind":"(tool|error|engine_error|finish|text)"|"ok":"false"' \
        | sed -E 's/"args":"(.{0,160}).*/"args":"\1…"}/' | cut -c1-300
      n=$total
    fi
    grep -q '"kind":"finish"' "$f" && exit 0
  fi
  sleep 5
done
