#!/usr/bin/env bash
#
# 一条命令在浏览器里预览博客。
#
# 没装 Hugo 就自动下载（只解压到项目里的 .tools/，不装进系统、不需要 sudo），
# 没拉主题就自动拉，然后启动本地服务器。
#
# 用法:
#   ./scripts/preview.sh
#   ./scripts/preview.sh --setup-only   # 只准备 Hugo 和主题，不启动服务器
#   PORT=8080 ./scripts/preview.sh     # 换端口
#
set -euo pipefail

SETUP_ONLY=0
case "${1:-}" in
  --setup-only) SETUP_ONLY=1 ;;
  "") ;;
  *) echo "未知参数：$1（可用：--setup-only）" >&2; exit 1 ;;
esac

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HUGO_VERSION="${HUGO_VERSION:-0.166.0}"
TOOLS_DIR="$ROOT_DIR/.tools"
HUGO_BIN="$TOOLS_DIR/hugo"
PORT="${PORT:-1313}"

download_hugo() {
  local url tmp pkg found payload extract_dir

  url="https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_darwin-universal.pkg"
  echo "==> 没找到 Hugo，开始下载 ${HUGO_VERSION}（约 30 MB，只需下载这一次）"

  mkdir -p "$TOOLS_DIR"
  tmp="$(mktemp -d)"
  pkg="$tmp/hugo.pkg"

  curl -fL --progress-bar -o "$pkg" "$url"

  # .pkg 本质上是个压缩包。这里只是把它解开、把里面的二进制拷出来，
  # 不安装任何东西，也不碰系统目录。
  if ! pkgutil --expand-full "$pkg" "$tmp/expanded" 2>/dev/null; then
    pkgutil --expand "$pkg" "$tmp/expanded"
  fi

  found="$(find "$tmp/expanded" -type f -name hugo 2>/dev/null | head -1)"

  # 某些系统上 --expand-full 不解包 payload，就手动解一次
  if [[ -z "$found" ]]; then
    payload="$(find "$tmp/expanded" -type f -name Payload 2>/dev/null | head -1)"
    if [[ -n "$payload" ]]; then
      extract_dir="$tmp/payload"
      mkdir -p "$extract_dir"
      ( cd "$extract_dir" && gzip -dc "$payload" | cpio -i 2>/dev/null ) || true
      found="$(find "$extract_dir" -type f -name hugo 2>/dev/null | head -1)"
    fi
  fi

  if [[ -z "$found" ]]; then
    rm -rf "$tmp"
    echo
    echo "没能从安装包里取出 hugo 二进制文件。" >&2
    echo "可以改用 Homebrew 安装，然后再跑一次这个脚本：" >&2
    echo "    HOMEBREW_NO_AUTO_UPDATE=1 brew install hugo" >&2
    exit 1
  fi

  cp "$found" "$HUGO_BIN"
  chmod +x "$HUGO_BIN"
  rm -rf "$tmp"
}

if command -v hugo >/dev/null 2>&1; then
  HUGO_BIN="$(command -v hugo)"
  echo "==> 使用已安装的 Hugo：$("$HUGO_BIN" version | head -1)"
elif [[ -x "$HUGO_BIN" ]]; then
  echo "==> 使用项目里的 Hugo：$("$HUGO_BIN" version | head -1)"
else
  download_hugo
  echo "==> Hugo 就绪：$("$HUGO_BIN" version | head -1)"
fi

"$ROOT_DIR/scripts/setup-theme.sh"

if (( SETUP_ONLY )); then
  echo
  echo "==> 准备完成（--setup-only，没有启动服务器）"
  exit 0
fi

echo
echo "======================================================"
echo "   浏览器打开：  http://localhost:${PORT}"
echo "   停止服务器：  Ctrl+C"
echo "======================================================"
echo

exec "$HUGO_BIN" server \
  --source "$ROOT_DIR" \
  --port "$PORT" \
  --bind 127.0.0.1 \
  --baseURL "http://localhost:${PORT}/" \
  --cleanDestinationDir \
  --buildDrafts
