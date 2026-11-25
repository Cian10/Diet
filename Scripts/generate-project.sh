#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
cd "$ROOT_DIR"

if [[ -n "${XCODEGEN_BIN:-}" ]]; then
  if [[ ! -x "$XCODEGEN_BIN" ]]; then
    echo "XCODEGEN_BIN 指向的文件不可执行：$XCODEGEN_BIN" >&2
    exit 1
  fi
elif command -v xcodegen >/dev/null 2>&1; then
  XCODEGEN_BIN="$(command -v xcodegen)"
elif [[ -x "$ROOT_DIR/.tooling-home/xcodegen/bin/xcodegen" ]]; then
  XCODEGEN_BIN="$ROOT_DIR/.tooling-home/xcodegen/bin/xcodegen"
else
  echo "未找到 XcodeGen。请安装：brew install xcodegen，或将官方 xcodegen 包解压到 .tooling-home/xcodegen。" >&2
  exit 1
fi

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "未检测到完整 Xcode。请安装 Xcode，并用 xcode-select 指向 Xcode.app。" >&2
  exit 1
fi

"$XCODEGEN_BIN" generate --spec project.yml
echo "已生成 DietApp.xcodeproj。请在 Xcode 中选择 DietApp macOS scheme；个人本机使用可选择 Sign to Run Locally。"
