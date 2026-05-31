#!/usr/bin/env bash
# 打包发布用 DMG（ad-hoc 自签，未公证；供官网/GitHub 直接下载）。
# 用法: scripts/make-dmg.sh [release|debug]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CONFIG="${1:-release}"
APP_NAME="StayAwake"
APP="dist/${APP_NAME}.app"
PLIST="${APP}/Contents/Info.plist"

echo "[1/3] 构建 ${APP_NAME}.app"
./scripts/build-app.sh "$CONFIG" >/dev/null
[[ -d "$APP" ]] || { echo "error: 未找到 ${APP}" >&2; exit 1; }

VER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST" 2>/dev/null || echo 1.0.0)"
DMG="dist/${APP_NAME}-${VER}.dmg"

echo "[2/3] 组装 DMG 暂存目录"
STAGE="$(mktemp -d)/${APP_NAME}"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
# 首次打开说明，随 DMG 附带
cat > "$STAGE/首次打开说明.txt" <<'EOF'
StayAwake 安装与首次打开
========================
1. 把 StayAwake 拖到 Applications 文件夹。
2. 首次打开（本版本未做 Apple 公证，会被门禁拦一次）：
   方式 A：打开 系统设置 → 隐私与安全性，找到 “已阻止 StayAwake” 的提示，点“仍要打开”。
   方式 B（终端一条命令去掉隔离标记）：
       xattr -dr com.apple.quarantine /Applications/StayAwake.app
   之后正常双击即可，图标常驻菜单栏（不在 Dock）。
3. 合盖继续运行需要管理员授权；开启“切换时免输密码”可一次授权后免密。
EOF

echo "[3/3] 生成 ${DMG}"
rm -f "$DMG"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
echo "done: ${DMG}"
ls -lh "$DMG"
