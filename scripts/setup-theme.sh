#!/usr/bin/env bash
#
# 把主题拉到 themes/ 目录（该目录不进仓库）。
# CI 构建时会做同样的事，这个脚本是给本地预览用的。
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THEME_REPO="${THEME_REPO:-https://github.com/codesign2020/blank-magazine}"
DEST="$ROOT_DIR/themes/blank-magazine"

mkdir -p "$ROOT_DIR/themes"

if [[ -d "$DEST/.git" ]]; then
  echo "主题已存在，尝试更新..."
  # 断网时不该卡在这里，用本地已有的版本继续就好
  if ! git -C "$DEST" pull --ff-only; then
    echo "更新失败（可能没联网），沿用本地已有的版本。"
  fi
else
  git clone --depth=1 "$THEME_REPO" "$DEST"
fi

echo "主题就绪：$DEST"
