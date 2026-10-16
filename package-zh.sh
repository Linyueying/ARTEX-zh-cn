#!/usr/bin/env bash
# 把 dist/<arch>/artex 打包成 Release 资产：
#   artex-<ver>-zh-linux-<arch>       裸二进制（install-zh.sh 下载后直接打成镜像）
#   artex-<ver>-zh-linux-<arch>.zip   官方风格发布包（artex + start.sh + skills/ + config.example.json）
#   SHA256SUMS                        校验值
#
# 用法：
#   ./package-zh.sh                  # 版本取 $ARTEX_VERSION，默认 0.3.21
#   ./package-zh.sh 0.3.22
#   ARTEX_ARCHES="amd64" ./package-zh.sh
set -euo pipefail
cd "$(cd "$(dirname "$0")" && pwd)"

VER="${1:-${ARTEX_VERSION:-0.3.21}}"
ARCHES="${ARTEX_ARCHES:-amd64 arm64}"
OUT="dist/release"

rm -rf "$OUT"
mkdir -p "$OUT"

for arch in $ARCHES; do
  BIN="dist/${arch}/artex"
  if [ ! -f "$BIN" ]; then
    echo "缺少 $BIN —— 先编译，例如：" >&2
    echo "  CGO_ENABLED=0 GOOS=linux GOARCH=${arch} go build -tags embedui -o $BIN ./cmd/artex" >&2
    exit 1
  fi

  root="artex-${VER}-zh-linux-${arch}"
  cp "$BIN" "$OUT/$root"                     # 裸二进制

  stage="$OUT/_stage/$root"                  # zip 的暂存目录
  mkdir -p "$stage"
  cp "$BIN" "$stage/artex"
  cp start.sh "$stage/start.sh"; chmod +x "$stage/start.sh"
  cp -r skills "$stage/skills"
  cp config.example.json "$stage/config.example.json"
  [ -f README-zh-cn.md ] && cp README-zh-cn.md "$stage/"

  python3 - "$OUT" "$root" <<'PY'
import os, sys, zipfile
out, root = sys.argv[1], sys.argv[2]
stage = os.path.join(out, '_stage', root)
with zipfile.ZipFile(os.path.join(out, root + '.zip'), 'w',
                     zipfile.ZIP_DEFLATED, compresslevel=6) as z:
    for dp, _dn, fn in os.walk(stage):
        for f in fn:
            full = os.path.join(dp, f)
            z.write(full, os.path.relpath(full, os.path.join(out, '_stage')))
PY
  echo "  + $root(.zip)"
done

rm -rf "$OUT/_stage"
(cd "$OUT" && sha256sum artex-* > SHA256SUMS)

echo "产物在 $OUT/"
ls -la "$OUT"
