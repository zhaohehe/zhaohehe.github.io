#!/usr/bin/env bash
#
# 把照片压成适合网页的 WebP，上传到 Cloudflare R2，
# 最后打印可以直接粘进 Markdown 的图片语法。
#
# 用法:
#   ./scripts/publish-photos.sh                  # 处理 photos-inbox/ 里的全部图片
#   ./scripts/publish-photos.sh ~/Pictures/*.jpg # 处理指定的文件
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INBOX="$ROOT_DIR/photos-inbox"
CONF="$ROOT_DIR/.photo-env"

if [[ -f "$CONF" ]]; then
  # shellcheck disable=SC1090
  source "$CONF"
fi

WIDTH="${WIDTH:-1600}"
WEBP_QUALITY="${WEBP_QUALITY:-82}"
# 灯箱用的大图：0 表示保持原始分辨率
FULL_WIDTH="${FULL_WIDTH:-0}"
FULL_QUALITY="${FULL_QUALITY:-90}"
R2_REMOTE="${R2_REMOTE:-r2}"
: "${R2_BUCKET:?未设置 R2_BUCKET，请照着 README 创建 .photo-env}"
: "${R2_PUBLIC_BASE:?未设置 R2_PUBLIC_BASE，请照着 README 创建 .photo-env}"

# 优先用项目里自带的 rclone（.tools/rclone），其次是系统里装的
if [[ -x "$ROOT_DIR/.tools/rclone" ]]; then
  RCLONE="$ROOT_DIR/.tools/rclone"
elif command -v rclone >/dev/null; then
  RCLONE="$(command -v rclone)"
else
  echo "缺少 rclone。"
  echo "  下载独立二进制（几秒，不用 brew）："
  echo "    curl -fsSL -o /tmp/rclone.zip https://downloads.rclone.org/rclone-current-osx-arm64.zip"
  echo "    unzip -q /tmp/rclone.zip -d /tmp/rc && cp /tmp/rc/*/rclone \"$ROOT_DIR/.tools/rclone\" && chmod +x \"$ROOT_DIR/.tools/rclone\""
  exit 1
fi

for tool in sips cwebp; do
  if ! command -v "$tool" >/dev/null; then
    echo "缺少 $tool。sips 是 macOS 自带，cwebp 用 brew install webp 安装。"
    exit 1
  fi
done

mkdir -p "$INBOX"

if [[ $# -gt 0 ]]; then
  INPUTS=("$@")
else
  shopt -s nullglob nocaseglob
  INPUTS=("$INBOX"/*.jpg "$INBOX"/*.jpeg "$INBOX"/*.png "$INBOX"/*.heic "$INBOX"/*.tif "$INBOX"/*.tiff)
  shopt -u nullglob nocaseglob
fi

if [[ ${#INPUTS[@]} -eq 0 ]]; then
  echo "photos-inbox/ 里还没有图片，放几张进去再跑一次。"
  exit 0
fi

# 按年月分目录，避免所有文件挤在一个前缀下
PREFIX="$(date +%Y/%m)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

long_edge() {
  local w h
  w="$(sips -g pixelWidth  "$1" | awk '/pixelWidth/  {print $2}')"
  h="$(sips -g pixelHeight "$1" | awk '/pixelHeight/ {print $2}')"
  if (( w >= h )); then echo "$w"; else echo "$h"; fi
}

human() { du -h "$1" | cut -f1 | tr -d ' '; }

URLS=()
for src in "${INPUTS[@]}"; do
  [[ -f "$src" ]] || { echo "跳过（不是文件）: $src"; continue; }

  name="$(basename "$src")"
  stem="${name%.*}"
  ext="$(printf '%s' "${name##*.}" | tr '[:upper:]' '[:lower:]')"
  base_jpg="$WORK/base-$stem.jpg"
  out_jpg="$WORK/$stem.jpg"
  out_webp="$WORK/$stem.webp"
  full_jpg="$WORK/$stem-full.jpg"
  full_webp="$WORK/$stem-full.webp"

  # 后面的中间文件都按 .jpg 命名，所以这里必须保证它真的是 JPEG。
  # JPEG 直接复用；HEIC（iPhone 默认格式）、PNG、TIFF 都用 sips 转一道，
  # 否则会因为「内容格式和文件名后缀对不上」而报错或产生警告。
  case "$ext" in
    jpg|jpeg)
      cp "$src" "$base_jpg"
      ;;
    *)
      sips -s format jpeg "$src" --out "$base_jpg" >/dev/null
      ;;
  esac

  # 只在超过 WIDTH 时缩放，绝不把手机上的小图放大
  if (( $(long_edge "$base_jpg") > WIDTH )); then
    sips -Z "$WIDTH" "$base_jpg" --out "$out_jpg" >/dev/null
  else
    cp "$base_jpg" "$out_jpg"
  fi

  cwebp -quiet -q "$WEBP_QUALITY" "$out_jpg" -o "$out_webp"
  "$RCLONE" copyto "$out_webp" "$R2_REMOTE:$R2_BUCKET/$PREFIX/${stem}.webp" --s3-no-check-bucket

  # 点开放大时用的那份。不指定 FULL_WIDTH 就保留原始分辨率。
  if (( FULL_WIDTH > 0 )) && (( $(long_edge "$base_jpg") > FULL_WIDTH )); then
    sips -Z "$FULL_WIDTH" "$base_jpg" --out "$full_jpg" >/dev/null
  else
    cp "$base_jpg" "$full_jpg"
  fi
  cwebp -quiet -q "$FULL_QUALITY" "$full_jpg" -o "$full_webp"
  "$RCLONE" copyto "$full_webp" "$R2_REMOTE:$R2_BUCKET/$PREFIX/${stem}-full.webp" --s3-no-check-bucket

  URLS+=("${R2_PUBLIC_BASE%/}/$PREFIX/${stem}.webp")
  printf '✓ %-32s 原图 %7s → 正文 %7s + 大图 %7s\n' \
    "$name" "$(human "$base_jpg")" "$(human "$out_webp")" "$(human "$full_webp")"
done

echo
if [[ ${#URLS[@]} -eq 0 ]]; then
  echo "没有成功处理任何图片。"
  exit 1
fi

echo "===== 用在文章正文里 ====="
for url in "${URLS[@]}"; do
  printf '![图片说明](%s)\n' "$url"
done

echo
echo "===== 用在相册里（粘进 content/gallery/相册名/index.md 的开头）====="
echo "photos:"
for url in "${URLS[@]}"; do
  printf '  - "%s"\n' "$url"
done
