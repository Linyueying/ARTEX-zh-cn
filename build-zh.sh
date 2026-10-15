#!/usr/bin/env bash
# 构建 ARTEX 汉化版单二进制镜像（artex-zh:local）。
#
# 步骤：
#   1. Next.js 静态导出（web/out）—— 在 node:22 容器里跑，宿主机无需 Node
#   2. 把导出结果放进 server/webui/dist（go:embed 的目录）
#   3. 带 -tags embedui 编译 Go 单二进制到 dist/amd64/artex
#   4. 基于官方镜像只替换二进制，产出 artex-zh:local
#
# 版本号固定为 0.3.21，与线上一致，避免触发「一键更新」逻辑。
set -euo pipefail
cd "$(cd "$(dirname "$0")" && pwd)"

SKIP_WEB="${SKIP_WEB:-0}"

if [ "$SKIP_WEB" != "1" ]; then
  echo "[1/4] 前端静态导出..."
  docker run --rm -v "$PWD":/src -w /src/web \
    -e NEXT_EXPORT=1 -e NODE_OPTIONS=--max-old-space-size=3072 \
    node:22-bookworm sh -c "NEXT_EXPORT=1 npm run build"
else
  echo "[1/4] 跳过前端构建（SKIP_WEB=1），复用已有 web/out"
fi

echo "[2/4] 复制到 server/webui/dist ..."
rm -rf server/webui/dist
mkdir -p server/webui
cp -r web/out server/webui/dist

echo "[3/4] 编译 Go 二进制（-tags embedui）..."
docker volume create artex-gomod >/dev/null
docker volume create artex-gocache >/dev/null
docker run --rm -v "$PWD":/src -w /src \
  -v artex-gomod:/go/pkg/mod -v artex-gocache:/root/.cache/go-build \
  -e CGO_ENABLED=0 -e GOFLAGS=-mod=mod \
  golang:1.26.9-bookworm \
  go build -tags embedui -ldflags "-s -w -buildid= -X main.version=0.3.21" \
  -o dist/amd64/artex ./cmd/artex

echo "[4/4] 打包镜像 artex-zh:local ..."
docker build -f Dockerfile.zh -t artex-zh:local .

echo "完成：artex-zh:local"
