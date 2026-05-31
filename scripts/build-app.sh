#!/usr/bin/env bash
# 构建 StayAwake 可执行文件并组装为 StayAwake.app 应用包。
# 用法: scripts/build-app.sh [debug|release]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CONFIG="${1:-release}"
APP_NAME="StayAwake"
BIN_NAME="StayAwake"
BUNDLE_ID="com.chenran.stayawake"

echo "[1/4] swift build (${CONFIG})"
swift build -c "$CONFIG"

BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"
BIN_PATH="${BIN_DIR}/${BIN_NAME}"
if [[ ! -x "$BIN_PATH" ]]; then
    echo "error: 未找到可执行文件 ${BIN_PATH}" >&2
    exit 1
fi

APP_DIR="${ROOT}/dist/${APP_NAME}.app"
echo "[2/4] 组装应用包 ${APP_DIR}"
rm -rf "$APP_DIR"
mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources"
cp "$BIN_PATH" "${APP_DIR}/Contents/MacOS/${BIN_NAME}"
cp "${ROOT}/Resources/Info.plist" "${APP_DIR}/Contents/Info.plist"
if [[ -f "${ROOT}/Resources/AppIcon.icns" ]]; then
    cp "${ROOT}/Resources/AppIcon.icns" "${APP_DIR}/Contents/Resources/AppIcon.icns"
fi

echo "[3/4] ad-hoc 代码签名 (本地开发)"
if ! codesign --force --sign - "$APP_DIR" 2>/dev/null; then
    echo "warn: ad-hoc 签名失败，应用仍可本地运行，但登录项功能可能受限" >&2
fi

echo "[4/4] 完成: ${APP_DIR}"
echo "运行: open \"${APP_DIR}\"   或   \"${APP_DIR}/Contents/MacOS/${BIN_NAME}\""
