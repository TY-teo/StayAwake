#!/usr/bin/env bash
# 从源 PNG 生成应用图标：去白边/透明化/方形化 -> 多分辨率 AppIcon.icns。
# 用法: scripts/make-icon.sh [源png，默认取 icon/ 下第一个 png]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SRC="${1:-}"
if [[ -z "$SRC" ]]; then SRC="$(ls -t icon/*.png 2>/dev/null | head -1 || true)"; fi
[[ -f "$SRC" ]] || { echo "error: 未找到源图标 PNG" >&2; exit 1; }

echo "[1/3] 预处理（近白->透明，裁白边，方形化）: $SRC"
swift scripts/iconprep.swift "$SRC" Resources/AppIcon.png

echo "[2/3] 生成 iconset"
ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"
for pair in "16 16x16" "32 16x16@2x" "32 32x32" "64 32x32@2x" "128 128x128" "256 128x128@2x" "256 256x256" "512 256x256@2x" "512 512x512" "1024 512x512@2x"; do
    size="${pair%% *}"; name="${pair##* }"
    sips -z "$size" "$size" Resources/AppIcon.png --out "$ICONSET/icon_${name}.png" >/dev/null 2>&1
done

echo "[3/3] iconutil -> Resources/AppIcon.icns"
iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
echo "done: Resources/AppIcon.icns"
